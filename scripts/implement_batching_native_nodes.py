#!/usr/bin/env python3
"""
Implementação CORRETA de message batching usando nodes NATIVOS do n8n

Arquitetura:
1. Main Router Flow: Adiciona nodes Postgres + IF + Code
2. Batch Processor Flow: Cron + Postgres + IF + Execute

NÃO usa $executeQuery() em JavaScript (não existe!)
USA nodes nativos do n8n (Postgres, IF, Code)
"""

import json
from pathlib import Path
import uuid


def create_batch_check_and_collect_nodes():
    """
    Criar sequência de nodes para coletar mensagens em batch

    Fluxo:
    1. Code: Prepare Batch Check (prepara dados)
    2. Postgres: Check Existing Batch (query)
    3. IF: Batch Exists?
       - YES → Postgres: Add to Batch → Stop (output [])
       - NO → Postgres: Create Batch → Stop (output [])
    """

    nodes = []

    # Node 1: Code - Prepare Batch Check
    node_prepare = {
        "parameters": {
            "jsCode": """// Preparar dados para check de batch
const message = $input.first().json;

// Verificar se é mensagem válida para batch
if (!message.whatsapp_id || message.is_from_me || message.is_broadcast) {
  // Não fazer batch - passar adiante normalmente
  return [{
    json: {
      ...message,
      should_batch: false,
      batch_reason: 'not_batchable'
    }
  }];
}

// Preparar dados para query
return [{
  json: {
    ...message,
    should_batch: true,
    whatsapp_id: message.whatsapp_id,
    company_id: message.company_id || 1
  }
}];"""
        },
        "id": str(uuid.uuid4()),
        "name": "Code: Prepare Batch Check",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [1000, 300]
    }
    nodes.append(node_prepare)

    # Node 2: IF - Should Batch?
    node_if_should_batch = {
        "parameters": {
            "conditions": {
                "boolean": [
                    {
                        "value1": "={{ $json.should_batch }}",
                        "value2": True
                    }
                ]
            }
        },
        "id": str(uuid.uuid4()),
        "name": "IF: Should Batch?",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2,
        "position": [1200, 300]
    }
    nodes.append(node_if_should_batch)

    # Node 3: Postgres - Check Existing Batch
    node_check_batch = {
        "parameters": {
            "operation": "executeQuery",
            "query": """SELECT
  id,
  contact_id,
  batch_expires_at,
  batch_messages,
  array_length(batch_messages, 1) as message_count
FROM corev4_chats
WHERE company_id = {{ $json.company_id }}
  AND contact_id = (
    SELECT id FROM corev4_contacts
    WHERE whatsapp = '{{ $json.whatsapp_id }}'
      AND company_id = {{ $json.company_id }}
    LIMIT 1
  )
  AND batch_collecting = TRUE
  AND batch_expires_at > NOW()
LIMIT 1;""",
            "options": {}
        },
        "id": str(uuid.uuid4()),
        "name": "Postgres: Check Batch",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [1400, 250],
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        }
    }
    nodes.append(node_check_batch)

    # Node 4: IF - Batch Exists?
    node_if_batch_exists = {
        "parameters": {
            "conditions": {
                "number": [
                    {
                        "value1": "={{ $json.id }}",
                        "operation": "isNotEmpty"
                    }
                ]
            }
        },
        "id": str(uuid.uuid4()),
        "name": "IF: Batch Exists?",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2,
        "position": [1600, 250]
    }
    nodes.append(node_if_batch_exists)

    # Node 5: Code - Prepare Message Object (for adding to batch)
    node_prepare_message = {
        "parameters": {
            "jsCode": """// Criar objeto da mensagem para armazenar no batch
const originalMessage = $('Code: Prepare Batch Check').first().json;
const batch = $input.first().json;

const messageObj = {
  message_id: originalMessage.message_id,
  whatsapp_id: originalMessage.whatsapp_id,
  message_content: originalMessage.message_content,
  message_type: originalMessage.message_type,
  media_type: originalMessage.media_type || 'none',
  has_media: originalMessage.has_media || false,
  media_url: originalMessage.media_url || null,
  transcribed: originalMessage.transcribed || null,
  timestamp: new Date().toISOString(),
  raw: originalMessage
};

return [{
  json: {
    batch_id: batch.id,
    message_obj: JSON.stringify(messageObj)
  }
}];"""
        },
        "id": str(uuid.uuid4()),
        "name": "Code: Prepare Message Obj",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [1800, 150]
    }
    nodes.append(node_prepare_message)

    # Node 6: Postgres - Add to Existing Batch
    node_add_to_batch = {
        "parameters": {
            "operation": "executeQuery",
            "query": """UPDATE corev4_chats
SET
  batch_messages = array_append(batch_messages, $1::jsonb),
  batch_expires_at = NOW() + INTERVAL '3 seconds',
  last_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
  updated_at = NOW()
WHERE id = $2
RETURNING id, array_length(batch_messages, 1) as total_messages;""",
            "options": {
                "queryReplacement": "={{ $json.message_obj }}:{{ $json.batch_id }}"
            }
        },
        "id": str(uuid.uuid4()),
        "name": "Postgres: Add to Batch",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [2000, 150],
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        }
    }
    nodes.append(node_add_to_batch)

    # Node 7: Code - Stop (return empty for added to batch)
    node_stop_added = {
        "parameters": {
            "jsCode": """// Mensagem adicionada ao batch - não processar agora
console.log('✅ Batch ${$json.batch_id}: Added message (total: ${$json.total_messages})');
return [];  // Return empty - não processar ainda"""
        },
        "id": str(uuid.uuid4()),
        "name": "Code: Stop (Added)",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [2200, 150]
    }
    nodes.append(node_stop_added)

    # Node 8: Code - Prepare New Batch
    node_prepare_new_batch = {
        "parameters": {
            "jsCode": """// Criar novo batch
const originalMessage = $('Code: Prepare Batch Check').first().json;

// Buscar contact_id
const contactQuery = `SELECT id FROM corev4_contacts WHERE whatsapp = '${originalMessage.whatsapp_id}' AND company_id = ${originalMessage.company_id} LIMIT 1`;

// Preparar primeiro messageObj
const messageObj = {
  message_id: originalMessage.message_id,
  whatsapp_id: originalMessage.whatsapp_id,
  message_content: originalMessage.message_content,
  message_type: originalMessage.message_type,
  media_type: originalMessage.media_type || 'none',
  has_media: originalMessage.has_media || false,
  media_url: originalMessage.media_url || null,
  transcribed: originalMessage.transcribed || null,
  timestamp: new Date().toISOString(),
  raw: originalMessage
};

return [{
  json: {
    company_id: originalMessage.company_id || 1,
    whatsapp_id: originalMessage.whatsapp_id,
    message_obj: JSON.stringify(messageObj),
    contact_query: contactQuery
  }
}];"""
        },
        "id": str(uuid.uuid4()),
        "name": "Code: Prepare New Batch",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [1800, 350]
    }
    nodes.append(node_prepare_new_batch)

    # Node 9: Postgres - Get Contact ID
    node_get_contact = {
        "parameters": {
            "operation": "executeQuery",
            "query": "={{ $json.contact_query }}",
            "options": {}
        },
        "id": str(uuid.uuid4()),
        "name": "Postgres: Get Contact",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [2000, 350],
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        }
    }
    nodes.append(node_get_contact)

    # Node 10: Postgres - Create New Batch
    node_create_batch = {
        "parameters": {
            "operation": "executeQuery",
            "query": """INSERT INTO corev4_chats (
  contact_id,
  company_id,
  batch_collecting,
  batch_expires_at,
  batch_messages,
  last_message_ts,
  last_lead_message_ts,
  conversation_open
) VALUES (
  $1,
  $2,
  TRUE,
  NOW() + INTERVAL '3 seconds',
  ARRAY[$3::jsonb],
  EXTRACT(EPOCH FROM NOW())::bigint,
  EXTRACT(EPOCH FROM NOW())::bigint,
  TRUE
)
ON CONFLICT (contact_id, company_id) DO UPDATE
SET
  batch_collecting = TRUE,
  batch_expires_at = NOW() + INTERVAL '3 seconds',
  batch_messages = ARRAY[$3::jsonb],
  last_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
  updated_at = NOW()
RETURNING id;""",
            "options": {
                "queryReplacement": "={{ $json.id }}:={{ $('Code: Prepare New Batch').item.json.company_id }}:={{ $('Code: Prepare New Batch').item.json.message_obj }}"
            }
        },
        "id": str(uuid.uuid4()),
        "name": "Postgres: Create Batch",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [2200, 350],
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        }
    }
    nodes.append(node_create_batch)

    # Node 11: Code - Stop (return empty for new batch)
    node_stop_created = {
        "parameters": {
            "jsCode": """// Novo batch criado - não processar agora
console.log('🆕 Batch ${$json.id}: Started (waiting 3s)');
return [];  // Return empty - aguardar mais mensagens"""
        },
        "id": str(uuid.uuid4()),
        "name": "Code: Stop (Created)",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [2400, 350]
    }
    nodes.append(node_stop_created)

    return nodes


def create_batch_processor_workflow():
    """
    Criar Batch Processor Flow usando nodes nativos

    Fluxo:
    1. Cron: Every 2s
    2. Postgres: Fetch Expired Batches
    3. IF: Has Results?
       - YES → Code: Combine Messages → Postgres: Mark Processed → Execute: One Flow
       - NO → Stop
    """

    workflow = {
        "name": "Batch Processor Flow | v4 (Native Nodes)",
        "nodes": [],
        "connections": {},
        "active": False,
        "settings": {
            "executionOrder": "v1"
        },
        "versionId": str(uuid.uuid4())
    }

    # Node 1: Cron Trigger
    node_cron = {
        "parameters": {
            "rule": {
                "interval": [
                    {
                        "field": "seconds",
                        "secondsInterval": 2
                    }
                ]
            }
        },
        "id": str(uuid.uuid4()),
        "name": "Cron: Every 2 Seconds",
        "type": "n8n-nodes-base.cron",
        "typeVersion": 1,
        "position": [200, 300]
    }
    workflow["nodes"].append(node_cron)

    # Node 2: Postgres - Fetch Expired Batches
    node_fetch = {
        "parameters": {
            "operation": "executeQuery",
            "query": """SELECT
  c.id as chat_id,
  c.contact_id,
  c.company_id,
  c.batch_messages,
  co.whatsapp as whatsapp_number,
  co.name as contact_name
FROM corev4_chats c
JOIN corev4_contacts co ON c.contact_id = co.id
WHERE c.batch_collecting = TRUE
  AND c.batch_expires_at <= NOW()
  AND c.batch_messages IS NOT NULL
  AND jsonb_array_length(c.batch_messages) > 0
LIMIT 10;""",
            "options": {}
        },
        "id": str(uuid.uuid4()),
        "name": "Postgres: Fetch Expired Batches",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [400, 300],
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        }
    }
    workflow["nodes"].append(node_fetch)

    # Node 3: IF - Has Results?
    node_if_has_results = {
        "parameters": {
            "conditions": {
                "number": [
                    {
                        "value1": "={{ $input.all().length }}",
                        "operation": "larger",
                        "value2": 0
                    }
                ]
            }
        },
        "id": str(uuid.uuid4()),
        "name": "IF: Has Batches?",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2,
        "position": [600, 300]
    }
    workflow["nodes"].append(node_if_has_results)

    # Node 4: Code - Combine Messages
    node_combine = {
        "parameters": {
            "jsCode": """// Combinar mensagens do batch
const batch = $input.first().json;

// Parse batch_messages (é JSONB array)
const messages = typeof batch.batch_messages === 'string'
  ? JSON.parse(batch.batch_messages)
  : batch.batch_messages;

// Combinar em texto único
const combinedText = messages
  .map((msg, idx) => {
    const content = msg.message_content || '';
    return content;
  })
  .filter(Boolean)
  .join('\\n');

console.log(`📦 Processing batch ${batch.chat_id}: ${messages.length} messages`);
console.log(`🤝 Combined: "${combinedText.substring(0, 100)}..."`);

// Pegar a ÚLTIMA mensagem como base (tem todos os dados de contexto)
const lastMessage = messages[messages.length - 1];
const originalData = lastMessage.raw || lastMessage;

// Retornar como se fosse UMA mensagem normal
return [{
  json: {
    ...originalData,
    message_content: combinedText,
    is_batched: true,
    batch_message_count: messages.length,
    chat_id_to_mark: batch.chat_id
  }
}];"""
        },
        "id": str(uuid.uuid4()),
        "name": "Code: Combine Messages",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [800, 250]
    }
    workflow["nodes"].append(node_combine)

    # Node 5: Postgres - Mark Batch Processed
    node_mark_processed = {
        "parameters": {
            "operation": "executeQuery",
            "query": """UPDATE corev4_chats
SET
  batch_collecting = FALSE,
  batch_expires_at = NULL,
  updated_at = NOW()
WHERE id = {{ $json.chat_id_to_mark }};""",
            "options": {}
        },
        "id": str(uuid.uuid4()),
        "name": "Postgres: Mark Processed",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [1000, 250],
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        }
    }
    workflow["nodes"].append(node_mark_processed)

    # Node 6: Execute Workflow - CoreAdapt One Flow
    node_execute_one = {
        "parameters": {
            "source": "database",
            "workflowId": "={{ 'CoreAdapt One Flow | v4' }}",  # Will be resolved by n8n
            "options": {}
        },
        "id": str(uuid.uuid4()),
        "name": "Execute: One Flow",
        "type": "n8n-nodes-base.executeWorkflow",
        "typeVersion": 1.3,
        "position": [1200, 250]
    }
    workflow["nodes"].append(node_execute_one)

    # Node 7: No Operation (for false branch)
    node_noop = {
        "parameters": {},
        "id": str(uuid.uuid4()),
        "name": "No Operation",
        "type": "n8n-nodes-base.noOp",
        "typeVersion": 1,
        "position": [800, 400]
    }
    workflow["nodes"].append(node_noop)

    # Connections
    workflow["connections"] = {
        "Cron: Every 2 Seconds": {
            "main": [[{"node": "Postgres: Fetch Expired Batches", "type": "main", "index": 0}]]
        },
        "Postgres: Fetch Expired Batches": {
            "main": [[{"node": "IF: Has Batches?", "type": "main", "index": 0}]]
        },
        "IF: Has Batches?": {
            "main": [
                [{"node": "Code: Combine Messages", "type": "main", "index": 0}],
                [{"node": "No Operation", "type": "main", "index": 0}]
            ]
        },
        "Code: Combine Messages": {
            "main": [[{"node": "Postgres: Mark Processed", "type": "main", "index": 0}]]
        },
        "Postgres: Mark Processed": {
            "main": [[{"node": "Execute: One Flow", "type": "main", "index": 0}]]
        }
    }

    return workflow


def main():
    print("=" * 80)
    print("IMPLEMENTANDO MESSAGE BATCHING COM NODES NATIVOS")
    print("=" * 80)
    print()
    print("Arquitetura:")
    print("  1. Main Router: Nodes Postgres + IF + Code (NÃO JavaScript puro)")
    print("  2. Batch Processor: Cron + Postgres + Execute")
    print()
    print("IMPORTANTE: NÃO usa $executeQuery() (não existe!)")
    print("            USA nodes nativos do n8n")
    print()

    # Criar Batch Processor Flow
    print("Criando Batch Processor Flow...")
    batch_processor = create_batch_processor_workflow()

    output_file = Path("Batch Processor Flow _ v4_NATIVE.json")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(batch_processor, f, indent=2, ensure_ascii=False)

    print(f"✅ Criado: {output_file}")
    print(f"   - {len(batch_processor['nodes'])} nodes")
    print(f"   - Usa nodes nativos (Postgres, IF, Code, Execute)")
    print()

    # Documentar nodes do Main Router (não vou modificar o arquivo diretamente)
    print("=" * 80)
    print("NODES PARA ADICIONAR NO MAIN ROUTER FLOW")
    print("=" * 80)
    print()
    print("Você precisa adicionar manualmente estes nodes no Main Router:")
    print()
    print("1. Code: Prepare Batch Check")
    print("2. IF: Should Batch?")
    print("3. Postgres: Check Batch")
    print("4. IF: Batch Exists?")
    print("5. Code: Prepare Message Obj (branch YES)")
    print("6. Postgres: Add to Batch")
    print("7. Code: Stop (Added)")
    print("8. Code: Prepare New Batch (branch NO)")
    print("9. Postgres: Get Contact")
    print("10. Postgres: Create Batch")
    print("11. Code: Stop (Created)")
    print()
    print("OU use o código Python em create_batch_check_and_collect_nodes()")
    print("para gerar JSON dos nodes e importar no n8n.")
    print()
    print("=" * 80)
    print("PRÓXIMOS PASSOS")
    print("=" * 80)
    print()
    print("1. Importar 'Batch Processor Flow _ v4_NATIVE.json' no n8n")
    print("2. Ativar o workflow (toggle verde)")
    print("3. Adicionar nodes de batch no Main Router Flow (ver acima)")
    print("4. Testar enviando 3 mensagens rápidas")
    print("5. Aguardar 3s")
    print("6. Verificar que ONE resposta foi gerada")
    print()


if __name__ == "__main__":
    main()

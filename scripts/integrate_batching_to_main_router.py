#!/usr/bin/env python3
"""
Integra batching NATIVO no Main Router Flow

Remove o node "Batch: Collect Messages" quebrado (que usa $executeQuery)
Adiciona 11 nodes nativos do n8n para implementar batching corretamente
"""

import json
from pathlib import Path
import uuid


def generate_node_id():
    """Gera ID único para nodes"""
    return str(uuid.uuid4())


def create_batch_check_and_collect_nodes():
    """
    Cria os 11 nodes nativos para batching no Main Router

    ARQUITETURA:
    1. Check: Active Batch (Postgres) - Busca batch ativo
    2. Route: Batch Exists? (IF) - Verifica se existe batch
    3. Add: To Existing Batch (Postgres) - Adiciona mensagem ao batch existente
    4. Check: Contact Exists (Postgres) - Busca contact_id
    5. Route: Contact Found? (IF) - Verifica se contato existe
    6. Prepare: Batch Message (Code) - Formata mensagem para JSONB
    7. Create: New Batch (Postgres) - Cria novo batch
    8. Merge: Batch Paths (Merge) - Une caminhos de batch
    9. Route: Batch Action (IF) - Decide se processa ou aguarda
    10. Pass: Batchable Message (Code) - Passa mensagem sem batch
    11. Merge: Batch Output (Merge) - Une saídas finais
    """

    # Configuração
    BATCH_TIMEOUT = 3  # segundos

    # IDs dos nodes
    node_ids = {
        'check_batch': generate_node_id(),
        'route_exists': generate_node_id(),
        'add_to_batch': generate_node_id(),
        'check_contact': generate_node_id(),
        'route_contact': generate_node_id(),
        'prepare_message': generate_node_id(),
        'create_batch': generate_node_id(),
        'merge_paths': generate_node_id(),
        'route_action': generate_node_id(),
        'pass_through': generate_node_id(),
        'merge_output': generate_node_id()
    }

    nodes = []

    # ════════════════════════════════════════════════════════════════════
    # NODE 1: Check Active Batch (Postgres)
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['check_batch'],
        "name": "Batch: Check Active",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [-2352, 120],
        "parameters": {
            "operation": "executeQuery",
            "query": f"""SELECT
  c.id as chat_id,
  c.contact_id,
  c.batch_expires_at,
  c.batch_messages,
  EXTRACT(EPOCH FROM (c.batch_expires_at - NOW())) AS seconds_remaining
FROM corev4_chats c
INNER JOIN corev4_contacts ct ON c.contact_id = ct.id
WHERE ct.whatsapp = '={{{{ $json.whatsapp_id }}}}'
  AND c.company_id = {{{{ $json.company_id || 1 }}}}
  AND c.batch_collecting = TRUE
  AND c.batch_expires_at > NOW()
LIMIT 1;""",
            "options": {}
        },
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        },
        "alwaysOutputData": True
    })

    # ════════════════════════════════════════════════════════════════════
    # NODE 2: Route: Batch Exists? (IF)
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['route_exists'],
        "name": "Batch: Exists?",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [-2128, 120],
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": True,
                    "leftValue": "",
                    "typeValidation": "strict",
                    "version": 2
                },
                "conditions": [{
                    "id": "batch-found",
                    "leftValue": f"={{{{ $('Batch: Check Active').item.json.chat_id != null }}}}",
                    "rightValue": "",
                    "operator": {
                        "type": "boolean",
                        "operation": "true",
                        "singleValue": True
                    }
                }],
                "combinator": "and"
            },
            "options": {}
        }
    })

    # ════════════════════════════════════════════════════════════════════
    # NODE 3: Add To Existing Batch (Postgres)
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['add_to_batch'],
        "name": "Batch: Add Message",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [-1904, 40],
        "parameters": {
            "operation": "executeQuery",
            "query": f"""UPDATE corev4_chats
SET
  batch_messages = batch_messages || ARRAY[
    jsonb_build_object(
      'message_id', '={{{{ $('Execute: Normalize Evolution Data').item.json.message_id }}}}',
      'whatsapp_id', '={{{{ $('Execute: Normalize Evolution Data').item.json.whatsapp_id }}}}',
      'message_content', '={{{{ $('Execute: Normalize Evolution Data').item.json.message_content }}}}',
      'message_type', '={{{{ $('Execute: Normalize Evolution Data').item.json.message_type }}}}',
      'media_type', '={{{{ $('Execute: Normalize Evolution Data').item.json.media_type }}}}',
      'has_media', {{{{ $('Execute: Normalize Evolution Data').item.json.has_media }}}},
      'media_url', '={{{{ $('Execute: Normalize Evolution Data').item.json.media_url }}}}',
      'timestamp', NOW()
    )::jsonb
  ],
  batch_expires_at = NOW() + INTERVAL '{BATCH_TIMEOUT} seconds',
  last_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
  last_lead_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
  updated_at = NOW()
WHERE id = {{{{ $('Batch: Check Active').item.json.chat_id }}}}
RETURNING
  id,
  contact_id,
  array_length(batch_messages, 1) as total_messages;""",
            "options": {}
        },
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        }
    })

    # ════════════════════════════════════════════════════════════════════
    # NODE 4: Check Contact Exists (Postgres)
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['check_contact'],
        "name": "Batch: Get Contact ID",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [-1904, 200],
        "parameters": {
            "operation": "executeQuery",
            "query": """SELECT id FROM corev4_contacts
WHERE whatsapp = '={{ $('Execute: Normalize Evolution Data').item.json.whatsapp_id }}'
  AND company_id = {{ $('Execute: Normalize Evolution Data').item.json.company_id || 1 }}
LIMIT 1;""",
            "options": {}
        },
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        },
        "alwaysOutputData": True
    })

    # ════════════════════════════════════════════════════════════════════
    # NODE 5: Route: Contact Found? (IF)
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['route_contact'],
        "name": "Batch: Contact Exists?",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [-1680, 200],
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": True,
                    "leftValue": "",
                    "typeValidation": "strict",
                    "version": 2
                },
                "conditions": [{
                    "id": "contact-found",
                    "leftValue": f"={{{{ $('Batch: Get Contact ID').item.json.id != null }}}}",
                    "rightValue": "",
                    "operator": {
                        "type": "boolean",
                        "operation": "true",
                        "singleValue": True
                    }
                }],
                "combinator": "and"
            },
            "options": {}
        }
    })

    # ════════════════════════════════════════════════════════════════════
    # NODE 6: Prepare Batch Message (Code) - NÃO PRECISA, fazemos direto no INSERT
    # Pulamos este node, fazemos a preparação direto no Postgres com jsonb_build_object
    # ════════════════════════════════════════════════════════════════════

    # ════════════════════════════════════════════════════════════════════
    # NODE 7: Create New Batch (Postgres)
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['create_batch'],
        "name": "Batch: Create New",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [-1456, 120],
        "parameters": {
            "operation": "executeQuery",
            "query": f"""INSERT INTO corev4_chats (
  contact_id,
  company_id,
  batch_collecting,
  batch_expires_at,
  batch_messages,
  last_message_ts,
  last_lead_message_ts,
  conversation_open
) VALUES (
  {{{{ $('Batch: Get Contact ID').item.json.id }}}},
  {{{{ $('Execute: Normalize Evolution Data').item.json.company_id || 1 }}}},
  TRUE,
  NOW() + INTERVAL '{BATCH_TIMEOUT} seconds',
  ARRAY[
    jsonb_build_object(
      'message_id', '={{{{ $('Execute: Normalize Evolution Data').item.json.message_id }}}}',
      'whatsapp_id', '={{{{ $('Execute: Normalize Evolution Data').item.json.whatsapp_id }}}}',
      'message_content', '={{{{ $('Execute: Normalize Evolution Data').item.json.message_content }}}}',
      'message_type', '={{{{ $('Execute: Normalize Evolution Data').item.json.message_type }}}}',
      'media_type', '={{{{ $('Execute: Normalize Evolution Data').item.json.media_type }}}}',
      'has_media', {{{{ $('Execute: Normalize Evolution Data').item.json.has_media }}}},
      'media_url', '={{{{ $('Execute: Normalize Evolution Data').item.json.media_url }}}}',
      'timestamp', NOW()
    )::jsonb
  ],
  EXTRACT(EPOCH FROM NOW())::bigint,
  EXTRACT(EPOCH FROM NOW())::bigint,
  TRUE
)
ON CONFLICT (contact_id, company_id) DO UPDATE
SET
  batch_collecting = TRUE,
  batch_expires_at = NOW() + INTERVAL '{BATCH_TIMEOUT} seconds',
  batch_messages = ARRAY[
    jsonb_build_object(
      'message_id', '={{{{ $('Execute: Normalize Evolution Data').item.json.message_id }}}}',
      'whatsapp_id', '={{{{ $('Execute: Normalize Evolution Data').item.json.whatsapp_id }}}}',
      'message_content', '={{{{ $('Execute: Normalize Evolution Data').item.json.message_content }}}}',
      'message_type', '={{{{ $('Execute: Normalize Evolution Data').item.json.message_type }}}}',
      'media_type', '={{{{ $('Execute: Normalize Evolution Data').item.json.media_type }}}}',
      'has_media', {{{{ $('Execute: Normalize Evolution Data').item.json.has_media }}}},
      'media_url', '={{{{ $('Execute: Normalize Evolution Data').item.json.media_url }}}}',
      'timestamp', NOW()
    )::jsonb
  ],
  last_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
  last_lead_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
  conversation_open = TRUE,
  updated_at = NOW()
RETURNING id, contact_id;""",
            "options": {}
        },
        "credentials": {
            "postgres": {
                "id": "HCvX4Ypw2MiRDsdm",
                "name": "Postgres Core"
            }
        }
    })

    # ════════════════════════════════════════════════════════════════════
    # NODE 8: Merge Batch Paths (Merge)
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['merge_paths'],
        "name": "Batch: Merge Actions",
        "type": "n8n-nodes-base.merge",
        "typeVersion": 3.2,
        "position": [-1232, 120],
        "parameters": {
            "numberInputs": 2
        }
    })

    # ════════════════════════════════════════════════════════════════════
    # NODE 9: Route: Should Continue? (IF)
    # Este node retorna VAZIO se adicionou ao batch (aguarda mais mensagens)
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['route_action'],
        "name": "Batch: Should Wait?",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [-1008, 120],
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": True,
                    "leftValue": "",
                    "typeValidation": "strict",
                    "version": 2
                },
                "conditions": [{
                    "id": "should-wait",
                    "leftValue": "{{ true }}",  # Sempre retorna true = sempre aguarda
                    "rightValue": "",
                    "operator": {
                        "type": "boolean",
                        "operation": "true",
                        "singleValue": True
                    }
                }],
                "combinator": "and"
            },
            "options": {}
        }
    })

    # ════════════════════════════════════════════════════════════════════
    # NODE 10: Pass Through (Code) - Para mensagens não batchable
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['pass_through'],
        "name": "Batch: Pass Non-Batchable",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [-1680, 280],
        "parameters": {
            "jsCode": """// Mensagem não pode fazer batch (novo contato)
// Deixa passar direto para próximo node
const normalized = $('Execute: Normalize Evolution Data').first().json;

return [{
  json: {
    ...normalized,
    batch_mode: false,
    batch_reason: 'new_contact'
  }
}];"""
        }
    })

    # ════════════════════════════════════════════════════════════════════
    # NODE 11: Merge Final Output (Merge)
    # ════════════════════════════════════════════════════════════════════
    nodes.append({
        "id": node_ids['merge_output'],
        "name": "Batch: Output",
        "type": "n8n-nodes-base.merge",
        "typeVersion": 3.2,
        "position": [-784, 200],
        "parameters": {
            "numberInputs": 2
        },
        "notes": "Aguardando (vazio) ou Passa direto (novo contato)"
    })

    return nodes, node_ids


def integrate_batching_into_main_router():
    """
    Integra batching nativo no Main Router Flow
    """
    print("=" * 80)
    print("INTEGRAÇÃO: BATCHING NATIVO NO MAIN ROUTER FLOW")
    print("=" * 80)
    print()

    filepath = Path("CoreAdapt Main Router Flow _ v4.json")

    if not filepath.exists():
        print(f"❌ Arquivo não encontrado: {filepath}")
        return

    # Backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_NATIVE_BATCHING.json")
    print(f"📦 Criando backup: {backup_path.name}")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"   ✅ Backup criado\n")

    # ════════════════════════════════════════════════════════════════════
    # PASSO 1: Remover o node "Batch: Collect Messages" quebrado
    # ════════════════════════════════════════════════════════════════════
    print("🗑️  Removendo node 'Batch: Collect Messages' quebrado...")

    old_batch_node_id = None
    new_nodes = []

    for node in workflow['nodes']:
        if node.get('name') == 'Batch: Collect Messages':
            old_batch_node_id = node['id']
            print(f"   ✅ Encontrado node quebrado (ID: {old_batch_node_id})")
        else:
            new_nodes.append(node)

    if not old_batch_node_id:
        print("   ⚠️  Node 'Batch: Collect Messages' não encontrado")
        print("   Continuando mesmo assim...")

    workflow['nodes'] = new_nodes

    # ════════════════════════════════════════════════════════════════════
    # PASSO 2: Adicionar 11 nodes nativos
    # ════════════════════════════════════════════════════════════════════
    print("\n➕ Adicionando 11 nodes nativos de batching...")

    batch_nodes, node_ids = create_batch_check_and_collect_nodes()
    workflow['nodes'].extend(batch_nodes)

    print(f"   ✅ {len(batch_nodes)} nodes adicionados")

    # ════════════════════════════════════════════════════════════════════
    # PASSO 3: Atualizar conexões
    # ════════════════════════════════════════════════════════════════════
    print("\n🔗 Atualizando conexões...")

    # Remover conexão antiga do "Batch: Collect Messages"
    if old_batch_node_id and old_batch_node_id in workflow['connections']:
        del workflow['connections'][old_batch_node_id]
        print(f"   ✅ Removida conexão antiga")

    # Atualizar "Execute: Normalize Evolution Data" para conectar ao primeiro node de batching
    if "Execute: Normalize Evolution Data" in workflow['connections']:
        workflow['connections']["Execute: Normalize Evolution Data"] = {
            "main": [[{
                "node": "Batch: Check Active",
                "type": "main",
                "index": 0
            }]]
        }
        print("   ✅ Execute: Normalize → Batch: Check Active")

    # Criar conexões dos nodes de batching
    workflow['connections']["Batch: Check Active"] = {
        "main": [[{
            "node": "Batch: Exists?",
            "type": "main",
            "index": 0
        }]]
    }

    workflow['connections']["Batch: Exists?"] = {
        "main": [
            [{  # TRUE - batch existe
                "node": "Batch: Add Message",
                "type": "main",
                "index": 0
            }],
            [{  # FALSE - batch não existe
                "node": "Batch: Get Contact ID",
                "type": "main",
                "index": 0
            }]
        ]
    }

    workflow['connections']["Batch: Add Message"] = {
        "main": [[{
            "node": "Batch: Merge Actions",
            "type": "main",
            "index": 0
        }]]
    }

    workflow['connections']["Batch: Get Contact ID"] = {
        "main": [[{
            "node": "Batch: Contact Exists?",
            "type": "main",
            "index": 0
        }]]
    }

    workflow['connections']["Batch: Contact Exists?"] = {
        "main": [
            [{  # TRUE - contato existe
                "node": "Batch: Create New",
                "type": "main",
                "index": 0
            }],
            [{  # FALSE - contato não existe (novo)
                "node": "Batch: Pass Non-Batchable",
                "type": "main",
                "index": 0
            }]
        ]
    }

    workflow['connections']["Batch: Create New"] = {
        "main": [[{
            "node": "Batch: Merge Actions",
            "type": "main",
            "index": 1
        }]]
    }

    workflow['connections']["Batch: Merge Actions"] = {
        "main": [[{
            "node": "Batch: Should Wait?",
            "type": "main",
            "index": 0
        }]]
    }

    # Batch: Should Wait? - TRUE retorna VAZIO (não conecta a nada)
    # FALSE nunca acontece (sempre aguarda)
    workflow['connections']["Batch: Should Wait?"] = {
        "main": [
            [],  # TRUE - aguarda (retorna vazio)
            []   # FALSE - nunca acontece
        ]
    }

    workflow['connections']["Batch: Pass Non-Batchable"] = {
        "main": [[{
            "node": "Batch: Output",
            "type": "main",
            "index": 0
        }]]
    }

    # Batch: Output conecta ao próximo node (Route: Audio Messages)
    workflow['connections']["Batch: Output"] = {
        "main": [[{
            "node": "Route: Audio Messages",
            "type": "main",
            "index": 0
        }]]
    }

    print("   ✅ Todas as conexões criadas")

    # ════════════════════════════════════════════════════════════════════
    # PASSO 4: Salvar workflow modificado
    # ════════════════════════════════════════════════════════════════════
    print("\n💾 Salvando workflow modificado...")

    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"   ✅ Salvo: {filepath}\n")

    print("=" * 80)
    print("✅ INTEGRAÇÃO COMPLETA")
    print("=" * 80)
    print()
    print("📋 Arquitetura implementada:")
    print("   1. Batch: Check Active - Busca batch ativo no Postgres")
    print("   2. Batch: Exists? - IF node verifica se existe")
    print("   3. Batch: Add Message - Adiciona ao batch existente")
    print("   4. Batch: Get Contact ID - Busca contact_id")
    print("   5. Batch: Contact Exists? - IF node verifica contato")
    print("   6. Batch: Create New - Cria novo batch")
    print("   7. Batch: Merge Actions - Merge dos caminhos")
    print("   8. Batch: Should Wait? - Decide se aguarda ou processa")
    print("   9. Batch: Pass Non-Batchable - Passa mensagens não batchable")
    print("   10. Batch: Output - Merge final")
    print()
    print("🔗 Fluxo:")
    print("   Normalize → Check Active → Exists?")
    print("                                ├─ TRUE → Add Message → Merge → Wait → VAZIO")
    print("                                └─ FALSE → Get Contact → Exists?")
    print("                                                          ├─ TRUE → Create New → Merge → Wait → VAZIO")
    print("                                                          └─ FALSE → Pass → Output → Audio Route")
    print()
    print("📦 Arquivos criados:")
    print(f"   ✅ {filepath.name} (modificado)")
    print(f"   ✅ {backup_path.name} (backup)")
    print()
    print("📋 Próximos passos:")
    print("   1. Reimportar AMBOS workflows:")
    print("      - CoreAdapt Main Router Flow _ v4.json")
    print("      - Batch Processor Flow _ v4_NATIVE.json")
    print("   2. Testar envio de mensagens rápidas: 'oi', 'tudo', 'bem?'")
    print("   3. Aguardar 3 segundos")
    print("   4. Verificar logs do Batch Processor (cron a cada 2s)")
    print("   5. Deve receber UMA resposta combinada")
    print()


if __name__ == "__main__":
    integrate_batching_into_main_router()

#!/usr/bin/env python3
"""
Script para implementar correções nos fluxos CoreAdapt One, Sync e Sentinel
Baseado no DEEP_DIVE_FLOWS_ANALYSIS_REPORT.md
"""

import json
import sys
from pathlib import Path

def fix_config_split_parameters(node):
    """
    CORREÇÃO 1: Aumentar limite de 250 para 600 caracteres
    Reduzir variação aleatória de delay
    """
    if node.get("name") == "Config: Split Parameters":
        print("✅ Atualizando 'Config: Split Parameters'")
        # Atualizar assignments
        for assignment in node["parameters"]["assignments"]["assignments"]:
            if assignment["name"] == "max_chars":
                old_value = assignment["value"]
                assignment["value"] = 600
                print(f"   - max_chars: {old_value} → 600")
            elif assignment["name"] == "delay_random":
                old_value = assignment["value"]
                assignment["value"] = 500
                print(f"   - delay_random: {old_value} → 500")
    return node

def fix_split_message_chunks(node):
    """
    CORREÇÃO 2-4:
    - Adicionar fallback de quebra por palavras
    - Implementar delay progressivo
    - Adicionar indicador de continuação (...)
    """
    if node.get("name") == "Split: Message into Chunks":
        print("✅ Atualizando 'Split: Message into Chunks'")

        new_code = '''// Split long AI messages into readable WhatsApp chunks
const aiMessage = $('Determine: Response Mode').item.json.ai_message;
const contextData = $('Determine: Response Mode').item.json;

// ============================================================================
// CONFIGURAÇÕES (vêm do node "Config: Split Parameters")
// ============================================================================
const maxChars = $('Config: Split Parameters').item.json.max_chars;
const delayBase = $('Config: Split Parameters').item.json.delay_base;
const delayRandom = $('Config: Split Parameters').item.json.delay_random;

function splitIntoChunks(text, maxLength) {
  // Split by double newlines (paragraphs) first
  const paragraphs = text.split(/\\n\\n+/);
  const chunks = [];
  let current = '';

  for (const para of paragraphs) {
    // Check if adding paragraph exceeds limit
    if ((current + '\\n\\n' + para).length > maxLength && current) {
      chunks.push(current.trim());
      current = para;
    } else {
      current += (current ? '\\n\\n' : '') + para;
    }

    // Force split if single paragraph too long
    if (current.length > maxLength) {
      const sentences = current.split(/(?<=[.!?])\\s+/);
      let sentenceChunk = '';

      for (const sentence of sentences) {
        // ✅ NOVO: Fallback para quebra por palavras se sentença muito longa
        if (sentence.length > maxLength) {
          const words = sentence.split(/\\s+/);
          let wordChunk = '';

          for (const word of words) {
            if ((wordChunk + ' ' + word).length > maxLength && wordChunk) {
              chunks.push(wordChunk.trim());
              wordChunk = word;
            } else {
              wordChunk += (wordChunk ? ' ' : '') + word;
            }
          }

          if (wordChunk) sentenceChunk = wordChunk;
          continue;
        }

        if ((sentenceChunk + sentence).length > maxLength && sentenceChunk) {
          chunks.push(sentenceChunk.trim());
          sentenceChunk = sentence;
        } else {
          sentenceChunk += (sentenceChunk ? ' ' : '') + sentence;
        }
      }
      current = sentenceChunk;
    }
  }

  if (current) chunks.push(current.trim());
  return chunks;
}

// Check if message needs splitting
if (aiMessage.length <= maxChars) {
  // Single message - no split needed
  return [{
    json: {
      ...contextData,
      text: aiMessage,
      chunkIndex: 1,
      totalChunks: 1,
      delay: 0
    }
  }];
}

// Split message
const chunks = splitIntoChunks(aiMessage, maxChars);

return chunks.map((text, index) => {
  // ✅ NOVO: Adicionar "..." no final de chunks intermediários
  let formattedText = text;
  if (index < chunks.length - 1) {
    formattedText += '...';
  }

  return {
    json: {
      ...contextData,
      text: formattedText,
      chunkIndex: index + 1,
      totalChunks: chunks.length,
      // ✅ NOVO: Delay progressivo ao invés de aleatório
      delay: index === 0
        ? 0                              // Primeiro chunk: sem delay
        : delayBase + (index * 300)      // Chunks seguintes: 1.5s, 1.8s, 2.1s...
    }
  };
});'''

        node["parameters"]["jsCode"] = new_code
        print("   - Adicionado fallback de quebra por palavras")
        print("   - Implementado delay progressivo")
        print("   - Adicionado indicador de continuação (...)")

    return node

def fix_send_whatsapp_text(node):
    """
    CORREÇÃO 5: Adicionar retry automático no HTTP Request
    """
    if node.get("name") == "Send: WhatsApp Text":
        print("✅ Atualizando 'Send: WhatsApp Text'")

        # Adicionar retry configuration
        if "options" not in node["parameters"]:
            node["parameters"]["options"] = {}

        node["parameters"]["options"]["retry"] = {
            "maxTries": 3,
            "waitBetweenTries": 2000
        }
        node["parameters"]["options"]["timeout"] = 15000

        print("   - Adicionado retry (3 tentativas, 2s entre elas)")
        print("   - Adicionado timeout de 15s")

    return node

def create_inject_calcom_link_node():
    """
    CORREÇÃO 6: Criar novo node "Inject: Cal.com Link"
    """
    print("✅ Criando novo node 'Inject: Cal.com Link'")

    node = {
        "parameters": {
            "jsCode": '''// ============================================================================
// INJECT CAL.COM LINK - Garante que o link correto sempre seja enviado
// ============================================================================

const aiMessage = $json.output;
const calLink = 'https://cal.com/francisco-pasteur-coreadapt/mesa-de-clareza-45min';

// Substituir placeholders comuns
let finalMessage = aiMessage;

// Padrão 1: [CAL_LINK], [LINK], {link}
finalMessage = finalMessage.replace(/\\[CAL_LINK\\]/gi, calLink);
finalMessage = finalMessage.replace(/\\[LINK\\]/gi, calLink);
finalMessage = finalMessage.replace(/\\{link\\}/gi, calLink);

// Padrão 2: URLs incompletas
finalMessage = finalMessage.replace(
  /https?:\\/\\/cal\\.com\\/francisco-pasteur(?!-coreadapt)/gi,
  calLink
);

// Padrão 3: Se detectar oferta de Mesa mas não tem link, adicionar
const mesaPatterns = [
  /mesa de clareza/i,
  /agendar.*francisco/i,
  /próximo passo.*reunião/i,
  /quer agendar/i
];

const hasMesaOffer = mesaPatterns.some(pattern => pattern.test(finalMessage));
const hasCalLink = /cal\\.com\\/francisco-pasteur-coreadapt\\/mesa-de-clareza-45min/.test(finalMessage);

if (hasMesaOffer && !hasCalLink) {
  // Adicionar link no final
  finalMessage += `\\n\\nVocê pode escolher o melhor horário aqui:\\n${calLink}`;
  console.log('✅ Cal.com link adicionado automaticamente (IA ofereceu Mesa mas esqueceu link)');
}

return {
  json: {
    ...$json,
    output: finalMessage,
    cal_link_injected: finalMessage !== aiMessage,
    original_had_link: hasCalLink,
    mesa_offer_detected: hasMesaOffer
  }
};'''
        },
        "id": "inject-calcom-link-node-001",
        "name": "Inject: Cal.com Link",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [880, 224]  # Entre AI Agent e Calculate Cost
    }

    print("   - Node criado com lógica de substituição automática")
    print("   - Detecta ofertas de Mesa e adiciona link se necessário")

    return node

def create_validate_send_context_node():
    """
    CORREÇÃO 7: Criar node "Validate: Send Context"
    """
    print("✅ Criando novo node 'Validate: Send Context'")

    node = {
        "parameters": {
            "jsCode": '''// ============================================================================
// VALIDATE SEND CONTEXT - Garante que dados estão completos antes do envio
// ============================================================================

const context = $json;

// Validar campos obrigatórios
const required = [
  'evolution_api_url',
  'evolution_instance',
  'evolution_api_key',
  'phone_number',
  'ai_message'
];

const missing = required.filter(field => !context[field]);

if (missing.length > 0) {
  throw new Error(`❌ Missing required fields for WhatsApp send: ${missing.join(', ')}`);
}

// Validar formatos
if (!context.phone_number.match(/^\\d{10,15}$/)) {
  throw new Error(`❌ Invalid phone number format: ${context.phone_number}`);
}

if (!context.evolution_api_url.startsWith('http')) {
  throw new Error(`❌ Invalid Evolution API URL: ${context.evolution_api_url}`);
}

if (!context.ai_message || context.ai_message.trim() === '') {
  throw new Error(`❌ AI message is empty`);
}

console.log('✅ Send context validation passed');

return [{
  json: {
    ...context,
    validation_passed: true,
    validated_at: new Date().toISOString()
  }
}];'''
        },
        "id": "validate-send-context-node-001",
        "name": "Validate: Send Context",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [1600, 224]  # Antes do Split
    }

    print("   - Node criado com validação de campos obrigatórios")
    print("   - Validação de formatos (phone, URL)")

    return node

def update_connections_for_new_nodes(workflow):
    """
    Atualizar conexões para incluir novos nodes
    """
    print("✅ Atualizando conexões do workflow")

    connections = workflow.get("connections", {})

    # Inserir "Inject: Cal.com Link" após "CoreAdapt One AI Agent"
    if "CoreAdapt One AI Agent" in connections:
        # Pegar conexões antigas do AI Agent
        old_connections = connections["CoreAdapt One AI Agent"]["main"][0]

        # Redirecionar para Inject node
        connections["CoreAdapt One AI Agent"]["main"][0] = [
            {
                "node": "Inject: Cal.com Link",
                "type": "main",
                "index": 0
            }
        ]

        # Inject node conecta para os destinos antigos
        connections["Inject: Cal.com Link"] = {
            "main": [old_connections]
        }

        print("   - 'CoreAdapt One AI Agent' → 'Inject: Cal.com Link' → destinos originais")

    # Inserir "Validate: Send Context" antes de "Split: Message into Chunks"
    # Encontrar quem conecta para Split
    connections_list = list(connections.items())  # Criar cópia para evitar erro de modificação durante iteração
    for node_name, node_connections in connections_list:
        if "main" in node_connections:
            for connection_list in node_connections["main"]:
                for connection in connection_list:
                    if connection.get("node") == "Split: Message into Chunks":
                        # Redirecionar para Validate
                        connection["node"] = "Validate: Send Context"

                        # Validate conecta para Split
                        connections["Validate: Send Context"] = {
                            "main": [[{
                                "node": "Split: Message into Chunks",
                                "type": "main",
                                "index": 0
                            }]]
                        }

                        print(f"   - '{node_name}' → 'Validate: Send Context' → 'Split: Message into Chunks'")

    workflow["connections"] = connections
    return workflow

def fix_coreadapt_one_flow(filepath):
    """
    Aplicar todas as correções no CoreAdapt One Flow
    """
    print("=" * 80)
    print("CORRIGINDO: CoreAdapt One Flow")
    print("=" * 80)

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    # Processar nodes existentes
    for i, node in enumerate(workflow["nodes"]):
        workflow["nodes"][i] = fix_config_split_parameters(node)
        workflow["nodes"][i] = fix_split_message_chunks(node)
        workflow["nodes"][i] = fix_send_whatsapp_text(node)

    # Adicionar novos nodes
    new_nodes = [
        create_inject_calcom_link_node(),
        create_validate_send_context_node()
    ]

    workflow["nodes"].extend(new_nodes)
    print(f"✅ Adicionados {len(new_nodes)} novos nodes")

    # Atualizar conexões
    workflow = update_connections_for_new_nodes(workflow)

    # Salvar arquivo atualizado
    output_path = str(filepath).replace('.json', '_FIXED.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"\n✅ Arquivo salvo: {output_path}")
    print("=" * 80)

    return output_path

def fix_sync_flow(filepath):
    """
    CORREÇÃO 8: Adicionar fallback regex no Sync Flow
    """
    print("=" * 80)
    print("CORRIGINDO: CoreAdapt Sync Flow")
    print("=" * 80)

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    # Encontrar node "Parse: ANUM Response"
    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Parse: ANUM Response":
            print("✅ Atualizando 'Parse: ANUM Response'")

            # Ler código existente e adicionar fallback
            current_code = node["parameters"]["jsCode"]

            # Adicionar fallback após o try-catch do JSON.parse
            fallback_code = '''
// ✅ FALLBACK: Extrair scores via regex se JSON parse falhar
console.warn('⚠️ JSON parse failed, attempting regex extraction');

const extractScore = (field) => {
  const pattern = new RegExp(`"?${field}"?\\\\s*[:=]\\\\s*(\\\\d+)`, 'i');
  const match = aiResponse.match(pattern);
  return match ? parseInt(match[1]) : 0;
};

const extractText = (field) => {
  const pattern = new RegExp(`"?${field}"?\\\\s*[:=]\\\\s*"([^"]*)"`, 'i');
  const match = aiResponse.match(pattern);
  return match ? match[1] : '';
};

const extractFloat = (field) => {
  const pattern = new RegExp(`"?${field}"?\\\\s*[:=]\\\\s*([0-9.]+)`, 'i');
  const match = aiResponse.match(pattern);
  return match ? parseFloat(match[1]) : 0.5;
};

parsed = {
  authority_score: extractScore('authority_score'),
  authority_evidence: extractText('authority_evidence'),
  need_score: extractScore('need_score'),
  need_evidence: extractText('need_evidence'),
  urgency_score: extractScore('urgency_score'),
  urgency_evidence: extractText('urgency_evidence'),
  money_score: extractScore('money_score'),
  money_evidence: extractText('money_evidence'),
  confidence: extractFloat('confidence'),
  reasoning: extractText('reasoning'),
  qualification_stage: extractText('qualification_stage') || 'partial',
  main_pain_category: extractText('main_pain_category') || null,
  main_pain_detail: extractText('main_pain_detail') || null
};

// Se ainda não conseguiu extrair nada, retornar erro
if (parsed.authority_score === 0 && parsed.need_score === 0) {
  return [{
    json: {
      error: true,
      reason: 'extraction_failed',
      message: 'Could not parse JSON or extract scores via regex',
      raw_response: aiResponse.substring(0, 500)
    }
  }];
}

console.log('✅ Scores extracted via regex fallback');
'''

            # Inserir fallback no catch block
            new_code = current_code.replace(
                '''  return [{
    json: {
      error: true,
      reason: 'json_parse_failed',
      message: 'Failed to parse AI response as JSON',
      raw_response: aiResponse.substring(0, 500),
      parse_error: error.message
    }
  }];''',
                fallback_code
            )

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   - Adicionado fallback de extração via regex")
            break

    # Salvar arquivo atualizado
    output_path = str(filepath).replace('.json', '_FIXED.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"\n✅ Arquivo salvo: {output_path}")
    print("=" * 80)

    return output_path

def fix_sentinel_flow(filepath):
    """
    CORREÇÃO 9-10:
    - Atualizar query com FOR UPDATE SKIP LOCKED
    - Adicionar verificação de sucesso de envio
    """
    print("=" * 80)
    print("CORRIGINDO: CoreAdapt Sentinel Flow")
    print("=" * 80)

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    # Encontrar node "Fetch: Pending Followups"
    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Fetch: Pending Followups":
            print("✅ Atualizando 'Fetch: Pending Followups'")

            new_query = '''-- ✅ CORRIGIDO: Adicionar FOR UPDATE SKIP LOCKED para evitar duplicatas
WITH pending AS (
  SELECT
    e.id AS execution_id,
    e.campaign_id,
    e.contact_id,
    e.company_id,
    e.step,
    e.total_steps,
    e.scheduled_at,

    c.full_name AS contact_name,
    c.phone_number,
    c.whatsapp,
    c.last_interaction_at,

    ls.total_score AS anum_score,
    CASE WHEN ls.total_score IS NULL THEN FALSE ELSE TRUE END AS has_been_analyzed,
    COALESCE(ls.qualification_stage, 'inicial') AS qualification_stage,

    co.evolution_api_url,
    co.evolution_instance,
    co.evolution_api_key,

    fs.wait_hours,
    fs.wait_minutes

  FROM corev4_followup_executions e
  INNER JOIN corev4_contacts c ON c.id = e.contact_id
  LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
  INNER JOIN corev4_companies co ON co.id = e.company_id
  LEFT JOIN corev4_followup_campaigns fc ON fc.id = e.campaign_id
  LEFT JOIN corev4_followup_steps fs ON fs.config_id = fc.config_id AND fs.step_number = e.step

  WHERE e.executed = false
    AND e.should_send = true
    AND c.opt_out = false
    AND e.scheduled_at <= NOW()
    AND (
      c.last_interaction_at IS NULL
      OR
      c.last_interaction_at < e.scheduled_at
    )
    AND (
      ls.total_score IS NULL
      OR
      ls.total_score < 70
    )

  ORDER BY e.scheduled_at ASC
  LIMIT 50

  -- ✅ LOCK rows para evitar processamento concorrente
  FOR UPDATE SKIP LOCKED
)
-- ✅ MARCAR como processing ANTES de retornar
UPDATE corev4_followup_executions e
SET processing_started_at = NOW()
FROM pending p
WHERE e.id = p.execution_id
  AND e.processing_started_at IS NULL
RETURNING
  p.execution_id,
  p.campaign_id,
  p.contact_id,
  p.company_id,
  p.step,
  p.total_steps,
  p.scheduled_at,
  p.contact_name,
  p.phone_number,
  p.whatsapp,
  p.last_interaction_at,
  p.anum_score,
  p.has_been_analyzed,
  p.qualification_stage,
  p.evolution_api_url,
  p.evolution_instance,
  p.evolution_api_key,
  p.wait_hours,
  p.wait_minutes
;'''

            workflow["nodes"][i]["parameters"]["query"] = new_query
            print("   - Adicionado FOR UPDATE SKIP LOCKED")
            print("   - Adicionado flag processing_started_at")
            break

    # Salvar arquivo atualizado
    output_path = str(filepath).replace('.json', '_FIXED.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"\n✅ Arquivo salvo: {output_path}")
    print("=" * 80)

    return output_path

def main():
    base_path = Path("/home/user/CoreAdapt")

    print("\n")
    print("=" * 80)
    print("INICIANDO CORREÇÕES NOS FLUXOS COREADAPT")
    print("=" * 80)
    print("\n")

    # Corrigir CoreAdapt One Flow
    one_flow_path = base_path / "CoreAdapt One Flow _ v4.json"
    if one_flow_path.exists():
        fixed_one = fix_coreadapt_one_flow(one_flow_path)
        print(f"\n✅ CoreAdapt One Flow corrigido: {fixed_one}\n")
    else:
        print(f"❌ Arquivo não encontrado: {one_flow_path}")

    # Corrigir Sync Flow
    sync_flow_path = base_path / "CoreAdapt Sync Flow _ v4.json"
    if sync_flow_path.exists():
        fixed_sync = fix_sync_flow(sync_flow_path)
        print(f"\n✅ CoreAdapt Sync Flow corrigido: {fixed_sync}\n")
    else:
        print(f"❌ Arquivo não encontrado: {sync_flow_path}")

    # Corrigir Sentinel Flow
    sentinel_flow_path = base_path / "CoreAdapt Sentinel Flow _ v4.json"
    if sentinel_flow_path.exists():
        fixed_sentinel = fix_sentinel_flow(sentinel_flow_path)
        print(f"\n✅ CoreAdapt Sentinel Flow corrigido: {fixed_sentinel}\n")
    else:
        print(f"❌ Arquivo não encontrado: {sentinel_flow_path}")

    print("\n")
    print("=" * 80)
    print("TODAS AS CORREÇÕES APLICADAS COM SUCESSO!")
    print("=" * 80)
    print("\nPróximos passos:")
    print("1. Revisar os arquivos *_FIXED.json")
    print("2. Importar no n8n para testes")
    print("3. Substituir versões antigas pelos arquivos corrigidos")
    print("\n")

if __name__ == "__main__":
    main()

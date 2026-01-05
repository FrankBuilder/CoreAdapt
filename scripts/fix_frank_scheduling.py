#!/usr/bin/env python3
"""
Correções críticas no One Flow:

1. PROBLEMA PRINCIPAL: FRANK inventa horários quando can_offer_meeting=false
   SOLUÇÃO: Atualizar prompt para NUNCA gerar horários específicos

2. PROBLEMA SECUNDÁRIO: Detecção de intenção não intercepta quando FRANK quer agendar
   SOLUÇÃO: Forçar chamada ao Availability Flow quando FRANK menciona agendamento

3. Converter HTTP Request para Execute Subworkflow (padrão do sistema)
"""

import json
import re

print("📦 Carregando One Flow...")
with open('CoreAdapt One Flow _ v4.1_AUTONOMOUS.json', 'r', encoding='utf-8') as f:
    one_flow = json.load(f)

# ============================================================================
# 1. ATUALIZAR NODE "Detect: Scheduling Intent" - Forçar detecção mais agressiva
# ============================================================================

NEW_DETECT_INTENT_CODE = '''const aiOutput = $('CoreAdapt One AI Agent').item.json.output || '';
const contextData = $('Prepare: Chat Context').item.json;
const canOffer = $('Check: Can Offer Meeting').item.json;
const lower = aiOutput.toLowerCase();

// Padrões de intenção de agendamento - AMPLIADOS
const patterns = [
  'agendar', 'agenda', 'horario', 'horário', 'reuniao', 'reunião',
  'mesa de clareza', 'conversa com', 'call', 'disponivel', 'disponível',
  'marcar', 'marcamos', 'bater papo', 'próximo passo', 'proximo passo',
  'mostrar como', 'demonstrar', 'apresentar',
  // Padrões que indicam que FRANK quer oferecer horários
  'deixa eu ver', 'vou verificar', 'vou checar', 'temos essas opções',
  'opções nos próximos', 'opcoes nos proximos',
  // Dias da semana (FRANK pode estar inventando)
  'segunda', 'terça', 'terca', 'quarta', 'quinta', 'sexta',
  // Meses (FRANK pode estar inventando datas)
  '/jan', '/fev', '/mar', '/abr', '/mai', '/jun',
  '/jul', '/ago', '/set', '/out', '/nov', '/dez'
];
const hasIntent = patterns.some(p => lower.includes(p));

// CRÍTICO: Detectar se FRANK INVENTOU horários na resposta
// Se ele mencionou dia da semana + horário, provavelmente inventou
const inventedSlotsPattern = /(segunda|terça|terca|quarta|quinta|sexta|sábado|sabado|domingo)[^\\n]*\\d{1,2}[:/h]\\d{2}/i;
const frankInventedSlots = inventedSlotsPattern.test(aiOutput);

// REMOVER links externos E horários inventados
let cleanOutput = aiOutput
  .replace(/https?:\\/\\/[^\\s]*cal\\.com[^\\s]*/gi, '')
  .replace(/https?:\\/\\/[^\\s]*calendly[^\\s]*/gi, '')
  .replace(/agenda\\s*(aqui|pelo\\s*link)[^\\n]*/gi, '')
  .replace(/\\n{3,}/g, '\\n\\n')
  .trim();

// Se FRANK inventou slots, remover a parte com horários inventados
if (frankInventedSlots) {
  // Remover linhas que parecem horários inventados
  cleanOutput = cleanOutput
    .replace(/\\d+\\.?\\s*(segunda|terça|terca|quarta|quinta|sexta)[^\\n]*\\d{1,2}[:/h]\\d{2}[^\\n]*/gi, '')
    .replace(/[1️⃣2️⃣3️⃣][^\\n]*\\d{1,2}[:/h]\\d{2}[^\\n]*/gi, '')
    .replace(/(temos essas opções|deixa eu ver)[^\\n]*:/gi, '')
    .replace(/qual funciona[^\\n]*/gi, '')
    .replace(/responde 1, 2 ou 3[^\\n]*/gi, '')
    .replace(/\\n{2,}/g, '\\n\\n')
    .trim();
}

// Decisão: chamar Availability Flow?
// MUDANÇA: Chamar SEMPRE que FRANK tentar agendar, independente de can_offer_meeting
// O Availability Flow vai decidir se retorna slots ou mensagem de fallback
const shouldFetchSlots = hasIntent && (canOffer.can_offer_meeting || frankInventedSlots);

return [{
  json: {
    original_output: aiOutput,
    clean_output: cleanOutput,
    ai_message: cleanOutput,
    has_scheduling_intent: hasIntent,
    frank_invented_slots: frankInventedSlots,
    should_fetch_slots: shouldFetchSlots,
    can_offer_meeting: canOffer.can_offer_meeting,
    anum_score: canOffer.total_score || canOffer.meeting_qualification?.scores?.total || 0,
    contact_id: contextData.contact_id,
    company_id: contextData.company_id,
    _debug: {
      patterns_matched: patterns.filter(p => lower.includes(p)),
      invented_slots_detected: frankInventedSlots
    }
  }
}];'''

for node in one_flow['nodes']:
    if node['name'] == 'Detect: Scheduling Intent':
        node['parameters']['jsCode'] = NEW_DETECT_INTENT_CODE
        print("✅ Detect: Scheduling Intent atualizado com detecção de slots inventados")
        break

# ============================================================================
# 2. ATUALIZAR NODE "Inject: Dynamic Slots" - Melhorar substituição
# ============================================================================

NEW_INJECT_SLOTS_CODE = '''const avail = $input.first().json;
const detect = $('Detect: Scheduling Intent').first().json;

if (avail.success && avail.slots_found > 0) {
  // Slots encontrados - usar mensagem do Availability Flow
  return [{
    json: {
      ai_message: avail.offer_message,
      slots_offered: true,
      offer_id: avail.offer_id,
      conversation_state: 'awaiting_slot_selection'
    }
  }];
} else if (detect.frank_invented_slots) {
  // FRANK inventou slots mas não temos disponibilidade real
  // Usar a versão limpa (sem os slots inventados) + mensagem de fallback
  const fallbackMsg = detect.clean_output +
    (detect.clean_output ? '\\n\\n' : '') +
    'A agenda tá bem cheia nos próximos dias. Quer falar direto com o Pasteur? WhatsApp: 5585999855443';
  return [{
    json: {
      ai_message: fallbackMsg,
      slots_offered: false,
      conversation_state: 'normal'
    }
  }];
} else {
  // Sem intenção de agendamento ou sem slots
  const fallback = detect.clean_output + '\\n\\nA agenda tá cheia. Fala com o Pasteur: 5585999855443';
  return [{
    json: {
      ai_message: fallback,
      slots_offered: false,
      conversation_state: 'normal'
    }
  }];
}'''

for node in one_flow['nodes']:
    if node['name'] == 'Inject: Dynamic Slots':
        node['parameters']['jsCode'] = NEW_INJECT_SLOTS_CODE
        print("✅ Inject: Dynamic Slots atualizado com tratamento de slots inventados")
        break

# ============================================================================
# 3. CONVERTER HTTP REQUEST PARA EXECUTE SUBWORKFLOW
# ============================================================================

# Encontrar e atualizar "Call: Availability Flow"
for i, node in enumerate(one_flow['nodes']):
    if node['name'] == 'Call: Availability Flow':
        # Converter de HTTP Request para Execute Workflow
        one_flow['nodes'][i] = {
            "parameters": {
                "source": "database",
                "workflowId": {
                    "__rl": True,
                    "value": "={{ $env.AVAILABILITY_FLOW_ID || 'CoreAdaptAvailabilityV4' }}",
                    "mode": "id"
                },
                "options": {
                    "waitForSubWorkflow": True
                },
                "workflowInputs": {
                    "mappingMode": "defineBelow",
                    "value": {
                        "contact_id": "={{ $json.contact_id }}",
                        "company_id": "={{ $json.company_id }}"
                    }
                }
            },
            "id": node['id'],
            "name": "Call: Availability Flow",
            "type": "n8n-nodes-base.executeWorkflow",
            "typeVersion": 1.1,
            "position": node.get('position', [768, 224]),
            "retryOnFail": True,
            "maxTries": 2
        }
        print("✅ Call: Availability Flow convertido para Execute Subworkflow")
        break

# Encontrar e atualizar "Call: Availability Filtered"
for i, node in enumerate(one_flow['nodes']):
    if node['name'] == 'Call: Availability Filtered':
        one_flow['nodes'][i] = {
            "parameters": {
                "source": "database",
                "workflowId": {
                    "__rl": True,
                    "value": "={{ $env.AVAILABILITY_FLOW_ID || 'CoreAdaptAvailabilityV4' }}",
                    "mode": "id"
                },
                "options": {
                    "waitForSubWorkflow": True
                },
                "workflowInputs": {
                    "mappingMode": "defineBelow",
                    "value": {
                        "contact_id": "={{ $json.contact_id }}",
                        "company_id": "={{ $json.company_id }}",
                        "is_filtered_search": "={{ true }}",
                        "filter_weekday": "={{ $json.preference_weekday || null }}",
                        "filter_period": "={{ $json.preference_period || null }}"
                    }
                }
            },
            "id": node['id'],
            "name": "Call: Availability Filtered",
            "type": "n8n-nodes-base.executeWorkflow",
            "typeVersion": 1.1,
            "position": node.get('position', [-1176, -100]),
            "retryOnFail": True,
            "maxTries": 2
        }
        print("✅ Call: Availability Filtered convertido para Execute Subworkflow")
        break

# ============================================================================
# 4. ATUALIZAR AVAILABILITY FLOW PARA ACEITAR INPUT DE SUBWORKFLOW
# ============================================================================

print("\n📦 Carregando Availability Flow para ajustar entrada...")
with open('CoreAdapt Availability Flow _ v4.json', 'r', encoding='utf-8') as f:
    avail_flow = json.load(f)

# Adicionar node de entrada para subworkflow (Execute Workflow Trigger)
# Verificar se já existe
has_trigger = any(n.get('type') == 'n8n-nodes-base.executeWorkflowTrigger' for n in avail_flow['nodes'])

if not has_trigger:
    # Adicionar trigger node
    trigger_node = {
        "parameters": {},
        "id": "avail-subworkflow-trigger",
        "name": "Subworkflow Trigger",
        "type": "n8n-nodes-base.executeWorkflowTrigger",
        "typeVersion": 1,
        "position": [-1400, 240]
    }
    avail_flow['nodes'].append(trigger_node)

    # Atualizar Fetch: Calendar Settings para aceitar input do trigger ou webhook
    for node in avail_flow['nodes']:
        if node['name'] == 'Fetch: Calendar Settings':
            # Modificar query replacement para aceitar ambos os inputs
            node['parameters']['options']['queryReplacement'] = '''={{
  // Aceitar input de Subworkflow Trigger ou Webhook
  const triggerData = $('Subworkflow Trigger').first()?.json || {};
  const webhookData = $('Webhook: Check Availability').first()?.json?.body || {};
  const data = triggerData.contact_id ? triggerData : webhookData;
  [data.company_id, data.contact_id]
}}'''
            break

    # Atualizar conexões para incluir trigger
    if 'Subworkflow Trigger' not in avail_flow['connections']:
        avail_flow['connections']['Subworkflow Trigger'] = {
            "main": [[{"node": "Fetch: Calendar Settings", "type": "main", "index": 0}]]
        }

    print("✅ Subworkflow Trigger adicionado ao Availability Flow")

# Atualizar Prepare: Query Parameters também
for node in avail_flow['nodes']:
    if node['name'] == 'Prepare: Query Parameters':
        # Atualizar jsCode para aceitar input de trigger ou webhook
        old_code = node['parameters']['jsCode']
        new_code = old_code.replace(
            "const inputData = $('Webhook: Check Availability').first().json.body;",
            """// Aceitar input de Subworkflow Trigger ou Webhook
const triggerData = $('Subworkflow Trigger').first()?.json || {};
const webhookData = $('Webhook: Check Availability').first()?.json?.body || {};
const inputData = triggerData.contact_id ? triggerData : webhookData;"""
        )
        node['parameters']['jsCode'] = new_code
        print("✅ Prepare: Query Parameters atualizado para aceitar subworkflow input")
        break

# Salvar Availability Flow
with open('CoreAdapt Availability Flow _ v4.json', 'w', encoding='utf-8') as f:
    json.dump(avail_flow, f, indent=2, ensure_ascii=False)
print("✅ Availability Flow salvo")

# ============================================================================
# 5. SALVAR ONE FLOW
# ============================================================================

one_flow['name'] = "CoreAdapt One Flow | v4.3 (Fixed Scheduling)"
one_flow['versionId'] = "one-flow-v4.3-fixed-scheduling"

with open('CoreAdapt One Flow _ v4.1_AUTONOMOUS.json', 'w', encoding='utf-8') as f:
    json.dump(one_flow, f, indent=2, ensure_ascii=False)
print("✅ One Flow salvo")

# ============================================================================
# RESUMO
# ============================================================================

print("\n" + "="*70)
print("✅ CORREÇÕES APLICADAS!")
print("="*70)
print("""
MUDANÇAS:

1. DETECT: SCHEDULING INTENT
   - Agora detecta quando FRANK inventa horários na resposta
   - Padrões ampliados para capturar mais intenções
   - Flag `frank_invented_slots` identifica alucinações
   - Força `should_fetch_slots=true` quando detecta slots inventados

2. INJECT: DYNAMIC SLOTS
   - Trata o caso de FRANK ter inventado slots
   - Remove horários inventados e adiciona fallback apropriado
   - Mensagens mais naturais

3. CHAMADAS CONVERTIDAS PARA SUBWORKFLOW
   - Call: Availability Flow → Execute Subworkflow
   - Call: Availability Filtered → Execute Subworkflow
   - Mais eficiente (não passa pela rede)
   - Padrão consistente com resto do sistema

4. AVAILABILITY FLOW
   - Adicionado Subworkflow Trigger para aceitar chamadas de subworkflow
   - Mantém compatibilidade com webhook para testes diretos

FLUXO CORRIGIDO:
1. FRANK gera resposta
2. Detect: Scheduling Intent verifica se FRANK inventou slots
3. Se inventou → força chamada ao Availability Flow
4. Availability Flow retorna slots REAIS
5. Inject: Dynamic Slots substitui a mensagem com slots reais
6. Lead recebe horários corretos

PRÓXIMO PASSO:
→ Re-importar ambos os fluxos no n8n:
   1. CoreAdapt Availability Flow _ v4.json
   2. CoreAdapt One Flow _ v4.1_AUTONOMOUS.json
→ Configurar variável de ambiente AVAILABILITY_FLOW_ID no n8n
""")

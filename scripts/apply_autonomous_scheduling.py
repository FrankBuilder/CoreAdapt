#!/usr/bin/env python3
"""
Script para modificar o CoreAdapt One Flow adicionando agendamento autonomo.
Executa: python3 scripts/apply_autonomous_scheduling.py
"""

import json
import copy
from datetime import datetime

# Carregar fluxo original
with open('CoreAdapt One Flow _ v4.json', 'r', encoding='utf-8') as f:
    flow = json.load(f)

# ============================================================================
# NOVOS NODES A ADICIONAR
# ============================================================================

NEW_NODES = [
    # 1. Fetch Conversation State
    {
        "parameters": {
            "operation": "executeQuery",
            "query": "SELECT\n  c.conversation_state,\n  c.pending_offer_id,\n  c.state_changed_at,\n  c.state_data,\n  o.id AS offer_id,\n  o.status AS offer_status,\n  o.slot_1_datetime, o.slot_1_label,\n  o.slot_2_datetime, o.slot_2_label,\n  o.slot_3_datetime, o.slot_3_label,\n  o.parsing_attempts,\n  CASE\n    WHEN o.id IS NOT NULL AND o.expires_at > NOW() AND o.status IN ('pending', 'needs_confirmation')\n    THEN true ELSE false\n  END AS has_valid_offer\nFROM corev4_chats c\nLEFT JOIN corev4_pending_slot_offers o ON o.id = c.pending_offer_id\nWHERE c.contact_id = $1 AND c.company_id = $2\nORDER BY c.created_at DESC\nLIMIT 1",
            "options": {
                "queryReplacement": "={{ [$('Prepare: Chat Context').item.json.contact_id, $('Prepare: Chat Context').item.json.company_id] }}"
            }
        },
        "id": "fetch-conv-state-001",
        "name": "Fetch: Conversation State",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [-2180, 176],
        "alwaysOutputData": True,
        "credentials": {
            "postgres": {"id": "HCvX4Ypw2MiRDsdm", "name": "Postgres Core"}
        }
    },
    # 2. Route by Conversation State
    {
        "parameters": {
            "rules": {
                "values": [
                    {
                        "conditions": {
                            "conditions": [
                                {"leftValue": "={{ $json.conversation_state }}", "rightValue": "awaiting_slot_selection", "operator": {"type": "string", "operation": "equals"}},
                                {"leftValue": "={{ $json.has_valid_offer }}", "rightValue": True, "operator": {"type": "boolean", "operation": "equals"}}
                            ],
                            "combinator": "and"
                        },
                        "renameOutput": True,
                        "outputKey": "Awaiting Selection"
                    },
                    {
                        "conditions": {
                            "conditions": [
                                {"leftValue": "={{ $json.conversation_state }}", "rightValue": "confirming_slot", "operator": {"type": "string", "operation": "equals"}}
                            ],
                            "combinator": "and"
                        },
                        "renameOutput": True,
                        "outputKey": "Confirming"
                    }
                ],
                "fallbackOutput": {"renameOutput": True, "outputKey": "Normal"}
            },
            "options": {}
        },
        "id": "route-by-state-001",
        "name": "Route: By Conversation State",
        "type": "n8n-nodes-base.switch",
        "typeVersion": 3.2,
        "position": [-1956, 176]
    },
    # 3. Parse Slot Selection
    {
        "parameters": {
            "jsCode": """const stateData = $('Fetch: Conversation State').first().json;
const contextData = $('Prepare: Chat Context').first().json;
const message = (contextData.message_content || '').toLowerCase().trim();

const slots = [
  { index: 1, datetime: stateData.slot_1_datetime, label: stateData.slot_1_label },
  { index: 2, datetime: stateData.slot_2_datetime, label: stateData.slot_2_label },
  { index: 3, datetime: stateData.slot_3_datetime, label: stateData.slot_3_label }
].filter(s => s.datetime);

let selectedSlot = null;
let confidence = 0;
let method = null;

// Numero direto
const directNum = message.match(/^\\s*([1-3])\\s*$/);
if (directNum) {
  const num = parseInt(directNum[1]);
  if (num <= slots.length) { selectedSlot = num; confidence = 1.0; method = 'direct_number'; }
}

// Ordinal
if (!selectedSlot) {
  const ordinals = {'primeir': 1, 'segund': 2, 'terceir': 3, 'um': 1, 'dois': 2, 'tres': 3};
  for (const [key, value] of Object.entries(ordinals)) {
    if (message.includes(key) && value <= slots.length) { selectedSlot = value; confidence = 0.9; method = 'ordinal'; break; }
  }
}

// Dia da semana
if (!selectedSlot) {
  const weekdays = {'segunda': 1, 'terca': 2, 'terça': 2, 'quarta': 3, 'quinta': 4, 'sexta': 5};
  for (const [dayName, dayNum] of Object.entries(weekdays)) {
    if (message.includes(dayName)) {
      for (const slot of slots) {
        if (new Date(slot.datetime).getDay() === dayNum) { selectedSlot = slot.index; confidence = 0.85; method = 'weekday'; break; }
      }
      if (selectedSlot) break;
    }
  }
}

// Generico
if (!selectedSlot) {
  const generic = ['pode ser', 'qualquer', 'tanto faz', 'o primeiro', 'mais cedo'];
  if (generic.some(g => message.includes(g))) { selectedSlot = 1; confidence = 0.75; method = 'generic'; }
}

// Confirmacao
let isConfirmation = false;
if (stateData.conversation_state === 'confirming_slot') {
  const confirms = ['sim', 'isso', 'pode', 'confirma', 'certo', 'ok', 'beleza'];
  if (confirms.some(c => message.includes(c))) {
    selectedSlot = stateData.state_data?.pending_slot || 1;
    confidence = 1.0; method = 'confirmation'; isConfirmation = true;
  }
}

// Recusa
const refusals = ['nao', 'não', 'nenhum', 'outro', 'cancelar'];
const isRefusal = refusals.some(r => message.includes(r)) && !selectedSlot;

return [{
  json: {
    parsed: selectedSlot !== null,
    selected_slot: selectedSlot,
    confidence: confidence,
    method: method,
    is_refusal: isRefusal,
    is_confirmation: isConfirmation,
    needs_clarification: !selectedSlot && !isRefusal,
    offer_id: stateData.offer_id,
    contact_id: contextData.contact_id,
    company_id: contextData.company_id,
    slots: slots,
    selected_datetime: selectedSlot ? slots[selectedSlot - 1]?.datetime : null,
    selected_label: selectedSlot ? slots[selectedSlot - 1]?.label : null,
    parsing_attempts: (stateData.parsing_attempts || 0) + 1
  }
}];"""
        },
        "id": "parse-slot-001",
        "name": "Parse: Slot Selection",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [-1732, 80]
    },
    # 4. Route Parse Result
    {
        "parameters": {
            "rules": {
                "values": [
                    {
                        "conditions": {"conditions": [{"leftValue": "={{ $json.parsed && $json.confidence >= 0.8 }}", "rightValue": True, "operator": {"type": "boolean", "operation": "equals"}}], "combinator": "and"},
                        "renameOutput": True, "outputKey": "High Confidence"
                    },
                    {
                        "conditions": {"conditions": [{"leftValue": "={{ $json.parsed && $json.confidence < 0.8 }}", "rightValue": True, "operator": {"type": "boolean", "operation": "equals"}}], "combinator": "and"},
                        "renameOutput": True, "outputKey": "Needs Confirm"
                    },
                    {
                        "conditions": {"conditions": [{"leftValue": "={{ $json.is_refusal }}", "rightValue": True, "operator": {"type": "boolean", "operation": "equals"}}], "combinator": "and"},
                        "renameOutput": True, "outputKey": "Refusal"
                    }
                ],
                "fallbackOutput": {"renameOutput": True, "outputKey": "Clarify"}
            },
            "options": {}
        },
        "id": "route-parse-001",
        "name": "Route: Parse Result",
        "type": "n8n-nodes-base.switch",
        "typeVersion": 3.2,
        "position": [-1508, 80]
    },
    # 5. Call Booking Flow
    {
        "parameters": {
            "method": "POST",
            "url": "={{ $env.N8N_WEBHOOK_URL || 'https://n8n.coreadapt.cloud' }}/webhook/create-booking",
            "sendHeaders": True,
            "headerParameters": {"parameters": [{"name": "Content-Type", "value": "application/json"}]},
            "sendBody": True,
            "specifyBody": "json",
            "jsonBody": "={{ JSON.stringify({ offer_id: $json.offer_id, selected_slot: $json.selected_slot, confidence: $json.confidence }) }}",
            "options": {"timeout": 30000}
        },
        "id": "call-booking-001",
        "name": "Call: Booking Flow",
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": [-1284, -16],
        "retryOnFail": True,
        "maxTries": 3
    },
    # 6. Handle Booking Result
    {
        "parameters": {
            "jsCode": """const result = $input.first().json;
if (result.success && result.booking_created) {
  return [{ json: { ai_message: '', booking_success: true, skip_response: true } }];
} else {
  const msg = result.should_retry
    ? 'Ops, esse horario acabou de ser reservado! Quer que eu busque outros?'
    : 'Tive um problema. Voce pode falar direto com o Pasteur: 5585999855443';
  return [{ json: { ai_message: msg, booking_success: false, skip_response: false } }];
}"""
        },
        "id": "handle-booking-001",
        "name": "Handle: Booking Result",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [-1060, -16]
    },
    # 7. Reset State After Booking
    {
        "parameters": {
            "operation": "executeQuery",
            "query": "SELECT reset_conversation_state($1::bigint, $2::integer)",
            "options": {"queryReplacement": "={{ [$('Prepare: Chat Context').item.json.contact_id, $('Prepare: Chat Context').item.json.company_id] }}"}
        },
        "id": "reset-state-001",
        "name": "Reset: State After Booking",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [-836, -16],
        "credentials": {"postgres": {"id": "HCvX4Ypw2MiRDsdm", "name": "Postgres Core"}}
    },
    # 8. Prepare Confirmation Request
    {
        "parameters": {
            "jsCode": """const data = $('Parse: Slot Selection').first().json;
const msg = 'Entendi! Voce escolheu:\\n\\n' + data.selected_label + '\\n\\nPosso confirmar esse horario?';
return [{ json: { ai_message: msg, selected_slot: data.selected_slot, selected_label: data.selected_label } }];"""
        },
        "id": "prepare-confirm-001",
        "name": "Prepare: Confirmation Request",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [-1284, 128]
    },
    # 9. Update State to Confirming
    {
        "parameters": {
            "operation": "executeQuery",
            "query": "SELECT update_conversation_state($1::bigint, $2::integer, 'confirming_slot', $3::bigint, $4::jsonb)",
            "options": {"queryReplacement": "={{ [$('Prepare: Chat Context').item.json.contact_id, $('Prepare: Chat Context').item.json.company_id, $('Parse: Slot Selection').first().json.offer_id, JSON.stringify({pending_slot: $json.selected_slot})] }}"}
        },
        "id": "update-confirming-001",
        "name": "Update: State to Confirming",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [-1060, 128],
        "credentials": {"postgres": {"id": "HCvX4Ypw2MiRDsdm", "name": "Postgres Core"}}
    },
    # 10. Prepare Clarification
    {
        "parameters": {
            "jsCode": """const data = $('Parse: Slot Selection').first().json;
const slotsText = data.slots.map((s, i) => (i + 1) + '. ' + s.label).join('\\n');
const msg = data.parsing_attempts >= 3
  ? 'Nao entendi. Pode falar com o Pasteur: 5585999855443\\nOu diz o numero (1, 2 ou 3).'
  : 'Desculpa, qual horario voce prefere?\\n\\n' + slotsText + '\\n\\nResponde 1, 2 ou 3.';
return [{ json: { ai_message: msg } }];"""
        },
        "id": "prepare-clarify-001",
        "name": "Prepare: Clarification",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [-1284, 272]
    },
    # 11. Handle Refusal
    {
        "parameters": {
            "jsCode": """return [{ json: { ai_message: 'Entendi! Quer outros horarios ou prefere falar com o Pasteur? WhatsApp: 5585999855443' } }];"""
        },
        "id": "handle-refusal-001",
        "name": "Handle: Refusal",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [-1284, 368]
    },
    # 12. Cancel Offer Reset
    {
        "parameters": {
            "operation": "executeQuery",
            "query": "UPDATE corev4_pending_slot_offers SET status = 'cancelled' WHERE id = $3; SELECT reset_conversation_state($1::bigint, $2::integer)",
            "options": {"queryReplacement": "={{ [$('Prepare: Chat Context').item.json.contact_id, $('Prepare: Chat Context').item.json.company_id, $('Parse: Slot Selection').first().json.offer_id] }}"}
        },
        "id": "cancel-reset-001",
        "name": "Cancel: Offer and Reset",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [-1060, 368],
        "credentials": {"postgres": {"id": "HCvX4Ypw2MiRDsdm", "name": "Postgres Core"}}
    },
    # 13. Detect Scheduling Intent (SUBSTITUI Inject: Cal.com Link)
    {
        "parameters": {
            "jsCode": """const aiOutput = $('CoreAdapt One AI Agent').item.json.output || '';
const contextData = $('Prepare: Chat Context').item.json;
const canOffer = $('Check: Can Offer Meeting').item.json;
const lower = aiOutput.toLowerCase();

const patterns = ['agendar', 'agenda', 'horario', 'reuniao', 'mesa de clareza', 'conversa com', 'call', 'disponivel'];
const hasIntent = patterns.some(p => lower.includes(p));

// REMOVER links externos
let cleanOutput = aiOutput
  .replace(/https?:\\/\\/[^\\s]*cal\\.com[^\\s]*/gi, '')
  .replace(/https?:\\/\\/[^\\s]*calendly[^\\s]*/gi, '')
  .replace(/agenda\\s*(aqui|pelo\\s*link)[^\\n]*/gi, '')
  .replace(/\\n{3,}/g, '\\n\\n')
  .trim();

return [{
  json: {
    original_output: aiOutput,
    clean_output: cleanOutput,
    ai_message: cleanOutput,
    has_scheduling_intent: hasIntent,
    should_fetch_slots: hasIntent && canOffer.can_offer_meeting,
    contact_id: contextData.contact_id,
    company_id: contextData.company_id
  }
}];"""
        },
        "id": "detect-intent-001",
        "name": "Detect: Scheduling Intent",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [320, 320]
    },
    # 14. Route Should Fetch
    {
        "parameters": {
            "conditions": {
                "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "strict", "version": 2},
                "conditions": [{"id": "fetch-check", "leftValue": "={{ $json.should_fetch_slots }}", "rightValue": True, "operator": {"type": "boolean", "operation": "equals"}}],
                "combinator": "and"
            },
            "options": {}
        },
        "id": "route-fetch-001",
        "name": "Route: Should Fetch Slots",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [544, 320]
    },
    # 15. Call Availability Flow
    {
        "parameters": {
            "method": "POST",
            "url": "={{ $env.N8N_WEBHOOK_URL || 'https://n8n.coreadapt.cloud' }}/webhook/availability-check",
            "sendHeaders": True,
            "headerParameters": {"parameters": [{"name": "Content-Type", "value": "application/json"}]},
            "sendBody": True,
            "specifyBody": "json",
            "jsonBody": "={{ JSON.stringify({ contact_id: $json.contact_id, company_id: $json.company_id }) }}",
            "options": {"timeout": 30000}
        },
        "id": "call-avail-001",
        "name": "Call: Availability Flow",
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": [768, 224],
        "retryOnFail": True,
        "maxTries": 2
    },
    # 16. Inject Dynamic Slots
    {
        "parameters": {
            "jsCode": """const avail = $input.first().json;
const detect = $('Detect: Scheduling Intent').first().json;

if (avail.success && avail.slots_found > 0) {
  return [{ json: { ai_message: avail.offer_message, slots_offered: true, offer_id: avail.offer_id, conversation_state: 'awaiting_slot_selection' } }];
} else {
  const fallback = detect.clean_output + '\\n\\nA agenda ta cheia. Fala com o Pasteur: 5585999855443';
  return [{ json: { ai_message: fallback, slots_offered: false, conversation_state: 'normal' } }];
}"""
        },
        "id": "inject-slots-001",
        "name": "Inject: Dynamic Slots",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [992, 224]
    },
    # 17. Update State After Offer
    {
        "parameters": {
            "operation": "executeQuery",
            "query": "SELECT update_conversation_state($1::bigint, $2::integer, $3::text, $4::bigint, $5::jsonb)",
            "options": {"queryReplacement": "={{ [$('Prepare: Chat Context').item.json.contact_id, $('Prepare: Chat Context').item.json.company_id, $json.conversation_state, $json.offer_id || null, JSON.stringify({offered_at: new Date().toISOString()})] }}"}
        },
        "id": "update-offer-state-001",
        "name": "Update: State After Offer",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.6,
        "position": [1216, 224],
        "credentials": {"postgres": {"id": "HCvX4Ypw2MiRDsdm", "name": "Postgres Core"}}
    },
    # 18. Merge Slot Path
    {
        "parameters": {"mode": "chooseBranch", "output": "empty"},
        "id": "merge-slot-path-001",
        "name": "Merge: Slot Path",
        "type": "n8n-nodes-base.merge",
        "typeVersion": 3,
        "position": [-612, 176]
    }
]

# ============================================================================
# MODIFICAR O FLUXO
# ============================================================================

# Adicionar novos nodes
flow['nodes'].extend(NEW_NODES)

# Encontrar e remover o node "Inject: Cal.com Link"
flow['nodes'] = [n for n in flow['nodes'] if n.get('name') != 'Inject: Cal.com Link']

# Atualizar conexoes
new_connections = {
    "Prepare: Chat Context": {
        "main": [[{"node": "Fetch: Conversation State", "type": "main", "index": 0}]]
    },
    "Fetch: Conversation State": {
        "main": [[{"node": "Route: By Conversation State", "type": "main", "index": 0}]]
    },
    "Route: By Conversation State": {
        "main": [
            [{"node": "Parse: Slot Selection", "type": "main", "index": 0}],
            [{"node": "Parse: Slot Selection", "type": "main", "index": 0}],
            [{"node": "Fetch: Lead State and Preferences", "type": "main", "index": 0}]
        ]
    },
    "Parse: Slot Selection": {
        "main": [[{"node": "Route: Parse Result", "type": "main", "index": 0}]]
    },
    "Route: Parse Result": {
        "main": [
            [{"node": "Call: Booking Flow", "type": "main", "index": 0}],
            [{"node": "Prepare: Confirmation Request", "type": "main", "index": 0}],
            [{"node": "Handle: Refusal", "type": "main", "index": 0}],
            [{"node": "Prepare: Clarification", "type": "main", "index": 0}]
        ]
    },
    "Call: Booking Flow": {
        "main": [[{"node": "Handle: Booking Result", "type": "main", "index": 0}]]
    },
    "Handle: Booking Result": {
        "main": [[{"node": "Reset: State After Booking", "type": "main", "index": 0}]]
    },
    "Reset: State After Booking": {
        "main": [[{"node": "Merge: Slot Path", "type": "main", "index": 0}]]
    },
    "Prepare: Confirmation Request": {
        "main": [[{"node": "Update: State to Confirming", "type": "main", "index": 0}]]
    },
    "Update: State to Confirming": {
        "main": [[{"node": "Merge: Slot Path", "type": "main", "index": 0}]]
    },
    "Prepare: Clarification": {
        "main": [[{"node": "Merge: Slot Path", "type": "main", "index": 0}]]
    },
    "Handle: Refusal": {
        "main": [[{"node": "Cancel: Offer and Reset", "type": "main", "index": 0}]]
    },
    "Cancel: Offer and Reset": {
        "main": [[{"node": "Merge: Slot Path", "type": "main", "index": 0}]]
    },
    "Merge: Slot Path": {
        "main": [[{"node": "Save: AI Response", "type": "main", "index": 0}]]
    },
    "CoreAdapt One AI Agent": {
        "main": [[{"node": "Detect: Scheduling Intent", "type": "main", "index": 0}]]
    },
    "Detect: Scheduling Intent": {
        "main": [[{"node": "Route: Should Fetch Slots", "type": "main", "index": 0}]]
    },
    "Route: Should Fetch Slots": {
        "main": [
            [{"node": "Call: Availability Flow", "type": "main", "index": 0}],
            [{"node": "Calculate: Assistant Cost", "type": "main", "index": 0}]
        ]
    },
    "Call: Availability Flow": {
        "main": [[{"node": "Inject: Dynamic Slots", "type": "main", "index": 0}]]
    },
    "Inject: Dynamic Slots": {
        "main": [[{"node": "Update: State After Offer", "type": "main", "index": 0}]]
    },
    "Update: State After Offer": {
        "main": [[{"node": "Calculate: Assistant Cost", "type": "main", "index": 0}]]
    }
}

# Mesclar conexoes
flow['connections'].update(new_connections)

# Remover conexao antiga do Inject: Cal.com Link
if "Inject: Cal.com Link" in flow['connections']:
    del flow['connections']['Inject: Cal.com Link']

# Atualizar metadata
flow['name'] = "CoreAdapt One Flow | v4.1 (Autonomous Scheduling)"
flow['versionId'] = f"one-flow-autonomous-{datetime.now().strftime('%Y%m%d')}"

# Salvar
output_file = 'CoreAdapt One Flow _ v4.1_AUTONOMOUS.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(flow, f, indent=2, ensure_ascii=False)

print(f"Fluxo modificado salvo em: {output_file}")
print(f"Nodes adicionados: {len(NEW_NODES)}")
print("Proximo passo: Importar no n8n")

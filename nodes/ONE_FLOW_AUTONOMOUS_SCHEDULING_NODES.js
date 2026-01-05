// ============================================================================
// COREADAPT ONE FLOW - AUTONOMOUS SCHEDULING NODES
// v4.1.0 - Janeiro 2026
// ============================================================================
// Este arquivo contem todos os nodes que precisam ser ADICIONADOS ou
// SUBSTITUIDOS no CoreAdapt One Flow para implementar agendamento autonomo.
// ============================================================================

// ============================================================================
// NODE 1: Fetch Conversation State (NOVO - adicionar apos "Prepare: Chat Context")
// ============================================================================
const FETCH_CONVERSATION_STATE = {
  parameters: {
    operation: "executeQuery",
    query: `-- Buscar estado da conversa e oferta pendente
SELECT
  c.conversation_state,
  c.pending_offer_id,
  c.state_changed_at,
  c.state_data,
  o.id AS offer_id,
  o.status AS offer_status,
  o.slot_1_datetime, o.slot_1_label,
  o.slot_2_datetime, o.slot_2_label,
  o.slot_3_datetime, o.slot_3_label,
  o.parsing_attempts,
  CASE
    WHEN o.id IS NOT NULL AND o.expires_at > NOW() AND o.status IN ('pending', 'needs_confirmation')
    THEN true ELSE false
  END AS has_valid_offer,
  EXTRACT(EPOCH FROM (NOW() - c.state_changed_at))::INTEGER / 60 AS minutes_in_state
FROM corev4_chats c
LEFT JOIN corev4_pending_slot_offers o ON o.id = c.pending_offer_id
WHERE c.contact_id = $1 AND c.company_id = $2
ORDER BY c.created_at DESC
LIMIT 1`,
    options: {
      queryReplacement: "={{ [$json.contact_id, $json.company_id] }}"
    }
  },
  id: "fetch-conv-state-001",
  name: "Fetch: Conversation State",
  type: "n8n-nodes-base.postgres",
  typeVersion: 2.6,
  position: [-2500, 176],
  alwaysOutputData: true,
  credentials: {
    postgres: {
      id: "HCvX4Ypw2MiRDsdm",
      name: "Postgres Core"
    }
  }
};

// ============================================================================
// NODE 2: Route by Conversation State (NOVO - apos Fetch Conversation State)
// ============================================================================
const ROUTE_BY_STATE = {
  parameters: {
    rules: {
      values: [
        {
          conditions: {
            conditions: [
              {
                leftValue: "={{ $json.conversation_state }}",
                rightValue: "awaiting_slot_selection",
                operator: { type: "string", operation: "equals" }
              },
              {
                leftValue: "={{ $json.has_valid_offer }}",
                rightValue: true,
                operator: { type: "boolean", operation: "equals" }
              }
            ],
            combinator: "and"
          },
          renameOutput: true,
          outputKey: "Awaiting Selection"
        },
        {
          conditions: {
            conditions: [
              {
                leftValue: "={{ $json.conversation_state }}",
                rightValue: "confirming_slot",
                operator: { type: "string", operation: "equals" }
              }
            ],
            combinator: "and"
          },
          renameOutput: true,
          outputKey: "Confirming Slot"
        }
      ],
      fallbackOutput: {
        renameOutput: true,
        outputKey: "Normal Flow"
      }
    },
    options: {}
  },
  id: "route-by-state-001",
  name: "Route: By Conversation State",
  type: "n8n-nodes-base.switch",
  typeVersion: 3.2,
  position: [-2276, 176]
};

// ============================================================================
// NODE 3: Parse Slot Selection (NOVO - para quando awaiting_slot_selection)
// ============================================================================
const PARSE_SLOT_SELECTION = {
  parameters: {
    jsCode: `// ============================================
// SLOT SELECTION PARSER
// CoreAdapt v4 | Autonomous Scheduling
// ============================================

const stateData = $('Fetch: Conversation State').first().json;
const contextData = $('Prepare: Chat Context').first().json;
const message = (contextData.message_content || '').toLowerCase().trim();

// Slots disponiveis na oferta
const slots = [
  { index: 1, datetime: stateData.slot_1_datetime, label: stateData.slot_1_label },
  { index: 2, datetime: stateData.slot_2_datetime, label: stateData.slot_2_label },
  { index: 3, datetime: stateData.slot_3_datetime, label: stateData.slot_3_label }
].filter(s => s.datetime);

let selectedSlot = null;
let confidence = 0;
let method = null;

// METODO 1: Numero direto ("1", "2", "3")
const directNumber = message.match(/^[\\s]*([1-5])[\\s]*$/);
if (directNumber) {
  const num = parseInt(directNumber[1]);
  if (num <= slots.length) {
    selectedSlot = num;
    confidence = 1.0;
    method = 'direct_number';
  }
}

// METODO 2: Ordinal ("primeiro", "segundo", "terceiro")
if (!selectedSlot) {
  const ordinals = {
    'primeir': 1, '1': 1, 'um': 1, 'uma': 1,
    'segund': 2, '2': 2, 'dois': 2, 'duas': 2,
    'terceir': 3, '3': 3, 'tres': 3, 'três': 3
  };

  for (const [key, value] of Object.entries(ordinals)) {
    if (message.includes(key) && value <= slots.length) {
      selectedSlot = value;
      confidence = 0.9;
      method = 'ordinal';
      break;
    }
  }
}

// METODO 3: Dia da semana ("terca", "quarta")
if (!selectedSlot) {
  const weekdays = {
    'segunda': 1, 'seg': 1,
    'terca': 2, 'terça': 2, 'ter': 2,
    'quarta': 3, 'qua': 3,
    'quinta': 4, 'qui': 4,
    'sexta': 5, 'sex': 5
  };

  for (const [dayName, dayNum] of Object.entries(weekdays)) {
    if (message.includes(dayName)) {
      for (const slot of slots) {
        const slotDate = new Date(slot.datetime);
        if (slotDate.getDay() === dayNum) {
          selectedSlot = slot.index;
          confidence = 0.85;
          method = 'weekday';
          break;
        }
      }
      if (selectedSlot) break;
    }
  }
}

// METODO 4: Afirmacao generica ("pode ser", "qualquer")
if (!selectedSlot) {
  const genericAffirm = ['pode ser', 'qualquer', 'tanto faz', 'voce escolhe', 'vc escolhe', 'o primeiro', 'mais cedo'];
  for (const phrase of genericAffirm) {
    if (message.includes(phrase)) {
      selectedSlot = 1;
      confidence = 0.75;
      method = 'generic_affirm';
      break;
    }
  }
}

// DETECCAO DE RECUSA
const refusalKeywords = ['nao', 'não', 'nenhum', 'outro', 'diferente', 'mudar', 'remarcar', 'cancelar'];
let isRefusal = refusalKeywords.some(kw => message.includes(kw)) && !selectedSlot;

// Verificar confirmacao (se estado era confirming_slot)
let isConfirmation = false;
if (stateData.conversation_state === 'confirming_slot') {
  const confirmKeywords = ['sim', 'isso', 'pode', 'confirma', 'certo', 'ok', 'beleza', 'perfeito'];
  isConfirmation = confirmKeywords.some(kw => message.includes(kw));
  if (isConfirmation) {
    // Recuperar slot que estava sendo confirmado do state_data
    const prevSelected = stateData.state_data?.pending_slot || 1;
    selectedSlot = prevSelected;
    confidence = 1.0;
    method = 'confirmation';
  }
}

return [{
  json: {
    parsed: selectedSlot !== null,
    selected_slot: selectedSlot,
    confidence: confidence,
    method: method,
    is_refusal: isRefusal,
    is_confirmation: isConfirmation,
    needs_clarification: !selectedSlot && !isRefusal,
    original_message: contextData.message_content,
    offer_id: stateData.offer_id,
    contact_id: contextData.contact_id,
    company_id: contextData.company_id,
    slots: slots,
    selected_datetime: selectedSlot ? slots[selectedSlot - 1]?.datetime : null,
    selected_label: selectedSlot ? slots[selectedSlot - 1]?.label : null,
    parsing_attempts: (stateData.parsing_attempts || 0) + 1
  }
}];`
  },
  id: "parse-slot-selection-001",
  name: "Parse: Slot Selection",
  type: "n8n-nodes-base.code",
  typeVersion: 2,
  position: [-2052, 80]
};

// ============================================================================
// NODE 4: Route by Parse Result (NOVO - apos Parse Slot Selection)
// ============================================================================
const ROUTE_BY_PARSE_RESULT = {
  parameters: {
    rules: {
      values: [
        {
          conditions: {
            conditions: [
              {
                leftValue: "={{ $json.parsed }}",
                rightValue: true,
                operator: { type: "boolean", operation: "equals" }
              },
              {
                leftValue: "={{ $json.confidence }}",
                rightValue: 0.8,
                operator: { type: "number", operation: "gte" }
              }
            ],
            combinator: "and"
          },
          renameOutput: true,
          outputKey: "High Confidence"
        },
        {
          conditions: {
            conditions: [
              {
                leftValue: "={{ $json.parsed }}",
                rightValue: true,
                operator: { type: "boolean", operation: "equals" }
              },
              {
                leftValue: "={{ $json.confidence }}",
                rightValue: 0.8,
                operator: { type: "number", operation: "lt" }
              }
            ],
            combinator: "and"
          },
          renameOutput: true,
          outputKey: "Needs Confirmation"
        },
        {
          conditions: {
            conditions: [
              {
                leftValue: "={{ $json.is_refusal }}",
                rightValue: true,
                operator: { type: "boolean", operation: "equals" }
              }
            ],
            combinator: "and"
          },
          renameOutput: true,
          outputKey: "Refusal"
        }
      ],
      fallbackOutput: {
        renameOutput: true,
        outputKey: "Needs Clarification"
      }
    },
    options: {}
  },
  id: "route-parse-result-001",
  name: "Route: Parse Result",
  type: "n8n-nodes-base.switch",
  typeVersion: 3.2,
  position: [-1828, 80]
};

// ============================================================================
// NODE 5: Call Booking Flow (NOVO - quando confianca alta)
// ============================================================================
const CALL_BOOKING_FLOW = {
  parameters: {
    method: "POST",
    url: "={{ $env.N8N_WEBHOOK_URL || 'https://n8n.coreadapt.cloud' }}/webhook/create-booking",
    sendHeaders: true,
    headerParameters: {
      parameters: [
        { name: "Content-Type", value: "application/json" }
      ]
    },
    sendBody: true,
    specifyBody: "json",
    jsonBody: `={{ {
  "offer_id": $json.offer_id,
  "selected_slot": $json.selected_slot,
  "confidence": $json.confidence,
  "method": $json.method
} }}`,
    options: { timeout: 30000 }
  },
  id: "call-booking-flow-001",
  name: "Call: Booking Flow",
  type: "n8n-nodes-base.httpRequest",
  typeVersion: 4.2,
  position: [-1604, -16],
  retryOnFail: true,
  maxTries: 3
};

// ============================================================================
// NODE 6: SUBSTITUIR "Inject: Cal.com Link" por este
// ============================================================================
const DETECT_AND_INJECT_SLOTS = {
  parameters: {
    jsCode: `// ============================================
// DETECT SCHEDULING INTENT & INJECT SLOTS
// Substitui o antigo "Inject: Cal.com Link"
// ============================================

const aiOutput = $('CoreAdapt One AI Agent').item.json.output || '';
const contextData = $('Prepare: Chat Context').item.json;
const canOfferData = $('Check: Can Offer Meeting').item.json;

// Detectar se AI esta tentando oferecer reuniao
const lowerOutput = aiOutput.toLowerCase();
const schedulingPatterns = [
  'agendar', 'agenda', 'horario', 'horário', 'reuniao', 'reunião',
  'mesa de clareza', 'conversa com', 'papo com', 'call', 'meeting',
  'disponivel', 'disponível', 'quando voce pode', 'quando você pode',
  'faz sentido conversar', 'vale uma conversa', 'quer marcar'
];

const hasSchedulingIntent = schedulingPatterns.some(p => lowerOutput.includes(p));

// Verificar se tem link externo (nao deveria ter, mas por seguranca)
const hasExternalLink = /https?:\\/\\/[^\\s]+(?:cal\\.com|calendly|meet)/i.test(aiOutput);

// REMOVER qualquer link de agendamento externo
let cleanOutput = aiOutput
  .replace(/https?:\\/\\/[^\\s]*cal\\.com[^\\s]*/gi, '')
  .replace(/https?:\\/\\/[^\\s]*calendly[^\\s]*/gi, '')
  .replace(/agenda\\s*(aqui|pelo\\s*link)[^\\n]*/gi, '')
  .replace(/voce\\s*pode\\s*escolher\\s*o\\s*(melhor\\s*)?hor[aá]rio\\s*(aqui)?[^\\n]*/gi, '')
  .replace(/\\n{3,}/g, '\\n\\n')
  .trim();

// Decisao: precisa buscar slots?
const shouldFetchSlots = hasSchedulingIntent &&
                         canOfferData.can_offer_meeting &&
                         !hasExternalLink;

return [{
  json: {
    original_output: aiOutput,
    clean_output: cleanOutput,
    has_scheduling_intent: hasSchedulingIntent,
    had_external_link: hasExternalLink,
    should_fetch_slots: shouldFetchSlots,
    can_offer_meeting: canOfferData.can_offer_meeting,
    contact_id: contextData.contact_id,
    company_id: contextData.company_id,
    meeting_qualification: canOfferData.meeting_qualification
  }
}];`
  },
  id: "detect-inject-slots-001",
  name: "Detect: Scheduling Intent",
  type: "n8n-nodes-base.code",
  typeVersion: 2,
  position: [544, 320]
};

// ============================================================================
// NODE 7: Route Should Fetch Slots (NOVO)
// ============================================================================
const ROUTE_SHOULD_FETCH_SLOTS = {
  parameters: {
    conditions: {
      options: {
        caseSensitive: true,
        leftValue: "",
        typeValidation: "strict",
        version: 2
      },
      conditions: [
        {
          id: "should-fetch-slots",
          leftValue: "={{ $json.should_fetch_slots }}",
          rightValue: true,
          operator: {
            type: "boolean",
            operation: "equals"
          }
        }
      ],
      combinator: "and"
    },
    options: {}
  },
  id: "route-should-fetch-001",
  name: "Route: Should Fetch Slots",
  type: "n8n-nodes-base.if",
  typeVersion: 2.2,
  position: [768, 320]
};

// ============================================================================
// NODE 8: Call Availability Flow (NOVO)
// ============================================================================
const CALL_AVAILABILITY_FLOW = {
  parameters: {
    method: "POST",
    url: "={{ $env.N8N_WEBHOOK_URL || 'https://n8n.coreadapt.cloud' }}/webhook/availability-check",
    sendHeaders: true,
    headerParameters: {
      parameters: [
        { name: "Content-Type", value: "application/json" }
      ]
    },
    sendBody: true,
    specifyBody: "json",
    jsonBody: `={{ {
  "contact_id": $json.contact_id,
  "company_id": $json.company_id
} }}`,
    options: { timeout: 30000 }
  },
  id: "call-availability-001",
  name: "Call: Availability Flow",
  type: "n8n-nodes-base.httpRequest",
  typeVersion: 4.2,
  position: [992, 224],
  retryOnFail: true,
  maxTries: 2
};

// ============================================================================
// NODE 9: Inject Dynamic Slots (NOVO)
// ============================================================================
const INJECT_DYNAMIC_SLOTS = {
  parameters: {
    jsCode: `// ============================================
// INJECT DYNAMIC SLOTS INTO AI RESPONSE
// ============================================

const availResult = $input.first().json;
const detectData = $('Detect: Scheduling Intent').first().json;

if (availResult.success && availResult.slots_found > 0) {
  // Disponibilidade encontrada - usar mensagem com slots
  return [{
    json: {
      ai_message: availResult.offer_message,
      slots_offered: true,
      offer_id: availResult.offer_id,
      slots: availResult.slots,
      conversation_state: 'awaiting_slot_selection'
    }
  }];
} else {
  // Sem slots - usar fallback com WhatsApp direto
  const fallbackMsg = detectData.clean_output +
    '\\n\\nA agenda do Pasteur ta bem cheia. Voce pode mandar um WhatsApp direto pra ele: 5585999855443';

  return [{
    json: {
      ai_message: fallbackMsg,
      slots_offered: false,
      conversation_state: 'normal'
    }
  }];
}`
  },
  id: "inject-dynamic-slots-001",
  name: "Inject: Dynamic Slots",
  type: "n8n-nodes-base.code",
  typeVersion: 2,
  position: [1216, 224]
};

// ============================================================================
// NODE 10: Update Conversation State After Offer (NOVO)
// ============================================================================
const UPDATE_STATE_AFTER_OFFER = {
  parameters: {
    operation: "executeQuery",
    query: `SELECT update_conversation_state(
  $1::bigint,
  $2::integer,
  $3::text,
  $4::bigint,
  $5::jsonb
) AS state_updated`,
    options: {
      queryReplacement: `={{ [
  $('Prepare: Chat Context').item.json.contact_id,
  $('Prepare: Chat Context').item.json.company_id,
  $json.conversation_state,
  $json.offer_id || null,
  JSON.stringify({ offered_at: new Date().toISOString(), slots_count: $json.slots?.length || 0 })
] }}`
    }
  },
  id: "update-state-offer-001",
  name: "Update: Conversation State",
  type: "n8n-nodes-base.postgres",
  typeVersion: 2.6,
  position: [1440, 224],
  credentials: {
    postgres: {
      id: "HCvX4Ypw2MiRDsdm",
      name: "Postgres Core"
    }
  }
};

// ============================================================================
// NODE 11: SUBSTITUIR "Detect: Meeting Offer Sent"
// ============================================================================
const DETECT_SLOTS_OFFERED = {
  parameters: {
    jsCode: `// ============================================
// DETECT SLOTS OFFERED (substitui Detect: Meeting Offer Sent)
// ============================================

const contextData = $('Prepare: Chat Context').item.json;

// Verificar se slots foram oferecidos
let slotsOffered = false;
let offerId = null;

try {
  const injectData = $('Inject: Dynamic Slots').first().json;
  slotsOffered = injectData.slots_offered || false;
  offerId = injectData.offer_id || null;
} catch (e) {
  // Se node nao executou, nao foram oferecidos slots
  slotsOffered = false;
}

// Se nao passou pelo inject, verificar se AI mencionou horarios
const aiMessage = $json.ai_message || '';
const mentionedSlots = /\\d\\.\\s*(segunda|terca|terça|quarta|quinta|sexta|[0-9]{1,2}h|[0-9]{1,2}:[0-9]{2})/i.test(aiMessage);

return [{
  json: {
    meeting_offered: slotsOffered || mentionedSlots,
    slots_offered: slotsOffered,
    offer_id: offerId,
    ai_message: $json.ai_message,
    contact_id: contextData.contact_id,
    company_id: contextData.company_id,
    offered_at: slotsOffered ? new Date().toISOString() : null
  }
}];`
  },
  id: "detect-slots-offered-001",
  name: "Detect: Slots Offered",
  type: "n8n-nodes-base.code",
  typeVersion: 2,
  position: [-32, 320]
};

// ============================================================================
// NODE 12: Prepare Clarification Message (para parsing ambiguo)
// ============================================================================
const PREPARE_CLARIFICATION = {
  parameters: {
    jsCode: `// Preparar mensagem de esclarecimento
const parseData = $('Parse: Slot Selection').first().json;

const slotsText = parseData.slots.map((s, i) => \`\${i + 1}. \${s.label}\`).join('\\n');

let msg;
if (parseData.parsing_attempts >= 3) {
  msg = \`Hmm, nao consegui entender qual horario voce prefere.

Voce pode falar direto com o Pasteur pelo WhatsApp: 5585999855443

Ou me diz qual numero voce escolhe (1, 2 ou 3).\`;
} else {
  msg = \`Desculpa, nao entendi bem. Qual desses horarios funciona pra voce?

\${slotsText}

Responde com o numero (1, 2 ou 3).\`;
}

return [{
  json: {
    ai_message: msg,
    needs_clarification: true,
    parsing_attempts: parseData.parsing_attempts
  }
}];`
  },
  id: "prepare-clarification-001",
  name: "Prepare: Clarification Message",
  type: "n8n-nodes-base.code",
  typeVersion: 2,
  position: [-1604, 272]
};

// ============================================================================
// NODE 13: Prepare Confirmation Request (para confianca media)
// ============================================================================
const PREPARE_CONFIRMATION_REQUEST = {
  parameters: {
    jsCode: `// Preparar pedido de confirmacao
const parseData = $('Parse: Slot Selection').first().json;

const msg = \`Entendi! Voce escolheu:

\${parseData.selected_label}

Posso confirmar esse horario?\`;

return [{
  json: {
    ai_message: msg,
    needs_confirmation: true,
    selected_slot: parseData.selected_slot,
    selected_label: parseData.selected_label
  }
}];`
  },
  id: "prepare-confirmation-001",
  name: "Prepare: Confirmation Request",
  type: "n8n-nodes-base.code",
  typeVersion: 2,
  position: [-1604, 128]
};

// ============================================================================
// NODE 14: Update State to Confirming (apos pedir confirmacao)
// ============================================================================
const UPDATE_STATE_CONFIRMING = {
  parameters: {
    operation: "executeQuery",
    query: `SELECT update_conversation_state(
  $1::bigint,
  $2::integer,
  'confirming_slot',
  $3::bigint,
  $4::jsonb
) AS state_updated`,
    options: {
      queryReplacement: `={{ [
  $('Prepare: Chat Context').item.json.contact_id,
  $('Prepare: Chat Context').item.json.company_id,
  $('Parse: Slot Selection').first().json.offer_id,
  JSON.stringify({ pending_slot: $json.selected_slot, pending_label: $json.selected_label })
] }}`
    }
  },
  id: "update-state-confirming-001",
  name: "Update: State to Confirming",
  type: "n8n-nodes-base.postgres",
  typeVersion: 2.6,
  position: [-1380, 128],
  credentials: {
    postgres: {
      id: "HCvX4Ypw2MiRDsdm",
      name: "Postgres Core"
    }
  }
};

// ============================================================================
// NODE 15: Handle Booking Result (apos Booking Flow retornar)
// ============================================================================
const HANDLE_BOOKING_RESULT = {
  parameters: {
    jsCode: `// Processar resultado do booking
const bookingResult = $input.first().json;
const contextData = $('Prepare: Chat Context').first().json;

if (bookingResult.success && bookingResult.booking_created) {
  // Booking criado com sucesso!
  return [{
    json: {
      ai_message: '', // Booking Flow ja enviou confirmacao
      booking_success: true,
      meeting_id: bookingResult.meeting_id,
      meeting_datetime: bookingResult.meeting_datetime,
      skip_response: true // Nao enviar resposta adicional
    }
  }];
} else {
  // Erro no booking - tentar novamente ou fallback
  const errorMsg = bookingResult.message || 'Erro ao agendar';
  let recoveryMsg;

  if (bookingResult.should_retry) {
    recoveryMsg = \`Ops, esse horario acabou de ser reservado! Quer que eu busque outros horarios disponiveis?\`;
  } else {
    recoveryMsg = \`Tive um problema pra confirmar. Voce pode falar direto com o Pasteur: 5585999855443\`;
  }

  return [{
    json: {
      ai_message: recoveryMsg,
      booking_success: false,
      error: errorMsg,
      skip_response: false
    }
  }];
}`
  },
  id: "handle-booking-result-001",
  name: "Handle: Booking Result",
  type: "n8n-nodes-base.code",
  typeVersion: 2,
  position: [-1380, -16]
};

// ============================================================================
// NODE 16: Reset State After Booking (sucesso)
// ============================================================================
const RESET_STATE_AFTER_BOOKING = {
  parameters: {
    operation: "executeQuery",
    query: `SELECT reset_conversation_state($1::bigint, $2::integer) AS state_reset`,
    options: {
      queryReplacement: `={{ [
  $('Prepare: Chat Context').item.json.contact_id,
  $('Prepare: Chat Context').item.json.company_id
] }}`
    }
  },
  id: "reset-state-booking-001",
  name: "Reset: State After Booking",
  type: "n8n-nodes-base.postgres",
  typeVersion: 2.6,
  position: [-1156, -16],
  credentials: {
    postgres: {
      id: "HCvX4Ypw2MiRDsdm",
      name: "Postgres Core"
    }
  }
};

// ============================================================================
// NODE 17: Handle Refusal (quando lead recusa slots)
// ============================================================================
const HANDLE_REFUSAL = {
  parameters: {
    jsCode: `// Lead recusou os horarios oferecidos
const parseData = $('Parse: Slot Selection').first().json;

const msg = \`Entendi! Quer que eu busque outros horarios disponiveis, ou prefere falar direto com o Pasteur?

O WhatsApp dele e 5585999855443\`;

return [{
  json: {
    ai_message: msg,
    is_refusal: true,
    should_reset_state: true
  }
}];`
  },
  id: "handle-refusal-001",
  name: "Handle: Slot Refusal",
  type: "n8n-nodes-base.code",
  typeVersion: 2,
  position: [-1604, 368]
};

// ============================================================================
// NODE 18: Cancel Offer and Reset State (apos recusa)
// ============================================================================
const CANCEL_OFFER_RESET = {
  parameters: {
    operation: "executeQuery",
    query: `-- Cancelar oferta e resetar estado
UPDATE corev4_pending_slot_offers
SET status = 'cancelled', cancellation_reason = 'lead_refused', updated_at = NOW()
WHERE id = $3;

SELECT reset_conversation_state($1::bigint, $2::integer) AS state_reset`,
    options: {
      queryReplacement: `={{ [
  $('Prepare: Chat Context').item.json.contact_id,
  $('Prepare: Chat Context').item.json.company_id,
  $('Parse: Slot Selection').first().json.offer_id
] }}`
    }
  },
  id: "cancel-offer-reset-001",
  name: "Cancel: Offer and Reset",
  type: "n8n-nodes-base.postgres",
  typeVersion: 2.6,
  position: [-1380, 368],
  credentials: {
    postgres: {
      id: "HCvX4Ypw2MiRDsdm",
      name: "Postgres Core"
    }
  }
};

// ============================================================================
// CONEXOES NECESSARIAS (adicionar ao connections do fluxo)
// ============================================================================
const NEW_CONNECTIONS = {
  "Fetch: Conversation State": {
    main: [[{ node: "Route: By Conversation State", type: "main", index: 0 }]]
  },
  "Route: By Conversation State": {
    main: [
      [{ node: "Parse: Slot Selection", type: "main", index: 0 }], // Awaiting Selection
      [{ node: "Parse: Slot Selection", type: "main", index: 0 }], // Confirming Slot
      [{ node: "Fetch: Lead State and Preferences", type: "main", index: 0 }] // Normal Flow
    ]
  },
  "Parse: Slot Selection": {
    main: [[{ node: "Route: Parse Result", type: "main", index: 0 }]]
  },
  "Route: Parse Result": {
    main: [
      [{ node: "Call: Booking Flow", type: "main", index: 0 }], // High Confidence
      [{ node: "Prepare: Confirmation Request", type: "main", index: 0 }], // Needs Confirmation
      [{ node: "Handle: Slot Refusal", type: "main", index: 0 }], // Refusal
      [{ node: "Prepare: Clarification Message", type: "main", index: 0 }] // Needs Clarification
    ]
  },
  "Call: Booking Flow": {
    main: [[{ node: "Handle: Booking Result", type: "main", index: 0 }]]
  },
  "Handle: Booking Result": {
    main: [[{ node: "Reset: State After Booking", type: "main", index: 0 }]]
  },
  "Prepare: Confirmation Request": {
    main: [[{ node: "Update: State to Confirming", type: "main", index: 0 }]]
  },
  "Handle: Slot Refusal": {
    main: [[{ node: "Cancel: Offer and Reset", type: "main", index: 0 }]]
  },
  "Detect: Scheduling Intent": {
    main: [[{ node: "Route: Should Fetch Slots", type: "main", index: 0 }]]
  },
  "Route: Should Fetch Slots": {
    main: [
      [{ node: "Call: Availability Flow", type: "main", index: 0 }], // True
      [{ node: "Calculate: Assistant Cost", type: "main", index: 0 }] // False - continua fluxo normal
    ]
  },
  "Call: Availability Flow": {
    main: [[{ node: "Inject: Dynamic Slots", type: "main", index: 0 }]]
  },
  "Inject: Dynamic Slots": {
    main: [[{ node: "Update: Conversation State", type: "main", index: 0 }]]
  },
  "Update: Conversation State": {
    main: [[{ node: "Calculate: Assistant Cost", type: "main", index: 0 }]]
  }
};

// ============================================================================
// INSTRUCOES DE IMPLEMENTACAO
// ============================================================================
/*
PASSO A PASSO PARA IMPLEMENTAR NO ONE FLOW:

1. ADICIONAR NODES NOVOS:
   - Copie cada node definido acima
   - Cole no JSON do One Flow na secao "nodes"
   - Ajuste as posicoes conforme necessario

2. REMOVER/SUBSTITUIR NODES:
   - REMOVER: "Inject: Cal.com Link" (id: fea26431-908a-4c42-b20d-b1b0dd79d8a5)
   - SUBSTITUIR: "Detect: Meeting Offer Sent" pelo novo "Detect: Slots Offered"

3. AJUSTAR CONEXOES:
   - Adicionar as conexoes definidas em NEW_CONNECTIONS
   - Mudar conexao de "Prepare: Chat Context" para apontar para "Fetch: Conversation State"
   - Mudar conexao de "CoreAdapt One AI Agent" para apontar para "Detect: Scheduling Intent"

4. TESTAR:
   - Lead novo: deve ir para AI normalmente
   - AI oferece horarios: deve chamar Availability Flow e injetar slots
   - Lead seleciona "1": deve chamar Booking Flow e confirmar
   - Lead responde ambiguo: deve pedir confirmacao
   - Lead recusa: deve cancelar oferta e resetar estado

5. ROLLBACK:
   - Manter backup do One Flow original
   - Se algo falhar, restaurar o backup
*/

module.exports = {
  FETCH_CONVERSATION_STATE,
  ROUTE_BY_STATE,
  PARSE_SLOT_SELECTION,
  ROUTE_BY_PARSE_RESULT,
  CALL_BOOKING_FLOW,
  DETECT_AND_INJECT_SLOTS,
  ROUTE_SHOULD_FETCH_SLOTS,
  CALL_AVAILABILITY_FLOW,
  INJECT_DYNAMIC_SLOTS,
  UPDATE_STATE_AFTER_OFFER,
  DETECT_SLOTS_OFFERED,
  PREPARE_CLARIFICATION,
  PREPARE_CONFIRMATION_REQUEST,
  UPDATE_STATE_CONFIRMING,
  HANDLE_BOOKING_RESULT,
  RESET_STATE_AFTER_BOOKING,
  HANDLE_REFUSAL,
  CANCEL_OFFER_RESET,
  NEW_CONNECTIONS
};

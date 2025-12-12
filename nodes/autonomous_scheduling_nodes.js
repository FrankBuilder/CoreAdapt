/**
 * AUTONOMOUS SCHEDULING NODES
 * CoreAdapt v4 | Agendamento Autônomo
 *
 * Este arquivo contém o código JavaScript dos nodes que devem ser
 * adicionados ao CoreAdapt One Flow para suportar agendamento autônomo.
 *
 * INSTRUÇÕES:
 * 1. Adicionar estes nodes ao One Flow
 * 2. Conectar conforme diagrama abaixo
 * 3. Testar com contato de teste
 */

// ============================================================================
// NODE 1: Check Conversation State
// Tipo: n8n-nodes-base.code
// Posição: Logo após receber mensagem do lead, ANTES de chamar FRANK
// ============================================================================
const checkConversationState = `
// Buscar estado atual da conversa
const contactId = $json.contact_id;
const companyId = $json.company_id;

// Este valor vem da query anterior ou do contexto
const conversationState = $json.conversation_state || 'normal';
const pendingOfferId = $json.pending_offer_id;

return [{
  json: {
    ...$json,
    conversation_state: conversationState,
    pending_offer_id: pendingOfferId,
    is_awaiting_selection: conversationState === 'awaiting_slot_selection',
    is_normal: conversationState === 'normal'
  }
}];
`;

// ============================================================================
// NODE 2: Parse Slot Selection
// Tipo: n8n-nodes-base.code
// Posição: Se conversation_state === 'awaiting_slot_selection'
// ============================================================================
const parseSlotSelection = `
// Parser de seleção de slot
const message = $json.message_content || $json.message || '';
const pendingOffer = $json.pending_offer || {};

// Padrões de reconhecimento
const patterns = {
  // Número direto: "1", "2", "3"
  direct_number: /^\\s*([1-5])\\s*$/,

  // Com palavra opção: "opção 1", "opcao 2"
  with_option: /opç[aã]o\\s*([1-5])/i,

  // Ordinal: "primeiro", "segunda", "terceiro"
  ordinal: {
    pattern: /(primeir|segund|terceir|quart|quint)/i,
    map: { 'primeir': 1, 'segund': 2, 'terceir': 3, 'quart': 4, 'quint': 5 }
  },

  // Com verbo: "pode ser o 2", "vamos de 1", "marca o 3"
  with_verb: /(pode ser|vamos de|marca|reserva|quero|prefiro)\\s*(?:o\\s*)?([1-5]|primeir|segund|terceir)/i,

  // Dia da semana
  weekday: /(segunda|terça|terca|quarta|quinta|sexta|s[aá]bado|domingo)/i,

  // Horário
  time: /(?:às?|as)\\s*(\\d{1,2})(?:h|:00|\\s*horas?)?/i,

  // Posicional
  positional: /(primeir|últim|ultim|mei)/i
};

let selectedSlot = null;
let confidence = 0;
let method = null;

// Tentar cada padrão
const normalized = message.toLowerCase().trim();

// 1. Número direto (maior confiança)
const directMatch = normalized.match(patterns.direct_number);
if (directMatch) {
  selectedSlot = parseInt(directMatch[1]);
  confidence = 1.0;
  method = 'direct_number';
}

// 2. Com palavra "opção"
if (!selectedSlot) {
  const optionMatch = message.match(patterns.with_option);
  if (optionMatch) {
    selectedSlot = parseInt(optionMatch[1]);
    confidence = 0.95;
    method = 'with_option';
  }
}

// 3. Com verbo
if (!selectedSlot) {
  const verbMatch = message.match(patterns.with_verb);
  if (verbMatch) {
    const value = verbMatch[2];
    if (/\\d/.test(value)) {
      selectedSlot = parseInt(value);
    } else {
      // Mapear ordinal
      const ordKey = Object.keys(patterns.ordinal.map).find(k => value.toLowerCase().includes(k));
      if (ordKey) selectedSlot = patterns.ordinal.map[ordKey];
    }
    if (selectedSlot) {
      confidence = 0.9;
      method = 'with_verb';
    }
  }
}

// 4. Ordinal sozinho
if (!selectedSlot) {
  const ordMatch = message.match(patterns.ordinal.pattern);
  if (ordMatch) {
    const ordKey = Object.keys(patterns.ordinal.map).find(k => ordMatch[1].toLowerCase().includes(k));
    if (ordKey) {
      selectedSlot = patterns.ordinal.map[ordKey];
      confidence = 0.85;
      method = 'ordinal';
    }
  }
}

// 5. Dia da semana (precisa match com slots disponíveis)
if (!selectedSlot && pendingOffer.slots) {
  const weekdayMatch = message.match(patterns.weekday);
  if (weekdayMatch) {
    const dayMap = {
      'segunda': 1, 'terça': 2, 'terca': 2, 'quarta': 3,
      'quinta': 4, 'sexta': 5, 'sábado': 6, 'sabado': 6, 'domingo': 0
    };
    const targetDay = dayMap[weekdayMatch[1].toLowerCase()];

    // Buscar slot nesse dia
    const matchingSlots = pendingOffer.slots.filter(slot => {
      const slotDate = new Date(slot.datetime);
      return slotDate.getDay() === targetDay;
    });

    if (matchingSlots.length === 1) {
      selectedSlot = matchingSlots[0].index;
      confidence = 0.8;
      method = 'weekday_unique';
    } else if (matchingSlots.length > 1) {
      // Múltiplos slots no mesmo dia - precisa confirmação
      confidence = 0.5;
      method = 'weekday_ambiguous';
    }
  }
}

// 6. Horário (precisa match com slots)
if (!selectedSlot && pendingOffer.slots) {
  const timeMatch = message.match(patterns.time);
  if (timeMatch) {
    const targetHour = parseInt(timeMatch[1]);

    const matchingSlots = pendingOffer.slots.filter(slot => {
      const slotDate = new Date(slot.datetime);
      return slotDate.getHours() === targetHour;
    });

    if (matchingSlots.length === 1) {
      selectedSlot = matchingSlots[0].index;
      confidence = 0.8;
      method = 'time_unique';
    }
  }
}

// Detectar rejeição ou adiamento
const rejectionPatterns = [
  /nenhum/i,
  /n[aã]o\\s*(funciona|d[aá]|serve)/i,
  /depois/i,
  /vou\\s*(ver|pensar|confirmar)/i,
  /deixa\\s*(eu|pra)/i
];

const isRejection = rejectionPatterns.some(p => p.test(message));

// Resultado
const result = {
  selection_detected: selectedSlot !== null && confidence >= 0.7,
  selected_slot: selectedSlot,
  confidence: confidence,
  method: method,
  needs_confirmation: confidence > 0 && confidence < 0.8,
  is_rejection: isRejection,
  original_message: message
};

return [{
  json: {
    ...$json,
    slot_selection: result
  }
}];
`;

// ============================================================================
// NODE 3: Prepare Availability Request
// Tipo: n8n-nodes-base.code
// Posição: Quando FRANK deve oferecer horários (após qualificação)
// ============================================================================
const prepareAvailabilityRequest = `
// Preparar request para Availability Flow
const contactId = $json.contact_id;
const companyId = $json.company_id;

return [{
  json: {
    contact_id: contactId,
    company_id: companyId
  }
}];
`;

// ============================================================================
// NODE 4: Prepare Booking Request
// Tipo: n8n-nodes-base.code
// Posição: Quando seleção é detectada com confiança
// ============================================================================
const prepareBookingRequest = `
// Preparar request para Booking Flow
const selection = $json.slot_selection;
const pendingOfferId = $json.pending_offer_id;

if (!selection.selection_detected) {
  return [{
    json: {
      skip_booking: true,
      reason: 'no_selection_detected'
    }
  }];
}

return [{
  json: {
    offer_id: pendingOfferId,
    selected_slot: selection.selected_slot,
    confidence: selection.confidence
  }
}];
`;

// ============================================================================
// NODE 5: Handle Booking Response
// Tipo: n8n-nodes-base.code
// Posição: Após resposta do Booking Flow
// ============================================================================
const handleBookingResponse = `
// Processar resposta do Booking Flow
const bookingResponse = $json;

if (bookingResponse.success) {
  // Booking bem-sucedido
  return [{
    json: {
      booking_success: true,
      meeting_id: bookingResponse.meeting_id,
      meeting_datetime: bookingResponse.meeting_datetime,
      meeting_url: bookingResponse.meeting_url,
      // Sinalizar para FRANK que não precisa fazer nada
      skip_ai_response: true,
      confirmation_already_sent: true
    }
  }];
}

// Booking falhou
if (bookingResponse.should_retry) {
  // Buscar novos slots
  return [{
    json: {
      booking_success: false,
      error: bookingResponse.error,
      should_fetch_new_slots: true,
      error_message_to_lead: bookingResponse.message
    }
  }];
}

// Erro não recuperável
return [{
  json: {
    booking_success: false,
    error: bookingResponse.error,
    should_use_fallback: true,
    fallback_message: 'Você pode agendar pelo link: https://cal.com/francisco-pasteur-coreadapt/mesa-de-clareza-45min'
  }
}];
`;

// ============================================================================
// NODE 6: Inject Slots into Context
// Tipo: n8n-nodes-base.code
// Posição: Após Availability Flow retornar, ANTES de chamar FRANK
// ============================================================================
const injectSlotsIntoContext = `
// Injetar slots disponíveis no contexto do FRANK
const availabilityResponse = $json;

if (!availabilityResponse.success) {
  // Sem slots - usar fallback Cal.com
  return [{
    json: {
      ...$('Prepare: Chat Context').first().json,
      available_slots: null,
      should_use_cal_link: true,
      cal_link_message: availabilityResponse.fallback_message
    }
  }];
}

// Construir contexto com slots
const slots = availabilityResponse.slots;
const slotsContext = slots.map((s, i) => \`\${i+1}. \${s.label}\`).join('\\n');

return [{
  json: {
    ...$('Prepare: Chat Context').first().json,
    available_slots: slots,
    slots_for_frank: slotsContext,
    offer_message_template: availabilityResponse.offer_message,
    pending_offer_id: availabilityResponse.offer_id,
    conversation_state: 'awaiting_slot_selection'
  }
}];
`;

// ============================================================================
// NODE 7: Check Should Offer Slots
// Tipo: n8n-nodes-base.code
// Posição: Após FRANK responder, verificar se deve oferecer horários
// ============================================================================
const checkShouldOfferSlots = `
// Verificar se a resposta do FRANK indica que deve oferecer horários
const aiResponse = $json.ai_message || $json.response || '';
const anumScore = $json.anum_score || $json.total_score || 0;

// Gatilhos na resposta que indicam oferecimento
const offerTriggers = [
  /mesa de clareza/i,
  /agendar/i,
  /próximo passo/i,
  /quer conhecer/i,
  /marcar (um|uma)? (horário|reunião|conversa)/i,
  /deixa eu ver a agenda/i,
  /francisco.*conversar/i
];

const hasOfferTrigger = offerTriggers.some(pattern => pattern.test(aiResponse));

// Verificar se ainda não tem link Cal.com na resposta
const hasCalLink = /cal\\.com/i.test(aiResponse);

// Decidir se deve buscar slots
const shouldOfferSlots =
  anumScore >= 55 &&
  hasOfferTrigger &&
  !hasCalLink &&
  $json.conversation_state !== 'awaiting_slot_selection';

return [{
  json: {
    ...$json,
    should_offer_slots: shouldOfferSlots,
    trigger_detected: hasOfferTrigger ? 'offer_trigger_in_response' : null
  }
}];
`;

// ============================================================================
// EXPORTS / USAGE
// ============================================================================
module.exports = {
  checkConversationState,
  parseSlotSelection,
  prepareAvailabilityRequest,
  prepareBookingRequest,
  handleBookingResponse,
  injectSlotsIntoContext,
  checkShouldOfferSlots
};

/**
 * DIAGRAMA DE INTEGRAÇÃO NO ONE FLOW:
 *
 *                    ┌─────────────────┐
 *                    │ Mensagem do Lead│
 *                    └────────┬────────┘
 *                             │
 *                             ▼
 *                    ┌─────────────────┐
 *                    │ Query: Get Chat │
 *                    │ State           │
 *                    └────────┬────────┘
 *                             │
 *                             ▼
 *                    ┌─────────────────┐
 *                    │ Node 1: Check   │
 *                    │ Conversation    │
 *                    │ State           │
 *                    └────────┬────────┘
 *                             │
 *              ┌──────────────┴──────────────┐
 *              │                             │
 *      (state = normal)           (state = awaiting_selection)
 *              │                             │
 *              ▼                             ▼
 *    ┌─────────────────┐           ┌─────────────────┐
 *    │ Continue para   │           │ Node 2: Parse   │
 *    │ FRANK           │           │ Slot Selection  │
 *    └────────┬────────┘           └────────┬────────┘
 *             │                             │
 *             ▼                  ┌──────────┴──────────┐
 *    ┌─────────────────┐        │                     │
 *    │ FRANK AI Agent  │   (selection)          (no selection)
 *    └────────┬────────┘        │                     │
 *             │                 ▼                     ▼
 *             ▼        ┌─────────────────┐   ┌─────────────────┐
 *    ┌─────────────────┐│ Node 4: Prepare │   │ Continue para   │
 *    │ Node 7: Check   ││ Booking Request │   │ FRANK           │
 *    │ Should Offer    │└────────┬────────┘   └─────────────────┘
 *    └────────┬────────┘         │
 *             │                  ▼
 *    ┌────────┴────────┐ ┌─────────────────┐
 *    │                 │ │ HTTP: Call      │
 *   (yes)            (no)│ Booking Flow    │
 *    │                 │ └────────┬────────┘
 *    ▼                 │          │
 * ┌─────────────────┐  │          ▼
 * │ Node 3: Prepare │  │ ┌─────────────────┐
 * │ Availability    │  │ │ Node 5: Handle  │
 * │ Request         │  │ │ Booking Response│
 * └────────┬────────┘  │ └────────┬────────┘
 *          │           │          │
 *          ▼           │          ▼
 * ┌─────────────────┐  │ ┌─────────────────┐
 * │ HTTP: Call      │  │ │ Send: WhatsApp  │
 * │ Availability    │  │ │ (se necessário) │
 * │ Flow            │  │ └─────────────────┘
 * └────────┬────────┘  │
 *          │           │
 *          ▼           │
 * ┌─────────────────┐  │
 * │ Node 6: Inject  │  │
 * │ Slots into      │──┘
 * │ Context         │
 * └────────┬────────┘
 *          │
 *          ▼
 * ┌─────────────────┐
 * │ Send: WhatsApp  │
 * │ (com horários)  │
 * └─────────────────┘
 */

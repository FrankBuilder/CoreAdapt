// ================================================================
// FIX: Inject: Dynamic Slots v4.5.1
//
// PROBLEMA: Quando FRANK prometia ver agenda mas ANUM era baixo,
// não havia tratamento adequado.
//
// CORREÇÃO: Agora trata 3 cenários:
// 1. ANUM >= 55 + slots disponíveis → Mostra slots
// 2. ANUM >= 55 + sem slots → Fallback (agenda cheia)
// 3. ANUM < 55 → Continua qualificação (não deveria ter oferecido)
// ================================================================

const avail = $input.first().json;
const detect = $('Detect: Scheduling Intent').first().json;
const canOfferData = $('Check: Can Offer Meeting').first().json;

const anumScore = detect.anum_score || canOfferData.meeting_qualification?.scores?.total || 0;
const canOffer = canOfferData.can_offer_meeting || false;

// ================================================================
// CENÁRIO 1: ANUM >= 55 e slots disponíveis
// ================================================================
if (avail.success && avail.slots_found > 0 && canOffer) {
  return [{
    json: {
      ai_message: avail.offer_message,
      slots_offered: true,
      offer_id: avail.offer_id,
      conversation_state: 'awaiting_slot_selection'
    }
  }];
}

// ================================================================
// CENÁRIO 2: ANUM >= 55 mas sem slots disponíveis
// ================================================================
if (canOffer && (!avail.success || avail.slots_found === 0)) {
  const fallbackMsg = 'A agenda do Pasteur tá bem cheia nos próximos dias.\n\nQuer falar direto com ele? WhatsApp: 5585999855443';
  return [{
    json: {
      ai_message: fallbackMsg,
      slots_offered: false,
      conversation_state: 'normal'
    }
  }];
}

// ================================================================
// CENÁRIO 3: FRANK prometeu ver agenda mas ANUM < 55
// Isso não deveria ter acontecido, mas precisamos tratar
// ================================================================
if (detect.frank_promised_to_check && !canOffer) {
  // ANUM ainda baixo - explicar que precisa de mais informações
  const qualificationNeeded = [];
  const scores = canOfferData.meeting_qualification?.scores || {};

  if ((scores.authority || 0) < 50) qualificationNeeded.push('decisor');
  if ((scores.need || 0) < 50) qualificationNeeded.push('dor específica');
  if ((scores.urgency || 0) < 40 && (scores.money || 0) < 40) qualificationNeeded.push('timing/budget');

  // Mensagem que continua a qualificação ao invés de bloquear
  let recoveryMsg;
  if (qualificationNeeded.length > 0) {
    recoveryMsg = `Antes de ver a agenda, me ajuda com mais um detalhe:\n\n`;

    if (qualificationNeeded.includes('decisor')) {
      recoveryMsg += 'Você seria quem bate o martelo sobre implementar uma solução dessas, ou precisaria passar por mais alguém?';
    } else if (qualificationNeeded.includes('dor específica')) {
      recoveryMsg += 'Consegue me dar uma ideia de quanto isso impacta em números? Tipo, quantos leads vocês perdem por semana, ou quanto tempo a equipe gasta?';
    } else if (qualificationNeeded.includes('timing/budget')) {
      recoveryMsg += 'Isso é algo que você quer resolver agora ou está mais para um planejamento futuro?';
    }
  } else {
    // Fallback genérico
    recoveryMsg = 'Me conta mais sobre a situação atual pra eu entender melhor como podemos ajudar.';
  }

  return [{
    json: {
      ai_message: recoveryMsg,
      slots_offered: false,
      conversation_state: 'normal',
      _debug: {
        reason: 'anum_too_low_for_meeting',
        anum_score: anumScore,
        qualification_needed: qualificationNeeded,
        fix_version: '4.5.1'
      }
    }
  }];
}

// ================================================================
// CENÁRIO 4: FRANK inventou slots (manter comportamento original)
// ================================================================
if (detect.frank_invented_slots) {
  const fallbackMsg = detect.clean_output +
    (detect.clean_output ? '\n\n' : '') +
    'A agenda tá bem cheia nos próximos dias. Quer falar direto com o Pasteur? WhatsApp: 5585999855443';
  return [{
    json: {
      ai_message: fallbackMsg,
      slots_offered: false,
      conversation_state: 'normal'
    }
  }];
}

// ================================================================
// CENÁRIO 5: Fallback padrão
// ================================================================
const fallback = detect.clean_output + '\n\nA agenda tá cheia. Fala com o Pasteur: 5585999855443';
return [{
  json: {
    ai_message: fallback,
    slots_offered: false,
    conversation_state: 'normal'
  }
}];

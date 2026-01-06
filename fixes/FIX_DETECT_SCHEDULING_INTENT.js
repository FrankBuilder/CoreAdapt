// ================================================================
// FIX: Detect: Scheduling Intent v4.5.1
//
// PROBLEMA: O código não buscava slots quando FRANK prometia ver a agenda
// mas can_offer_meeting era false (ANUM < 55).
//
// CORREÇÃO: Agora busca slots SEMPRE que FRANK mencionar agenda.
// O Inject: Dynamic Slots vai decidir o que fazer com base no ANUM.
// ================================================================

const aiOutput = $('CoreAdapt One AI Agent').item.json.output || '';
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
const inventedSlotsPattern = /(segunda|terça|terca|quarta|quinta|sexta|sábado|sabado|domingo)[^\n]*\d{1,2}[:/h]\d{2}/i;
const frankInventedSlots = inventedSlotsPattern.test(aiOutput);

// FIX v4.5.1: Detectar se FRANK está PROMETENDO ver a agenda
const frankPromisedToCheck = /verificando|deixa eu ver|vou ver|vou checar|estou verificando|vou verificar/i.test(aiOutput);

// REMOVER links externos E horários inventados
let cleanOutput = aiOutput
  .replace(/https?:\/\/[^\s]*cal\.com[^\s]*/gi, '')
  .replace(/https?:\/\/[^\s]*calendly[^\s]*/gi, '')
  .replace(/agenda\s*(aqui|pelo\s*link)[^\n]*/gi, '')
  .replace(/\n{3,}/g, '\n\n')
  .trim();

// Se FRANK inventou slots, remover a parte com horários inventados
if (frankInventedSlots) {
  cleanOutput = cleanOutput
    .replace(/\d+\.?\s*(segunda|terça|terca|quarta|quinta|sexta)[^\n]*\d{1,2}[:/h]\d{2}[^\n]*/gi, '')
    .replace(/[1️⃣2️⃣3️⃣][^\n]*\d{1,2}[:/h]\d{2}[^\n]*/gi, '')
    .replace(/(temos essas opções|deixa eu ver)[^\n]*:/gi, '')
    .replace(/qual funciona[^\n]*/gi, '')
    .replace(/responde 1, 2 ou 3[^\n]*/gi, '')
    .replace(/\n{2,}/g, '\n\n')
    .trim();
}

// ================================================================
// FIX v4.5.1: CORREÇÃO PRINCIPAL
// ================================================================
// Decisão: chamar Availability Flow?
//
// ANTES (BUGADO):
// const shouldFetchSlots = hasIntent && (canOffer.can_offer_meeting || frankInventedSlots);
//
// AGORA (CORRIGIDO):
// Buscar slots se:
// 1. can_offer_meeting é true (ANUM >= 55) OU
// 2. FRANK inventou slots (precisa corrigir) OU
// 3. FRANK prometeu ver a agenda (precisa entregar ou dar fallback)
// ================================================================

const shouldFetchSlots = hasIntent && (canOffer.can_offer_meeting || frankInventedSlots || frankPromisedToCheck);

return [{
  json: {
    original_output: aiOutput,
    clean_output: cleanOutput,
    ai_message: cleanOutput,
    has_scheduling_intent: hasIntent,
    frank_invented_slots: frankInventedSlots,
    frank_promised_to_check: frankPromisedToCheck, // NOVO
    should_fetch_slots: shouldFetchSlots,
    can_offer_meeting: canOffer.can_offer_meeting,
    anum_score: canOffer.total_score || canOffer.meeting_qualification?.scores?.total || 0,
    contact_id: contextData.contact_id,
    company_id: contextData.company_id,
    _debug: {
      patterns_matched: patterns.filter(p => lower.includes(p)),
      invented_slots_detected: frankInventedSlots,
      promised_to_check: frankPromisedToCheck,
      fix_version: '4.5.1'
    }
  }
}];

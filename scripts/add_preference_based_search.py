#!/usr/bin/env python3
"""
Script para adicionar busca de slots baseada em preferência do lead.
Quando o lead diz "tem quinta à tarde?", o sistema busca especificamente.

Mudanças:
1. Parse: Slot Selection - detectar preferências (dia, período)
2. Availability Flow - aceitar filtros
3. One Flow - novo path para busca filtrada
"""

import json
import uuid

# ============================================================================
# 1. ATUALIZAR AVAILABILITY FLOW - Aceitar filtros
# ============================================================================

print("📦 Carregando Availability Flow...")
with open('CoreAdapt Availability Flow _ v4.json', 'r', encoding='utf-8') as f:
    avail_flow = json.load(f)

# Atualizar "Prepare: Query Parameters" para incluir filtros
NEW_PREPARE_PARAMS_CODE = '''// Preparar parâmetros para busca de disponibilidade
const settings = $input.first().json;
const inputData = $('Webhook: Check Availability').first().json.body;

// NOVO: Filtros de preferência do lead
const filterWeekday = inputData.filter_weekday || null; // 'monday', 'tuesday', etc.
const filterPeriod = inputData.filter_period || null; // 'morning', 'afternoon', 'evening'
const isFilteredSearch = inputData.is_filtered_search === true;

// Calcular range de datas
const now = new Date();
const minNoticeMs = (settings.min_notice_hours || 2) * 60 * 60 * 1000;
const timeMin = new Date(now.getTime() + minNoticeMs);

// Se busca filtrada, expandir o range para garantir encontrar slots
const maxDays = isFilteredSearch ? Math.min((settings.max_days_ahead || 14) + 7, 21) : (settings.max_days_ahead || 14);
const timeMax = new Date(now.getTime() + (maxDays * 24 * 60 * 60 * 1000));

// Dias da semana permitidos (converter para índices)
const weekdayMap = {
  'sunday': 0, 'monday': 1, 'tuesday': 2, 'wednesday': 3,
  'thursday': 4, 'friday': 5, 'saturday': 6,
  // Portuguese aliases
  'domingo': 0, 'segunda': 1, 'terca': 2, 'terça': 2, 'quarta': 3,
  'quinta': 4, 'sexta': 5, 'sabado': 6, 'sábado': 6
};
let allowedDays = (settings.allowed_weekdays || ['monday','tuesday','wednesday','thursday','friday'])
  .map(d => weekdayMap[d.toLowerCase()]);

// Se tem filtro de dia, sobrepor
if (filterWeekday) {
  const filteredDay = weekdayMap[filterWeekday.toLowerCase()];
  if (filteredDay !== undefined) {
    // Só permite esse dia (se estiver nos dias permitidos originalmente)
    if (allowedDays.includes(filteredDay)) {
      allowedDays = [filteredDay];
    } else {
      // Dia não permitido nas configurações
      allowedDays = [];
    }
  }
}

// Horário comercial
const [startHour, startMin] = (settings.business_hours_start || '09:00:00').split(':').map(Number);
const [endHour, endMin] = (settings.business_hours_end || '18:00:00').split(':').map(Number);

// Aplicar filtro de período
let businessStart = { hour: startHour, min: startMin };
let businessEnd = { hour: endHour, min: endMin };

if (filterPeriod) {
  switch (filterPeriod.toLowerCase()) {
    case 'morning':
    case 'manha':
    case 'manhã':
      businessStart = { hour: Math.max(startHour, 8), min: startMin };
      businessEnd = { hour: Math.min(12, endHour), min: 0 };
      break;
    case 'afternoon':
    case 'tarde':
      businessStart = { hour: Math.max(12, startHour), min: 0 };
      businessEnd = { hour: Math.min(18, endHour), min: 0 };
      break;
    case 'evening':
    case 'noite':
      businessStart = { hour: Math.max(18, startHour), min: 0 };
      businessEnd = { hour: endHour, min: endMin };
      break;
  }
}

// Preferências de horário para scoring
let preferredSlots = settings.preferred_time_slots;
if (typeof preferredSlots === 'string') {
  try { preferredSlots = JSON.parse(preferredSlots); } catch(e) { preferredSlots = []; }
}

// Preferências de dia da semana
let preferredWeekdays = settings.preferred_weekdays;
if (typeof preferredWeekdays === 'string') {
  try { preferredWeekdays = JSON.parse(preferredWeekdays); } catch(e) { preferredWeekdays = {}; }
}

// Datas excluídas
const excludedDates = (settings.excluded_dates || []).map(d => {
  const date = new Date(d);
  return date.toISOString().split('T')[0];
});

return [{
  json: {
    settings: {
      calendar_provider: settings.calendar_provider,
      calendar_id: settings.calendar_id || 'primary',
      timezone: settings.timezone || 'America/Sao_Paulo',
      meeting_duration: settings.meeting_duration_minutes || 45,
      buffer_before: settings.buffer_before_minutes || 15,
      buffer_after: settings.buffer_after_minutes || 15,
      slots_to_offer: settings.slots_to_offer || 3,
      max_meetings_per_day: settings.max_meetings_per_day || 4,
      offer_template: settings.slot_offer_template
    },
    time_range: {
      min: timeMin.toISOString(),
      max: timeMax.toISOString()
    },
    business_hours: {
      start_hour: businessStart.hour,
      start_min: businessStart.min,
      end_hour: businessEnd.hour,
      end_min: businessEnd.min
    },
    allowed_weekdays: allowedDays,
    excluded_dates: excludedDates,
    scoring: {
      preferred_slots: preferredSlots || [],
      preferred_weekdays: preferredWeekdays || {}
    },
    contact: {
      id: inputData.contact_id,
      name: settings.contact_name,
      whatsapp: settings.contact_whatsapp,
      anum_score: settings.anum_score
    },
    company_id: inputData.company_id,
    // NOVO: Metadados de filtro
    filter_applied: {
      is_filtered: isFilteredSearch,
      weekday: filterWeekday,
      period: filterPeriod
    }
  }
}];'''

for node in avail_flow['nodes']:
    if node['name'] == 'Prepare: Query Parameters':
        node['parameters']['jsCode'] = NEW_PREPARE_PARAMS_CODE
        print("✅ Prepare: Query Parameters atualizado com suporte a filtros")
        break

# Atualizar "Generate: Available Slots" para mensagem contextual
NEW_GENERATE_SLOTS_CODE = '''// Gerar slots disponíveis considerando Google Calendar + DB
const { busy_blocks, params } = $input.first().json;

// Configurações
const {
  settings,
  time_range,
  business_hours,
  allowed_weekdays,
  excluded_dates,
  scoring,
  filter_applied
} = params;

const meetingDuration = settings.meeting_duration; // minutos
const bufferBefore = settings.buffer_before;
const bufferAfter = settings.buffer_after;

// Converter busy_blocks para objetos Date
const busyBlocks = busy_blocks.map(b => ({
  start: new Date(b.start),
  end: new Date(b.end)
}));

// Função para verificar se slot conflita com bloco ocupado
function isSlotAvailable(slotStart, slotEnd) {
  const bufferStart = new Date(slotStart.getTime() - bufferBefore * 60000);
  const bufferEnd = new Date(slotEnd.getTime() + bufferAfter * 60000);

  for (const block of busyBlocks) {
    // Verifica overlap
    if (bufferStart < block.end && bufferEnd > block.start) {
      return false;
    }
  }
  return true;
}

// Função para calcular score do slot
function calculateSlotScore(slotDate) {
  let score = 100; // Base score

  // Score por dia da semana
  const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const dayName = dayNames[slotDate.getDay()];
  const dayScore = (scoring.preferred_weekdays || {})[dayName] || 1;
  score += dayScore * 10;

  // Score por horário preferido
  const slotMinutes = slotDate.getHours() * 60 + slotDate.getMinutes();

  for (const pref of (scoring.preferred_slots || [])) {
    if (!pref.start || !pref.end) continue;
    const [prefStartH, prefStartM] = pref.start.split(':').map(Number);
    const [prefEndH, prefEndM] = pref.end.split(':').map(Number);
    const prefStartMin = prefStartH * 60 + prefStartM;
    const prefEndMin = prefEndH * 60 + prefEndM;

    if (slotMinutes >= prefStartMin && slotMinutes < prefEndMin) {
      const priorityScore = { high: 30, medium: 20, low: 10 };
      score += priorityScore[pref.priority] || 10;
      break;
    }
  }

  // Bonus para slots mais próximos (urgência)
  const daysFromNow = (slotDate.getTime() - Date.now()) / (24 * 60 * 60 * 1000);
  score += Math.max(0, 20 - daysFromNow * 2);

  return score;
}

// Gerar todos os slots possíveis
const availableSlots = [];
const startDate = new Date(time_range.min);
const endDate = new Date(time_range.max);

// Se não há dias permitidos (filtro inválido), retornar vazio
if (allowed_weekdays.length === 0) {
  return [{
    json: {
      success: false,
      slots_found: 0,
      slots: [],
      offer_message: filter_applied.is_filtered
        ? 'Infelizmente não temos disponibilidade nesse dia. Quer que eu veja outros horários?'
        : 'Não há horários disponíveis nos próximos dias',
      contact: params.contact,
      company_id: params.company_id,
      filter_applied: filter_applied,
      metadata: { reason: 'no_allowed_days' }
    }
  }];
}

// Iterar por cada dia
let currentDay = new Date(startDate);
currentDay.setHours(0, 0, 0, 0);

while (currentDay <= endDate) {
  const dayOfWeek = currentDay.getDay();
  const dateStr = currentDay.toISOString().split('T')[0];

  // Verificar se dia é permitido
  if (!allowed_weekdays.includes(dayOfWeek)) {
    currentDay.setDate(currentDay.getDate() + 1);
    continue;
  }

  // Verificar se data está excluída
  if (excluded_dates.includes(dateStr)) {
    currentDay.setDate(currentDay.getDate() + 1);
    continue;
  }

  // Gerar slots para o dia (a cada 30 minutos)
  const dayStart = new Date(currentDay);
  dayStart.setHours(business_hours.start_hour, business_hours.start_min, 0, 0);

  const dayEnd = new Date(currentDay);
  dayEnd.setHours(business_hours.end_hour, business_hours.end_min, 0, 0);
  // Subtrair duração da reunião do final
  dayEnd.setMinutes(dayEnd.getMinutes() - meetingDuration);

  let slotStart = new Date(dayStart);

  while (slotStart <= dayEnd && slotStart <= endDate) {
    // Pular se slot é antes do tempo mínimo
    if (slotStart <= startDate) {
      slotStart = new Date(slotStart.getTime() + 30 * 60000);
      continue;
    }

    const slotEnd = new Date(slotStart.getTime() + meetingDuration * 60000);

    if (isSlotAvailable(slotStart, slotEnd)) {
      const score = calculateSlotScore(slotStart);
      availableSlots.push({
        datetime: slotStart.toISOString(),
        end: slotEnd.toISOString(),
        score: score
      });
    }

    // Próximo slot (a cada 30 minutos)
    slotStart = new Date(slotStart.getTime() + 30 * 60000);
  }

  currentDay.setDate(currentDay.getDate() + 1);
}

// Ordenar por score (maior primeiro) e pegar os melhores
const sortedSlots = availableSlots
  .sort((a, b) => b.score - a.score)
  .slice(0, settings.slots_to_offer);

// Reordenar cronologicamente para apresentação
sortedSlots.sort((a, b) => new Date(a.datetime) - new Date(b.datetime));

// Formatar labels para exibição
const weekdaysPt = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
const monthsPt = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

const formattedSlots = sortedSlots.map((slot, idx) => {
  const dt = new Date(slot.datetime);
  // Ajustar para timezone São Paulo (UTC-3)
  const localDt = new Date(dt.toLocaleString('en-US', { timeZone: 'America/Sao_Paulo' }));

  const dayName = weekdaysPt[localDt.getDay()];
  const day = localDt.getDate();
  const month = monthsPt[localDt.getMonth()];
  const hour = localDt.getHours().toString().padStart(2, '0');
  const min = localDt.getMinutes().toString().padStart(2, '0');

  return {
    index: idx + 1,
    datetime: slot.datetime,
    end: slot.end,
    score: slot.score,
    label: `${dayName}, ${day}/${month} às ${hour}:${min}`
  };
});

// Construir mensagem de oferta - CONTEXTUAL se foi busca filtrada
let slotsText = '';
formattedSlots.forEach((slot, idx) => {
  const emoji = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣'][idx] || `${idx + 1}.`;
  slotsText += `${emoji} ${slot.label}\\n`;
});

let offerMessage = '';

if (filter_applied.is_filtered && formattedSlots.length > 0) {
  // Mensagem contextual para busca filtrada
  const periodPt = {
    'morning': 'de manhã',
    'manha': 'de manhã',
    'manhã': 'de manhã',
    'afternoon': 'à tarde',
    'tarde': 'à tarde',
    'evening': 'à noite',
    'noite': 'à noite'
  };
  const weekdayPt = {
    'monday': 'segunda',
    'segunda': 'segunda',
    'tuesday': 'terça',
    'terca': 'terça',
    'terça': 'terça',
    'wednesday': 'quarta',
    'quarta': 'quarta',
    'thursday': 'quinta',
    'quinta': 'quinta',
    'friday': 'sexta',
    'sexta': 'sexta'
  };

  let contextPhrase = 'Achei essas opções';
  if (filter_applied.weekday && filter_applied.period) {
    contextPhrase = `${weekdayPt[filter_applied.weekday] || filter_applied.weekday} ${periodPt[filter_applied.period] || filter_applied.period}? Tenho essas opções`;
  } else if (filter_applied.weekday) {
    contextPhrase = `${weekdayPt[filter_applied.weekday] || filter_applied.weekday}? Tenho essas opções`;
  } else if (filter_applied.period) {
    contextPhrase = `${periodPt[filter_applied.period] || filter_applied.period}? Tenho essas opções`;
  }

  offerMessage = `${contextPhrase}:\\n\\n${slotsText.trim()}\\n\\nQual funciona pra você?`;
} else if (formattedSlots.length > 0) {
  // Mensagem padrão
  offerMessage = (settings.offer_template || `Legal! Deixa eu ver a agenda do Francisco...\\n\\nTemos essas opções nos próximos dias:\\n{slots}\\nQual funciona melhor pra você? (responde 1, 2 ou 3)`)
    .replace('{slots}', slotsText.trim());
} else if (filter_applied.is_filtered) {
  // Busca filtrada sem resultados
  offerMessage = 'Não achei horários disponíveis com essa preferência. Quer que eu busque em outros dias/horários?';
} else {
  offerMessage = 'Puxa, a agenda está bem cheia nos próximos dias. Pode falar direto com o Pasteur: 5585999855443';
}

return [{
  json: {
    success: formattedSlots.length > 0,
    slots_found: formattedSlots.length,
    slots: formattedSlots,
    offer_message: offerMessage,
    contact: params.contact,
    company_id: params.company_id,
    settings: {
      timezone: settings.timezone,
      meeting_duration: meetingDuration,
      offer_expiration_hours: 24
    },
    filter_applied: filter_applied,
    metadata: {
      total_slots_evaluated: availableSlots.length,
      busy_blocks_count: busyBlocks.length,
      gcal_events: $input.first().json.gcal_events_count,
      db_meetings: $input.first().json.db_meetings_count,
      time_range: time_range
    }
  }
}];'''

for node in avail_flow['nodes']:
    if node['name'] == 'Generate: Available Slots':
        node['parameters']['jsCode'] = NEW_GENERATE_SLOTS_CODE
        print("✅ Generate: Available Slots atualizado com mensagens contextuais")
        break

# Atualizar versão
avail_flow['name'] = "CoreAdapt Availability Flow | v4.2 (Preference Filters)"
avail_flow['versionId'] = "avail-flow-v4.2-filters"

# Salvar
with open('CoreAdapt Availability Flow _ v4.json', 'w', encoding='utf-8') as f:
    json.dump(avail_flow, f, indent=2, ensure_ascii=False)
print("✅ Availability Flow salvo")

# ============================================================================
# 2. ATUALIZAR ONE FLOW - Parse: Slot Selection com detecção de preferências
# ============================================================================

print("\n📦 Carregando One Flow...")
with open('CoreAdapt One Flow _ v4.1_AUTONOMOUS.json', 'r', encoding='utf-8') as f:
    one_flow = json.load(f)

# Novo código do Parse: Slot Selection com detecção de preferências
NEW_PARSE_SLOT_CODE = '''const stateData = $('Fetch: Conversation State').first().json;
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

// ============================================================================
// NOVO: Detectar pedido de preferência (ex: "tem quinta à tarde?")
// ============================================================================

const preferencePatterns = {
  // Dias da semana
  weekdays: {
    'segunda': 'monday',
    'terça': 'tuesday',
    'terca': 'tuesday',
    'quarta': 'wednesday',
    'quinta': 'thursday',
    'sexta': 'friday',
    'sabado': 'saturday',
    'sábado': 'saturday',
    'domingo': 'sunday'
  },
  // Períodos
  periods: {
    'manhã': 'morning',
    'manha': 'morning',
    'de manhã': 'morning',
    'pela manhã': 'morning',
    'cedo': 'morning',
    'tarde': 'afternoon',
    'à tarde': 'afternoon',
    'de tarde': 'afternoon',
    'pela tarde': 'afternoon',
    'noite': 'evening',
    'à noite': 'evening',
    'de noite': 'evening'
  },
  // Indicadores de pergunta
  questionIndicators: ['tem', 'tem como', 'pode ser', 'consigo', 'dá pra', 'da pra', 'rola', 'tem horário', 'tem horario', 'alguma', 'outra opção', 'outra opcao', 'outro dia', 'outro horário', 'outro horario', 'semana que vem', 'proxima semana', 'próxima semana']
};

let preferenceRequest = {
  is_preference_request: false,
  weekday: null,
  period: null,
  raw_request: null
};

// Detectar se é uma pergunta/pedido de preferência
const isQuestionIndicator = preferencePatterns.questionIndicators.some(q => message.includes(q));

// Detectar dia da semana mencionado
let detectedWeekday = null;
for (const [ptDay, enDay] of Object.entries(preferencePatterns.weekdays)) {
  if (message.includes(ptDay)) {
    detectedWeekday = enDay;
    break;
  }
}

// Detectar período mencionado
let detectedPeriod = null;
for (const [ptPeriod, enPeriod] of Object.entries(preferencePatterns.periods)) {
  if (message.includes(ptPeriod)) {
    detectedPeriod = enPeriod;
    break;
  }
}

// É preferência se: tem indicador de pergunta OU se menciona dia/período sem selecionar slot dos oferecidos
if ((isQuestionIndicator && (detectedWeekday || detectedPeriod)) ||
    (detectedWeekday && !slots.some(s => new Date(s.datetime).getDay() ===
      ({'sunday':0,'monday':1,'tuesday':2,'wednesday':3,'thursday':4,'friday':5,'saturday':6})[detectedWeekday]))) {
  preferenceRequest = {
    is_preference_request: true,
    weekday: detectedWeekday,
    period: detectedPeriod,
    raw_request: message
  };
}

// ============================================================================
// Seleção direta de slot (lógica original)
// ============================================================================

// Numero direto
const directNum = message.match(/^\\s*([1-3])\\s*$/);
if (directNum && !preferenceRequest.is_preference_request) {
  const num = parseInt(directNum[1]);
  if (num <= slots.length) { selectedSlot = num; confidence = 1.0; method = 'direct_number'; }
}

// Ordinal
if (!selectedSlot && !preferenceRequest.is_preference_request) {
  const ordinals = {'primeir': 1, 'segund': 2, 'terceir': 3, 'um': 1, 'dois': 2, 'tres': 3};
  for (const [key, value] of Object.entries(ordinals)) {
    if (message.includes(key) && value <= slots.length) { selectedSlot = value; confidence = 0.9; method = 'ordinal'; break; }
  }
}

// Dia da semana - SÓ se o dia corresponde a um slot oferecido
if (!selectedSlot && detectedWeekday && !preferenceRequest.is_preference_request) {
  const dayNum = {'sunday':0,'monday':1,'tuesday':2,'wednesday':3,'thursday':4,'friday':5,'saturday':6}[detectedWeekday];
  for (const slot of slots) {
    if (new Date(slot.datetime).getDay() === dayNum) {
      selectedSlot = slot.index;
      confidence = 0.85;
      method = 'weekday';
      break;
    }
  }
}

// Generico
if (!selectedSlot && !preferenceRequest.is_preference_request) {
  const generic = ['pode ser', 'qualquer', 'tanto faz', 'o primeiro', 'mais cedo'];
  if (generic.some(g => message.includes(g)) && !detectedWeekday && !detectedPeriod) {
    selectedSlot = 1;
    confidence = 0.75;
    method = 'generic';
  }
}

// Confirmacao
let isConfirmation = false;
if (stateData.conversation_state === 'confirming_slot' && !preferenceRequest.is_preference_request) {
  const confirms = ['sim', 'isso', 'pode', 'confirma', 'certo', 'ok', 'beleza'];
  if (confirms.some(c => message.includes(c))) {
    selectedSlot = stateData.state_data?.pending_slot || 1;
    confidence = 1.0; method = 'confirmation'; isConfirmation = true;
  }
}

// Recusa explícita
const refusals = ['nao quero', 'não quero', 'nenhum desses', 'nenhuma dessas', 'cancelar', 'deixa pra lá', 'deixa pra la'];
const isRefusal = refusals.some(r => message.includes(r)) && !selectedSlot;

return [{
  json: {
    parsed: selectedSlot !== null,
    selected_slot: selectedSlot,
    confidence: confidence,
    method: method,
    is_refusal: isRefusal,
    is_confirmation: isConfirmation,
    needs_clarification: !selectedSlot && !isRefusal && !preferenceRequest.is_preference_request,
    // NOVO: Dados de preferência
    is_preference_request: preferenceRequest.is_preference_request,
    preference_weekday: preferenceRequest.weekday,
    preference_period: preferenceRequest.period,
    preference_raw: preferenceRequest.raw_request,
    // Dados originais
    offer_id: stateData.offer_id,
    contact_id: contextData.contact_id,
    company_id: contextData.company_id,
    slots: slots,
    selected_datetime: selectedSlot ? slots[selectedSlot - 1]?.datetime : null,
    selected_label: selectedSlot ? slots[selectedSlot - 1]?.label : null,
    parsing_attempts: (stateData.parsing_attempts || 0) + 1
  }
}];'''

# Atualizar node Parse: Slot Selection
for node in one_flow['nodes']:
    if node['name'] == 'Parse: Slot Selection':
        node['parameters']['jsCode'] = NEW_PARSE_SLOT_CODE
        print("✅ Parse: Slot Selection atualizado com detecção de preferências")
        break

# ============================================================================
# 3. ADICIONAR NODES para path de busca filtrada
# ============================================================================

# Node: Check: Is Preference Request
check_preference_node = {
    "parameters": {
        "conditions": {
            "options": {
                "caseSensitive": True,
                "leftValue": "",
                "typeValidation": "strict",
                "version": 2
            },
            "conditions": [
                {
                    "id": str(uuid.uuid4()),
                    "leftValue": "={{ $json.is_preference_request === true }}",
                    "rightValue": "",
                    "operator": {
                        "type": "boolean",
                        "operation": "true",
                        "singleValue": True
                    }
                }
            ],
            "combinator": "and"
        },
        "options": {}
    },
    "id": str(uuid.uuid4()),
    "name": "Check: Is Preference Request",
    "type": "n8n-nodes-base.if",
    "typeVersion": 2.2,
    "position": [-1400, -100]
}

# Node: Call Availability (Filtered)
call_filtered_node = {
    "parameters": {
        "method": "POST",
        "url": "={{ $env.N8N_WEBHOOK_URL || 'https://n8n.coreadapt.cloud' }}/webhook/availability-check",
        "sendHeaders": True,
        "headerParameters": {
            "parameters": [
                {
                    "name": "Content-Type",
                    "value": "application/json"
                }
            ]
        },
        "sendBody": True,
        "specifyBody": "json",
        "jsonBody": """={{ JSON.stringify({
  contact_id: $json.contact_id,
  company_id: $json.company_id,
  is_filtered_search: true,
  filter_weekday: $json.preference_weekday || null,
  filter_period: $json.preference_period || null
}) }}""",
        "options": {
            "timeout": 30000
        }
    },
    "id": str(uuid.uuid4()),
    "name": "Call: Availability Filtered",
    "type": "n8n-nodes-base.httpRequest",
    "typeVersion": 4.2,
    "position": [-1176, -100],
    "retryOnFail": True,
    "maxTries": 2
}

# Node: Handle Filtered Result
handle_filtered_node = {
    "parameters": {
        "jsCode": """const result = $input.first().json;
const parseData = $('Parse: Slot Selection').first().json;

if (result.success && result.slots_found > 0) {
  // Novos slots encontrados - enviar oferta
  return [{
    json: {
      ai_message: result.offer_message,
      new_slots: true,
      offer_id: result.offer_id,
      slots_found: result.slots_found
    }
  }];
} else {
  // Sem slots - perguntar se quer outras opções
  return [{
    json: {
      ai_message: result.offer_message || 'Não achei horários com essa preferência. Quer que eu busque outros horários?',
      new_slots: false,
      no_results_for_preference: true
    }
  }];
}"""
    },
    "id": str(uuid.uuid4()),
    "name": "Handle: Filtered Result",
    "type": "n8n-nodes-base.code",
    "typeVersion": 2,
    "position": [-952, -100]
}

# Adicionar nodes
one_flow['nodes'].append(check_preference_node)
one_flow['nodes'].append(call_filtered_node)
one_flow['nodes'].append(handle_filtered_node)
print("✅ Nodes de busca filtrada adicionados")

# ============================================================================
# 4. ATUALIZAR CONEXÕES
# ============================================================================

# Parse: Slot Selection -> Check: Is Preference Request (primeiro)
# Se é preferência -> Call: Availability Filtered
# Se não -> Check: High Confidence (lógica original)

one_flow['connections']['Parse: Slot Selection'] = {
    "main": [
        [{"node": "Check: Is Preference Request", "type": "main", "index": 0}]
    ]
}

one_flow['connections']['Check: Is Preference Request'] = {
    "main": [
        # True (é preferência) -> busca filtrada
        [{"node": "Call: Availability Filtered", "type": "main", "index": 0}],
        # False -> lógica original
        [{"node": "Check: High Confidence", "type": "main", "index": 0}]
    ]
}

one_flow['connections']['Call: Availability Filtered'] = {
    "main": [
        [{"node": "Handle: Filtered Result", "type": "main", "index": 0}]
    ]
}

one_flow['connections']['Handle: Filtered Result'] = {
    "main": [
        [{"node": "Merge: Slot Path", "type": "main", "index": 0}]
    ]
}

print("✅ Conexões atualizadas")

# Atualizar versão
one_flow['name'] = "CoreAdapt One Flow | v4.2 (Preference Search)"
one_flow['versionId'] = "one-flow-v4.2-preference"

# Salvar
with open('CoreAdapt One Flow _ v4.1_AUTONOMOUS.json', 'w', encoding='utf-8') as f:
    json.dump(one_flow, f, indent=2, ensure_ascii=False)
print("✅ One Flow salvo")

# ============================================================================
# RESUMO
# ============================================================================

print("\n" + "="*70)
print("✅ BUSCA POR PREFERÊNCIA IMPLEMENTADA!")
print("="*70)
print("""
Mudanças realizadas:

📄 CoreAdapt Availability Flow _ v4.json (v4.2)
   - Prepare: Query Parameters aceita filter_weekday e filter_period
   - Generate: Available Slots gera mensagens contextuais
   - Suporta filtros de dia da semana e período (manhã/tarde/noite)

📄 CoreAdapt One Flow _ v4.1_AUTONOMOUS.json (v4.2)
   - Parse: Slot Selection detecta preferências do lead
   - Novo node: Check: Is Preference Request
   - Novo node: Call: Availability Filtered
   - Novo node: Handle: Filtered Result
   - Conexões atualizadas para novo path

EXEMPLOS DE FUNCIONAMENTO:

Lead: "tem quinta à tarde?"
→ Sistema detecta: weekday=thursday, period=afternoon
→ Chama Availability Flow com filtros
→ Retorna: "Quinta à tarde? Tenho essas opções:
   1️⃣ Quinta, 09/jan às 14:00
   2️⃣ Quinta, 09/jan às 15:30
   3️⃣ Quinta, 16/jan às 14:30
   Qual funciona pra você?"

Lead: "prefiro de manhã"
→ Sistema detecta: period=morning
→ Busca slots só de manhã

Lead: "tem como segunda?"
→ Sistema detecta: weekday=monday
→ Busca slots só de segunda

PRÓXIMO PASSO:
→ Re-importar os dois fluxos no n8n:
   1. CoreAdapt Availability Flow _ v4.json
   2. CoreAdapt One Flow _ v4.1_AUTONOMOUS.json
""")

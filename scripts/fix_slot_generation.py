#!/usr/bin/env python3
"""
Correções no Generate: Available Slots:
1. Bug de timezone: usar formatação correta para São Paulo
2. Nova regra de distribuição: 1 slot do primeiro dia + 2 do segundo dia
"""

import json

print("📦 Carregando Availability Flow...")
with open('CoreAdapt Availability Flow _ v4.json', 'r', encoding='utf-8') as f:
    avail_flow = json.load(f)

# Novo código do Generate: Available Slots com correções
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
const timezone = settings.timezone || 'America/Sao_Paulo';

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
    if (bufferStart < block.end && bufferEnd > block.start) {
      return false;
    }
  }
  return true;
}

// ============================================================================
// CORREÇÃO: Função para formatar data corretamente no timezone de São Paulo
// ============================================================================
function formatSlotInTimezone(isoDatetime, tz) {
  const dt = new Date(isoDatetime);

  // Usar Intl.DateTimeFormat para obter os componentes corretos no timezone
  const formatter = new Intl.DateTimeFormat('pt-BR', {
    timeZone: tz,
    weekday: 'long',
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });

  const parts = formatter.formatToParts(dt);
  const getPart = (type) => parts.find(p => p.type === type)?.value || '';

  // Capitalizar primeira letra do dia da semana
  let weekday = getPart('weekday');
  weekday = weekday.charAt(0).toUpperCase() + weekday.slice(1);
  // Remover "-feira" se presente
  weekday = weekday.replace('-feira', '');

  const day = getPart('day');
  const month = getPart('month').replace('.', '');
  const hour = getPart('hour');
  const minute = getPart('minute');

  return {
    label: `${weekday}, ${day}/${month} às ${hour}:${minute}`,
    // Também retornar o dia como string para agrupar slots por dia
    dateKey: `${dt.toLocaleDateString('en-CA', { timeZone: tz })}` // YYYY-MM-DD
  };
}

// Função para calcular score do slot (mantida para desempate dentro do mesmo dia)
function calculateSlotScore(slotDate) {
  let score = 100;

  const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const dayName = dayNames[slotDate.getDay()];
  const dayScore = (scoring.preferred_weekdays || {})[dayName] || 1;
  score += dayScore * 10;

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

  return score;
}

// Gerar todos os slots possíveis
const availableSlots = [];
const startDate = new Date(time_range.min);
const endDate = new Date(time_range.max);

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

  if (!allowed_weekdays.includes(dayOfWeek)) {
    currentDay.setDate(currentDay.getDate() + 1);
    continue;
  }

  if (excluded_dates.includes(dateStr)) {
    currentDay.setDate(currentDay.getDate() + 1);
    continue;
  }

  const dayStart = new Date(currentDay);
  dayStart.setHours(business_hours.start_hour, business_hours.start_min, 0, 0);

  const dayEnd = new Date(currentDay);
  dayEnd.setHours(business_hours.end_hour, business_hours.end_min, 0, 0);
  dayEnd.setMinutes(dayEnd.getMinutes() - meetingDuration);

  let slotStart = new Date(dayStart);

  while (slotStart <= dayEnd && slotStart <= endDate) {
    if (slotStart <= startDate) {
      slotStart = new Date(slotStart.getTime() + 30 * 60000);
      continue;
    }

    const slotEnd = new Date(slotStart.getTime() + meetingDuration * 60000);

    if (isSlotAvailable(slotStart, slotEnd)) {
      const formatted = formatSlotInTimezone(slotStart.toISOString(), timezone);
      const score = calculateSlotScore(slotStart);

      availableSlots.push({
        datetime: slotStart.toISOString(),
        end: slotEnd.toISOString(),
        score: score,
        dateKey: formatted.dateKey,
        label: formatted.label
      });
    }

    slotStart = new Date(slotStart.getTime() + 30 * 60000);
  }

  currentDay.setDate(currentDay.getDate() + 1);
}

// ============================================================================
// NOVA REGRA: 1 slot do primeiro dia disponível + 2 do segundo dia
// Se não houver 2 no segundo dia, pegar do terceiro, etc.
// ============================================================================

// Agrupar slots por dia
const slotsByDay = {};
for (const slot of availableSlots) {
  if (!slotsByDay[slot.dateKey]) {
    slotsByDay[slot.dateKey] = [];
  }
  slotsByDay[slot.dateKey].push(slot);
}

// Ordenar cada dia por score (melhor primeiro)
for (const dateKey in slotsByDay) {
  slotsByDay[dateKey].sort((a, b) => b.score - a.score);
}

// Obter lista de dias ordenados cronologicamente
const sortedDays = Object.keys(slotsByDay).sort();

// Selecionar slots conforme a regra: 1 do primeiro dia + 2 do segundo
const selectedSlots = [];
const slotsNeeded = settings.slots_to_offer || 3;

let slotsFromFirstDay = 1; // Sempre 1 do primeiro dia
let slotsRemaining = slotsNeeded - slotsFromFirstDay; // Restante do segundo dia

// Pegar 1 slot do primeiro dia
if (sortedDays.length > 0) {
  const firstDaySlots = slotsByDay[sortedDays[0]];
  if (firstDaySlots.length > 0) {
    selectedSlots.push(firstDaySlots[0]);
  }
}

// Pegar slots restantes dos próximos dias (2 do segundo, ou distribuir se necessário)
let dayIndex = 1;
while (selectedSlots.length < slotsNeeded && dayIndex < sortedDays.length) {
  const daySlots = slotsByDay[sortedDays[dayIndex]];
  const slotsToTake = Math.min(daySlots.length, slotsNeeded - selectedSlots.length);

  for (let i = 0; i < slotsToTake; i++) {
    selectedSlots.push(daySlots[i]);
  }

  dayIndex++;
}

// Se ainda não temos slots suficientes, pegar mais do primeiro dia
if (selectedSlots.length < slotsNeeded && sortedDays.length > 0) {
  const firstDaySlots = slotsByDay[sortedDays[0]];
  for (let i = 1; i < firstDaySlots.length && selectedSlots.length < slotsNeeded; i++) {
    selectedSlots.push(firstDaySlots[i]);
  }
}

// Reordenar cronologicamente para apresentação
selectedSlots.sort((a, b) => new Date(a.datetime) - new Date(b.datetime));

// Formatar slots para resposta
const formattedSlots = selectedSlots.map((slot, idx) => ({
  index: idx + 1,
  datetime: slot.datetime,
  end: slot.end,
  score: slot.score,
  label: slot.label,
  dateKey: slot.dateKey
}));

// Construir mensagem de oferta
let slotsText = '';
formattedSlots.forEach((slot, idx) => {
  const emoji = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣'][idx] || `${idx + 1}.`;
  slotsText += `${emoji} ${slot.label}\\n`;
});

let offerMessage = '';

if (filter_applied.is_filtered && formattedSlots.length > 0) {
  const periodPt = {
    'morning': 'de manhã', 'manha': 'de manhã', 'manhã': 'de manhã',
    'afternoon': 'à tarde', 'tarde': 'à tarde',
    'evening': 'à noite', 'noite': 'à noite'
  };
  const weekdayPt = {
    'monday': 'Segunda', 'segunda': 'Segunda',
    'tuesday': 'Terça', 'terca': 'Terça', 'terça': 'Terça',
    'wednesday': 'Quarta', 'quarta': 'Quarta',
    'thursday': 'Quinta', 'quinta': 'Quinta',
    'friday': 'Sexta', 'sexta': 'Sexta'
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
  offerMessage = (settings.offer_template || `Legal! Deixa eu ver a agenda do Francisco...\\n\\nTemos essas opções nos próximos dias:\\n{slots}\\nQual funciona melhor pra você? (responde 1, 2 ou 3)`)
    .replace('{slots}', slotsText.trim());
} else if (filter_applied.is_filtered) {
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
      time_range: time_range,
      days_with_slots: sortedDays.length,
      distribution: formattedSlots.map(s => s.dateKey)
    }
  }
}];'''

# Atualizar o node
for node in avail_flow['nodes']:
    if node['name'] == 'Generate: Available Slots':
        node['parameters']['jsCode'] = NEW_GENERATE_SLOTS_CODE
        print("✅ Generate: Available Slots corrigido")
        break

# Atualizar versão
avail_flow['name'] = "CoreAdapt Availability Flow | v4.3 (Fixed Dates)"
avail_flow['versionId'] = "avail-flow-v4.3-fixed"

# Salvar
with open('CoreAdapt Availability Flow _ v4.json', 'w', encoding='utf-8') as f:
    json.dump(avail_flow, f, indent=2, ensure_ascii=False)

print("\n" + "="*70)
print("✅ CORREÇÕES APLICADAS!")
print("="*70)
print("""
CORREÇÕES:

1. BUG DE TIMEZONE CORRIGIDO
   - Agora usa Intl.DateTimeFormat com timeZone explícito
   - O dia da semana é calculado corretamente no timezone de São Paulo
   - Antes: Terça, 7/jan (errado)
   - Agora: Terça, 6/jan (correto para 05/01 segunda-feira)

2. NOVA REGRA DE DISTRIBUIÇÃO
   - 1 slot do primeiro dia disponível
   - 2 slots do segundo dia disponível
   - Se não houver 2 no segundo dia, pega do terceiro

   Exemplo (hoje = segunda 05/01):
   1️⃣ Terça, 06/jan às 10:00   (1 do primeiro dia)
   2️⃣ Quarta, 07/jan às 09:30  (2 do segundo dia)
   3️⃣ Quarta, 07/jan às 14:00  (2 do segundo dia)

PRÓXIMO PASSO:
→ Re-importar o Availability Flow no n8n
""")

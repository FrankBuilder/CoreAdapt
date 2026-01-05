#!/usr/bin/env python3
"""
Script para atualizar o Sentinel Flow com contexto de agendamento autônomo.
Adiciona conversation_state e info de slot offers ao contexto do follow-up.
"""

import json
import re

# Carregar Sentinel Flow
with open('CoreAdapt Sentinel Flow _ v4.json', 'r', encoding='utf-8') as f:
    flow = json.load(f)

# ============================================================================
# 1. ATUALIZAR QUERY PRINCIPAL - Adicionar conversation_state e slot offers
# ============================================================================

NEW_QUERY = """SELECT DISTINCT ON (e.contact_id)
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
  ce.last_interaction_at,

  ls.total_score AS anum_score,
  CASE WHEN ls.total_score IS NULL THEN FALSE ELSE TRUE END AS has_been_analyzed,
  COALESCE(ls.qualification_stage, 'inicial') AS qualification_stage,

  co.evolution_api_url,
  co.evolution_instance,
  co.evolution_api_key,

  fs.wait_hours,
  fs.wait_minutes,

  -- NOVO: Estado da conversa e info de slot offers
  ch.conversation_state,
  ch.pending_offer_id,
  po.slot_1_label,
  po.slot_2_label,
  po.slot_3_label,
  po.expires_at AS offer_expires_at,
  CASE
    WHEN po.id IS NOT NULL AND po.expires_at > NOW() AND po.status = 'pending'
    THEN true ELSE false
  END AS has_active_slot_offer,

  -- Último contato: maior entre last_interaction_at e último step enviado
  GREATEST(
    COALESCE(ce.last_interaction_at, e.created_at),
    COALESCE(fc.last_step_sent_at, e.created_at)
  ) AS last_contact_at

FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
LEFT JOIN corev4_contact_extras ce ON ce.contact_id = e.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
INNER JOIN corev4_companies co ON co.id = e.company_id
LEFT JOIN corev4_followup_campaigns fc ON fc.id = e.campaign_id
LEFT JOIN corev4_followup_steps fs ON fs.config_id = fc.config_id AND fs.step_number = e.step
-- NOVO: Joins para conversation_state e slot offers
LEFT JOIN corev4_chats ch ON ch.contact_id = e.contact_id AND ch.company_id = e.company_id
LEFT JOIN corev4_pending_slot_offers po ON po.id = ch.pending_offer_id

WHERE e.executed = false
  AND e.should_send = true
  AND c.opt_out = false
  -- Tempo de silêncio passou desde o ÚLTIMO CONTATO (interação do lead OU envio de followup)
  AND NOW() >= GREATEST(
    COALESCE(ce.last_interaction_at, e.created_at),
    COALESCE(fc.last_step_sent_at, e.created_at)
  ) + (fs.wait_hours || ' hours')::interval + (COALESCE(fs.wait_minutes, 0) || ' minutes')::interval
  AND (
    ls.total_score IS NULL
    OR
    ls.total_score < 70
  )
  -- Dias úteis: Segunda(1) a Sexta(5) - horário de São Paulo
  AND EXTRACT(DOW FROM NOW() AT TIME ZONE 'America/Sao_Paulo') BETWEEN 1 AND 5
  -- Horário comercial: 8h às 20h - horário de São Paulo
  AND EXTRACT(HOUR FROM NOW() AT TIME ZONE 'America/Sao_Paulo') BETWEEN 8 AND 19

-- DISTINCT ON requer que a primeira coluna do ORDER BY seja a mesma
ORDER BY e.contact_id, e.step ASC
LIMIT 50;"""

# Encontrar e atualizar o node "Fetch: Pending Followups"
for node in flow['nodes']:
    if node['name'] == 'Fetch: Pending Followups':
        node['parameters']['query'] = NEW_QUERY
        print("✅ Query principal atualizada")
        break

# ============================================================================
# 2. ATUALIZAR "Prepare: Followup Context" - Adicionar scheduling context
# ============================================================================

NEW_PREPARE_CODE = '''const lead = $('Loop: Over Followups').item.json;
const chat_history = $('Fetch: Chat History').all();
const previous_followups = $('Fetch: Previous Followups').all();
const session_id = $('Fetch: Session UUID').first().json.session_uuid;

const step = lead.step;
const total_steps = lead.total_steps;

// Extrair apenas mensagens do lead (human)
const lead_messages = chat_history
  .filter(m => m.json && m.json.role === 'human' && m.json.message && m.json.message.trim() !== '')
  .slice(0, 10)
  .map(m => m.json.message);

// Chat history já vem DESC, não precisa reverse()
const recent_messages_array = chat_history
  .filter(m => m.json && m.json.message && m.json.message.trim() !== '')
  .slice(0, 15)
  .reverse()
  .map(m => {
    const role = m.json.role === 'human' ? 'Lead' : 'Frank';
    return `${role}: ${m.json.message}`;
  });

const recent_messages = recent_messages_array.join('\\n\\n');
const conversation_full = recent_messages;

const last_lead_message = lead_messages[0] || null;

const followup_history = previous_followups
  .map(f => `Step ${f.json.step}: ${f.json.generated_message}`)
  .join('\\n') || 'Nenhum followup anterior';

let step_context = '';

if (step === 1) {
  step_context = 'STEP 1 de ' + total_steps + ': REENGAJAMENTO SUAVE\\n- Primeira tentativa após ~1 hora de inatividade\\n- Tom: leve, útil, sem pressão\\n- Objetivo: retomar conversa naturalmente';
} else if (step === 2) {
  step_context = 'STEP 2 de ' + total_steps + ': AGREGAR VALOR\\n- Segunda tentativa após ~1 dia\\n- Tom: educativo, consultivo\\n- Objetivo: demonstrar expertise e valor';
} else if (step === 3) {
  step_context = 'STEP 3 de ' + total_steps + ': URGÊNCIA SUTIL\\n- Terceira tentativa após ~3 dias\\n- Tom: profissional com senso de oportunidade\\n- Objetivo: criar timing adequado sem ser pushy';
} else if (step === 4) {
  step_context = 'STEP 4 de ' + total_steps + ': ÚLTIMA CHANCE\\n- Quarta tentativa após ~6 dias\\n- Tom: respeitoso e direto\\n- Objetivo: comunicar closure respeitoso';
} else if (step === 5) {
  step_context = 'STEP 5 de ' + total_steps + ': DESPEDIDA\\n- Última mensagem após ~13 dias\\n- Tom: gracioso, sem ressentimento\\n- Objetivo: encerrar com classe e plantar semente';
}

const lead_responded = chat_history.some(m => m.json && m.json.role === 'human');

// NOVO: Contexto de agendamento autônomo
const conversation_state = lead.conversation_state || 'normal';
const has_active_slot_offer = lead.has_active_slot_offer === true;

let scheduling_context = '';
if (has_active_slot_offer && conversation_state === 'awaiting_slot_selection') {
  const slots = [lead.slot_1_label, lead.slot_2_label, lead.slot_3_label].filter(s => s);
  scheduling_context = `⚠️ CONTEXTO ESPECIAL: Lead recebeu oferta de horários e NÃO respondeu.
Horários oferecidos:
${slots.map((s, i) => `${i+1}. ${s}`).join('\\n')}

INSTRUÇÃO: Seu follow-up deve LEMBRAR dos horários oferecidos, não ignorá-los.
Exemplo: "Oi [Nome]! Vi que te mandei algumas opções de horário... algum deles funciona pra você? Se nenhum der certo, me fala que busco outros!"`;
} else if (conversation_state === 'confirming_slot') {
  scheduling_context = `⚠️ CONTEXTO ESPECIAL: Lead está CONFIRMANDO um horário selecionado.
INSTRUÇÃO: Pergunte gentilmente se ele conseguiu confirmar ou se precisa de ajuda.`;
}

return {
  execution_id: lead.execution_id,
  campaign_id: lead.campaign_id,
  contact_id: lead.contact_id,
  company_id: lead.company_id,
  contact_name: lead.contact_name || 'Cliente',
  phone_number: lead.phone_number,
  whatsapp: lead.whatsapp,
  evolution_api_url: lead.evolution_api_url,
  evolution_instance: lead.evolution_instance,
  evolution_api_key: lead.evolution_api_key,
  step: step,
  total_steps: total_steps,
  anum_score: lead.anum_score ?? null,
  has_been_analyzed: lead.has_been_analyzed ?? false,
  qualification_stage: lead.qualification_stage || 'inicial',
  session_id: session_id,
  step_context: step_context,
  conversation_full: conversation_full,
  recent_messages: recent_messages,
  last_lead_message: last_lead_message,
  lead_message_count: lead_messages.length,
  followup_history: followup_history,
  lead_responded: lead_responded,
  // NOVO: Campos de agendamento
  conversation_state: conversation_state,
  has_active_slot_offer: has_active_slot_offer,
  scheduling_context: scheduling_context
};'''

# Encontrar e atualizar o node "Prepare: Followup Context"
for node in flow['nodes']:
    if node['name'] == 'Prepare: Followup Context':
        node['parameters']['jsCode'] = NEW_PREPARE_CODE
        print("✅ Prepare: Followup Context atualizado")
        break

# ============================================================================
# 3. ATUALIZAR PROMPT DO AI AGENT - Incluir scheduling_context
# ============================================================================

# O prompt text precisa incluir o scheduling_context
NEW_PROMPT_TEXT = '''=# CONTEXT

## STEP STRATEGY
{{ $json.step_context }}

## LEAD INFO
**Name:** {{ $json.contact_name }}
**ANUM Score:** {{ $json.anum_score || 'Not analyzed yet' }}
**Stage:** {{ $json.qualification_stage || 'initial' }}
**Responded before:** {{ $json.lead_responded ? 'Yes' : 'No' }}

## SCHEDULING STATUS
{{ $json.scheduling_context || 'Normal flow - no pending scheduling' }}

## RECENT CONVERSATION
{{ $json.recent_messages || 'No previous conversation' }}

## PREVIOUS FOLLOW-UPS SENT
{{ $json.followup_history || 'None' }}

---

# TASK

Generate ONE follow-up message for this step.

**Checklist:**
1. ✅ Check scheduling_context FIRST - if lead has pending slot offer, reference it!
2. ✅ Read recent_messages - what was discussed?
3. ✅ Identify their main pain/challenge
4. ✅ Check ANUM score - should I mention CoreAdapt? Offer Implementation?
5. ✅ Check previous follow-ups - what did I already try?
6. ✅ Deliver value BEFORE asking anything

**ANUM-based offers:**
- ANUM ≥70 + Step ≥3: Offer Implementation (R$ 997, 7 days ready, 30-day guarantee)
- ANUM 55-69 + Step ≥3: Offer Mesa de Clareza™ (FREE, 45min, discovery)
- ANUM <55: Continue discovery or graceful exit

**If lead has active slot offer (scheduling_context shows slots):**
→ MUST reference the slots offered
→ Ask which one works or offer to find new ones
→ Do NOT send generic follow-up ignoring the scheduling context

**If lead never responded:**
Empathy + curiosity. Offer value without pressure.

**If lead responded before:**
Reference specific conversation topic. Show you remember.

**Structure:**
1. Reference their context (name + pain/topic discussed OR pending slots)
2. Value bomb (insight, ROI calculation, case study) OR slot reminder
3. Low-pressure CTA

---

# OUTPUT

ONLY the message text in Portuguese, ready to send.
No quotes, no explanations.
2-4 lines maximum.'''

# Encontrar e atualizar o node "CoreAdapt Sentinel AI Agent"
for node in flow['nodes']:
    if node['name'] == 'CoreAdapt Sentinel AI Agent':
        node['parameters']['text'] = NEW_PROMPT_TEXT

        # Também atualizar o systemMessage para incluir instrução sobre scheduling
        current_system = node['parameters']['options'].get('systemMessage', '')

        # Adicionar seção sobre scheduling context se não existir
        if 'SCHEDULING CONTEXT' not in current_system:
            scheduling_section = '''

# SCHEDULING CONTEXT HANDLING

When scheduling_context is NOT empty, the lead has received time slot offers and went silent.

**CRITICAL:** You MUST reference the pending slots in your follow-up. Do NOT ignore them.

Examples of good follow-ups when slots were offered:
- "Oi [Nome]! Vi que te mandei alguns horários ontem... algum funciona pra você? Se não, me fala que busco outros!"
- "[Nome], ainda conseguimos aquele horário de terça às 10h se quiser confirmar. Ou prefere outra opção?"
- "E aí [Nome], conseguiu ver os horários que mandei? Qualquer coisa me avisa que a gente ajusta!"

Examples of BAD follow-ups (DO NOT DO THIS when slots are pending):
- "Ainda está interessado no CoreAdapt?" (ignores the slots)
- "Posso te ajudar com mais alguma coisa?" (generic, ignores context)
- "Que tal agendarmos uma Mesa de Clareza?" (slots already offered!)

'''
            # Inserir antes de "# REQUIREMENTS"
            if '# REQUIREMENTS' in current_system:
                current_system = current_system.replace('# REQUIREMENTS', scheduling_section + '# REQUIREMENTS')
            else:
                current_system += scheduling_section

            node['parameters']['options']['systemMessage'] = current_system

        print("✅ CoreAdapt Sentinel AI Agent prompt atualizado")
        break

# ============================================================================
# 4. SALVAR FLUXO ATUALIZADO
# ============================================================================

# Atualizar nome e versão
flow['name'] = "CoreAdapt Sentinel Flow | v4.1 (Scheduling Context)"
flow['versionId'] = "sentinel-v4.1-scheduling"

# Salvar
with open('CoreAdapt Sentinel Flow _ v4.json', 'w', encoding='utf-8') as f:
    json.dump(flow, f, indent=2, ensure_ascii=False)

print("\n✅ Sentinel Flow atualizado com sucesso!")
print("Mudanças:")
print("  - Query inclui conversation_state e slot offers")
print("  - Prepare: Followup Context inclui scheduling_context")
print("  - AI Agent prompt referencia scheduling_context")
print("\nPróximo passo: Re-importar no n8n")

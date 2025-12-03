-- ============================================================================
-- DASHBOARD DE OPERAÇÕES - Metabase
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Este dashboard é focado na operação diária do time de vendas,
-- mostrando campanhas ativas, reuniões e leads prioritários.
-- ============================================================================

-- ============================================================================
-- 2.1 KPI: CAMPANHAS ATIVAS
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Total de campanhas de follow-up em execução

SELECT COUNT(*) AS campanhas_ativas
FROM corev4_followup_campaigns
WHERE company_id = 1
  AND status = 'active'
  AND should_continue = true;


-- ============================================================================
-- 2.2 KPI: FOLLOW-UPS PENDENTES HOJE
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Steps de follow-up agendados para hoje

SELECT COUNT(*) AS followups_pendentes_hoje
FROM corev4_followup_executions
WHERE company_id = 1
  AND executed = false
  AND should_send = true
  AND scheduled_at::date = CURRENT_DATE;


-- ============================================================================
-- 2.3 KPI: REUNIÕES PRÓXIMOS 7 DIAS
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Reuniões agendadas na próxima semana

SELECT COUNT(*) AS reunioes_proxima_semana
FROM corev4_scheduled_meetings
WHERE company_id = 1
  AND meeting_date >= NOW()
  AND meeting_date <= NOW() + INTERVAL '7 days'
  AND status IN ('scheduled', 'confirmed');


-- ============================================================================
-- 2.4 TOP 10 LEADS POR SCORE ANUM
-- ============================================================================
-- Tipo: Table
-- Descrição: Leads mais qualificados para priorização

SELECT
    c.id AS lead_id,
    c.full_name AS nome,
    COALESCE(c.email, '-') AS email,
    COALESCE(c.phone_number, SPLIT_PART(c.whatsapp, '@', 1)) AS telefone,
    ls.total_score AS anum_total,
    CASE ls.qualification_stage
        WHEN 'qualified' THEN 'Qualificado'
        WHEN 'developing' THEN 'Desenvolvendo'
        ELSE 'Pré-qualificado'
    END AS estagio,
    COALESCE(pc.category_label_pt, '-') AS categoria_dor,
    TO_CHAR(c.last_interaction_at AT TIME ZONE 'America/Sao_Paulo', 'DD/MM HH24:MI') AS ultima_interacao,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM corev4_scheduled_meetings sm
            WHERE sm.contact_id = c.id
            AND sm.meeting_date > NOW()
            AND sm.status IN ('scheduled', 'confirmed')
        ) THEN 'Sim'
        ELSE 'Não'
    END AS tem_reuniao
FROM corev4_contacts c
INNER JOIN corev4_lead_state ls ON c.id = ls.contact_id
LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
WHERE c.company_id = 1
  AND c.is_active = true
  AND c.opt_out = false
  AND ls.total_score IS NOT NULL
ORDER BY ls.total_score DESC
LIMIT 10;


-- ============================================================================
-- 2.5 CAMPANHAS DE FOLLOW-UP - STATUS
-- ============================================================================
-- Tipo: Bar Chart (horizontal)
-- Descrição: Status das campanhas de follow-up

SELECT
    CASE status
        WHEN 'active' THEN 'Ativas'
        WHEN 'completed' THEN 'Concluídas'
        WHEN 'stopped' THEN 'Interrompidas'
        ELSE 'Outro'
    END AS status_campanha,
    COUNT(*) AS total
FROM corev4_followup_campaigns
WHERE company_id = 1
GROUP BY status
ORDER BY total DESC;


-- ============================================================================
-- 2.6 MOTIVOS DE INTERRUPÇÃO DE CAMPANHAS
-- ============================================================================
-- Tipo: Pie Chart
-- Descrição: Por que as campanhas foram interrompidas

SELECT
    CASE stopped_reason
        WHEN 'meeting_scheduled' THEN 'Reunião Agendada'
        WHEN 'qualified' THEN 'Lead Qualificado'
        WHEN 'disqualified' THEN 'Lead Desqualificado'
        WHEN 'opt_out' THEN 'Opt-Out'
        WHEN 'no_response' THEN 'Sem Resposta'
        WHEN 'manual' THEN 'Manual'
        ELSE COALESCE(stopped_reason, 'Não especificado')
    END AS motivo,
    COUNT(*) AS total
FROM corev4_followup_campaigns
WHERE company_id = 1
  AND status = 'stopped'
  AND stopped_reason IS NOT NULL
GROUP BY stopped_reason
ORDER BY total DESC;


-- ============================================================================
-- 2.7 REUNIÕES AGENDADAS - LISTA DETALHADA
-- ============================================================================
-- Tipo: Table
-- Descrição: Próximas reuniões com detalhes

SELECT
    TO_CHAR(sm.meeting_date AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') AS data,
    TO_CHAR(sm.meeting_date AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI') AS horario,
    c.full_name AS lead,
    COALESCE(c.email, '-') AS email,
    sm.meeting_duration_minutes || ' min' AS duracao,
    ROUND(sm.anum_score_at_booking, 0) AS anum_agendamento,
    CASE
        WHEN sm.reminder_24h_sent THEN 'Sim'
        ELSE 'Não'
    END AS lembrete_24h,
    CASE
        WHEN sm.reminder_1h_sent THEN 'Sim'
        ELSE 'Não'
    END AS lembrete_1h,
    CASE sm.status
        WHEN 'scheduled' THEN 'Agendada'
        WHEN 'confirmed' THEN 'Confirmada'
        ELSE sm.status
    END AS status
FROM corev4_scheduled_meetings sm
INNER JOIN corev4_contacts c ON sm.contact_id = c.id
WHERE sm.company_id = 1
  AND sm.meeting_date >= NOW()
  AND sm.status IN ('scheduled', 'confirmed')
ORDER BY sm.meeting_date ASC
LIMIT 15;


-- ============================================================================
-- 2.8 TAXA DE EXECUÇÃO DE FOLLOW-UPS POR STEP
-- ============================================================================
-- Tipo: Bar Chart
-- Descrição: Taxa de execução por número do step

SELECT
    'Step ' || step AS passo,
    COUNT(*) AS total_agendados,
    COUNT(*) FILTER (WHERE executed = true) AS executados,
    ROUND(
        COUNT(*) FILTER (WHERE executed = true)::numeric /
        NULLIF(COUNT(*), 0) * 100,
        1
    ) AS taxa_execucao_pct
FROM corev4_followup_executions
WHERE company_id = 1
GROUP BY step
ORDER BY step ASC;


-- ============================================================================
-- 2.9 LEADS SEM INTERAÇÃO (ÚLTIMOS 7 DIAS)
-- ============================================================================
-- Tipo: Table
-- Descrição: Leads que não interagiram recentemente (risco de esfriar)

SELECT
    c.id AS lead_id,
    c.full_name AS nome,
    ls.total_score AS anum,
    EXTRACT(DAY FROM NOW() - c.last_interaction_at) AS dias_sem_interacao,
    TO_CHAR(c.last_interaction_at AT TIME ZONE 'America/Sao_Paulo', 'DD/MM HH24:MI') AS ultima_interacao,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM corev4_followup_campaigns fc
            WHERE fc.contact_id = c.id AND fc.status = 'active'
        ) THEN 'Em Follow-up'
        ELSE 'Sem Campanha'
    END AS status_followup
FROM corev4_contacts c
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
WHERE c.company_id = 1
  AND c.is_active = true
  AND c.opt_out = false
  AND c.last_interaction_at < NOW() - INTERVAL '7 days'
  AND c.last_interaction_at > NOW() - INTERVAL '30 days'
  AND ls.total_score >= 30  -- Pelo menos em desenvolvimento
ORDER BY ls.total_score DESC, c.last_interaction_at ASC
LIMIT 15;


-- ============================================================================
-- 2.10 VOLUME DE MENSAGENS (ÚLTIMOS 14 DIAS)
-- ============================================================================
-- Tipo: Line Chart
-- Descrição: Volume diário de mensagens trocadas

SELECT
    DATE_TRUNC('day', message_timestamp)::date AS dia,
    COUNT(*) FILTER (WHERE role = 'user') AS mensagens_leads,
    COUNT(*) FILTER (WHERE role = 'assistant') AS mensagens_frank,
    COUNT(DISTINCT contact_id) AS leads_ativos
FROM corev4_chat_history
WHERE company_id = 1
  AND message_timestamp >= NOW() - INTERVAL '14 days'
GROUP BY DATE_TRUNC('day', message_timestamp)
ORDER BY dia ASC;


-- ============================================================================
-- 2.11 LEADS POR ORIGEM (UTM SOURCE)
-- ============================================================================
-- Tipo: Bar Chart (horizontal)
-- Descrição: Distribuição de leads por fonte de tráfego

SELECT
    COALESCE(utm_source, 'Orgânico/Direto') AS fonte,
    COUNT(*) AS total_leads,
    COUNT(*) FILTER (
        WHERE id IN (SELECT contact_id FROM corev4_lead_state WHERE is_qualified = true AND company_id = 1)
    ) AS qualificados
FROM corev4_contacts
WHERE company_id = 1
  AND is_active = true
GROUP BY utm_source
ORDER BY total_leads DESC
LIMIT 10;


-- ============================================================================
-- 2.12 PROGRESSO DAS CAMPANHAS ATIVAS
-- ============================================================================
-- Tipo: Progress Bar / Table
-- Descrição: Progresso de cada campanha ativa

SELECT
    fc.id AS campanha_id,
    c.full_name AS lead,
    fc.steps_completed || '/' || fc.total_steps AS progresso,
    ROUND(fc.steps_completed::numeric / NULLIF(fc.total_steps, 0) * 100, 0) AS pct_completo,
    TO_CHAR(fc.last_step_sent_at AT TIME ZONE 'America/Sao_Paulo', 'DD/MM HH24:MI') AS ultimo_step,
    COALESCE(ls.total_score, 0) AS anum_atual
FROM corev4_followup_campaigns fc
INNER JOIN corev4_contacts c ON fc.contact_id = c.id
LEFT JOIN corev4_lead_state ls ON fc.contact_id = ls.contact_id
WHERE fc.company_id = 1
  AND fc.status = 'active'
  AND fc.should_continue = true
ORDER BY fc.last_step_sent_at DESC
LIMIT 20;

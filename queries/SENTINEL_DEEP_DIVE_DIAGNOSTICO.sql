-- ============================================================================
-- SENTINEL DEEP DIVE - DIAGNÓSTICO COMPLETO DE FOLLOWUPS
-- ============================================================================
-- Data: 2024-12-08
-- Objetivo: Investigar por que os followups não estão sendo enviados
-- ============================================================================

-- ============================================================================
-- PARTE 1: VISÃO GERAL DO SISTEMA
-- ============================================================================

-- 1.1: Contagem total de leads no sistema
SELECT
    'Total de Contatos' AS metrica,
    COUNT(*) AS valor
FROM corev4_contacts
WHERE company_id = 1

UNION ALL

SELECT
    'Contatos Ativos' AS metrica,
    COUNT(*) AS valor
FROM corev4_contacts
WHERE company_id = 1 AND is_active = true

UNION ALL

SELECT
    'Contatos com Opt-Out' AS metrica,
    COUNT(*) AS valor
FROM corev4_contacts
WHERE company_id = 1 AND opt_out = true;


-- 1.2: Distribuição de leads por status ANUM
SELECT
    COALESCE(ls.qualification_stage, 'sem_analise') AS stage,
    COUNT(*) AS total_leads,
    ROUND(AVG(ls.total_score), 2) AS avg_anum_score,
    ROUND(MIN(ls.total_score), 2) AS min_score,
    ROUND(MAX(ls.total_score), 2) AS max_score
FROM corev4_contacts c
LEFT JOIN corev4_lead_state ls ON ls.contact_id = c.id
WHERE c.company_id = 1
GROUP BY ls.qualification_stage
ORDER BY total_leads DESC;


-- 1.3: Leads por faixa de ANUM score
SELECT
    CASE
        WHEN ls.total_score IS NULL THEN '0. Sem Score'
        WHEN ls.total_score < 30 THEN '1. Frio (0-30)'
        WHEN ls.total_score < 60 THEN '2. Morno (30-60)'
        WHEN ls.total_score < 70 THEN '3. Quente (60-70)'
        ELSE '4. Qualificado (70+)'
    END AS faixa_anum,
    COUNT(*) AS total_leads
FROM corev4_contacts c
LEFT JOIN corev4_lead_state ls ON ls.contact_id = c.id
WHERE c.company_id = 1
GROUP BY 1
ORDER BY 1;


-- ============================================================================
-- PARTE 2: ESTADO DAS CAMPANHAS DE FOLLOWUP
-- ============================================================================

-- 2.1: Resumo de campanhas por status
SELECT
    status,
    COUNT(*) AS total_campanhas,
    ROUND(AVG(steps_completed), 2) AS avg_steps_completed,
    ROUND(AVG(total_steps), 2) AS avg_total_steps,
    SUM(CASE WHEN should_continue = true THEN 1 ELSE 0 END) AS should_continue_true,
    SUM(CASE WHEN should_continue = false THEN 1 ELSE 0 END) AS should_continue_false
FROM corev4_followup_campaigns
WHERE company_id = 1
GROUP BY status
ORDER BY total_campanhas DESC;


-- 2.2: Campanhas ativas - detalhe
SELECT
    fc.id AS campaign_id,
    c.full_name,
    c.whatsapp,
    fc.status,
    fc.steps_completed,
    fc.total_steps,
    fc.should_continue,
    fc.stopped_reason,
    fc.pause_reason,
    fc.last_step_sent_at,
    fc.created_at,
    ls.total_score AS anum_score,
    ls.qualification_stage
FROM corev4_followup_campaigns fc
INNER JOIN corev4_contacts c ON c.id = fc.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = c.id
WHERE fc.company_id = 1
  AND fc.status = 'active'
ORDER BY fc.created_at DESC
LIMIT 50;


-- 2.3: Campanhas paradas - por que pararam?
SELECT
    fc.stopped_reason,
    fc.pause_reason,
    COUNT(*) AS total
FROM corev4_followup_campaigns fc
WHERE fc.company_id = 1
  AND (fc.status = 'stopped' OR fc.should_continue = false)
GROUP BY fc.stopped_reason, fc.pause_reason
ORDER BY total DESC;


-- ============================================================================
-- PARTE 3: FOLLOWUPS PENDENTES (CRÍTICO!)
-- ============================================================================

-- 3.1: Followups que DEVERIAM ter sido enviados (scheduled_at no passado)
SELECT
    e.id AS execution_id,
    e.campaign_id,
    e.step,
    e.scheduled_at,
    NOW() - e.scheduled_at AS atraso,
    e.executed,
    e.should_send,
    e.decision_reason,
    c.full_name,
    c.whatsapp,
    c.opt_out,
    c.last_interaction_at,
    ls.total_score AS anum_score
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
WHERE e.company_id = 1
  AND e.executed = false
  AND e.scheduled_at <= NOW()
ORDER BY e.scheduled_at ASC
LIMIT 100;


-- 3.2: Resumo de followups pendentes por motivo de bloqueio
SELECT
    CASE
        WHEN e.executed = true THEN 'Já Executado'
        WHEN e.should_send = false THEN 'Cancelado (should_send=false)'
        WHEN c.opt_out = true THEN 'Lead com Opt-Out'
        WHEN ls.total_score >= 70 THEN 'Lead Qualificado (ANUM >= 70)'
        WHEN e.scheduled_at > NOW() THEN 'Agendado para Futuro'
        ELSE 'PRONTO PARA ENVIAR'
    END AS status_followup,
    COUNT(*) AS total,
    MIN(e.scheduled_at) AS primeiro_agendado,
    MAX(e.scheduled_at) AS ultimo_agendado
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
WHERE e.company_id = 1
GROUP BY 1
ORDER BY 1;


-- 3.3: Followups PRONTOS para enviar (o que o Sentinel deveria pegar)
SELECT
    e.id AS execution_id,
    e.campaign_id,
    e.contact_id,
    e.step,
    e.total_steps,
    e.scheduled_at,
    NOW() - e.scheduled_at AS tempo_atraso,
    c.full_name,
    c.whatsapp,
    c.opt_out,
    c.last_interaction_at,
    ls.total_score AS anum_score,
    ls.qualification_stage
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
WHERE e.company_id = 1
  AND e.executed = false
  AND e.should_send = true
  AND e.scheduled_at <= NOW()
  AND c.opt_out = false
  AND (ls.total_score IS NULL OR ls.total_score < 70)
ORDER BY e.scheduled_at ASC
LIMIT 50;


-- 3.4: Query EXATA que o Sentinel usa (DISTINCT ON por campaign_id)
SELECT DISTINCT ON (e.campaign_id)
    e.id AS execution_id,
    e.campaign_id,
    e.contact_id,
    e.step,
    e.total_steps,
    e.scheduled_at,
    NOW() - e.scheduled_at AS tempo_atraso,
    c.full_name,
    c.whatsapp,
    ls.total_score AS anum_score
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
WHERE e.company_id = 1
  AND e.executed = false
  AND e.should_send = true
  AND e.scheduled_at <= NOW()
  AND c.opt_out = false
  AND (ls.total_score IS NULL OR ls.total_score < 70)
ORDER BY e.campaign_id, e.step ASC
LIMIT 50;


-- ============================================================================
-- PARTE 4: HISTÓRICO DE EXECUÇÕES
-- ============================================================================

-- 4.1: Últimos followups enviados
SELECT
    e.id AS execution_id,
    e.campaign_id,
    e.step,
    e.scheduled_at,
    e.sent_at,
    e.decision_reason,
    e.anum_at_execution,
    c.full_name,
    c.whatsapp,
    LEFT(e.generated_message, 100) AS msg_preview
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
WHERE e.company_id = 1
  AND e.executed = true
  AND e.sent_at IS NOT NULL
ORDER BY e.sent_at DESC
LIMIT 30;


-- 4.2: Followups por dia (últimos 30 dias)
SELECT
    DATE(sent_at) AS dia,
    COUNT(*) AS followups_enviados,
    COUNT(DISTINCT campaign_id) AS campanhas_distintas,
    COUNT(DISTINCT contact_id) AS leads_distintos
FROM corev4_followup_executions
WHERE company_id = 1
  AND executed = true
  AND sent_at IS NOT NULL
  AND sent_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(sent_at)
ORDER BY dia DESC;


-- 4.3: Followups por step (distribuição)
SELECT
    step,
    COUNT(*) AS total_executados,
    COUNT(CASE WHEN executed = true THEN 1 END) AS enviados,
    COUNT(CASE WHEN executed = false AND should_send = true THEN 1 END) AS pendentes,
    COUNT(CASE WHEN should_send = false THEN 1 END) AS cancelados
FROM corev4_followup_executions
WHERE company_id = 1
GROUP BY step
ORDER BY step;


-- 4.4: Motivos de decision_reason
SELECT
    decision_reason,
    executed,
    should_send,
    COUNT(*) AS total
FROM corev4_followup_executions
WHERE company_id = 1
GROUP BY decision_reason, executed, should_send
ORDER BY total DESC;


-- ============================================================================
-- PARTE 5: ANÁLISE DE TIMING E SCHEDULING
-- ============================================================================

-- 5.1: Configuração de steps (timing entre followups)
SELECT
    fs.step_number,
    fs.wait_hours,
    fs.wait_minutes,
    CONCAT(
        CASE
            WHEN fs.wait_hours >= 24 THEN CONCAT(fs.wait_hours / 24, ' dias')
            ELSE CONCAT(fs.wait_hours, 'h')
        END,
        CASE WHEN fs.wait_minutes > 0 THEN CONCAT(' ', fs.wait_minutes, 'min') ELSE '' END
    ) AS timing_legivel
FROM corev4_followup_steps fs
INNER JOIN corev4_followup_configs fc ON fc.id = fs.config_id
WHERE fc.company_id = 1
ORDER BY fs.config_id, fs.step_number;


-- 5.2: Distribuição de scheduled_at (quando os followups estão agendados)
SELECT
    CASE
        WHEN scheduled_at < NOW() - INTERVAL '7 days' THEN '1. Atrasado > 7 dias'
        WHEN scheduled_at < NOW() - INTERVAL '1 day' THEN '2. Atrasado 1-7 dias'
        WHEN scheduled_at < NOW() THEN '3. Atrasado < 1 dia'
        WHEN scheduled_at < NOW() + INTERVAL '1 day' THEN '4. Próximas 24h'
        WHEN scheduled_at < NOW() + INTERVAL '7 days' THEN '5. Próximos 7 dias'
        ELSE '6. Mais de 7 dias'
    END AS faixa_agendamento,
    COUNT(*) AS total,
    COUNT(CASE WHEN executed = false AND should_send = true THEN 1 END) AS pendentes_ativos
FROM corev4_followup_executions
WHERE company_id = 1
GROUP BY 1
ORDER BY 1;


-- 5.3: Leads com última interação recente (podem ter tido followups reagendados)
SELECT
    c.id AS contact_id,
    c.full_name,
    c.last_interaction_at,
    NOW() - c.last_interaction_at AS tempo_desde_interacao,
    COUNT(e.id) AS followups_pendentes,
    MIN(e.scheduled_at) AS proximo_followup_agendado
FROM corev4_contacts c
INNER JOIN corev4_followup_executions e ON e.contact_id = c.id
WHERE c.company_id = 1
  AND e.executed = false
  AND e.should_send = true
  AND c.last_interaction_at >= NOW() - INTERVAL '7 days'
GROUP BY c.id, c.full_name, c.last_interaction_at
ORDER BY c.last_interaction_at DESC
LIMIT 30;


-- ============================================================================
-- PARTE 6: DIAGNÓSTICO DE PROBLEMAS ESPECÍFICOS
-- ============================================================================

-- 6.1: Leads SEM campanha de followup (possível problema de criação)
SELECT
    c.id AS contact_id,
    c.full_name,
    c.whatsapp,
    c.created_at,
    c.last_interaction_at,
    ls.total_score AS anum_score,
    'SEM CAMPANHA' AS problema
FROM corev4_contacts c
LEFT JOIN corev4_followup_campaigns fc ON fc.contact_id = c.id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = c.id
WHERE c.company_id = 1
  AND c.is_active = true
  AND c.opt_out = false
  AND fc.id IS NULL
ORDER BY c.created_at DESC
LIMIT 50;


-- 6.2: Campanhas com 0 execuções (problema na criação de steps)
SELECT
    fc.id AS campaign_id,
    fc.contact_id,
    c.full_name,
    fc.status,
    fc.created_at,
    (SELECT COUNT(*) FROM corev4_followup_executions e WHERE e.campaign_id = fc.id) AS total_execucoes
FROM corev4_followup_campaigns fc
INNER JOIN corev4_contacts c ON c.id = fc.contact_id
WHERE fc.company_id = 1
  AND NOT EXISTS (
      SELECT 1 FROM corev4_followup_executions e WHERE e.campaign_id = fc.id
  )
ORDER BY fc.created_at DESC;


-- 6.3: Execuções com dados inconsistentes
SELECT
    e.id AS execution_id,
    e.campaign_id,
    e.contact_id,
    e.step,
    e.executed,
    e.sent_at,
    e.should_send,
    e.scheduled_at,
    CASE
        WHEN e.executed = true AND e.sent_at IS NULL THEN 'Executado sem sent_at'
        WHEN e.executed = false AND e.sent_at IS NOT NULL THEN 'Não executado com sent_at'
        WHEN e.should_send = false AND e.executed = true THEN 'Cancelado mas executado'
        ELSE 'OK'
    END AS inconsistencia
FROM corev4_followup_executions e
WHERE e.company_id = 1
  AND (
      (e.executed = true AND e.sent_at IS NULL) OR
      (e.executed = false AND e.sent_at IS NOT NULL) OR
      (e.should_send = false AND e.executed = true)
  )
LIMIT 50;


-- 6.4: Campanhas duplicadas por lead
SELECT
    contact_id,
    c.full_name,
    COUNT(*) AS total_campanhas,
    STRING_AGG(fc.status, ', ' ORDER BY fc.created_at) AS status_campanhas,
    MIN(fc.created_at) AS primeira_campanha,
    MAX(fc.created_at) AS ultima_campanha
FROM corev4_followup_campaigns fc
INNER JOIN corev4_contacts c ON c.id = fc.contact_id
WHERE fc.company_id = 1
GROUP BY contact_id, c.full_name
HAVING COUNT(*) > 1
ORDER BY total_campanhas DESC
LIMIT 30;


-- ============================================================================
-- PARTE 7: VERIFICAÇÕES DE CONFIGURAÇÃO
-- ============================================================================

-- 7.1: Configs de followup ativas
SELECT
    fc.id AS config_id,
    fc.company_id,
    fc.total_steps,
    fc.qualification_threshold,
    fc.disqualification_threshold,
    fc.is_active,
    fc.created_at
FROM corev4_followup_configs fc
WHERE fc.company_id = 1;


-- 7.2: Verificar se há steps configurados para cada config
SELECT
    fc.id AS config_id,
    fc.total_steps AS steps_configurados,
    COUNT(fs.id) AS steps_criados,
    CASE
        WHEN fc.total_steps = COUNT(fs.id) THEN 'OK'
        ELSE 'DIVERGENTE'
    END AS status
FROM corev4_followup_configs fc
LEFT JOIN corev4_followup_steps fs ON fs.config_id = fc.id
WHERE fc.company_id = 1
GROUP BY fc.id, fc.total_steps;


-- ============================================================================
-- PARTE 8: MÉTRICAS DE PERFORMANCE DO SENTINEL
-- ============================================================================

-- 8.1: Taxa de conversão por step
SELECT
    e.step,
    COUNT(*) AS total_enviados,
    COUNT(CASE WHEN ls.total_score >= 70 THEN 1 END) AS qualificados_apos,
    ROUND(
        COUNT(CASE WHEN ls.total_score >= 70 THEN 1 END)::numeric /
        NULLIF(COUNT(*), 0) * 100,
        2
    ) AS taxa_qualificacao_pct
FROM corev4_followup_executions e
INNER JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
WHERE e.company_id = 1
  AND e.executed = true
GROUP BY e.step
ORDER BY e.step;


-- 8.2: Tempo médio entre agendamento e execução
SELECT
    step,
    COUNT(*) AS total,
    ROUND(AVG(EXTRACT(EPOCH FROM (sent_at - scheduled_at)) / 60), 2) AS media_minutos_atraso,
    MIN(sent_at - scheduled_at) AS min_atraso,
    MAX(sent_at - scheduled_at) AS max_atraso
FROM corev4_followup_executions
WHERE company_id = 1
  AND executed = true
  AND sent_at IS NOT NULL
  AND scheduled_at IS NOT NULL
GROUP BY step
ORDER BY step;


-- ============================================================================
-- PARTE 9: SUMÁRIO EXECUTIVO
-- ============================================================================

-- 9.1: Dashboard resumido do estado atual
SELECT
    'Total Leads' AS metrica,
    COUNT(*)::text AS valor
FROM corev4_contacts WHERE company_id = 1

UNION ALL

SELECT
    'Leads com Campanha Ativa',
    COUNT(DISTINCT contact_id)::text
FROM corev4_followup_campaigns
WHERE company_id = 1 AND status = 'active'

UNION ALL

SELECT
    'Followups Pendentes (Total)',
    COUNT(*)::text
FROM corev4_followup_executions
WHERE company_id = 1 AND executed = false AND should_send = true

UNION ALL

SELECT
    'Followups ATRASADOS (deveriam ter sido enviados)',
    COUNT(*)::text
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
WHERE e.company_id = 1
  AND e.executed = false
  AND e.should_send = true
  AND e.scheduled_at <= NOW()
  AND c.opt_out = false
  AND (ls.total_score IS NULL OR ls.total_score < 70)

UNION ALL

SELECT
    'Followups Enviados (últimas 24h)',
    COUNT(*)::text
FROM corev4_followup_executions
WHERE company_id = 1 AND executed = true AND sent_at >= NOW() - INTERVAL '24 hours'

UNION ALL

SELECT
    'Followups Enviados (últimos 7 dias)',
    COUNT(*)::text
FROM corev4_followup_executions
WHERE company_id = 1 AND executed = true AND sent_at >= NOW() - INTERVAL '7 days';


-- ============================================================================
-- FIM DO DIAGNÓSTICO
-- ============================================================================

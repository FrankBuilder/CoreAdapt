-- ============================================================================
-- QUERIES SQL PARA DASHBOARDS - Apache Superset / Redash / Grafana
-- ============================================================================
-- Queries prontas para criar dashboards visuais bonitos
-- Copie e cole no SQL Lab do Superset
-- ============================================================================

-- ============================================================================
-- 1. KPI: TOTAL DE LEADS POR STATUS
-- ============================================================================
-- Tipo de gráfico: Big Number ou Pie Chart

SELECT
    CASE
        WHEN opt_out THEN 'Opt-Out'
        WHEN NOT is_active THEN 'Inativo'
        ELSE 'Ativo'
    END AS status,
    COUNT(*) AS total_leads
FROM corev4_contacts
GROUP BY status
ORDER BY total_leads DESC;


-- ============================================================================
-- 2. KPI: ANUM MÉDIO POR ESTÁGIO DE QUALIFICAÇÃO
-- ============================================================================
-- Tipo de gráfico: Bar Chart (horizontal)

SELECT
    UPPER(qualification_stage) AS estagio,
    COUNT(*) AS total_leads,
    ROUND(AVG(total_score), 1) AS anum_medio,
    ROUND(AVG(authority_score), 1) AS authority_medio,
    ROUND(AVG(need_score), 1) AS need_medio,
    ROUND(AVG(urgency_score), 1) AS urgency_medio,
    ROUND(AVG(money_score), 1) AS money_medio
FROM corev4_lead_state
WHERE total_score IS NOT NULL
GROUP BY qualification_stage
ORDER BY
    CASE qualification_stage
        WHEN 'qualified' THEN 1
        WHEN 'developing' THEN 2
        WHEN 'pre' THEN 3
        ELSE 4
    END;


-- ============================================================================
-- 3. TENDÊNCIA: LEADS CRIADOS POR MÊS
-- ============================================================================
-- Tipo de gráfico: Line Chart

SELECT
    DATE_TRUNC('month', created_at) AS mes,
    COUNT(*) AS novos_leads,
    COUNT(*) FILTER (WHERE opt_out = true) AS opt_outs,
    COUNT(*) FILTER (WHERE is_active = true) AS leads_ativos
FROM corev4_contacts
WHERE created_at >= NOW() - INTERVAL '12 months'
GROUP BY mes
ORDER BY mes ASC;


-- ============================================================================
-- 4. FUNIL DE CONVERSÃO: ANUM SCORES
-- ============================================================================
-- Tipo de gráfico: Funnel Chart

SELECT
    'Total de Leads' AS etapa,
    COUNT(*) AS quantidade,
    1 AS ordem
FROM corev4_contacts

UNION ALL

SELECT
    'Com ANUM Analisado' AS etapa,
    COUNT(*) AS quantidade,
    2 AS ordem
FROM corev4_lead_state
WHERE total_score IS NOT NULL

UNION ALL

SELECT
    'Developing (30-70)' AS etapa,
    COUNT(*) AS quantidade,
    3 AS ordem
FROM corev4_lead_state
WHERE total_score >= 30 AND total_score < 70

UNION ALL

SELECT
    'Qualified (70+)' AS etapa,
    COUNT(*) AS quantidade,
    4 AS ordem
FROM corev4_lead_state
WHERE total_score >= 70

UNION ALL

SELECT
    'Com Reunião Agendada' AS etapa,
    COUNT(DISTINCT sm.contact_id) AS quantidade,
    5 AS ordem
FROM corev4_scheduled_meetings sm
WHERE sm.status = 'scheduled' OR sm.meeting_completed = true

ORDER BY ordem;


-- ============================================================================
-- 5. PERFORMANCE DE FOLLOW-UPS
-- ============================================================================
-- Tipo de gráfico: Stacked Bar Chart

SELECT
    fc.status AS status_campanha,
    COUNT(*) AS total_campanhas,
    ROUND(AVG(fc.steps_completed::numeric / NULLIF(fc.total_steps, 0) * 100), 1) AS progresso_medio_pct,
    COUNT(*) FILTER (WHERE fc.should_continue = true) AS campanhas_ativas,
    COUNT(*) FILTER (WHERE fc.stopped_reason = 'meeting_scheduled') AS paradas_por_reuniao,
    COUNT(*) FILTER (WHERE fc.stopped_reason = 'opt_out') AS paradas_por_optout
FROM corev4_followup_campaigns fc
GROUP BY fc.status
ORDER BY total_campanhas DESC;


-- ============================================================================
-- 6. TAXA DE RESPOSTA POR PASSO DE FOLLOW-UP
-- ============================================================================
-- Tipo de gráfico: Line Chart com múltiplas linhas

SELECT
    step AS passo,
    COUNT(*) AS total_enviados,
    COUNT(*) FILTER (WHERE executed = true) AS executados,
    COUNT(*) FILTER (WHERE should_send = false) AS cancelados,
    ROUND(COUNT(*) FILTER (WHERE executed = true)::numeric / NULLIF(COUNT(*), 0) * 100, 1) AS taxa_execucao_pct
FROM corev4_followup_executions
GROUP BY step
ORDER BY step ASC;


-- ============================================================================
-- 7. REUNIÕES: STATUS E CONVERSÃO
-- ============================================================================
-- Tipo de gráfico: Pie Chart

SELECT
    CASE
        WHEN meeting_completed = true THEN 'Realizada'
        WHEN no_show = true THEN 'No-Show'
        WHEN status = 'cancelled' THEN 'Cancelada'
        WHEN meeting_date > NOW() THEN 'Agendada (Futura)'
        ELSE 'Pendente Confirmação'
    END AS status_reuniao,
    COUNT(*) AS total,
    ROUND(AVG(anum_score_at_booking), 1) AS anum_medio_no_agendamento
FROM corev4_scheduled_meetings
GROUP BY status_reuniao
ORDER BY total DESC;


-- ============================================================================
-- 8. ANUM: DISTRIBUIÇÃO POR FAIXA
-- ============================================================================
-- Tipo de gráfico: Histogram ou Bar Chart

SELECT
    CASE
        WHEN total_score < 30 THEN '0-29 (Pre-qualified)'
        WHEN total_score >= 30 AND total_score < 50 THEN '30-49 (Developing)'
        WHEN total_score >= 50 AND total_score < 70 THEN '50-69 (Developing)'
        WHEN total_score >= 70 AND total_score < 85 THEN '70-84 (Qualified)'
        WHEN total_score >= 85 THEN '85-100 (Highly Qualified)'
        ELSE 'Sem Score'
    END AS faixa_anum,
    COUNT(*) AS total_leads,
    ROUND(AVG(total_score), 1) AS score_medio
FROM corev4_lead_state
GROUP BY faixa_anum
ORDER BY
    CASE
        WHEN total_score < 30 THEN 1
        WHEN total_score >= 30 AND total_score < 50 THEN 2
        WHEN total_score >= 50 AND total_score < 70 THEN 3
        WHEN total_score >= 70 AND total_score < 85 THEN 4
        WHEN total_score >= 85 THEN 5
        ELSE 6
    END;


-- ============================================================================
-- 9. ORIGEM DE LEADS (UTM)
-- ============================================================================
-- Tipo de gráfico: Treemap ou Sunburst

SELECT
    COALESCE(utm_source, 'Orgânico') AS fonte,
    COALESCE(utm_medium, 'Direto') AS meio,
    COALESCE(utm_campaign, 'Sem Campanha') AS campanha,
    COUNT(*) AS total_leads,
    COUNT(*) FILTER (
        WHERE id IN (
            SELECT contact_id
            FROM corev4_lead_state
            WHERE is_qualified = true
        )
    ) AS leads_qualificados,
    ROUND(
        COUNT(*) FILTER (
            WHERE id IN (SELECT contact_id FROM corev4_lead_state WHERE is_qualified = true)
        )::numeric / NULLIF(COUNT(*), 0) * 100,
        1
    ) AS taxa_qualificacao_pct
FROM corev4_contacts
GROUP BY fonte, meio, campanha
ORDER BY total_leads DESC
LIMIT 20;


-- ============================================================================
-- 10. ATIVIDADE DE MENSAGENS POR DIA
-- ============================================================================
-- Tipo de gráfico: Line Chart com área preenchida

SELECT
    DATE_TRUNC('day', message_timestamp) AS dia,
    COUNT(*) AS total_mensagens,
    COUNT(*) FILTER (WHERE role = 'user') AS mensagens_lead,
    COUNT(*) FILTER (WHERE role = 'assistant') AS mensagens_bot,
    COUNT(DISTINCT contact_id) AS leads_unicos_ativos,
    SUM(tokens_used) AS tokens_consumidos,
    ROUND(SUM(cost_usd), 4) AS custo_total_usd
FROM corev4_chat_history
WHERE message_timestamp >= NOW() - INTERVAL '30 days'
GROUP BY dia
ORDER BY dia ASC;


-- ============================================================================
-- 11. TOP 10 LEADS POR SCORE ANUM
-- ============================================================================
-- Tipo de gráfico: Table (tabela)

SELECT
    c.id,
    c.full_name AS nome,
    c.email,
    c.whatsapp,
    ls.total_score AS anum_total,
    ls.qualification_stage AS estagio,
    ls.is_qualified AS qualificado,
    pc.category_label_pt AS categoria_dor,
    c.last_interaction_at AS ultima_interacao,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM corev4_scheduled_meetings sm
            WHERE sm.contact_id = c.id
            AND sm.meeting_date > NOW()
        ) THEN '✓ Reunião Agendada'
        ELSE '○ Sem Reunião'
    END AS status_reuniao
FROM corev4_contacts c
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
WHERE ls.total_score IS NOT NULL
ORDER BY ls.total_score DESC
LIMIT 10;


-- ============================================================================
-- 12. CUSTO POR LEAD (Tokens e USD)
-- ============================================================================
-- Tipo de gráfico: Scatter Plot ou Table

SELECT
    c.id,
    c.full_name AS nome,
    COUNT(ch.id) AS total_mensagens,
    SUM(ch.tokens_used) AS tokens_totais,
    ROUND(SUM(ch.cost_usd), 4) AS custo_total_usd,
    ROUND(SUM(ch.cost_usd) / NULLIF(COUNT(ch.id), 0), 6) AS custo_por_mensagem,
    ls.total_score AS anum_score,
    CASE
        WHEN ls.total_score >= 70 THEN 'Qualified'
        WHEN ls.total_score >= 30 THEN 'Developing'
        ELSE 'Pre-qualified'
    END AS categoria
FROM corev4_contacts c
LEFT JOIN corev4_chat_history ch ON c.id = ch.contact_id
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
WHERE ch.id IS NOT NULL
GROUP BY c.id, c.full_name, ls.total_score
ORDER BY custo_total_usd DESC
LIMIT 20;


-- ============================================================================
-- 13. TEMPO MÉDIO PARA QUALIFICAÇÃO
-- ============================================================================
-- Tipo de gráfico: Box Plot ou Big Number

SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (ls.last_analyzed_at - c.created_at))/3600), 1) AS horas_media_para_qualificacao,
    ROUND(MIN(EXTRACT(EPOCH FROM (ls.last_analyzed_at - c.created_at))/3600), 1) AS tempo_minimo_horas,
    ROUND(MAX(EXTRACT(EPOCH FROM (ls.last_analyzed_at - c.created_at))/3600), 1) AS tempo_maximo_horas,
    COUNT(*) AS total_analisados
FROM corev4_contacts c
INNER JOIN corev4_lead_state ls ON c.id = ls.contact_id
WHERE ls.last_analyzed_at IS NOT NULL
  AND ls.total_score IS NOT NULL;


-- ============================================================================
-- 14. REENGAJAMENTO: LEADS QUE VOLTARAM
-- ============================================================================
-- Tipo de gráfico: Time Series (linha do tempo)

WITH user_messages AS (
    SELECT
        contact_id,
        message_timestamp,
        LAG(message_timestamp) OVER (PARTITION BY contact_id ORDER BY message_timestamp) AS prev_msg
    FROM corev4_chat_history
    WHERE role = 'user'
),
reengagements AS (
    SELECT
        contact_id,
        message_timestamp,
        EXTRACT(EPOCH FROM (message_timestamp - prev_msg))/3600 AS gap_hours
    FROM user_messages
    WHERE prev_msg IS NOT NULL
      AND EXTRACT(EPOCH FROM (message_timestamp - prev_msg))/3600 > 48
)
SELECT
    DATE_TRUNC('week', message_timestamp) AS semana,
    COUNT(*) AS reengajamentos,
    COUNT(DISTINCT contact_id) AS leads_unicos_reengajados,
    ROUND(AVG(gap_hours), 1) AS gap_medio_horas
FROM reengagements
WHERE message_timestamp >= NOW() - INTERVAL '3 months'
GROUP BY semana
ORDER BY semana ASC;


-- ============================================================================
-- 15. ANÁLISE DE CATEGORIAS DE DOR
-- ============================================================================
-- Tipo de gráfico: Horizontal Bar Chart

SELECT
    pc.category_label_pt AS categoria_dor,
    COUNT(*) AS total_leads,
    ROUND(AVG(ls.total_score), 1) AS anum_medio,
    COUNT(*) FILTER (WHERE ls.is_qualified = true) AS leads_qualificados,
    ROUND(
        COUNT(*) FILTER (WHERE ls.is_qualified = true)::numeric /
        NULLIF(COUNT(*), 0) * 100,
        1
    ) AS taxa_qualificacao_pct,
    COUNT(DISTINCT sm.id) AS reunioes_agendadas
FROM corev4_pain_categories pc
LEFT JOIN corev4_lead_state ls ON pc.id = ls.main_pain_category_id
LEFT JOIN corev4_scheduled_meetings sm ON ls.contact_id = sm.contact_id
GROUP BY pc.category_label_pt
ORDER BY total_leads DESC;


-- ============================================================================
-- DICA: PARÂMETROS DINÂMICOS
-- ============================================================================
-- No Superset, você pode criar filtros dinâmicos:
--
-- WHERE created_at >= '{{ from_dttm }}'
--   AND created_at < '{{ to_dttm }}'
--
-- Isso cria seletores de data automáticos no dashboard!
-- ============================================================================

-- ============================================================================
-- DASHBOARD EXECUTIVO - Metabase
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Este dashboard apresenta uma visão executiva do funil de vendas
-- e performance geral do robô Frank na qualificação de leads.
-- ============================================================================

-- ============================================================================
-- 1.1 KPI: TOTAL DE LEADS ATIVOS
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Total de leads ativos no sistema (não opt-out)

SELECT COUNT(*) AS total_leads_ativos
FROM corev4_contacts
WHERE company_id = 1
  AND is_active = true
  AND opt_out = false;


-- ============================================================================
-- 1.2 KPI: LEADS QUALIFICADOS (ANUM 70+)
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Leads que atingiram score ANUM >= 70

SELECT COUNT(*) AS leads_qualificados
FROM corev4_lead_state
WHERE company_id = 1
  AND is_qualified = true;


-- ============================================================================
-- 1.3 KPI: REUNIÕES AGENDADAS (PRÓXIMOS 30 DIAS)
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Reuniões futuras confirmadas

SELECT COUNT(*) AS reunioes_agendadas
FROM corev4_scheduled_meetings
WHERE company_id = 1
  AND meeting_date >= NOW()
  AND meeting_date <= NOW() + INTERVAL '30 days'
  AND status IN ('scheduled', 'confirmed');


-- ============================================================================
-- 1.4 KPI: TAXA DE QUALIFICAÇÃO (%)
-- ============================================================================
-- Tipo: Number (Big Number) com sufixo %
-- Descrição: % de leads analisados que foram qualificados

SELECT
    ROUND(
        COUNT(*) FILTER (WHERE is_qualified = true)::numeric /
        NULLIF(COUNT(*), 0) * 100,
        1
    ) AS taxa_qualificacao_pct
FROM corev4_lead_state
WHERE company_id = 1
  AND total_score IS NOT NULL;


-- ============================================================================
-- 1.5 FUNIL DE CONVERSÃO
-- ============================================================================
-- Tipo: Funnel Chart
-- Descrição: Visualização do funil completo de leads

SELECT etapa, quantidade, ordem
FROM (
    SELECT
        'Total de Leads' AS etapa,
        COUNT(*) AS quantidade,
        1 AS ordem
    FROM corev4_contacts
    WHERE company_id = 1
      AND is_active = true
      AND opt_out = false

    UNION ALL

    SELECT
        'Com ANUM Analisado' AS etapa,
        COUNT(*) AS quantidade,
        2 AS ordem
    FROM corev4_lead_state
    WHERE company_id = 1
      AND total_score IS NOT NULL

    UNION ALL

    SELECT
        'Em Desenvolvimento (30-69)' AS etapa,
        COUNT(*) AS quantidade,
        3 AS ordem
    FROM corev4_lead_state
    WHERE company_id = 1
      AND total_score >= 30
      AND total_score < 70

    UNION ALL

    SELECT
        'Qualificados (70+)' AS etapa,
        COUNT(*) AS quantidade,
        4 AS ordem
    FROM corev4_lead_state
    WHERE company_id = 1
      AND total_score >= 70

    UNION ALL

    SELECT
        'Com Reunião Agendada' AS etapa,
        COUNT(DISTINCT sm.contact_id) AS quantidade,
        5 AS ordem
    FROM corev4_scheduled_meetings sm
    WHERE sm.company_id = 1
      AND (sm.status IN ('scheduled', 'confirmed') OR sm.meeting_completed = true)

    UNION ALL

    SELECT
        'Reuniões Realizadas' AS etapa,
        COUNT(*) AS quantidade,
        6 AS ordem
    FROM corev4_scheduled_meetings
    WHERE company_id = 1
      AND meeting_completed = true
) funil
ORDER BY ordem;


-- ============================================================================
-- 1.6 DISTRIBUIÇÃO ANUM POR ESTÁGIO
-- ============================================================================
-- Tipo: Pie Chart ou Donut
-- Descrição: Distribuição de leads por estágio de qualificação

SELECT
    CASE qualification_stage
        WHEN 'qualified' THEN 'Qualificado (70+)'
        WHEN 'developing' THEN 'Em Desenvolvimento (30-69)'
        WHEN 'pre' THEN 'Pré-qualificado (0-29)'
        ELSE 'Sem Score'
    END AS estagio,
    COUNT(*) AS total_leads
FROM corev4_lead_state
WHERE company_id = 1
GROUP BY qualification_stage
ORDER BY
    CASE qualification_stage
        WHEN 'qualified' THEN 1
        WHEN 'developing' THEN 2
        WHEN 'pre' THEN 3
        ELSE 4
    END;


-- ============================================================================
-- 1.7 TENDÊNCIA DE NOVOS LEADS (ÚLTIMOS 6 MESES)
-- ============================================================================
-- Tipo: Line Chart (com área preenchida)
-- Descrição: Evolução mensal de novos leads

SELECT
    TO_CHAR(DATE_TRUNC('month', created_at), 'Mon/YY') AS mes,
    DATE_TRUNC('month', created_at) AS mes_ordem,
    COUNT(*) AS novos_leads,
    COUNT(*) FILTER (WHERE opt_out = true) AS opt_outs
FROM corev4_contacts
WHERE company_id = 1
  AND created_at >= NOW() - INTERVAL '6 months'
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY mes_ordem ASC;


-- ============================================================================
-- 1.8 SCORE ANUM MÉDIO POR DIMENSÃO
-- ============================================================================
-- Tipo: Bar Chart (horizontal) ou Radar
-- Descrição: Média de cada dimensão do ANUM

SELECT
    dimensao,
    score_medio
FROM (
    SELECT 'Authority' AS dimensao, ROUND(AVG(authority_score), 1) AS score_medio, 1 AS ordem
    FROM corev4_lead_state WHERE company_id = 1 AND authority_score IS NOT NULL
    UNION ALL
    SELECT 'Need' AS dimensao, ROUND(AVG(need_score), 1) AS score_medio, 2 AS ordem
    FROM corev4_lead_state WHERE company_id = 1 AND need_score IS NOT NULL
    UNION ALL
    SELECT 'Urgency' AS dimensao, ROUND(AVG(urgency_score), 1) AS score_medio, 3 AS ordem
    FROM corev4_lead_state WHERE company_id = 1 AND urgency_score IS NOT NULL
    UNION ALL
    SELECT 'Money' AS dimensao, ROUND(AVG(money_score), 1) AS score_medio, 4 AS ordem
    FROM corev4_lead_state WHERE company_id = 1 AND money_score IS NOT NULL
) anum
ORDER BY ordem;


-- ============================================================================
-- 1.9 KPI: ANUM MÉDIO GERAL
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Score ANUM médio de todos os leads analisados

SELECT ROUND(AVG(total_score), 1) AS anum_medio
FROM corev4_lead_state
WHERE company_id = 1
  AND total_score IS NOT NULL;


-- ============================================================================
-- 1.10 REUNIÕES POR STATUS
-- ============================================================================
-- Tipo: Pie Chart
-- Descrição: Distribuição de reuniões por status

SELECT
    CASE
        WHEN meeting_completed = true THEN 'Realizada'
        WHEN no_show = true THEN 'No-Show'
        WHEN status = 'cancelled' THEN 'Cancelada'
        WHEN status = 'rescheduled' THEN 'Reagendada'
        WHEN meeting_date > NOW() THEN 'Agendada (Futura)'
        ELSE 'Pendente'
    END AS status_reuniao,
    COUNT(*) AS total
FROM corev4_scheduled_meetings
WHERE company_id = 1
GROUP BY status_reuniao
ORDER BY total DESC;

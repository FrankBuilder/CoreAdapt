-- ============================================================================
-- DASHBOARD DE CUSTOS LLM - Metabase
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Este dashboard apresenta a análise de custos com LLM (IA),
-- permitindo controle financeiro e otimização de uso.
-- ============================================================================

-- ============================================================================
-- 3.1 KPI: CUSTO TOTAL LLM (USD) - MÊS ATUAL
-- ============================================================================
-- Tipo: Number (Big Number) com prefixo $
-- Descrição: Custo total em dólares no mês corrente

SELECT
    ROUND(SUM(cost_usd), 2) AS custo_total_usd_mes
FROM corev4_chat_history
WHERE company_id = 1
  AND role = 'assistant'
  AND cost_usd IS NOT NULL
  AND DATE_TRUNC('month', message_timestamp) = DATE_TRUNC('month', NOW());


-- ============================================================================
-- 3.2 KPI: CUSTO POR LEAD (MÉDIA)
-- ============================================================================
-- Tipo: Number (Big Number) com prefixo $
-- Descrição: Custo médio de LLM por lead contactado

SELECT
    ROUND(SUM(cost_usd) / NULLIF(COUNT(DISTINCT contact_id), 0), 4) AS custo_medio_por_lead
FROM corev4_chat_history
WHERE company_id = 1
  AND role = 'assistant'
  AND cost_usd IS NOT NULL;


-- ============================================================================
-- 3.3 KPI: TOTAL DE TOKENS CONSUMIDOS (MÊS)
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Tokens totais usados no mês

SELECT
    SUM(tokens_used) AS tokens_mes_atual
FROM corev4_chat_history
WHERE company_id = 1
  AND role = 'assistant'
  AND DATE_TRUNC('month', message_timestamp) = DATE_TRUNC('month', NOW());


-- ============================================================================
-- 3.4 CUSTO POR MODELO DE LLM
-- ============================================================================
-- Tipo: Pie Chart ou Donut
-- Descrição: Distribuição de custos por modelo utilizado

SELECT
    COALESCE(model_used, 'Não especificado') AS modelo,
    COUNT(*) AS total_mensagens,
    SUM(tokens_used) AS tokens_totais,
    ROUND(SUM(cost_usd), 4) AS custo_total_usd,
    ROUND(SUM(cost_usd) / NULLIF(COUNT(*), 0), 6) AS custo_por_mensagem
FROM corev4_chat_history
WHERE company_id = 1
  AND role = 'assistant'
  AND cost_usd IS NOT NULL
GROUP BY model_used
ORDER BY custo_total_usd DESC;


-- ============================================================================
-- 3.5 TENDÊNCIA DE CUSTOS (ÚLTIMOS 30 DIAS)
-- ============================================================================
-- Tipo: Line Chart (com área)
-- Descrição: Evolução diária dos custos

SELECT
    DATE_TRUNC('day', message_timestamp)::date AS dia,
    ROUND(SUM(cost_usd), 4) AS custo_diario_usd,
    SUM(tokens_used) AS tokens_diarios,
    COUNT(*) AS mensagens
FROM corev4_chat_history
WHERE company_id = 1
  AND role = 'assistant'
  AND cost_usd IS NOT NULL
  AND message_timestamp >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', message_timestamp)
ORDER BY dia ASC;


-- ============================================================================
-- 3.6 CUSTO MENSAL (ÚLTIMOS 6 MESES)
-- ============================================================================
-- Tipo: Bar Chart
-- Descrição: Comparativo mensal de custos

SELECT
    TO_CHAR(DATE_TRUNC('month', message_timestamp), 'Mon/YY') AS mes,
    DATE_TRUNC('month', message_timestamp) AS mes_ordem,
    ROUND(SUM(cost_usd), 2) AS custo_mensal_usd,
    SUM(tokens_used) AS tokens_mensais,
    COUNT(DISTINCT contact_id) AS leads_unicos
FROM corev4_chat_history
WHERE company_id = 1
  AND role = 'assistant'
  AND cost_usd IS NOT NULL
  AND message_timestamp >= NOW() - INTERVAL '6 months'
GROUP BY DATE_TRUNC('month', message_timestamp)
ORDER BY mes_ordem ASC;


-- ============================================================================
-- 3.7 TOP 10 LEADS POR CUSTO
-- ============================================================================
-- Tipo: Table
-- Descrição: Leads que mais consumiram recursos de LLM

SELECT
    c.id AS lead_id,
    c.full_name AS nome,
    COUNT(ch.id) AS total_mensagens,
    SUM(ch.tokens_used) AS tokens_totais,
    ROUND(SUM(ch.cost_usd), 4) AS custo_total_usd,
    COALESCE(ls.total_score, 0) AS anum_score,
    CASE
        WHEN ls.is_qualified = true THEN 'Qualificado'
        WHEN ls.total_score >= 30 THEN 'Desenvolvendo'
        ELSE 'Pré-qualificado'
    END AS status_lead
FROM corev4_contacts c
INNER JOIN corev4_chat_history ch ON c.id = ch.contact_id
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
WHERE c.company_id = 1
  AND ch.role = 'assistant'
  AND ch.cost_usd IS NOT NULL
GROUP BY c.id, c.full_name, ls.total_score, ls.is_qualified
ORDER BY custo_total_usd DESC
LIMIT 10;


-- ============================================================================
-- 3.8 EFICIÊNCIA: CUSTO VS RESULTADO
-- ============================================================================
-- Tipo: Table ou Scatter Plot
-- Descrição: Relação entre custo e qualificação

SELECT
    CASE
        WHEN ls.is_qualified = true THEN 'Qualificados'
        WHEN ls.total_score >= 30 THEN 'Em Desenvolvimento'
        ELSE 'Pré-qualificados'
    END AS categoria,
    COUNT(DISTINCT c.id) AS total_leads,
    ROUND(SUM(ch.cost_usd), 2) AS custo_total_usd,
    ROUND(SUM(ch.cost_usd) / NULLIF(COUNT(DISTINCT c.id), 0), 4) AS custo_por_lead,
    ROUND(AVG(ls.total_score), 1) AS anum_medio
FROM corev4_contacts c
INNER JOIN corev4_chat_history ch ON c.id = ch.contact_id
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
WHERE c.company_id = 1
  AND ch.role = 'assistant'
  AND ch.cost_usd IS NOT NULL
GROUP BY
    CASE
        WHEN ls.is_qualified = true THEN 'Qualificados'
        WHEN ls.total_score >= 30 THEN 'Em Desenvolvimento'
        ELSE 'Pré-qualificados'
    END
ORDER BY custo_total_usd DESC;


-- ============================================================================
-- 3.9 CUSTO POR REUNIÃO AGENDADA
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Quanto custa em média para conseguir uma reunião

WITH leads_com_reuniao AS (
    SELECT DISTINCT contact_id
    FROM corev4_scheduled_meetings
    WHERE company_id = 1
      AND status IN ('scheduled', 'confirmed', 'completed')
),
custos_leads_reuniao AS (
    SELECT
        SUM(ch.cost_usd) AS custo_total,
        COUNT(DISTINCT lr.contact_id) AS total_reunioes
    FROM leads_com_reuniao lr
    INNER JOIN corev4_chat_history ch ON lr.contact_id = ch.contact_id
    WHERE ch.company_id = 1
      AND ch.role = 'assistant'
)
SELECT
    ROUND(custo_total / NULLIF(total_reunioes, 0), 2) AS custo_por_reuniao_usd,
    total_reunioes,
    ROUND(custo_total, 2) AS custo_total_leads_reuniao
FROM custos_leads_reuniao;


-- ============================================================================
-- 3.10 PREÇOS ATUAIS DOS MODELOS
-- ============================================================================
-- Tipo: Table
-- Descrição: Tabela de preços de referência

SELECT
    display_name AS modelo,
    provider AS provedor,
    '$' || ROUND(input_cost_per_1m, 3) AS custo_input_1m,
    '$' || ROUND(output_cost_per_1m, 3) AS custo_output_1m,
    CASE WHEN is_active THEN 'Ativo' ELSE 'Inativo' END AS status
FROM llm_pricing
WHERE is_active = true
ORDER BY provider, input_cost_per_1m ASC;


-- ============================================================================
-- 3.11 TOKENS POR TIPO DE MENSAGEM
-- ============================================================================
-- Tipo: Bar Chart
-- Descrição: Consumo de tokens por tipo de mídia

SELECT
    CASE message_type
        WHEN 'text' THEN 'Texto'
        WHEN 'audio' THEN 'Áudio'
        WHEN 'image' THEN 'Imagem'
        WHEN 'video' THEN 'Vídeo'
        WHEN 'document' THEN 'Documento'
        ELSE COALESCE(message_type, 'Texto')
    END AS tipo_mensagem,
    COUNT(*) AS total_mensagens,
    SUM(tokens_used) AS tokens_totais,
    ROUND(AVG(tokens_used), 0) AS tokens_medio
FROM corev4_chat_history
WHERE company_id = 1
  AND role = 'assistant'
GROUP BY message_type
ORDER BY tokens_totais DESC;

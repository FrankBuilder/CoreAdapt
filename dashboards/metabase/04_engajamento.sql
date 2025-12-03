-- ============================================================================
-- DASHBOARD DE ENGAJAMENTO - Metabase
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Este dashboard analisa o engajamento dos leads com o robô Frank,
-- incluindo padrões de conversa, reengajamento e categorias de dor.
-- ============================================================================

-- ============================================================================
-- 4.1 KPI: TOTAL DE MENSAGENS (MÊS ATUAL)
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Total de mensagens trocadas no mês

SELECT COUNT(*) AS total_mensagens_mes
FROM corev4_chat_history
WHERE company_id = 1
  AND DATE_TRUNC('month', message_timestamp) = DATE_TRUNC('month', NOW());


-- ============================================================================
-- 4.2 KPI: LEADS ATIVOS (ÚLTIMOS 7 DIAS)
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Leads que interagiram na última semana

SELECT COUNT(DISTINCT contact_id) AS leads_ativos_7d
FROM corev4_chat_history
WHERE company_id = 1
  AND role = 'user'
  AND message_timestamp >= NOW() - INTERVAL '7 days';


-- ============================================================================
-- 4.3 KPI: MÉDIA DE MENSAGENS POR LEAD
-- ============================================================================
-- Tipo: Number (Big Number)
-- Descrição: Profundidade média das conversas

SELECT
    ROUND(COUNT(*)::numeric / NULLIF(COUNT(DISTINCT contact_id), 0), 1) AS media_msgs_por_lead
FROM corev4_chat_history
WHERE company_id = 1;


-- ============================================================================
-- 4.4 DISTRIBUIÇÃO POR CATEGORIA DE DOR
-- ============================================================================
-- Tipo: Pie Chart ou Bar Chart
-- Descrição: Leads por tipo de dor/problema identificado

SELECT
    COALESCE(pc.category_label_pt, 'Não categorizado') AS categoria_dor,
    COUNT(*) AS total_leads,
    ROUND(AVG(ls.total_score), 1) AS anum_medio,
    COUNT(*) FILTER (WHERE ls.is_qualified = true) AS qualificados
FROM corev4_lead_state ls
LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
WHERE ls.company_id = 1
  AND ls.total_score IS NOT NULL
GROUP BY pc.category_label_pt
ORDER BY total_leads DESC;


-- ============================================================================
-- 4.5 VOLUME DE MENSAGENS POR DIA DA SEMANA
-- ============================================================================
-- Tipo: Bar Chart
-- Descrição: Padrão de atividade semanal

SELECT
    CASE EXTRACT(DOW FROM message_timestamp)
        WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Segunda'
        WHEN 2 THEN 'Terça'
        WHEN 3 THEN 'Quarta'
        WHEN 4 THEN 'Quinta'
        WHEN 5 THEN 'Sexta'
        WHEN 6 THEN 'Sábado'
    END AS dia_semana,
    EXTRACT(DOW FROM message_timestamp) AS dia_ordem,
    COUNT(*) AS total_mensagens,
    COUNT(*) FILTER (WHERE role = 'user') AS msgs_leads,
    COUNT(*) FILTER (WHERE role = 'assistant') AS msgs_frank
FROM corev4_chat_history
WHERE company_id = 1
  AND message_timestamp >= NOW() - INTERVAL '30 days'
GROUP BY EXTRACT(DOW FROM message_timestamp)
ORDER BY dia_ordem;


-- ============================================================================
-- 4.6 VOLUME DE MENSAGENS POR HORA DO DIA
-- ============================================================================
-- Tipo: Bar Chart ou Heatmap
-- Descrição: Padrão de atividade por hora

SELECT
    EXTRACT(HOUR FROM message_timestamp AT TIME ZONE 'America/Sao_Paulo') AS hora,
    COUNT(*) AS total_mensagens
FROM corev4_chat_history
WHERE company_id = 1
  AND message_timestamp >= NOW() - INTERVAL '30 days'
GROUP BY EXTRACT(HOUR FROM message_timestamp AT TIME ZONE 'America/Sao_Paulo')
ORDER BY hora;


-- ============================================================================
-- 4.7 TIPOS DE MÍDIA NAS CONVERSAS
-- ============================================================================
-- Tipo: Pie Chart
-- Descrição: Distribuição de tipos de mensagem

SELECT
    CASE
        WHEN message_type = 'audio' THEN 'Áudio'
        WHEN message_type = 'image' THEN 'Imagem'
        WHEN message_type = 'video' THEN 'Vídeo'
        WHEN message_type = 'document' THEN 'Documento'
        ELSE 'Texto'
    END AS tipo_midia,
    COUNT(*) AS total,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER () * 100, 1) AS percentual
FROM corev4_chat_history
WHERE company_id = 1
  AND role = 'user'
GROUP BY message_type
ORDER BY total DESC;


-- ============================================================================
-- 4.8 LEADS REENGAJADOS (VOLTARAM APÓS 48H+)
-- ============================================================================
-- Tipo: Line Chart
-- Descrição: Leads que voltaram a interagir após período de silêncio

WITH user_messages AS (
    SELECT
        contact_id,
        message_timestamp,
        LAG(message_timestamp) OVER (
            PARTITION BY contact_id ORDER BY message_timestamp
        ) AS msg_anterior
    FROM corev4_chat_history
    WHERE company_id = 1
      AND role = 'user'
),
reengajamentos AS (
    SELECT
        contact_id,
        message_timestamp,
        EXTRACT(EPOCH FROM (message_timestamp - msg_anterior)) / 3600 AS gap_horas
    FROM user_messages
    WHERE msg_anterior IS NOT NULL
      AND EXTRACT(EPOCH FROM (message_timestamp - msg_anterior)) / 3600 > 48
)
SELECT
    DATE_TRUNC('week', message_timestamp)::date AS semana,
    COUNT(*) AS total_reengajamentos,
    COUNT(DISTINCT contact_id) AS leads_unicos,
    ROUND(AVG(gap_horas), 1) AS gap_medio_horas
FROM reengajamentos
WHERE message_timestamp >= NOW() - INTERVAL '3 months'
GROUP BY DATE_TRUNC('week', message_timestamp)
ORDER BY semana ASC;


-- ============================================================================
-- 4.9 TEMPO DE RESPOSTA DO FRANK
-- ============================================================================
-- Tipo: Number ou Histogram
-- Descrição: Tempo médio de resposta do bot

WITH mensagens_ordenadas AS (
    SELECT
        contact_id,
        role,
        message_timestamp,
        LAG(message_timestamp) OVER (
            PARTITION BY contact_id ORDER BY message_timestamp
        ) AS ts_anterior,
        LAG(role) OVER (
            PARTITION BY contact_id ORDER BY message_timestamp
        ) AS role_anterior
    FROM corev4_chat_history
    WHERE company_id = 1
)
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (message_timestamp - ts_anterior))), 1) AS tempo_resposta_segundos,
    ROUND(AVG(EXTRACT(EPOCH FROM (message_timestamp - ts_anterior))) / 60, 2) AS tempo_resposta_minutos
FROM mensagens_ordenadas
WHERE role = 'assistant'
  AND role_anterior = 'user'
  AND EXTRACT(EPOCH FROM (message_timestamp - ts_anterior)) < 3600; -- Ignora gaps > 1h


-- ============================================================================
-- 4.10 PROFUNDIDADE DAS CONVERSAS
-- ============================================================================
-- Tipo: Histogram ou Bar Chart
-- Descrição: Distribuição de leads por quantidade de mensagens

WITH msgs_por_lead AS (
    SELECT
        contact_id,
        COUNT(*) AS total_msgs
    FROM corev4_chat_history
    WHERE company_id = 1
    GROUP BY contact_id
)
SELECT
    CASE
        WHEN total_msgs <= 5 THEN '1-5 msgs'
        WHEN total_msgs <= 10 THEN '6-10 msgs'
        WHEN total_msgs <= 20 THEN '11-20 msgs'
        WHEN total_msgs <= 50 THEN '21-50 msgs'
        ELSE '50+ msgs'
    END AS faixa_mensagens,
    COUNT(*) AS total_leads,
    ROUND(AVG(total_msgs), 1) AS media_msgs
FROM msgs_por_lead
GROUP BY
    CASE
        WHEN total_msgs <= 5 THEN '1-5 msgs'
        WHEN total_msgs <= 10 THEN '6-10 msgs'
        WHEN total_msgs <= 20 THEN '11-20 msgs'
        WHEN total_msgs <= 50 THEN '21-50 msgs'
        ELSE '50+ msgs'
    END
ORDER BY
    CASE
        WHEN faixa_mensagens = '1-5 msgs' THEN 1
        WHEN faixa_mensagens = '6-10 msgs' THEN 2
        WHEN faixa_mensagens = '11-20 msgs' THEN 3
        WHEN faixa_mensagens = '21-50 msgs' THEN 4
        ELSE 5
    END;


-- ============================================================================
-- 4.11 TAXA DE OPT-OUT
-- ============================================================================
-- Tipo: Number (Big Number) com sufixo %
-- Descrição: Percentual de leads que pediram para sair

SELECT
    COUNT(*) FILTER (WHERE opt_out = true) AS total_opt_outs,
    COUNT(*) AS total_leads,
    ROUND(
        COUNT(*) FILTER (WHERE opt_out = true)::numeric /
        NULLIF(COUNT(*), 0) * 100,
        2
    ) AS taxa_opt_out_pct
FROM corev4_contacts
WHERE company_id = 1;


-- ============================================================================
-- 4.12 CONVERSÃO POR CATEGORIA DE DOR
-- ============================================================================
-- Tipo: Table ou Bar Chart
-- Descrição: Taxa de qualificação e reunião por categoria de dor

SELECT
    COALESCE(pc.category_label_pt, 'Não categorizado') AS categoria,
    COUNT(*) AS total_leads,
    COUNT(*) FILTER (WHERE ls.is_qualified = true) AS qualificados,
    ROUND(
        COUNT(*) FILTER (WHERE ls.is_qualified = true)::numeric /
        NULLIF(COUNT(*), 0) * 100,
        1
    ) AS taxa_qualificacao_pct,
    COUNT(DISTINCT sm.id) AS reunioes_agendadas,
    ROUND(
        COUNT(DISTINCT sm.id)::numeric /
        NULLIF(COUNT(*), 0) * 100,
        1
    ) AS taxa_reuniao_pct
FROM corev4_lead_state ls
LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
LEFT JOIN corev4_scheduled_meetings sm ON ls.contact_id = sm.contact_id
    AND sm.status IN ('scheduled', 'confirmed', 'completed')
WHERE ls.company_id = 1
GROUP BY pc.category_label_pt
ORDER BY total_leads DESC;

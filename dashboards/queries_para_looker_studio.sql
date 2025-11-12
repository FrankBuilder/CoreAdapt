-- ============================================================================
-- QUERIES SQL PARA LOOKER STUDIO (via Google Sheets)
-- ============================================================================
-- Queries otimizadas para exportar como CSV e importar no Google Sheets
-- Formato: Tabelas planas (sem UNION, sem queries complexas)
-- ============================================================================

-- ============================================================================
-- QUERY 1: DADOS PRINCIPAIS DE LEADS
-- ============================================================================
-- Use esta query para a ABA principal "Leads" no Google Sheets
-- Contém todos os dados essenciais para dashboards

SELECT
    -- Identificação
    c.id,
    c.full_name AS nome_completo,
    c.email,
    c.whatsapp,
    c.phone_number AS telefone,

    -- Datas
    c.created_at AS data_criacao,
    c.last_interaction_at AS ultima_interacao,
    EXTRACT(EPOCH FROM (NOW() - c.last_interaction_at))/3600 AS horas_desde_ultima_interacao,
    DATE_TRUNC('month', c.created_at) AS mes_criacao,
    DATE_TRUNC('week', c.created_at) AS semana_criacao,

    -- Status
    c.is_active AS ativo,
    c.opt_out AS opt_out,
    CASE
        WHEN c.opt_out THEN 'Opt-Out'
        WHEN NOT c.is_active THEN 'Inativo'
        ELSE 'Ativo'
    END AS status_label,

    -- Origem e UTM
    c.origin_source AS origem,
    c.sector AS setor,
    COALESCE(c.utm_source, 'Orgânico') AS utm_source,
    COALESCE(c.utm_medium, 'Direto') AS utm_medium,
    COALESCE(c.utm_campaign, 'Sem Campanha') AS utm_campaign,
    COALESCE(c.utm_adgroup, 'N/A') AS utm_adgroup,
    COALESCE(c.utm_creative, 'N/A') AS utm_creative,

    -- ANUM Scores
    ROUND(COALESCE(ls.total_score, 0)::numeric, 1) AS anum_total,
    ROUND(COALESCE(ls.authority_score, 0)::numeric, 1) AS anum_authority,
    ROUND(COALESCE(ls.need_score, 0)::numeric, 1) AS anum_need,
    ROUND(COALESCE(ls.urgency_score, 0)::numeric, 1) AS anum_urgency,
    ROUND(COALESCE(ls.money_score, 0)::numeric, 1) AS anum_money,

    -- Qualificação
    COALESCE(ls.qualification_stage, 'Não Analisado') AS estagio_qualificacao,
    CASE
        WHEN ls.is_qualified = true THEN 'Sim'
        WHEN ls.is_qualified = false THEN 'Não'
        ELSE 'Pendente'
    END AS qualificado,

    CASE
        WHEN ls.total_score >= 85 THEN 'Highly Qualified (85+)'
        WHEN ls.total_score >= 70 THEN 'Qualified (70-84)'
        WHEN ls.total_score >= 50 THEN 'Developing (50-69)'
        WHEN ls.total_score >= 30 THEN 'Developing (30-49)'
        WHEN ls.total_score < 30 THEN 'Pre-qualified (<30)'
        ELSE 'Sem Score'
    END AS faixa_anum,

    ls.status AS lead_state_status,
    ls.analysis_count AS qtd_analises,
    ls.last_analyzed_at AS ultima_analise_em,

    -- Dor principal
    pc.category_label_pt AS categoria_dor,
    ls.main_pain_detail AS detalhe_dor,

    -- Reunião
    CASE
        WHEN EXISTS (
            SELECT 1 FROM corev4_scheduled_meetings sm
            WHERE sm.contact_id = c.id
            AND sm.meeting_date > NOW()
            AND sm.status != 'cancelled'
        ) THEN 'Sim'
        ELSE 'Não'
    END AS tem_reuniao_futura,

    CASE
        WHEN EXISTS (
            SELECT 1 FROM corev4_scheduled_meetings sm
            WHERE sm.contact_id = c.id
            AND sm.meeting_completed = true
        ) THEN 'Sim'
        ELSE 'Não'
    END AS teve_reuniao_realizada,

    -- Campanha de follow-up
    fc.status AS campanha_status,
    fc.steps_completed AS follow_ups_completados,
    fc.total_steps AS follow_ups_total,
    ROUND((fc.steps_completed::numeric / NULLIF(fc.total_steps, 0)::numeric) * 100, 1) AS follow_up_progresso_pct,
    fc.should_continue AS campanha_ativa,
    fc.stopped_reason AS campanha_motivo_parada,

    -- Extras
    ce.interactions AS total_interacoes,
    ce.audio_response AS aceita_audio,
    ce.text_response AS aceita_texto

FROM corev4_contacts c
LEFT JOIN corev4_companies comp ON c.company_id = comp.id
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
LEFT JOIN corev4_contact_extras ce ON c.id = ce.contact_id
LEFT JOIN corev4_followup_campaigns fc ON c.id = fc.contact_id

ORDER BY c.created_at DESC;


-- ============================================================================
-- QUERY 2: FOLLOW-UPS DETALHADOS
-- ============================================================================
-- Use esta query para uma ABA "Follow-ups" separada

SELECT
    -- Identificação
    fe.id AS execution_id,
    fe.contact_id,
    c.full_name AS nome_lead,

    -- Passo
    fe.step AS passo,
    fe.total_steps AS total_passos,
    CONCAT('Passo ', fe.step, '/', fe.total_steps) AS passo_label,

    -- Timing
    fe.scheduled_at AS agendado_para,
    fe.sent_at AS enviado_em,
    fe.executed AS foi_executado,
    fe.should_send AS deve_enviar,

    -- Status interpretado
    CASE
        WHEN fe.executed = true AND fe.sent_at IS NOT NULL THEN 'Enviado'
        WHEN fe.executed = true AND fe.sent_at IS NULL THEN 'Executado (sem envio)'
        WHEN fe.should_send = false THEN 'Cancelado'
        WHEN fe.scheduled_at > NOW() THEN 'Agendado'
        WHEN fe.scheduled_at <= NOW() AND fe.executed = false THEN 'Atrasado'
        ELSE 'Pendente'
    END AS status,

    -- ANUM no momento
    ROUND(COALESCE(fe.anum_at_execution, 0)::numeric, 1) AS anum_no_envio,

    -- Contexto
    fe.decision_reason AS razao_decisao,
    LEFT(fe.generated_message, 200) AS mensagem_preview,

    -- Campanha
    fc.status AS campanha_status,

    -- Lead info
    ls.total_score AS anum_atual_lead,
    ls.qualification_stage AS estagio_lead,

    -- Datas
    DATE_TRUNC('day', fe.scheduled_at) AS data_agendamento,
    DATE_TRUNC('day', fe.sent_at) AS data_envio,
    c.created_at AS lead_criado_em

FROM corev4_followup_executions fe
INNER JOIN corev4_contacts c ON fe.contact_id = c.id
LEFT JOIN corev4_followup_campaigns fc ON fe.campaign_id = fc.id
LEFT JOIN corev4_lead_state ls ON fe.contact_id = ls.contact_id

ORDER BY fe.scheduled_at DESC;


-- ============================================================================
-- QUERY 3: REUNIÕES (MEETINGS)
-- ============================================================================
-- Use esta query para uma ABA "Reuniões"

SELECT
    -- Identificação
    sm.id AS meeting_id,
    sm.contact_id,
    c.full_name AS nome_lead,
    c.email AS email_lead,

    -- Data e hora
    sm.meeting_date AS data_reuniao,
    sm.meeting_end_date AS fim_reuniao,
    sm.meeting_duration_minutes AS duracao_minutos,
    DATE_TRUNC('day', sm.meeting_date) AS dia_reuniao,
    DATE_TRUNC('month', sm.meeting_date) AS mes_reuniao,
    EXTRACT(HOUR FROM sm.meeting_date) AS hora_reuniao,

    -- Status
    sm.status AS status,
    CASE
        WHEN sm.meeting_completed = true THEN 'Realizada'
        WHEN sm.no_show = true THEN 'No-Show'
        WHEN sm.status = 'cancelled' THEN 'Cancelada'
        WHEN sm.meeting_date > NOW() THEN 'Agendada (Futura)'
        WHEN sm.meeting_date <= NOW() AND sm.meeting_completed = false THEN 'Pendente Confirmação'
        ELSE 'Desconhecido'
    END AS status_label,

    sm.meeting_completed AS foi_realizada,
    sm.meeting_completed_at AS realizada_em,
    sm.no_show AS foi_no_show,
    sm.no_show_reported_at AS no_show_em,

    -- Tipo e local
    sm.meeting_type AS tipo,
    sm.meeting_timezone AS timezone,
    sm.cal_location AS localizacao,
    sm.cal_meeting_url AS url_reuniao,

    -- Cal.com
    sm.cal_event_title AS titulo,
    sm.cal_attendee_name AS participante_nome,
    sm.cal_attendee_email AS participante_email,

    -- ANUM no momento do agendamento
    ROUND(COALESCE(sm.anum_score_at_booking, 0)::numeric, 1) AS anum_ao_agendar,
    ROUND(COALESCE(sm.authority_score, 0)::numeric, 1) AS authority_ao_agendar,
    ROUND(COALESCE(sm.need_score, 0)::numeric, 1) AS need_ao_agendar,
    ROUND(COALESCE(sm.urgency_score, 0)::numeric, 1) AS urgency_ao_agendar,
    ROUND(COALESCE(sm.money_score, 0)::numeric, 1) AS money_ao_agendar,
    sm.qualification_stage AS estagio_ao_agendar,
    sm.pain_category AS dor_ao_agendar,

    -- ANUM atual do lead
    ROUND(COALESCE(ls.total_score, 0)::numeric, 1) AS anum_atual,

    -- Resumo
    sm.conversation_summary AS resumo_conversa,
    sm.meeting_notes AS notas,
    sm.meeting_outcome AS resultado,
    sm.next_action AS proxima_acao,

    -- Lembretes
    sm.reminder_24h_sent AS lembrete_24h_enviado,
    sm.reminder_1h_sent AS lembrete_1h_enviado,

    -- Lead info
    c.origin_source AS origem_lead,
    c.utm_source AS utm_source_lead,
    c.created_at AS lead_criado_em

FROM corev4_scheduled_meetings sm
INNER JOIN corev4_contacts c ON sm.contact_id = c.id
LEFT JOIN corev4_lead_state ls ON sm.contact_id = ls.contact_id

ORDER BY sm.meeting_date DESC;


-- ============================================================================
-- QUERY 4: ATIVIDADE DE MENSAGENS (ÚLTIMOS 90 DIAS)
-- ============================================================================
-- Use esta query para análise de atividade ao longo do tempo

SELECT
    DATE_TRUNC('day', ch.message_timestamp) AS dia,
    DATE_TRUNC('week', ch.message_timestamp) AS semana,
    DATE_TRUNC('month', ch.message_timestamp) AS mes,

    COUNT(*) AS total_mensagens,
    COUNT(*) FILTER (WHERE ch.role = 'user') AS mensagens_lead,
    COUNT(*) FILTER (WHERE ch.role = 'assistant') AS mensagens_bot,
    COUNT(*) FILTER (WHERE ch.role = 'system') AS mensagens_sistema,

    COUNT(*) FILTER (WHERE ch.has_media = true) AS mensagens_com_midia,
    COUNT(*) FILTER (WHERE ch.message_type = 'audio') AS audios,
    COUNT(*) FILTER (WHERE ch.message_type = 'image') AS imagens,
    COUNT(*) FILTER (WHERE ch.message_type = 'video') AS videos,

    COUNT(DISTINCT ch.contact_id) AS leads_unicos_ativos,

    SUM(ch.tokens_used) AS tokens_consumidos,
    ROUND(SUM(ch.cost_usd)::numeric, 4) AS custo_usd,
    ROUND(AVG(ch.tokens_used) FILTER (WHERE ch.role = 'assistant')::numeric, 0) AS tokens_medios_por_resposta

FROM corev4_chat_history ch
WHERE ch.message_timestamp >= NOW() - INTERVAL '90 days'
GROUP BY dia, semana, mes
ORDER BY dia DESC;


-- ============================================================================
-- QUERY 5: CUSTO POR LEAD (TOP 50 MAIS CAROS)
-- ============================================================================
-- Use esta query para análise de custos

SELECT
    c.id AS contact_id,
    c.full_name AS nome,
    c.email,

    -- Mensagens
    COUNT(ch.id) AS total_mensagens,
    COUNT(ch.id) FILTER (WHERE ch.role = 'user') AS mensagens_enviadas,
    COUNT(ch.id) FILTER (WHERE ch.role = 'assistant') AS mensagens_recebidas,

    -- Tokens e custos
    SUM(ch.tokens_used) AS tokens_totais,
    ROUND(SUM(ch.cost_usd)::numeric, 4) AS custo_total_usd,
    ROUND((SUM(ch.cost_usd) / NULLIF(COUNT(ch.id), 0))::numeric, 6) AS custo_por_mensagem,

    -- ANUM
    ROUND(COALESCE(ls.total_score, 0)::numeric, 1) AS anum_score,
    ls.qualification_stage AS estagio,
    CASE
        WHEN ls.is_qualified = true THEN 'Sim'
        ELSE 'Não'
    END AS qualificado,

    -- ROI
    CASE
        WHEN EXISTS (
            SELECT 1 FROM corev4_scheduled_meetings sm
            WHERE sm.contact_id = c.id
            AND sm.meeting_completed = true
        ) THEN 'Sim'
        ELSE 'Não'
    END AS teve_reuniao,

    -- Custo vs Resultado
    CASE
        WHEN ls.total_score >= 70 THEN 'Qualified'
        WHEN ls.total_score >= 30 THEN 'Developing'
        WHEN ls.total_score < 30 THEN 'Pre-qualified'
        ELSE 'Não Analisado'
    END AS categoria_anum

FROM corev4_contacts c
INNER JOIN corev4_chat_history ch ON c.id = ch.contact_id
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id

GROUP BY c.id, c.full_name, c.email, ls.total_score, ls.qualification_stage, ls.is_qualified
HAVING SUM(ch.cost_usd) > 0
ORDER BY custo_total_usd DESC
LIMIT 50;


-- ============================================================================
-- QUERY 6: KPIs AGREGADOS (PARA SCORECARDS)
-- ============================================================================
-- Use esta query para criar scorecards (big numbers) no Looker Studio

SELECT
    -- Total de leads
    COUNT(DISTINCT c.id) AS total_leads,
    COUNT(DISTINCT c.id) FILTER (WHERE c.is_active = true) AS leads_ativos,
    COUNT(DISTINCT c.id) FILTER (WHERE c.opt_out = true) AS leads_opt_out,

    -- ANUM
    ROUND(AVG(ls.total_score) FILTER (WHERE ls.total_score IS NOT NULL)::numeric, 1) AS anum_medio_geral,
    COUNT(DISTINCT ls.contact_id) FILTER (WHERE ls.is_qualified = true) AS leads_qualificados,
    ROUND(
        (COUNT(DISTINCT ls.contact_id) FILTER (WHERE ls.is_qualified = true)::numeric /
        NULLIF(COUNT(DISTINCT c.id), 0) * 100),
        1
    ) AS taxa_qualificacao_pct,

    -- Reuniões
    COUNT(DISTINCT sm.id) AS total_reunioes_agendadas,
    COUNT(DISTINCT sm.id) FILTER (WHERE sm.meeting_completed = true) AS reunioes_realizadas,
    COUNT(DISTINCT sm.id) FILTER (WHERE sm.no_show = true) AS reunioes_no_show,
    COUNT(DISTINCT sm.id) FILTER (WHERE sm.meeting_date > NOW()) AS reunioes_futuras,
    ROUND(
        (COUNT(DISTINCT sm.id) FILTER (WHERE sm.meeting_completed = true)::numeric /
        NULLIF(COUNT(DISTINCT sm.id), 0) * 100),
        1
    ) AS taxa_comparecimento_pct,

    -- Follow-ups
    COUNT(DISTINCT fc.id) AS campanhas_follow_up,
    COUNT(DISTINCT fc.id) FILTER (WHERE fc.status = 'active') AS campanhas_ativas,
    COUNT(DISTINCT fe.id) FILTER (WHERE fe.executed = true) AS follow_ups_enviados,
    ROUND(AVG(fc.steps_completed::numeric / NULLIF(fc.total_steps, 0) * 100), 1) AS progresso_medio_campanha_pct,

    -- Mensagens e custos
    COUNT(DISTINCT ch.id) AS total_mensagens,
    SUM(ch.tokens_used) AS total_tokens,
    ROUND(SUM(ch.cost_usd)::numeric, 2) AS custo_total_usd,
    ROUND((SUM(ch.cost_usd) / NULLIF(COUNT(DISTINCT c.id), 0))::numeric, 4) AS custo_por_lead

FROM corev4_contacts c
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
LEFT JOIN corev4_scheduled_meetings sm ON c.id = sm.contact_id
LEFT JOIN corev4_followup_campaigns fc ON c.id = fc.contact_id
LEFT JOIN corev4_followup_executions fe ON c.id = fe.contact_id
LEFT JOIN corev4_chat_history ch ON c.id = ch.contact_id;


-- ============================================================================
-- QUERY 7: ANÁLISE POR ORIGEM (UTM)
-- ============================================================================
-- Use para entender de onde vêm os melhores leads

SELECT
    COALESCE(c.utm_source, 'Orgânico') AS fonte,
    COALESCE(c.utm_medium, 'Direto') AS meio,
    COALESCE(c.utm_campaign, 'Sem Campanha') AS campanha,

    COUNT(DISTINCT c.id) AS total_leads,

    ROUND(AVG(ls.total_score) FILTER (WHERE ls.total_score IS NOT NULL)::numeric, 1) AS anum_medio,

    COUNT(DISTINCT c.id) FILTER (WHERE ls.is_qualified = true) AS leads_qualificados,

    ROUND(
        (COUNT(DISTINCT c.id) FILTER (WHERE ls.is_qualified = true)::numeric /
        NULLIF(COUNT(DISTINCT c.id), 0) * 100),
        1
    ) AS taxa_qualificacao_pct,

    COUNT(DISTINCT sm.id) FILTER (WHERE sm.meeting_completed = true) AS reunioes_realizadas,

    ROUND(SUM(ch.cost_usd)::numeric, 2) AS custo_total_usd,

    ROUND((SUM(ch.cost_usd) / NULLIF(COUNT(DISTINCT c.id), 0))::numeric, 4) AS custo_por_lead

FROM corev4_contacts c
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
LEFT JOIN corev4_scheduled_meetings sm ON c.id = sm.contact_id
LEFT JOIN corev4_chat_history ch ON c.id = ch.contact_id

GROUP BY fonte, meio, campanha
HAVING COUNT(DISTINCT c.id) >= 5  -- Apenas origens com 5+ leads
ORDER BY total_leads DESC
LIMIT 30;


-- ============================================================================
-- INSTRUÇÕES DE USO
-- ============================================================================
--
-- 1. Execute cada query no Supabase SQL Editor
-- 2. Clique em "Download CSV" para cada uma
-- 3. Importe cada CSV em uma aba diferente do Google Sheets:
--    - Aba "Leads" → Query 1
--    - Aba "Follow-ups" → Query 2
--    - Aba "Reuniões" → Query 3
--    - Aba "Atividade" → Query 4
--    - Aba "Custos" → Query 5
--    - Aba "KPIs" → Query 6
--    - Aba "Origens" → Query 7
--
-- 4. No Looker Studio:
--    - Adicione o Google Sheets como fonte de dados
--    - Crie visualizações para cada aba
--    - Monte seu dashboard!
--
-- Para automação via Apps Script, veja: LOOKER_STUDIO_GUIA_COMPLETO.md
-- ============================================================================

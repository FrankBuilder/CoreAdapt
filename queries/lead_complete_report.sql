-- ============================================================================
-- RELATÓRIO COMPLETO DE LEAD - CoreAdapt v4
-- ============================================================================
-- Extração completa da situação de um lead específico incluindo:
-- - Dados do contato e origem
-- - Score ANUM detalhado e histórico de qualificação
-- - Campanha de follow-up e status de cada passo
-- - Histórico completo de mensagens
-- - Reuniões agendadas/realizadas
-- - Métricas de engajamento e reengajamento
-- - Timeline completa de interações
-- ============================================================================

-- PARÂMETROS DE ENTRADA:
-- @contact_id: ID do contato no banco (corev4_contacts.id)
-- OU
-- @whatsapp: Número do WhatsApp (formato: "5585999855443@s.whatsapp.net")

-- ============================================================================
-- SEÇÃO 1: INFORMAÇÕES BÁSICAS DO CONTATO E SCORE ANUM
-- ============================================================================

WITH contact_base AS (
    SELECT
        c.id AS contact_id,
        c.company_id,
        c.full_name,
        c.whatsapp,
        c.phone_number,
        c.email,
        c.origin_source,
        c.sector,
        c.tags,
        c.opt_out,
        c.is_active,
        c.last_interaction_at,
        c.created_at AS contact_created_at,

        -- UTM tracking
        c.utm_source,
        c.utm_medium,
        c.utm_campaign,
        c.utm_adgroup,
        c.utm_creative,

        -- Company info
        comp.name AS company_name,
        comp.bot_name,

        -- Contact preferences
        ce.audio_response,
        ce.text_response,
        ce.interactions AS total_interactions,
        ce.pipeline_id,

        -- ANUM Scores
        ls.authority_score,
        ls.need_score,
        ls.urgency_score,
        ls.money_score,
        ls.total_score AS anum_total_score,
        ls.qualification_stage,
        ls.is_qualified,
        ls.status AS lead_status,
        ls.analysis_count,
        ls.last_analyzed_at,
        ls.analyzed_at AS first_analyzed_at,

        -- Pain category
        pc.category_label_pt AS pain_category,
        ls.main_pain_detail,

        -- Session info
        ch.conversation_open,
        ch.batch_collecting,
        ch.last_message_ts,
        ch.last_lead_message_ts,
        ch.last_agent_message_ts

    FROM corev4_contacts c
    LEFT JOIN corev4_companies comp ON c.company_id = comp.id
    LEFT JOIN corev4_contact_extras ce ON c.id = ce.contact_id
    LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
    LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
    LEFT JOIN corev4_chats ch ON c.id = ch.contact_id AND c.company_id = ch.company_id
    WHERE
        -- Use um dos critérios abaixo:
        c.id = :contact_id  -- Substitua pelo ID do contato
        -- OR c.whatsapp = :whatsapp  -- OU substitua pelo WhatsApp
)

-- ============================================================================
-- SEÇÃO 2: CAMPANHA DE FOLLOW-UP - STATUS GERAL
-- ============================================================================

, followup_campaign_info AS (
    SELECT
        fc.contact_id,
        fc.id AS campaign_id,
        fc.status AS campaign_status,
        fc.steps_completed,
        fc.total_steps,
        fc.last_step_sent_at,
        fc.should_continue,
        fc.stopped_reason,
        fc.pause_reason,
        fc.created_at AS campaign_created_at,
        fc.updated_at AS campaign_updated_at,

        -- Config da campanha
        fconf.qualification_threshold,
        fconf.disqualification_threshold,

        -- Métricas calculadas
        ROUND((fc.steps_completed::numeric / NULLIF(fc.total_steps, 0)::numeric) * 100, 2) AS campaign_progress_pct,

        -- Status interpretado
        CASE
            WHEN fc.status = 'completed' THEN '✓ Campanha Completada'
            WHEN fc.status = 'stopped' THEN '⊗ Campanha Parada: ' || COALESCE(fc.stopped_reason, 'não especificado')
            WHEN fc.should_continue = false THEN '⊗ Campanha Pausada: ' || COALESCE(fc.pause_reason, 'não especificado')
            WHEN fc.status = 'active' THEN '→ Campanha Ativa'
            ELSE '? Status Desconhecido'
        END AS campaign_status_label

    FROM corev4_followup_campaigns fc
    LEFT JOIN corev4_followup_configs fconf ON fc.config_id = fconf.id
    WHERE fc.contact_id IN (SELECT contact_id FROM contact_base)
)

-- ============================================================================
-- SEÇÃO 3: FOLLOW-UP EXECUTIONS - DETALHAMENTO DE CADA PASSO
-- ============================================================================

, followup_executions_detail AS (
    SELECT
        fe.contact_id,
        fe.campaign_id,
        fe.step,
        fe.total_steps,
        fe.scheduled_at,
        fe.executed,
        fe.sent_at,
        fe.should_send,
        fe.decision_reason,
        fe.anum_at_execution,
        fe.generated_message,
        fe.evolution_message_id,

        -- Status interpretado do passo
        CASE
            WHEN fe.executed = true AND fe.sent_at IS NOT NULL THEN '✓ Enviado'
            WHEN fe.executed = true AND fe.sent_at IS NULL THEN '✗ Marcado como executado mas sem envio'
            WHEN fe.should_send = false THEN '⊗ Cancelado: ' || COALESCE(fe.decision_reason, 'não especificado')
            WHEN fe.scheduled_at > NOW() THEN '⏰ Agendado para ' || TO_CHAR(fe.scheduled_at, 'DD/MM/YYYY HH24:MI')
            WHEN fe.scheduled_at <= NOW() AND fe.executed = false THEN '⚠ Atrasado (deveria ter sido enviado)'
            ELSE '? Status Desconhecido'
        END AS step_status_label,

        -- Tempo até/desde a execução
        CASE
            WHEN fe.executed = true THEN
                'Enviado há ' ||
                EXTRACT(EPOCH FROM (NOW() - fe.sent_at))/3600 || ' horas'
            WHEN fe.scheduled_at > NOW() THEN
                'Faltam ' ||
                EXTRACT(EPOCH FROM (fe.scheduled_at - NOW()))/3600 || ' horas'
            ELSE
                'Atrasado há ' ||
                EXTRACT(EPOCH FROM (NOW() - fe.scheduled_at))/3600 || ' horas'
        END AS time_info,

        fe.created_at AS step_created_at

    FROM corev4_followup_executions fe
    WHERE fe.contact_id IN (SELECT contact_id FROM contact_base)
    ORDER BY fe.step ASC
)

-- ============================================================================
-- SEÇÃO 4: REUNIÕES AGENDADAS/REALIZADAS
-- ============================================================================

, meetings_info AS (
    SELECT
        sm.contact_id,
        sm.id AS meeting_id,
        sm.meeting_date,
        sm.meeting_end_date,
        sm.meeting_duration_minutes,
        sm.meeting_type,
        sm.meeting_timezone,
        sm.status AS meeting_status,

        -- Cal.com info
        sm.cal_booking_uid,
        sm.cal_event_title,
        sm.cal_attendee_email,
        sm.cal_attendee_name,
        sm.cal_meeting_url,
        sm.cal_location,

        -- ANUM no momento do agendamento
        sm.anum_score_at_booking,
        sm.authority_score AS authority_at_booking,
        sm.need_score AS need_at_booking,
        sm.urgency_score AS urgency_at_booking,
        sm.money_score AS money_at_booking,
        sm.qualification_stage AS qualification_at_booking,
        sm.pain_category AS pain_at_booking,

        -- Resumo da conversa
        sm.conversation_summary,

        -- Lembretes
        sm.reminder_24h_sent,
        sm.reminder_24h_sent_at,
        sm.reminder_1h_sent,
        sm.reminder_1h_sent_at,

        -- Resultado
        sm.meeting_completed,
        sm.meeting_completed_at,
        sm.no_show,
        sm.no_show_reported_at,
        sm.meeting_notes,
        sm.meeting_outcome,
        sm.next_action,

        -- Status interpretado
        CASE
            WHEN sm.meeting_completed = true THEN '✓ Realizada em ' || TO_CHAR(sm.meeting_completed_at, 'DD/MM/YYYY')
            WHEN sm.no_show = true THEN '✗ No-show em ' || TO_CHAR(sm.no_show_reported_at, 'DD/MM/YYYY')
            WHEN sm.status = 'cancelled' THEN '⊗ Cancelada: ' || COALESCE(sm.cal_cancel_reason, 'não especificado')
            WHEN sm.status = 'rescheduled' THEN '⟲ Remarcada (UID: ' || sm.cal_reschedule_uid || ')'
            WHEN sm.meeting_date > NOW() THEN '⏰ Agendada para ' || TO_CHAR(sm.meeting_date, 'DD/MM/YYYY HH24:MI')
            WHEN sm.meeting_date <= NOW() AND sm.meeting_completed = false THEN '⚠ Aguardando confirmação'
            ELSE '? Status Desconhecido'
        END AS meeting_status_label,

        sm.created_at AS meeting_created_at,
        sm.updated_at AS meeting_updated_at

    FROM corev4_scheduled_meetings sm
    WHERE sm.contact_id IN (SELECT contact_id FROM contact_base)
    ORDER BY sm.meeting_date DESC
)

-- ============================================================================
-- SEÇÃO 5: HISTÓRICO DE MENSAGENS COMPLETO
-- ============================================================================

, message_history AS (
    SELECT
        ch.contact_id,
        ch.id AS message_id,
        ch.session_id,
        ch.role,
        ch.message,
        ch.message_type,
        ch.has_media,
        ch.media_url,
        ch.media_mime_type,
        ch.tokens_used,
        ch.cost_usd,
        ch.model_used,
        ch.message_timestamp,
        ch.created_at,

        -- Formatação para exibição
        CASE ch.role
            WHEN 'user' THEN '👤 Lead'
            WHEN 'assistant' THEN '🤖 ' || COALESCE((SELECT bot_name FROM contact_base), 'Bot')
            WHEN 'system' THEN '⚙️  Sistema'
            ELSE '? ' || ch.role
        END AS role_label,

        -- Preview da mensagem
        CASE
            WHEN ch.has_media = true THEN '[' || UPPER(ch.message_type) || '] ' || LEFT(ch.message, 100)
            ELSE LEFT(ch.message, 150)
        END AS message_preview,

        -- Numeração sequencial
        ROW_NUMBER() OVER (PARTITION BY ch.contact_id ORDER BY ch.message_timestamp ASC) AS message_seq

    FROM corev4_chat_history ch
    WHERE ch.contact_id IN (SELECT contact_id FROM contact_base)
    ORDER BY ch.message_timestamp ASC
)

-- ============================================================================
-- SEÇÃO 6: ESTATÍSTICAS DE ENGAJAMENTO
-- ============================================================================

, engagement_stats AS (
    SELECT
        contact_id,
        COUNT(*) AS total_messages,
        COUNT(*) FILTER (WHERE role = 'user') AS user_messages,
        COUNT(*) FILTER (WHERE role = 'assistant') AS bot_messages,
        COUNT(*) FILTER (WHERE has_media = true) AS messages_with_media,
        MIN(message_timestamp) AS first_message_at,
        MAX(message_timestamp) AS last_message_at,
        MAX(message_timestamp) FILTER (WHERE role = 'user') AS last_user_message_at,
        MAX(message_timestamp) FILTER (WHERE role = 'assistant') AS last_bot_message_at,

        -- Cálculo de tempo desde última interação
        EXTRACT(EPOCH FROM (NOW() - MAX(message_timestamp)))/3600 AS hours_since_last_message,
        EXTRACT(EPOCH FROM (NOW() - MAX(message_timestamp) FILTER (WHERE role = 'user')))/3600 AS hours_since_last_user_message,

        -- Tokens e custos
        SUM(tokens_used) AS total_tokens_used,
        SUM(cost_usd) AS total_cost_usd,

        -- Distribuição por tipo de mídia
        COUNT(*) FILTER (WHERE message_type = 'audio') AS audio_messages,
        COUNT(*) FILTER (WHERE message_type = 'image') AS image_messages,
        COUNT(*) FILTER (WHERE message_type = 'video') AS video_messages,
        COUNT(*) FILTER (WHERE message_type = 'document') AS document_messages

    FROM message_history
    GROUP BY contact_id
)

-- ============================================================================
-- SEÇÃO 7: TIMELINE DE EVENTOS IMPORTANTES
-- ============================================================================

, timeline_events AS (
    -- Contato criado
    SELECT
        contact_id,
        contact_created_at AS event_timestamp,
        'contact_created' AS event_type,
        '🆕 Contato criado no sistema' AS event_description,
        1 AS event_order
    FROM contact_base

    UNION ALL

    -- Primeira mensagem
    SELECT
        contact_id,
        first_message_at AS event_timestamp,
        'first_message' AS event_type,
        '💬 Primeira mensagem recebida' AS event_description,
        2 AS event_order
    FROM engagement_stats

    UNION ALL

    -- Primeira análise ANUM
    SELECT
        contact_id,
        first_analyzed_at AS event_timestamp,
        'first_analysis' AS event_type,
        '📊 Primeira análise ANUM realizada (Score: ' || ROUND(anum_total_score, 1) || ')' AS event_description,
        3 AS event_order
    FROM contact_base
    WHERE first_analyzed_at IS NOT NULL

    UNION ALL

    -- Campanha de follow-up iniciada
    SELECT
        contact_id,
        campaign_created_at AS event_timestamp,
        'campaign_started' AS event_type,
        '📧 Campanha de follow-up iniciada (' || total_steps || ' passos)' AS event_description,
        4 AS event_order
    FROM followup_campaign_info

    UNION ALL

    -- Follow-ups enviados
    SELECT
        contact_id,
        sent_at AS event_timestamp,
        'followup_sent' AS event_type,
        '📤 Follow-up #' || step || ' enviado (ANUM: ' || ROUND(anum_at_execution, 1) || ')' AS event_description,
        10 + step AS event_order
    FROM followup_executions_detail
    WHERE executed = true AND sent_at IS NOT NULL

    UNION ALL

    -- Reunião agendada
    SELECT
        contact_id,
        meeting_created_at AS event_timestamp,
        'meeting_scheduled' AS event_type,
        '📅 Reunião agendada: ' || TO_CHAR(meeting_date, 'DD/MM/YYYY HH24:MI') ||
        ' (ANUM no agendamento: ' || ROUND(anum_score_at_booking, 1) || ')' AS event_description,
        50 AS event_order
    FROM meetings_info

    UNION ALL

    -- Reunião realizada
    SELECT
        contact_id,
        meeting_completed_at AS event_timestamp,
        'meeting_completed' AS event_type,
        '✓ Reunião realizada' AS event_description,
        51 AS event_order
    FROM meetings_info
    WHERE meeting_completed = true

    UNION ALL

    -- Opt-out
    SELECT
        contact_id,
        last_interaction_at AS event_timestamp,
        'opt_out' AS event_type,
        '🚫 Lead solicitou opt-out' AS event_description,
        99 AS event_order
    FROM contact_base
    WHERE opt_out = true

    ORDER BY event_timestamp ASC
)

-- ============================================================================
-- SEÇÃO 8: ANÁLISE DE REENGAJAMENTO
-- ============================================================================

, reengagement_analysis AS (
    SELECT
        mh.contact_id,

        -- Detectar reengajamentos (gaps de mais de 48h seguidos de nova mensagem do lead)
        COUNT(*) FILTER (
            WHERE mh.role = 'user'
            AND LAG(mh.message_timestamp) OVER (PARTITION BY mh.contact_id ORDER BY mh.message_timestamp) IS NOT NULL
            AND EXTRACT(EPOCH FROM (
                mh.message_timestamp -
                LAG(mh.message_timestamp) OVER (PARTITION BY mh.contact_id ORDER BY mh.message_timestamp)
            ))/3600 > 48
        ) AS reengagement_count,

        -- Detectar respostas após follow-ups
        COUNT(*) FILTER (
            WHERE mh.role = 'user'
            AND EXISTS (
                SELECT 1
                FROM followup_executions_detail fed
                WHERE fed.contact_id = mh.contact_id
                AND fed.sent_at IS NOT NULL
                AND fed.sent_at < mh.message_timestamp
                AND mh.message_timestamp < fed.sent_at + INTERVAL '24 hours'
            )
        ) AS responses_after_followup,

        -- Identificar períodos de silêncio
        MAX(
            EXTRACT(EPOCH FROM (
                mh.message_timestamp -
                LAG(mh.message_timestamp) OVER (PARTITION BY mh.contact_id ORDER BY mh.message_timestamp)
            ))/3600
        ) AS longest_silence_hours

    FROM message_history mh
    WHERE mh.role = 'user'
    GROUP BY mh.contact_id
)

-- ============================================================================
-- QUERY FINAL: CONSOLIDAÇÃO DE TODAS AS INFORMAÇÕES
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════════════' AS separator,
    '                    RELATÓRIO COMPLETO DO LEAD' AS title,
    '═══════════════════════════════════════════════════════════════════════' AS separator2,
    '' AS blank1,

    -- SEÇÃO: IDENTIFICAÇÃO
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header_id,
    '│  IDENTIFICAÇÃO DO LEAD                                              │' AS section_title_id,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer_id,
    '' AS blank2,
    cb.contact_id,
    cb.full_name,
    cb.whatsapp,
    cb.phone_number,
    cb.email,
    cb.company_name,
    '' AS blank3,

    -- SEÇÃO: STATUS ATUAL
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header_status,
    '│  STATUS ATUAL                                                       │' AS section_title_status,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer_status,
    '' AS blank4,
    CASE
        WHEN cb.opt_out = true THEN '🚫 OPT-OUT (não recebe mais mensagens)'
        WHEN cb.is_active = false THEN '⊗ INATIVO'
        WHEN cb.conversation_open = true THEN '💬 CONVERSA ATIVA'
        ELSE '✓ ATIVO'
    END AS status_geral,
    cb.lead_status AS status_lead_state,
    CONCAT('Última interação: ',
           TO_CHAR(cb.last_interaction_at, 'DD/MM/YYYY HH24:MI'),
           ' (há ',
           ROUND(EXTRACT(EPOCH FROM (NOW() - cb.last_interaction_at))/3600, 1),
           ' horas)'
    ) AS ultima_interacao,
    '' AS blank5,

    -- SEÇÃO: SCORE ANUM
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header_anum,
    '│  SCORE ANUM (QUALIFICAÇÃO)                                          │' AS section_title_anum,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer_anum,
    '' AS blank6,
    CONCAT('ANUM TOTAL: ', ROUND(cb.anum_total_score, 1), '/100') AS anum_score,
    CONCAT('  └─ Authority (Autoridade): ', ROUND(cb.authority_score, 1), '/100') AS anum_authority,
    CONCAT('  └─ Need (Necessidade): ', ROUND(cb.need_score, 1), '/100') AS anum_need,
    CONCAT('  └─ Urgency (Urgência): ', ROUND(cb.urgency_score, 1), '/100') AS anum_urgency,
    CONCAT('  └─ Money (Dinheiro): ', ROUND(cb.money_score, 1), '/100') AS anum_money,
    '' AS blank7,
    CONCAT('Estágio de Qualificação: ', UPPER(cb.qualification_stage)) AS qualification_stage,
    CASE
        WHEN cb.is_qualified = true THEN '✓ QUALIFICADO'
        ELSE '○ NÃO QUALIFICADO'
    END AS is_qualified_label,
    CONCAT('Analisado ', cb.analysis_count, ' vez(es)') AS analysis_count,
    CONCAT('Última análise: ', TO_CHAR(cb.last_analyzed_at, 'DD/MM/YYYY HH24:MI')) AS last_analysis,
    '' AS blank8,
    CONCAT('Categoria de Dor: ', COALESCE(cb.pain_category, 'Não identificada')) AS pain_category_label,
    CONCAT('Detalhes: ', COALESCE(cb.main_pain_detail, 'N/A')) AS pain_detail,
    '' AS blank9,

    -- SEÇÃO: ORIGEM E UTM
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header_origin,
    '│  ORIGEM E RASTREAMENTO                                              │' AS section_title_origin,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer_origin,
    '' AS blank10,
    CONCAT('Origem: ', cb.origin_source) AS origin_source,
    CONCAT('Setor: ', COALESCE(cb.sector, 'Não informado')) AS sector,
    CONCAT('Tags: ', COALESCE(ARRAY_TO_STRING(cb.tags, ', '), 'Nenhuma')) AS tags,
    CONCAT('UTM Source: ', COALESCE(cb.utm_source, 'N/A')) AS utm_source,
    CONCAT('UTM Medium: ', COALESCE(cb.utm_medium, 'N/A')) AS utm_medium,
    CONCAT('UTM Campaign: ', COALESCE(cb.utm_campaign, 'N/A')) AS utm_campaign,
    '' AS blank11

FROM contact_base cb;


-- ============================================================================
-- QUERY SEPARADA: CAMPANHA DE FOLLOW-UP
-- ============================================================================

SELECT
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header,
    '│  CAMPANHA DE FOLLOW-UP                                              │' AS section_title,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer,
    '' AS blank1,

    COALESCE(fci.campaign_status_label, '○ Nenhuma campanha iniciada') AS campaign_status,
    CONCAT('Progresso: ', COALESCE(fci.steps_completed, 0), '/', COALESCE(fci.total_steps, 0),
           ' passos (', COALESCE(ROUND(fci.campaign_progress_pct, 1), 0), '%)') AS campaign_progress,
    CONCAT('Último passo enviado: ',
           COALESCE(TO_CHAR(fci.last_step_sent_at, 'DD/MM/YYYY HH24:MI'), 'N/A')) AS last_step_sent,
    CONCAT('Thresholds: Qualificação ≥', fci.qualification_threshold,
           ' | Desqualificação <', fci.disqualification_threshold) AS thresholds,
    '' AS blank2

FROM contact_base cb
LEFT JOIN followup_campaign_info fci ON cb.contact_id = fci.contact_id;


-- ============================================================================
-- QUERY SEPARADA: DETALHAMENTO DOS PASSOS DE FOLLOW-UP
-- ============================================================================

SELECT
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header,
    '│  DETALHAMENTO DOS FOLLOW-UPS                                        │' AS section_title,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer,
    '' AS blank,

    CONCAT('Passo ', fed.step, '/', fed.total_steps) AS step_number,
    fed.step_status_label AS status,
    fed.time_info AS timing,
    CONCAT('ANUM na execução: ', COALESCE(ROUND(fed.anum_at_execution, 1), 'N/A')) AS anum_at_step,
    CONCAT('Agendado para: ', TO_CHAR(fed.scheduled_at, 'DD/MM/YYYY HH24:MI')) AS scheduled_time,
    CASE
        WHEN fed.executed = true THEN CONCAT('Enviado em: ', TO_CHAR(fed.sent_at, 'DD/MM/YYYY HH24:MI'))
        ELSE 'Ainda não enviado'
    END AS sent_time,
    CONCAT('Razão da decisão: ', COALESCE(fed.decision_reason, 'N/A')) AS decision_reason,
    CONCAT('ID da mensagem Evolution: ', COALESCE(fed.evolution_message_id, 'N/A')) AS evolution_id,
    CONCAT('Mensagem gerada: ', LEFT(COALESCE(fed.generated_message, 'N/A'), 200), '...') AS message_preview,
    '─────────────────────────────────────────────────────────────────────' AS separator

FROM followup_executions_detail fed
ORDER BY fed.step ASC;


-- ============================================================================
-- QUERY SEPARADA: REUNIÕES AGENDADAS/REALIZADAS
-- ============================================================================

SELECT
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header,
    '│  REUNIÕES AGENDADAS/REALIZADAS                                      │' AS section_title,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer,
    '' AS blank1,

    CASE
        WHEN COUNT(*) = 0 THEN '○ Nenhuma reunião agendada'
        ELSE NULL
    END AS no_meetings_label,

    mi.meeting_status_label AS status,
    CONCAT('Data/Hora: ', TO_CHAR(mi.meeting_date, 'DD/MM/YYYY HH24:MI'),
           ' (', mi.meeting_timezone, ')') AS meeting_datetime,
    CONCAT('Duração: ', mi.meeting_duration_minutes, ' minutos') AS duration,
    CONCAT('Tipo: ', mi.meeting_type) AS meeting_type,
    CONCAT('Participante: ', mi.cal_attendee_name, ' (', mi.cal_attendee_email, ')') AS attendee,
    CONCAT('Local: ', COALESCE(mi.cal_location, 'N/A')) AS location,
    CONCAT('URL: ', COALESCE(mi.cal_meeting_url, 'N/A')) AS meeting_url,
    '' AS blank2,

    -- ANUM no momento do agendamento
    CONCAT('ANUM no agendamento: ', ROUND(mi.anum_score_at_booking, 1)) AS anum_at_booking,
    CONCAT('  └─ Authority: ', ROUND(mi.authority_at_booking, 1)) AS auth_at_booking,
    CONCAT('  └─ Need: ', ROUND(mi.need_at_booking, 1)) AS need_at_booking,
    CONCAT('  └─ Urgency: ', ROUND(mi.urgency_at_booking, 1)) AS urgency_at_booking,
    CONCAT('  └─ Money: ', ROUND(mi.money_at_booking, 1)) AS money_at_booking,
    CONCAT('Estágio de qualificação: ', mi.qualification_at_booking) AS qual_at_booking,
    CONCAT('Categoria de dor: ', COALESCE(mi.pain_at_booking, 'N/A')) AS pain_at_booking,
    '' AS blank3,

    -- Lembretes
    CASE WHEN mi.reminder_24h_sent THEN
        CONCAT('✓ Lembrete 24h enviado em: ', TO_CHAR(mi.reminder_24h_sent_at, 'DD/MM/YYYY HH24:MI'))
    ELSE '○ Lembrete 24h não enviado' END AS reminder_24h_status,

    CASE WHEN mi.reminder_1h_sent THEN
        CONCAT('✓ Lembrete 1h enviado em: ', TO_CHAR(mi.reminder_1h_sent_at, 'DD/MM/YYYY HH24:MI'))
    ELSE '○ Lembrete 1h não enviado' END AS reminder_1h_status,
    '' AS blank4,

    -- Resultado
    CONCAT('Resumo da conversa: ', LEFT(COALESCE(mi.conversation_summary, 'N/A'), 300), '...') AS conversation_summary,
    CONCAT('Notas da reunião: ', COALESCE(mi.meeting_notes, 'N/A')) AS meeting_notes,
    CONCAT('Resultado: ', COALESCE(mi.meeting_outcome, 'N/A')) AS meeting_outcome,
    CONCAT('Próxima ação: ', COALESCE(mi.next_action, 'N/A')) AS next_action,
    '' AS blank5,

    CONCAT('UID Cal.com: ', mi.cal_booking_uid) AS cal_booking_uid,
    '═════════════════════════════════════════════════════════════════════' AS separator

FROM meetings_info mi
GROUP BY
    mi.meeting_id, mi.meeting_status_label, mi.meeting_date, mi.meeting_timezone,
    mi.meeting_duration_minutes, mi.meeting_type, mi.cal_attendee_name,
    mi.cal_attendee_email, mi.cal_location, mi.cal_meeting_url,
    mi.anum_score_at_booking, mi.authority_at_booking, mi.need_at_booking,
    mi.urgency_at_booking, mi.money_at_booking, mi.qualification_at_booking,
    mi.pain_at_booking, mi.reminder_24h_sent, mi.reminder_24h_sent_at,
    mi.reminder_1h_sent, mi.reminder_1h_sent_at, mi.conversation_summary,
    mi.meeting_notes, mi.meeting_outcome, mi.next_action, mi.cal_booking_uid
ORDER BY mi.meeting_date DESC;


-- ============================================================================
-- QUERY SEPARADA: ESTATÍSTICAS DE ENGAJAMENTO
-- ============================================================================

SELECT
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header,
    '│  ESTATÍSTICAS DE ENGAJAMENTO                                        │' AS section_title,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer,
    '' AS blank1,

    CONCAT('Total de mensagens: ', es.total_messages) AS total_messages,
    CONCAT('  └─ Mensagens do lead: ', es.user_messages) AS user_messages,
    CONCAT('  └─ Mensagens do bot: ', es.bot_messages) AS bot_messages,
    CONCAT('  └─ Mensagens com mídia: ', es.messages_with_media) AS media_messages,
    '' AS blank2,

    CONCAT('Distribuição por tipo de mídia:') AS media_distribution_label,
    CONCAT('  └─ Áudios: ', es.audio_messages) AS audio_count,
    CONCAT('  └─ Imagens: ', es.image_messages) AS image_count,
    CONCAT('  └─ Vídeos: ', es.video_messages) AS video_count,
    CONCAT('  └─ Documentos: ', es.document_messages) AS document_count,
    '' AS blank3,

    CONCAT('Primeira mensagem: ', TO_CHAR(es.first_message_at, 'DD/MM/YYYY HH24:MI')) AS first_message,
    CONCAT('Última mensagem: ', TO_CHAR(es.last_message_at, 'DD/MM/YYYY HH24:MI'),
           ' (há ', ROUND(es.hours_since_last_message, 1), ' horas)') AS last_message,
    CONCAT('Última mensagem do lead: ', TO_CHAR(es.last_user_message_at, 'DD/MM/YYYY HH24:MI'),
           ' (há ', ROUND(es.hours_since_last_user_message, 1), ' horas)') AS last_user_message,
    '' AS blank4,

    CONCAT('Total de tokens usados: ', es.total_tokens_used) AS total_tokens,
    CONCAT('Custo total (USD): $', ROUND(es.total_cost_usd, 4)) AS total_cost,
    '' AS blank5,

    -- Análise de reengajamento
    '┌─────────────────────────────────────────────────────────────────────┐' AS reengagement_header,
    '│  ANÁLISE DE REENGAJAMENTO                                           │' AS reengagement_title,
    '└─────────────────────────────────────────────────────────────────────┘' AS reengagement_footer,
    '' AS blank6,

    CONCAT('Reengajamentos detectados: ', ra.reengagement_count,
           ' (gaps >48h seguidos de nova mensagem)') AS reengagement_count,
    CONCAT('Respostas após follow-ups: ', ra.responses_after_followup) AS responses_after_followup,
    CONCAT('Maior período de silêncio: ', ROUND(ra.longest_silence_hours, 1), ' horas') AS longest_silence,
    '' AS blank7

FROM engagement_stats es
CROSS JOIN reengagement_analysis ra;


-- ============================================================================
-- QUERY SEPARADA: TIMELINE DE EVENTOS
-- ============================================================================

SELECT
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header,
    '│  TIMELINE DE EVENTOS IMPORTANTES                                    │' AS section_title,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer,
    '' AS blank,

    TO_CHAR(te.event_timestamp, 'DD/MM/YYYY HH24:MI') AS data_hora,
    te.event_description AS evento,
    CONCAT('(há ', ROUND(EXTRACT(EPOCH FROM (NOW() - te.event_timestamp))/3600, 1), ' horas)') AS tempo_decorrido

FROM timeline_events te
ORDER BY te.event_timestamp ASC;


-- ============================================================================
-- QUERY SEPARADA: ÚLTIMAS 20 MENSAGENS DA CONVERSA
-- ============================================================================

SELECT
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header,
    '│  ÚLTIMAS 20 MENSAGENS DA CONVERSA                                   │' AS section_title,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer,
    '' AS blank,

    CONCAT('#', mh.message_seq, ' - ', TO_CHAR(mh.message_timestamp, 'DD/MM HH24:MI')) AS msg_number,
    mh.role_label AS remetente,
    CASE
        WHEN mh.has_media = true THEN
            CONCAT('[', UPPER(mh.message_type), '] ', mh.message_preview)
        ELSE mh.message_preview
    END AS mensagem,
    CASE
        WHEN mh.role = 'assistant' THEN
            CONCAT('(', mh.tokens_used, ' tokens, $', ROUND(mh.cost_usd, 6), ', ', mh.model_used, ')')
        ELSE ''
    END AS metadata,
    '─────────────────────────────────────────────────────────────────────' AS separator

FROM (
    SELECT *
    FROM message_history
    ORDER BY message_timestamp DESC
    LIMIT 20
) mh
ORDER BY mh.message_timestamp ASC;


-- ============================================================================
-- QUERY OPCIONAL: HISTÓRICO COMPLETO DE MENSAGENS (pode gerar muito output)
-- ============================================================================
-- Descomente se precisar do histórico completo

/*
SELECT
    '┌─────────────────────────────────────────────────────────────────────┐' AS section_header,
    '│  HISTÓRICO COMPLETO DE MENSAGENS                                    │' AS section_title,
    '└─────────────────────────────────────────────────────────────────────┘' AS section_footer,
    '' AS blank,

    CONCAT('#', mh.message_seq) AS numero,
    TO_CHAR(mh.message_timestamp, 'DD/MM/YYYY HH24:MI:SS') AS timestamp,
    mh.role_label AS remetente,
    mh.message AS mensagem_completa,
    mh.message_type AS tipo,
    CASE WHEN mh.has_media THEN mh.media_url ELSE NULL END AS url_midia,
    CASE WHEN mh.role = 'assistant' THEN mh.model_used ELSE NULL END AS modelo_ia,
    CASE WHEN mh.role = 'assistant' THEN mh.tokens_used ELSE NULL END AS tokens,
    '═════════════════════════════════════════════════════════════════════' AS separator

FROM message_history mh
ORDER BY mh.message_timestamp ASC;
*/

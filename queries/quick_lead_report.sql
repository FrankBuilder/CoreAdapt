-- ============================================================================
-- RELATÓRIO RÁPIDO DE LEAD - CoreAdapt v4
-- ============================================================================
-- Query simplificada para execução direta no Supabase SQL Editor
-- Retorna todas as informações essenciais em uma única execução
--
-- USO:
-- 1. Substitua :contact_id pelo ID do contato desejado
-- 2. Execute no Supabase SQL Editor
-- 3. Analise os resultados
-- ============================================================================

-- PARÂMETRO: Substitua o valor abaixo
-- Exemplo: WHERE c.id = 123
-- Ou: WHERE c.whatsapp = '5585999855443@s.whatsapp.net'

-- ============================================================================
-- PARTE 1: RESUMO EXECUTIVO
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ RESUMO EXECUTIVO ━━━",
    '' AS " "
UNION ALL
SELECT
    CONCAT('Lead: ', c.full_name, ' (ID: ', c.id, ')') AS info,
    '' AS " "
FROM corev4_contacts c WHERE c.id = :contact_id  -- SUBSTITUA AQUI

UNION ALL
SELECT
    CONCAT('WhatsApp: ', c.whatsapp) AS info,
    CONCAT('Email: ', COALESCE(c.email, 'N/A')) AS " "
FROM corev4_contacts c WHERE c.id = :contact_id

UNION ALL
SELECT
    CONCAT('Status: ',
        CASE
            WHEN c.opt_out THEN '🚫 OPT-OUT'
            WHEN NOT c.is_active THEN '⊗ INATIVO'
            WHEN ch.conversation_open THEN '💬 CONVERSA ATIVA'
            ELSE '✓ ATIVO'
        END
    ) AS info,
    CONCAT('Última interação: ',
        TO_CHAR(c.last_interaction_at, 'DD/MM/YYYY HH24:MI'),
        ' (há ',
        ROUND(EXTRACT(EPOCH FROM (NOW() - c.last_interaction_at))/3600, 1),
        'h)'
    ) AS " "
FROM corev4_contacts c
LEFT JOIN corev4_chats ch ON c.id = ch.contact_id
WHERE c.id = :contact_id

UNION ALL
SELECT
    CONCAT('ANUM Total: ', ROUND(COALESCE(ls.total_score, 0)::numeric, 1), '/100 - ',
        UPPER(COALESCE(ls.qualification_stage, 'N/A')),
        CASE WHEN ls.is_qualified THEN ' ✓ QUALIFICADO' ELSE ' ○ NÃO QUALIFICADO' END
    ) AS info,
    '' AS " "
FROM corev4_lead_state ls WHERE ls.contact_id = :contact_id

UNION ALL
SELECT
    CONCAT('  └─ A:', ROUND(COALESCE(ls.authority_score, 0)::numeric, 1),
           ' | N:', ROUND(COALESCE(ls.need_score, 0)::numeric, 1),
           ' | U:', ROUND(COALESCE(ls.urgency_score, 0)::numeric, 1),
           ' | M:', ROUND(COALESCE(ls.money_score, 0)::numeric, 1)
    ) AS info,
    '' AS " "
FROM corev4_lead_state ls WHERE ls.contact_id = :contact_id

UNION ALL
SELECT
    CONCAT('Dor principal: ', COALESCE(pc.category_label_pt, 'Não identificada')) AS info,
    '' AS " "
FROM corev4_lead_state ls
LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
WHERE ls.contact_id = :contact_id

UNION ALL
SELECT
    CONCAT('Campanha: ',
        COALESCE(fc.status, 'Nenhuma'),
        ' - ',
        COALESCE(CONCAT(fc.steps_completed, '/', fc.total_steps, ' passos'), 'N/A')
    ) AS info,
    '' AS " "
FROM corev4_followup_campaigns fc WHERE fc.contact_id = :contact_id

UNION ALL
SELECT
    CONCAT('Reuniões: ',
        COALESCE(COUNT(sm.id)::text, '0'),
        ' agendada(s) | ',
        COALESCE(COUNT(sm.id) FILTER (WHERE sm.meeting_completed)::text, '0'),
        ' realizada(s)'
    ) AS info,
    '' AS " "
FROM corev4_scheduled_meetings sm WHERE sm.contact_id = :contact_id
GROUP BY sm.contact_id;


-- ============================================================================
-- PARTE 2: DETALHAMENTO COMPLETO
-- ============================================================================

WITH contact_full AS (
    SELECT
        -- Identificação
        c.id AS contact_id,
        c.full_name,
        c.whatsapp,
        c.phone_number,
        c.email,
        c.company_id,
        comp.name AS company_name,
        comp.bot_name,

        -- Status
        c.opt_out,
        c.is_active,
        c.origin_source,
        c.sector,
        c.tags,
        c.utm_source,
        c.utm_medium,
        c.utm_campaign,
        c.last_interaction_at,
        c.created_at AS contact_created_at,

        -- ANUM
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
        pc.category_label_pt AS pain_category,
        ls.main_pain_detail,

        -- Extras
        ce.interactions AS total_interactions,
        ce.audio_response,
        ce.text_response,

        -- Chat
        ch.conversation_open,
        ch.batch_collecting

    FROM corev4_contacts c
    LEFT JOIN corev4_companies comp ON c.company_id = comp.id
    LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
    LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
    LEFT JOIN corev4_contact_extras ce ON c.id = ce.contact_id
    LEFT JOIN corev4_chats ch ON c.id = ch.contact_id
    WHERE c.id = :contact_id
),

message_stats AS (
    SELECT
        contact_id,
        COUNT(*) AS total_messages,
        COUNT(*) FILTER (WHERE role = 'user') AS user_messages,
        COUNT(*) FILTER (WHERE role = 'assistant') AS bot_messages,
        COUNT(*) FILTER (WHERE has_media) AS media_messages,
        SUM(tokens_used) AS total_tokens,
        SUM(cost_usd) AS total_cost,
        MIN(message_timestamp) AS first_message_at,
        MAX(message_timestamp) AS last_message_at,
        MAX(message_timestamp) FILTER (WHERE role = 'user') AS last_user_message_at
    FROM corev4_chat_history
    WHERE contact_id = :contact_id
    GROUP BY contact_id
),

followup_summary AS (
    SELECT
        fc.contact_id,
        fc.status AS campaign_status,
        fc.steps_completed,
        fc.total_steps,
        fc.should_continue,
        fc.stopped_reason,
        fc.last_step_sent_at,
        COUNT(fe.id) AS total_executions,
        COUNT(fe.id) FILTER (WHERE fe.executed) AS executed_count,
        COUNT(fe.id) FILTER (WHERE fe.scheduled_at > NOW() AND NOT fe.executed) AS scheduled_count,
        COUNT(fe.id) FILTER (WHERE NOT fe.should_send) AS cancelled_count
    FROM corev4_followup_campaigns fc
    LEFT JOIN corev4_followup_executions fe ON fc.id = fe.campaign_id
    WHERE fc.contact_id = :contact_id
    GROUP BY fc.contact_id, fc.status, fc.steps_completed, fc.total_steps,
             fc.should_continue, fc.stopped_reason, fc.last_step_sent_at
),

meeting_summary AS (
    SELECT
        contact_id,
        COUNT(*) AS total_meetings,
        COUNT(*) FILTER (WHERE status = 'scheduled' AND meeting_date > NOW()) AS upcoming_meetings,
        COUNT(*) FILTER (WHERE meeting_completed) AS completed_meetings,
        COUNT(*) FILTER (WHERE no_show) AS no_show_meetings,
        MAX(meeting_date) FILTER (WHERE meeting_date > NOW()) AS next_meeting_date,
        MAX(anum_score_at_booking) AS last_anum_at_booking
    FROM corev4_scheduled_meetings
    WHERE contact_id = :contact_id
    GROUP BY contact_id
)

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ DETALHAMENTO COMPLETO ━━━",

    -- Seção: Identificação
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS " ",
    '┃ IDENTIFICAÇÃO                                                ┃' AS "  ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "   ",
    cf.contact_id AS "ID",
    cf.full_name AS "Nome Completo",
    cf.whatsapp AS "WhatsApp",
    cf.phone_number AS "Telefone",
    cf.email AS "Email",
    cf.company_name AS "Empresa",

    -- Seção: Status
    '' AS "    ",
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS "     ",
    '┃ STATUS                                                       ┃' AS "      ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "       ",
    CASE
        WHEN cf.opt_out THEN '🚫 OPT-OUT'
        WHEN NOT cf.is_active THEN '⊗ INATIVO'
        WHEN cf.conversation_open THEN '💬 CONVERSA ATIVA'
        ELSE '✓ ATIVO'
    END AS "Status Geral",
    cf.lead_status AS "Status Lead State",
    TO_CHAR(cf.last_interaction_at, 'DD/MM/YYYY HH24:MI') AS "Última Interação",
    CONCAT(ROUND(EXTRACT(EPOCH FROM (NOW() - cf.last_interaction_at))/3600, 1), ' horas atrás') AS "Tempo desde última interação",

    -- Seção: ANUM
    '' AS "        ",
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS "         ",
    '┃ SCORE ANUM                                                   ┃' AS "          ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "           ",
    CONCAT(ROUND(COALESCE(cf.anum_total_score, 0)::numeric, 1), '/100') AS "ANUM Total",
    CONCAT(ROUND(COALESCE(cf.authority_score, 0)::numeric, 1), '/100') AS "└─ Authority",
    CONCAT(ROUND(COALESCE(cf.need_score, 0)::numeric, 1), '/100') AS "└─ Need",
    CONCAT(ROUND(COALESCE(cf.urgency_score, 0)::numeric, 1), '/100') AS "└─ Urgency",
    CONCAT(ROUND(COALESCE(cf.money_score, 0)::numeric, 1), '/100') AS "└─ Money",
    UPPER(cf.qualification_stage) AS "Estágio",
    CASE WHEN cf.is_qualified THEN '✓ QUALIFICADO' ELSE '○ NÃO QUALIFICADO' END AS "Qualificação",
    cf.analysis_count AS "Análises Realizadas",
    TO_CHAR(cf.last_analyzed_at, 'DD/MM/YYYY HH24:MI') AS "Última Análise",
    cf.pain_category AS "Categoria de Dor",
    LEFT(cf.main_pain_detail, 100) AS "Detalhes da Dor",

    -- Seção: Origem
    '' AS "            ",
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS "             ",
    '┃ ORIGEM E RASTREAMENTO                                        ┃' AS "              ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "               ",
    cf.origin_source AS "Origem",
    cf.sector AS "Setor",
    ARRAY_TO_STRING(cf.tags, ', ') AS "Tags",
    cf.utm_source AS "UTM Source",
    cf.utm_medium AS "UTM Medium",
    cf.utm_campaign AS "UTM Campaign",

    -- Seção: Mensagens
    '' AS "                ",
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS "                 ",
    '┃ ESTATÍSTICAS DE MENSAGENS                                    ┃' AS "                  ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "                   ",
    ms.total_messages AS "Total de Mensagens",
    ms.user_messages AS "└─ Do Lead",
    ms.bot_messages AS "└─ Do Bot",
    ms.media_messages AS "└─ Com Mídia",
    ms.total_tokens AS "Tokens Consumidos",
    CONCAT('$', ROUND(ms.total_cost, 4)) AS "Custo Total (USD)",
    TO_CHAR(ms.first_message_at, 'DD/MM/YYYY HH24:MI') AS "Primeira Mensagem",
    TO_CHAR(ms.last_message_at, 'DD/MM/YYYY HH24:MI') AS "Última Mensagem",
    CONCAT(ROUND(EXTRACT(EPOCH FROM (NOW() - ms.last_user_message_at))/3600, 1), ' horas atrás') AS "Última Mensagem do Lead",

    -- Seção: Follow-up
    '' AS "                    ",
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS "                     ",
    '┃ CAMPANHA DE FOLLOW-UP                                        ┃' AS "                      ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "                       ",
    COALESCE(fs.campaign_status, 'Nenhuma campanha') AS "Status da Campanha",
    CONCAT(COALESCE(fs.steps_completed, 0), '/', COALESCE(fs.total_steps, 0), ' passos') AS "Progresso",
    CONCAT(ROUND((COALESCE(fs.steps_completed, 0)::numeric / NULLIF(fs.total_steps, 0)::numeric) * 100, 1), '%') AS "% Completo",
    CASE WHEN fs.should_continue THEN '→ Continuando' ELSE CONCAT('⊗ Parado: ', fs.stopped_reason) END AS "Continuidade",
    TO_CHAR(fs.last_step_sent_at, 'DD/MM/YYYY HH24:MI') AS "Último Passo Enviado",
    fs.executed_count AS "Passos Executados",
    fs.scheduled_count AS "Passos Agendados",
    fs.cancelled_count AS "Passos Cancelados",

    -- Seção: Reuniões
    '' AS "                        ",
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS "                         ",
    '┃ REUNIÕES                                                     ┃' AS "                          ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "                           ",
    COALESCE(msum.total_meetings, 0) AS "Total de Reuniões",
    COALESCE(msum.upcoming_meetings, 0) AS "└─ Próximas",
    COALESCE(msum.completed_meetings, 0) AS "└─ Realizadas",
    COALESCE(msum.no_show_meetings, 0) AS "└─ No-show",
    TO_CHAR(msum.next_meeting_date, 'DD/MM/YYYY HH24:MI') AS "Próxima Reunião",
    CONCAT(ROUND(COALESCE(msum.last_anum_at_booking, 0)::numeric, 1), '/100') AS "ANUM no Último Agendamento"

FROM contact_full cf
LEFT JOIN message_stats ms ON cf.contact_id = ms.contact_id
LEFT JOIN followup_summary fs ON cf.contact_id = fs.contact_id
LEFT JOIN meeting_summary msum ON cf.contact_id = msum.contact_id;


-- ============================================================================
-- PARTE 3: FOLLOW-UPS DETALHADOS
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ FOLLOW-UPS DETALHADOS ━━━",
    '' AS " "
UNION ALL
SELECT
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS info,
    '' AS " "
UNION ALL
SELECT
    '┃ DETALHAMENTO DE CADA PASSO                                   ┃' AS info,
    '' AS " "
UNION ALL
SELECT
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS info,
    '' AS " "
UNION ALL

SELECT
    CONCAT('Passo ', fe.step, '/', fe.total_steps) AS "Passo",
    CASE
        WHEN fe.executed AND fe.sent_at IS NOT NULL THEN '✓ Enviado'
        WHEN fe.executed AND fe.sent_at IS NULL THEN '✗ Executado sem envio'
        WHEN NOT fe.should_send THEN '⊗ Cancelado'
        WHEN fe.scheduled_at > NOW() THEN '⏰ Agendado'
        ELSE '⚠ Atrasado'
    END AS "Status"
FROM corev4_followup_executions fe
WHERE fe.contact_id = :contact_id
ORDER BY fe.step

UNION ALL
SELECT
    TO_CHAR(fe.scheduled_at, 'DD/MM/YYYY HH24:MI') AS "  └─ Agendado para",
    CASE
        WHEN fe.sent_at IS NOT NULL THEN CONCAT('Enviado em: ', TO_CHAR(fe.sent_at, 'DD/MM/YYYY HH24:MI'))
        ELSE 'Não enviado'
    END AS "  └─ Status de Envio"
FROM corev4_followup_executions fe
WHERE fe.contact_id = :contact_id
ORDER BY fe.step

UNION ALL
SELECT
    CONCAT('  └─ ANUM: ', COALESCE(ROUND(fe.anum_at_execution::numeric, 1)::text, 'N/A')) AS info,
    CONCAT('  └─ Razão: ', COALESCE(fe.decision_reason, 'N/A')) AS " "
FROM corev4_followup_executions fe
WHERE fe.contact_id = :contact_id
ORDER BY fe.step

UNION ALL
SELECT
    CONCAT('  └─ Mensagem: ', LEFT(COALESCE(fe.generated_message, 'N/A'), 100), '...') AS info,
    '─────────────────────────────────────────────────────────────' AS " "
FROM corev4_followup_executions fe
WHERE fe.contact_id = :contact_id
ORDER BY fe.step;


-- ============================================================================
-- PARTE 4: REUNIÕES DETALHADAS
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ REUNIÕES DETALHADAS ━━━",
    '' AS " ",
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS "  ",
    '┃ TODAS AS REUNIÕES                                            ┃' AS "   ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "    ",

    sm.id AS "ID Reunião",
    sm.cal_event_title AS "Título",
    TO_CHAR(sm.meeting_date, 'DD/MM/YYYY HH24:MI') AS "Data/Hora",
    CONCAT(sm.meeting_duration_minutes, ' min') AS "Duração",
    sm.status AS "Status",
    CASE
        WHEN sm.meeting_completed THEN CONCAT('✓ Realizada em ', TO_CHAR(sm.meeting_completed_at, 'DD/MM/YYYY'))
        WHEN sm.no_show THEN '✗ No-show'
        WHEN sm.status = 'cancelled' THEN '⊗ Cancelada'
        WHEN sm.meeting_date > NOW() THEN '⏰ Agendada'
        ELSE '⚠ Aguardando confirmação'
    END AS "Status Detalhado",

    '' AS "     ",
    CONCAT('ANUM no agendamento: ', ROUND(COALESCE(sm.anum_score_at_booking, 0)::numeric, 1), '/100') AS "Score ANUM",
    CONCAT('  A:', ROUND(COALESCE(sm.authority_score, 0)::numeric, 1),
           ' | N:', ROUND(COALESCE(sm.need_score, 0)::numeric, 1),
           ' | U:', ROUND(COALESCE(sm.urgency_score, 0)::numeric, 1),
           ' | M:', ROUND(COALESCE(sm.money_score, 0)::numeric, 1)) AS "  └─ Breakdown",

    '' AS "      ",
    sm.cal_attendee_name AS "Participante",
    sm.cal_attendee_email AS "Email",
    sm.cal_meeting_url AS "URL da Reunião",

    '' AS "       ",
    LEFT(sm.conversation_summary, 200) AS "Resumo da Conversa",
    sm.meeting_notes AS "Notas",
    sm.meeting_outcome AS "Resultado",

    '' AS "        ",
    CASE WHEN sm.reminder_24h_sent THEN
        CONCAT('✓ Lembrete 24h enviado: ', TO_CHAR(sm.reminder_24h_sent_at, 'DD/MM HH24:MI'))
    ELSE '○ Lembrete 24h não enviado' END AS "Lembrete 24h",
    CASE WHEN sm.reminder_1h_sent THEN
        CONCAT('✓ Lembrete 1h enviado: ', TO_CHAR(sm.reminder_1h_sent_at, 'DD/MM HH24:MI'))
    ELSE '○ Lembrete 1h não enviado' END AS "Lembrete 1h",

    '═════════════════════════════════════════════════════════════' AS "Separador"

FROM corev4_scheduled_meetings sm
WHERE sm.contact_id = :contact_id
ORDER BY sm.meeting_date DESC;


-- ============================================================================
-- PARTE 5: ÚLTIMAS 20 MENSAGENS
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ ÚLTIMAS 20 MENSAGENS ━━━",
    '' AS " ",
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS "  ",
    '┃ HISTÓRICO DE CONVERSA                                        ┃' AS "   ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "    ",

    ROW_NUMBER() OVER (ORDER BY ch.message_timestamp) AS "#",
    TO_CHAR(ch.message_timestamp, 'DD/MM HH24:MI') AS "Data/Hora",
    CASE ch.role
        WHEN 'user' THEN '👤 Lead'
        WHEN 'assistant' THEN CONCAT('🤖 ', (SELECT bot_name FROM corev4_companies WHERE id = (SELECT company_id FROM corev4_contacts WHERE id = :contact_id)))
        ELSE '⚙️ Sistema'
    END AS "Remetente",
    CASE
        WHEN ch.has_media THEN CONCAT('[', UPPER(ch.message_type), '] ', LEFT(ch.message, 100))
        ELSE LEFT(ch.message, 150)
    END AS "Mensagem",
    CASE
        WHEN ch.role = 'assistant' THEN CONCAT(ch.tokens_used, ' tokens, $', ROUND(ch.cost_usd, 6))
        ELSE ''
    END AS "Metadata"

FROM corev4_chat_history ch
WHERE ch.contact_id = :contact_id
ORDER BY ch.message_timestamp DESC
LIMIT 20;


-- ============================================================================
-- PARTE 6: ANÁLISE DE REENGAJAMENTO
-- ============================================================================

WITH user_messages AS (
    SELECT
        message_timestamp,
        LAG(message_timestamp) OVER (ORDER BY message_timestamp) AS prev_timestamp
    FROM corev4_chat_history
    WHERE contact_id = :contact_id AND role = 'user'
),
gaps AS (
    SELECT
        EXTRACT(EPOCH FROM (message_timestamp - prev_timestamp))/3600 AS gap_hours
    FROM user_messages
    WHERE prev_timestamp IS NOT NULL
)

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ ANÁLISE DE REENGAJAMENTO ━━━",
    '' AS " ",
    '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓' AS "  ",
    '┃ PADRÕES DE INTERAÇÃO                                         ┃' AS "   ",
    '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛' AS "    ",

    COUNT(*) FILTER (WHERE gap_hours > 48) AS "Reengajamentos (gaps >48h)",
    ROUND(MAX(gap_hours), 1) AS "Maior período de silêncio (horas)",
    ROUND(AVG(gap_hours), 1) AS "Média de tempo entre mensagens (horas)",

    '' AS "     ",
    COUNT(*) FILTER (WHERE gap_hours <= 1) AS "Respostas rápidas (<1h)",
    COUNT(*) FILTER (WHERE gap_hours BETWEEN 1 AND 24) AS "Respostas no mesmo dia (1-24h)",
    COUNT(*) FILTER (WHERE gap_hours BETWEEN 24 AND 48) AS "Respostas no dia seguinte (24-48h)",
    COUNT(*) FILTER (WHERE gap_hours > 48) AS "Respostas após gap longo (>48h)"

FROM gaps;


-- ============================================================================
-- FIM DO RELATÓRIO
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    CONCAT('Relatório gerado em: ', TO_CHAR(NOW(), 'DD/MM/YYYY HH24:MI:SS')) AS " ",
    '═══════════════════════════════════════════════════════════════' AS "  ";

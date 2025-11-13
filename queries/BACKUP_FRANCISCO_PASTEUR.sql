-- ============================================================================
-- BACKUP COMPLETO - Francisco Pasteur
-- ============================================================================
-- Execute ESTA query ANTES de deletar para fazer backup
-- Salve o resultado em um arquivo JSON
-- ============================================================================

SELECT json_build_object(
    'backup_date', NOW(),
    'backup_description', 'Backup completo de Francisco Pasteur antes de deleção',

    -- Dados do contato
    'contact', (
        SELECT row_to_json(c.*)
        FROM corev4_contacts c
        WHERE
            c.full_name ILIKE '%Francisco%Pasteur%'
            OR c.whatsapp LIKE '%5585999855443%'
            OR c.whatsapp LIKE '%85999855443%'
        LIMIT 1
    ),

    -- Lead State (ANUM)
    'lead_state', (
        SELECT row_to_json(ls.*)
        FROM corev4_lead_state ls
        WHERE ls.contact_id = (
            SELECT id FROM corev4_contacts
            WHERE full_name ILIKE '%Francisco%Pasteur%'
               OR whatsapp LIKE '%5585999855443%'
            LIMIT 1
        )
    ),

    -- Contact Extras
    'contact_extras', (
        SELECT row_to_json(ce.*)
        FROM corev4_contact_extras ce
        WHERE ce.contact_id = (
            SELECT id FROM corev4_contacts
            WHERE full_name ILIKE '%Francisco%Pasteur%'
               OR whatsapp LIKE '%5585999855443%'
            LIMIT 1
        )
    ),

    -- Chat Session
    'chat_session', (
        SELECT row_to_json(ch.*)
        FROM corev4_chats ch
        WHERE ch.contact_id = (
            SELECT id FROM corev4_contacts
            WHERE full_name ILIKE '%Francisco%Pasteur%'
               OR whatsapp LIKE '%5585999855443%'
            LIMIT 1
        )
    ),

    -- Follow-up Campaigns
    'followup_campaigns', (
        SELECT json_agg(row_to_json(fc.*))
        FROM corev4_followup_campaigns fc
        WHERE fc.contact_id = (
            SELECT id FROM corev4_contacts
            WHERE full_name ILIKE '%Francisco%Pasteur%'
               OR whatsapp LIKE '%5585999855443%'
            LIMIT 1
        )
    ),

    -- Follow-up Executions
    'followup_executions', (
        SELECT json_agg(row_to_json(fe.*))
        FROM corev4_followup_executions fe
        WHERE fe.contact_id = (
            SELECT id FROM corev4_contacts
            WHERE full_name ILIKE '%Francisco%Pasteur%'
               OR whatsapp LIKE '%5585999855443%'
            LIMIT 1
        )
    ),

    -- Scheduled Meetings
    'scheduled_meetings', (
        SELECT json_agg(row_to_json(sm.*))
        FROM corev4_scheduled_meetings sm
        WHERE sm.contact_id = (
            SELECT id FROM corev4_contacts
            WHERE full_name ILIKE '%Francisco%Pasteur%'
               OR whatsapp LIKE '%5585999855443%'
            LIMIT 1
        )
    ),

    -- Chat History (últimas 100 mensagens)
    'chat_history_recent', (
        SELECT json_agg(row_to_json(ch.*))
        FROM (
            SELECT *
            FROM corev4_chat_history ch
            WHERE ch.contact_id = (
                SELECT id FROM corev4_contacts
                WHERE full_name ILIKE '%Francisco%Pasteur%'
                   OR whatsapp LIKE '%5585999855443%'
                LIMIT 1
            )
            ORDER BY ch.message_timestamp DESC
            LIMIT 100
        ) ch
    ),

    -- Estatísticas de mensagens
    'message_stats', (
        SELECT json_build_object(
            'total_messages', COUNT(*),
            'user_messages', COUNT(*) FILTER (WHERE role = 'user'),
            'bot_messages', COUNT(*) FILTER (WHERE role = 'assistant'),
            'total_tokens', SUM(tokens_used),
            'total_cost_usd', SUM(cost_usd),
            'first_message', MIN(message_timestamp),
            'last_message', MAX(message_timestamp)
        )
        FROM corev4_chat_history ch
        WHERE ch.contact_id = (
            SELECT id FROM corev4_contacts
            WHERE full_name ILIKE '%Francisco%Pasteur%'
               OR whatsapp LIKE '%5585999855443%'
            LIMIT 1
        )
    ),

    -- N8N Chat Histories
    'n8n_chat_histories', (
        SELECT json_agg(row_to_json(nch.*))
        FROM corev4_n8n_chat_histories nch
        WHERE nch.contact_id = (
            SELECT id FROM corev4_contacts
            WHERE full_name ILIKE '%Francisco%Pasteur%'
               OR whatsapp LIKE '%5585999855443%'
            LIMIT 1
        )
    )

) AS backup_completo;


-- ============================================================================
-- INSTRUÇÕES
-- ============================================================================
--
-- 1. Execute esta query
-- 2. Copie o resultado JSON completo
-- 3. Salve em um arquivo: backup_francisco_pasteur_YYYYMMDD.json
-- 4. Guarde em local seguro
-- 5. Agora pode executar o DELETE com segurança!
--
-- Para restaurar no futuro (se necessário):
-- - Você precisará recriar os registros manualmente a partir do JSON
-- - Ou importar via script (podemos criar se precisar)
--
-- ============================================================================

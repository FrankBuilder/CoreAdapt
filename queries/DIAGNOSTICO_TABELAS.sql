-- ============================================================================
-- DIAGNÓSTICO: Verificar quais tabelas têm contact_id
-- ============================================================================
-- Execute isso para ver quais tabelas podem estar causando o erro
-- ============================================================================

-- Verificar estrutura das tabelas
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name LIKE 'corev4_%'
  AND (column_name = 'contact_id' OR column_name = 'whatsapp_id')
ORDER BY table_name, column_name;


-- Verificar especificamente as tabelas do script
SELECT
    'corev4_followup_executions' AS tabela,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'corev4_followup_executions'
        AND column_name = 'contact_id'
    ) THEN '✓ TEM contact_id' ELSE '✗ NÃO TEM contact_id' END AS status

UNION ALL SELECT 'corev4_followup_campaigns',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'corev4_followup_campaigns' AND column_name = 'contact_id') THEN '✓ TEM' ELSE '✗ NÃO TEM' END

UNION ALL SELECT 'corev4_scheduled_meetings',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'corev4_scheduled_meetings' AND column_name = 'contact_id') THEN '✓ TEM' ELSE '✗ NÃO TEM' END

UNION ALL SELECT 'corev4_chat_history',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'corev4_chat_history' AND column_name = 'contact_id') THEN '✓ TEM' ELSE '✗ NÃO TEM' END

UNION ALL SELECT 'corev4_n8n_chat_histories',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'corev4_n8n_chat_histories' AND column_name = 'contact_id') THEN '✓ TEM' ELSE '✗ NÃO TEM' END

UNION ALL SELECT 'corev4_chats',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'corev4_chats' AND column_name = 'contact_id') THEN '✓ TEM' ELSE '✗ NÃO TEM' END

UNION ALL SELECT 'corev4_lead_state',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'corev4_lead_state' AND column_name = 'contact_id') THEN '✓ TEM' ELSE '✗ NÃO TEM' END

UNION ALL SELECT 'corev4_contact_extras',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'corev4_contact_extras' AND column_name = 'contact_id') THEN '✓ TEM' ELSE '✗ NÃO TEM' END

UNION ALL SELECT 'corev4_message_dedup',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'corev4_message_dedup' AND column_name = 'contact_id') THEN '✓ TEM contact_id' ELSE '✗ Usa whatsapp_id' END;

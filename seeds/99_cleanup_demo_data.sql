-- ============================================================================
-- CLEANUP: Remove todos os dados demo
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Este script remove APENAS os dados com tag 'demo'
-- Não afeta dados reais do sistema
-- ============================================================================

-- IMPORTANTE: Execute este script com cuidado!
-- Ele removerá todos os dados de demonstração

BEGIN;

-- 1. Remover follow-up executions
DELETE FROM corev4_followup_executions
WHERE contact_id IN (
    SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]
);

-- 2. Remover follow-up campaigns
DELETE FROM corev4_followup_campaigns
WHERE contact_id IN (
    SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]
);

-- 3. Remover scheduled meetings
DELETE FROM corev4_scheduled_meetings
WHERE contact_id IN (
    SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]
);

-- 4. Remover chat history
DELETE FROM corev4_chat_history
WHERE contact_id IN (
    SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]
);

-- 5. Remover lead states
DELETE FROM corev4_lead_state
WHERE contact_id IN (
    SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]
);

-- 6. Finalmente, remover os contatos
DELETE FROM corev4_contacts
WHERE tags @> ARRAY['demo']::text[];

-- Verificar que não restou nada
SELECT 'Contacts' AS tabela, COUNT(*) AS restantes FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]
UNION ALL
SELECT 'Lead States', COUNT(*) FROM corev4_lead_state WHERE contact_id >= 1001 AND contact_id <= 1053
UNION ALL
SELECT 'Chat History', COUNT(*) FROM corev4_chat_history WHERE contact_id >= 1001 AND contact_id <= 1053
UNION ALL
SELECT 'Campaigns', COUNT(*) FROM corev4_followup_campaigns WHERE contact_id >= 1001 AND contact_id <= 1053
UNION ALL
SELECT 'Meetings', COUNT(*) FROM corev4_scheduled_meetings WHERE contact_id >= 1001 AND contact_id <= 1053;

COMMIT;

-- Se tudo der certo, todos os valores acima serão 0

-- ============================================================================
-- ⚠️⚠️⚠️ VERSÃO CORRIGIDA - DELEÇÃO PERMANENTE ⚠️⚠️⚠️
-- ============================================================================
-- Este script foi corrigido para lidar com tabelas que não têm contact_id
--
-- Nome: Francisco Pasteur
-- Telefones: 5585999855443, 85999855443
--
-- ⚠️ ISTO É IRREVERSÍVEL!
-- ============================================================================

BEGIN; -- Inicia transação

-- ============================================================================
-- PASSO 0: Identificar o contato e armazenar em variável
-- ============================================================================

-- Criar tabela temporária com os IDs a serem deletados
CREATE TEMP TABLE contacts_to_delete AS
SELECT
    id AS contact_id,
    whatsapp,
    full_name
FROM corev4_contacts
WHERE
    full_name ILIKE '%Francisco%Pasteur%'
    OR whatsapp LIKE '%5585999855443%'
    OR whatsapp LIKE '%85999855443%'
    OR phone_number LIKE '%5585999855443%'
    OR phone_number LIKE '%85999855443%'
    OR email ILIKE '%francisco%pasteur%';

-- Mostrar o que será deletado
SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ CONTATO A SER DELETADO ━━━",
    contact_id,
    full_name,
    whatsapp
FROM contacts_to_delete;


-- ============================================================================
-- ETAPA 1: DELETAR FOLLOW-UP EXECUTIONS
-- ============================================================================

DELETE FROM corev4_followup_executions
WHERE contact_id IN (SELECT contact_id FROM contacts_to_delete);

SELECT '✓ Deletados follow-up executions' AS resultado;


-- ============================================================================
-- ETAPA 2: DELETAR FOLLOW-UP CAMPAIGNS
-- ============================================================================

DELETE FROM corev4_followup_campaigns
WHERE contact_id IN (SELECT contact_id FROM contacts_to_delete);

SELECT '✓ Deletados follow-up campaigns' AS resultado;


-- ============================================================================
-- ETAPA 3: DELETAR SCHEDULED MEETINGS
-- ============================================================================

DELETE FROM corev4_scheduled_meetings
WHERE contact_id IN (SELECT contact_id FROM contacts_to_delete);

SELECT '✓ Deletados scheduled meetings' AS resultado;


-- ============================================================================
-- ETAPA 4: DELETAR CHAT HISTORY
-- ============================================================================

DELETE FROM corev4_chat_history
WHERE contact_id IN (SELECT contact_id FROM contacts_to_delete);

SELECT '✓ Deletados chat history messages' AS resultado;


-- ============================================================================
-- ETAPA 5: DELETAR N8N CHAT HISTORIES
-- ============================================================================

-- Verificar se a tabela tem contact_id
DO $$
BEGIN
    -- Tentar deletar usando contact_id
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'corev4_n8n_chat_histories'
        AND column_name = 'contact_id'
    ) THEN
        DELETE FROM corev4_n8n_chat_histories
        WHERE contact_id IN (SELECT contact_id FROM contacts_to_delete);

        RAISE NOTICE '✓ Deletados n8n chat histories (via contact_id)';
    ELSE
        -- Se não tem contact_id, tentar via session_id ou outro método
        RAISE NOTICE '⚠ Tabela n8n_chat_histories não tem contact_id - pulando';
    END IF;
END $$;


-- ============================================================================
-- ETAPA 6: DELETAR CHATS (sessions)
-- ============================================================================

DELETE FROM corev4_chats
WHERE contact_id IN (SELECT contact_id FROM contacts_to_delete);

SELECT '✓ Deletados chat sessions' AS resultado;


-- ============================================================================
-- ETAPA 7: DELETAR LEAD STATE (ANUM)
-- ============================================================================

DELETE FROM corev4_lead_state
WHERE contact_id IN (SELECT contact_id FROM contacts_to_delete);

SELECT '✓ Deletados lead state records' AS resultado;


-- ============================================================================
-- ETAPA 8: DELETAR CONTACT EXTRAS
-- ============================================================================

DELETE FROM corev4_contact_extras
WHERE contact_id IN (SELECT contact_id FROM contacts_to_delete);

SELECT '✓ Deletados contact extras' AS resultado;


-- ============================================================================
-- ETAPA 9: DELETAR MESSAGE DEDUP (usa whatsapp_id, não contact_id!)
-- ============================================================================

DELETE FROM corev4_message_dedup
WHERE whatsapp_id IN (SELECT whatsapp FROM contacts_to_delete);

SELECT '✓ Deletados message dedup records' AS resultado;


-- ============================================================================
-- ETAPA 10: DELETAR O CONTATO (PRINCIPAL)
-- ============================================================================

DELETE FROM corev4_contacts
WHERE id IN (SELECT contact_id FROM contacts_to_delete);

SELECT '✓ Deletado o contato principal' AS resultado;


-- ============================================================================
-- RESUMO FINAL
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    '✓✓✓ DELEÇÃO CONCLUÍDA! ✓✓✓' AS " ",
    '═══════════════════════════════════════════════════════════════' AS "  ",
    '' AS "   ",
    '⚠️ Para CONFIRMAR: COMMIT;' AS "    ",
    '⚠️ Para CANCELAR: ROLLBACK;' AS "     ";

-- Limpar tabela temporária
DROP TABLE contacts_to_delete;


-- ============================================================================
-- ESCOLHA UMA OPÇÃO:
-- ============================================================================

-- Opção 1: CONFIRMAR DELEÇÃO
COMMIT;

-- Opção 2: CANCELAR DELEÇÃO (descomente se quiser testar)
-- ROLLBACK;


-- ============================================================================
-- NOTAS:
-- ============================================================================
-- Esta versão corrigida:
-- 1. Usa tabela temporária para armazenar os IDs
-- 2. Trata message_dedup corretamente (usa whatsapp_id)
-- 3. Verifica se n8n_chat_histories tem contact_id antes de deletar
-- 4. Mais seguro e robusto
-- ============================================================================

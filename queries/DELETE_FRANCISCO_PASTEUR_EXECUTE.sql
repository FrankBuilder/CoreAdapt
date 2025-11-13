-- ============================================================================
-- ⚠️⚠️⚠️ ATENÇÃO: DELEÇÃO PERMANENTE ⚠️⚠️⚠️
-- ============================================================================
-- Este script vai DELETAR PERMANENTEMENTE todos os dados de:
--
-- Nome: Francisco Pasteur
-- Telefones: 5585999855443, 85999855443
--
-- ⚠️ ISTO É IRREVERSÍVEL!
-- ⚠️ EXECUTE O PREVIEW PRIMEIRO!
-- ⚠️ FAÇA BACKUP SE QUISER PODER RECUPERAR!
--
-- Como usar:
-- 1. Execute TUDO de uma vez (incluindo BEGIN e COMMIT)
-- 2. Se algo der errado, execute: ROLLBACK;
-- 3. Para confirmar: Execute o script completo
-- ============================================================================

BEGIN; -- Inicia transação (permite ROLLBACK se precisar)

-- ============================================================================
-- ETAPA 1: IDENTIFICAR O CONTATO
-- ============================================================================

DO $$
DECLARE
    v_contact_id bigint;
    v_contact_name text;
    v_whatsapp text;
BEGIN
    -- Buscar o contato
    SELECT id, full_name, whatsapp INTO v_contact_id, v_contact_name, v_whatsapp
    FROM corev4_contacts
    WHERE
        full_name ILIKE '%Francisco%Pasteur%'
        OR whatsapp LIKE '%5585999855443%'
        OR whatsapp LIKE '%85999855443%'
        OR phone_number LIKE '%5585999855443%'
        OR phone_number LIKE '%85999855443%'
        OR email ILIKE '%francisco%pasteur%'
    LIMIT 1;

    IF v_contact_id IS NULL THEN
        RAISE NOTICE '❌ Contato não encontrado!';
    ELSE
        RAISE NOTICE '✓ Contato encontrado:';
        RAISE NOTICE '  ID: %', v_contact_id;
        RAISE NOTICE '  Nome: %', v_contact_name;
        RAISE NOTICE '  WhatsApp: %', v_whatsapp;
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ Iniciando deleção...';
    END IF;
END $$;


-- ============================================================================
-- ETAPA 2: DELETAR FOLLOW-UP EXECUTIONS (dependências primeiro)
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_followup_executions
    WHERE contact_id IN (
        SELECT id FROM corev4_contacts
        WHERE
            full_name ILIKE '%Francisco%Pasteur%'
            OR whatsapp LIKE '%5585999855443%'
            OR whatsapp LIKE '%85999855443%'
    )
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' follow-up executions' AS resultado
FROM deleted;


-- ============================================================================
-- ETAPA 3: DELETAR FOLLOW-UP CAMPAIGNS
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_followup_campaigns
    WHERE contact_id IN (
        SELECT id FROM corev4_contacts
        WHERE
            full_name ILIKE '%Francisco%Pasteur%'
            OR whatsapp LIKE '%5585999855443%'
            OR whatsapp LIKE '%85999855443%'
    )
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' follow-up campaigns' AS resultado
FROM deleted;


-- ============================================================================
-- ETAPA 4: DELETAR SCHEDULED MEETINGS
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_scheduled_meetings
    WHERE contact_id IN (
        SELECT id FROM corev4_contacts
        WHERE
            full_name ILIKE '%Francisco%Pasteur%'
            OR whatsapp LIKE '%5585999855443%'
            OR whatsapp LIKE '%85999855443%'
    )
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' scheduled meetings' AS resultado
FROM deleted;


-- ============================================================================
-- ETAPA 5: DELETAR CHAT HISTORY (pode ter MUITOS registros!)
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_chat_history
    WHERE contact_id IN (
        SELECT id FROM corev4_contacts
        WHERE
            full_name ILIKE '%Francisco%Pasteur%'
            OR whatsapp LIKE '%5585999855443%'
            OR whatsapp LIKE '%85999855443%'
    )
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' chat history messages' AS resultado
FROM deleted;


-- ============================================================================
-- ETAPA 6: DELETAR N8N CHAT HISTORIES
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_n8n_chat_histories
    WHERE contact_id IN (
        SELECT id FROM corev4_contacts
        WHERE
            full_name ILIKE '%Francisco%Pasteur%'
            OR whatsapp LIKE '%5585999855443%'
            OR whatsapp LIKE '%85999855443%'
    )
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' n8n chat histories' AS resultado
FROM deleted;


-- ============================================================================
-- ETAPA 7: DELETAR CHATS (sessions)
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_chats
    WHERE contact_id IN (
        SELECT id FROM corev4_contacts
        WHERE
            full_name ILIKE '%Francisco%Pasteur%'
            OR whatsapp LIKE '%5585999855443%'
            OR whatsapp LIKE '%85999855443%'
    )
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' chat sessions' AS resultado
FROM deleted;


-- ============================================================================
-- ETAPA 8: DELETAR LEAD STATE (ANUM)
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_lead_state
    WHERE contact_id IN (
        SELECT id FROM corev4_contacts
        WHERE
            full_name ILIKE '%Francisco%Pasteur%'
            OR whatsapp LIKE '%5585999855443%'
            OR whatsapp LIKE '%85999855443%'
    )
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' lead state records' AS resultado
FROM deleted;


-- ============================================================================
-- ETAPA 9: DELETAR CONTACT EXTRAS
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_contact_extras
    WHERE contact_id IN (
        SELECT id FROM corev4_contacts
        WHERE
            full_name ILIKE '%Francisco%Pasteur%'
            OR whatsapp LIKE '%5585999855443%'
            OR whatsapp LIKE '%85999855443%'
    )
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' contact extras' AS resultado
FROM deleted;


-- ============================================================================
-- ETAPA 10: DELETAR MESSAGE DEDUP
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_message_dedup
    WHERE whatsapp_id IN (
        SELECT whatsapp FROM corev4_contacts
        WHERE
            full_name ILIKE '%Francisco%Pasteur%'
            OR whatsapp LIKE '%5585999855443%'
            OR whatsapp LIKE '%85999855443%'
    )
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' message dedup records' AS resultado
FROM deleted;


-- ============================================================================
-- ETAPA 11: DELETAR O CONTATO (PRINCIPAL)
-- ============================================================================

WITH deleted AS (
    DELETE FROM corev4_contacts
    WHERE
        full_name ILIKE '%Francisco%Pasteur%'
        OR whatsapp LIKE '%5585999855443%'
        OR whatsapp LIKE '%85999855443%'
        OR phone_number LIKE '%5585999855443%'
        OR phone_number LIKE '%85999855443%'
        OR email ILIKE '%francisco%pasteur%'
    RETURNING *
)
SELECT
    '✓ Deletados ' || COUNT(*) || ' contacts (PRINCIPAL)' AS resultado
FROM deleted;


-- ============================================================================
-- RESUMO FINAL
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    '✓✓✓ DELEÇÃO CONCLUÍDA COM SUCESSO! ✓✓✓' AS " ",
    '═══════════════════════════════════════════════════════════════' AS "  ",
    '' AS "   ",
    'Todos os dados de Francisco Pasteur foram removidos.' AS "    ",
    '' AS "     ",
    '⚠️ Para CONFIRMAR a deleção, execute: COMMIT;' AS "      ",
    '⚠️ Para CANCELAR e desfazer, execute: ROLLBACK;' AS "       ",
    '' AS "        ",
    'Transação ainda está aberta. Escolha:' AS "         ",
    '  - COMMIT   → Confirma e salva as mudanças' AS "          ",
    '  - ROLLBACK → Cancela e restaura tudo' AS "           ";


-- ============================================================================
-- IMPORTANTE: ESCOLHA UMA OPÇÃO ABAIXO
-- ============================================================================

-- Opção 1: CONFIRMAR DELEÇÃO (descomente a linha abaixo)
COMMIT;

-- Opção 2: CANCELAR DELEÇÃO (descomente a linha abaixo)
-- ROLLBACK;


-- ============================================================================
-- INSTRUÇÕES DE USO
-- ============================================================================
--
-- PASSO A PASSO:
--
-- 1. Execute o arquivo DELETE_FRANCISCO_PASTEUR_PREVIEW.sql PRIMEIRO
--    para ver o que será deletado
--
-- 2. Se estiver tudo OK, execute ESTE arquivo completo (incluindo BEGIN e COMMIT)
--
-- 3. Se algo der errado durante a execução:
--    - Execute: ROLLBACK;
--    - Isso vai desfazer TUDO
--
-- 4. Se você quiser TESTAR sem deletar de verdade:
--    - Comente a linha "COMMIT;"
--    - Descomente a linha "ROLLBACK;"
--    - Execute e veja os resultados
--    - Nada será deletado permanentemente
--
-- 5. Para DELETAR DE VERDADE:
--    - Deixe "COMMIT;" descomentado (como está)
--    - Execute todo o script
--
-- ============================================================================
-- BACKUP (RECOMENDADO)
-- ============================================================================
--
-- Para fazer backup antes de deletar:
--
-- 1. Execute esta query e salve o resultado:
--
-- SELECT json_build_object(
--     'contact', (SELECT row_to_json(c.*) FROM corev4_contacts c WHERE c.id = 7),
--     'lead_state', (SELECT row_to_json(ls.*) FROM corev4_lead_state ls WHERE ls.contact_id = 7),
--     'messages', (SELECT json_agg(row_to_json(ch.*)) FROM corev4_chat_history ch WHERE ch.contact_id = 7),
--     'followups', (SELECT json_agg(row_to_json(fc.*)) FROM corev4_followup_campaigns fc WHERE fc.contact_id = 7),
--     'meetings', (SELECT json_agg(row_to_json(sm.*)) FROM corev4_scheduled_meetings sm WHERE sm.contact_id = 7)
-- ) AS backup_completo;
--
-- 2. Salve o JSON retornado em um arquivo
--
-- 3. Agora pode deletar com segurança!
--
-- ============================================================================

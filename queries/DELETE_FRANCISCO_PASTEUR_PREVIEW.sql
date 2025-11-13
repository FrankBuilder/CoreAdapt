-- ============================================================================
-- PREVIEW - O QUE SERÁ DELETADO
-- ============================================================================
-- Execute ESTA query PRIMEIRO para ver o que será apagado
-- NÃO deleta nada, apenas mostra
--
-- Contato: Francisco Pasteur
-- Telefones: 5585999855443, 85999855443
-- ============================================================================

-- ============================================================================
-- 1. IDENTIFICAR O CONTATO
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ CONTATO A SER DELETADO ━━━",
    '' AS " "
UNION ALL
SELECT
    c.id::text AS "ID",
    c.full_name AS "Nome"
FROM corev4_contacts c
WHERE
    c.full_name ILIKE '%Francisco%Pasteur%'
    OR c.whatsapp LIKE '%5585999855443%'
    OR c.whatsapp LIKE '%85999855443%'
    OR c.phone_number LIKE '%5585999855443%'
    OR c.phone_number LIKE '%85999855443%'
    OR c.email ILIKE '%francisco%pasteur%';


-- ============================================================================
-- 2. MENSAGENS QUE SERÃO DELETADAS
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ MENSAGENS ━━━",
    '' AS " "
UNION ALL
SELECT
    COUNT(ch.id)::text AS "Total de Mensagens",
    CONCAT('$', ROUND(SUM(ch.cost_usd), 4)) AS "Custo Total (USD)"
FROM corev4_chat_history ch
WHERE ch.contact_id IN (
    SELECT c.id FROM corev4_contacts c
    WHERE
        c.full_name ILIKE '%Francisco%Pasteur%'
        OR c.whatsapp LIKE '%5585999855443%'
        OR c.whatsapp LIKE '%85999855443%'
        OR c.phone_number LIKE '%5585999855443%'
        OR c.phone_number LIKE '%85999855443%'
);


-- ============================================================================
-- 3. N8N CHAT HISTORIES (Memória do AI Agent)
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ N8N CHAT HISTORIES ━━━",
    '' AS " "
UNION ALL
SELECT
    COUNT(nch.id)::text AS "Total de Registros N8N",
    '' AS " "
FROM corev4_n8n_chat_histories nch
WHERE nch.contact_id IN (
    SELECT c.id FROM corev4_contacts c
    WHERE
        c.full_name ILIKE '%Francisco%Pasteur%'
        OR c.whatsapp LIKE '%5585999855443%'
        OR c.whatsapp LIKE '%85999855443%'
);


-- ============================================================================
-- 4. FOLLOW-UPS QUE SERÃO DELETADOS
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ FOLLOW-UPS ━━━",
    '' AS " "
UNION ALL
SELECT
    COUNT(DISTINCT fc.id)::text AS "Campanhas de Follow-up",
    COUNT(fe.id)::text AS "Execuções de Follow-up"
FROM corev4_followup_campaigns fc
LEFT JOIN corev4_followup_executions fe ON fc.id = fe.campaign_id
WHERE fc.contact_id IN (
    SELECT c.id FROM corev4_contacts c
    WHERE
        c.full_name ILIKE '%Francisco%Pasteur%'
        OR c.whatsapp LIKE '%5585999855443%'
        OR c.whatsapp LIKE '%85999855443%'
);


-- ============================================================================
-- 5. REUNIÕES QUE SERÃO DELETADAS
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ REUNIÕES ━━━",
    '' AS " "
UNION ALL
SELECT
    COUNT(sm.id)::text AS "Total de Reuniões",
    COUNT(sm.id) FILTER (WHERE sm.meeting_completed)::text AS "Reuniões Realizadas"
FROM corev4_scheduled_meetings sm
WHERE sm.contact_id IN (
    SELECT c.id FROM corev4_contacts c
    WHERE
        c.full_name ILIKE '%Francisco%Pasteur%'
        OR c.whatsapp LIKE '%5585999855443%'
        OR c.whatsapp LIKE '%85999855443%'
);


-- ============================================================================
-- 6. LEAD STATE (ANUM)
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ LEAD STATE (ANUM) ━━━",
    '' AS " "
UNION ALL
SELECT
    COUNT(ls.contact_id)::text AS "Registros de Lead State",
    CONCAT('ANUM: ', ROUND(AVG(ls.total_score), 1), '/100') AS "ANUM Médio"
FROM corev4_lead_state ls
WHERE ls.contact_id IN (
    SELECT c.id FROM corev4_contacts c
    WHERE
        c.full_name ILIKE '%Francisco%Pasteur%'
        OR c.whatsapp LIKE '%5585999855443%'
        OR c.whatsapp LIKE '%85999855443%'
);


-- ============================================================================
-- 7. CHATS E EXTRAS
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ OUTROS DADOS ━━━",
    '' AS " "
UNION ALL
SELECT
    (SELECT COUNT(*) FROM corev4_chats ch WHERE ch.contact_id IN (
        SELECT c.id FROM corev4_contacts c
        WHERE c.full_name ILIKE '%Francisco%Pasteur%'
           OR c.whatsapp LIKE '%5585999855443%'
           OR c.whatsapp LIKE '%85999855443%'
    ))::text AS "Sessões de Chat",

    (SELECT COUNT(*) FROM corev4_contact_extras ce WHERE ce.contact_id IN (
        SELECT c.id FROM corev4_contacts c
        WHERE c.full_name ILIKE '%Francisco%Pasteur%'
           OR c.whatsapp LIKE '%5585999855443%'
           OR c.whatsapp LIKE '%85999855443%'
    ))::text AS "Contact Extras";


-- ============================================================================
-- 8. MESSAGE DEDUP
-- ============================================================================

SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━ MESSAGE DEDUP ━━━",
    '' AS " "
UNION ALL
SELECT
    COUNT(md.id)::text AS "Registros de Message Dedup",
    '' AS " "
FROM corev4_message_dedup md
WHERE md.whatsapp_id IN (
    SELECT c.whatsapp FROM corev4_contacts c
    WHERE
        c.full_name ILIKE '%Francisco%Pasteur%'
        OR c.whatsapp LIKE '%5585999855443%'
        OR c.whatsapp LIKE '%85999855443%'
);


-- ============================================================================
-- RESUMO FINAL
-- ============================================================================

WITH contact_to_delete AS (
    SELECT c.id, c.full_name, c.whatsapp, c.email
    FROM corev4_contacts c
    WHERE
        c.full_name ILIKE '%Francisco%Pasteur%'
        OR c.whatsapp LIKE '%5585999855443%'
        OR c.whatsapp LIKE '%85999855443%'
        OR c.phone_number LIKE '%5585999855443%'
        OR c.phone_number LIKE '%85999855443%'
)
SELECT
    '═══════════════════════════════════════════════════════════════' AS "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    '⚠️  RESUMO DO QUE SERÁ DELETADO' AS " ",
    '═══════════════════════════════════════════════════════════════' AS "  ",
    '' AS "   ",

    (SELECT COUNT(*) FROM contact_to_delete)::text AS "Contatos",

    (SELECT COUNT(*) FROM corev4_chat_history ch
     WHERE ch.contact_id IN (SELECT id FROM contact_to_delete))::text AS "Mensagens (corev4_chat_history)",

    (SELECT COUNT(*) FROM corev4_n8n_chat_histories nch
     WHERE nch.contact_id IN (SELECT id FROM contact_to_delete))::text AS "N8N Histories",

    (SELECT COUNT(*) FROM corev4_lead_state ls
     WHERE ls.contact_id IN (SELECT id FROM contact_to_delete))::text AS "Lead States (ANUM)",

    (SELECT COUNT(*) FROM corev4_followup_campaigns fc
     WHERE fc.contact_id IN (SELECT id FROM contact_to_delete))::text AS "Campanhas Follow-up",

    (SELECT COUNT(*) FROM corev4_followup_executions fe
     WHERE fe.contact_id IN (SELECT id FROM contact_to_delete))::text AS "Execuções Follow-up",

    (SELECT COUNT(*) FROM corev4_scheduled_meetings sm
     WHERE sm.contact_id IN (SELECT id FROM contact_to_delete))::text AS "Reuniões",

    (SELECT COUNT(*) FROM corev4_chats ch
     WHERE ch.contact_id IN (SELECT id FROM contact_to_delete))::text AS "Sessões Chat",

    (SELECT COUNT(*) FROM corev4_contact_extras ce
     WHERE ce.contact_id IN (SELECT id FROM contact_to_delete))::text AS "Contact Extras",

    '' AS "    ",
    '⚠️  SE ESTIVER CORRETO, EXECUTE O SCRIPT DE DELETE!' AS "     ",
    '═══════════════════════════════════════════════════════════════' AS "      ";


-- ============================================================================
-- INSTRUÇÕES
-- ============================================================================
--
-- 1. Execute ESTA query primeiro para revisar
-- 2. Confira se os dados são realmente os que você quer deletar
-- 3. Se estiver tudo OK, execute o arquivo: DELETE_FRANCISCO_PASTEUR_EXECUTE.sql
--
-- ⚠️ ATENÇÃO: A deleção é PERMANENTE e IRREVERSÍVEL!
-- ⚠️ Recomendamos fazer backup antes de deletar!
--
-- ============================================================================

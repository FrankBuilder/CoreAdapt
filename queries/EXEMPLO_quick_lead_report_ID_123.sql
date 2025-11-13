-- ============================================================================
-- EXEMPLO DE COMO USAR - Já com ID substituído
-- ============================================================================
-- Este é um EXEMPLO de como o arquivo quick_lead_report.sql deve ficar
-- DEPOIS de você substituir :contact_id por um ID real.
--
-- Neste exemplo, usei o ID = 123
-- Você deve substituir 123 pelo ID do seu lead!
--
-- COMO USAR:
-- 1. Copie TODO o conteúdo deste arquivo (Cmd+A, Cmd+C)
-- 2. Vá para: https://supabase.com/dashboard → seu projeto → SQL Editor
-- 3. Cole (Cmd+V)
-- 4. Clique em "Run" (ou Cmd+Enter)
-- 5. Veja o relatório aparecer!
-- ============================================================================

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
FROM corev4_contacts c WHERE c.id = 123  -- ← SUBSTITUA 123 pelo ID real!

UNION ALL
SELECT
    CONCAT('WhatsApp: ', c.whatsapp) AS info,
    CONCAT('Email: ', COALESCE(c.email, 'N/A')) AS " "
FROM corev4_contacts c WHERE c.id = 123  -- ← SUBSTITUA 123 pelo ID real!

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
WHERE c.id = 123  -- ← SUBSTITUA 123 pelo ID real!

UNION ALL
SELECT
    CONCAT('ANUM Total: ', ROUND(COALESCE(ls.total_score, 0)::numeric, 1), '/100 - ',
        UPPER(COALESCE(ls.qualification_stage, 'N/A')),
        CASE WHEN ls.is_qualified THEN ' ✓ QUALIFICADO' ELSE ' ○ NÃO QUALIFICADO' END
    ) AS info,
    '' AS " "
FROM corev4_lead_state ls WHERE ls.contact_id = 123  -- ← SUBSTITUA 123 pelo ID real!

UNION ALL
SELECT
    CONCAT('  └─ A:', ROUND(COALESCE(ls.authority_score, 0)::numeric, 1),
           ' | N:', ROUND(COALESCE(ls.need_score, 0)::numeric, 1),
           ' | U:', ROUND(COALESCE(ls.urgency_score, 0)::numeric, 1),
           ' | M:', ROUND(COALESCE(ls.money_score, 0)::numeric, 1)
    ) AS info,
    '' AS " "
FROM corev4_lead_state ls WHERE ls.contact_id = 123;  -- ← SUBSTITUA 123 pelo ID real!

-- ============================================================================
-- OBSERVAÇÃO:
-- Este é apenas um EXEMPLO com as primeiras linhas.
-- O arquivo completo tem cerca de 500 linhas e gera um relatório detalhado.
--
-- Para usar o arquivo completo:
-- 1. Abra: queries/quick_lead_report.sql
-- 2. Use Cmd+F (buscar) e procure por: :contact_id
-- 3. Use Cmd+Option+F (substituir) e substitua TODOS por: 123 (ou seu ID)
-- 4. Copie tudo (Cmd+A, Cmd+C)
-- 5. Cole no Supabase SQL Editor
-- 6. Execute!
-- ============================================================================

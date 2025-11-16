-- ============================================================================
-- EXECUTE ESTAS QUERIES NO SUPABASE PARA DIAGNOSTICAR FOLLOWUPS DUPLICADOS
-- ============================================================================
-- Cole os resultados aqui no chat para eu analisar
-- ============================================================================


-- ============================================================================
-- QUERY 1: Verificar se há campanhas com múltiplos steps pendentes AGORA
-- ============================================================================
-- Esta query mostra campanhas que TÊM o problema (múltiplos steps vencidos)

SELECT
    campaign_id,
    COUNT(*) as steps_pendentes,
    STRING_AGG(
        'Step ' || step::text ||
        ' (agendado: ' || to_char(scheduled_at, 'DD/MM HH24:MI') || ')',
        ' | '
        ORDER BY step
    ) as detalhes_steps
FROM corev4_followup_executions
WHERE executed = false
  AND should_send = true
  AND scheduled_at <= NOW()
GROUP BY campaign_id
HAVING COUNT(*) > 1
ORDER BY steps_pendentes DESC
LIMIT 20;

-- ✅ Se retornar 0 linhas: Não há problema ativo
-- ⚠️  Se retornar linhas: Há campanhas que enviariam múltiplos steps


-- ============================================================================
-- QUERY 2: Comparar query ANTIGA (com bug) vs NOVA (corrigida)
-- ============================================================================
-- Mostra quantos followups seriam enviados com cada abordagem

WITH query_antiga AS (
    -- Simula comportamento ANTES da correção
    SELECT COUNT(*) as total
    FROM corev4_followup_executions e
    INNER JOIN corev4_contacts c ON c.id = e.contact_id
    WHERE e.executed = false
      AND e.should_send = true
      AND e.scheduled_at <= NOW()
),
query_nova AS (
    -- Simula comportamento DEPOIS da correção
    SELECT COUNT(*) as total
    FROM (
        SELECT DISTINCT ON (e.campaign_id) e.id
        FROM corev4_followup_executions e
        INNER JOIN corev4_contacts c ON c.id = e.contact_id
        WHERE e.executed = false
          AND e.should_send = true
          AND e.scheduled_at <= NOW()
        ORDER BY e.campaign_id, e.step ASC
    ) subquery
)
SELECT
    'ANTIGA (com bug)' as versao,
    (SELECT total FROM query_antiga) as followups_enviados,
    'Pode enviar múltiplos steps da mesma campanha' as comportamento
UNION ALL
SELECT
    'NOVA (corrigida)',
    (SELECT total FROM query_nova),
    'Envia apenas 1 step por campanha (o mais antigo)';

-- Interpretação:
-- Se os números forem IGUAIS: Não há problema ativo no momento
-- Se ANTIGA > NOVA: A diferença mostra quantos followups duplicados seriam evitados


-- ============================================================================
-- QUERY 3: Ver exemplo de campanha que TERIA problema
-- ============================================================================
-- Mostra detalhes de uma campanha específica com múltiplos steps pendentes

SELECT
    e.campaign_id,
    e.step,
    e.executed,
    e.should_send,
    e.scheduled_at,
    to_char(e.scheduled_at, 'DD/MM/YYYY HH24:MI') as agendado_formatado,
    CASE
        WHEN e.scheduled_at <= NOW() THEN '✓ VENCIDO (seria enviado)'
        ELSE '✗ Futuro (não envia ainda)'
    END as status,
    c.full_name as lead_nome,
    c.phone_number
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
WHERE e.campaign_id IN (
    -- Pegar uma campanha que tem múltiplos steps pendentes
    SELECT campaign_id
    FROM corev4_followup_executions
    WHERE executed = false
      AND should_send = true
      AND scheduled_at <= NOW()
    GROUP BY campaign_id
    HAVING COUNT(*) > 1
    LIMIT 1
)
ORDER BY e.step;

-- Interpretação:
-- Se houver múltiplas linhas com "✓ VENCIDO":
--   ANTES: Todos seriam enviados juntos
--   DEPOIS: Apenas o Step menor seria enviado


-- ============================================================================
-- QUERY 4: Simular o que a QUERY CORRIGIDA retornaria
-- ============================================================================
-- Esta é EXATAMENTE a query que está no Sentinel agora (após correção)

SELECT DISTINCT ON (e.campaign_id)
  e.id AS execution_id,
  e.campaign_id,
  e.step,
  e.scheduled_at,
  to_char(e.scheduled_at, 'DD/MM HH24:MI') as agendado_formatado,
  c.full_name AS contact_name,
  c.phone_number
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
INNER JOIN corev4_companies co ON co.id = e.company_id
LEFT JOIN corev4_followup_campaigns fc ON fc.id = e.campaign_id
WHERE e.executed = false
  AND e.should_send = true
  AND c.opt_out = false
  AND e.scheduled_at <= NOW()
  AND (
    c.last_interaction_at IS NULL
    OR c.last_interaction_at < e.scheduled_at
  )
  AND (
    ls.total_score IS NULL
    OR ls.total_score < 70
  )
ORDER BY e.campaign_id, e.step ASC, e.scheduled_at ASC
LIMIT 10;

-- Interpretação:
-- Cada campaign_id aparece NO MÁXIMO 1 vez
-- Sempre o step MENOR (primeiro não executado)


-- ============================================================================
-- QUERY 5: Verificar estrutura da tabela (confirmar campos existem)
-- ============================================================================

SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'corev4_followup_executions'
  AND column_name IN ('campaign_id', 'step', 'executed', 'should_send', 'scheduled_at')
ORDER BY ordinal_position;

-- Deve retornar 5 linhas confirmando que os campos existem


-- ============================================================================
-- INSTRUÇÕES DE USO:
-- ============================================================================
-- 1. Copie cada query (de QUERY 1 até QUERY 5)
-- 2. Execute no Supabase SQL Editor
-- 3. Cole os resultados aqui no chat
-- 4. Eu vou analisar e confirmar se a correção está funcionando
-- ============================================================================

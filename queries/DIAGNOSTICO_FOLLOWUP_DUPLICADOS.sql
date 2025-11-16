-- ============================================================================
-- DIAGNÓSTICO: Followups Duplicados (Múltiplos steps enviados juntos)
-- ============================================================================
-- Este script investiga o problema onde múltiplos followups de uma mesma
-- campanha são enviados simultaneamente quando vencem durante espera de horário
-- ============================================================================

-- ============================================================================
-- 1. SCHEMA DAS TABELAS (para entender estrutura)
-- ============================================================================

-- Verificar colunas de corev4_followup_executions
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'corev4_followup_executions'
ORDER BY ordinal_position;

-- Verificar colunas de corev4_followup_campaigns
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'corev4_followup_campaigns'
ORDER BY ordinal_position;

-- Verificar colunas de corev4_followup_steps
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'corev4_followup_steps'
ORDER BY ordinal_position;


-- ============================================================================
-- 2. IDENTIFICAR CAMPANHAS COM MÚLTIPLOS STEPS PENDENTES
-- ============================================================================

-- Campanhas que têm mais de 1 step pendente (scheduled_at vencido)
SELECT
    campaign_id,
    COUNT(*) as steps_pendentes,
    STRING_AGG(step::text || ' (scheduled: ' || scheduled_at::text || ')', ', ' ORDER BY step) as detalhes
FROM corev4_followup_executions
WHERE executed = false
  AND should_send = true
  AND scheduled_at <= NOW()
GROUP BY campaign_id
HAVING COUNT(*) > 1
ORDER BY steps_pendentes DESC;


-- ============================================================================
-- 3. DETALHES DE UMA CAMPANHA ESPECÍFICA COM PROBLEMA
-- ============================================================================

-- Ver todos os steps de uma campanha específica (substitua o ID)
-- SELECT * FROM corev4_followup_executions
-- WHERE campaign_id = 'COLE_O_ID_AQUI'
-- ORDER BY step;


-- ============================================================================
-- 4. VERIFICAR LÓGICA ATUAL DA QUERY DO SENTINEL
-- ============================================================================

-- Esta é a query ATUAL do Sentinel (com problema)
-- Ela seleciona TODOS os steps pendentes, sem filtrar por "primeiro step não executado"
SELECT
  e.id AS execution_id,
  e.campaign_id,
  e.contact_id,
  e.step,
  e.scheduled_at,
  c.full_name AS contact_name,
  c.phone_number,
  fc.steps_completed AS campaign_steps_completed
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
INNER JOIN corev4_followup_campaigns fc ON fc.id = e.campaign_id
WHERE e.executed = false
  AND e.should_send = true
  AND e.scheduled_at <= NOW()
ORDER BY e.scheduled_at ASC
LIMIT 10;


-- ============================================================================
-- 5. IDENTIFICAR CASOS ONDE STEP POSTERIOR VENCE ANTES DO ANTERIOR
-- ============================================================================

-- Encontrar execuções onde um step posterior está agendado ANTES do anterior
SELECT
    e1.campaign_id,
    e1.step as step_anterior,
    e1.scheduled_at as agendado_anterior,
    e1.executed as executado_anterior,
    e2.step as step_posterior,
    e2.scheduled_at as agendado_posterior,
    e2.executed as executado_posterior,
    CASE
        WHEN e1.executed = false AND e2.executed = false AND e2.scheduled_at <= NOW()
        THEN '🚨 PROBLEMA: Ambos vencidos e não executados'
        ELSE 'OK'
    END as status
FROM corev4_followup_executions e1
INNER JOIN corev4_followup_executions e2
    ON e1.campaign_id = e2.campaign_id
    AND e2.step = e1.step + 1
WHERE e1.executed = false
ORDER BY e1.campaign_id, e1.step;


-- ============================================================================
-- 6. SIMULAR A QUERY CORRIGIDA (com DISTINCT ON para pegar apenas primeiro step)
-- ============================================================================

-- Query CORRIGIDA: Pega apenas o PRIMEIRO step pendente de cada campanha
SELECT DISTINCT ON (e.campaign_id)
  e.id AS execution_id,
  e.campaign_id,
  e.contact_id,
  e.step,
  e.scheduled_at,
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
LIMIT 50;


-- ============================================================================
-- 7. COMPARAR RESULTADOS: QUERY ATUAL vs QUERY CORRIGIDA
-- ============================================================================

-- QUERY ATUAL (sem filtro de step único por campanha)
SELECT 'ATUAL (com bug)' as tipo, COUNT(*) as total_executions
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
WHERE e.executed = false
  AND e.should_send = true
  AND e.scheduled_at <= NOW()

UNION ALL

-- QUERY CORRIGIDA (apenas primeiro step por campanha)
SELECT 'CORRIGIDA', COUNT(*)
FROM (
    SELECT DISTINCT ON (e.campaign_id) e.id
    FROM corev4_followup_executions e
    INNER JOIN corev4_contacts c ON c.id = e.contact_id
    WHERE e.executed = false
      AND e.should_send = true
      AND e.scheduled_at <= NOW()
    ORDER BY e.campaign_id, e.step ASC
) subquery;


-- ============================================================================
-- 8. VERIFICAR HORÁRIO DE ENVIO (Business Hours)
-- ============================================================================

-- Ver se existe controle de horário de envio
SELECT
    table_name,
    column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    column_name LIKE '%business%'
    OR column_name LIKE '%hour%'
    OR column_name LIKE '%schedule%'
  )
  AND table_name LIKE 'corev4_%'
ORDER BY table_name;


-- ============================================================================
-- INSTRUÇÕES DE USO:
-- ============================================================================
-- 1. Execute cada seção separadamente
-- 2. Seção 2: Identifica campanhas com problema
-- 3. Seção 4: Mostra o que a query atual retorna (com duplicatas)
-- 4. Seção 6: Mostra o que a query corrigida retornaria (sem duplicatas)
-- 5. Seção 7: Compara quantos followups seriam enviados (ATUAL vs CORRIGIDO)
-- ============================================================================

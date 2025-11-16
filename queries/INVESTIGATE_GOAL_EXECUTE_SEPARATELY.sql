-- ============================================================================
-- EXECUTE CADA QUERY SEPARADAMENTE E COLE OS RESULTADOS AQUI NO CHAT
-- ============================================================================
-- Copie e execute UMA POR VEZ no Supabase
-- ============================================================================


-- ============================================================================
-- QUERY 1: Campos relacionados a goal/meeting
-- ============================================================================
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name LIKE 'corev4_%'
  AND (
    column_name ILIKE '%goal%'
    OR column_name ILIKE '%objective%'
    OR column_name ILIKE '%target%'
    OR column_name ILIKE '%meeting%'
    OR column_name ILIKE '%scheduled%'
    OR column_name ILIKE '%appointment%'
  )
ORDER BY table_name, column_name;


-- ============================================================================
-- QUERY 2: Estrutura de corev4_followup_campaigns
-- ============================================================================
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'corev4_followup_campaigns'
ORDER BY ordinal_position;


-- ============================================================================
-- QUERY 3: Estrutura de corev4_followup_steps (TIMINGS)
-- ============================================================================
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'corev4_followup_steps'
ORDER BY ordinal_position;


-- ============================================================================
-- QUERY 4: DADOS - Ver timings configurados (CRÍTICO!)
-- ============================================================================
SELECT
    config_id,
    step_number,
    wait_hours,
    wait_minutes
FROM corev4_followup_steps
ORDER BY config_id, step_number
LIMIT 20;


-- ============================================================================
-- QUERY 5: DADOS - Exemplo de campanha
-- ============================================================================
SELECT *
FROM corev4_followup_campaigns
LIMIT 3;


-- ============================================================================
-- QUERY 6: Tabelas de reuniões
-- ============================================================================
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND (
    table_name LIKE '%meeting%'
    OR table_name LIKE '%appointment%'
    OR table_name LIKE '%schedule%'
  );


-- ============================================================================
-- QUERY 7: Estrutura de corev4_scheduled_meetings
-- ============================================================================
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'corev4_scheduled_meetings'
ORDER BY ordinal_position;

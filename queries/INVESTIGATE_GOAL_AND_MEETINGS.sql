-- ============================================================================
-- INVESTIGAÇÃO: Objetivo do Tenant e Sistema de Reuniões
-- ============================================================================

-- 1. SCHEMA: Verificar campos relacionados a objetivo/goal
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


-- 2. SCHEMA: Estrutura completa da tabela corev4_companies
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'corev4_companies'
ORDER BY ordinal_position;


-- 3. SCHEMA: Estrutura completa da tabela corev4_followup_campaigns
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'corev4_followup_campaigns'
ORDER BY ordinal_position;


-- 4. SCHEMA: Verificar se existe tabela de reuniões
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE '%meeting%'
     OR table_name LIKE '%appointment%'
     OR table_name LIKE '%schedule%';


-- 5. SCHEMA: Estrutura da tabela corev4_followup_steps (timings)
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'corev4_followup_steps'
ORDER BY ordinal_position;


-- 6. DADOS: Ver exemplo de configuração de steps (timings)
SELECT
    config_id,
    step_number,
    wait_hours,
    wait_minutes,
    step_type
FROM corev4_followup_steps
ORDER BY config_id, step_number
LIMIT 20;


-- 7. DADOS: Ver campos da campanha que podem indicar objetivo
SELECT *
FROM corev4_followup_campaigns
LIMIT 3;


-- 8. DADOS: Ver se há algum campo em companies relacionado a objetivo
SELECT *
FROM corev4_companies
LIMIT 2;

-- ============================================================================
-- CLEANUP: Remove dados parciais da Dra. Ilana (caso tenha dado erro)
-- ============================================================================
-- Execute ANTES de rodar o 01_QUICK_SETUP.sql novamente
-- ============================================================================

-- 1. Deletar steps de followup (se existirem)
DELETE FROM corev4_followup_steps
WHERE config_id IN (
    SELECT fc.id
    FROM corev4_followup_configs fc
    JOIN corev4_companies c ON c.id = fc.company_id
    WHERE c.slug = 'ilana-feingold'
);

-- 2. Deletar config de followup (se existir)
DELETE FROM corev4_followup_configs
WHERE company_id IN (
    SELECT id FROM corev4_companies WHERE slug = 'ilana-feingold'
);

-- 3. Deletar categorias (se existirem)
DELETE FROM corev4_pain_categories
WHERE company_id IN (
    SELECT id FROM corev4_companies WHERE slug = 'ilana-feingold'
);

-- 4. Deletar empresa (se existir)
DELETE FROM corev4_companies
WHERE slug = 'ilana-feingold';

-- Verificar que foi limpo
SELECT 'Cleanup concluído' as status,
       (SELECT COUNT(*) FROM corev4_companies WHERE slug = 'ilana-feingold') as empresas_restantes;

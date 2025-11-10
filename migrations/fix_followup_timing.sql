-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIX FOLLOWUP TIMING
-- Data: 2025-11-10
-- Motivo: Corrigir timing incorreto das campanhas de follow-up
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ANTES (INCORRETO):
-- Step 1: 1h ✅
-- Step 2: 25h (~1d) ❌ Deveria ser 4h
-- Step 3: 73h (~3d) ❌ Deveria ser 24h (1d)
-- Step 4: 145h (~6d) ❌ Deveria ser 72h (3d)
-- Step 5: 313h (~13d) ❌ Deveria ser 168h (7d)

-- DEPOIS (CORRETO):
-- Step 1: 1h
-- Step 2: 4h
-- Step 3: 24h (1d)
-- Step 4: 72h (3d)
-- Step 5: 168h (7d)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BEGIN;

-- Backup dos valores antigos (para auditoria)
DO $$
BEGIN
  RAISE NOTICE '=== VALORES ANTIGOS ===';
  RAISE NOTICE 'Step | wait_hours | wait_minutes | Total';
END $$;

DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT step_number, wait_hours, wait_minutes,
           (wait_hours + ROUND(wait_minutes::numeric / 60, 2)) as total_hours
    FROM corev4_followup_steps
    ORDER BY step_number
  LOOP
    RAISE NOTICE '% | % | % | %h', rec.step_number, rec.wait_hours, rec.wait_minutes, rec.total_hours;
  END LOOP;
END $$;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ATUALIZAÇÕES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Step 1: 1h (JÁ CORRETO, mas atualizando para garantir)
UPDATE corev4_followup_steps
SET
  wait_hours = 1,
  wait_minutes = 0,
  updated_at = NOW()
WHERE step_number = 1;

-- Step 2: 25h → 4h
UPDATE corev4_followup_steps
SET
  wait_hours = 4,
  wait_minutes = 0,
  updated_at = NOW()
WHERE step_number = 2;

-- Step 3: 73h → 24h (1 dia)
UPDATE corev4_followup_steps
SET
  wait_hours = 24,
  wait_minutes = 0,
  updated_at = NOW()
WHERE step_number = 3;

-- Step 4: 145h → 72h (3 dias)
UPDATE corev4_followup_steps
SET
  wait_hours = 72,
  wait_minutes = 0,
  updated_at = NOW()
WHERE step_number = 4;

-- Step 5: 313h → 168h (7 dias)
UPDATE corev4_followup_steps
SET
  wait_hours = 168,
  wait_minutes = 0,
  updated_at = NOW()
WHERE step_number = 5;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VERIFICAÇÃO
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== VALORES NOVOS ===';
  RAISE NOTICE 'Step | wait_hours | wait_minutes | Total';
END $$;

DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT step_number, wait_hours, wait_minutes,
           (wait_hours + ROUND(wait_minutes::numeric / 60, 2)) as total_hours
    FROM corev4_followup_steps
    ORDER BY step_number
  LOOP
    RAISE NOTICE '% | % | % | %h', rec.step_number, rec.wait_hours, rec.wait_minutes, rec.total_hours;
  END LOOP;
END $$;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VALIDAÇÃO
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DO $$
DECLARE
  v_step1 INTEGER;
  v_step2 INTEGER;
  v_step3 INTEGER;
  v_step4 INTEGER;
  v_step5 INTEGER;
BEGIN
  SELECT wait_hours INTO v_step1 FROM corev4_followup_steps WHERE step_number = 1;
  SELECT wait_hours INTO v_step2 FROM corev4_followup_steps WHERE step_number = 2;
  SELECT wait_hours INTO v_step3 FROM corev4_followup_steps WHERE step_number = 3;
  SELECT wait_hours INTO v_step4 FROM corev4_followup_steps WHERE step_number = 4;
  SELECT wait_hours INTO v_step5 FROM corev4_followup_steps WHERE step_number = 5;

  RAISE NOTICE '';
  RAISE NOTICE '=== VALIDAÇÃO ===';

  IF v_step1 = 1 AND v_step2 = 4 AND v_step3 = 24 AND v_step4 = 72 AND v_step5 = 168 THEN
    RAISE NOTICE '✅ TIMING CORRETO! Todos os steps foram atualizados com sucesso.';
  ELSE
    RAISE EXCEPTION '❌ ERRO: Timing incorreto após atualização!';
  END IF;
END $$;

COMMIT;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- IMPACTO EM CAMPANHAS ATIVAS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- NOTA: Campanhas já criadas COM timing antigo NÃO serão afetadas
-- pois os scheduled_at já foram calculados e salvos.
--
-- AÇÃO RECOMENDADA:
-- 1. Aguardar campanhas ativas terminarem naturalmente, OU
-- 2. Forçar recálculo via: SELECT recalculate_followup_schedule(contact_id, NOW())
--    para cada campanha ativa
--
-- Para recalcular TODAS as campanhas ativas:
-- (EXECUTAR APENAS SE NECESSÁRIO)
/*
DO $$
DECLARE
  rec RECORD;
  v_count INTEGER := 0;
BEGIN
  FOR rec IN
    SELECT DISTINCT contact_id
    FROM corev4_followup_campaigns
    WHERE status = 'active' AND should_continue = true
  LOOP
    PERFORM recalculate_followup_schedule(rec.contact_id, NOW());
    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'Recalculadas % campanhas ativas com novo timing.', v_count;
END $$;
*/

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIM DA MIGRATION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ADD BUSINESS HOURS TRIGGER FOR FOLLOWUP EXECUTIONS
-- Data: 2025-11-10
-- Motivo: Ajustar automaticamente scheduled_at ao inserir novas executions
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- PREREQUISITO: adjust_to_business_hours já deve estar criado
-- Execute antes: add_business_hours_function.sql

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FUNÇÃO TRIGGER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE OR REPLACE FUNCTION adjust_followup_execution_business_hours()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
BEGIN
  -- Ajustar scheduled_at para horário comercial
  NEW.scheduled_at := adjust_to_business_hours(NEW.scheduled_at);

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION adjust_followup_execution_business_hours() IS
'Trigger function que ajusta scheduled_at para horário comercial
automaticamente quando nova execution é inserida ou atualizada.

Garante que TODAS as executions respeitam:
- Segunda-Sexta: 08:00-18:00
- Sábado: 08:00-12:00
- Domingo: agenda para Segunda 08:00';

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TRIGGER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Drop trigger if exists (para permitir re-executar migration)
DROP TRIGGER IF EXISTS adjust_business_hours_on_insert ON corev4_followup_executions;
DROP TRIGGER IF EXISTS adjust_business_hours_on_update ON corev4_followup_executions;

-- Trigger para INSERT
CREATE TRIGGER adjust_business_hours_on_insert
  BEFORE INSERT ON corev4_followup_executions
  FOR EACH ROW
  EXECUTE FUNCTION adjust_followup_execution_business_hours();

-- Trigger para UPDATE (caso scheduled_at seja modificado)
CREATE TRIGGER adjust_business_hours_on_update
  BEFORE UPDATE OF scheduled_at ON corev4_followup_executions
  FOR EACH ROW
  WHEN (OLD.scheduled_at IS DISTINCT FROM NEW.scheduled_at)
  EXECUTE FUNCTION adjust_followup_execution_business_hours();

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- COMENTÁRIOS DOS TRIGGERS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

COMMENT ON TRIGGER adjust_business_hours_on_insert ON corev4_followup_executions IS
'Ajusta scheduled_at automaticamente para horário comercial quando nova execution é criada.
Executado ANTES do INSERT para garantir que o valor salvo já está correto.';

COMMENT ON TRIGGER adjust_business_hours_on_update ON corev4_followup_executions IS
'Ajusta scheduled_at automaticamente para horário comercial quando scheduled_at é atualizado.
Executado ANTES do UPDATE apenas quando scheduled_at realmente mudou.';

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TESTE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DO $$
DECLARE
  v_test_id INTEGER;
  v_scheduled TIMESTAMPTZ;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== TESTE: Trigger adjust_business_hours_on_insert ===';
  RAISE NOTICE '';

  -- Teste 1: Inserir execution agendada para Domingo 10:00
  -- Esperado: Ajustar para Segunda 08:00

  BEGIN
    -- Criar uma execution temporária para teste
    INSERT INTO corev4_followup_executions (
      campaign_id,
      contact_id,
      company_id,
      step,
      total_steps,
      scheduled_at,
      executed,
      should_send
    )
    VALUES (
      999999, -- campaign_id fictício (será deletado)
      999999, -- contact_id fictício
      1,      -- company_id
      1,      -- step
      5,      -- total_steps
      '2025-11-16 10:00:00-03'::TIMESTAMPTZ, -- Domingo 10:00
      false,
      true
    )
    RETURNING id, scheduled_at INTO v_test_id, v_scheduled;

    RAISE NOTICE 'Teste 1 - INSERT:';
    RAISE NOTICE '  Input: Domingo 2025-11-16 10:00:00';
    RAISE NOTICE '  Output (ajustado): %', v_scheduled;
    RAISE NOTICE '  Esperado: Segunda 2025-11-17 08:00:00';
    RAISE NOTICE '';

    -- Limpar teste
    DELETE FROM corev4_followup_executions WHERE id = v_test_id;

  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'Teste falhou (expected - campaign/contact não existem): %', SQLERRM;
      RAISE NOTICE 'Para testar com dados reais, use campaign_id e contact_id válidos.';
      RAISE NOTICE '';
  END;

  -- Teste 2: Atualizar scheduled_at de Sexta 20:00 para Sexta 20:00
  -- Esperado: Ajustar para Segunda 08:00

  RAISE NOTICE 'Teste 2 - UPDATE:';
  RAISE NOTICE '  Para testar, execute:';
  RAISE NOTICE '  UPDATE corev4_followup_executions';
  RAISE NOTICE '  SET scheduled_at = ''2025-11-14 20:00:00-03''::TIMESTAMPTZ';
  RAISE NOTICE '  WHERE id = <execution_id>;';
  RAISE NOTICE '';
  RAISE NOTICE '  Resultado esperado: scheduled_at ajustado para Segunda 08:00';
  RAISE NOTICE '';

  RAISE NOTICE '=== FIM DOS TESTES ===';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Trigger instalado com sucesso!';
  RAISE NOTICE '✅ Todas novas executions respeitarão horário comercial automaticamente.';
END $$;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- IMPACTO
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ✅ Novas campanhas criadas via "Create Followup Campaign" workflow:
--    → Já terão scheduled_at ajustado automaticamente

-- ✅ Recálculo via recalculate_followup_schedule():
--    → Já ajusta via função (modificação anterior)

-- ✅ Qualquer UPDATE manual em scheduled_at:
--    → Será ajustado automaticamente pelo trigger

-- ⚠️  Executions JÁ CRIADAS (antes desta migration):
--    → NÃO serão retroativamente ajustadas
--    → Próximo recalculate (quando lead responder) ajustará automaticamente

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIM DA MIGRATION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

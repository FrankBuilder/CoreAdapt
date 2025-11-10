-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INTEGRATE BUSINESS HOURS IN recalculate_followup_schedule
-- Data: 2025-11-10
-- Motivo: Fazer recalculate_followup_schedule respeitar horário comercial
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- PREREQUISITO: adjust_to_business_hours já deve estar criado
-- Execute antes: add_business_hours_function.sql

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE OR REPLACE FUNCTION public.recalculate_followup_schedule(
  p_contact_id bigint,
  p_interaction_timestamp timestamp with time zone DEFAULT now()
)
RETURNS TABLE(
  execution_id integer,
  old_scheduled_at timestamp with time zone,
  new_scheduled_at timestamp with time zone,
  step_number integer
)
LANGUAGE PLPGSQL
VOLATILE
AS $$

DECLARE
  v_updated_count INTEGER := 0;
BEGIN

  -- ✅ PASSO 1: Atualizar last_interaction_at no contato
  UPDATE corev4_contacts
  SET
    last_interaction_at = p_interaction_timestamp,
    updated_at = NOW()
  WHERE id = p_contact_id;

  -- ✅ PASSO 2: Recalcular scheduled_at para TODOS os followups pendentes
  -- ✅ NOVO: Ajustar para horário comercial
  RETURN QUERY
  WITH old_values AS (
    SELECT
      e.id,
      e.scheduled_at as old_scheduled,
      e.step
    FROM corev4_followup_executions e
    INNER JOIN corev4_followup_campaigns fc ON e.campaign_id = fc.id
    WHERE e.contact_id = p_contact_id
      AND e.executed = FALSE
      AND e.should_send = TRUE
      AND fc.should_continue = TRUE
  ),
  updated_executions AS (
    UPDATE corev4_followup_executions e
    SET
      -- ✅ MUDANÇA: Envolve o cálculo em adjust_to_business_hours
      scheduled_at = adjust_to_business_hours(
        p_interaction_timestamp +
          (fs.wait_hours * INTERVAL '1 hour') +
          (fs.wait_minutes * INTERVAL '1 minute')
      ),
      updated_at = NOW()
    FROM
      corev4_followup_campaigns fc,
      corev4_followup_steps fs
    WHERE
      e.campaign_id = fc.id
      AND fs.config_id = fc.config_id
      AND fs.step_number = e.step
      AND e.contact_id = p_contact_id
      AND e.executed = FALSE
      AND e.should_send = TRUE
      AND fc.should_continue = TRUE
    RETURNING
      e.id,
      e.scheduled_at as new_scheduled,
      e.step
  )
  SELECT
    ue.id as execution_id,
    ov.old_scheduled as old_scheduled_at,
    ue.new_scheduled as new_scheduled_at,
    ue.step as step_number
  FROM updated_executions ue
  INNER JOIN old_values ov ON ue.id = ov.id;

  -- Log execution count
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  RAISE NOTICE 'Recalculated % followup executions for contact % (with business hours adjustment)',
    v_updated_count, p_contact_id;

END;
$$;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- COMENTÁRIO ATUALIZADO
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

COMMENT ON FUNCTION recalculate_followup_schedule(BIGINT, TIMESTAMPTZ) IS
'Recalcula scheduled_at de todos os followups pendentes quando lead responde.

MUDANÇA (2025-11-10): Agora respeita horário comercial via adjust_to_business_hours():
- Segunda-Sexta: 08:00-18:00
- Sábado: 08:00-12:00
- Domingo: agenda para Segunda 08:00

Exemplo:
- Lead responde Sexta 19:00
- Step 2 timing: +4h
- Cálculo bruto: Sexta 23:00
- Ajustado: Sábado 08:00 (respeita business hours)

Parâmetros:
- p_contact_id: ID do contato que respondeu
- p_interaction_timestamp: Quando respondeu (default NOW())

Retorna:
- execution_id: ID da execução recalculada
- old_scheduled_at: Timestamp antigo
- new_scheduled_at: Timestamp novo (com business hours)
- step_number: Qual step (1-5)';

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TESTE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== TESTE: recalculate_followup_schedule com Business Hours ===';
  RAISE NOTICE '';
  RAISE NOTICE 'Cenário: Lead responde Sexta 19:00';
  RAISE NOTICE 'Step 2 timing: +4h';
  RAISE NOTICE 'Cálculo bruto: Sexta 23:00';
  RAISE NOTICE 'Esperado: Sábado 08:00 (ajustado para business hours)';
  RAISE NOTICE '';
  RAISE NOTICE 'Para testar com dados reais, execute:';
  RAISE NOTICE 'SELECT * FROM recalculate_followup_schedule(<contact_id>, ''2025-11-14 19:00:00-03''::TIMESTAMPTZ);';
  RAISE NOTICE '';
END $$;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIM DA MIGRATION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ============================================================================
-- TRIGGER: Reagendar Followups quando Lead Interage
-- ============================================================================
-- Quando last_interaction_at é atualizado em corev4_contacts,
-- recalcula scheduled_at de todos os followups pendentes
-- ============================================================================

-- Função que reagenda followups
CREATE OR REPLACE FUNCTION reagendar_followups_on_interaction()
RETURNS TRIGGER AS $$
BEGIN
  -- Apenas reagenda se last_interaction_at mudou
  IF NEW.last_interaction_at IS DISTINCT FROM OLD.last_interaction_at THEN

    UPDATE corev4_followup_executions e
    SET
      scheduled_at = NEW.last_interaction_at +
                     (fs.wait_hours || ' hours')::INTERVAL +
                     (fs.wait_minutes || ' minutes')::INTERVAL,
      updated_at = NOW()
    FROM corev4_followup_campaigns fc
    INNER JOIN corev4_followup_steps fs
      ON fs.config_id = fc.config_id
      AND fs.step_number = e.step
    WHERE e.contact_id = NEW.id
      AND e.campaign_id = fc.id
      AND e.executed = false
      AND e.should_send = true;

    RAISE NOTICE 'Followups reagendados para contact_id %', NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Criar trigger
DROP TRIGGER IF EXISTS trigger_reagendar_followups ON corev4_contacts;

CREATE TRIGGER trigger_reagendar_followups
  AFTER UPDATE OF last_interaction_at ON corev4_contacts
  FOR EACH ROW
  EXECUTE FUNCTION reagendar_followups_on_interaction();


-- ============================================================================
-- TESTE: Verificar se trigger foi criado
-- ============================================================================
SELECT
  trigger_name,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'trigger_reagendar_followups';


-- ============================================================================
-- INSTRUÇÕES:
-- ============================================================================
-- 1. Execute este SQL no Supabase SQL Editor
-- 2. Verifique que o trigger foi criado (última query)
-- 3. Teste: Atualize last_interaction_at de um contact com followups pendentes
-- 4. Verifique que scheduled_at foi recalculado
-- ============================================================================

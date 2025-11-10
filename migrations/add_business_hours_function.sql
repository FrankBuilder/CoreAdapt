-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ADD BUSINESS HOURS FUNCTION
-- Data: 2025-11-10
-- Motivo: Respeitar horário comercial nas campanhas de follow-up
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- HORÁRIO COMERCIAL:
-- Segunda à Sexta: 08:00 - 18:00
-- Sábado: 08:00 - 12:00
-- Domingo: NÃO ENVIA (agenda para Segunda 08:00)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CREATE OR REPLACE FUNCTION adjust_to_business_hours(
  p_timestamp TIMESTAMPTZ,
  p_timezone TEXT DEFAULT 'America/Fortaleza'
)
RETURNS TIMESTAMPTZ
LANGUAGE PLPGSQL
IMMUTABLE
AS $$
DECLARE
  v_local_time TIMESTAMPTZ;
  v_day_of_week INTEGER;
  v_hour INTEGER;
  v_minute INTEGER;
  v_adjusted TIMESTAMPTZ;
BEGIN
  -- Converter para timezone local
  v_local_time := p_timestamp AT TIME ZONE p_timezone;
  v_day_of_week := EXTRACT(DOW FROM v_local_time); -- 0=Sunday, 1=Monday, ..., 6=Saturday
  v_hour := EXTRACT(HOUR FROM v_local_time);
  v_minute := EXTRACT(MINUTE FROM v_local_time);

  -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  -- CASO 1: DOMINGO (0) → Pular para Segunda 08:00
  -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  IF v_day_of_week = 0 THEN
    v_adjusted := date_trunc('day', v_local_time) + INTERVAL '1 day' + INTERVAL '8 hours';
    RETURN v_adjusted AT TIME ZONE p_timezone;
  END IF;

  -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  -- CASO 2: SÁBADO (6)
  -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  IF v_day_of_week = 6 THEN
    -- Se antes das 08:00 → Sábado 08:00
    IF v_hour < 8 THEN
      v_adjusted := date_trunc('day', v_local_time) + INTERVAL '8 hours';
      RETURN v_adjusted AT TIME ZONE p_timezone;

    -- Se depois das 12:00 → Segunda 08:00
    ELSIF v_hour >= 12 THEN
      v_adjusted := date_trunc('day', v_local_time) + INTERVAL '2 days' + INTERVAL '8 hours';
      RETURN v_adjusted AT TIME ZONE p_timezone;

    -- Entre 08:00-12:00 → OK, mantém timestamp
    ELSE
      RETURN p_timestamp;
    END IF;
  END IF;

  -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  -- CASO 3: SEGUNDA-SEXTA (1-5)
  -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  -- Se antes das 08:00 → Mesmo dia 08:00
  IF v_hour < 8 THEN
    v_adjusted := date_trunc('day', v_local_time) + INTERVAL '8 hours';
    RETURN v_adjusted AT TIME ZONE p_timezone;

  -- Se depois das 18:00 → Próximo dia útil 08:00
  ELSIF v_hour >= 18 THEN
    -- Se Sexta (5) → Segunda (3 dias depois)
    IF v_day_of_week = 5 THEN
      v_adjusted := date_trunc('day', v_local_time) + INTERVAL '3 days' + INTERVAL '8 hours';
    -- Outros dias → Próximo dia 08:00
    ELSE
      v_adjusted := date_trunc('day', v_local_time) + INTERVAL '1 day' + INTERVAL '8 hours';
    END IF;
    RETURN v_adjusted AT TIME ZONE p_timezone;

  -- Entre 08:00-18:00 → OK, mantém timestamp
  ELSE
    RETURN p_timestamp;
  END IF;

END;
$$;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- COMENTÁRIOS DA FUNÇÃO
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

COMMENT ON FUNCTION adjust_to_business_hours(TIMESTAMPTZ, TEXT) IS
'Ajusta timestamp para respeitar horário comercial:
- Segunda-Sexta: 08:00-18:00
- Sábado: 08:00-12:00
- Domingo: NÃO ENVIA (agenda para Segunda 08:00)

Exemplos:
- Sexta 19:00 → Segunda 08:00
- Sábado 13:00 → Segunda 08:00
- Domingo 10:00 → Segunda 08:00
- Segunda 07:00 → Segunda 08:00
- Terça 15:00 → Terça 15:00 (mantém)';

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TESTES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DO $$
DECLARE
  v_test_time TIMESTAMPTZ;
  v_result TIMESTAMPTZ;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== TESTES DA FUNÇÃO adjust_to_business_hours ===';
  RAISE NOTICE '';

  -- Teste 1: Segunda 07:00 → Segunda 08:00
  v_test_time := '2025-11-10 07:00:00-03'::TIMESTAMPTZ; -- Segunda
  v_result := adjust_to_business_hours(v_test_time);
  RAISE NOTICE 'Teste 1: Segunda 07:00 → %', v_result;
  RAISE NOTICE 'Esperado: Segunda 08:00';
  RAISE NOTICE '';

  -- Teste 2: Segunda 10:30 → Segunda 10:30 (mantém)
  v_test_time := '2025-11-10 10:30:00-03'::TIMESTAMPTZ; -- Segunda
  v_result := adjust_to_business_hours(v_test_time);
  RAISE NOTICE 'Teste 2: Segunda 10:30 → %', v_result;
  RAISE NOTICE 'Esperado: Segunda 10:30 (sem mudança)';
  RAISE NOTICE '';

  -- Teste 3: Segunda 19:00 → Terça 08:00
  v_test_time := '2025-11-10 19:00:00-03'::TIMESTAMPTZ; -- Segunda
  v_result := adjust_to_business_hours(v_test_time);
  RAISE NOTICE 'Teste 3: Segunda 19:00 → %', v_result;
  RAISE NOTICE 'Esperado: Terça 08:00';
  RAISE NOTICE '';

  -- Teste 4: Sexta 19:00 → Segunda 08:00
  v_test_time := '2025-11-14 19:00:00-03'::TIMESTAMPTZ; -- Sexta
  v_result := adjust_to_business_hours(v_test_time);
  RAISE NOTICE 'Teste 4: Sexta 19:00 → %', v_result;
  RAISE NOTICE 'Esperado: Segunda 08:00 (3 dias depois)';
  RAISE NOTICE '';

  -- Teste 5: Sábado 07:00 → Sábado 08:00
  v_test_time := '2025-11-15 07:00:00-03'::TIMESTAMPTZ; -- Sábado
  v_result := adjust_to_business_hours(v_test_time);
  RAISE NOTICE 'Teste 5: Sábado 07:00 → %', v_result;
  RAISE NOTICE 'Esperado: Sábado 08:00';
  RAISE NOTICE '';

  -- Teste 6: Sábado 10:00 → Sábado 10:00 (mantém)
  v_test_time := '2025-11-15 10:00:00-03'::TIMESTAMPTZ; -- Sábado
  v_result := adjust_to_business_hours(v_test_time);
  RAISE NOTICE 'Teste 6: Sábado 10:00 → %', v_result;
  RAISE NOTICE 'Esperado: Sábado 10:00 (sem mudança)';
  RAISE NOTICE '';

  -- Teste 7: Sábado 13:00 → Segunda 08:00
  v_test_time := '2025-11-15 13:00:00-03'::TIMESTAMPTZ; -- Sábado
  v_result := adjust_to_business_hours(v_test_time);
  RAISE NOTICE 'Teste 7: Sábado 13:00 → %', v_result;
  RAISE NOTICE 'Esperado: Segunda 08:00 (2 dias depois)';
  RAISE NOTICE '';

  -- Teste 8: Domingo 10:00 → Segunda 08:00
  v_test_time := '2025-11-16 10:00:00-03'::TIMESTAMPTZ; -- Domingo
  v_result := adjust_to_business_hours(v_test_time);
  RAISE NOTICE 'Teste 8: Domingo 10:00 → %', v_result;
  RAISE NOTICE 'Esperado: Segunda 08:00 (1 dia depois)';
  RAISE NOTICE '';

  RAISE NOTICE '=== FIM DOS TESTES ===';
END $$;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIM DA MIGRATION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

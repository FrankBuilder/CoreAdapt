-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Test: Validar intervalos entre mensagens do assistant
-- Purpose: Verificar se o delay está sendo aplicado corretamente
-- Expected: ~1.5-2.5s entre mensagens sequenciais do assistant
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WITH message_intervals AS (
  SELECT
    ch.id,
    ch.contact_id,
    c.full_name,
    c.whatsapp,
    ch.role,
    ch.message,
    ch.message_timestamp,

    -- Mensagem anterior do mesmo contato
    LAG(ch.message_timestamp) OVER (
      PARTITION BY ch.contact_id
      ORDER BY ch.message_timestamp
    ) as previous_message_ts,

    -- Intervalo em segundos
    EXTRACT(EPOCH FROM (
      ch.message_timestamp - LAG(ch.message_timestamp) OVER (
        PARTITION BY ch.contact_id
        ORDER BY ch.message_timestamp
      )
    )) as seconds_between,

    -- Contagem de mensagens sequenciais do assistant
    ROW_NUMBER() OVER (
      PARTITION BY ch.contact_id
      ORDER BY ch.message_timestamp
    ) as message_sequence

  FROM corev4_chat_history ch
  INNER JOIN corev4_contacts c ON c.id = ch.contact_id

  WHERE
    ch.role = 'assistant'
    AND ch.message_timestamp > NOW() - INTERVAL '1 hour'  -- Última hora

  ORDER BY ch.contact_id, ch.message_timestamp
)

SELECT
  contact_id,
  full_name,
  whatsapp,
  message_sequence,
  message_timestamp,
  ROUND(seconds_between::numeric, 2) as interval_seconds,

  -- Status do intervalo
  CASE
    WHEN seconds_between IS NULL THEN '🟦 PRIMEIRA'
    WHEN seconds_between < 0.5 THEN '🔴 MUITO RÁPIDO! (< 0.5s)'
    WHEN seconds_between < 1.0 THEN '🟡 RÁPIDO (0.5-1s)'
    WHEN seconds_between BETWEEN 1.0 AND 3.0 THEN '🟢 IDEAL (1-3s)'
    WHEN seconds_between > 3.0 THEN '🟠 LENTO (> 3s)'
  END as status,

  -- Preview da mensagem
  LEFT(message, 50) || '...' as message_preview

FROM message_intervals

WHERE
  -- Focar em mensagens sequenciais do assistant
  -- (onde o intervalo deveria existir)
  seconds_between IS NOT NULL
  OR message_sequence = 1  -- Incluir primeira mensagem

ORDER BY contact_id, message_timestamp DESC;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Análise Resumida
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SELECT
  CASE
    WHEN seconds_between < 0.5 THEN '🔴 < 0.5s (PROBLEMA!)'
    WHEN seconds_between < 1.0 THEN '🟡 0.5-1s'
    WHEN seconds_between BETWEEN 1.0 AND 3.0 THEN '🟢 1-3s (IDEAL)'
    WHEN seconds_between > 3.0 THEN '🟠 > 3s'
  END as interval_range,

  COUNT(*) as message_count,
  ROUND(AVG(seconds_between)::numeric, 2) as avg_interval,
  ROUND(MIN(seconds_between)::numeric, 2) as min_interval,
  ROUND(MAX(seconds_between)::numeric, 2) as max_interval

FROM (
  SELECT
    EXTRACT(EPOCH FROM (
      message_timestamp - LAG(message_timestamp) OVER (
        PARTITION BY contact_id
        ORDER BY message_timestamp
      )
    )) as seconds_between
  FROM corev4_chat_history
  WHERE
    role = 'assistant'
    AND message_timestamp > NOW() - INTERVAL '1 hour'
) intervals

WHERE seconds_between IS NOT NULL

GROUP BY interval_range
ORDER BY interval_range;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INTERPRETAÇÃO DOS RESULTADOS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/*
ANTES DO FIX (sem Wait node):
  🔴 < 0.5s    → 80-90% das mensagens (PROBLEMA!)
  🟡 0.5-1s    → 10-15%
  🟢 1-3s      → 0-5%

DEPOIS DO FIX (com Wait node):
  🔴 < 0.5s    → 0-5% (apenas mensagens únicas)
  🟡 0.5-1s    → 0-5%
  🟢 1-3s      → 90-95% (SUCESSO!)
  🟠 > 3s      → 0-5%

AÇÃO NECESSÁRIA:
- Se > 50% em 🔴: Wait node NÃO está ativo ou configurado errado
- Se > 80% em 🟢: Wait node funcionando perfeitamente!
- Se > 50% em 🟠: Delay muito alto, considerar reduzir delay_base
*/

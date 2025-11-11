-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Query: Fetch Expired Batches
-- Purpose: Get all batches where 3s timeout has expired
-- Used by: Batch Processor Flow (Cron every 2s)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SELECT
  ch.id,
  ch.contact_id,
  ch.company_id,
  ch.batch_messages,
  ch.batch_expires_at,
  ch.batch_collecting,

  -- Message count
  array_length(ch.batch_messages, 1) AS message_count,

  -- Contact info
  c.full_name AS contact_name,
  c.whatsapp,
  c.phone_number,

  -- Company info (for Evolution API)
  co.evolution_api_url,
  co.evolution_instance,
  co.evolution_api_key,

  -- Timing info
  EXTRACT(EPOCH FROM (NOW() - ch.batch_expires_at)) AS seconds_overdue

FROM corev4_chats ch
INNER JOIN corev4_contacts c ON c.id = ch.contact_id
INNER JOIN corev4_companies co ON co.id = ch.company_id

WHERE
  ch.batch_collecting = TRUE
  AND ch.batch_expires_at <= NOW()  -- Timer expirou!
  AND ch.batch_messages IS NOT NULL
  AND array_length(ch.batch_messages, 1) > 0  -- Tem mensagens
  AND c.opt_out = FALSE  -- Contato ativo
  AND c.is_active = TRUE

ORDER BY ch.batch_expires_at ASC  -- Mais antigos primeiro
LIMIT 50;  -- Processar no máximo 50 batches por vez

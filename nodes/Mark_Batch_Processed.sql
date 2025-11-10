-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Query: Mark Batch as Processed
-- Purpose: Reset batch collection flags after processing
-- Used by: Batch Processor Flow (after sending to One Flow)
-- Parameters: $1 = chat_id
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UPDATE corev4_chats
SET
  batch_collecting = FALSE,
  batch_expires_at = NULL,
  batch_messages = '{}',  -- Limpar array
  updated_at = NOW()
WHERE id = $1
RETURNING
  id,
  contact_id,
  batch_collecting,
  updated_at;

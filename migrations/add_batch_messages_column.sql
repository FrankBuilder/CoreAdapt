-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Migration: Add batch_messages column to corev4_chats
-- Purpose: Store collected messages during batch collection window
-- Date: 2025-11-10
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Add column to store messages during batch collection
ALTER TABLE corev4_chats
ADD COLUMN IF NOT EXISTS batch_messages JSONB[] DEFAULT '{}';

-- Add comment
COMMENT ON COLUMN corev4_chats.batch_messages IS 'Array of messages collected during batch window (3s)';

-- Add index for faster queries on batches with messages
CREATE INDEX IF NOT EXISTS idx_chats_batch_active
  ON corev4_chats(batch_expires_at)
  WHERE batch_collecting = true
    AND batch_expires_at IS NOT NULL;

-- Confirm changes
SELECT
  column_name,
  data_type,
  column_default
FROM information_schema.columns
WHERE table_name = 'corev4_chats'
  AND column_name IN ('batch_collecting', 'batch_expires_at', 'batch_messages')
ORDER BY column_name;

-- ============================================================================
-- E2EE ENCRYPTION SUPPORT FOR MESSAGES
-- ============================================================================
-- Adds content_iv field to messages table for E2EE (encrypted_content already exists)
-- Messages with encrypted_content should have empty content field

-- Add IV field to messages table (encrypted_content already exists from 05_messaging.sql)
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS content_iv TEXT;

-- Add index for encrypted messages lookup
CREATE INDEX IF NOT EXISTS idx_messages_encrypted 
ON messages(conversation_id, created_at DESC)
WHERE encrypted_content IS NOT NULL;

-- Update constraint: content OR encrypted_content must be present (not both)
-- Note: content field is NOT NULL in schema, so we allow empty string when encrypted
ALTER TABLE messages
DROP CONSTRAINT IF EXISTS messages_content_check;

ALTER TABLE messages
ADD CONSTRAINT messages_content_check 
CHECK (
  -- Plaintext message: content must be non-empty (after trimming), encrypted_content must be NULL or empty
  (LENGTH(TRIM(content)) > 0 AND (encrypted_content IS NULL OR encrypted_content = '')) OR
  -- Encrypted message: encrypted_content must be non-empty (after trimming), content must be empty string (content is NOT NULL)
  (LENGTH(TRIM(encrypted_content)) > 0 AND (content = '' OR LENGTH(TRIM(content)) = 0))
);

COMMENT ON COLUMN messages.encrypted_content IS 'E2EE encrypted message content (AES-GCM-256)';
COMMENT ON COLUMN messages.content_iv IS 'Initialization vector for E2EE decryption';
COMMENT ON COLUMN messages.content IS 'Plaintext content (only used if encrypted_content is NULL, for backward compatibility)';

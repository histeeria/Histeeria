-- ============================================================================
-- CONVERSATION-SPECIFIC E2EE KEY STORAGE
-- ============================================================================
-- Stores public keys per conversation per user for E2EE
-- This replaces in-memory key storage with persistent database storage
-- ============================================================================

CREATE TABLE IF NOT EXISTS conversation_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    public_key TEXT NOT NULL,
    key_type VARCHAR(20) DEFAULT 'RSA-OAEP',
    key_version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    revoked_at TIMESTAMP,
    
    -- One active key per user per conversation
    CONSTRAINT unique_conversation_user_key 
        UNIQUE (conversation_id, user_id, key_version)
);

-- Index for fast lookup by conversation and user
CREATE INDEX IF NOT EXISTS idx_conversation_keys_lookup 
    ON conversation_keys(conversation_id, user_id) 
    WHERE revoked_at IS NULL;

-- Index for finding active keys
CREATE INDEX IF NOT EXISTS idx_conversation_keys_active 
    ON conversation_keys(conversation_id, user_id, key_version DESC) 
    WHERE revoked_at IS NULL;

-- Index for user's keys across all conversations
CREATE INDEX IF NOT EXISTS idx_conversation_keys_user 
    ON conversation_keys(user_id) 
    WHERE revoked_at IS NULL;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_conversation_keys_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER conversation_keys_updated_at
    BEFORE UPDATE ON conversation_keys
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_keys_updated_at();

COMMENT ON TABLE conversation_keys IS 'E2EE public keys stored per conversation per user';
COMMENT ON COLUMN conversation_keys.conversation_id IS 'The conversation this key is for';
COMMENT ON COLUMN conversation_keys.user_id IS 'The user who owns this public key';
COMMENT ON COLUMN conversation_keys.public_key IS 'RSA public key in PEM format';
COMMENT ON COLUMN conversation_keys.key_version IS 'Key version for rotation support';
COMMENT ON COLUMN conversation_keys.revoked_at IS 'Timestamp when key was revoked (NULL = active)';

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE conversation_keys ENABLE ROW LEVEL SECURITY;

-- Users can only see keys for conversations they're part of
CREATE POLICY conversation_keys_select_participant ON conversation_keys
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = conversation_keys.conversation_id
            AND (c.participant1_id = auth.uid() OR c.participant2_id = auth.uid())
        )
    );

-- Users can only insert their own keys
CREATE POLICY conversation_keys_insert_own ON conversation_keys
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own keys
CREATE POLICY conversation_keys_update_own ON conversation_keys
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON conversation_keys TO authenticated;

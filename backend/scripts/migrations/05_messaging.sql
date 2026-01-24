-- ============================================================================
-- HISTEERIA DATABASE - 05: MESSAGING
-- ============================================================================
-- Contains: Conversations, Messages, Reactions, Stars, Pins, Edits, Forwards
-- Dependencies: 01_core_schema.sql (users table)
-- ============================================================================

-- ============================================================================
-- CONVERSATIONS TABLE
-- 1-on-1 conversations between users
-- ============================================================================
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participant1_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    participant2_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Last message cache (for conversation list performance)
    last_message_content TEXT,
    last_message_sender_id UUID REFERENCES users(id),
    last_message_at TIMESTAMP,
    
    -- Unread counts per participant
    unread_count_p1 INTEGER DEFAULT 0,
    unread_count_p2 INTEGER DEFAULT 0,
    
    -- Typing indicators
    p1_typing BOOLEAN DEFAULT FALSE,
    p2_typing BOOLEAN DEFAULT FALSE,
    p1_typing_at TIMESTAMP,
    p2_typing_at TIMESTAMP,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT unique_participants UNIQUE (participant1_id, participant2_id),
    CONSTRAINT no_self_conversation CHECK (participant1_id != participant2_id),
    -- FIX: Enforce consistent ordering to prevent duplicate conversations
    CONSTRAINT ordered_participants CHECK (participant1_id < participant2_id)
);

-- ============================================================================
-- MESSAGES TABLE
-- Individual messages with full feature support
-- ============================================================================
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Content
    content TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'file', 'audio', 'system')),
    
    -- Attachments
    attachment_url TEXT,
    attachment_name TEXT,
    attachment_size INTEGER,  -- bytes
    attachment_type VARCHAR(50),  -- MIME type
    
    -- Video metadata
    thumbnail_url TEXT,
    video_duration INTEGER,  -- seconds
    video_width INTEGER,
    video_height INTEGER,
    
    -- Delivery status (WhatsApp-style)
    status VARCHAR(20) DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    
    -- Reply support
    reply_to_id UUID REFERENCES messages(id),
    
    -- Pin feature
    pinned_at TIMESTAMP,
    pinned_by UUID REFERENCES users(id),
    
    -- Edit feature
    edited_at TIMESTAMP,
    edit_count INTEGER DEFAULT 0,
    original_content TEXT,
    
    -- Forward feature
    -- FIX: Add ON DELETE SET NULL to prevent orphaned references
    forwarded_from_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    is_forwarded BOOLEAN DEFAULT FALSE,
    
    -- Soft delete (per-user deletion)
    deleted_by UUID[],
    
    -- E2EE preparation (for future)
    encrypted_content TEXT,
    encryption_version INTEGER DEFAULT 0,
    sender_public_key_id UUID,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- MESSAGE REACTIONS TABLE
-- Emoji reactions on messages
-- ============================================================================
CREATE TABLE IF NOT EXISTS message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_user_message_reaction UNIQUE (message_id, user_id)
);

-- ============================================================================
-- STARRED MESSAGES TABLE
-- User-specific starred/bookmarked messages
-- ============================================================================
CREATE TABLE IF NOT EXISTS starred_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    starred_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_user_starred_message UNIQUE (user_id, message_id)
);

-- ============================================================================
-- SHARED MESSAGES TABLE
-- Track external message sharing
-- ============================================================================
CREATE TABLE IF NOT EXISTS shared_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    shared_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    share_method VARCHAR(50),  -- 'link', 'email', 'social', 'clipboard'
    share_url TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- MESSAGE EDIT HISTORY TABLE
-- Audit trail for edited messages
-- ============================================================================
CREATE TABLE IF NOT EXISTS message_edit_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    previous_content TEXT NOT NULL,
    edited_by UUID NOT NULL REFERENCES users(id),
    edited_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- E2EE: USER ENCRYPTION KEYS TABLE
-- Public keys for end-to-end encryption (future)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_encryption_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    public_key TEXT NOT NULL,
    key_type VARCHAR(20) DEFAULT 'RSA-OAEP',
    created_at TIMESTAMP DEFAULT NOW(),
    revoked_at TIMESTAMP
);

-- Partial unique constraint: only one active key per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_active_encryption_key 
    ON user_encryption_keys(user_id) WHERE revoked_at IS NULL;

-- ============================================================================
-- INDEXES
-- ============================================================================
-- Conversations
CREATE INDEX IF NOT EXISTS idx_conversations_p1 ON conversations(participant1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_p2 ON conversations(participant2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message ON conversations(last_message_at DESC NULLS LAST);
-- FIX: Composite index for fast conversation lookup (used by get_or_create_conversation)
CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_lookup ON conversations(participant1_id, participant2_id);
-- Keep this for sorting conversation lists
CREATE INDEX IF NOT EXISTS idx_conversations_participants ON conversations(participant1_id, participant2_id, last_message_at DESC);

-- Messages (CRITICAL for performance)
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at DESC);
-- FIX: Covering index for message loading (includes commonly needed fields)
CREATE INDEX IF NOT EXISTS idx_messages_conv_covering ON messages(conversation_id, created_at DESC)
INCLUDE (sender_id, content, message_type, status, encrypted_content);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_status ON messages(status);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(conversation_id, created_at DESC) WHERE status != 'read';
CREATE INDEX IF NOT EXISTS idx_messages_pinned ON messages(conversation_id, pinned_at DESC NULLS LAST) WHERE pinned_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_edited ON messages(edited_at DESC) WHERE edited_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_forwarded ON messages(forwarded_from_id) WHERE is_forwarded = TRUE;

-- Reactions
CREATE INDEX IF NOT EXISTS idx_message_reactions_message ON message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_user ON message_reactions(user_id);

-- Starred
CREATE INDEX IF NOT EXISTS idx_starred_messages_user ON starred_messages(user_id, starred_at DESC);
CREATE INDEX IF NOT EXISTS idx_starred_messages_message ON starred_messages(message_id);

-- Shared
CREATE INDEX IF NOT EXISTS idx_shared_messages_message ON shared_messages(message_id);
CREATE INDEX IF NOT EXISTS idx_shared_messages_user ON shared_messages(shared_by);

-- Edit History
CREATE INDEX IF NOT EXISTS idx_message_edit_history ON message_edit_history(message_id, edited_at DESC);

-- Encryption Keys
CREATE INDEX IF NOT EXISTS idx_encryption_keys_user ON user_encryption_keys(user_id);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Update conversation on new message
DROP FUNCTION IF EXISTS update_conversation_last_message() CASCADE;
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations
    SET 
        last_message_content = CASE 
            WHEN NEW.message_type = 'text' THEN LEFT(NEW.content, 100)
            WHEN NEW.message_type = 'image' THEN '📷 Photo'
            WHEN NEW.message_type = 'video' THEN '🎬 Video'
            WHEN NEW.message_type = 'audio' THEN '🎤 Voice message'
            WHEN NEW.message_type = 'file' THEN '📎 ' || COALESCE(NEW.attachment_name, 'File')
            ELSE NEW.content
        END,
        last_message_sender_id = NEW.sender_id,
        last_message_at = NEW.created_at,
        updated_at = NOW()
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_conversation_last_message ON messages;
CREATE TRIGGER trigger_update_conversation_last_message
    AFTER INSERT ON messages
    FOR EACH ROW EXECUTE FUNCTION update_conversation_last_message();

-- Increment unread count for recipient
DROP FUNCTION IF EXISTS increment_unread_count() CASCADE;
CREATE OR REPLACE FUNCTION increment_unread_count()
RETURNS TRIGGER AS $$
DECLARE
    conv RECORD;
BEGIN
    SELECT participant1_id, participant2_id INTO conv
    FROM conversations WHERE id = NEW.conversation_id;
    
    IF conv.participant1_id = NEW.sender_id THEN
        UPDATE conversations SET unread_count_p2 = unread_count_p2 + 1 WHERE id = NEW.conversation_id;
    ELSE
        UPDATE conversations SET unread_count_p1 = unread_count_p1 + 1 WHERE id = NEW.conversation_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_increment_unread_count ON messages;
CREATE TRIGGER trigger_increment_unread_count
    AFTER INSERT ON messages
    FOR EACH ROW EXECUTE FUNCTION increment_unread_count();

-- Auto-set read_at timestamp
DROP FUNCTION IF EXISTS update_message_read_at() CASCADE;
CREATE OR REPLACE FUNCTION update_message_read_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'read' AND OLD.status != 'read' AND NEW.read_at IS NULL THEN
        NEW.read_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_message_read_at ON messages;
CREATE TRIGGER trigger_update_message_read_at
    BEFORE UPDATE ON messages
    FOR EACH ROW
    WHEN (NEW.status = 'read' AND OLD.status != 'read')
    EXECUTE FUNCTION update_message_read_at();

-- Track edit history
DROP FUNCTION IF EXISTS track_message_edit() CASCADE;
CREATE OR REPLACE FUNCTION track_message_edit()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.content IS DISTINCT FROM NEW.content THEN
        INSERT INTO message_edit_history (message_id, previous_content, edited_by)
        VALUES (OLD.id, OLD.content, NEW.sender_id);
        
        NEW.edit_count = COALESCE(OLD.edit_count, 0) + 1;
        NEW.edited_at = NOW();
        IF OLD.original_content IS NULL THEN
            NEW.original_content = OLD.content;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_track_message_edit ON messages;
CREATE TRIGGER trigger_track_message_edit
    BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION track_message_edit();

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Get total unread count for a user
DROP FUNCTION IF EXISTS get_user_total_unread_count(UUID);
CREATE OR REPLACE FUNCTION get_user_total_unread_count(user_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    total INTEGER;
BEGIN
    SELECT COALESCE(SUM(
        CASE 
            WHEN participant1_id = user_uuid THEN unread_count_p1
            WHEN participant2_id = user_uuid THEN unread_count_p2
            ELSE 0
        END
    ), 0) INTO total
    FROM conversations
    WHERE participant1_id = user_uuid OR participant2_id = user_uuid;
    RETURN total;
END;
$$ LANGUAGE plpgsql;

-- Mark messages as read
DROP FUNCTION IF EXISTS mark_messages_read(UUID, UUID);
CREATE OR REPLACE FUNCTION mark_messages_read(
    conv_id UUID,
    reader_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    WITH updated AS (
        UPDATE messages
        SET status = 'read', read_at = NOW()
        WHERE conversation_id = conv_id
        AND sender_id != reader_id
        AND status != 'read'
        RETURNING id
    )
    SELECT COUNT(*) INTO updated_count FROM updated;
    
    -- Reset unread count
    UPDATE conversations
    SET 
        unread_count_p1 = CASE WHEN participant1_id = reader_id THEN 0 ELSE unread_count_p1 END,
        unread_count_p2 = CASE WHEN participant2_id = reader_id THEN 0 ELSE unread_count_p2 END
    WHERE id = conv_id;
    
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Get or create conversation
DROP FUNCTION IF EXISTS get_or_create_conversation(UUID, UUID);
CREATE OR REPLACE FUNCTION get_or_create_conversation(
    user_a UUID,
    user_b UUID
)
RETURNS UUID AS $$
DECLARE
    conv_id UUID;
    p1 UUID;
    p2 UUID;
BEGIN
    -- Normalize order (smaller UUID first)
    IF user_a < user_b THEN
        p1 := user_a;
        p2 := user_b;
    ELSE
        p1 := user_b;
        p2 := user_a;
    END IF;
    
    -- Try to find existing
    SELECT id INTO conv_id
    FROM conversations
    WHERE participant1_id = p1 AND participant2_id = p2;
    
    -- Create if not exists
    IF conv_id IS NULL THEN
        INSERT INTO conversations (participant1_id, participant2_id)
        VALUES (p1, p2)
        RETURNING id INTO conv_id;
    END IF;
    
    RETURN conv_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE conversations IS '1-on-1 conversations with cached last message for performance';
COMMENT ON TABLE messages IS 'Individual messages with delivery tracking, edits, forwards, pins';
COMMENT ON TABLE message_reactions IS 'Emoji reactions on messages';
COMMENT ON TABLE starred_messages IS 'User-specific starred/bookmarked messages';
COMMENT ON TABLE shared_messages IS 'Tracks external sharing of messages';
COMMENT ON TABLE message_edit_history IS 'Audit trail for edited messages';
COMMENT ON TABLE user_encryption_keys IS 'Public keys for E2EE (future feature)';

COMMENT ON COLUMN conversations.last_message_content IS 'Cached for fast conversation list rendering';
COMMENT ON COLUMN conversations.unread_count_p1 IS 'Unread messages for participant 1';
COMMENT ON COLUMN messages.status IS 'sent=✓, delivered=✓✓, read=✓✓ (blue)';
COMMENT ON COLUMN messages.deleted_by IS 'Array of user IDs who soft-deleted this message';
COMMENT ON COLUMN messages.encrypted_content IS 'E2EE encrypted content (future)';

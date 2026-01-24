-- ============================================================================
-- HISTEERIA DATABASE - 09: DM STORE-AND-FORWARD (WhatsApp Style)
-- ============================================================================
-- Adds delivery tracking and auto-deletion for WhatsApp-style DMs
-- Messages are stored until delivered, then deleted after 24 hours
-- Dependencies: 05_messaging.sql (messages table)
-- ============================================================================

-- ============================================================================
-- ADD DELIVERY TRACKING COLUMNS TO MESSAGES
-- ============================================================================

ALTER TABLE messages
ADD COLUMN IF NOT EXISTS downloaded_by_recipient BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS delete_scheduled_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS backed_up_by_sender BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS backed_up_by_recipient BOOLEAN DEFAULT FALSE;

-- Index for cleanup job (find messages to delete)
CREATE INDEX IF NOT EXISTS idx_messages_pending_delete 
ON messages(delete_scheduled_at)
WHERE delete_scheduled_at IS NOT NULL;

-- Index for pending messages (recipient hasn't downloaded)
CREATE INDEX IF NOT EXISTS idx_messages_pending_delivery
ON messages(conversation_id, created_at DESC)
WHERE downloaded_by_recipient = FALSE AND status = 'sent';

-- ============================================================================
-- MESSAGE LIFECYCLE FUNCTIONS
-- ============================================================================

-- Mark message as delivered and schedule deletion
DROP FUNCTION IF EXISTS mark_message_delivered(UUID);
CREATE OR REPLACE FUNCTION mark_message_delivered(p_message_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE messages
    SET 
        status = 'delivered',
        delivered_at = NOW(),
        downloaded_by_recipient = TRUE,
        -- Schedule deletion 24 hours after delivery
        delete_scheduled_at = NOW() + INTERVAL '24 hours'
    WHERE id = p_message_id
    AND status != 'delivered';  -- Idempotent
END;
$$ LANGUAGE plpgsql;

-- Mark message as read (blue ticks)
DROP FUNCTION IF EXISTS mark_message_read(UUID);
CREATE OR REPLACE FUNCTION mark_message_read(p_message_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE messages
    SET 
        status = 'read',
        read_at = NOW()
    WHERE id = p_message_id
    AND status != 'read';  -- Idempotent
END;
$$ LANGUAGE plpgsql;

-- Batch mark messages as delivered (when recipient opens conversation)
DROP FUNCTION IF EXISTS mark_conversation_delivered(UUID, UUID);
CREATE OR REPLACE FUNCTION mark_conversation_delivered(
    p_conversation_id UUID,
    p_recipient_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    WITH updated AS (
        UPDATE messages
        SET 
            status = CASE WHEN status = 'sent' THEN 'delivered' ELSE status END,
            delivered_at = COALESCE(delivered_at, NOW()),
            downloaded_by_recipient = TRUE,
            delete_scheduled_at = COALESCE(delete_scheduled_at, NOW() + INTERVAL '24 hours')
        WHERE conversation_id = p_conversation_id
        AND sender_id != p_recipient_id  -- Only mark messages FROM the other person
        AND downloaded_by_recipient = FALSE
        RETURNING id
    )
    SELECT COUNT(*) INTO updated_count FROM updated;
    
    -- Update unread count in conversation
    UPDATE conversations
    SET 
        unread_count_p1 = CASE WHEN participant1_id = p_recipient_id THEN 0 ELSE unread_count_p1 END,
        unread_count_p2 = CASE WHEN participant2_id = p_recipient_id THEN 0 ELSE unread_count_p2 END
    WHERE id = p_conversation_id;
    
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Cleanup job: Delete messages past their scheduled deletion time
DROP FUNCTION IF EXISTS cleanup_delivered_messages();
CREATE OR REPLACE FUNCTION cleanup_delivered_messages()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        DELETE FROM messages
        WHERE delete_scheduled_at IS NOT NULL
        AND delete_scheduled_at < NOW()
        RETURNING id
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Cleanup job: Delete messages that were never delivered (offline > 30 days)
DROP FUNCTION IF EXISTS cleanup_undelivered_messages();
CREATE OR REPLACE FUNCTION cleanup_undelivered_messages()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        DELETE FROM messages
        WHERE downloaded_by_recipient = FALSE
        AND status = 'sent'
        AND created_at < NOW() - INTERVAL '30 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Get pending messages for a user (for sync when they come online)
DROP FUNCTION IF EXISTS get_pending_messages(UUID);
CREATE OR REPLACE FUNCTION get_pending_messages(p_user_id UUID)
RETURNS TABLE (
    message_id UUID,
    conversation_id UUID,
    sender_id UUID,
    content TEXT,
    encrypted_content TEXT,
    encryption_version INTEGER,
    message_type VARCHAR,
    created_at TIMESTAMP,
    reply_to_id UUID,
    attachment_url TEXT,
    attachment_name TEXT,
    attachment_type VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.conversation_id,
        m.sender_id,
        m.content,
        m.encrypted_content,
        m.encryption_version,
        m.message_type::VARCHAR,
        m.created_at,
        m.reply_to_id,
        m.attachment_url,
        m.attachment_name,
        m.attachment_type
    FROM messages m
    JOIN conversations c ON m.conversation_id = c.id
    WHERE (c.participant1_id = p_user_id OR c.participant2_id = p_user_id)
    AND m.sender_id != p_user_id  -- Messages TO this user
    AND m.downloaded_by_recipient = FALSE
    AND m.status = 'sent'
    ORDER BY m.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Export user's message history for backup
DROP FUNCTION IF EXISTS export_user_messages(UUID, INTEGER);
CREATE OR REPLACE FUNCTION export_user_messages(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 10000
)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', m.id,
            'conversation_id', m.conversation_id,
            'sender_id', m.sender_id,
            'content', m.content,
            'encrypted_content', m.encrypted_content,
            'encryption_version', m.encryption_version,
            'message_type', m.message_type,
            'created_at', m.created_at,
            'reply_to_id', m.reply_to_id,
            'attachment_url', m.attachment_url
        ) ORDER BY m.created_at DESC
    )
    INTO result
    FROM messages m
    JOIN conversations c ON m.conversation_id = c.id
    WHERE c.participant1_id = p_user_id OR c.participant2_id = p_user_id
    LIMIT p_limit;
    
    -- Mark messages as backed up
    UPDATE messages m
    SET 
        backed_up_by_sender = CASE WHEN m.sender_id = p_user_id THEN TRUE ELSE backed_up_by_sender END,
        backed_up_by_recipient = CASE WHEN m.sender_id != p_user_id THEN TRUE ELSE backed_up_by_recipient END
    FROM conversations c
    WHERE m.conversation_id = c.id
    AND (c.participant1_id = p_user_id OR c.participant2_id = p_user_id);
    
    RETURN COALESCE(result, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MEDIA EXPIRY FOR DMs (Optional - only if media_references table exists)
-- ============================================================================

-- Media references with auto-expiry for DMs
-- Note: These operations will only work if media_references table exists
-- If the table doesn't exist, these can be safely skipped
DO $$
BEGIN
    -- Check if media_references table exists before altering it
    IF EXISTS (SELECT FROM information_schema.tables 
               WHERE table_schema = 'public' 
               AND table_name = 'media_references') THEN
        
        -- Add columns if table exists
        ALTER TABLE media_references
        ADD COLUMN IF NOT EXISTS is_dm_attachment BOOLEAN DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS downloaded_by_recipient BOOLEAN DEFAULT FALSE;
        
    END IF;
END $$;

-- When media is downloaded, schedule deletion
-- This function only works if media_references table exists
-- If table doesn't exist, function will fail but can be recreated after table is added
DROP FUNCTION IF EXISTS mark_media_downloaded(UUID);
DO $$
BEGIN
    -- Only create function if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'public' 
               AND table_name = 'media_references') THEN
        EXECUTE '
        CREATE OR REPLACE FUNCTION mark_media_downloaded(p_media_id UUID)
        RETURNS VOID AS $func$
        BEGIN
            UPDATE media_references
            SET 
                downloaded_by_recipient = TRUE,
                expires_at = COALESCE(expires_at, NOW() + INTERVAL ''24 hours'')
            WHERE id = p_media_id
            AND is_dm_attachment = TRUE;
        END;
        $func$ LANGUAGE plpgsql';
    END IF;
END $$;

-- Get expired media for deletion (actual R2 deletion via Edge Function)
-- This function only works if media_references table exists
-- If table doesn't exist, function will fail but can be recreated after table is added
DROP FUNCTION IF EXISTS get_expired_media_for_deletion();
DO $$
BEGIN
    -- Only create function if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'public' 
               AND table_name = 'media_references') THEN
        EXECUTE '
        CREATE OR REPLACE FUNCTION get_expired_media_for_deletion()
        RETURNS TABLE (
            id UUID,
            content_hash TEXT,
            storage_provider VARCHAR
        ) AS $func$
        BEGIN
            RETURN QUERY
            SELECT mr.id, mr.content_hash, mr.storage_provider
            FROM media_references mr
            WHERE mr.expires_at IS NOT NULL
            AND mr.expires_at < NOW()
            AND mr.is_dm_attachment = TRUE;
        END;
        $func$ LANGUAGE plpgsql';
    END IF;
END $$;

-- Comments for documentation
COMMENT ON COLUMN messages.downloaded_by_recipient IS 'True when recipient has downloaded/synced the message';
COMMENT ON COLUMN messages.delete_scheduled_at IS 'When to delete this message (24h after delivery)';
COMMENT ON COLUMN messages.backed_up_by_sender IS 'Whether sender has backed up this message';
COMMENT ON COLUMN messages.backed_up_by_recipient IS 'Whether recipient has backed up this message';

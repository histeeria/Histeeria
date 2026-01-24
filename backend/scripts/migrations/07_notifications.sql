-- ============================================================================
-- HISTEERIA DATABASE - 07: NOTIFICATIONS
-- ============================================================================
-- Contains: Notifications, Preferences, Auto-expiry
-- Dependencies: 01_core_schema.sql (users table)
-- ============================================================================

-- ============================================================================
-- ENUMS
-- ============================================================================
DO $$ BEGIN
    CREATE TYPE notification_type AS ENUM (
        -- Social
        'follow',
        'follow_back',
        'connection_request',
        'connection_accepted',
        'connection_rejected',
        'collaboration_request',
        'collaboration_accepted',
        'collaboration_rejected',
        -- Content
        'post_like',
        'post_comment',
        'post_mention',
        'comment_reply',
        'status_reaction',
        'status_comment',
        -- Messaging
        'message',
        -- System
        'system_announcement',
        'account_warning',
        'feature_update'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE notification_category AS ENUM (
        'social',
        'content',
        'messages',
        'system'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE email_frequency AS ENUM (
        'instant',
        'daily',
        'weekly',
        'never'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- NOTIFICATIONS TABLE
-- All user notifications with 30-day auto-expiry
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Classification
    type notification_type NOT NULL,
    category notification_category NOT NULL,
    
    -- Content
    title TEXT NOT NULL,
    message TEXT,
    
    -- Related entities
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,  -- Who triggered the notification
    target_id UUID,  -- ID of the related entity (post, comment, etc.)
    target_type TEXT,  -- 'post', 'comment', 'message', etc.
    action_url TEXT,  -- Deep link URL
    
    -- Status
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    is_actionable BOOLEAN NOT NULL DEFAULT FALSE,  -- Has accept/reject buttons
    action_type TEXT,  -- 'accept_reject', 'view', etc.
    action_taken BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Flexible metadata
    metadata JSONB DEFAULT '{}',
    
    -- Auto-expiry
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '30 days')
);

-- ============================================================================
-- NOTIFICATION PREFERENCES TABLE
-- User settings for notification delivery
-- ============================================================================
CREATE TABLE IF NOT EXISTS notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Global toggles
    email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    in_app_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    push_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    inline_actions_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Email frequency
    email_frequency email_frequency NOT NULL DEFAULT 'instant',
    
    -- Per-type email settings
    email_types JSONB NOT NULL DEFAULT '{
        "follow": false,
        "follow_back": false,
        "connection_request": true,
        "connection_accepted": true,
        "collaboration_request": true,
        "collaboration_accepted": true,
        "post_like": false,
        "post_comment": true,
        "post_mention": true,
        "message": false,
        "system_announcement": true
    }',
    
    -- Category toggles
    categories_enabled JSONB NOT NULL DEFAULT '{
        "social": true,
        "content": true,
        "messages": true,
        "system": true
    }',
    
    -- Quiet hours (optional)
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
-- Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_category ON notifications(user_id, category, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_expires ON notifications(expires_at);
CREATE INDEX IF NOT EXISTS idx_notifications_actor ON notifications(actor_id) WHERE actor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_actionable ON notifications(user_id, is_actionable, action_taken) 
    WHERE is_actionable = TRUE AND action_taken = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_target ON notifications(target_id, target_type) WHERE target_id IS NOT NULL;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update preferences timestamp
DROP TRIGGER IF EXISTS update_notification_preferences_updated_at ON notification_preferences;
CREATE TRIGGER update_notification_preferences_updated_at
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-create preferences for new users
DROP FUNCTION IF EXISTS create_default_notification_preferences() CASCADE;
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notification_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_create_notification_preferences ON users;
CREATE TRIGGER trigger_create_notification_preferences
    AFTER INSERT ON users
    FOR EACH ROW EXECUTE FUNCTION create_default_notification_preferences();

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Get unread notification count
DROP FUNCTION IF EXISTS get_unread_notification_count(UUID);
CREATE OR REPLACE FUNCTION get_unread_notification_count(user_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    count INTEGER;
BEGIN
    SELECT COUNT(*) INTO count
    FROM notifications
    WHERE user_id = user_uuid AND is_read = FALSE AND expires_at > NOW();
    RETURN count;
END;
$$ LANGUAGE plpgsql;

-- Mark all notifications as read
DROP FUNCTION IF EXISTS mark_all_notifications_read(UUID);
CREATE OR REPLACE FUNCTION mark_all_notifications_read(user_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    WITH updated AS (
        UPDATE notifications
        SET is_read = TRUE
        WHERE user_id = user_uuid AND is_read = FALSE
        RETURNING id
    )
    SELECT COUNT(*) INTO updated_count FROM updated;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Cleanup expired notifications (run via cron)
DROP FUNCTION IF EXISTS cleanup_expired_notifications();
CREATE OR REPLACE FUNCTION cleanup_expired_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        DELETE FROM notifications
        WHERE expires_at < NOW()
        RETURNING id
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create notification helper function
DROP FUNCTION IF EXISTS create_notification(UUID, notification_type, notification_category, TEXT, TEXT, UUID, UUID, TEXT, TEXT, BOOLEAN, TEXT, JSONB);
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_type notification_type,
    p_category notification_category,
    p_title TEXT,
    p_message TEXT DEFAULT NULL,
    p_actor_id UUID DEFAULT NULL,
    p_target_id UUID DEFAULT NULL,
    p_target_type TEXT DEFAULT NULL,
    p_action_url TEXT DEFAULT NULL,
    p_is_actionable BOOLEAN DEFAULT FALSE,
    p_action_type TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
    user_prefs RECORD;
BEGIN
    -- Check user preferences
    SELECT * INTO user_prefs FROM notification_preferences WHERE user_id = p_user_id;
    
    -- Respect category preferences
    IF user_prefs.categories_enabled IS NOT NULL THEN
        IF NOT (user_prefs.categories_enabled->>p_category::TEXT)::BOOLEAN THEN
            RETURN NULL;  -- User disabled this category
        END IF;
    END IF;
    
    -- Create the notification
    INSERT INTO notifications (
        user_id, type, category, title, message,
        actor_id, target_id, target_type, action_url,
        is_actionable, action_type, metadata
    )
    VALUES (
        p_user_id, p_type, p_category, p_title, p_message,
        p_actor_id, p_target_id, p_target_type, p_action_url,
        p_is_actionable, p_action_type, p_metadata
    )
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INITIAL DATA: Create preferences for existing users
-- ============================================================================
INSERT INTO notification_preferences (user_id)
SELECT id FROM users
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE notifications IS 'All user notifications with 30-day auto-expiry';
COMMENT ON TABLE notification_preferences IS 'User settings for notification delivery (email, in-app, push)';

COMMENT ON COLUMN notifications.metadata IS 'Flexible JSONB for extra data (message preview, post content, etc.)';
COMMENT ON COLUMN notifications.expires_at IS 'Auto-delete after 30 days via cleanup job';
COMMENT ON COLUMN notifications.is_actionable IS 'TRUE if notification has accept/reject buttons';

COMMENT ON COLUMN notification_preferences.email_types IS 'Per-type email toggle: which types trigger emails';
COMMENT ON COLUMN notification_preferences.categories_enabled IS 'Which categories to show in the UI';
COMMENT ON COLUMN notification_preferences.quiet_hours_start IS 'Start of do-not-disturb period';

COMMENT ON FUNCTION cleanup_expired_notifications() IS 'Run daily via pg_cron to delete old notifications';
COMMENT ON FUNCTION create_notification IS 'Helper to create notifications respecting user preferences';

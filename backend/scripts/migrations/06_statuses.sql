-- ============================================================================
-- HISTEERIA DATABASE - 06: STATUSES (STORIES)
-- ============================================================================
-- Contains: 24-hour ephemeral statuses, views, reactions, comments
-- Dependencies: 01_core_schema.sql, 02_relationships.sql, 05_messaging.sql
-- ============================================================================

-- ============================================================================
-- STATUSES TABLE
-- Instagram-like 24-hour stories
-- ============================================================================
CREATE TABLE IF NOT EXISTS statuses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Content
    status_type VARCHAR(20) NOT NULL CHECK (status_type IN ('text', 'image', 'video')),
    content TEXT,  -- For text statuses or captions
    media_url TEXT,  -- For image/video
    media_type VARCHAR(20),  -- MIME type
    
    -- Styling
    -- FIX: Validate hex color format
    background_color VARCHAR(7) DEFAULT '#1a1f3a' CHECK (background_color ~ '^#[0-9A-Fa-f]{6}$'),
    
    -- Denormalized Stats
    views_count INTEGER DEFAULT 0,
    reactions_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    
    -- Auto-expiry (24 hours)
    expires_at TIMESTAMP NOT NULL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Validation
    CONSTRAINT valid_text_status CHECK (
        status_type != 'text' OR (content IS NOT NULL AND LENGTH(content) > 0)
    ),
    CONSTRAINT valid_media_status CHECK (
        status_type NOT IN ('image', 'video') OR (media_url IS NOT NULL AND media_type IS NOT NULL)
    )
);

-- ============================================================================
-- STATUS VIEWS TABLE
-- Track who viewed which status
-- ============================================================================
CREATE TABLE IF NOT EXISTS status_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status_id UUID NOT NULL REFERENCES statuses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_status_view UNIQUE (status_id, user_id)
);

-- ============================================================================
-- STATUS REACTIONS TABLE
-- Emoji reactions: 👍 like, 💯 fully, ❤️ appreciate, 🤝 support, 💡 insightful
-- ============================================================================
CREATE TABLE IF NOT EXISTS status_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status_id UUID NOT NULL REFERENCES statuses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(10) NOT NULL CHECK (emoji IN ('👍', '💯', '❤️', '🤝', '💡')),
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_status_reaction UNIQUE (status_id, user_id)
);

-- ============================================================================
-- STATUS COMMENTS TABLE
-- Comments on statuses
-- ============================================================================
CREATE TABLE IF NOT EXISTS status_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status_id UUID NOT NULL REFERENCES statuses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (LENGTH(TRIM(content)) >= 1 AND LENGTH(content) <= 500),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP  -- Soft delete
);

-- ============================================================================
-- STATUS MESSAGE REPLIES TABLE
-- DM replies to statuses (links status to conversation)
-- ============================================================================
CREATE TABLE IF NOT EXISTS status_message_replies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status_id UUID NOT NULL REFERENCES statuses(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
    message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_status_reply_per_user UNIQUE (status_id, from_user_id, to_user_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
-- Statuses
CREATE INDEX IF NOT EXISTS idx_statuses_user_expires ON statuses(user_id, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_statuses_expires ON statuses(expires_at DESC);
-- NOTE: Cannot use `WHERE expires_at > NOW()` in partial index - NOW() is not IMMUTABLE
-- Instead, use a covering index for active status queries
CREATE INDEX IF NOT EXISTS idx_statuses_active ON statuses(expires_at DESC, user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_statuses_type ON statuses(status_type);
CREATE INDEX IF NOT EXISTS idx_statuses_created ON statuses(created_at DESC);

-- Views
CREATE INDEX IF NOT EXISTS idx_status_views_status ON status_views(status_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_status_views_user ON status_views(user_id, viewed_at DESC);

-- Reactions
CREATE INDEX IF NOT EXISTS idx_status_reactions_status ON status_reactions(status_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_status_reactions_user ON status_reactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_status_reactions_emoji ON status_reactions(status_id, emoji);

-- Comments
CREATE INDEX IF NOT EXISTS idx_status_comments_status ON status_comments(status_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_status_comments_user ON status_comments(user_id, created_at DESC);

-- Message Replies
CREATE INDEX IF NOT EXISTS idx_status_message_replies_status ON status_message_replies(status_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_status_message_replies_from ON status_message_replies(from_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_status_message_replies_to ON status_message_replies(to_user_id, created_at DESC);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update timestamps
DROP TRIGGER IF EXISTS update_statuses_updated_at ON statuses;
CREATE TRIGGER update_statuses_updated_at
    BEFORE UPDATE ON statuses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_status_comments_updated_at ON status_comments;
CREATE TRIGGER update_status_comments_updated_at
    BEFORE UPDATE ON status_comments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Update views count
DROP FUNCTION IF EXISTS update_status_views_count() CASCADE;
CREATE OR REPLACE FUNCTION update_status_views_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE statuses 
    SET views_count = views_count + 1, updated_at = NOW()
    WHERE id = NEW.status_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_status_views_count ON status_views;
CREATE TRIGGER trigger_status_views_count
    AFTER INSERT ON status_views
    FOR EACH ROW EXECUTE FUNCTION update_status_views_count();

-- Update reactions count
DROP FUNCTION IF EXISTS update_status_reactions_count() CASCADE;
CREATE OR REPLACE FUNCTION update_status_reactions_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE statuses SET reactions_count = reactions_count + 1, updated_at = NOW() WHERE id = NEW.status_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE statuses SET reactions_count = GREATEST(0, reactions_count - 1), updated_at = NOW() WHERE id = OLD.status_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_status_reactions_count ON status_reactions;
CREATE TRIGGER trigger_status_reactions_count
    AFTER INSERT OR DELETE ON status_reactions
    FOR EACH ROW EXECUTE FUNCTION update_status_reactions_count();

-- Update comments count (handles soft delete)
DROP FUNCTION IF EXISTS update_status_comments_count() CASCADE;
CREATE OR REPLACE FUNCTION update_status_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE statuses SET comments_count = comments_count + 1, updated_at = NOW() WHERE id = NEW.status_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE statuses SET comments_count = GREATEST(0, comments_count - 1), updated_at = NOW() WHERE id = OLD.status_id;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle soft delete
        IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
            UPDATE statuses SET comments_count = GREATEST(0, comments_count - 1), updated_at = NOW() WHERE id = NEW.status_id;
        ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
            UPDATE statuses SET comments_count = comments_count + 1, updated_at = NOW() WHERE id = NEW.status_id;
        END IF;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_status_comments_count ON status_comments;
CREATE TRIGGER trigger_status_comments_count
    AFTER INSERT OR UPDATE OR DELETE ON status_comments
    FOR EACH ROW EXECUTE FUNCTION update_status_comments_count();

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Cleanup expired statuses (run via cron job)
DROP FUNCTION IF EXISTS cleanup_expired_statuses();
CREATE OR REPLACE FUNCTION cleanup_expired_statuses()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        DELETE FROM statuses
        WHERE expires_at < NOW()
        RETURNING id
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Cleanup all expired status data (cascade handles related tables)
DROP FUNCTION IF EXISTS cleanup_expired_status_data();
CREATE OR REPLACE FUNCTION cleanup_expired_status_data()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete expired statuses (cascade will handle views, reactions, comments)
    WITH deleted AS (
        DELETE FROM statuses WHERE expires_at < NOW() RETURNING id
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Get active statuses from users I follow
DROP FUNCTION IF EXISTS get_followed_statuses(UUID, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION get_followed_statuses(
    viewer_id UUID,
    page_limit INTEGER DEFAULT 50,
    page_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    status_id UUID,
    user_id UUID,
    status_type VARCHAR(20),
    content TEXT,
    media_url TEXT,
    views_count INTEGER,
    reactions_count INTEGER,
    expires_at TIMESTAMP,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.user_id,
        s.status_type,
        s.content,
        s.media_url,
        s.views_count,
        s.reactions_count,
        s.expires_at,
        s.created_at
    FROM statuses s
    WHERE 
        s.expires_at > NOW()
        AND (
            s.user_id = viewer_id
            OR EXISTS (
                SELECT 1 FROM user_relationships ur
                WHERE ur.from_user_id = viewer_id
                AND ur.to_user_id = s.user_id
                AND ur.relationship_type = 'following'
                AND ur.status = 'active'
            )
        )
    ORDER BY s.created_at DESC
    LIMIT page_limit OFFSET page_offset;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE statuses IS '24-hour ephemeral stories/statuses (auto-expire)';
COMMENT ON TABLE status_views IS 'Tracks who viewed which status';
COMMENT ON TABLE status_reactions IS 'Emoji reactions: 👍 like, 💯 fully, ❤️ appreciate, 🤝 support, 💡 insightful';
COMMENT ON TABLE status_comments IS 'Comments on statuses';
COMMENT ON TABLE status_message_replies IS 'DM replies to statuses (links to conversations)';

COMMENT ON COLUMN statuses.expires_at IS 'Auto-expire after 24 hours. Run cleanup_expired_statuses() via cron.';
COMMENT ON COLUMN statuses.background_color IS 'Hex color for text status backgrounds';
COMMENT ON FUNCTION cleanup_expired_statuses() IS 'Call hourly via pg_cron or external scheduler';

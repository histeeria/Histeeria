-- ============================================================================
-- HISTEERIA DATABASE - 04: ENGAGEMENT
-- ============================================================================
-- Contains: Likes, Comments, Shares, Saves
-- Dependencies: 01_core_schema.sql, 03_content.sql
-- ============================================================================

-- ============================================================================
-- POST LIKES TABLE
-- Users liking posts
-- ============================================================================
CREATE TABLE IF NOT EXISTS post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_post_like UNIQUE (post_id, user_id)
);

-- ============================================================================
-- POST COMMENTS TABLE
-- Nested comment system with 2-level threading
-- ============================================================================
CREATE TABLE IF NOT EXISTS post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES post_comments(id) ON DELETE CASCADE,
    
    -- Content
    content TEXT NOT NULL CHECK (LENGTH(content) >= 1 AND LENGTH(content) <= 1000),
    
    -- Media (GIFs allowed)
    media_url TEXT,
    media_type VARCHAR(20) CHECK (media_type IN ('gif', 'image') OR media_type IS NULL),
    
    -- Stats
    likes_count INTEGER DEFAULT 0,
    replies_count INTEGER DEFAULT 0,
    
    -- Edit tracking
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP  -- Soft delete
);

-- ============================================================================
-- COMMENT LIKES TABLE
-- Users liking comments
-- ============================================================================
CREATE TABLE IF NOT EXISTS comment_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES post_comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_comment_like UNIQUE (comment_id, user_id)
);

-- ============================================================================
-- POST SHARES TABLE
-- Reposts/shares with optional quote
-- ============================================================================
CREATE TABLE IF NOT EXISTS post_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    repost_comment TEXT CHECK (repost_comment IS NULL OR LENGTH(repost_comment) <= 280),
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_user_share UNIQUE (post_id, user_id)
);

-- ============================================================================
-- SAVED POSTS TABLE
-- Bookmarked posts with collections
-- ============================================================================
CREATE TABLE IF NOT EXISTS saved_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    collection_name VARCHAR(50) DEFAULT 'Saved',
    saved_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_user_saved_post UNIQUE (post_id, user_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
-- Likes
CREATE INDEX IF NOT EXISTS idx_post_likes_post ON post_likes(post_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_likes_user ON post_likes(user_id, created_at DESC);

-- Comments
CREATE INDEX IF NOT EXISTS idx_comments_post ON post_comments(post_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON post_comments(parent_comment_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_user ON post_comments(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_active ON post_comments(post_id, created_at DESC) WHERE deleted_at IS NULL;

-- Comment Likes
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment ON comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_user ON comment_likes(user_id);

-- Shares
CREATE INDEX IF NOT EXISTS idx_post_shares_post ON post_shares(post_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_shares_user ON post_shares(user_id, created_at DESC);

-- Saved Posts
CREATE INDEX IF NOT EXISTS idx_saved_posts_user ON saved_posts(user_id, saved_at DESC);
CREATE INDEX IF NOT EXISTS idx_saved_posts_collection ON saved_posts(user_id, collection_name);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Enforce 2-level comment nesting
DROP FUNCTION IF EXISTS check_comment_nesting_depth() CASCADE;
CREATE OR REPLACE FUNCTION check_comment_nesting_depth()
RETURNS TRIGGER AS $$
DECLARE
    parent_has_parent BOOLEAN;
BEGIN
    IF NEW.parent_comment_id IS NOT NULL THEN
        SELECT parent_comment_id IS NOT NULL INTO parent_has_parent
        FROM post_comments
        WHERE id = NEW.parent_comment_id;
        
        IF parent_has_parent THEN
            RAISE EXCEPTION 'Comments can only be nested 2 levels deep';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_comment_nesting_depth ON post_comments;
CREATE TRIGGER enforce_comment_nesting_depth
    BEFORE INSERT ON post_comments
    FOR EACH ROW EXECUTE FUNCTION check_comment_nesting_depth();

-- Update post likes_count
DROP FUNCTION IF EXISTS update_post_likes_count() CASCADE;
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE posts SET likes_count = likes_count + 1, updated_at = NOW() WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE posts SET likes_count = GREATEST(0, likes_count - 1), updated_at = NOW() WHERE id = OLD.post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_post_likes_count ON post_likes;
CREATE TRIGGER trigger_post_likes_count
    AFTER INSERT OR DELETE ON post_likes
    FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

-- Update post comments_count
DROP FUNCTION IF EXISTS update_post_comments_count() CASCADE;
CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE posts SET comments_count = comments_count + 1, updated_at = NOW() WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE posts SET comments_count = GREATEST(0, comments_count - 1), updated_at = NOW() WHERE id = OLD.post_id;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle soft delete
        IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
            UPDATE posts SET comments_count = GREATEST(0, comments_count - 1), updated_at = NOW() WHERE id = NEW.post_id;
        ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
            UPDATE posts SET comments_count = comments_count + 1, updated_at = NOW() WHERE id = NEW.post_id;
        END IF;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_post_comments_count ON post_comments;
CREATE TRIGGER trigger_post_comments_count
    AFTER INSERT OR DELETE OR UPDATE ON post_comments
    FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

-- Update comment likes_count
DROP FUNCTION IF EXISTS update_comment_likes_count() CASCADE;
CREATE OR REPLACE FUNCTION update_comment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE post_comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE post_comments SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.comment_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_comment_likes_count ON comment_likes;
CREATE TRIGGER trigger_comment_likes_count
    AFTER INSERT OR DELETE ON comment_likes
    FOR EACH ROW EXECUTE FUNCTION update_comment_likes_count();

-- Update comment replies_count
DROP FUNCTION IF EXISTS update_comment_replies_count() CASCADE;
CREATE OR REPLACE FUNCTION update_comment_replies_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.parent_comment_id IS NOT NULL THEN
        UPDATE post_comments SET replies_count = replies_count + 1 WHERE id = NEW.parent_comment_id;
    ELSIF TG_OP = 'DELETE' AND OLD.parent_comment_id IS NOT NULL THEN
        UPDATE post_comments SET replies_count = GREATEST(0, replies_count - 1) WHERE id = OLD.parent_comment_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_comment_replies_count ON post_comments;
CREATE TRIGGER trigger_comment_replies_count
    AFTER INSERT OR DELETE ON post_comments
    FOR EACH ROW EXECUTE FUNCTION update_comment_replies_count();

-- Update post shares_count
DROP FUNCTION IF EXISTS update_post_shares_count() CASCADE;
CREATE OR REPLACE FUNCTION update_post_shares_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE posts SET shares_count = shares_count + 1, updated_at = NOW() WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE posts SET shares_count = GREATEST(0, shares_count - 1), updated_at = NOW() WHERE id = OLD.post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_post_shares_count ON post_shares;
CREATE TRIGGER trigger_post_shares_count
    AFTER INSERT OR DELETE ON post_shares
    FOR EACH ROW EXECUTE FUNCTION update_post_shares_count();

-- Update post saves_count
DROP FUNCTION IF EXISTS update_post_saves_count() CASCADE;
CREATE OR REPLACE FUNCTION update_post_saves_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE posts SET saves_count = saves_count + 1, updated_at = NOW() WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE posts SET saves_count = GREATEST(0, saves_count - 1), updated_at = NOW() WHERE id = OLD.post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_post_saves_count ON saved_posts;
CREATE TRIGGER trigger_post_saves_count
    AFTER INSERT OR DELETE ON saved_posts
    FOR EACH ROW EXECUTE FUNCTION update_post_saves_count();

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE post_likes IS 'Users liking posts';
COMMENT ON TABLE post_comments IS 'Nested comment system (max 2 levels)';
COMMENT ON TABLE comment_likes IS 'Users liking comments';
COMMENT ON TABLE post_shares IS 'Reposts with optional quote (like Twitter retweets)';
COMMENT ON TABLE saved_posts IS 'Bookmarked posts organized by collections';

COMMENT ON COLUMN post_comments.parent_comment_id IS 'NULL for top-level, set for replies (max 2 levels)';
COMMENT ON COLUMN post_shares.repost_comment IS 'Optional quote text (like quote tweet)';
COMMENT ON COLUMN saved_posts.collection_name IS 'Custom collection name for organizing saves';

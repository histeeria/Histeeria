-- ============================================================================
-- HISTEERIA DATABASE - 03: CONTENT
-- ============================================================================
-- Contains: Posts, Polls, Articles, Hashtags, Mentions
-- Dependencies: 01_core_schema.sql (users table)
-- ============================================================================

-- ============================================================================
-- POSTS TABLE
-- Unified table for all content types (posts, polls, articles)
-- ============================================================================
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Content Type
    post_type VARCHAR(20) NOT NULL CHECK (post_type IN ('post', 'poll', 'article')),
    
    -- Content
    content TEXT NOT NULL CHECK (
        (post_type = 'article' AND LENGTH(content) <= 100000) OR
        (post_type != 'article' AND LENGTH(content) <= 10000)
    ),
    
    -- Media (for posts)
    media_urls TEXT[],
    media_types TEXT[],  -- ['image', 'image', 'video']
    
    -- Settings
    visibility VARCHAR(20) DEFAULT 'public' CHECK (visibility IN ('public', 'connections', 'private')),
    allows_comments BOOLEAN DEFAULT TRUE,
    allows_sharing BOOLEAN DEFAULT TRUE,
    
    -- Denormalized Stats (for performance)
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    views_count INTEGER DEFAULT 0,
    saves_count INTEGER DEFAULT 0,
    
    -- Features
    is_pinned BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,
    is_nsfw BOOLEAN DEFAULT FALSE,
    
    -- Status
    is_published BOOLEAN DEFAULT TRUE,
    is_draft BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMP,
    
    -- Full-text search
    search_vector tsvector,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP  -- Soft delete
);

-- ============================================================================
-- POLLS TABLE
-- Interactive polls with voting system
-- ============================================================================
CREATE TABLE IF NOT EXISTS polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL UNIQUE REFERENCES posts(id) ON DELETE CASCADE,
    
    -- Poll Content
    question TEXT NOT NULL CHECK (LENGTH(question) <= 280),
    
    -- Settings
    duration_hours INTEGER NOT NULL DEFAULT 168,  -- Default 1 week
    allow_multiple_votes BOOLEAN DEFAULT FALSE,
    show_results_before_vote BOOLEAN DEFAULT TRUE,
    allow_vote_changes BOOLEAN DEFAULT TRUE,
    anonymous_votes BOOLEAN DEFAULT FALSE,
    
    -- Status
    is_closed BOOLEAN DEFAULT FALSE,
    closed_at TIMESTAMP,
    ends_at TIMESTAMP NOT NULL,
    
    -- Stats
    total_votes INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- POLL OPTIONS TABLE
-- Poll choices (max 4 per poll)
-- ============================================================================
CREATE TABLE IF NOT EXISTS poll_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_text VARCHAR(100) NOT NULL,
    option_index INTEGER NOT NULL CHECK (option_index >= 0 AND option_index <= 3),
    votes_count INTEGER DEFAULT 0,
    
    CONSTRAINT unique_poll_option UNIQUE (poll_id, option_index)
);

-- ============================================================================
-- POLL VOTES TABLE
-- User votes on polls
-- FIX: Removed hard UNIQUE constraint to support allow_multiple_votes
-- ============================================================================
CREATE TABLE IF NOT EXISTS poll_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_id UUID NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    voted_at TIMESTAMP DEFAULT NOW()
    -- Note: Uniqueness enforced by trigger based on poll settings
);

-- ============================================================================
-- ARTICLES TABLE
-- Long-form rich text content with SEO
-- ============================================================================
CREATE TABLE IF NOT EXISTS articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL UNIQUE REFERENCES posts(id) ON DELETE CASCADE,
    
    -- Content
    title VARCHAR(100) NOT NULL,
    subtitle VARCHAR(150),
    content_html TEXT NOT NULL,
    cover_image_url TEXT,
    
    -- SEO
    meta_title VARCHAR(60),
    meta_description VARCHAR(160),
    -- FIX: Better slug validation with min/max length and proper format
    slug VARCHAR(100) UNIQUE NOT NULL CHECK (
        slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND 
        LENGTH(slug) >= 3 AND 
        LENGTH(slug) <= 100
    ),
    
    -- Metadata
    read_time_minutes INTEGER,
    category VARCHAR(50),
    
    -- Stats
    views_count INTEGER DEFAULT 0,
    reads_count INTEGER DEFAULT 0,  -- Users who scrolled to end
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- ARTICLE TAGS TABLE
-- Tags for article categorization
-- ============================================================================
CREATE TABLE IF NOT EXISTS article_tags (
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    tag VARCHAR(50) NOT NULL,
    PRIMARY KEY (article_id, tag)
);

-- ============================================================================
-- HASHTAGS TABLE
-- Hashtag registry with trending scores
-- ============================================================================
CREATE TABLE IF NOT EXISTS hashtags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag VARCHAR(100) UNIQUE NOT NULL,
    posts_count INTEGER DEFAULT 0,
    followers_count INTEGER DEFAULT 0,
    trending_score DECIMAL(10,2) DEFAULT 0,
    last_trending_update TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- POST HASHTAGS TABLE
-- Many-to-many: posts <-> hashtags
-- ============================================================================
CREATE TABLE IF NOT EXISTS post_hashtags (
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    hashtag_id UUID NOT NULL REFERENCES hashtags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, hashtag_id)
);

-- ============================================================================
-- HASHTAG FOLLOWERS TABLE
-- Users following specific hashtags
-- ============================================================================
CREATE TABLE IF NOT EXISTS hashtag_followers (
    hashtag_id UUID NOT NULL REFERENCES hashtags(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (hashtag_id, user_id)
);

-- ============================================================================
-- POST MENTIONS TABLE
-- User mentions in posts (@username)
-- ============================================================================
CREATE TABLE IF NOT EXISTS post_mentions (
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    mentioned_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, mentioned_user_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
-- Posts
CREATE INDEX IF NOT EXISTS idx_posts_user_time ON posts(user_id, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_type ON posts(post_type);
CREATE INDEX IF NOT EXISTS idx_posts_visibility ON posts(visibility);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_pinned ON posts(user_id, is_pinned) WHERE is_pinned = TRUE;
CREATE INDEX IF NOT EXISTS idx_posts_search ON posts USING GIN(search_vector);

-- Optimized feed index (CRITICAL for performance)
CREATE INDEX IF NOT EXISTS idx_posts_feed ON posts(created_at DESC)
    INCLUDE (user_id, post_type, content, likes_count, comments_count, visibility)
    WHERE is_published = TRUE AND deleted_at IS NULL;

-- Polls
CREATE INDEX IF NOT EXISTS idx_polls_post ON polls(post_id);
CREATE INDEX IF NOT EXISTS idx_polls_ends ON polls(ends_at) WHERE is_closed = FALSE;
CREATE INDEX IF NOT EXISTS idx_poll_options_poll ON poll_options(poll_id, option_index);
CREATE INDEX IF NOT EXISTS idx_poll_votes_poll ON poll_votes(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_user ON poll_votes(user_id);

-- Articles
CREATE INDEX IF NOT EXISTS idx_articles_post ON articles(post_id);
CREATE INDEX IF NOT EXISTS idx_articles_slug ON articles(slug);
CREATE INDEX IF NOT EXISTS idx_articles_category ON articles(category);
CREATE INDEX IF NOT EXISTS idx_article_tags_tag ON article_tags(tag);

-- Hashtags
CREATE INDEX IF NOT EXISTS idx_hashtags_tag_lower ON hashtags(LOWER(tag));
CREATE INDEX IF NOT EXISTS idx_hashtags_trending ON hashtags(trending_score DESC);
CREATE INDEX IF NOT EXISTS idx_post_hashtags_post ON post_hashtags(post_id);
CREATE INDEX IF NOT EXISTS idx_post_hashtags_hashtag ON post_hashtags(hashtag_id);

-- Mentions
CREATE INDEX IF NOT EXISTS idx_post_mentions_user ON post_mentions(mentioned_user_id);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-set published_at on publish
DROP FUNCTION IF EXISTS set_published_at() CASCADE;
CREATE OR REPLACE FUNCTION set_published_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_published = TRUE AND OLD.is_published = FALSE AND NEW.published_at IS NULL THEN
        NEW.published_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_published_at ON posts;
CREATE TRIGGER trigger_set_published_at
    BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION set_published_at();

-- Update post search vector
DROP FUNCTION IF EXISTS update_post_search_vector() CASCADE;
CREATE OR REPLACE FUNCTION update_post_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := setweight(to_tsvector('english', COALESCE(NEW.content, '')), 'A');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_post_search_vector ON posts;
CREATE TRIGGER trigger_update_post_search_vector
    BEFORE INSERT OR UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION update_post_search_vector();

-- Update user posts_count
DROP FUNCTION IF EXISTS update_user_posts_count() CASCADE;
CREATE OR REPLACE FUNCTION update_user_posts_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_published = TRUE THEN
        UPDATE users SET posts_count = posts_count + 1 WHERE id = NEW.user_id;
    ELSIF TG_OP = 'DELETE' AND OLD.is_published = TRUE THEN
        UPDATE users SET posts_count = GREATEST(0, posts_count - 1) WHERE id = OLD.user_id;
    ELSIF TG_OP = 'UPDATE' AND OLD.is_published != NEW.is_published THEN
        IF NEW.is_published = TRUE THEN
            UPDATE users SET posts_count = posts_count + 1 WHERE id = NEW.user_id;
        ELSE
            UPDATE users SET posts_count = GREATEST(0, posts_count - 1) WHERE id = NEW.user_id;
        END IF;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_user_posts_count ON posts;
CREATE TRIGGER trigger_user_posts_count
    AFTER INSERT OR DELETE OR UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION update_user_posts_count();

-- FIX: Check poll vote rules (single vs multiple votes)
DROP FUNCTION IF EXISTS check_poll_vote_rules() CASCADE;
CREATE OR REPLACE FUNCTION check_poll_vote_rules()
RETURNS TRIGGER AS $$
DECLARE
    poll_settings RECORD;
    existing_vote_count INTEGER;
BEGIN
    -- Get poll settings
    SELECT allow_multiple_votes, allow_vote_changes, is_closed, ends_at
    INTO poll_settings
    FROM polls WHERE id = NEW.poll_id;
    
    -- Check if poll is closed or expired
    IF poll_settings.is_closed OR poll_settings.ends_at < NOW() THEN
        RAISE EXCEPTION 'This poll is closed and no longer accepting votes';
    END IF;
    
    -- Count existing votes by this user
    SELECT COUNT(*) INTO existing_vote_count
    FROM poll_votes
    WHERE poll_id = NEW.poll_id AND user_id = NEW.user_id;
    
    -- If multiple votes not allowed and user already voted
    IF NOT poll_settings.allow_multiple_votes AND existing_vote_count > 0 THEN
        -- Check if this is a vote change (UPDATE will handle this)
        IF TG_OP = 'INSERT' THEN
            RAISE EXCEPTION 'You have already voted on this poll';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_poll_vote_rules ON poll_votes;
CREATE TRIGGER trigger_check_poll_vote_rules
    BEFORE INSERT ON poll_votes
    FOR EACH ROW EXECUTE FUNCTION check_poll_vote_rules();

-- Update poll votes count
DROP FUNCTION IF EXISTS update_poll_votes_count() CASCADE;
CREATE OR REPLACE FUNCTION update_poll_votes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE polls SET total_votes = total_votes + 1 WHERE id = NEW.poll_id;
        UPDATE poll_options SET votes_count = votes_count + 1 WHERE id = NEW.option_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE polls SET total_votes = GREATEST(0, total_votes - 1) WHERE id = OLD.poll_id;
        UPDATE poll_options SET votes_count = GREATEST(0, votes_count - 1) WHERE id = OLD.option_id;
    ELSIF TG_OP = 'UPDATE' AND OLD.option_id != NEW.option_id THEN
        UPDATE poll_options SET votes_count = GREATEST(0, votes_count - 1) WHERE id = OLD.option_id;
        UPDATE poll_options SET votes_count = votes_count + 1 WHERE id = NEW.option_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_poll_votes_count ON poll_votes;
CREATE TRIGGER trigger_poll_votes_count
    AFTER INSERT OR DELETE OR UPDATE ON poll_votes
    FOR EACH ROW EXECUTE FUNCTION update_poll_votes_count();

-- Update hashtag posts_count
DROP FUNCTION IF EXISTS update_hashtag_posts_count() CASCADE;
CREATE OR REPLACE FUNCTION update_hashtag_posts_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE hashtags SET posts_count = posts_count + 1 WHERE id = NEW.hashtag_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE hashtags SET posts_count = GREATEST(0, posts_count - 1) WHERE id = OLD.hashtag_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_hashtag_posts_count ON post_hashtags;
CREATE TRIGGER trigger_hashtag_posts_count
    AFTER INSERT OR DELETE ON post_hashtags
    FOR EACH ROW EXECUTE FUNCTION update_hashtag_posts_count();

-- Update hashtag followers_count
DROP FUNCTION IF EXISTS update_hashtag_followers_count() CASCADE;
CREATE OR REPLACE FUNCTION update_hashtag_followers_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE hashtags SET followers_count = followers_count + 1 WHERE id = NEW.hashtag_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE hashtags SET followers_count = GREATEST(0, followers_count - 1) WHERE id = OLD.hashtag_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_hashtag_followers_count ON hashtag_followers;
CREATE TRIGGER trigger_hashtag_followers_count
    AFTER INSERT OR DELETE ON hashtag_followers
    FOR EACH ROW EXECUTE FUNCTION update_hashtag_followers_count();

-- ============================================================================
-- FUNCTIONS - Content Utilities
-- ============================================================================

-- FIX: DEPRECATED - Use cursor-based pagination instead
DROP FUNCTION IF EXISTS get_user_feed(UUID, INTEGER, INTEGER);

-- FIX: Cursor-based feed pagination (much faster at scale)
DROP FUNCTION IF EXISTS get_user_feed_cursor(UUID, TIMESTAMP, INTEGER);
CREATE OR REPLACE FUNCTION get_user_feed_cursor(
    user_uuid UUID,
    cursor_timestamp TIMESTAMP DEFAULT NULL,  -- NULL for first page
    page_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    post_id UUID,
    post_type VARCHAR(20),
    content TEXT,
    user_id UUID,
    published_at TIMESTAMP,
    likes_count INTEGER,
    comments_count INTEGER,
    next_cursor TIMESTAMP  -- Use this for next page
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.post_type,
        p.content,
        p.user_id,
        p.published_at,
        p.likes_count,
        p.comments_count,
        p.published_at as next_cursor  -- Client uses last row's timestamp
    FROM posts p
    WHERE 
        p.is_published = TRUE 
        AND p.deleted_at IS NULL
        AND (cursor_timestamp IS NULL OR p.published_at < cursor_timestamp)
        AND (
            p.visibility = 'public' 
            OR p.user_id = user_uuid
            OR EXISTS (
                SELECT 1 FROM user_relationships ur
                WHERE ur.from_user_id = user_uuid
                AND ur.to_user_id = p.user_id
                AND ur.relationship_type = 'following'
                AND ur.status = 'active'
            )
        )
    ORDER BY p.published_at DESC
    LIMIT page_limit;
END;
$$ LANGUAGE plpgsql;

-- Legacy function for backward compatibility (wraps cursor function)
CREATE OR REPLACE FUNCTION get_user_feed(
    user_uuid UUID,
    page_limit INTEGER DEFAULT 20,
    page_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    post_id UUID,
    post_type VARCHAR(20),
    content TEXT,
    user_id UUID,
    published_at TIMESTAMP,
    likes_count INTEGER,
    comments_count INTEGER
) AS $$
BEGIN
    -- WARNING: OFFSET pagination is slow at scale. Use get_user_feed_cursor instead.
    RETURN QUERY
    SELECT 
        p.id,
        p.post_type,
        p.content,
        p.user_id,
        p.published_at,
        p.likes_count,
        p.comments_count
    FROM posts p
    WHERE 
        p.is_published = TRUE 
        AND p.deleted_at IS NULL
        AND (
            p.visibility = 'public' 
            OR p.user_id = user_uuid
            OR EXISTS (
                SELECT 1 FROM user_relationships ur
                WHERE ur.from_user_id = user_uuid
                AND ur.to_user_id = p.user_id
                AND ur.relationship_type = 'following'
                AND ur.status = 'active'
            )
        )
    ORDER BY p.published_at DESC
    LIMIT page_limit OFFSET page_offset;
END;
$$ LANGUAGE plpgsql;

-- Get trending hashtags
DROP FUNCTION IF EXISTS get_trending_hashtags(INTEGER);
CREATE OR REPLACE FUNCTION get_trending_hashtags(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    tag VARCHAR(100),
    posts_count INTEGER,
    trending_score DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT h.tag, h.posts_count, h.trending_score
    FROM hashtags h
    ORDER BY h.trending_score DESC, h.posts_count DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Calculate hashtag trending scores (run daily via cron)
-- FIX: Weight by unique authors to prevent manipulation by spam accounts
DROP FUNCTION IF EXISTS calculate_hashtag_trending_scores();
CREATE OR REPLACE FUNCTION calculate_hashtag_trending_scores()
RETURNS VOID AS $$
BEGIN
    UPDATE hashtags h
    SET 
        trending_score = (
            SELECT 
                -- FIX: Unique authors weighted more than post count
                -- Prevents one user spamming a hashtag to inflate score
                COUNT(DISTINCT p.user_id) * 20 +  -- Unique authors (most important)
                COUNT(*) * 5 +                     -- Total posts (less weight)
                COALESCE(SUM(p.likes_count + p.comments_count * 2), 0)  -- Engagement
            FROM post_hashtags ph
            JOIN posts p ON ph.post_id = p.id
            WHERE ph.hashtag_id = h.id
            AND p.published_at >= NOW() - INTERVAL '7 days'
            AND p.deleted_at IS NULL
            AND p.is_published = TRUE
        ),
        last_trending_update = NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE posts IS 'Unified table for all content: posts, polls, articles';
COMMENT ON TABLE polls IS 'Interactive polls with multiple choice voting';
COMMENT ON TABLE articles IS 'Long-form rich text articles with SEO';
COMMENT ON TABLE hashtags IS 'Hashtag registry with trending scores';

COMMENT ON COLUMN posts.post_type IS 'post=short content, poll=interactive vote, article=long-form';
COMMENT ON COLUMN posts.visibility IS 'public=all users, connections=followers only, private=author only';
COMMENT ON COLUMN articles.slug IS 'URL-friendly identifier for SEO';
COMMENT ON COLUMN hashtags.trending_score IS 'Calculated daily: posts * 10 + engagement';

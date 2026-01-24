-- ============================================================================
-- HISTEERIA DATABASE - 15: POST VIEWS TRACKING
-- ============================================================================
-- Contains: Post views tracking for insights (reach, impressions)
-- Dependencies: 01_core_schema.sql, 03_content.sql
-- ============================================================================

-- ============================================================================
-- POST VIEWS TABLE
-- Tracks unique user views for post insights (reach calculation)
-- ============================================================================
CREATE TABLE IF NOT EXISTS post_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_post_user_view UNIQUE (post_id, user_id)
);

-- ============================================================================
-- PROFILE VISITS FROM POST TABLE
-- Tracks when users visit profile from a specific post
-- ============================================================================
CREATE TABLE IF NOT EXISTS profile_visits_from_post (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    visitor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    visited_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_post_profile_visit UNIQUE (post_id, visitor_id, profile_owner_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_post_views_post ON post_views(post_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_views_user ON post_views(user_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_profile_visits_post ON profile_visits_from_post(post_id, visited_at DESC);
CREATE INDEX IF NOT EXISTS idx_profile_visits_profile_owner ON profile_visits_from_post(profile_owner_id, visited_at DESC);

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE post_views IS 'Tracks unique user views for post insights (reach = unique users who viewed)';
COMMENT ON TABLE profile_visits_from_post IS 'Tracks profile visits originating from a specific post';

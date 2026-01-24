-- ============================================================================
-- HISTEERIA DATABASE - 16: POST AND USER MODERATION
-- ============================================================================
-- Contains: Post deletion, restriction, user blocking, restricting, and reporting
-- Dependencies: 01_core_schema.sql, 02_relationships.sql, 03_content.sql
-- ============================================================================

-- ============================================================================
-- RESTRICTED POSTS TABLE
-- Tracks posts that users have restricted (hidden from their feed)
-- ============================================================================
CREATE TABLE IF NOT EXISTS restricted_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    restricted_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_restricted_post UNIQUE (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_restricted_posts_user_id ON restricted_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_restricted_posts_post_id ON restricted_posts(post_id);

-- ============================================================================
-- BLOCKED USERS TABLE
-- Tracks users that have been blocked (complete barrier - no messaging, content hidden)
-- ============================================================================
CREATE TABLE IF NOT EXISTS blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_blocked_user UNIQUE (blocker_id, blocked_id),
    CONSTRAINT no_self_block CHECK (blocker_id != blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker_id ON blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked_id ON blocked_users(blocked_id);

-- ============================================================================
-- RESTRICTED USERS TABLE
-- Tracks users that have been restricted (their content is hidden from feed)
-- ============================================================================
CREATE TABLE IF NOT EXISTS restricted_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restrictor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    restricted_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    restricted_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_restricted_user UNIQUE (restrictor_id, restricted_id),
    CONSTRAINT no_self_restrict CHECK (restrictor_id != restricted_id)
);

CREATE INDEX IF NOT EXISTS idx_restricted_users_restrictor_id ON restricted_users(restrictor_id);
CREATE INDEX IF NOT EXISTS idx_restricted_users_restricted_id ON restricted_users(restricted_id);

-- ============================================================================
-- USER REPORTS TABLE
-- Tracks user reports for moderation purposes
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- pending, reviewed, resolved, dismissed
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_user_report UNIQUE (reporter_id, reported_id),
    CONSTRAINT no_self_report CHECK (reporter_id != reported_id),
    CONSTRAINT valid_report_status CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed'))
);

CREATE INDEX IF NOT EXISTS idx_user_reports_reporter_id ON user_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_reported_id ON user_reports(reported_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_status ON user_reports(status);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE restricted_posts IS 'Tracks posts that users have hidden from their feed';
COMMENT ON TABLE blocked_users IS 'Tracks blocked user relationships - complete barrier, no messaging, content hidden';
COMMENT ON TABLE restricted_users IS 'Tracks restricted users - their content is hidden from feed';
COMMENT ON TABLE user_reports IS 'Tracks user reports for moderation and safety purposes';

-- ============================================================================
-- HISTEERIA DATABASE - 02: RELATIONSHIPS
-- ============================================================================
-- Contains: Follow/Connect/Collaborate system, Rate limiting, Spam protection
-- Dependencies: 01_core_schema.sql (users table)
-- ============================================================================

-- ============================================================================
-- ENUMS
-- ============================================================================
DO $$ BEGIN
    CREATE TYPE relationship_type AS ENUM ('following', 'connected', 'collaborating');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE relationship_status AS ENUM ('active', 'pending', 'rejected', 'blocked');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- USER RELATIONSHIPS TABLE
-- Core table for all user-to-user relationships
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Relationship tier
    relationship_type relationship_type NOT NULL,
    status relationship_status DEFAULT 'active',
    
    -- For pending requests
    request_message TEXT CHECK (request_message IS NULL OR LENGTH(request_message) <= 500),
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    accepted_at TIMESTAMP,
    
    -- Constraints
    CONSTRAINT unique_relationship UNIQUE(from_user_id, to_user_id, relationship_type),
    CONSTRAINT no_self_relationship CHECK(from_user_id != to_user_id)
);

-- ============================================================================
-- RELATIONSHIP RATE LIMITS TABLE
-- Prevents spam by limiting actions per time window
-- ============================================================================
CREATE TABLE IF NOT EXISTS relationship_rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_type VARCHAR(20) NOT NULL,  -- 'follow', 'connect', 'collaborate'
    action_count INTEGER DEFAULT 0,
    window_start TIMESTAMP DEFAULT NOW(),
    cooldown_multiplier DECIMAL(3,1) DEFAULT 1.0,  -- 1.0 = 24hrs, 2.0 = 48hrs for repeat offenders
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_user_action UNIQUE(user_id, action_type)
);

-- ============================================================================
-- SPAM FLAGS TABLE
-- Records suspicious activity patterns for manual review
-- ============================================================================
CREATE TABLE IF NOT EXISTS spam_flags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    detection_type VARCHAR(50) NOT NULL,  -- 'rapid_follow_unfollow', 'excessive_requests', etc.
    flag_count INTEGER DEFAULT 1,
    last_flagged_at TIMESTAMP DEFAULT NOW(),
    requires_review BOOLEAN DEFAULT FALSE,
    reviewed_at TIMESTAMP,
    reviewed_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_user_detection UNIQUE(user_id, detection_type)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_relationships_from ON user_relationships(from_user_id);
CREATE INDEX IF NOT EXISTS idx_relationships_to ON user_relationships(to_user_id);
CREATE INDEX IF NOT EXISTS idx_relationships_type ON user_relationships(relationship_type);
CREATE INDEX IF NOT EXISTS idx_relationships_status ON user_relationships(status);
CREATE INDEX IF NOT EXISTS idx_relationships_from_to ON user_relationships(from_user_id, to_user_id);
CREATE INDEX IF NOT EXISTS idx_relationships_to_type_status ON user_relationships(to_user_id, relationship_type, status);
CREATE INDEX IF NOT EXISTS idx_relationships_mutual ON user_relationships(to_user_id, from_user_id, relationship_type, status);

CREATE INDEX IF NOT EXISTS idx_rate_limits_user ON relationship_rate_limits(user_id);
CREATE INDEX IF NOT EXISTS idx_rate_limits_window ON relationship_rate_limits(window_start);
-- FIX: Composite index for rate limit lookups (used in trigger)
CREATE INDEX IF NOT EXISTS idx_rate_limits_user_action ON relationship_rate_limits(user_id, action_type);
-- FIX: Index for active following relationships (heavily queried in RLS)
CREATE INDEX IF NOT EXISTS idx_relationships_following_active ON user_relationships(from_user_id, to_user_id)
WHERE relationship_type = 'following' AND status = 'active';

CREATE INDEX IF NOT EXISTS idx_spam_flags_user ON spam_flags(user_id);
CREATE INDEX IF NOT EXISTS idx_spam_flags_review ON spam_flags(requires_review) WHERE requires_review = TRUE;

-- ============================================================================
-- TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_relationships_updated_at ON user_relationships;
DROP TRIGGER IF EXISTS update_rate_limits_updated_at ON relationship_rate_limits;

CREATE TRIGGER update_relationships_updated_at
    BEFORE UPDATE ON user_relationships
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rate_limits_updated_at
    BEFORE UPDATE ON relationship_rate_limits
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- TRIGGERS - Update user follower/following counts
-- ============================================================================
DROP FUNCTION IF EXISTS update_relationship_counts() CASCADE;
CREATE OR REPLACE FUNCTION update_relationship_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Update counts based on relationship type
        IF NEW.relationship_type = 'following' AND NEW.status = 'active' THEN
            UPDATE users SET following_count = following_count + 1 WHERE id = NEW.from_user_id;
            UPDATE users SET followers_count = followers_count + 1 WHERE id = NEW.to_user_id;
        ELSIF NEW.relationship_type = 'connected' AND NEW.status = 'active' THEN
            UPDATE users SET connections_count = connections_count + 1 WHERE id = NEW.from_user_id;
            UPDATE users SET connections_count = connections_count + 1 WHERE id = NEW.to_user_id;
        ELSIF NEW.relationship_type = 'collaborating' AND NEW.status = 'active' THEN
            UPDATE users SET collaborators_count = collaborators_count + 1 WHERE id = NEW.from_user_id;
            UPDATE users SET collaborators_count = collaborators_count + 1 WHERE id = NEW.to_user_id;
        END IF;
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.relationship_type = 'following' AND OLD.status = 'active' THEN
            UPDATE users SET following_count = GREATEST(0, following_count - 1) WHERE id = OLD.from_user_id;
            UPDATE users SET followers_count = GREATEST(0, followers_count - 1) WHERE id = OLD.to_user_id;
        ELSIF OLD.relationship_type = 'connected' AND OLD.status = 'active' THEN
            UPDATE users SET connections_count = GREATEST(0, connections_count - 1) WHERE id = OLD.from_user_id;
            UPDATE users SET connections_count = GREATEST(0, connections_count - 1) WHERE id = OLD.to_user_id;
        ELSIF OLD.relationship_type = 'collaborating' AND OLD.status = 'active' THEN
            UPDATE users SET collaborators_count = GREATEST(0, collaborators_count - 1) WHERE id = OLD.from_user_id;
            UPDATE users SET collaborators_count = GREATEST(0, collaborators_count - 1) WHERE id = OLD.to_user_id;
        END IF;
        RETURN OLD;
        
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle status change (pending -> active, active -> blocked, etc.)
        IF OLD.status != NEW.status THEN
            -- Was active, now not active -> decrement
            IF OLD.status = 'active' AND NEW.status != 'active' THEN
                IF NEW.relationship_type = 'following' THEN
                    UPDATE users SET following_count = GREATEST(0, following_count - 1) WHERE id = NEW.from_user_id;
                    UPDATE users SET followers_count = GREATEST(0, followers_count - 1) WHERE id = NEW.to_user_id;
                ELSIF NEW.relationship_type = 'connected' THEN
                    UPDATE users SET connections_count = GREATEST(0, connections_count - 1) WHERE id = NEW.from_user_id;
                    UPDATE users SET connections_count = GREATEST(0, connections_count - 1) WHERE id = NEW.to_user_id;
                ELSIF NEW.relationship_type = 'collaborating' THEN
                    UPDATE users SET collaborators_count = GREATEST(0, collaborators_count - 1) WHERE id = NEW.from_user_id;
                    UPDATE users SET collaborators_count = GREATEST(0, collaborators_count - 1) WHERE id = NEW.to_user_id;
                END IF;
            -- Was not active, now active -> increment
            ELSIF OLD.status != 'active' AND NEW.status = 'active' THEN
                IF NEW.relationship_type = 'following' THEN
                    UPDATE users SET following_count = following_count + 1 WHERE id = NEW.from_user_id;
                    UPDATE users SET followers_count = followers_count + 1 WHERE id = NEW.to_user_id;
                ELSIF NEW.relationship_type = 'connected' THEN
                    UPDATE users SET connections_count = connections_count + 1 WHERE id = NEW.from_user_id;
                    UPDATE users SET connections_count = connections_count + 1 WHERE id = NEW.to_user_id;
                ELSIF NEW.relationship_type = 'collaborating' THEN
                    UPDATE users SET collaborators_count = collaborators_count + 1 WHERE id = NEW.from_user_id;
                    UPDATE users SET collaborators_count = collaborators_count + 1 WHERE id = NEW.to_user_id;
                END IF;
            END IF;
        END IF;
        RETURN NEW;
    END IF;
    -- FIX: Consistent return for AFTER triggers
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_relationship_counts ON user_relationships;
CREATE TRIGGER trigger_relationship_counts
    AFTER INSERT OR UPDATE OR DELETE ON user_relationships
    FOR EACH ROW EXECUTE FUNCTION update_relationship_counts();

-- ============================================================================
-- RATE LIMITING TRIGGER
-- Prevents spam by limiting relationship actions
-- FIX: Improved with better index usage and atomic operations
-- ============================================================================
DROP FUNCTION IF EXISTS check_relationship_rate_limit() CASCADE;
CREATE OR REPLACE FUNCTION check_relationship_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
    rate_record RECORD;
    max_actions INTEGER;
    window_hours INTEGER;
    window_expiry TIMESTAMP;
BEGIN
    -- Different limits based on relationship type
    CASE NEW.relationship_type::TEXT
        WHEN 'following' THEN
            max_actions := 50;  -- 50 follows per window
            window_hours := 1;  -- 1 hour window
        WHEN 'connected' THEN
            max_actions := 20;  -- 20 connection requests per window
            window_hours := 24; -- 24 hour window
        WHEN 'collaborating' THEN
            max_actions := 10;  -- 10 collab requests per window
            window_hours := 24; -- 24 hour window
        ELSE
            max_actions := 30;
            window_hours := 1;
    END CASE;
    
    -- FIX: Use single atomic UPSERT instead of SELECT + UPDATE/INSERT
    -- This is faster and prevents race conditions
    INSERT INTO relationship_rate_limits (user_id, action_type, action_count, window_start)
    VALUES (NEW.from_user_id, NEW.relationship_type::TEXT, 1, NOW())
    ON CONFLICT (user_id, action_type) DO UPDATE SET
        -- Reset window if expired, otherwise increment
        action_count = CASE
            WHEN relationship_rate_limits.window_start < 
                 NOW() - (window_hours * relationship_rate_limits.cooldown_multiplier || ' hours')::INTERVAL
            THEN 1  -- Reset
            ELSE relationship_rate_limits.action_count + 1  -- Increment
        END,
        window_start = CASE
            WHEN relationship_rate_limits.window_start < 
                 NOW() - (window_hours * relationship_rate_limits.cooldown_multiplier || ' hours')::INTERVAL
            THEN NOW()  -- Reset window
            ELSE relationship_rate_limits.window_start  -- Keep current
        END
    RETURNING * INTO rate_record;
    
    -- Check if limit exceeded AFTER the update
    IF rate_record.action_count > max_actions THEN
        -- Rollback the increment by decrementing
        UPDATE relationship_rate_limits
        SET action_count = action_count - 1
        WHERE id = rate_record.id;
        
        RAISE EXCEPTION 'Rate limit exceeded: Too many % actions. Please wait.', NEW.relationship_type;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_rate_limit ON user_relationships;
CREATE TRIGGER trigger_check_rate_limit
    BEFORE INSERT ON user_relationships
    FOR EACH ROW EXECUTE FUNCTION check_relationship_rate_limit();

-- ============================================================================
-- FUNCTIONS - Relationship Utilities
-- ============================================================================

-- Check if two users have a specific relationship
DROP FUNCTION IF EXISTS has_relationship(UUID, UUID, relationship_type);
CREATE OR REPLACE FUNCTION has_relationship(
    user_a UUID,
    user_b UUID,
    rel_type relationship_type
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM user_relationships
        WHERE from_user_id = user_a 
        AND to_user_id = user_b 
        AND relationship_type = rel_type
        AND status = 'active'
    );
END;
$$ LANGUAGE plpgsql;

-- Check if relationship is mutual (both follow each other, etc.)
DROP FUNCTION IF EXISTS is_mutual_relationship(UUID, UUID, relationship_type);
CREATE OR REPLACE FUNCTION is_mutual_relationship(
    user_a UUID,
    user_b UUID,
    rel_type relationship_type
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN has_relationship(user_a, user_b, rel_type) 
       AND has_relationship(user_b, user_a, rel_type);
END;
$$ LANGUAGE plpgsql;

-- Get user's followers/following/connections count
DROP FUNCTION IF EXISTS get_relationship_counts(UUID);
CREATE OR REPLACE FUNCTION get_relationship_counts(user_id_param UUID)
RETURNS TABLE (
    followers_count BIGINT,
    following_count BIGINT,
    connections_count BIGINT,
    collaborators_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM user_relationships WHERE to_user_id = user_id_param AND relationship_type = 'following' AND status = 'active'),
        (SELECT COUNT(*) FROM user_relationships WHERE from_user_id = user_id_param AND relationship_type = 'following' AND status = 'active'),
        (SELECT COUNT(*) FROM user_relationships WHERE (from_user_id = user_id_param OR to_user_id = user_id_param) AND relationship_type = 'connected' AND status = 'active'),
        (SELECT COUNT(*) FROM user_relationships WHERE (from_user_id = user_id_param OR to_user_id = user_id_param) AND relationship_type = 'collaborating' AND status = 'active');
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE user_relationships IS 'All user-to-user relationships: following, connected, collaborating';
COMMENT ON TABLE relationship_rate_limits IS 'Rate limits for relationship actions with escalating cooldowns';
COMMENT ON TABLE spam_flags IS 'Tracks suspicious activity patterns for manual review';

COMMENT ON COLUMN user_relationships.relationship_type IS 'following=one-way, connected=mutual acceptance, collaborating=work partners';
COMMENT ON COLUMN user_relationships.status IS 'active=confirmed, pending=awaiting acceptance, rejected=declined, blocked=no contact';
COMMENT ON COLUMN relationship_rate_limits.cooldown_multiplier IS 'Increases for repeat limit violations (1.0=24hrs, 2.0=48hrs)';

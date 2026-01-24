-- ============================================================================
-- HISTEERIA DATABASE - 01: CORE SCHEMA
-- ============================================================================
-- Contains: Extensions, Users table, Sessions, Profile fields
-- Run Order: FIRST (no dependencies)
-- ============================================================================

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For fuzzy text search
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- For secure hashing

-- ============================================================================
-- USERS TABLE
-- Core user accounts with all profile fields
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Authentication
    email VARCHAR(255) NOT NULL,  -- Stored but not indexed directly for privacy
    email_hash VARCHAR(64) UNIQUE NOT NULL,  -- SHA-256 hash for lookups (prevents enumeration)
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255),  -- NULL for OAuth-only accounts
    
    -- Basic Profile
    display_name VARCHAR(100) NOT NULL,
    age INTEGER NOT NULL CHECK (age >= 13 AND age <= 120),
    bio VARCHAR(150),
    location VARCHAR(100),
    website VARCHAR(255),
    profile_picture TEXT,
    
    -- Gender
    gender VARCHAR(20) CHECK (gender IN ('male', 'female', 'non-binary', 'prefer-not-to-say', 'custom') OR gender IS NULL),
    gender_custom VARCHAR(50),
    
    -- About Section
    story VARCHAR(1000),
    ambition VARCHAR(200),
    
    -- OAuth Providers
    google_id VARCHAR(255) UNIQUE,
    github_id VARCHAR(255) UNIQUE,
    linkedin_id VARCHAR(255) UNIQUE,
    oauth_provider VARCHAR(50),
    
    -- Social Links (JSONB for flexibility)
    social_links JSONB DEFAULT '{
        "twitter": null,
        "instagram": null,
        "facebook": null,
        "linkedin": null,
        "github": null,
        "youtube": null
    }'::jsonb,
    
    -- Verification & Security
    is_verified BOOLEAN DEFAULT FALSE,
    is_email_verified BOOLEAN DEFAULT FALSE,
    email_verification_code VARCHAR(6),
    email_verification_expires_at TIMESTAMP,
    password_reset_token_hash TEXT,  -- Use bcrypt hash (timing-attack safe)
    password_reset_token_created_at TIMESTAMP,  -- Track when token was created
    password_reset_expires_at TIMESTAMP,
    
    -- Email Change (pending verification)
    pending_email VARCHAR(255),
    pending_email_code VARCHAR(6),
    pending_email_expires_at TIMESTAMP,
    
    -- Username Change Tracking
    username_changed_at TIMESTAMP,
    
    -- Privacy Settings
    profile_privacy VARCHAR(20) DEFAULT 'public' CHECK (profile_privacy IN ('public', 'private', 'connections')),
    field_visibility JSONB DEFAULT '{
        "location": true,
        "gender": true,
        "age": true,
        "website": true,
        "joined_date": true,
        "email": false
    }'::jsonb,
    stat_visibility JSONB DEFAULT '{
        "posts": true,
        "projects": true,
        "followers": true,
        "following": true,
        "connections": true,
        "collaborators": true
    }'::jsonb,
    
    -- Denormalized Stats (for performance)
    posts_count INTEGER DEFAULT 0,
    projects_count INTEGER DEFAULT 0,
    followers_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    connections_count INTEGER DEFAULT 0,
    collaborators_count INTEGER DEFAULT 0,
    
    -- Trust & Anti-Spam
    account_trust_level INTEGER DEFAULT 0,  -- 0=new, 1=established
    
    -- Account Status
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMP,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- USER SESSIONS TABLE
-- Active login sessions for multi-device support
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    device_info TEXT,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- COMPANIES TABLE
-- For company logos in work experience
-- ============================================================================
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(150) NOT NULL UNIQUE,
    logo_url VARCHAR(500),
    website VARCHAR(255),
    industry VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- USER EXPERIENCES TABLE
-- Work history / employment
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_experiences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    company_name VARCHAR(150) NOT NULL,
    title VARCHAR(150) NOT NULL,
    employment_type VARCHAR(30) CHECK (
        employment_type IS NULL OR 
        employment_type IN ('full-time', 'part-time', 'contract', 'internship', 'freelance', 'self-employed')
    ),
    start_date DATE NOT NULL,
    end_date DATE,
    is_current BOOLEAN DEFAULT FALSE,
    description VARCHAR(200),
    is_public BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT check_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- ============================================================================
-- USER EDUCATION TABLE
-- Education history
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_education (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    school_name VARCHAR(150) NOT NULL,
    degree VARCHAR(150),
    field_of_study VARCHAR(150),
    start_date DATE NOT NULL,
    end_date DATE,
    is_current BOOLEAN DEFAULT FALSE,
    description VARCHAR(200),
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT check_edu_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- ============================================================================
-- USER CERTIFICATIONS TABLE
-- Professional certifications
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_certifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    issuing_organization VARCHAR(150),
    issue_date DATE NOT NULL,
    expiration_date DATE,
    credential_id VARCHAR(100),
    credential_url VARCHAR(500),
    description VARCHAR(200),
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT check_cert_dates CHECK (expiration_date IS NULL OR expiration_date >= issue_date)
);

-- ============================================================================
-- USER SKILLS TABLE
-- Professional skills with proficiency levels
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_skills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_name VARCHAR(100) NOT NULL,
    proficiency_level VARCHAR(20) CHECK (
        proficiency_level IS NULL OR 
        proficiency_level IN ('beginner', 'intermediate', 'advanced', 'expert')
    ),
    category VARCHAR(50),
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- USER LANGUAGES TABLE
-- Language proficiencies
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_languages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    language_name VARCHAR(100) NOT NULL,
    proficiency_level VARCHAR(20) CHECK (
        proficiency_level IS NULL OR 
        proficiency_level IN ('basic', 'conversational', 'fluent', 'native')
    ),
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- USER VOLUNTEERING TABLE
-- Volunteer experience
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_volunteering (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_name VARCHAR(150) NOT NULL,
    role VARCHAR(150) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    is_current BOOLEAN DEFAULT FALSE,
    description VARCHAR(200),
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT check_volunteer_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- ============================================================================
-- USER PUBLICATIONS TABLE
-- Published articles, books, papers
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_publications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(300) NOT NULL,
    publication_type VARCHAR(50),
    publisher VARCHAR(150),
    publication_date DATE,
    publication_url VARCHAR(500),
    description VARCHAR(200),
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- USER INTERESTS TABLE
-- Personal interests and hobbies
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_interests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    interest_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- USER ACHIEVEMENTS TABLE
-- Awards and recognitions
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    achievement_type VARCHAR(50),
    issuing_organization VARCHAR(150),
    achievement_date DATE,
    description VARCHAR(200),
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- INDEXES - Users & Profile
-- ============================================================================
-- FIX: Use email_hash for lookups, not plaintext email (privacy)
CREATE INDEX IF NOT EXISTS idx_users_email_hash ON users(email_hash);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_username_prefix ON users(username varchar_pattern_ops);  -- For ILIKE prefix searches
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id) WHERE google_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_github_id ON users(github_id) WHERE github_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_linkedin_id ON users(linkedin_id) WHERE linkedin_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_email_verification ON users(email_verification_code) WHERE email_verification_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_verified ON users(is_verified);
CREATE INDEX IF NOT EXISTS idx_users_profile_privacy ON users(profile_privacy);
CREATE INDEX IF NOT EXISTS idx_users_trust_level ON users(account_trust_level);
CREATE INDEX IF NOT EXISTS idx_users_followers_count ON users(followers_count DESC);
-- FIX: Use COALESCE in trigram index for NULL handling
CREATE INDEX IF NOT EXISTS idx_users_search_trgm ON users USING GIN ((username || ' ' || COALESCE(display_name, '')) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON user_sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_companies_name ON companies(name);
CREATE INDEX IF NOT EXISTS idx_experiences_user_id ON user_experiences(user_id);
CREATE INDEX IF NOT EXISTS idx_experiences_order ON user_experiences(user_id, display_order DESC);
CREATE INDEX IF NOT EXISTS idx_education_user_id ON user_education(user_id);
CREATE INDEX IF NOT EXISTS idx_education_order ON user_education(user_id, display_order DESC);
CREATE INDEX IF NOT EXISTS idx_certifications_user_id ON user_certifications(user_id);
CREATE INDEX IF NOT EXISTS idx_skills_user_id ON user_skills(user_id);
CREATE INDEX IF NOT EXISTS idx_languages_user_id ON user_languages(user_id);
CREATE INDEX IF NOT EXISTS idx_volunteering_user_id ON user_volunteering(user_id);
CREATE INDEX IF NOT EXISTS idx_publications_user_id ON user_publications(user_id);
CREATE INDEX IF NOT EXISTS idx_interests_user_id ON user_interests(user_id);
CREATE INDEX IF NOT EXISTS idx_achievements_user_id ON user_achievements(user_id);

-- ============================================================================
-- TRIGGERS - Auto-update timestamps
-- ============================================================================
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers first (for idempotency)
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
DROP TRIGGER IF EXISTS update_companies_updated_at ON companies;
DROP TRIGGER IF EXISTS update_experiences_updated_at ON user_experiences;
DROP TRIGGER IF EXISTS update_education_updated_at ON user_education;
DROP TRIGGER IF EXISTS update_certifications_updated_at ON user_certifications;
DROP TRIGGER IF EXISTS update_volunteering_updated_at ON user_volunteering;
DROP TRIGGER IF EXISTS update_publications_updated_at ON user_publications;
DROP TRIGGER IF EXISTS update_achievements_updated_at ON user_achievements;

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_companies_updated_at
    BEFORE UPDATE ON companies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_experiences_updated_at
    BEFORE UPDATE ON user_experiences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_education_updated_at
    BEFORE UPDATE ON user_education
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_certifications_updated_at
    BEFORE UPDATE ON user_certifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_volunteering_updated_at
    BEFORE UPDATE ON user_volunteering
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_publications_updated_at
    BEFORE UPDATE ON user_publications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_achievements_updated_at
    BEFORE UPDATE ON user_achievements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FUNCTIONS - User Utilities
-- ============================================================================

-- Calculate user trust level based on account age, verification, followers
DROP FUNCTION IF EXISTS calculate_trust_level(UUID);
CREATE OR REPLACE FUNCTION calculate_trust_level(user_id_param UUID)
RETURNS INTEGER AS $$
DECLARE
    account_age_days INTEGER;
    is_verified_user BOOLEAN;
    is_email_verified_user BOOLEAN;
    follower_count_val INTEGER;
    trust_level INTEGER := 0;
BEGIN
    SELECT 
        EXTRACT(DAY FROM NOW() - created_at)::INTEGER,
        is_verified,
        is_email_verified,
        followers_count
    INTO 
        account_age_days,
        is_verified_user,
        is_email_verified_user,
        follower_count_val
    FROM users
    WHERE id = user_id_param;
    
    -- Level 1: Verified account OR 30+ day old account with email verified OR 100+ followers
    IF is_verified_user THEN
        trust_level := 1;
    ELSIF account_age_days >= 30 AND is_email_verified_user THEN
        trust_level := 1;
    ELSIF follower_count_val >= 100 THEN
        trust_level := 1;
    END IF;
    
    RETURN trust_level;
END;
$$ LANGUAGE plpgsql;

-- Optimized user search function with early termination
DROP FUNCTION IF EXISTS search_users(TEXT, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION search_users(
    search_query TEXT,
    result_limit INTEGER DEFAULT 20,
    result_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    username VARCHAR,
    display_name VARCHAR,
    profile_picture TEXT,
    is_verified BOOLEAN,
    similarity_score REAL
) AS $$
BEGIN
    -- First try exact username match (fastest)
    RETURN QUERY
    SELECT 
        u.id, u.username, u.display_name, u.profile_picture, u.is_verified,
        1.0::REAL as similarity_score
    FROM users u
    WHERE u.username = search_query AND u.is_active = TRUE
    LIMIT 1;
    IF FOUND THEN RETURN; END IF;
    
    -- Then try prefix match (fast, uses index)
    RETURN QUERY
    SELECT 
        u.id, u.username, u.display_name, u.profile_picture, u.is_verified,
        0.9::REAL as similarity_score
    FROM users u
    WHERE u.is_active = TRUE AND u.username ILIKE search_query || '%'
    ORDER BY u.followers_count DESC
    LIMIT result_limit;
    IF FOUND THEN RETURN; END IF;
    
    -- Finally fuzzy match (slower but comprehensive)
    -- FIX: Use COALESCE to handle NULL display_name
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.display_name,
        u.profile_picture,
        u.is_verified,
        similarity(u.username || ' ' || COALESCE(u.display_name, ''), search_query) as similarity_score
    FROM users u
    WHERE 
        u.is_active = TRUE AND
        (
            u.username ILIKE '%' || search_query || '%' OR
            COALESCE(u.display_name, '') ILIKE '%' || search_query || '%' OR
            similarity(u.username || ' ' || COALESCE(u.display_name, ''), search_query) > 0.2
        )
    ORDER BY 
        u.is_verified DESC,
        similarity_score DESC,
        u.followers_count DESC
    LIMIT result_limit
    OFFSET result_offset;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE users IS 'Core user accounts with authentication, profile, and privacy settings';
COMMENT ON TABLE user_sessions IS 'Active login sessions for multi-device support';
COMMENT ON TABLE companies IS 'Company registry for work experience references';
COMMENT ON TABLE user_experiences IS 'Work history and employment records';
COMMENT ON TABLE user_education IS 'Educational background';
COMMENT ON TABLE user_certifications IS 'Professional certifications and credentials';
COMMENT ON TABLE user_skills IS 'Professional skills with proficiency levels';
COMMENT ON TABLE user_languages IS 'Language proficiencies';
COMMENT ON TABLE user_volunteering IS 'Volunteer experience';
COMMENT ON TABLE user_publications IS 'Published works (articles, books, papers)';
COMMENT ON TABLE user_interests IS 'Personal interests and hobbies';
COMMENT ON TABLE user_achievements IS 'Awards and recognitions';

COMMENT ON COLUMN users.email_hash IS 'SHA-256 hash of lowercase email for lookups (prevents enumeration)';
COMMENT ON COLUMN users.password_reset_token_hash IS 'Bcrypt hash of reset token (timing-attack safe)';
COMMENT ON COLUMN users.account_trust_level IS '0=new user, 1=established (affects rate limits)';
COMMENT ON COLUMN users.stat_visibility IS 'Controls which profile stats are visible (min 3 required)';

-- ============================================================================
-- HELPER FUNCTION: Generate email hash for lookups
-- ============================================================================
DROP FUNCTION IF EXISTS generate_email_hash(TEXT);
CREATE OR REPLACE FUNCTION generate_email_hash(email_input TEXT)
RETURNS VARCHAR(64) AS $$
BEGIN
    RETURN encode(digest(LOWER(TRIM(email_input)), 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

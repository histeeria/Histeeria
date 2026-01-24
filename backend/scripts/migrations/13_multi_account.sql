-- ============================================================================
-- HISTEERIA DATABASE - 13: MULTI-ACCOUNT / ACCOUNT GROUPS
-- ============================================================================
-- Instagram-style multi-profile login/logout
-- Allows users to link multiple accounts and switch between them
-- Run Order: After 01_core_schema.sql (depends on users table)
-- ============================================================================

-- ============================================================================
-- ACCOUNT GROUPS TABLE
-- ============================================================================
-- Represents a group of linked accounts (like Instagram's Accounts Center)
CREATE TABLE IF NOT EXISTS account_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- ACCOUNT GROUP MEMBERS TABLE
-- ============================================================================
-- Many-to-many relationship between account_groups and users
CREATE TABLE IF NOT EXISTS account_group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_group_id UUID NOT NULL REFERENCES account_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT FALSE, -- Which account is the "main" one
    added_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(account_group_id, user_id),
    CONSTRAINT fk_account_group FOREIGN KEY (account_group_id) REFERENCES account_groups(id) ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================================
-- ADD ACCOUNT_GROUP_ID TO USERS TABLE
-- ============================================================================
-- Optional: Quick lookup of which account group a user belongs to
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'account_group_id'
    ) THEN
        ALTER TABLE users ADD COLUMN account_group_id UUID REFERENCES account_groups(id) ON DELETE SET NULL;
    END IF;
END $$;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_account_group_members_group_id 
    ON account_group_members(account_group_id);
CREATE INDEX IF NOT EXISTS idx_account_group_members_user_id 
    ON account_group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_account_group_members_primary 
    ON account_group_members(account_group_id, is_primary) 
    WHERE is_primary = TRUE;
CREATE INDEX IF NOT EXISTS idx_users_account_group_id 
    ON users(account_group_id) 
    WHERE account_group_id IS NOT NULL;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function: Get all accounts in a group
DROP FUNCTION IF EXISTS get_accounts_in_group(UUID) CASCADE;
CREATE OR REPLACE FUNCTION get_accounts_in_group(group_id UUID)
RETURNS TABLE (
    user_id UUID,
    username VARCHAR,
    email VARCHAR,
    display_name VARCHAR,
    profile_picture TEXT,
    is_primary BOOLEAN,
    added_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.email,
        u.display_name,
        u.profile_picture,
        agm.is_primary,
        agm.added_at
    FROM account_group_members agm
    JOIN users u ON agm.user_id = u.id
    WHERE agm.account_group_id = group_id
    ORDER BY agm.is_primary DESC, agm.added_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Function: Get account group for a user
DROP FUNCTION IF EXISTS get_account_group_for_user(UUID) CASCADE;
CREATE OR REPLACE FUNCTION get_account_group_for_user(user_uuid UUID)
RETURNS UUID AS $$
DECLARE
    group_id UUID;
BEGIN
    SELECT account_group_id INTO group_id
    FROM account_group_members
    WHERE user_id = user_uuid
    LIMIT 1;
    
    RETURN group_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Create account group and add first user
DROP FUNCTION IF EXISTS create_account_group_with_user(UUID, BOOLEAN) CASCADE;
CREATE OR REPLACE FUNCTION create_account_group_with_user(
    user_uuid UUID,
    is_primary BOOLEAN DEFAULT TRUE
)
RETURNS UUID AS $$
DECLARE
    new_group_id UUID;
BEGIN
    -- Create new group
    INSERT INTO account_groups DEFAULT VALUES RETURNING id INTO new_group_id;
    
    -- Add user to group
    INSERT INTO account_group_members (account_group_id, user_id, is_primary)
    VALUES (new_group_id, user_uuid, is_primary)
    ON CONFLICT DO NOTHING;
    
    -- Update user's account_group_id
    UPDATE users SET account_group_id = new_group_id WHERE id = user_uuid;
    
    RETURN new_group_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Add user to existing account group
DROP FUNCTION IF EXISTS add_user_to_account_group(UUID, UUID, BOOLEAN) CASCADE;
CREATE OR REPLACE FUNCTION add_user_to_account_group(
    group_uuid UUID,
    user_uuid UUID,
    is_primary BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Add user to group
    INSERT INTO account_group_members (account_group_id, user_id, is_primary)
    VALUES (group_uuid, user_uuid, is_primary)
    ON CONFLICT (account_group_id, user_id) DO NOTHING;
    
    -- Update user's account_group_id
    UPDATE users SET account_group_id = group_uuid WHERE id = user_uuid;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function: Remove user from account group
DROP FUNCTION IF EXISTS remove_user_from_account_group(UUID, UUID) CASCADE;
CREATE OR REPLACE FUNCTION remove_user_from_account_group(
    group_uuid UUID,
    user_uuid UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    member_count INTEGER;
BEGIN
    -- Remove user from group
    DELETE FROM account_group_members 
    WHERE account_group_id = group_uuid AND user_id = user_uuid;
    
    -- Update user's account_group_id
    UPDATE users SET account_group_id = NULL WHERE id = user_uuid;
    
    -- Check if group is now empty
    SELECT COUNT(*) INTO member_count
    FROM account_group_members
    WHERE account_group_id = group_uuid;
    
    -- Delete empty group
    IF member_count = 0 THEN
        DELETE FROM account_groups WHERE id = group_uuid;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function: Set primary account in group
DROP FUNCTION IF EXISTS set_primary_account(UUID, UUID) CASCADE;
CREATE OR REPLACE FUNCTION set_primary_account(
    group_uuid UUID,
    user_uuid UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Unset all primary flags in group
    UPDATE account_group_members 
    SET is_primary = FALSE 
    WHERE account_group_id = group_uuid;
    
    -- Set new primary
    UPDATE account_group_members 
    SET is_primary = TRUE 
    WHERE account_group_id = group_uuid AND user_id = user_uuid;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
DROP TRIGGER IF EXISTS update_account_groups_updated_at ON account_groups;
CREATE TRIGGER update_account_groups_updated_at
    BEFORE UPDATE ON account_groups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- RLS POLICIES (if RLS is enabled)
-- ============================================================================
-- Note: These policies assume RLS is enabled on users table
-- Users can only see accounts in their own account group

-- Enable RLS on account_groups (optional - depends on your security model)
-- ALTER TABLE account_groups ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own account group
-- CREATE POLICY account_groups_select ON account_groups
--     FOR SELECT
--     USING (
--         id IN (
--             SELECT account_group_id FROM account_group_members 
--             WHERE user_id = auth.uid()
--         )
--     );

-- Enable RLS on account_group_members
-- ALTER TABLE account_group_members ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view members of their own account group
-- CREATE POLICY account_group_members_select ON account_group_members
--     FOR SELECT
--     USING (
--         account_group_id IN (
--             SELECT account_group_id FROM account_group_members 
--             WHERE user_id = auth.uid()
--         )
--     );

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE account_groups IS 'Groups of linked accounts (Instagram-style multi-profile)';
COMMENT ON TABLE account_group_members IS 'Many-to-many relationship between account groups and users';
COMMENT ON COLUMN account_group_members.is_primary IS 'Indicates which account is the primary/main account in the group';
COMMENT ON COLUMN users.account_group_id IS 'Quick lookup: which account group this user belongs to';

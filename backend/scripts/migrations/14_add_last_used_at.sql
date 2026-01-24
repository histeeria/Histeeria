-- Migration: Add last_used_at field to users table
-- Purpose: Track when user last used the app (separate from last_login_at)
-- Date: 2025-01-XX

-- Add last_used_at column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMP;

-- Create index for faster queries on last_used_at
CREATE INDEX IF NOT EXISTS idx_users_last_used_at ON users(last_used_at);

-- Update existing users: set last_used_at to last_login_at if last_login_at exists
UPDATE users 
SET last_used_at = last_login_at 
WHERE last_login_at IS NOT NULL AND last_used_at IS NULL;

-- For users without last_login_at, set last_used_at to created_at
UPDATE users 
SET last_used_at = created_at 
WHERE last_used_at IS NULL;

-- Add comment to column
COMMENT ON COLUMN users.last_used_at IS 'Timestamp of when user last used the app (updated on app activity, separate from last_login_at which tracks authentication)';

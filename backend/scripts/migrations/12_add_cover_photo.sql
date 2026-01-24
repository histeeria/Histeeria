-- ============================================================================
-- HISTEERIA DATABASE - 12: ADD COVER PHOTO
-- ============================================================================
-- Adds cover_photo column to users table
-- Run Order: After 01_core_schema.sql
-- ============================================================================

-- Add cover_photo column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS cover_photo TEXT;

-- Add comment for documentation
COMMENT ON COLUMN users.cover_photo IS 'URL to user cover photo stored in Supabase Storage';

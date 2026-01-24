-- ============================================================================
-- HISTEERIA DATABASE - 08: SECURITY (RLS POLICIES)
-- ============================================================================
-- Contains: Row Level Security policies, Permissions, Audit logging
-- Run Order: LAST (after all tables are created)
-- ============================================================================
-- 
-- SECURITY PRINCIPLES:
-- 1. Principle of Least Privilege: Users only access what they need
-- 2. Never use USING (true) for non-admin policies
-- 3. Service role bypasses RLS by default (managed by Supabase)
-- 4. Anonymous users have minimal read-only access
-- 5. All writes require authentication
--
-- ============================================================================

-- ============================================================================
-- ENABLE RLS ON ALL TABLES
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_experiences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_education ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_certifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_languages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_volunteering ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_publications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_interests ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE relationship_rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE spam_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE hashtags ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_hashtags ENABLE ROW LEVEL SECURITY;
ALTER TABLE hashtag_followers ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_mentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE starred_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_edit_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_encryption_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_message_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- REVOKE ALL - START FRESH
-- ============================================================================
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;

-- ============================================================================
-- USERS TABLE POLICIES
-- ============================================================================
-- Public profiles visible to all
CREATE POLICY users_select_public ON users
    FOR SELECT
    USING (
        is_active = TRUE AND
        (profile_privacy = 'public' OR id = auth.uid())
    );

-- Users can update their own profile
CREATE POLICY users_update_own ON users
    FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Registration (service role handles this via backend)
CREATE POLICY users_insert_service ON users
    FOR INSERT
    WITH CHECK (TRUE);  -- Controlled by backend validation

-- ============================================================================
-- USER SESSIONS POLICIES
-- ============================================================================
CREATE POLICY sessions_select_own ON user_sessions
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY sessions_insert_own ON user_sessions
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY sessions_delete_own ON user_sessions
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================================
-- PROFILE EXTENSION TABLES (Experience, Education, etc.)
-- FIX: Allow viewing public profiles, not just own data
-- ============================================================================
-- Companies: Public read, authenticated write
CREATE POLICY companies_select_all ON companies
    FOR SELECT USING (TRUE);

CREATE POLICY companies_insert_auth ON companies
    FOR INSERT TO authenticated
    WITH CHECK (TRUE);

-- FIX: User Profile Tables need separate SELECT (public) and WRITE (own) policies
-- Experiences
CREATE POLICY experiences_select_public ON user_experiences
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        (is_public = TRUE AND EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = user_experiences.user_id 
            AND u.profile_privacy = 'public' AND u.is_active = TRUE
        ))
    );
CREATE POLICY experiences_insert_own ON user_experiences
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY experiences_update_own ON user_experiences
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY experiences_delete_own ON user_experiences
    FOR DELETE USING (user_id = auth.uid());

-- Education
CREATE POLICY education_select_public ON user_education
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = user_education.user_id 
            AND u.profile_privacy = 'public' AND u.is_active = TRUE
        )
    );
CREATE POLICY education_insert_own ON user_education
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY education_update_own ON user_education
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY education_delete_own ON user_education
    FOR DELETE USING (user_id = auth.uid());

-- Certifications
CREATE POLICY certifications_select_public ON user_certifications
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = user_certifications.user_id 
            AND u.profile_privacy = 'public' AND u.is_active = TRUE
        )
    );
CREATE POLICY certifications_insert_own ON user_certifications
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY certifications_update_own ON user_certifications
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY certifications_delete_own ON user_certifications
    FOR DELETE USING (user_id = auth.uid());

-- Skills
CREATE POLICY skills_select_public ON user_skills
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = user_skills.user_id 
            AND u.profile_privacy = 'public' AND u.is_active = TRUE
        )
    );
CREATE POLICY skills_insert_own ON user_skills
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY skills_update_own ON user_skills
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY skills_delete_own ON user_skills
    FOR DELETE USING (user_id = auth.uid());

-- Languages
CREATE POLICY languages_select_public ON user_languages
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = user_languages.user_id 
            AND u.profile_privacy = 'public' AND u.is_active = TRUE
        )
    );
CREATE POLICY languages_insert_own ON user_languages
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY languages_update_own ON user_languages
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY languages_delete_own ON user_languages
    FOR DELETE USING (user_id = auth.uid());

-- Volunteering
CREATE POLICY volunteering_select_public ON user_volunteering
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = user_volunteering.user_id 
            AND u.profile_privacy = 'public' AND u.is_active = TRUE
        )
    );
CREATE POLICY volunteering_insert_own ON user_volunteering
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY volunteering_update_own ON user_volunteering
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY volunteering_delete_own ON user_volunteering
    FOR DELETE USING (user_id = auth.uid());

-- Publications
CREATE POLICY publications_select_public ON user_publications
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = user_publications.user_id 
            AND u.profile_privacy = 'public' AND u.is_active = TRUE
        )
    );
CREATE POLICY publications_insert_own ON user_publications
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY publications_update_own ON user_publications
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY publications_delete_own ON user_publications
    FOR DELETE USING (user_id = auth.uid());

-- Interests
CREATE POLICY interests_select_public ON user_interests
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = user_interests.user_id 
            AND u.profile_privacy = 'public' AND u.is_active = TRUE
        )
    );
CREATE POLICY interests_insert_own ON user_interests
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY interests_update_own ON user_interests
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY interests_delete_own ON user_interests
    FOR DELETE USING (user_id = auth.uid());

-- Achievements
CREATE POLICY achievements_select_public ON user_achievements
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = user_achievements.user_id 
            AND u.profile_privacy = 'public' AND u.is_active = TRUE
        )
    );
CREATE POLICY achievements_insert_own ON user_achievements
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY achievements_update_own ON user_achievements
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY achievements_delete_own ON user_achievements
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================================
-- RELATIONSHIPS POLICIES (SECURE)
-- ============================================================================
-- View relationships you're part of
CREATE POLICY relationships_select_own ON user_relationships
    FOR SELECT
    USING (from_user_id = auth.uid() OR to_user_id = auth.uid());

-- Create relationships from yourself only
CREATE POLICY relationships_insert_own ON user_relationships
    FOR INSERT
    WITH CHECK (from_user_id = auth.uid());

-- Update relationships you're part of
CREATE POLICY relationships_update_own ON user_relationships
    FOR UPDATE
    USING (from_user_id = auth.uid() OR to_user_id = auth.uid());

-- Delete your own initiated relationships
CREATE POLICY relationships_delete_own ON user_relationships
    FOR DELETE
    USING (from_user_id = auth.uid());

-- Rate limits: Own data only
CREATE POLICY rate_limits_select_own ON relationship_rate_limits
    FOR SELECT USING (user_id = auth.uid());

-- Spam flags: Own data only
CREATE POLICY spam_flags_select_own ON spam_flags
    FOR SELECT USING (user_id = auth.uid());

-- ============================================================================
-- POSTS POLICIES
-- ============================================================================
-- View public posts or own posts
CREATE POLICY posts_select_visible ON posts
    FOR SELECT
    USING (
        deleted_at IS NULL AND
        (
            visibility = 'public' OR
            user_id = auth.uid() OR
            (visibility = 'connections' AND EXISTS (
                SELECT 1 FROM user_relationships
                WHERE from_user_id = auth.uid()
                AND to_user_id = posts.user_id
                AND relationship_type = 'following'
                AND status = 'active'
            ))
        )
    );

-- Create own posts
CREATE POLICY posts_insert_own ON posts
    FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Update own posts
CREATE POLICY posts_update_own ON posts
    FOR UPDATE
    USING (user_id = auth.uid());

-- Delete own posts (soft delete)
CREATE POLICY posts_delete_own ON posts
    FOR DELETE
    USING (user_id = auth.uid());

-- ============================================================================
-- POLLS & ARTICLES POLICIES
-- ============================================================================
CREATE POLICY polls_select_visible ON polls
    FOR SELECT
    USING (EXISTS (SELECT 1 FROM posts WHERE posts.id = polls.post_id AND posts.deleted_at IS NULL));

CREATE POLICY polls_insert_own ON polls
    FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM posts WHERE posts.id = polls.post_id AND posts.user_id = auth.uid()));

CREATE POLICY poll_options_select_visible ON poll_options
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM polls p JOIN posts po ON p.post_id = po.id
        WHERE p.id = poll_options.poll_id AND po.deleted_at IS NULL
    ));

CREATE POLICY poll_options_insert_own ON poll_options
    FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM polls p JOIN posts po ON p.post_id = po.id
        WHERE p.id = poll_options.poll_id AND po.user_id = auth.uid()
    ));

CREATE POLICY poll_votes_select_visible ON poll_votes
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        EXISTS (SELECT 1 FROM polls p WHERE p.id = poll_votes.poll_id AND p.anonymous_votes = FALSE)
    );

CREATE POLICY poll_votes_insert_own ON poll_votes
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY poll_votes_update_own ON poll_votes
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY articles_select_visible ON articles
    FOR SELECT
    USING (EXISTS (SELECT 1 FROM posts WHERE posts.id = articles.post_id AND posts.deleted_at IS NULL));

CREATE POLICY articles_insert_own ON articles
    FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM posts WHERE posts.id = articles.post_id AND posts.user_id = auth.uid()));

CREATE POLICY article_tags_select_all ON article_tags FOR SELECT USING (TRUE);

-- ============================================================================
-- HASHTAGS & MENTIONS POLICIES (PUBLIC READ)
-- ============================================================================
CREATE POLICY hashtags_select_all ON hashtags FOR SELECT USING (TRUE);
CREATE POLICY post_hashtags_select_all ON post_hashtags FOR SELECT USING (TRUE);
CREATE POLICY post_mentions_select_all ON post_mentions FOR SELECT USING (TRUE);

CREATE POLICY hashtag_followers_select_all ON hashtag_followers FOR SELECT USING (TRUE);
CREATE POLICY hashtag_followers_insert_own ON hashtag_followers
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY hashtag_followers_delete_own ON hashtag_followers
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================================
-- ENGAGEMENT POLICIES (Likes, Comments, Shares, Saves)
-- ============================================================================
CREATE POLICY post_likes_select_all ON post_likes
    FOR SELECT
    USING (EXISTS (SELECT 1 FROM posts WHERE posts.id = post_likes.post_id AND posts.deleted_at IS NULL));

CREATE POLICY post_likes_insert_own ON post_likes
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY post_likes_delete_own ON post_likes
    FOR DELETE USING (user_id = auth.uid());

CREATE POLICY comments_select_visible ON post_comments
    FOR SELECT
    USING (deleted_at IS NULL AND EXISTS (SELECT 1 FROM posts WHERE posts.id = post_comments.post_id AND posts.deleted_at IS NULL));

CREATE POLICY comments_insert_own ON post_comments
    FOR INSERT
    WITH CHECK (user_id = auth.uid() AND EXISTS (
        SELECT 1 FROM posts WHERE posts.id = post_comments.post_id AND posts.allows_comments = TRUE
    ));

CREATE POLICY comments_update_own ON post_comments
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY comments_delete_own ON post_comments
    FOR DELETE USING (user_id = auth.uid());

CREATE POLICY comment_likes_select_all ON comment_likes
    FOR SELECT
    USING (EXISTS (SELECT 1 FROM post_comments WHERE post_comments.id = comment_likes.comment_id AND post_comments.deleted_at IS NULL));

CREATE POLICY comment_likes_insert_own ON comment_likes
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY comment_likes_delete_own ON comment_likes
    FOR DELETE USING (user_id = auth.uid());

CREATE POLICY post_shares_select_all ON post_shares FOR SELECT USING (TRUE);
CREATE POLICY post_shares_insert_own ON post_shares
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- Saved posts: Private to user
CREATE POLICY saved_posts_select_own ON saved_posts
    FOR SELECT USING (user_id = auth.uid());
CREATE POLICY saved_posts_insert_own ON saved_posts
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY saved_posts_delete_own ON saved_posts
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================================
-- MESSAGING POLICIES (PRIVATE)
-- ============================================================================
CREATE POLICY conversations_select_own ON conversations
    FOR SELECT
    USING (participant1_id = auth.uid() OR participant2_id = auth.uid());

CREATE POLICY conversations_insert_own ON conversations
    FOR INSERT
    WITH CHECK (participant1_id = auth.uid() OR participant2_id = auth.uid());

CREATE POLICY conversations_update_own ON conversations
    FOR UPDATE
    USING (participant1_id = auth.uid() OR participant2_id = auth.uid());

CREATE POLICY messages_select_own ON messages
    FOR SELECT
    USING (conversation_id IN (
        SELECT id FROM conversations WHERE participant1_id = auth.uid() OR participant2_id = auth.uid()
    ));

CREATE POLICY messages_insert_own ON messages
    FOR INSERT
    WITH CHECK (
        sender_id = auth.uid() AND
        conversation_id IN (
            SELECT id FROM conversations WHERE participant1_id = auth.uid() OR participant2_id = auth.uid()
        )
    );

CREATE POLICY messages_update_own ON messages
    FOR UPDATE
    USING (conversation_id IN (
        SELECT id FROM conversations WHERE participant1_id = auth.uid() OR participant2_id = auth.uid()
    ));

CREATE POLICY message_reactions_select_own ON message_reactions
    FOR SELECT
    USING (message_id IN (
        SELECT m.id FROM messages m
        JOIN conversations c ON m.conversation_id = c.id
        WHERE c.participant1_id = auth.uid() OR c.participant2_id = auth.uid()
    ));

CREATE POLICY message_reactions_insert_own ON message_reactions
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY message_reactions_delete_own ON message_reactions
    FOR DELETE USING (user_id = auth.uid());

CREATE POLICY starred_messages_select_own ON starred_messages
    FOR SELECT USING (user_id = auth.uid());
CREATE POLICY starred_messages_insert_own ON starred_messages
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY starred_messages_delete_own ON starred_messages
    FOR DELETE USING (user_id = auth.uid());

CREATE POLICY shared_messages_select_own ON shared_messages
    FOR SELECT
    USING (shared_by = auth.uid() OR message_id IN (SELECT id FROM messages WHERE sender_id = auth.uid()));
CREATE POLICY shared_messages_insert_own ON shared_messages
    FOR INSERT WITH CHECK (shared_by = auth.uid());

CREATE POLICY message_edit_history_select_own ON message_edit_history
    FOR SELECT
    USING (message_id IN (
        SELECT m.id FROM messages m
        JOIN conversations c ON m.conversation_id = c.id
        WHERE c.participant1_id = auth.uid() OR c.participant2_id = auth.uid()
    ));

CREATE POLICY encryption_keys_select_own ON user_encryption_keys
    FOR SELECT USING (user_id = auth.uid());
CREATE POLICY encryption_keys_insert_own ON user_encryption_keys
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- STATUSES POLICIES
-- ============================================================================
CREATE POLICY statuses_select_visible ON statuses
    FOR SELECT
    USING (
        expires_at > NOW() AND
        (
            user_id = auth.uid() OR
            EXISTS (
                SELECT 1 FROM user_relationships
                WHERE from_user_id = auth.uid()
                AND to_user_id = statuses.user_id
                AND relationship_type = 'following'
                AND status = 'active'
            )
        )
    );

CREATE POLICY statuses_insert_own ON statuses
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY statuses_update_own ON statuses
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY statuses_delete_own ON statuses
    FOR DELETE USING (user_id = auth.uid());

-- Status views: Can see views on own statuses, can record view on visible statuses
CREATE POLICY status_views_select_own ON status_views
    FOR SELECT
    USING (EXISTS (SELECT 1 FROM statuses WHERE statuses.id = status_views.status_id AND statuses.user_id = auth.uid()));

CREATE POLICY status_views_insert_own ON status_views
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid() AND
        EXISTS (SELECT 1 FROM statuses WHERE statuses.id = status_id AND expires_at > NOW())
    );

-- Status reactions
CREATE POLICY status_reactions_select_visible ON status_reactions
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM statuses s
        WHERE s.id = status_reactions.status_id
        AND expires_at > NOW()
        AND (s.user_id = auth.uid() OR EXISTS (
            SELECT 1 FROM user_relationships
            WHERE from_user_id = auth.uid() AND to_user_id = s.user_id
            AND relationship_type = 'following' AND status = 'active'
        ))
    ));

CREATE POLICY status_reactions_insert_own ON status_reactions
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY status_reactions_update_own ON status_reactions
    FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY status_reactions_delete_own ON status_reactions
    FOR DELETE USING (user_id = auth.uid());

-- Status comments
CREATE POLICY status_comments_select_visible ON status_comments
    FOR SELECT
    USING (deleted_at IS NULL AND EXISTS (
        SELECT 1 FROM statuses s
        WHERE s.id = status_comments.status_id AND expires_at > NOW()
    ));

CREATE POLICY status_comments_insert_own ON status_comments
    FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY status_comments_update_own ON status_comments
    FOR UPDATE USING (user_id = auth.uid());

-- Status message replies
CREATE POLICY status_message_replies_select_own ON status_message_replies
    FOR SELECT USING (from_user_id = auth.uid() OR to_user_id = auth.uid());
CREATE POLICY status_message_replies_insert_own ON status_message_replies
    FOR INSERT WITH CHECK (from_user_id = auth.uid());

-- ============================================================================
-- NOTIFICATIONS POLICIES (PRIVATE)
-- FIX: Removed dangerous INSERT policy that allowed any user to create notifications
-- ============================================================================
CREATE POLICY notifications_select_own ON notifications
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY notifications_update_own ON notifications
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY notifications_delete_own ON notifications
    FOR DELETE USING (user_id = auth.uid());

-- FIX: REMOVED notifications_insert_service policy
-- Notifications are created by backend via service_role which bypasses RLS
-- NO client-side notification creation allowed (prevents spam injection)

-- Preferences
CREATE POLICY notification_preferences_select_own ON notification_preferences
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY notification_preferences_update_own ON notification_preferences
    FOR UPDATE USING (user_id = auth.uid());

-- FIX: Also removed INSERT for preferences - created by trigger on user creation
-- or via service_role

-- ============================================================================
-- GRANT SPECIFIC PERMISSIONS
-- ============================================================================

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- Anonymous: Limited read access
GRANT SELECT ON users TO anon;
GRANT SELECT ON posts TO anon;
GRANT SELECT ON articles TO anon;
GRANT SELECT ON hashtags TO anon;
GRANT SELECT ON companies TO anon;

-- Authenticated: Full access to their data
GRANT SELECT, INSERT, UPDATE ON users TO authenticated;
GRANT SELECT, INSERT, DELETE ON user_sessions TO authenticated;
GRANT SELECT ON companies TO authenticated;
GRANT INSERT ON companies TO authenticated;
GRANT ALL ON user_experiences TO authenticated;
GRANT ALL ON user_education TO authenticated;
GRANT ALL ON user_certifications TO authenticated;
GRANT ALL ON user_skills TO authenticated;
GRANT ALL ON user_languages TO authenticated;
GRANT ALL ON user_volunteering TO authenticated;
GRANT ALL ON user_publications TO authenticated;
GRANT ALL ON user_interests TO authenticated;
GRANT ALL ON user_achievements TO authenticated;
GRANT ALL ON user_relationships TO authenticated;
GRANT SELECT ON relationship_rate_limits TO authenticated;
GRANT SELECT ON spam_flags TO authenticated;
GRANT ALL ON posts TO authenticated;
GRANT ALL ON polls TO authenticated;
GRANT ALL ON poll_options TO authenticated;
GRANT ALL ON poll_votes TO authenticated;
GRANT ALL ON articles TO authenticated;
GRANT SELECT ON article_tags TO authenticated;
GRANT SELECT ON hashtags TO authenticated;
GRANT SELECT ON post_hashtags TO authenticated;
GRANT ALL ON hashtag_followers TO authenticated;
GRANT SELECT ON post_mentions TO authenticated;
GRANT ALL ON post_likes TO authenticated;
GRANT ALL ON post_comments TO authenticated;
GRANT ALL ON comment_likes TO authenticated;
GRANT ALL ON post_shares TO authenticated;
GRANT ALL ON saved_posts TO authenticated;
GRANT ALL ON conversations TO authenticated;
GRANT ALL ON messages TO authenticated;
GRANT ALL ON message_reactions TO authenticated;
GRANT ALL ON starred_messages TO authenticated;
GRANT ALL ON shared_messages TO authenticated;
GRANT SELECT ON message_edit_history TO authenticated;
GRANT SELECT, INSERT ON user_encryption_keys TO authenticated;
GRANT ALL ON statuses TO authenticated;
GRANT ALL ON status_views TO authenticated;
GRANT ALL ON status_reactions TO authenticated;
GRANT ALL ON status_comments TO authenticated;
GRANT ALL ON status_message_replies TO authenticated;
-- FIX: No INSERT on notifications - backend creates via service_role
GRANT SELECT, UPDATE, DELETE ON notifications TO authenticated;
-- FIX: No INSERT on preferences - created by trigger
GRANT SELECT, UPDATE ON notification_preferences TO authenticated;

-- Grant sequence usage for ID generation
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- AUDIT LOG TABLE (for compliance)
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    target_table VARCHAR(50),
    target_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_target ON audit_log(target_table, target_id);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Admin only can view audit logs (implement admin check based on your needs)
CREATE POLICY audit_log_admin_only ON audit_log
    FOR SELECT
    USING (FALSE);  -- Blocked by default, admin access via service role

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE audit_log IS 'Audit trail for sensitive operations (admin/compliance use)';

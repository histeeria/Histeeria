package repository

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"histeeria-backend/internal/models"
	apperr "histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// min helper function
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// parseFlexibleTime parses timestamps in various formats (with or without timezone)
func parseFlexibleTime(timeStr string) time.Time {
	if timeStr == "" {
		return time.Time{}
	}

	// Try common timestamp formats (order matters - most specific first)
	formats := []string{
		time.RFC3339Nano,                 // "2006-01-02T15:04:05.999999999Z07:00"
		time.RFC3339,                     // "2006-01-02T15:04:05Z07:00"
		"2006-01-02T15:04:05.999999999Z", // "2006-01-02T15:04:05.999999999Z"
		"2006-01-02T15:04:05Z",           // "2006-01-02T15:04:05Z"
		"2006-01-02T15:04:05.999999999",  // "2006-01-02T15:04:05.999999999" (no timezone)
		"2006-01-02T15:04:05.999999",     // "2006-01-02T15:04:05.999999" (no timezone) - matches "2025-10-31T23:05:13.638454"
		"2006-01-02T15:04:05.999",        // "2006-01-02T15:04:05.999" (no timezone)
		"2006-01-02T15:04:05",            // "2006-01-02T15:04:05" (no timezone, no fractional seconds)
	}

	for _, format := range formats {
		if t, err := time.Parse(format, timeStr); err == nil {
			return t
		}
	}

	// Last resort: try parsing without fractional seconds if it contains a dot
	if strings.Contains(timeStr, ".") {
		parts := strings.Split(timeStr, ".")
		if len(parts) == 2 {
			basePart := parts[0] // "2025-10-31T23:05:13"
			if t, err := time.Parse("2006-01-02T15:04:05", basePart); err == nil {
				return t
			}
		}
	}

	// If all fail, return zero time
	log.Printf("[Supabase] parseFlexibleTime - Failed to parse timestamp: %s", timeStr)
	return time.Time{}
}

// SupabaseUserRepository implements UserRepository using Supabase PostgREST.
type SupabaseUserRepository struct {
	baseURL string // e.g. https://<project>.supabase.co/rest/v1
	apiKey  string // service role key
	http    *http.Client
}

func NewSupabaseUserRepository(baseURL, serviceRoleKey string) *SupabaseUserRepository {
	return &SupabaseUserRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseUserRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseUserRepository) usersURL(q url.Values) string {
	u := r.baseURL + "/users"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseUserRepository) CreateUser(ctx context.Context, user *models.User) error {
	// Create a map with all fields including password_hash (which is excluded from JSON by default)
	userData := map[string]interface{}{
		"id":                user.ID.String(),
		"email":             user.Email,
		"email_hash":        user.EmailHash, // SHA-256 hash for privacy-preserving lookups
		"username":          user.Username,
		"password_hash":     user.PasswordHash, // Include password_hash explicitly
		"display_name":      user.DisplayName,
		"age":               user.Age,
		"is_email_verified": user.IsEmailVerified,
		"is_active":         user.IsActive,
		"created_at":        user.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
		"updated_at":        user.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	// Add optional fields if they exist
	if user.EmailVerificationCode != nil {
		userData["email_verification_code"] = *user.EmailVerificationCode
	}
	if user.EmailVerificationExpiresAt != nil {
		userData["email_verification_expires_at"] = user.EmailVerificationExpiresAt.Format("2006-01-02T15:04:05.999999999Z07:00")
	}
	if user.LastLoginAt != nil {
		userData["last_login_at"] = user.LastLoginAt.Format("2006-01-02T15:04:05.999999999Z07:00")
	}
	if user.LastUsedAt != nil {
		userData["last_used_at"] = user.LastUsedAt.Format("2006-01-02T15:04:05.999999999Z07:00")
	}

	// Add OAuth fields if they exist
	if user.GoogleID != nil {
		userData["google_id"] = *user.GoogleID
	}
	if user.GitHubID != nil {
		userData["github_id"] = *user.GitHubID
	}
	if user.LinkedInID != nil {
		userData["linkedin_id"] = *user.LinkedInID
	}
	if user.OAuthProvider != nil {
		userData["oauth_provider"] = *user.OAuthProvider
	}
	if user.ProfilePicture != nil {
		userData["profile_picture"] = *user.ProfilePicture
	}

	body, err := json.Marshal(userData)
	if err != nil {
		log.Printf("[Supabase] CreateUser marshal error: %v", err)
		return fmt.Errorf("%w: marshal error: %v", apperr.ErrDatabaseError, err)
	}

	q := url.Values{}
	q.Set("select", "*")
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.usersURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=representation")
	resp, err := r.http.Do(req)
	if err != nil {
		log.Printf("[Supabase] CreateUser request failed: %v", err)
		return fmt.Errorf("%w: request failed: %v", apperr.ErrDatabaseError, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		errorBody := string(bodyBytes)
		log.Printf("[Supabase] CreateUser failed: HTTP %d - %s", resp.StatusCode, errorBody)

		// Check for unique constraint violations (username or email)
		if strings.Contains(errorBody, "username") && strings.Contains(errorBody, "unique") {
			return apperr.ErrUsernameExists
		}
		if strings.Contains(errorBody, "email") && strings.Contains(errorBody, "unique") {
			return apperr.ErrEmailAlreadyExists
		}

		return fmt.Errorf("%w: HTTP %d - %s", apperr.ErrDatabaseError, resp.StatusCode, errorBody)
	}
	return nil
}

func (r *SupabaseUserRepository) fetchOne(ctx context.Context, q url.Values) (*models.User, error) {
	// Only set select and limit if not already set
	if q.Get("select") == "" {
		q.Set("select", "*")
	}
	if q.Get("limit") == "" {
		q.Set("limit", "1")
	}
	url := r.usersURL(q)
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		log.Printf("[Supabase] fetchOne request failed: %v", err)
		return nil, fmt.Errorf("%w: request failed: %v", apperr.ErrDatabaseError, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return nil, apperr.ErrUserNotFound
	}
	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] fetchOne failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		log.Printf("[Supabase] fetchOne - URL: %s", req.URL.String())
		return nil, fmt.Errorf("%w: HTTP %d - %s", apperr.ErrDatabaseError, resp.StatusCode, string(bodyBytes))
	}
	// Read response body first
	bodyBytes, _ := io.ReadAll(resp.Body)

	// Parse JSON into a flexible structure that handles timestamps
	var rawUsers []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &rawUsers); err != nil {
		log.Printf("[Supabase] fetchOne decode error: %v", err)
		return nil, fmt.Errorf("%w: decode error: %v", apperr.ErrDatabaseError, err)
	}

	if len(rawUsers) == 0 {
		return nil, apperr.ErrUserNotFound
	}

	// Manually convert to User model, handling timestamps
	user := &models.User{}
	rawUser := rawUsers[0]

	if idStr, ok := rawUser["id"].(string); ok {
		if id, err := uuid.Parse(idStr); err == nil {
			user.ID = id
		}
	}
	if email, ok := rawUser["email"].(string); ok {
		user.Email = email
	}
	if username, ok := rawUser["username"].(string); ok {
		user.Username = username
	}
	if passwordHash, ok := rawUser["password_hash"].(string); ok {
		user.PasswordHash = passwordHash
	}
	if displayName, ok := rawUser["display_name"].(string); ok {
		user.DisplayName = displayName
	}
	if age, ok := rawUser["age"].(float64); ok {
		user.Age = int(age)
	}
	if isEmailVerified, ok := rawUser["is_email_verified"].(bool); ok {
		user.IsEmailVerified = isEmailVerified
	}
	if isActive, ok := rawUser["is_active"].(bool); ok {
		user.IsActive = isActive
	}

	// Parse OAuth fields
	if googleID, ok := rawUser["google_id"].(string); ok && googleID != "" {
		user.GoogleID = &googleID
	}
	if githubID, ok := rawUser["github_id"].(string); ok && githubID != "" {
		user.GitHubID = &githubID
	}
	if linkedinID, ok := rawUser["linkedin_id"].(string); ok && linkedinID != "" {
		user.LinkedInID = &linkedinID
	}

	// Parse pending email change fields
	if pendingEmail, ok := rawUser["pending_email"].(string); ok && pendingEmail != "" {
		user.PendingEmail = &pendingEmail
	}
	if pendingEmailCode, ok := rawUser["pending_email_code"].(string); ok && pendingEmailCode != "" {
		user.PendingEmailCode = &pendingEmailCode
	}
	if pendingEmailExpiresAtStr, ok := rawUser["pending_email_expires_at"].(string); ok && pendingEmailExpiresAtStr != "" {
		t := parseFlexibleTime(pendingEmailExpiresAtStr)
		if !t.IsZero() {
			user.PendingEmailExpiresAt = &t
		}
	}
	if oauthProvider, ok := rawUser["oauth_provider"].(string); ok && oauthProvider != "" {
		user.OAuthProvider = &oauthProvider
	}
	if profilePicture, ok := rawUser["profile_picture"].(string); ok && profilePicture != "" {
		user.ProfilePicture = &profilePicture
	}
	if coverPhoto, ok := rawUser["cover_photo"].(string); ok && coverPhoto != "" {
		user.CoverPhoto = &coverPhoto
	}

	// Parse Profile System Phase 1 fields
	if bio, ok := rawUser["bio"].(string); ok && bio != "" {
		user.Bio = &bio
	}
	if location, ok := rawUser["location"].(string); ok && location != "" {
		user.Location = &location
	}
	if gender, ok := rawUser["gender"].(string); ok && gender != "" {
		user.Gender = &gender
	}
	if genderCustom, ok := rawUser["gender_custom"].(string); ok && genderCustom != "" {
		user.GenderCustom = &genderCustom
	}
	if website, ok := rawUser["website"].(string); ok && website != "" {
		user.Website = &website
	}
	if isVerified, ok := rawUser["is_verified"].(bool); ok {
		user.IsVerified = isVerified
	}
	if profilePrivacy, ok := rawUser["profile_privacy"].(string); ok {
		user.ProfilePrivacy = profilePrivacy
	} else {
		user.ProfilePrivacy = "public" // default
	}
	if fieldVisibilityRaw, ok := rawUser["field_visibility"].(map[string]interface{}); ok {
		fieldVisibility := make(map[string]bool)
		for k, v := range fieldVisibilityRaw {
			if boolVal, ok := v.(bool); ok {
				fieldVisibility[k] = boolVal
			}
		}
		user.FieldVisibility = fieldVisibility
	}
	if statVisibilityRaw, ok := rawUser["stat_visibility"].(map[string]interface{}); ok {
		statVisibility := make(map[string]bool)
		for k, v := range statVisibilityRaw {
			if boolVal, ok := v.(bool); ok {
				statVisibility[k] = boolVal
			}
		}
		user.StatVisibility = statVisibility
	}
	if socialLinksRaw, ok := rawUser["social_links"].(map[string]interface{}); ok {
		socialLinks := make(map[string]*string)
		for k, v := range socialLinksRaw {
			if v == nil {
				socialLinks[k] = nil
			} else if strVal, ok := v.(string); ok && strVal != "" {
				socialLinks[k] = &strVal
			} else {
				socialLinks[k] = nil
			}
		}
		user.SocialLinks = socialLinks
	}
	if story, ok := rawUser["story"].(string); ok && story != "" {
		user.Story = &story
	}
	if ambition, ok := rawUser["ambition"].(string); ok && ambition != "" {
		user.Ambition = &ambition
	}
	if postsCount, ok := rawUser["posts_count"].(float64); ok {
		user.PostsCount = int(postsCount)
	}
	if projectsCount, ok := rawUser["projects_count"].(float64); ok {
		user.ProjectsCount = int(projectsCount)
	}
	if followersCount, ok := rawUser["followers_count"].(float64); ok {
		user.FollowersCount = int(followersCount)
	}
	if followingCount, ok := rawUser["following_count"].(float64); ok {
		user.FollowingCount = int(followingCount)
	}

	// Parse timestamps with flexible format
	if createdAtStr, ok := rawUser["created_at"].(string); ok {
		if t := parseFlexibleTime(createdAtStr); !t.IsZero() {
			user.CreatedAt = t
		}
	}
	if updatedAtStr, ok := rawUser["updated_at"].(string); ok {
		if t := parseFlexibleTime(updatedAtStr); !t.IsZero() {
			user.UpdatedAt = t
		}
	}
	if lastLoginAtStr, ok := rawUser["last_login_at"].(string); ok && lastLoginAtStr != "" {
		t := parseFlexibleTime(lastLoginAtStr)
		if !t.IsZero() {
			user.LastLoginAt = &t
		}
	}
	if lastUsedAtStr, ok := rawUser["last_used_at"].(string); ok && lastUsedAtStr != "" {
		t := parseFlexibleTime(lastUsedAtStr)
		if !t.IsZero() {
			user.LastUsedAt = &t
		}
	}

	var users []models.User
	users = append(users, *user)
	if len(users) == 0 {
		return nil, apperr.ErrUserNotFound
	}
	return &users[0], nil
}

func (r *SupabaseUserRepository) GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	q := url.Values{}
	q.Set("id", "eq."+id.String())
	return r.fetchOne(ctx, q)
}

func (r *SupabaseUserRepository) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	q := url.Values{}
	q.Set("email", "eq."+email)
	return r.fetchOne(ctx, q)
}

func (r *SupabaseUserRepository) GetUserByUsername(ctx context.Context, username string) (*models.User, error) {
	q := url.Values{}
	q.Set("username", "eq."+username)
	return r.fetchOne(ctx, q)
}

func (r *SupabaseUserRepository) GetUserByEmailOrUsername(ctx context.Context, emailOrUsername string) (*models.User, error) {
	q := url.Values{}
	q.Set("or", fmt.Sprintf("(email.eq.%s,username.eq.%s)", emailOrUsername, emailOrUsername))
	return r.fetchOne(ctx, q)
}

func (r *SupabaseUserRepository) GetUserByGoogleID(ctx context.Context, googleID string) (*models.User, error) {
	q := url.Values{}
	q.Set("google_id", "eq."+googleID)
	return r.fetchOne(ctx, q)
}

func (r *SupabaseUserRepository) GetUserByGitHubID(ctx context.Context, githubID string) (*models.User, error) {
	q := url.Values{}
	q.Set("github_id", "eq."+githubID)
	return r.fetchOne(ctx, q)
}

func (r *SupabaseUserRepository) GetUserByLinkedInID(ctx context.Context, linkedinID string) (*models.User, error) {
	q := url.Values{}
	q.Set("linkedin_id", "eq."+linkedinID)
	return r.fetchOne(ctx, q)
}

func (r *SupabaseUserRepository) UpdateUser(ctx context.Context, user *models.User) error {
	body, _ := json.Marshal(user)
	q := url.Values{}
	q.Set("id", "eq."+user.ID.String())
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")
	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabaseUserRepository) UpdateEmailVerification(ctx context.Context, email, code string, expiresAt time.Time) error {
	update := map[string]interface{}{
		"email_verification_code":       code,
		"email_verification_expires_at": expiresAt,
		"updated_at":                    time.Now(),
	}
	body, _ := json.Marshal(update)
	q := url.Values{}
	q.Set("email", "eq."+email)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")
	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabaseUserRepository) VerifyEmail(ctx context.Context, email, code string) error {
	// Fetch user directly with only needed fields to avoid RLS issues
	q := url.Values{}
	q.Set("email", "eq."+email)
	q.Set("select", "id,email,email_verification_code,email_verification_expires_at,is_email_verified")
	q.Set("limit", "1")

	fetchReq, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.usersURL(q), nil)
	r.setHeaders(fetchReq, "")
	fetchResp, err := r.http.Do(fetchReq)
	if err != nil {
		log.Printf("[Supabase] VerifyEmail - Failed to fetch user: %v", err)
		return fmt.Errorf("%w: failed to fetch user: %v", apperr.ErrInvalidVerificationCode, err)
	}
	defer fetchResp.Body.Close()

	if fetchResp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(fetchResp.Body)
		log.Printf("[Supabase] VerifyEmail - Fetch user failed: HTTP %d - %s", fetchResp.StatusCode, string(bodyBytes))
		return fmt.Errorf("%w: user fetch failed: HTTP %d", apperr.ErrInvalidVerificationCode, fetchResp.StatusCode)
	}

	// Read raw response
	bodyBytes, _ := io.ReadAll(fetchResp.Body)

	// First, decode to a temporary struct to get the verification code
	// (since EmailVerificationCode has json:"-" tag)
	type tempUser struct {
		ID                         string  `json:"id"`
		Email                      string  `json:"email"`
		EmailVerificationCode      *string `json:"email_verification_code"`
		EmailVerificationExpiresAt *string `json:"email_verification_expires_at"` // Parse as string first
		IsEmailVerified            bool    `json:"is_email_verified"`
	}

	var tempUsers []tempUser
	if err := json.Unmarshal(bodyBytes, &tempUsers); err != nil {
		log.Printf("[Supabase] VerifyEmail - Failed to decode temp user: %v", err)
		return fmt.Errorf("%w: failed to decode user", apperr.ErrInvalidVerificationCode)
	}

	if len(tempUsers) == 0 {
		return apperr.ErrUserNotFound
	}

	tempUserData := tempUsers[0]

	// Check if code matches
	if tempUserData.EmailVerificationCode == nil {
		return apperr.ErrInvalidVerificationCode
	}

	// Parse expiry time if it exists
	var expiresAt *time.Time
	if tempUserData.EmailVerificationExpiresAt != nil && *tempUserData.EmailVerificationExpiresAt != "" {
		parsed, err := time.Parse(time.RFC3339, *tempUserData.EmailVerificationExpiresAt)
		if err == nil {
			expiresAt = &parsed
		}
	}

	// Check if code matches
	if *tempUserData.EmailVerificationCode != code {
		return apperr.ErrInvalidVerificationCode
	}

	// Check if code has expired
	if expiresAt != nil && time.Now().After(*expiresAt) {
		return apperr.ErrInvalidVerificationCode
	}

	// Now get the user ID as UUID
	userID, err := uuid.Parse(tempUserData.ID)
	if err != nil {
		return fmt.Errorf("%w: invalid user ID", apperr.ErrInvalidVerificationCode)
	}

	// Code is valid, update the user by ID (more reliable than filtering)
	update := map[string]interface{}{
		"is_email_verified":             true,
		"email_verification_code":       nil,
		"email_verification_expires_at": nil,
		"updated_at":                    time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	body, err := json.Marshal(update)
	if err != nil {
		log.Printf("[Supabase] VerifyEmail marshal error: %v", err)
		return fmt.Errorf("%w: marshal error: %v", apperr.ErrInvalidVerificationCode, err)
	}

	// Update by ID instead of filtering
	q2 := url.Values{}
	q2.Set("id", "eq."+userID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q2), bytes.NewReader(body))
	r.setHeaders(req, "return=representation")
	resp, err := r.http.Do(req)
	if err != nil {
		log.Printf("[Supabase] VerifyEmail request failed: %v", err)
		return fmt.Errorf("%w: request failed: %v", apperr.ErrInvalidVerificationCode, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		errorBodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] VerifyEmail failed: HTTP %d - %s", resp.StatusCode, string(errorBodyBytes))
		return fmt.Errorf("%w: HTTP %d - %s", apperr.ErrInvalidVerificationCode, resp.StatusCode, string(errorBodyBytes))
	}

	// Update succeeded (HTTP 200)
	// Response body can be ignored since update was successful

	return nil
}

func (r *SupabaseUserRepository) UpdatePasswordReset(ctx context.Context, email, token string, expiresAt time.Time) error {
	update := map[string]interface{}{
		"password_reset_token":      token,
		"password_reset_expires_at": expiresAt,
		"updated_at":                time.Now(),
	}
	body, _ := json.Marshal(update)
	q := url.Values{}
	q.Set("email", "eq."+email)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")
	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabaseUserRepository) ResetPassword(ctx context.Context, token, newPasswordHash string) error {
	update := map[string]interface{}{
		"password_hash":             newPasswordHash,
		"password_reset_token":      nil,
		"password_reset_expires_at": nil,
		"updated_at":                time.Now(),
	}
	body, _ := json.Marshal(update)
	q := url.Values{}
	q.Set("password_reset_token", "eq."+token)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")
	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrInvalidResetToken
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return apperr.ErrInvalidResetToken
	}
	return nil
}

func (r *SupabaseUserRepository) UpdateLastLogin(ctx context.Context, userID uuid.UUID) error {
	update := map[string]interface{}{
		"last_login_at": time.Now(),
		"updated_at":    time.Now(),
	}
	body, _ := json.Marshal(update)
	q := url.Values{}
	q.Set("id", "eq."+userID.String())
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")
	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabaseUserRepository) UpdateLastUsed(ctx context.Context, userID uuid.UUID) error {
	update := map[string]interface{}{
		"last_used_at": time.Now(),
		"updated_at":   time.Now(),
	}
	body, _ := json.Marshal(update)
	q := url.Values{}
	q.Set("id", "eq."+userID.String())
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")
	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabaseUserRepository) CheckEmailExists(ctx context.Context, email string) (bool, error) {
	q := url.Values{}
	q.Set("select", "id")
	q.Set("email", "eq."+email)
	q.Set("limit", "1")
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.usersURL(q), nil)
	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		log.Printf("[Supabase] CheckEmailExists request failed: %v", err)
		return false, fmt.Errorf("%w: request failed: %v", apperr.ErrDatabaseError, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CheckEmailExists failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return false, fmt.Errorf("%w: HTTP %d - %s", apperr.ErrDatabaseError, resp.StatusCode, string(bodyBytes))
	}
	var users []models.User
	if err := json.NewDecoder(resp.Body).Decode(&users); err != nil {
		return false, apperr.ErrDatabaseError
	}
	return len(users) > 0, nil
}

func (r *SupabaseUserRepository) CheckUsernameExists(ctx context.Context, username string) (bool, error) {
	q := url.Values{}
	q.Set("select", "id")
	q.Set("username", "eq."+username)
	q.Set("limit", "1")
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.usersURL(q), nil)
	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		log.Printf("[Supabase] CheckUsernameExists request failed: %v", err)
		return false, fmt.Errorf("%w: request failed: %v", apperr.ErrDatabaseError, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CheckUsernameExists failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return false, fmt.Errorf("%w: HTTP %d - %s", apperr.ErrDatabaseError, resp.StatusCode, string(bodyBytes))
	}
	var users []models.User
	if err := json.NewDecoder(resp.Body).Decode(&users); err != nil {
		return false, apperr.ErrDatabaseError
	}
	return len(users) > 0, nil
}

// UpdateProfile updates user profile fields
func (r *SupabaseUserRepository) UpdateProfile(ctx context.Context, userID uuid.UUID, updates map[string]interface{}) error {
	// Always update the updated_at timestamp
	updates["updated_at"] = time.Now()

	body, err := json.Marshal(updates)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateProfile failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// UpdatePassword updates user's password hash
func (r *SupabaseUserRepository) UpdatePassword(ctx context.Context, userID uuid.UUID, newPasswordHash string) error {
	update := map[string]interface{}{
		"password_hash": newPasswordHash,
		"updated_at":    time.Now(),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdatePassword failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// DeleteUser permanently deletes a user account
func (r *SupabaseUserRepository) DeleteUser(ctx context.Context, userID uuid.UUID) error {
	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, r.usersURL(q), nil)
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] DeleteUser failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// InitiateEmailChange stores pending email change request
func (r *SupabaseUserRepository) InitiateEmailChange(ctx context.Context, userID uuid.UUID, newEmail, code string, expiresAt time.Time) error {
	update := map[string]interface{}{
		"pending_email":            newEmail,
		"pending_email_code":       code,
		"pending_email_expires_at": expiresAt,
		"updated_at":               time.Now(),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] InitiateEmailChange failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// VerifyEmailChange completes the email change process
func (r *SupabaseUserRepository) VerifyEmailChange(ctx context.Context, userID uuid.UUID, code string) error {
	// First, fetch user to validate code
	user, err := r.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}

	// Validate pending email exists
	if user.PendingEmail == nil || *user.PendingEmail == "" {
		return apperr.NewAppError(400, "No pending email change request found")
	}

	// Validate code
	if user.PendingEmailCode == nil || *user.PendingEmailCode != code {
		return apperr.NewAppError(400, "Invalid verification code")
	}

	// Check expiration
	if user.PendingEmailExpiresAt == nil || time.Now().After(*user.PendingEmailExpiresAt) {
		return apperr.NewAppError(400, "Verification code has expired")
	}

	// Update email and clear pending fields
	update := map[string]interface{}{
		"email":                    *user.PendingEmail,
		"pending_email":            nil,
		"pending_email_code":       nil,
		"pending_email_expires_at": nil,
		"updated_at":               time.Now(),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] VerifyEmailChange failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// ChangeUsername updates the username with tracking
func (r *SupabaseUserRepository) ChangeUsername(ctx context.Context, userID uuid.UUID, newUsername string) error {
	update := map[string]interface{}{
		"username":            newUsername,
		"username_changed_at": time.Now(),
		"updated_at":          time.Now(),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] ChangeUsername failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// DeactivateAccount soft deletes the account
func (r *SupabaseUserRepository) DeactivateAccount(ctx context.Context, userID uuid.UUID) error {
	update := map[string]interface{}{
		"is_active":  false,
		"updated_at": time.Now(),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] DeactivateAccount failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// UpdateBasicProfile updates basic profile information
func (r *SupabaseUserRepository) UpdateBasicProfile(ctx context.Context, userID uuid.UUID, req *models.UpdateBasicProfileRequest) error {
	update := make(map[string]interface{})

	if req.DisplayName != nil {
		update["display_name"] = *req.DisplayName
	}
	if req.Bio != nil {
		update["bio"] = *req.Bio
	}
	if req.Location != nil {
		update["location"] = *req.Location
	}
	if req.Gender != nil {
		update["gender"] = *req.Gender
	}
	if req.GenderCustom != nil {
		update["gender_custom"] = *req.GenderCustom
	}
	if req.Age != nil {
		update["age"] = *req.Age
	}
	if req.Website != nil {
		update["website"] = *req.Website
	}

	update["updated_at"] = time.Now().Format("2006-01-02T15:04:05.999999999Z07:00")

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(httpReq, "return=minimal")

	resp, err := r.http.Do(httpReq)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateBasicProfile failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// UpdatePrivacySettings updates user privacy settings
func (r *SupabaseUserRepository) UpdatePrivacySettings(ctx context.Context, userID uuid.UUID, req *models.UpdatePrivacySettingsRequest) error {
	update := map[string]interface{}{
		"profile_privacy":  req.ProfilePrivacy,
		"field_visibility": req.FieldVisibility,
		"updated_at":       time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(httpReq, "return=minimal")

	resp, err := r.http.Do(httpReq)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdatePrivacySettings failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// UpdateStory updates the user's story section
func (r *SupabaseUserRepository) UpdateStory(ctx context.Context, userID uuid.UUID, story *string) error {
	update := map[string]interface{}{
		"story":      story,
		"updated_at": time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(httpReq, "return=minimal")

	resp, err := r.http.Do(httpReq)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateStory failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// UpdateAmbition updates the user's ambition section
func (r *SupabaseUserRepository) UpdateAmbition(ctx context.Context, userID uuid.UUID, ambition *string) error {
	update := map[string]interface{}{
		"ambition":   ambition,
		"updated_at": time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(httpReq, "return=minimal")

	resp, err := r.http.Do(httpReq)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateAmbition failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// UpdateSocialLinks updates user's social media links
func (r *SupabaseUserRepository) UpdateSocialLinks(ctx context.Context, userID uuid.UUID, socialLinks map[string]*string) error {
	// Supabase PostgREST expects JSONB as a JSON object, not a string
	update := map[string]interface{}{
		"social_links": socialLinks, // Pass directly, not as string
		"updated_at":   time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(httpReq, "return=minimal")

	resp, err := r.http.Do(httpReq)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateSocialLinks failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// UpdateStatVisibility updates which stats are visible on user's profile
func (r *SupabaseUserRepository) UpdateStatVisibility(ctx context.Context, userID uuid.UUID, statVisibility map[string]bool) error {
	// Supabase PostgREST expects JSONB as a JSON object, not a string
	update := map[string]interface{}{
		"stat_visibility": statVisibility, // Pass directly, not as string
		"updated_at":      time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(httpReq, "return=minimal")

	resp, err := r.http.Do(httpReq)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateStatVisibility failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// SearchUsers searches for users by query string
func (r *SupabaseUserRepository) SearchUsers(ctx context.Context, query string, limit int, offset int) ([]*models.User, int, error) {
	// Build search query - search in username, display_name, bio, location
	// Exclude private profiles from search results
	
	log.Printf("[Supabase] SearchUsers called with query: '%s', limit: %d, offset: %d", query, limit, offset)

	q := url.Values{}
	q.Set("select", "*")
	// Simple username or display_name search - use * for wildcard in PostgREST
	// ilike is case-insensitive LIKE in PostgreSQL
	q.Set("or", fmt.Sprintf("(username.ilike.*%s*,display_name.ilike.*%s*)", query, query))
	// Removed is_active filter - show all users
	q.Set("limit", fmt.Sprintf("%d", limit))
	q.Set("offset", fmt.Sprintf("%d", offset))
	q.Set("order", "is_verified.desc,followers_count.desc") // Sort by verified first, then popularity

	url := r.usersURL(q)
	log.Printf("[Supabase] SearchUsers URL: %s", url)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		log.Printf("[Supabase] SearchUsers failed to create request: %v", err)
		return nil, 0, apperr.ErrInternalServer
	}

	r.setHeaders(req, "count=exact")

	resp, err := r.http.Do(req)
	if err != nil {
		log.Printf("[Supabase] SearchUsers HTTP request failed: %v", err)
		return nil, 0, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	// Read response body first
	bodyBytes, _ := io.ReadAll(resp.Body)

	if resp.StatusCode >= 300 {
		log.Printf("[Supabase] SearchUsers failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return nil, 0, apperr.ErrDatabaseError
	}
	
	log.Printf("[Supabase] SearchUsers response: %s", string(bodyBytes))

	// Get total count from Content-Range header
	totalCount := 0
	if contentRange := resp.Header.Get("Content-Range"); contentRange != "" {
		// Format: "0-1/2" or "*/2"
		var start, end int
		if n, _ := fmt.Sscanf(contentRange, "%d-%d/%d", &start, &end, &totalCount); n == 3 {
			// Successfully parsed range format
			log.Printf("[Supabase] SearchUsers Content-Range: %s, parsed total: %d", contentRange, totalCount)
		} else if n, _ := fmt.Sscanf(contentRange, "*/%d", &totalCount); n == 1 {
			// Successfully parsed unknown range format
			log.Printf("[Supabase] SearchUsers Content-Range: %s, parsed total: %d", contentRange, totalCount)
		} else {
			log.Printf("[Supabase] SearchUsers failed to parse Content-Range: %s", contentRange)
		}
	} else {
		log.Printf("[Supabase] SearchUsers no Content-Range header found")
	}

	// Parse as array of raw users
	var rawUsers []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &rawUsers); err != nil {
		log.Printf("[Supabase] SearchUsers decode error: %v", err)
		return nil, 0, apperr.ErrDatabaseError
	}

	log.Printf("[Supabase] SearchUsers found %d users in response", len(rawUsers))

	// Convert each raw user to User model (simplified)
	users := make([]*models.User, 0, len(rawUsers))
	for _, rawUser := range rawUsers {
		user := &models.User{}

		// Parse basic fields
		if idStr, ok := rawUser["id"].(string); ok {
			if id, err := uuid.Parse(idStr); err == nil {
				user.ID = id
			}
		}
		if email, ok := rawUser["email"].(string); ok {
			user.Email = email
		}
		if username, ok := rawUser["username"].(string); ok {
			user.Username = username
		}
		if displayName, ok := rawUser["display_name"].(string); ok {
			user.DisplayName = displayName
		}
		if profilePicture, ok := rawUser["profile_picture"].(string); ok && profilePicture != "" {
			user.ProfilePicture = &profilePicture
		}
		if coverPhoto, ok := rawUser["cover_photo"].(string); ok && coverPhoto != "" {
			user.CoverPhoto = &coverPhoto
		}
		if bio, ok := rawUser["bio"].(string); ok && bio != "" {
			user.Bio = &bio
		}
		if location, ok := rawUser["location"].(string); ok && location != "" {
			user.Location = &location
		}
		if isVerified, ok := rawUser["is_verified"].(bool); ok {
			user.IsVerified = isVerified
		}
		if profilePrivacy, ok := rawUser["profile_privacy"].(string); ok {
			user.ProfilePrivacy = profilePrivacy
		}
		if followersCount, ok := rawUser["followers_count"].(float64); ok {
			user.FollowersCount = int(followersCount)
		}
		if followingCount, ok := rawUser["following_count"].(float64); ok {
			user.FollowingCount = int(followingCount)
		}

		users = append(users, user)
	}

	return users, totalCount, nil
}

// IncrementFollowerCount increments the followers_count for a user
func (r *SupabaseUserRepository) IncrementFollowerCount(ctx context.Context, userID uuid.UUID) error {
	log.Printf("[IncrementFollowerCount] Starting for user %s", userID)

	// Get current user
	user, err := r.GetUserByID(ctx, userID)
	if err != nil {
		log.Printf("[IncrementFollowerCount] GetUserByID FAILED: %v", err)
		return err
	}
	log.Printf("[IncrementFollowerCount] Current followers_count: %d", user.FollowersCount)

	// Increment count
	update := map[string]interface{}{
		"followers_count": user.FollowersCount + 1,
		"updated_at":      time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}
	log.Printf("[IncrementFollowerCount] Updating to: %d", user.FollowersCount+1)

	err = r.updateUserFields(ctx, userID, update)
	if err != nil {
		log.Printf("[IncrementFollowerCount] updateUserFields FAILED: %v", err)
		return err
	}

	log.Printf("[IncrementFollowerCount] Successfully updated followers_count")
	return nil
}

// DecrementFollowerCount decrements the followers_count for a user
func (r *SupabaseUserRepository) DecrementFollowerCount(ctx context.Context, userID uuid.UUID) error {
	// Get current user
	user, err := r.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}

	// Decrement count (don't go below 0)
	newCount := user.FollowersCount - 1
	if newCount < 0 {
		newCount = 0
	}

	update := map[string]interface{}{
		"followers_count": newCount,
		"updated_at":      time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	return r.updateUserFields(ctx, userID, update)
}

// IncrementFollowingCount increments the following_count for a user
func (r *SupabaseUserRepository) IncrementFollowingCount(ctx context.Context, userID uuid.UUID) error {
	log.Printf("[IncrementFollowingCount] Starting for user %s", userID)

	// Get current user
	user, err := r.GetUserByID(ctx, userID)
	if err != nil {
		log.Printf("[IncrementFollowingCount] GetUserByID FAILED: %v", err)
		return err
	}
	log.Printf("[IncrementFollowingCount] Current following_count: %d", user.FollowingCount)

	// Increment count
	update := map[string]interface{}{
		"following_count": user.FollowingCount + 1,
		"updated_at":      time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}
	log.Printf("[IncrementFollowingCount] Updating to: %d", user.FollowingCount+1)

	err = r.updateUserFields(ctx, userID, update)
	if err != nil {
		log.Printf("[IncrementFollowingCount] updateUserFields FAILED: %v", err)
		return err
	}

	log.Printf("[IncrementFollowingCount] Successfully updated following_count")
	return nil
}

// DecrementFollowingCount decrements the following_count for a user
func (r *SupabaseUserRepository) DecrementFollowingCount(ctx context.Context, userID uuid.UUID) error {
	// Get current user
	user, err := r.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}

	// Decrement count (don't go below 0)
	newCount := user.FollowingCount - 1
	if newCount < 0 {
		newCount = 0
	}

	update := map[string]interface{}{
		"following_count": newCount,
		"updated_at":      time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	return r.updateUserFields(ctx, userID, update)
}

// Helper function to update user fields
// GetNewUsersCountSince returns the count of new users created since the given time
func (r *SupabaseUserRepository) GetNewUsersCountSince(ctx context.Context, since time.Time) (int, error) {
	q := url.Values{}
	sinceStr := since.Format(time.RFC3339)
	q.Set("created_at", "gte."+sinceStr)
	q.Set("select", "id")
	q.Set("is_active", "eq.true")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.usersURL(q), nil)
	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return 0, fmt.Errorf("%w: request failed: %v", apperr.ErrDatabaseError, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("%w: HTTP %d - %s", apperr.ErrDatabaseError, resp.StatusCode, string(bodyBytes))
	}

	var users []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&users); err != nil {
		return 0, fmt.Errorf("%w: decode error: %v", apperr.ErrDatabaseError, err)
	}

	return len(users), nil
}

func (r *SupabaseUserRepository) updateUserFields(ctx context.Context, userID uuid.UUID, fields map[string]interface{}) error {
	body, err := json.Marshal(fields)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+userID.String())

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.usersURL(q), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(httpReq, "return=minimal")

	resp, err := r.http.Do(httpReq)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] updateUserFields failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// BlockUser blocks a user (complete barrier - no messaging, content hidden)
func (r *SupabaseUserRepository) BlockUser(ctx context.Context, blockerID, blockedID uuid.UUID) error {
	payload := map[string]interface{}{
		"blocker_id": blockerID.String(),
		"blocked_id": blockedID.String(),
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal block request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.baseURL+"/blocked_users", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return fmt.Errorf("failed to block user: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		// Check if it's a unique constraint violation (already blocked)
		if strings.Contains(string(bodyBytes), "duplicate") || strings.Contains(string(bodyBytes), "unique") {
			return nil // Already blocked, no error
		}
		return fmt.Errorf("failed to block user: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// UnblockUser unblocks a user
func (r *SupabaseUserRepository) UnblockUser(ctx context.Context, blockerID, blockedID uuid.UUID) error {
	q := url.Values{}
	q.Set("blocker_id", "eq."+blockerID.String())
	q.Set("blocked_id", "eq."+blockedID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, r.baseURL+"/blocked_users?"+q.Encode(), nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return fmt.Errorf("failed to unblock user: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 && resp.StatusCode != 404 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to unblock user: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// IsUserBlocked checks if a user is blocked by another user
func (r *SupabaseUserRepository) IsUserBlocked(ctx context.Context, blockerID, blockedID uuid.UUID) (bool, error) {
	q := url.Values{}
	q.Set("blocker_id", "eq."+blockerID.String())
	q.Set("blocked_id", "eq."+blockedID.String())
	q.Set("select", "id")

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.baseURL+"/blocked_users?"+q.Encode(), nil)
	if err != nil {
		return false, fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return false, fmt.Errorf("failed to check block status: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return false, fmt.Errorf("failed to check block status: HTTP %d", resp.StatusCode)
	}

	var results []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return false, fmt.Errorf("failed to parse block check response: %w", err)
	}

	return len(results) > 0, nil
}

// GetBlockedUserIDs gets all user IDs that a user has blocked
func (r *SupabaseUserRepository) GetBlockedUserIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	q := url.Values{}
	q.Set("blocker_id", "eq."+userID.String())
	q.Set("select", "blocked_id")

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.baseURL+"/blocked_users?"+q.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to get blocked users: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return nil, fmt.Errorf("failed to get blocked users: HTTP %d", resp.StatusCode)
	}

	var results []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return nil, fmt.Errorf("failed to parse blocked users: %w", err)
	}

	userIDs := make([]uuid.UUID, 0, len(results))
	for _, result := range results {
		if userIDStr, ok := result["blocked_id"].(string); ok {
			if uid, err := uuid.Parse(userIDStr); err == nil {
				userIDs = append(userIDs, uid)
			}
		}
	}

	return userIDs, nil
}

// RestrictUser restricts a user (their content is hidden from feed)
func (r *SupabaseUserRepository) RestrictUser(ctx context.Context, restrictorID, restrictedID uuid.UUID) error {
	payload := map[string]interface{}{
		"restrictor_id": restrictorID.String(),
		"restricted_id": restrictedID.String(),
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal restrict request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.baseURL+"/restricted_users", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return fmt.Errorf("failed to restrict user: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		// Check if it's a unique constraint violation (already restricted)
		if strings.Contains(string(bodyBytes), "duplicate") || strings.Contains(string(bodyBytes), "unique") {
			return nil // Already restricted, no error
		}
		return fmt.Errorf("failed to restrict user: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// UnrestrictUser unrestricts a user
func (r *SupabaseUserRepository) UnrestrictUser(ctx context.Context, restrictorID, restrictedID uuid.UUID) error {
	q := url.Values{}
	q.Set("restrictor_id", "eq."+restrictorID.String())
	q.Set("restricted_id", "eq."+restrictedID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, r.baseURL+"/restricted_users?"+q.Encode(), nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return fmt.Errorf("failed to unrestrict user: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 && resp.StatusCode != 404 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to unrestrict user: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// IsUserRestricted checks if a user is restricted by another user
func (r *SupabaseUserRepository) IsUserRestricted(ctx context.Context, restrictorID, restrictedID uuid.UUID) (bool, error) {
	q := url.Values{}
	q.Set("restrictor_id", "eq."+restrictorID.String())
	q.Set("restricted_id", "eq."+restrictedID.String())
	q.Set("select", "id")

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.baseURL+"/restricted_users?"+q.Encode(), nil)
	if err != nil {
		return false, fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return false, fmt.Errorf("failed to check restrict status: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return false, fmt.Errorf("failed to check restrict status: HTTP %d", resp.StatusCode)
	}

	var results []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return false, fmt.Errorf("failed to parse restrict check response: %w", err)
	}

	return len(results) > 0, nil
}

// GetRestrictedUserIDs gets all user IDs that a user has restricted
func (r *SupabaseUserRepository) GetRestrictedUserIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	q := url.Values{}
	q.Set("restrictor_id", "eq."+userID.String())
	q.Set("select", "restricted_id")

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.baseURL+"/restricted_users?"+q.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to get restricted users: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return nil, fmt.Errorf("failed to get restricted users: HTTP %d", resp.StatusCode)
	}

	var results []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return nil, fmt.Errorf("failed to parse restricted users: %w", err)
	}

	userIDs := make([]uuid.UUID, 0, len(results))
	for _, result := range results {
		if userIDStr, ok := result["restricted_id"].(string); ok {
			if uid, err := uuid.Parse(userIDStr); err == nil {
				userIDs = append(userIDs, uid)
			}
		}
	}

	return userIDs, nil
}

// ReportUser reports a user for moderation purposes
func (r *SupabaseUserRepository) ReportUser(ctx context.Context, reporterID, reportedID uuid.UUID, reason, description string) error {
	payload := map[string]interface{}{
		"reporter_id": reporterID.String(),
		"reported_id": reportedID.String(),
		"reason":      reason,
		"description": description,
		"status":      "pending",
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal report request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.baseURL+"/user_reports", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := r.http.Do(req)
	if err != nil {
		return fmt.Errorf("failed to report user: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		// Check if it's a unique constraint violation (already reported)
		if strings.Contains(string(bodyBytes), "duplicate") || strings.Contains(string(bodyBytes), "unique") {
			return fmt.Errorf("user already reported")
		}
		return fmt.Errorf("failed to report user: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

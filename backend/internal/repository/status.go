package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// StatusRepository defines the interface for status data access
type StatusRepository interface {
	// Status CRUD
	CreateStatus(ctx context.Context, status *models.Status) error
	GetStatus(ctx context.Context, statusID, viewerID uuid.UUID) (*models.Status, error)
	GetUserStatuses(ctx context.Context, userID, viewerID uuid.UUID, limit int) ([]models.Status, error)
	GetStatusesForFeed(ctx context.Context, viewerID uuid.UUID, limit int) ([]models.Status, error)
	DeleteStatus(ctx context.Context, statusID, userID uuid.UUID) error

	// Views
	CreateStatusView(ctx context.Context, statusID, userID uuid.UUID) error
	HasUserViewedStatus(ctx context.Context, statusID, userID uuid.UUID) (bool, error)
	GetStatusViews(ctx context.Context, statusID uuid.UUID, limit int) ([]models.StatusView, error)

	// Reactions
	ReactToStatus(ctx context.Context, statusID, userID uuid.UUID, emoji string) error
	RemoveStatusReaction(ctx context.Context, statusID, userID uuid.UUID) error
	GetStatusReactions(ctx context.Context, statusID uuid.UUID, limit int) ([]models.StatusReaction, error)

	// Comments
	CreateStatusComment(ctx context.Context, comment *models.StatusComment) error
	GetStatusComments(ctx context.Context, statusID uuid.UUID, limit, offset int) ([]models.StatusComment, int, error)
	DeleteStatusComment(ctx context.Context, commentID, userID uuid.UUID) error

	// Message Replies
	CreateStatusMessageReply(ctx context.Context, statusID, fromUserID, toUserID uuid.UUID) (*uuid.UUID, error)
}

// SupabaseStatusRepository implements StatusRepository using Supabase REST API
type SupabaseStatusRepository struct {
	supabaseURL string
	serviceKey  string
	client      *http.Client
}

// NewSupabaseStatusRepository creates a new Supabase status repository
func NewSupabaseStatusRepository(supabaseURL, serviceKey string) *SupabaseStatusRepository {
	return &SupabaseStatusRepository{
		supabaseURL: supabaseURL,
		serviceKey:  serviceKey,
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// Helper to make Supabase requests
func (r *SupabaseStatusRepository) makeRequest(method, table, query string, body interface{}) ([]byte, error) {
	url := fmt.Sprintf("%s/rest/v1/%s%s", r.supabaseURL, table, query)

	var reqBody io.Reader
	if body != nil {
		jsonData, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request body: %w", err)
		}
		reqBody = strings.NewReader(string(jsonData))
	}

	req, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", r.serviceKey)
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", r.serviceKey))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "return=representation")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("supabase error (status %d): %s", resp.StatusCode, string(data))
	}

	return data, nil
}

// Helper to parse timestamps from Supabase (handles various formats)
func parseStatusTime(val interface{}) *time.Time {
	if val == nil {
		return nil
	}
	str, ok := val.(string)
	if !ok {
		return nil
	}

	// Try RFC3339 first (with timezone)
	if t, err := time.Parse(time.RFC3339, str); err == nil {
		return &t
	}
	// Try RFC3339Nano
	if t, err := time.Parse(time.RFC3339Nano, str); err == nil {
		return &t
	}

	// Handle Supabase format without timezone: treat as UTC
	utc, _ := time.LoadLocation("UTC")

	if !strings.Contains(str, "Z") && !strings.Contains(str, "+") && len(str) > 10 {
		parts := strings.Split(str, ".")
		if len(parts) == 2 {
			fractional := parts[1]
			if len(fractional) > 6 {
				fractional = fractional[:6]
			} else if len(fractional) < 6 {
				fractional = fractional + strings.Repeat("0", 6-len(fractional))
			}
			normalized := parts[0] + "." + fractional
			if t, err := time.ParseInLocation("2006-01-02T15:04:05.999999", normalized, utc); err == nil {
				return &t
			}
		} else {
			if t, err := time.ParseInLocation("2006-01-02T15:04:05", str, utc); err == nil {
				return &t
			}
		}
	}

	return nil
}

func parseRequiredStatusTime(val interface{}) time.Time {
	if t := parseStatusTime(val); t != nil {
		return *t
	}
	return time.Now()
}

// parseStatusFromMap parses a status from map[string]interface{}
func (r *SupabaseStatusRepository) parseStatusFromMap(statusData map[string]interface{}) (*models.Status, error) {
	status := &models.Status{}

	if id, ok := statusData["id"].(string); ok {
		if uuid, err := uuid.Parse(id); err == nil {
			status.ID = uuid
		}
	}
	if userId, ok := statusData["user_id"].(string); ok {
		if uuid, err := uuid.Parse(userId); err == nil {
			status.UserID = uuid
		}
	}
	if statusType, ok := statusData["status_type"].(string); ok {
		status.StatusType = statusType
	}
	if content, ok := statusData["content"].(string); ok && content != "" {
		status.Content = &content
	}
	if mediaURL, ok := statusData["media_url"].(string); ok && mediaURL != "" {
		status.MediaURL = &mediaURL
	}
	if mediaType, ok := statusData["media_type"].(string); ok && mediaType != "" {
		status.MediaType = &mediaType
	}
	if bgColor, ok := statusData["background_color"].(string); ok {
		status.BackgroundColor = bgColor
	}

	// Parse numeric fields
	if viewsCount, ok := statusData["views_count"].(float64); ok {
		status.ViewsCount = int(viewsCount)
	}
	if reactionsCount, ok := statusData["reactions_count"].(float64); ok {
		status.ReactionsCount = int(reactionsCount)
	}
	if commentsCount, ok := statusData["comments_count"].(float64); ok {
		status.CommentsCount = int(commentsCount)
	}

	// Parse timestamps
	status.CreatedAt = parseRequiredStatusTime(statusData["created_at"])
	status.UpdatedAt = parseRequiredStatusTime(statusData["updated_at"])
	if expiresAt := parseStatusTime(statusData["expires_at"]); expiresAt != nil {
		status.ExpiresAt = *expiresAt
	}

	// Parse is_viewed from joined query if present
	if isViewed, ok := statusData["is_viewed"].(bool); ok {
		status.IsViewed = isViewed
	}

	// Parse user_reaction from joined query if present
	if userReaction, ok := statusData["user_reaction"].(string); ok && userReaction != "" {
		status.UserReaction = &userReaction
	}

	return status, nil
}

// CreateStatus creates a new status
func (r *SupabaseStatusRepository) CreateStatus(ctx context.Context, status *models.Status) error {
	if status.ID == uuid.Nil {
		status.ID = uuid.New()
	}

	// Set expires_at to 24 hours from now
	if status.ExpiresAt.IsZero() {
		status.ExpiresAt = time.Now().Add(24 * time.Hour)
	}

	payload := map[string]interface{}{
		"id":               status.ID,
		"user_id":          status.UserID,
		"status_type":      status.StatusType,
		"content":          status.Content,
		"media_url":        status.MediaURL,
		"media_type":       status.MediaType,
		"background_color": status.BackgroundColor,
		"expires_at":       status.ExpiresAt.Format(time.RFC3339),
	}

	data, err := r.makeRequest("POST", "statuses", "", payload)
	if err != nil {
		return fmt.Errorf("failed to create status: %w", err)
	}

	var created []map[string]interface{}
	if err := json.Unmarshal(data, &created); err != nil {
		return fmt.Errorf("failed to unmarshal created status: %w", err)
	}

	if len(created) > 0 {
		parsed, err := r.parseStatusFromMap(created[0])
		if err != nil {
			return fmt.Errorf("failed to parse created status: %w", err)
		}
		*status = *parsed
	}

	return nil
}

// GetStatus retrieves a single status by ID
func (r *SupabaseStatusRepository) GetStatus(ctx context.Context, statusID, viewerID uuid.UUID) (*models.Status, error) {
	// Query with joins to get author, views, and reactions
	query := fmt.Sprintf("?id=eq.%s&expires_at=gt.%s&select=*,users!statuses_user_id_fkey(id,username,display_name,profile_picture),status_views!left(user_id),status_reactions!left(user_id,emoji)",
		statusID.String(),
		url.QueryEscape(time.Now().Format(time.RFC3339)))

	data, err := r.makeRequest("GET", "statuses", query, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get status: %w", err)
	}

	var results []map[string]interface{}
	if err := json.Unmarshal(data, &results); err != nil {
		return nil, fmt.Errorf("failed to unmarshal status: %w", err)
	}

	if len(results) == 0 {
		return nil, models.ErrStatusNotFound
	}

	statusData := results[0]

	// Parse author information first
	var author *models.User
	if users, ok := statusData["users"].(map[string]interface{}); ok {
		author = &models.User{}
		if userId, ok := users["id"].(string); ok {
			if uuid, err := uuid.Parse(userId); err == nil {
				author.ID = uuid
			}
		}
		if username, ok := users["username"].(string); ok {
			author.Username = username
		}
		if displayName, ok := users["display_name"].(string); ok {
			author.DisplayName = displayName
		}
		if profilePic, ok := users["profile_picture"].(string); ok && profilePic != "" {
			author.ProfilePicture = &profilePic
		}
	}

	// Check if viewed
	isViewed := false
	if views, ok := statusData["status_views"].([]interface{}); ok {
		for _, v := range views {
			if view, ok := v.(map[string]interface{}); ok {
				if userId, ok := view["user_id"].(string); ok {
					if userId == viewerID.String() {
						isViewed = true
						break
					}
				}
			}
		}
	}
	statusData["is_viewed"] = isViewed

	// Check user reaction
	var userReaction *string
	if reactions, ok := statusData["status_reactions"].([]interface{}); ok {
		for _, v := range reactions {
			if reaction, ok := v.(map[string]interface{}); ok {
				if userId, ok := reaction["user_id"].(string); ok {
					if userId == viewerID.String() {
						if emoji, ok := reaction["emoji"].(string); ok {
							userReaction = &emoji
							break
						}
					}
				}
			}
		}
	}
	if userReaction != nil {
		statusData["user_reaction"] = *userReaction
	}

	status, err := r.parseStatusFromMap(statusData)
	if err != nil {
		return nil, fmt.Errorf("failed to parse status: %w", err)
	}

	// Set author after parsing
	if author != nil {
		status.Author = author
	}

	return status, nil
}

// GetUserStatuses retrieves all active statuses for a user
func (r *SupabaseStatusRepository) GetUserStatuses(ctx context.Context, userID, viewerID uuid.UUID, limit int) ([]models.Status, error) {
	if limit <= 0 {
		limit = 50
	}

	query := fmt.Sprintf("?user_id=eq.%s&expires_at=gt.%s&order=created_at.desc&limit=%d&select=*,users!statuses_user_id_fkey(id,username,display_name,profile_picture)",
		userID.String(),
		url.QueryEscape(time.Now().Format(time.RFC3339)),
		limit)

	data, err := r.makeRequest("GET", "statuses", query, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get user statuses: %w", err)
	}

	var results []map[string]interface{}
	if err := json.Unmarshal(data, &results); err != nil {
		return nil, fmt.Errorf("failed to unmarshal statuses: %w", err)
	}

	statuses := make([]models.Status, 0, len(results))
	for _, item := range results {
		// Parse author first
		var author *models.User
		if users, ok := item["users"].(map[string]interface{}); ok {
			author = &models.User{}
			if userId, ok := users["id"].(string); ok {
				if uuid, err := uuid.Parse(userId); err == nil {
					author.ID = uuid
				}
			}
			if username, ok := users["username"].(string); ok {
				author.Username = username
			}
			if displayName, ok := users["display_name"].(string); ok {
				author.DisplayName = displayName
			}
			if profilePic, ok := users["profile_picture"].(string); ok && profilePic != "" {
				author.ProfilePicture = &profilePic
			}
		}

		status, err := r.parseStatusFromMap(item)
		if err != nil {
			continue
		}

		// Set author after parsing
		if author != nil {
			status.Author = author
		}

		statuses = append(statuses, *status)
	}

	return statuses, nil
}

// GetStatusesForFeed retrieves statuses from followed users for the feed
func (r *SupabaseStatusRepository) GetStatusesForFeed(ctx context.Context, viewerID uuid.UUID, limit int) ([]models.Status, error) {
	if limit <= 0 {
		limit = 100
	}

	// Query: Get statuses from users that viewer follows, plus viewer's own statuses
	// This is done in two queries for simplicity (can be optimized with a single query using OR)

	// First, get following relationships
	relQuery := fmt.Sprintf("?from_user_id=eq.%s&relationship_type=eq.following&status=eq.active&select=to_user_id", viewerID.String())
	relData, err := r.makeRequest("GET", "user_relationships", relQuery, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get following: %w", err)
	}

	var relationships []map[string]interface{}
	if err := json.Unmarshal(relData, &relationships); err != nil {
		return nil, fmt.Errorf("failed to unmarshal relationships: %w", err)
	}

	// Build list of user IDs (including viewer)
	userIDs := []string{viewerID.String()}
	for _, rel := range relationships {
		if toUserId, ok := rel["to_user_id"].(string); ok {
			userIDs = append(userIDs, toUserId)
		}
	}

	if len(userIDs) == 0 {
		return []models.Status{}, nil
	}

	// Query statuses from these users with author info
	statusQuery := fmt.Sprintf("?user_id=in.(%s)&expires_at=gt.%s&order=created_at.desc&limit=%d&select=*,users!statuses_user_id_fkey(id,username,display_name,profile_picture)",
		strings.Join(userIDs, ","),
		url.QueryEscape(time.Now().Format(time.RFC3339)),
		limit)

	data, err := r.makeRequest("GET", "statuses", statusQuery, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get feed statuses: %w", err)
	}

	var results []map[string]interface{}
	if err := json.Unmarshal(data, &results); err != nil {
		return nil, fmt.Errorf("failed to unmarshal statuses: %w", err)
	}

	// Group by user and get latest status per user
	userStatusMap := make(map[string]*models.Status)
	for _, item := range results {
		// Parse author first
		var author *models.User
		if users, ok := item["users"].(map[string]interface{}); ok {
			author = &models.User{}
			if userId, ok := users["id"].(string); ok {
				if uuid, err := uuid.Parse(userId); err == nil {
					author.ID = uuid
				}
			}
			if username, ok := users["username"].(string); ok {
				author.Username = username
			}
			if displayName, ok := users["display_name"].(string); ok {
				author.DisplayName = displayName
			}
			if profilePic, ok := users["profile_picture"].(string); ok && profilePic != "" {
				author.ProfilePicture = &profilePic
			}
		}

		status, err := r.parseStatusFromMap(item)
		if err != nil {
			continue
		}

		// Set author after parsing
		if author != nil {
			status.Author = author
		}

		userIdStr := status.UserID.String()
		if existing, exists := userStatusMap[userIdStr]; !exists || status.CreatedAt.After(existing.CreatedAt) {
			userStatusMap[userIdStr] = status
		}
	}

	// Convert to slice
	statuses := make([]models.Status, 0, len(userStatusMap))
	for _, status := range userStatusMap {
		statuses = append(statuses, *status)
	}

	return statuses, nil
}

// DeleteStatus deletes a status (only if owner)
func (r *SupabaseStatusRepository) DeleteStatus(ctx context.Context, statusID, userID uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s&user_id=eq.%s", statusID.String(), userID.String())

	_, err := r.makeRequest("DELETE", "statuses", query, nil)
	if err != nil {
		return fmt.Errorf("failed to delete status: %w", err)
	}

	return nil
}

// CreateStatusView records a view on a status
func (r *SupabaseStatusRepository) CreateStatusView(ctx context.Context, statusID, userID uuid.UUID) error {
	// Check if already viewed (idempotent)
	hasViewed, err := r.HasUserViewedStatus(ctx, statusID, userID)
	if err == nil && hasViewed {
		return nil // Already viewed, skip
	}

	payload := map[string]interface{}{
		"status_id": statusID,
		"user_id":   userID,
	}

	_, err = r.makeRequest("POST", "status_views", "", payload)
	if err != nil {
		// Ignore unique constraint errors (already viewed)
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique") {
			return nil
		}
		return fmt.Errorf("failed to create status view: %w", err)
	}

	return nil
}

// HasUserViewedStatus checks if a user has viewed a status
func (r *SupabaseStatusRepository) HasUserViewedStatus(ctx context.Context, statusID, userID uuid.UUID) (bool, error) {
	query := fmt.Sprintf("?status_id=eq.%s&user_id=eq.%s&limit=1", statusID.String(), userID.String())

	data, err := r.makeRequest("GET", "status_views", query, nil)
	if err != nil {
		return false, fmt.Errorf("failed to check status view: %w", err)
	}

	var results []map[string]interface{}
	if err := json.Unmarshal(data, &results); err != nil {
		return false, fmt.Errorf("failed to unmarshal status views: %w", err)
	}

	return len(results) > 0, nil
}

// GetStatusViews retrieves views for a status
func (r *SupabaseStatusRepository) GetStatusViews(ctx context.Context, statusID uuid.UUID, limit int) ([]models.StatusView, error) {
	if limit <= 0 {
		limit = 100
	}

	query := fmt.Sprintf("?status_id=eq.%s&order=viewed_at.desc&limit=%d&select=*,users(id,username,display_name,profile_picture)",
		statusID.String(), limit)

	data, err := r.makeRequest("GET", "status_views", query, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get status views: %w", err)
	}

	var results []map[string]interface{}
	if err := json.Unmarshal(data, &results); err != nil {
		return nil, fmt.Errorf("failed to unmarshal status views: %w", err)
	}

	views := make([]models.StatusView, 0, len(results))
	for _, item := range results {
		view := models.StatusView{}

		if id, ok := item["id"].(string); ok {
			if uuid, err := uuid.Parse(id); err == nil {
				view.ID = uuid
			}
		}
		if statusId, ok := item["status_id"].(string); ok {
			if uuid, err := uuid.Parse(statusId); err == nil {
				view.StatusID = uuid
			}
		}
		if userId, ok := item["user_id"].(string); ok {
			if uuid, err := uuid.Parse(userId); err == nil {
				view.UserID = uuid
			}
		}
		view.ViewedAt = parseRequiredStatusTime(item["viewed_at"])

		// Parse user if present
		if users, ok := item["users"].(map[string]interface{}); ok {
			user := &models.User{}
			if userId, ok := users["id"].(string); ok {
				if uuid, err := uuid.Parse(userId); err == nil {
					user.ID = uuid
				}
			}
			if username, ok := users["username"].(string); ok {
				user.Username = username
			}
			if displayName, ok := users["display_name"].(string); ok {
				user.DisplayName = displayName
			}
			if profilePic, ok := users["profile_picture"].(string); ok && profilePic != "" {
				user.ProfilePicture = &profilePic
			}
			view.User = user
		}

		views = append(views, view)
	}

	return views, nil
}

// ReactToStatus adds or updates a reaction on a status
func (r *SupabaseStatusRepository) ReactToStatus(ctx context.Context, statusID, userID uuid.UUID, emoji string) error {
	// Check if reaction exists
	query := fmt.Sprintf("?status_id=eq.%s&user_id=eq.%s&limit=1", statusID.String(), userID.String())
	data, err := r.makeRequest("GET", "status_reactions", query, nil)
	if err != nil {
		return fmt.Errorf("failed to check existing reaction: %w", err)
	}

	var existing []map[string]interface{}
	json.Unmarshal(data, &existing)

	if len(existing) > 0 {
		// Update existing reaction
		updateQuery := fmt.Sprintf("?status_id=eq.%s&user_id=eq.%s", statusID.String(), userID.String())
		payload := map[string]interface{}{
			"emoji": emoji,
		}
		_, err = r.makeRequest("PATCH", "status_reactions", updateQuery, payload)
	} else {
		// Create new reaction
		payload := map[string]interface{}{
			"status_id": statusID,
			"user_id":   userID,
			"emoji":     emoji,
		}
		_, err = r.makeRequest("POST", "status_reactions", "", payload)
	}

	if err != nil {
		return fmt.Errorf("failed to react to status: %w", err)
	}

	return nil
}

// RemoveStatusReaction removes a reaction from a status
func (r *SupabaseStatusRepository) RemoveStatusReaction(ctx context.Context, statusID, userID uuid.UUID) error {
	query := fmt.Sprintf("?status_id=eq.%s&user_id=eq.%s", statusID.String(), userID.String())

	_, err := r.makeRequest("DELETE", "status_reactions", query, nil)
	if err != nil {
		return fmt.Errorf("failed to remove reaction: %w", err)
	}

	return nil
}

// GetStatusReactions retrieves reactions for a status
func (r *SupabaseStatusRepository) GetStatusReactions(ctx context.Context, statusID uuid.UUID, limit int) ([]models.StatusReaction, error) {
	if limit <= 0 {
		limit = 50
	}

	query := fmt.Sprintf("?status_id=eq.%s&order=created_at.desc&limit=%d&select=*,users(id,username,display_name,profile_picture)",
		statusID.String(), limit)

	data, err := r.makeRequest("GET", "status_reactions", query, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get reactions: %w", err)
	}

	var results []map[string]interface{}
	if err := json.Unmarshal(data, &results); err != nil {
		return nil, fmt.Errorf("failed to unmarshal reactions: %w", err)
	}

	reactions := make([]models.StatusReaction, 0, len(results))
	for _, item := range results {
		reaction := models.StatusReaction{}

		if id, ok := item["id"].(string); ok {
			if uuid, err := uuid.Parse(id); err == nil {
				reaction.ID = uuid
			}
		}
		if statusId, ok := item["status_id"].(string); ok {
			if uuid, err := uuid.Parse(statusId); err == nil {
				reaction.StatusID = uuid
			}
		}
		if userId, ok := item["user_id"].(string); ok {
			if uuid, err := uuid.Parse(userId); err == nil {
				reaction.UserID = uuid
			}
		}
		if emoji, ok := item["emoji"].(string); ok {
			reaction.Emoji = emoji
		}
		reaction.CreatedAt = parseRequiredStatusTime(item["created_at"])

		// Parse user if present
		if users, ok := item["users"].(map[string]interface{}); ok {
			user := &models.User{}
			if userId, ok := users["id"].(string); ok {
				if uuid, err := uuid.Parse(userId); err == nil {
					user.ID = uuid
				}
			}
			if username, ok := users["username"].(string); ok {
				user.Username = username
			}
			if displayName, ok := users["display_name"].(string); ok {
				user.DisplayName = displayName
			}
			if profilePic, ok := users["profile_picture"].(string); ok && profilePic != "" {
				user.ProfilePicture = &profilePic
			}
			reaction.User = user
		}

		reactions = append(reactions, reaction)
	}

	return reactions, nil
}

// CreateStatusComment creates a comment on a status
func (r *SupabaseStatusRepository) CreateStatusComment(ctx context.Context, comment *models.StatusComment) error {
	if comment.ID == uuid.Nil {
		comment.ID = uuid.New()
	}

	payload := map[string]interface{}{
		"id":        comment.ID,
		"status_id": comment.StatusID,
		"user_id":   comment.UserID,
		"content":   comment.Content,
	}

	// Use select to get user data in response
	query := "?select=*,users(id,username,display_name,profile_picture)"
	data, err := r.makeRequest("POST", "status_comments", query, payload)
	if err != nil {
		return fmt.Errorf("failed to create comment: %w", err)
	}

	var created []map[string]interface{}
	if err := json.Unmarshal(data, &created); err != nil {
		return fmt.Errorf("failed to unmarshal created comment: %w", err)
	}

	if len(created) > 0 {
		commentData := created[0]
		if id, ok := commentData["id"].(string); ok {
			if uuid, err := uuid.Parse(id); err == nil {
				comment.ID = uuid
			}
		}
		comment.CreatedAt = parseRequiredStatusTime(commentData["created_at"])
		comment.UpdatedAt = parseRequiredStatusTime(commentData["updated_at"])

		// Parse user if present
		if users, ok := commentData["users"].(map[string]interface{}); ok {
			user := &models.User{}
			if userId, ok := users["id"].(string); ok {
				if uuid, err := uuid.Parse(userId); err == nil {
					user.ID = uuid
				}
			}
			if username, ok := users["username"].(string); ok {
				user.Username = username
			}
			if displayName, ok := users["display_name"].(string); ok {
				user.DisplayName = displayName
			}
			if profilePic, ok := users["profile_picture"].(string); ok && profilePic != "" {
				user.ProfilePicture = &profilePic
			}
			comment.Author = user
		}
	}

	return nil
}

// GetStatusComments retrieves comments for a status
func (r *SupabaseStatusRepository) GetStatusComments(ctx context.Context, statusID uuid.UUID, limit, offset int) ([]models.StatusComment, int, error) {
	if limit <= 0 {
		limit = 50
	}

	query := fmt.Sprintf("?status_id=eq.%s&order=created_at.desc&limit=%d&offset=%d&select=*,users(id,username,display_name,profile_picture)",
		statusID.String(), limit, offset)

	data, err := r.makeRequest("GET", "status_comments", query, nil)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get comments: %w", err)
	}

	var results []map[string]interface{}
	if err := json.Unmarshal(data, &results); err != nil {
		return nil, 0, fmt.Errorf("failed to unmarshal comments: %w", err)
	}

	comments := make([]models.StatusComment, 0, len(results))
	for _, item := range results {
		comment := models.StatusComment{}

		if id, ok := item["id"].(string); ok {
			if uuid, err := uuid.Parse(id); err == nil {
				comment.ID = uuid
			}
		}
		if statusId, ok := item["status_id"].(string); ok {
			if uuid, err := uuid.Parse(statusId); err == nil {
				comment.StatusID = uuid
			}
		}
		if userId, ok := item["user_id"].(string); ok {
			if uuid, err := uuid.Parse(userId); err == nil {
				comment.UserID = uuid
			}
		}
		if content, ok := item["content"].(string); ok {
			comment.Content = content
		}
		comment.CreatedAt = parseRequiredStatusTime(item["created_at"])
		comment.UpdatedAt = parseRequiredStatusTime(item["updated_at"])

		// Parse user if present
		if users, ok := item["users"].(map[string]interface{}); ok {
			user := &models.User{}
			if userId, ok := users["id"].(string); ok {
				if uuid, err := uuid.Parse(userId); err == nil {
					user.ID = uuid
				}
			}
			if username, ok := users["username"].(string); ok {
				user.Username = username
			}
			if displayName, ok := users["display_name"].(string); ok {
				user.DisplayName = displayName
			}
			if profilePic, ok := users["profile_picture"].(string); ok && profilePic != "" {
				user.ProfilePicture = &profilePic
			}
			comment.Author = user
		}

		comments = append(comments, comment)
	}

	// Get total count (simplified - in production, use COUNT query)
	total := len(comments) + offset
	if len(comments) == limit {
		total += 1 // Likely has more
	} else {
		total = len(comments) + offset
	}

	return comments, total, nil
}

// DeleteStatusComment soft deletes a comment
func (r *SupabaseStatusRepository) DeleteStatusComment(ctx context.Context, commentID, userID uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s&user_id=eq.%s", commentID.String(), userID.String())

	payload := map[string]interface{}{
		"deleted_at": time.Now().Format(time.RFC3339),
	}

	_, err := r.makeRequest("PATCH", "status_comments", query, payload)
	if err != nil {
		return fmt.Errorf("failed to delete comment: %w", err)
	}

	return nil
}

// CreateStatusMessageReply creates a record of a direct message reply to a status
func (r *SupabaseStatusRepository) CreateStatusMessageReply(ctx context.Context, statusID, fromUserID, toUserID uuid.UUID) (*uuid.UUID, error) {
	// This creates a record linking the status to a message reply
	// The actual message creation is handled by the messaging system
	replyID := uuid.New()

	payload := map[string]interface{}{
		"id":           replyID,
		"status_id":    statusID,
		"from_user_id": fromUserID,
		"to_user_id":   toUserID,
	}

	_, err := r.makeRequest("POST", "status_message_replies", "", payload)
	if err != nil {
		// Ignore if already exists (unique constraint)
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique") {
			return &replyID, nil
		}
		return nil, fmt.Errorf("failed to create status message reply: %w", err)
	}

	return &replyID, nil
}

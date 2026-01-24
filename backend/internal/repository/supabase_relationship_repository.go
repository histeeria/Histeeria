package repository

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// SupabaseRelationshipRepository implements RelationshipRepository using Supabase
type SupabaseRelationshipRepository struct {
	supabaseURL string
	apiKey      string
	httpClient  *http.Client
}

// NewSupabaseRelationshipRepository creates a new Supabase relationship repository
func NewSupabaseRelationshipRepository(supabaseURL, apiKey string) *SupabaseRelationshipRepository {
	return &SupabaseRelationshipRepository{
		supabaseURL: supabaseURL,
		apiKey:      apiKey,
		httpClient:  &http.Client{Timeout: 10 * time.Second},
	}
}

// CreateRelationship creates a new relationship
func (r *SupabaseRelationshipRepository) CreateRelationship(ctx context.Context, relationship *models.UserRelationship) error {
	// Generate ID if not set
	if relationship.ID == uuid.Nil {
		relationship.ID = uuid.New()
	}

	// Build the request data manually to control timestamp format
	data := map[string]interface{}{
		"id":                relationship.ID.String(),
		"from_user_id":      relationship.FromUserID.String(),
		"to_user_id":        relationship.ToUserID.String(),
		"relationship_type": string(relationship.RelationshipType),
		"status":            string(relationship.Status),
	}

	if relationship.RequestMessage != nil {
		data["request_message"] = *relationship.RequestMessage
	}

	// Let database handle timestamps with DEFAULT NOW()
	// Don't send created_at or updated_at

	jsonData, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal relationship: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", r.supabaseURL+"/rest/v1/user_relationships", bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "return=representation")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateRelationship failed: HTTP %d - %s", resp.StatusCode, string(body))
		return fmt.Errorf("failed to create relationship (HTTP %d): %s", resp.StatusCode, string(body))
	}

	return nil
}

// GetRelationship gets a specific relationship between two users
func (r *SupabaseRelationshipRepository) GetRelationship(ctx context.Context, fromUserID, toUserID uuid.UUID, relationshipType models.RelationshipType) (*models.UserRelationship, error) {
	url := fmt.Sprintf("%s/rest/v1/user_relationships?from_user_id=eq.%s&to_user_id=eq.%s&relationship_type=eq.%s&limit=1",
		r.supabaseURL, fromUserID.String(), toUserID.String(), relationshipType)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get relationship: status %d", resp.StatusCode)
	}

	// Parse as raw JSON first to avoid timestamp parsing issues
	var rawRelationships []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&rawRelationships); err != nil {
		return nil, err
	}

	if len(rawRelationships) == 0 {
		return nil, nil
	}

	// Convert to UserRelationship (we don't actually need timestamps for checking existence)
	raw := rawRelationships[0]
	relationship := &models.UserRelationship{
		RelationshipType: models.RelationshipType(raw["relationship_type"].(string)),
		Status:           models.RelationshipStatus(raw["status"].(string)),
	}

	if idStr, ok := raw["id"].(string); ok {
		relationship.ID, _ = uuid.Parse(idStr)
	}
	if fromStr, ok := raw["from_user_id"].(string); ok {
		relationship.FromUserID, _ = uuid.Parse(fromStr)
	}
	if toStr, ok := raw["to_user_id"].(string); ok {
		relationship.ToUserID, _ = uuid.Parse(toStr)
	}

	return relationship, nil
}

// GetRelationshipByID gets a relationship by ID
func (r *SupabaseRelationshipRepository) GetRelationshipByID(ctx context.Context, relationshipID uuid.UUID) (*models.UserRelationship, error) {
	url := fmt.Sprintf("%s/rest/v1/user_relationships?id=eq.%s&limit=1", r.supabaseURL, relationshipID.String())

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get relationship: status %d", resp.StatusCode)
	}

	// Parse as raw JSON first to avoid timestamp parsing issues
	var rawRelationships []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&rawRelationships); err != nil {
		return nil, err
	}

	if len(rawRelationships) == 0 {
		return nil, fmt.Errorf("relationship not found")
	}

	// Convert to UserRelationship
	raw := rawRelationships[0]
	relationship := &models.UserRelationship{
		RelationshipType: models.RelationshipType(raw["relationship_type"].(string)),
		Status:           models.RelationshipStatus(raw["status"].(string)),
	}

	if idStr, ok := raw["id"].(string); ok {
		relationship.ID, _ = uuid.Parse(idStr)
	}
	if fromStr, ok := raw["from_user_id"].(string); ok {
		relationship.FromUserID, _ = uuid.Parse(fromStr)
	}
	if toStr, ok := raw["to_user_id"].(string); ok {
		relationship.ToUserID, _ = uuid.Parse(toStr)
	}

	return relationship, nil
}

// UpdateRelationshipStatus updates the status of a relationship
func (r *SupabaseRelationshipRepository) UpdateRelationshipStatus(ctx context.Context, relationshipID uuid.UUID, status models.RelationshipStatus) error {
	updateData := map[string]interface{}{
		"status":     status,
		"updated_at": time.Now(),
	}

	if status == models.RelationshipActive {
		updateData["accepted_at"] = time.Now()
	}

	data, err := json.Marshal(updateData)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/rest/v1/user_relationships?id=eq.%s", r.supabaseURL, relationshipID.String())
	req, err := http.NewRequestWithContext(ctx, "PATCH", url, bytes.NewBuffer(data))
	if err != nil {
		return err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to update relationship status: %s", string(body))
	}

	return nil
}

// DeleteRelationship deletes a relationship
func (r *SupabaseRelationshipRepository) DeleteRelationship(ctx context.Context, fromUserID, toUserID uuid.UUID, relationshipType models.RelationshipType) error {
	url := fmt.Sprintf("%s/rest/v1/user_relationships?from_user_id=eq.%s&to_user_id=eq.%s&relationship_type=eq.%s",
		r.supabaseURL, fromUserID.String(), toUserID.String(), relationshipType)

	req, err := http.NewRequestWithContext(ctx, "DELETE", url, nil)
	if err != nil {
		return err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to delete relationship: %s", string(body))
	}

	return nil
}

// GetUserRelationships gets a list of user relationships
func (r *SupabaseRelationshipRepository) GetUserRelationships(ctx context.Context, userID uuid.UUID, relationshipType models.RelationshipType, status models.RelationshipStatus, asFrom bool, page, limit int) ([]*models.RelationshipListItem, int, error) {
	offset := (page - 1) * limit

	// Determine which side of the relationship we're querying
	userField := "to_user_id"
	if asFrom {
		userField = "from_user_id"
	}

	// Build query
	url := fmt.Sprintf("%s/rest/v1/user_relationships?%s=eq.%s&relationship_type=eq.%s&status=eq.%s&select=*,users!from_user_id(*),users!to_user_id(*)&limit=%d&offset=%d&order=created_at.desc",
		r.supabaseURL, userField, userID.String(), relationshipType, status, limit, offset)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, 0, err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Prefer", "count=exact")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, 0, fmt.Errorf("failed to get relationships: status %d", resp.StatusCode)
	}

	// Parse Content-Range header for total count
	total := 0
	if contentRange := resp.Header.Get("Content-Range"); contentRange != "" {
		fmt.Sscanf(contentRange, "*/%d", &total)
	}

	// This is simplified - in production you'd need to join with users table
	// For now, return empty list
	items := make([]*models.RelationshipListItem, 0)

	return items, total, nil
}

// GetRelationshipList gets a simplified list of users for followers/following/connections/collaborators
func (r *SupabaseRelationshipRepository) GetRelationshipList(ctx context.Context, userID uuid.UUID, listType string, page, limit int) ([]*models.RelationshipListItem, int, error) {
	offset := (page - 1) * limit

	var queryParams string
	var userField string

	switch listType {
	case "followers":
		// People who follow this user
		queryParams = fmt.Sprintf("to_user_id=eq.%s&relationship_type=eq.following&status=eq.active", userID.String())
		userField = "from_user_id" // Return the follower

	case "following":
		// People this user follows
		queryParams = fmt.Sprintf("from_user_id=eq.%s&relationship_type=eq.following&status=eq.active", userID.String())
		userField = "to_user_id" // Return the followed user

	case "connections":
		// Mutual connections
		queryParams = fmt.Sprintf("from_user_id=eq.%s&relationship_type=eq.connected&status=eq.active", userID.String())
		userField = "to_user_id" // Return the connected user

	case "collaborators":
		// Mutual collaborators
		queryParams = fmt.Sprintf("from_user_id=eq.%s&relationship_type=eq.collaborating&status=eq.active", userID.String())
		userField = "to_user_id" // Return the collaborator

	default:
		return nil, 0, fmt.Errorf("invalid list type: %s", listType)
	}

	requestURL := fmt.Sprintf("%s/rest/v1/user_relationships?%s&select=id,from_user_id,to_user_id,created_at&limit=%d&offset=%d&order=created_at.desc",
		r.supabaseURL, queryParams, limit, offset)

	req, err := http.NewRequestWithContext(ctx, "GET", requestURL, nil)
	if err != nil {
		return nil, 0, err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Prefer", "count=exact")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[GetRelationshipList] Failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return nil, 0, fmt.Errorf("failed to get relationship list: %d", resp.StatusCode)
	}

	// Parse total count from Content-Range header
	totalCount := 0
	if contentRange := resp.Header.Get("Content-Range"); contentRange != "" {
		var start, end, total int
		if n, _ := fmt.Sscanf(contentRange, "%d-%d/%d", &start, &end, &total); n == 3 {
			totalCount = total
		} else if n, _ := fmt.Sscanf(contentRange, "*/%d", &total); n == 1 {
			totalCount = total
		}
	}

	var rawRelationships []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&rawRelationships); err != nil {
		return nil, 0, err
	}

	// Convert to RelationshipListItem
	items := make([]*models.RelationshipListItem, 0, len(rawRelationships))
	for _, raw := range rawRelationships {
		var targetUserID uuid.UUID

		if userField == "from_user_id" {
			if fromUserIDStr, ok := raw["from_user_id"].(string); ok {
				targetUserID, _ = uuid.Parse(fromUserIDStr)
			}
		} else {
			if toUserIDStr, ok := raw["to_user_id"].(string); ok {
				targetUserID, _ = uuid.Parse(toUserIDStr)
			}
		}

		item := &models.RelationshipListItem{
			UserID: targetUserID,
		}

		if createdAtStr, ok := raw["created_at"].(string); ok {
			item.CreatedAt, _ = time.Parse(time.RFC3339, createdAtStr)
		}

		items = append(items, item)
	}

	log.Printf("[GetRelationshipList] Fetched %d %s (total: %d) for user %s", len(items), listType, totalCount, userID)
	return items, totalCount, nil
}

// GetRelationshipStats gets the relationship stats for a user
func (r *SupabaseRelationshipRepository) GetRelationshipStats(ctx context.Context, userID uuid.UUID) (*models.RelationshipStats, error) {
	log.Printf("[GetRelationshipStats] Fetching stats for user %s", userID)

	// Fetch denormalized counts from users table (much faster than counting relationships)
	usersURL := fmt.Sprintf("%s/rest/v1/users?id=eq.%s&select=followers_count,following_count,connections_count,collaborators_count",
		r.supabaseURL, userID.String())

	req, err := http.NewRequestWithContext(ctx, "GET", usersURL, nil)
	if err != nil {
		log.Printf("[GetRelationshipStats] Failed to create request: %v", err)
		return nil, err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		log.Printf("[GetRelationshipStats] HTTP request failed: %v", err)
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[GetRelationshipStats] Supabase error: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return nil, fmt.Errorf("failed to fetch user stats: %d", resp.StatusCode)
	}

	var users []struct {
		FollowersCount     int `json:"followers_count"`
		FollowingCount     int `json:"following_count"`
		ConnectionsCount   int `json:"connections_count"`
		CollaboratorsCount int `json:"collaborators_count"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&users); err != nil {
		log.Printf("[GetRelationshipStats] Failed to decode response: %v", err)
		return nil, err
	}

	if len(users) == 0 {
		log.Printf("[GetRelationshipStats] User not found: %s", userID)
		return nil, fmt.Errorf("user not found")
	}

	stats := &models.RelationshipStats{
		FollowersCount:     users[0].FollowersCount,
		FollowingCount:     users[0].FollowingCount,
		ConnectionsCount:   users[0].ConnectionsCount,
		CollaboratorsCount: users[0].CollaboratorsCount,
	}

	log.Printf("[GetRelationshipStats] Stats for user %s: followers=%d following=%d connections=%d collaborators=%d",
		userID, stats.FollowersCount, stats.FollowingCount, stats.ConnectionsCount, stats.CollaboratorsCount)

	return stats, nil
}

// Helper function to count records
func (r *SupabaseRelationshipRepository) countRecords(ctx context.Context, url string) (int, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return 0, err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Prefer", "count=exact")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("failed to count records: status %d", resp.StatusCode)
	}

	// Parse Content-Range header for count
	total := 0
	if contentRange := resp.Header.Get("Content-Range"); contentRange != "" {
		fmt.Sscanf(contentRange, "*/%d", &total)
	}

	return total, nil
}

// GetRelationshipStatus gets the relationship status between two users
func (r *SupabaseRelationshipRepository) GetRelationshipStatus(ctx context.Context, fromUserID, toUserID uuid.UUID) (*models.RelationshipStatusResponse, error) {
	status := &models.RelationshipStatusResponse{}

	// Check if fromUser is following toUser
	followingRel, _ := r.GetRelationship(ctx, fromUserID, toUserID, models.RelationshipFollowing)
	if followingRel != nil && followingRel.Status == models.RelationshipActive {
		status.IsFollowing = true
	} else if followingRel != nil && followingRel.Status == models.RelationshipPending {
		status.HasPending = true
	}

	// Check if toUser is following fromUser (fromUser is a follower)
	followerRel, _ := r.GetRelationship(ctx, toUserID, fromUserID, models.RelationshipFollowing)
	if followerRel != nil && followerRel.Status == models.RelationshipActive {
		status.IsFollower = true
	}

	// Check connection (bidirectional)
	connectedRel, _ := r.GetRelationship(ctx, fromUserID, toUserID, models.RelationshipConnected)
	if connectedRel != nil && connectedRel.Status == models.RelationshipActive {
		status.IsConnected = true
	} else if connectedRel != nil && connectedRel.Status == models.RelationshipPending {
		status.HasPending = true
	}

	// Check collaboration (bidirectional)
	collabRel, _ := r.GetRelationship(ctx, fromUserID, toUserID, models.RelationshipCollaborating)
	if collabRel != nil && collabRel.Status == models.RelationshipActive {
		status.IsCollaborating = true
	} else if collabRel != nil && collabRel.Status == models.RelationshipPending {
		status.HasPending = true
	}

	// Check if blocked
	blockedRel, _ := r.GetRelationship(ctx, fromUserID, toUserID, models.RelationshipFollowing)
	if blockedRel != nil && blockedRel.Status == models.RelationshipBlocked {
		status.IsBlocked = true
	}

	return status, nil
}

// GetPendingRequests gets pending relationship requests
func (r *SupabaseRelationshipRepository) GetPendingRequests(ctx context.Context, userID uuid.UUID, incoming bool, page, limit int) ([]*models.RelationshipRequest, int, error) {
	// This is a simplified implementation
	// In production, you'd join with users table to get full user details
	requests := make([]*models.RelationshipRequest, 0)
	return requests, 0, nil
}

// GetRateLimit gets the rate limit record for a user and action type
func (r *SupabaseRelationshipRepository) GetRateLimit(ctx context.Context, userID uuid.UUID, actionType string) (*models.RelationshipRateLimit, error) {
	url := fmt.Sprintf("%s/rest/v1/relationship_rate_limits?user_id=eq.%s&action_type=eq.%s&limit=1",
		r.supabaseURL, userID.String(), actionType)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get rate limit: status %d", resp.StatusCode)
	}

	// Parse as raw JSON to avoid timestamp parsing issues
	var rawLimits []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&rawLimits); err != nil {
		return nil, err
	}

	if len(rawLimits) == 0 {
		return nil, nil
	}

	// Convert to RelationshipRateLimit (skip timestamps, we only need counts)
	raw := rawLimits[0]
	rateLimit := &models.RelationshipRateLimit{
		ActionType:         raw["action_type"].(string),
		ActionCount:        int(raw["action_count"].(float64)),
		CooldownMultiplier: raw["cooldown_multiplier"].(float64),
	}

	if idStr, ok := raw["id"].(string); ok {
		rateLimit.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		rateLimit.UserID, _ = uuid.Parse(userIDStr)
	}
	// Parse window_start timestamp manually if needed
	if windowStartStr, ok := raw["window_start"].(string); ok {
		rateLimit.WindowStart, _ = time.Parse("2006-01-02T15:04:05", windowStartStr[:19])
	}

	return rateLimit, nil
}

// CreateOrUpdateRateLimit creates or updates a rate limit record
func (r *SupabaseRelationshipRepository) CreateOrUpdateRateLimit(ctx context.Context, rateLimit *models.RelationshipRateLimit) error {
	// Try to get existing record
	existing, err := r.GetRateLimit(ctx, rateLimit.UserID, rateLimit.ActionType)
	if err != nil {
		return err
	}

	if existing != nil {
		// Update existing
		updateData := map[string]interface{}{
			"action_count":        rateLimit.ActionCount,
			"window_start":        rateLimit.WindowStart,
			"cooldown_multiplier": rateLimit.CooldownMultiplier,
			"updated_at":          time.Now(),
		}

		data, err := json.Marshal(updateData)
		if err != nil {
			return err
		}

		url := fmt.Sprintf("%s/rest/v1/relationship_rate_limits?user_id=eq.%s&action_type=eq.%s",
			r.supabaseURL, rateLimit.UserID.String(), rateLimit.ActionType)

		req, err := http.NewRequestWithContext(ctx, "PATCH", url, bytes.NewBuffer(data))
		if err != nil {
			return err
		}

		req.Header.Set("apikey", r.apiKey)
		req.Header.Set("Authorization", "Bearer "+r.apiKey)
		req.Header.Set("Content-Type", "application/json")

		resp, err := r.httpClient.Do(req)
		if err != nil {
			return err
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
			body, _ := io.ReadAll(resp.Body)
			return fmt.Errorf("failed to update rate limit: %s", string(body))
		}

		return nil
	}

	// Create new
	if rateLimit.ID == uuid.Nil {
		rateLimit.ID = uuid.New()
	}
	if rateLimit.CreatedAt.IsZero() {
		rateLimit.CreatedAt = time.Now()
	}
	if rateLimit.UpdatedAt.IsZero() {
		rateLimit.UpdatedAt = time.Now()
	}

	data, err := json.Marshal(rateLimit)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", r.supabaseURL+"/rest/v1/relationship_rate_limits", bytes.NewBuffer(data))
	if err != nil {
		return err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to create rate limit: %s", string(body))
	}

	return nil
}

// ResetRateLimit resets the rate limit for a user and action type
func (r *SupabaseRelationshipRepository) ResetRateLimit(ctx context.Context, userID uuid.UUID, actionType string) error {
	updateData := map[string]interface{}{
		"action_count":        0,
		"window_start":        time.Now(),
		"cooldown_multiplier": 1.0,
		"updated_at":          time.Now(),
	}

	data, err := json.Marshal(updateData)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/rest/v1/relationship_rate_limits?user_id=eq.%s&action_type=eq.%s",
		r.supabaseURL, userID.String(), actionType)

	req, err := http.NewRequestWithContext(ctx, "PATCH", url, bytes.NewBuffer(data))
	if err != nil {
		return err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("failed to reset rate limit: status %d", resp.StatusCode)
	}

	return nil
}

// GetSpamFlag gets a spam flag for a user
func (r *SupabaseRelationshipRepository) GetSpamFlag(ctx context.Context, userID uuid.UUID, detectionType string) (*models.SpamFlag, error) {
	url := fmt.Sprintf("%s/rest/v1/spam_flags?user_id=eq.%s&detection_type=eq.%s&limit=1",
		r.supabaseURL, userID.String(), detectionType)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get spam flag: status %d", resp.StatusCode)
	}

	// Parse as raw JSON to avoid timestamp parsing issues
	var rawFlags []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&rawFlags); err != nil {
		return nil, err
	}

	if len(rawFlags) == 0 {
		return nil, nil
	}

	// Convert to SpamFlag (skip timestamps for now)
	raw := rawFlags[0]
	flag := &models.SpamFlag{
		DetectionType:  raw["detection_type"].(string),
		FlagCount:      int(raw["flag_count"].(float64)),
		RequiresReview: raw["requires_review"].(bool),
	}

	if idStr, ok := raw["id"].(string); ok {
		flag.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		flag.UserID, _ = uuid.Parse(userIDStr)
	}

	return flag, nil
}

// CreateOrUpdateSpamFlag creates or updates a spam flag
func (r *SupabaseRelationshipRepository) CreateOrUpdateSpamFlag(ctx context.Context, spamFlag *models.SpamFlag) error {
	existing, err := r.GetSpamFlag(ctx, spamFlag.UserID, spamFlag.DetectionType)
	if err != nil {
		return err
	}

	if existing != nil {
		// Update existing
		updateData := map[string]interface{}{
			"flag_count":      spamFlag.FlagCount,
			"last_flagged_at": spamFlag.LastFlaggedAt,
			"requires_review": spamFlag.RequiresReview,
		}

		data, err := json.Marshal(updateData)
		if err != nil {
			return err
		}

		url := fmt.Sprintf("%s/rest/v1/spam_flags?user_id=eq.%s&detection_type=eq.%s",
			r.supabaseURL, spamFlag.UserID.String(), spamFlag.DetectionType)

		req, err := http.NewRequestWithContext(ctx, "PATCH", url, bytes.NewBuffer(data))
		if err != nil {
			return err
		}

		req.Header.Set("apikey", r.apiKey)
		req.Header.Set("Authorization", "Bearer "+r.apiKey)
		req.Header.Set("Content-Type", "application/json")

		resp, err := r.httpClient.Do(req)
		if err != nil {
			return err
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
			body, _ := io.ReadAll(resp.Body)
			return fmt.Errorf("failed to update spam flag: %s", string(body))
		}

		return nil
	}

	// Create new
	if spamFlag.ID == uuid.Nil {
		spamFlag.ID = uuid.New()
	}
	if spamFlag.CreatedAt.IsZero() {
		spamFlag.CreatedAt = time.Now()
	}

	data, err := json.Marshal(spamFlag)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", r.supabaseURL+"/rest/v1/spam_flags", bytes.NewBuffer(data))
	if err != nil {
		return err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to create spam flag: %s", string(body))
	}

	return nil
}

// GetUserSpamFlags gets all spam flags for a user
func (r *SupabaseRelationshipRepository) GetUserSpamFlags(ctx context.Context, userID uuid.UUID) ([]*models.SpamFlag, error) {
	url := fmt.Sprintf("%s/rest/v1/spam_flags?user_id=eq.%s", r.supabaseURL, userID.String())

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get spam flags: status %d", resp.StatusCode)
	}

	var flags []*models.SpamFlag
	if err := json.NewDecoder(resp.Body).Decode(&flags); err != nil {
		return nil, err
	}

	return flags, nil
}

// CheckRelationshipExists checks if a relationship exists
func (r *SupabaseRelationshipRepository) CheckRelationshipExists(ctx context.Context, fromUserID, toUserID uuid.UUID, relationshipType models.RelationshipType) (bool, error) {
	rel, err := r.GetRelationship(ctx, fromUserID, toUserID, relationshipType)
	if err != nil {
		return false, err
	}
	return rel != nil, nil
}

// CountRecentActions counts recent actions by a user
func (r *SupabaseRelationshipRepository) CountRecentActions(ctx context.Context, userID uuid.UUID, actionType string, since time.Time) (int, error) {
	// Query relationships created since the given time
	var relationshipType string
	switch actionType {
	case "follow":
		relationshipType = "following"
	case "connect":
		relationshipType = "connected"
	case "collaborate":
		relationshipType = "collaborating"
	default:
		return 0, fmt.Errorf("invalid action type: %s", actionType)
	}

	url := fmt.Sprintf("%s/rest/v1/user_relationships?from_user_id=eq.%s&relationship_type=eq.%s&created_at=gte.%s&select=id",
		r.supabaseURL, userID.String(), relationshipType, since.Format(time.RFC3339))

	return r.countRecords(ctx, url)
}

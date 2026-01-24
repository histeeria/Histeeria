package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// parseTime parses timestamps from Supabase (handles various formats)
func parseTime(val interface{}) *time.Time {
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
	// Try RFC3339Nano (with nanoseconds and timezone)
	if t, err := time.Parse(time.RFC3339Nano, str); err == nil {
		return &t
	}

	// Handle Supabase format without timezone: 2025-11-15T00:00:45.060234
	// Parse as UTC since Supabase stores timestamps in UTC
	utc, _ := time.LoadLocation("UTC")

	// If no timezone, parse directly as UTC
	if !strings.Contains(str, "Z") && !strings.Contains(str, "+") && len(str) > 10 {
		// Check if it has fractional seconds
		parts := strings.Split(str, ".")
		if len(parts) == 2 {
			// Has fractional seconds: 2025-11-15T00:00:45.060234
			// Normalize to 6 digits for parsing
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
			// No fractional seconds: 2025-11-15T00:00:45
			if t, err := time.ParseInLocation("2006-01-02T15:04:05", str, utc); err == nil {
				return &t
			}
		}
	}

	// Fallback: try formats with fractional seconds (no timezone)
	formats := []string{
		"2006-01-02T15:04:05.999999999",
		"2006-01-02T15:04:05.999999",
		"2006-01-02T15:04:05.999",
		"2006-01-02T15:04:05",
	}

	for _, format := range formats {
		if t, err := time.ParseInLocation(format, str, utc); err == nil {
			return &t
		}
	}

	return nil
}

// parseCommentFromMap parses a comment from a map (handles timestamp parsing)
func (r *SupabaseCommentRepository) parseCommentFromMap(commentData map[string]interface{}) (*models.Comment, error) {
	comment := &models.Comment{}

	// Parse UUIDs - these are required
	var hasValidID, hasValidPostID, hasValidUserID bool
	
	if id, ok := commentData["id"].(string); ok && id != "" {
		if parsedUUID, err := uuid.Parse(id); err == nil {
			comment.ID = parsedUUID
			hasValidID = true
		}
	}
	if postId, ok := commentData["post_id"].(string); ok && postId != "" {
		if parsedUUID, err := uuid.Parse(postId); err == nil {
			comment.PostID = parsedUUID
			hasValidPostID = true
		}
	}
	if userId, ok := commentData["user_id"].(string); ok && userId != "" {
		if parsedUUID, err := uuid.Parse(userId); err == nil {
			comment.UserID = parsedUUID
			hasValidUserID = true
		}
	}
	if parentId, ok := commentData["parent_comment_id"].(string); ok && parentId != "" {
		if parsedUUID, err := uuid.Parse(parentId); err == nil {
			comment.ParentCommentID = &parsedUUID
		}
	}

	// Validate required fields
	if !hasValidID || !hasValidPostID || !hasValidUserID {
		return nil, fmt.Errorf("missing required UUID fields: id=%v, post_id=%v, user_id=%v", hasValidID, hasValidPostID, hasValidUserID)
	}

	// Parse strings
	if content, ok := commentData["content"].(string); ok {
		comment.Content = content
	}
	if mediaURL, ok := commentData["media_url"].(string); ok {
		comment.MediaURL = mediaURL
	}
	if mediaType, ok := commentData["media_type"].(string); ok {
		comment.MediaType = mediaType
	}

	// Parse integers
	if likesCount, ok := commentData["likes_count"].(float64); ok {
		comment.LikesCount = int(likesCount)
	}
	if repliesCount, ok := commentData["replies_count"].(float64); ok {
		comment.RepliesCount = int(repliesCount)
	}

	// Parse booleans
	if isEdited, ok := commentData["is_edited"].(bool); ok {
		comment.IsEdited = isEdited
	}

	// Parse timestamps
	if createdAt := parseTime(commentData["created_at"]); createdAt != nil {
		comment.CreatedAt = *createdAt
	} else {
		// Fallback to current time if parsing fails
		comment.CreatedAt = time.Now()
	}
	if updatedAt := parseTime(commentData["updated_at"]); updatedAt != nil {
		comment.UpdatedAt = *updatedAt
	} else {
		// Fallback to current time if parsing fails
		comment.UpdatedAt = time.Now()
	}
	comment.EditedAt = parseTime(commentData["edited_at"])
	comment.DeletedAt = parseTime(commentData["deleted_at"])

	return comment, nil
}

// parseCommentsFromJSON parses comments from JSON with custom timestamp handling
func (r *SupabaseCommentRepository) parseCommentsFromJSON(data []byte) ([]models.Comment, error) {
	var rawComments []map[string]interface{}
	if err := json.Unmarshal(data, &rawComments); err != nil {
		return nil, fmt.Errorf("failed to unmarshal comments JSON: %w", err)
	}

	comments := make([]models.Comment, 0, len(rawComments))
	for _, raw := range rawComments {
		comment, err := r.parseCommentFromMap(raw)
		if err != nil {
			log.Printf("[CommentRepo] Warning: Failed to parse comment: %v", err)
			continue // Skip invalid comments
		}
		if comment != nil {
			comments = append(comments, *comment)
		}
	}

	return comments, nil
}

// SupabaseCommentRepository implements CommentRepository using Supabase
type SupabaseCommentRepository struct {
	*SupabasePostRepository
}

// NewSupabaseCommentRepository creates a new comment repository
func NewSupabaseCommentRepository(supabaseURL, serviceKey string) *SupabaseCommentRepository {
	return &SupabaseCommentRepository{
		SupabasePostRepository: NewSupabasePostRepository(supabaseURL, serviceKey),
	}
}

// CreateComment creates a new comment
func (r *SupabaseCommentRepository) CreateComment(ctx context.Context, comment *models.Comment) error {
	if comment.ID == uuid.Nil {
		comment.ID = uuid.New()
	}

	payload := map[string]interface{}{
		"id":                comment.ID,
		"post_id":           comment.PostID,
		"user_id":           comment.UserID,
		"parent_comment_id": comment.ParentCommentID,
		"content":           comment.Content,
	}
	
	// Only include media fields if they have values (database constraint requires NULL or valid values)
	if comment.MediaURL != "" {
		payload["media_url"] = comment.MediaURL
	}
	if comment.MediaType != "" {
		payload["media_type"] = comment.MediaType
	}

	data, err := r.makeRequest("POST", "post_comments", "", payload)
	if err != nil {
		return fmt.Errorf("failed to create comment: %w", err)
	}

	created, err := r.parseCommentsFromJSON(data)
	if err != nil {
		return fmt.Errorf("failed to parse created comment: %w", err)
	}

	if len(created) > 0 {
		*comment = created[0]
	}

	// Load author
	r.loadCommentAuthor(ctx, comment)

	return nil
}

// GetComment retrieves a single comment
func (r *SupabaseCommentRepository) GetComment(ctx context.Context, commentID uuid.UUID) (*models.Comment, error) {
	query := fmt.Sprintf("?id=eq.%s&deleted_at=is.null&select=*", commentID.String())

	data, err := r.makeRequest("GET", "post_comments", query, nil)
	if err != nil {
		return nil, err
	}

	comments, err := r.parseCommentsFromJSON(data)
	if err != nil {
		return nil, fmt.Errorf("failed to parse comment: %w", err)
	}

	if len(comments) == 0 {
		return nil, fmt.Errorf("comment not found")
	}

	comment := &comments[0]
	r.loadCommentAuthor(ctx, comment)

	return comment, nil
}

// GetComments retrieves top-level comments for a post
func (r *SupabaseCommentRepository) GetComments(ctx context.Context, postID uuid.UUID, limit, offset int) ([]models.Comment, int, error) {
	query := fmt.Sprintf(
		"?post_id=eq.%s&parent_comment_id=is.null&deleted_at=is.null&select=*&order=created_at.desc&limit=%d&offset=%d",
		postID.String(), limit, offset,
	)

	// Make request and get response with headers
	url := fmt.Sprintf("%s/rest/v1/post_comments%s", r.SupabasePostRepository.supabaseURL, query)
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", r.SupabasePostRepository.serviceKey)
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", r.SupabasePostRepository.serviceKey))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "count=exact")

	resp, err := r.SupabasePostRepository.client.Do(req)
	if err != nil {
		log.Printf("[CommentRepo] Error making request: %v", err)
		return nil, 0, fmt.Errorf("failed to get comments: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[CommentRepo] Supabase error (status %d): %s", resp.StatusCode, string(bodyBytes))
		return nil, 0, fmt.Errorf("supabase error (status %d): %s", resp.StatusCode, string(bodyBytes))
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to read response: %w", err)
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

	if len(data) == 0 || string(data) == "[]" {
		// Empty response - return empty comments
		return []models.Comment{}, totalCount, nil
	}

	comments, err := r.parseCommentsFromJSON(data)
	if err != nil {
		log.Printf("[CommentRepo] Error parsing comments JSON: %v, data: %s", err, string(data))
		return nil, 0, fmt.Errorf("failed to parse comments: %w", err)
	}

	// Load authors for all comments
	for i := range comments {
		if err := r.loadCommentAuthor(ctx, &comments[i]); err != nil {
			// Log error but continue - comment will just have no author
			log.Printf("[CommentRepo] Warning: Failed to load author for comment %s: %v", comments[i].ID, err)
		}

		// Load first few replies (preview) - skip if there's an error
		replies, _, err := r.GetCommentReplies(ctx, comments[i].ID, 3, 0)
		if err != nil {
			// Log error but continue - comment will just have no replies preview
			log.Printf("[CommentRepo] Warning: Failed to load replies for comment %s: %v", comments[i].ID, err)
		} else if len(replies) > 0 {
			comments[i].Replies = replies
		}
	}

	// Use totalCount from header if available, otherwise use len(comments)
	if totalCount == 0 {
		totalCount = len(comments)
	}

	return comments, totalCount, nil
}

// GetCommentReplies retrieves replies to a comment
func (r *SupabaseCommentRepository) GetCommentReplies(ctx context.Context, parentCommentID uuid.UUID, limit, offset int) ([]models.Comment, int, error) {
	query := fmt.Sprintf(
		"?parent_comment_id=eq.%s&deleted_at=is.null&select=*&order=created_at.asc&limit=%d&offset=%d",
		parentCommentID.String(), limit, offset,
	)

	data, err := r.makeRequest("GET", "post_comments", query, nil)
	if err != nil {
		return nil, 0, err
	}

	replies, err := r.parseCommentsFromJSON(data)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to parse comment replies: %w", err)
	}

	// Load authors
	for i := range replies {
		if err := r.loadCommentAuthor(ctx, &replies[i]); err != nil {
			// Log error but continue - reply will just have no author
			log.Printf("[CommentRepo] Warning: Failed to load author for reply %s: %v", replies[i].ID, err)
		}
	}

	return replies, len(replies), nil
}

// UpdateComment updates a comment's content
func (r *SupabaseCommentRepository) UpdateComment(ctx context.Context, commentID uuid.UUID, content string) error {
	updates := map[string]interface{}{
		"content":    content,
		"is_edited":  true,
		"edited_at":  time.Now(),
		"updated_at": time.Now(),
	}

	query := fmt.Sprintf("?id=eq.%s", commentID.String())

	_, err := r.makeRequest("PATCH", "post_comments", query, updates)
	return err
}

// DeleteComment soft deletes a comment
func (r *SupabaseCommentRepository) DeleteComment(ctx context.Context, commentID, userID uuid.UUID) error {
	// Verify ownership
	comment, err := r.GetComment(ctx, commentID)
	if err != nil {
		return err
	}

	if comment.UserID != userID {
		return models.ErrUnauthorized
	}

	// Soft delete
	updates := map[string]interface{}{
		"deleted_at": time.Now(),
		"content":    "[deleted]",
	}

	query := fmt.Sprintf("?id=eq.%s", commentID.String())
	_, err = r.makeRequest("PATCH", "post_comments", query, updates)

	return err
}

// LikeComment adds a like to a comment
func (r *SupabaseCommentRepository) LikeComment(ctx context.Context, commentID, userID uuid.UUID) error {
	payload := map[string]interface{}{
		"comment_id": commentID,
		"user_id":    userID,
	}

	_, err := r.makeRequest("POST", "comment_likes", "", payload)
	if err != nil {
		if strings.Contains(err.Error(), "duplicate") {
			return nil // Already liked
		}
		return fmt.Errorf("failed to like comment: %w", err)
	}

	return nil
}

// UnlikeComment removes a like from a comment
func (r *SupabaseCommentRepository) UnlikeComment(ctx context.Context, commentID, userID uuid.UUID) error {
	query := fmt.Sprintf("?comment_id=eq.%s&user_id=eq.%s", commentID.String(), userID.String())

	_, err := r.makeRequest("DELETE", "comment_likes", query, nil)
	return err
}

// IsCommentLikedByUser checks if a user has liked a comment
func (r *SupabaseCommentRepository) IsCommentLikedByUser(ctx context.Context, commentID, userID uuid.UUID) (bool, error) {
	query := fmt.Sprintf("?comment_id=eq.%s&user_id=eq.%s&select=id", commentID.String(), userID.String())

	data, err := r.makeRequest("GET", "comment_likes", query, nil)
	if err != nil {
		return false, nil
	}

	var likes []map[string]interface{}
	if err := json.Unmarshal(data, &likes); err != nil {
		return false, nil
	}

	return len(likes) > 0, nil
}

// GetCommentLikes retrieves users who liked a comment
func (r *SupabaseCommentRepository) GetCommentLikes(ctx context.Context, commentID uuid.UUID, limit, offset int) ([]models.User, int, error) {
	// Would require join or RPC
	return []models.User{}, 0, nil
}

// loadCommentAuthor loads the author for a comment
func (r *SupabaseCommentRepository) loadCommentAuthor(ctx context.Context, comment *models.Comment) error {
	query := fmt.Sprintf("?id=eq.%s&select=id,username,display_name,profile_picture,is_verified", comment.UserID.String())

	data, err := r.makeRequest("GET", "users", query, nil)
	if err != nil {
		return err
	}

	var users []models.User
	if err := json.Unmarshal(data, &users); err != nil {
		return err
	}

	if len(users) > 0 {
		comment.Author = &users[0]
	}

	return nil
}

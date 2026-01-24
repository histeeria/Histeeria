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
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// SupabaseNotificationRepository implements NotificationRepository using Supabase
type SupabaseNotificationRepository struct {
	supabaseURL string
	apiKey      string
	httpClient  *http.Client
}

// NewSupabaseNotificationRepository creates a new Supabase notification repository
func NewSupabaseNotificationRepository(supabaseURL, apiKey string) *SupabaseNotificationRepository {
	return &SupabaseNotificationRepository{
		supabaseURL: supabaseURL,
		apiKey:      apiKey,
		httpClient:  &http.Client{Timeout: 10 * time.Second},
	}
}

// Helper to build URLs
func (r *SupabaseNotificationRepository) notificationsURL(query url.Values) string {
	base := fmt.Sprintf("%s/rest/v1/notifications", r.supabaseURL)
	if len(query) > 0 {
		return fmt.Sprintf("%s?%s", base, query.Encode())
	}
	return base
}

func (r *SupabaseNotificationRepository) preferencesURL(query url.Values) string {
	base := fmt.Sprintf("%s/rest/v1/notification_preferences", r.supabaseURL)
	if len(query) > 0 {
		return fmt.Sprintf("%s?%s", base, query.Encode())
	}
	return base
}

// Helper to set common headers
func (r *SupabaseNotificationRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

// =====================================================
// NOTIFICATION CRUD
// =====================================================

// Create creates a new notification
func (r *SupabaseNotificationRepository) Create(ctx context.Context, notification *models.Notification) error {
	log.Printf("[NotificationRepo] Creating notification: type=%s user=%s", notification.Type, notification.UserID)

	// Build JSON payload
	payload := map[string]interface{}{
		"user_id":       notification.UserID.String(),
		"type":          string(notification.Type),
		"category":      string(notification.Category),
		"title":         notification.Title,
		"is_read":       false,
		"is_actionable": notification.IsActionable,
		"action_taken":  false,
	}

	if notification.Message != nil {
		payload["message"] = *notification.Message
	}
	if notification.ActorID != nil {
		payload["actor_id"] = notification.ActorID.String()
	}
	if notification.TargetID != nil {
		payload["target_id"] = notification.TargetID.String()
	}
	if notification.TargetType != nil {
		payload["target_type"] = *notification.TargetType
	}
	if notification.ActionURL != nil {
		payload["action_url"] = *notification.ActionURL
	}
	if notification.ActionType != nil {
		payload["action_type"] = *notification.ActionType
	}
	if len(notification.Metadata) > 0 {
		payload["metadata"] = notification.Metadata
	}

	body, err := json.Marshal(payload)
	if err != nil {
		log.Printf("[NotificationRepo] Failed to marshal payload: %v", err)
		return fmt.Errorf("failed to marshal notification: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.notificationsURL(nil), bytes.NewReader(body))
	if err != nil {
		return err
	}
	r.setHeaders(req, "return=representation")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		log.Printf("[NotificationRepo] HTTP request failed: %v", err)
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[NotificationRepo] Create failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return fmt.Errorf("failed to create notification: %d", resp.StatusCode)
	}

	// Parse response to get the created notification with ID
	var created []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&created); err != nil {
		return err
	}

	if len(created) > 0 {
		if idStr, ok := created[0]["id"].(string); ok {
			notification.ID, _ = uuid.Parse(idStr)
		}
		log.Printf("[NotificationRepo] Notification created successfully: id=%s", notification.ID)
	}

	return nil
}

// GetByID retrieves a single notification by ID
func (r *SupabaseNotificationRepository) GetByID(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*models.Notification, error) {
	q := url.Values{}
	q.Set("id", "eq."+id.String())
	q.Set("user_id", "eq."+userID.String())
	q.Set("select", "*,actor:users!actor_id(id,username,display_name,profile_picture,is_verified)")

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.notificationsURL(q), nil)
	if err != nil {
		return nil, err
	}
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("notification not found")
	}

	var notifications []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&notifications); err != nil {
		return nil, err
	}

	if len(notifications) == 0 {
		return nil, fmt.Errorf("notification not found")
	}

	return r.parseNotification(notifications[0])
}

// GetByUser retrieves notifications for a user with filters
func (r *SupabaseNotificationRepository) GetByUser(ctx context.Context, userID uuid.UUID, category *models.NotificationCategory, unread *bool, limit int, offset int) ([]*models.Notification, int, error) {
	q := url.Values{}
	q.Set("user_id", "eq."+userID.String())
	q.Set("order", "created_at.desc")
	q.Set("limit", fmt.Sprintf("%d", limit))
	q.Set("offset", fmt.Sprintf("%d", offset))
	q.Set("select", "*,actor:users!actor_id(id,username,display_name,profile_picture,is_verified)")

	if category != nil {
		q.Set("category", "eq."+string(*category))
	}
	if unread != nil && *unread {
		q.Set("is_read", "eq.false")
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.notificationsURL(q), nil)
	if err != nil {
		return nil, 0, err
	}
	r.setHeaders(req, "count=exact")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[NotificationRepo] GetByUser failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return nil, 0, fmt.Errorf("failed to fetch notifications: %d", resp.StatusCode)
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

	var rawNotifications []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&rawNotifications); err != nil {
		return nil, 0, err
	}

	notifications := make([]*models.Notification, 0, len(rawNotifications))
	for _, raw := range rawNotifications {
		notification, err := r.parseNotification(raw)
		if err != nil {
			log.Printf("[NotificationRepo] Failed to parse notification: %v", err)
			continue
		}
		notifications = append(notifications, notification)
	}

	log.Printf("[NotificationRepo] Fetched %d notifications (total: %d) for user %s", len(notifications), totalCount, userID)
	return notifications, totalCount, nil
}

// GetUnreadCount gets the count of unread notifications
func (r *SupabaseNotificationRepository) GetUnreadCount(ctx context.Context, userID uuid.UUID, category *models.NotificationCategory) (int, error) {
	q := url.Values{}
	q.Set("user_id", "eq."+userID.String())
	q.Set("is_read", "eq.false")
	q.Set("select", "id")

	if category != nil {
		q.Set("category", "eq."+string(*category))
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.notificationsURL(q), nil)
	if err != nil {
		return 0, err
	}
	r.setHeaders(req, "count=exact")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	// Parse count from Content-Range header
	if contentRange := resp.Header.Get("Content-Range"); contentRange != "" {
		var total int
		if n, _ := fmt.Sscanf(contentRange, "*/%d", &total); n == 1 {
			return total, nil
		}
		var start, end int
		if n, _ := fmt.Sscanf(contentRange, "%d-%d/%d", &start, &end, &total); n == 3 {
			return total, nil
		}
	}

	return 0, nil
}

// GetCategoryCounts gets unread counts per category
func (r *SupabaseNotificationRepository) GetCategoryCounts(ctx context.Context, userID uuid.UUID) (map[string]int, error) {
	counts := make(map[string]int)

	categories := []models.NotificationCategory{
		models.CategorySocial,
		models.CategoryMessages,
		models.CategoryProjects,
		models.CategoryCommunities,
		models.CategoryPayments,
		models.CategorySystem,
	}

	for _, category := range categories {
		count, err := r.GetUnreadCount(ctx, userID, &category)
		if err != nil {
			log.Printf("[NotificationRepo] Failed to get count for category %s: %v", category, err)
			continue
		}
		counts[string(category)] = count
	}

	return counts, nil
}

// MarkAsRead marks a notification as read
func (r *SupabaseNotificationRepository) MarkAsRead(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	update := map[string]interface{}{
		"is_read": true,
	}

	body, err := json.Marshal(update)
	if err != nil {
		return err
	}

	q := url.Values{}
	q.Set("id", "eq."+id.String())
	q.Set("user_id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.notificationsURL(q), bytes.NewReader(body))
	if err != nil {
		return err
	}
	r.setHeaders(req, "return=minimal")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[NotificationRepo] MarkAsRead failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return fmt.Errorf("failed to mark as read: %d", resp.StatusCode)
	}

	log.Printf("[NotificationRepo] Marked notification %s as read", id)
	return nil
}

// MarkAllAsRead marks all notifications as read for a user
func (r *SupabaseNotificationRepository) MarkAllAsRead(ctx context.Context, userID uuid.UUID, category *models.NotificationCategory) error {
	update := map[string]interface{}{
		"is_read": true,
	}

	body, err := json.Marshal(update)
	if err != nil {
		return err
	}

	q := url.Values{}
	q.Set("user_id", "eq."+userID.String())
	q.Set("is_read", "eq.false")

	if category != nil {
		q.Set("category", "eq."+string(*category))
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.notificationsURL(q), bytes.NewReader(body))
	if err != nil {
		return err
	}
	r.setHeaders(req, "return=minimal")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[NotificationRepo] MarkAllAsRead failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return fmt.Errorf("failed to mark all as read: %d", resp.StatusCode)
	}

	categoryStr := "all"
	if category != nil {
		categoryStr = string(*category)
	}
	log.Printf("[NotificationRepo] Marked all %s notifications as read for user %s", categoryStr, userID)
	return nil
}

// Delete deletes a notification
func (r *SupabaseNotificationRepository) Delete(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	q := url.Values{}
	q.Set("id", "eq."+id.String())
	q.Set("user_id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, r.notificationsURL(q), nil)
	if err != nil {
		return err
	}
	r.setHeaders(req, "return=minimal")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[NotificationRepo] Delete failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return fmt.Errorf("failed to delete notification: %d", resp.StatusCode)
	}

	log.Printf("[NotificationRepo] Deleted notification %s", id)
	return nil
}

// UpdateActionTaken marks that an action was taken on a notification
func (r *SupabaseNotificationRepository) UpdateActionTaken(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	update := map[string]interface{}{
		"action_taken": true,
		"is_read":      true, // Also mark as read
	}

	body, err := json.Marshal(update)
	if err != nil {
		return err
	}

	q := url.Values{}
	q.Set("id", "eq."+id.String())
	q.Set("user_id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.notificationsURL(q), bytes.NewReader(body))
	if err != nil {
		return err
	}
	r.setHeaders(req, "return=minimal")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[NotificationRepo] UpdateActionTaken failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return fmt.Errorf("failed to update action taken: %d", resp.StatusCode)
	}

	log.Printf("[NotificationRepo] Updated action taken for notification %s", id)
	return nil
}

// =====================================================
// PREFERENCES
// =====================================================

// GetPreferences retrieves notification preferences for a user
func (r *SupabaseNotificationRepository) GetPreferences(ctx context.Context, userID uuid.UUID) (*models.NotificationPreferences, error) {
	q := url.Values{}
	q.Set("user_id", "eq."+userID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.preferencesURL(q), nil)
	if err != nil {
		return nil, err
	}
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("preferences not found")
	}

	var prefs []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&prefs); err != nil {
		return nil, err
	}

	if len(prefs) == 0 {
		return nil, fmt.Errorf("preferences not found")
	}

	return r.parsePreferences(prefs[0])
}

// UpsertPreferences creates or updates notification preferences
func (r *SupabaseNotificationRepository) UpsertPreferences(ctx context.Context, prefs *models.NotificationPreferences) error {
	payload := map[string]interface{}{
		"user_id": prefs.UserID.String(),
	}

	if prefs.EmailEnabled {
		payload["email_enabled"] = prefs.EmailEnabled
	}
	if prefs.EmailTypes != nil {
		payload["email_types"] = prefs.EmailTypes
	}
	if prefs.EmailFrequency != "" {
		payload["email_frequency"] = string(prefs.EmailFrequency)
	}
	if prefs.InAppEnabled {
		payload["in_app_enabled"] = prefs.InAppEnabled
	}
	if prefs.PushEnabled {
		payload["push_enabled"] = prefs.PushEnabled
	}
	if prefs.InlineActionsEnabled {
		payload["inline_actions_enabled"] = prefs.InlineActionsEnabled
	}
	if prefs.CategoriesEnabled != nil {
		payload["categories_enabled"] = prefs.CategoriesEnabled
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.preferencesURL(nil), bytes.NewReader(body))
	if err != nil {
		return err
	}
	r.setHeaders(req, "resolution=merge-duplicates,return=minimal")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[NotificationRepo] UpsertPreferences failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return fmt.Errorf("failed to upsert preferences: %d", resp.StatusCode)
	}

	log.Printf("[NotificationRepo] Upserted preferences for user %s", prefs.UserID)
	return nil
}

// =====================================================
// CLEANUP
// =====================================================

// DeleteExpired deletes notifications that have passed their expiry date
func (r *SupabaseNotificationRepository) DeleteExpired(ctx context.Context) (int, error) {
	q := url.Values{}
	q.Set("expires_at", "lt."+time.Now().Format(time.RFC3339))

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, r.notificationsURL(q), nil)
	if err != nil {
		return 0, err
	}
	r.setHeaders(req, "count=exact,return=minimal")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	// Parse count from Content-Range header
	deletedCount := 0
	if contentRange := resp.Header.Get("Content-Range"); contentRange != "" {
		var total int
		if n, _ := fmt.Sscanf(contentRange, "*/%d", &total); n == 1 {
			deletedCount = total
		}
	}

	log.Printf("[NotificationRepo] Deleted %d expired notifications", deletedCount)
	return deletedCount, nil
}

// GetUnreadForDigest retrieves unread notifications for users based on email frequency
func (r *SupabaseNotificationRepository) GetUnreadForDigest(ctx context.Context, frequency models.EmailFrequency) (map[uuid.UUID][]*models.Notification, error) {
	// This would need a more complex query joining with preferences
	// For now, return empty map - will implement in digest service
	return make(map[uuid.UUID][]*models.Notification), nil
}

// =====================================================
// HELPER METHODS
// =====================================================

// parseNotification converts raw JSON to Notification model
func (r *SupabaseNotificationRepository) parseNotification(raw map[string]interface{}) (*models.Notification, error) {
	notification := &models.Notification{
		IsRead:       false,
		IsActionable: false,
		ActionTaken:  false,
		Metadata:     make(map[string]interface{}),
	}

	// Parse ID
	if idStr, ok := raw["id"].(string); ok {
		notification.ID, _ = uuid.Parse(idStr)
	}

	// Parse UserID
	if userIDStr, ok := raw["user_id"].(string); ok {
		notification.UserID, _ = uuid.Parse(userIDStr)
	}

	// Parse Type
	if typeStr, ok := raw["type"].(string); ok {
		notification.Type = models.NotificationType(typeStr)
	}

	// Parse Category
	if categoryStr, ok := raw["category"].(string); ok {
		notification.Category = models.NotificationCategory(categoryStr)
	}

	// Parse strings
	if title, ok := raw["title"].(string); ok {
		notification.Title = title
	}
	if message, ok := raw["message"].(string); ok {
		notification.Message = &message
	}
	if actionURL, ok := raw["action_url"].(string); ok {
		notification.ActionURL = &actionURL
	}
	if actionType, ok := raw["action_type"].(string); ok {
		notification.ActionType = &actionType
	}
	if targetType, ok := raw["target_type"].(string); ok {
		notification.TargetType = &targetType
	}

	// Parse UUIDs
	if actorIDStr, ok := raw["actor_id"].(string); ok && actorIDStr != "" {
		actorID, _ := uuid.Parse(actorIDStr)
		notification.ActorID = &actorID
	}
	if targetIDStr, ok := raw["target_id"].(string); ok && targetIDStr != "" {
		targetID, _ := uuid.Parse(targetIDStr)
		notification.TargetID = &targetID
	}

	// Parse booleans
	if isRead, ok := raw["is_read"].(bool); ok {
		notification.IsRead = isRead
	}
	if isActionable, ok := raw["is_actionable"].(bool); ok {
		notification.IsActionable = isActionable
	}
	if actionTaken, ok := raw["action_taken"].(bool); ok {
		notification.ActionTaken = actionTaken
	}

	// Parse metadata
	if metadata, ok := raw["metadata"].(map[string]interface{}); ok {
		notification.Metadata = metadata
	}

	// Parse timestamps
	if createdAt, ok := raw["created_at"].(string); ok {
		notification.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	if expiresAt, ok := raw["expires_at"].(string); ok {
		notification.ExpiresAt, _ = time.Parse(time.RFC3339, expiresAt)
	}

	// Parse actor (joined user data)
	if actor, ok := raw["actor"].(map[string]interface{}); ok && actor != nil {
		notification.ActorUser = &models.User{}
		if idStr, ok := actor["id"].(string); ok {
			notification.ActorUser.ID, _ = uuid.Parse(idStr)
		}
		if username, ok := actor["username"].(string); ok {
			notification.ActorUser.Username = username
		}
		if displayName, ok := actor["display_name"].(string); ok {
			notification.ActorUser.DisplayName = displayName
		}
		if profilePic, ok := actor["profile_picture"].(string); ok {
			notification.ActorUser.ProfilePicture = &profilePic
		}
		if isVerified, ok := actor["is_verified"].(bool); ok {
			notification.ActorUser.IsVerified = isVerified
		}
	}

	return notification, nil
}

// parsePreferences converts raw JSON to NotificationPreferences model
func (r *SupabaseNotificationRepository) parsePreferences(raw map[string]interface{}) (*models.NotificationPreferences, error) {
	prefs := &models.NotificationPreferences{
		EmailTypes:        make(map[string]bool),
		CategoriesEnabled: make(map[string]bool),
	}

	// Parse UserID
	if userIDStr, ok := raw["user_id"].(string); ok {
		prefs.UserID, _ = uuid.Parse(userIDStr)
	}

	// Parse booleans
	if emailEnabled, ok := raw["email_enabled"].(bool); ok {
		prefs.EmailEnabled = emailEnabled
	}
	if inAppEnabled, ok := raw["in_app_enabled"].(bool); ok {
		prefs.InAppEnabled = inAppEnabled
	}
	if pushEnabled, ok := raw["push_enabled"].(bool); ok {
		prefs.PushEnabled = pushEnabled
	}
	if inlineActionsEnabled, ok := raw["inline_actions_enabled"].(bool); ok {
		prefs.InlineActionsEnabled = inlineActionsEnabled
	}

	// Parse email frequency
	if frequency, ok := raw["email_frequency"].(string); ok {
		prefs.EmailFrequency = models.EmailFrequency(frequency)
	}

	// Parse JSONB maps
	if emailTypes, ok := raw["email_types"].(map[string]interface{}); ok {
		for k, v := range emailTypes {
			if boolVal, ok := v.(bool); ok {
				prefs.EmailTypes[k] = boolVal
			}
		}
	}
	if categoriesEnabled, ok := raw["categories_enabled"].(map[string]interface{}); ok {
		for k, v := range categoriesEnabled {
			if boolVal, ok := v.(bool); ok {
				prefs.CategoriesEnabled[k] = boolVal
			}
		}
	}

	// Parse timestamp
	if updatedAt, ok := raw["updated_at"].(string); ok {
		prefs.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	}

	return prefs, nil
}

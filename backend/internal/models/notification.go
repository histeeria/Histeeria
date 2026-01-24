package models

import (
	"time"

	"github.com/google/uuid"
)

// =====================================================
// NOTIFICATION TYPES & CATEGORIES
// =====================================================

// NotificationType represents the type of notification
type NotificationType string

const (
	// Social notifications
	NotificationFollow                NotificationType = "follow"
	NotificationFollowBack            NotificationType = "follow_back"
	NotificationConnectionRequest     NotificationType = "connection_request"
	NotificationConnectionAccepted    NotificationType = "connection_accepted"
	NotificationConnectionRejected    NotificationType = "connection_rejected"
	NotificationCollaborationRequest  NotificationType = "collaboration_request"
	NotificationCollaborationAccepted NotificationType = "collaboration_accepted"
	NotificationCollaborationRejected NotificationType = "collaboration_rejected"

	// Future: Messaging notifications
	NotificationMessage NotificationType = "message"

	// Future: Post/Feed notifications
	NotificationPostLike    NotificationType = "post_like"
	NotificationPostComment NotificationType = "post_comment"
	NotificationPostMention NotificationType = "post_mention"

	// Future: Project notifications
	NotificationProjectInvite NotificationType = "project_invite"
	NotificationProjectUpdate NotificationType = "project_update"

	// Future: Community notifications
	NotificationCommunityInvite NotificationType = "community_invite"
	NotificationCommunityPost   NotificationType = "community_post"

	// Future: Payment notifications
	NotificationPaymentReceived NotificationType = "payment_received"
	NotificationPaymentSent     NotificationType = "payment_sent"

	// System notifications
	NotificationSystemAnnouncement NotificationType = "system_announcement"
)

// NotificationCategory represents the category for filtering
type NotificationCategory string

const (
	CategorySocial      NotificationCategory = "social"
	CategoryMessages    NotificationCategory = "messages"
	CategoryProjects    NotificationCategory = "projects"
	CategoryCommunities NotificationCategory = "communities"
	CategoryPayments    NotificationCategory = "payments"
	CategorySystem      NotificationCategory = "system"
)

// EmailFrequency represents how often to send email digests
type EmailFrequency string

const (
	EmailFrequencyInstant EmailFrequency = "instant"
	EmailFrequencyDaily   EmailFrequency = "daily"
	EmailFrequencyWeekly  EmailFrequency = "weekly"
	EmailFrequencyNever   EmailFrequency = "never"
)

// =====================================================
// CORE MODELS
// =====================================================

// Notification represents a user notification
type Notification struct {
	ID           uuid.UUID              `json:"id" db:"id"`
	UserID       uuid.UUID              `json:"user_id" db:"user_id"`
	Type         NotificationType       `json:"type" db:"type"`
	Category     NotificationCategory   `json:"category" db:"category"`
	Title        string                 `json:"title" db:"title"`
	Message      *string                `json:"message,omitempty" db:"message"`
	ActorID      *uuid.UUID             `json:"actor_id,omitempty" db:"actor_id"`
	ActorUser    *User                  `json:"actor,omitempty" db:"-"` // Populated when fetched with join
	TargetID     *uuid.UUID             `json:"target_id,omitempty" db:"target_id"`
	TargetType   *string                `json:"target_type,omitempty" db:"target_type"`
	ActionURL    *string                `json:"action_url,omitempty" db:"action_url"`
	IsRead       bool                   `json:"is_read" db:"is_read"`
	IsActionable bool                   `json:"is_actionable" db:"is_actionable"`
	ActionType   *string                `json:"action_type,omitempty" db:"action_type"`
	ActionTaken  bool                   `json:"action_taken" db:"action_taken"`
	Metadata     map[string]interface{} `json:"metadata,omitempty" db:"metadata"`
	CreatedAt    time.Time              `json:"created_at" db:"created_at"`
	ExpiresAt    time.Time              `json:"expires_at" db:"expires_at"`
}

// NotificationPreferences represents user notification settings
type NotificationPreferences struct {
	UserID               uuid.UUID       `json:"user_id" db:"user_id"`
	EmailEnabled         bool            `json:"email_enabled" db:"email_enabled"`
	EmailTypes           map[string]bool `json:"email_types" db:"email_types"`
	EmailFrequency       EmailFrequency  `json:"email_frequency" db:"email_frequency"`
	InAppEnabled         bool            `json:"in_app_enabled" db:"in_app_enabled"`
	PushEnabled          bool            `json:"push_enabled" db:"push_enabled"`
	InlineActionsEnabled bool            `json:"inline_actions_enabled" db:"inline_actions_enabled"`
	CategoriesEnabled    map[string]bool `json:"categories_enabled" db:"categories_enabled"`
	UpdatedAt            time.Time       `json:"updated_at" db:"updated_at"`
}

// =====================================================
// API RESPONSE MODELS
// =====================================================

// NotificationResponse is the API response for a notification
type NotificationResponse struct {
	ID           uuid.UUID              `json:"id"`
	Type         NotificationType       `json:"type"`
	Category     NotificationCategory   `json:"category"`
	Title        string                 `json:"title"`
	Message      *string                `json:"message,omitempty"`
	Actor        *NotificationActor     `json:"actor,omitempty"`
	ActionURL    *string                `json:"action_url,omitempty"`
	IsRead       bool                   `json:"is_read"`
	IsActionable bool                   `json:"is_actionable"`
	ActionType   *string                `json:"action_type,omitempty"`
	ActionTaken  bool                   `json:"action_taken"`
	Metadata     map[string]interface{} `json:"metadata,omitempty"`
	CreatedAt    time.Time              `json:"created_at"`
}

// NotificationActor represents the user who triggered the notification
type NotificationActor struct {
	ID             uuid.UUID `json:"id"`
	Username       string    `json:"username"`
	DisplayName    string    `json:"display_name"`
	ProfilePicture *string   `json:"profile_picture,omitempty"`
	IsVerified     bool      `json:"is_verified"`
}

// NotificationListResponse is the paginated list response
type NotificationListResponse struct {
	Success       bool                    `json:"success"`
	Notifications []*NotificationResponse `json:"notifications"`
	Total         int                     `json:"total"`
	Unread        int                     `json:"unread"`
	Limit         int                     `json:"limit"`
	Offset        int                     `json:"offset"`
}

// NotificationCountResponse returns unread counts
type NotificationCountResponse struct {
	Success        bool           `json:"success"`
	Total          int            `json:"total"`
	CategoryCounts map[string]int `json:"category_counts"`
}

// =====================================================
// REQUEST MODELS
// =====================================================

// MarkAsReadRequest for marking notifications as read
type MarkAsReadRequest struct {
	NotificationIDs []uuid.UUID           `json:"notification_ids,omitempty"`
	Category        *NotificationCategory `json:"category,omitempty"`
	MarkAll         bool                  `json:"mark_all"`
}

// TakeActionRequest for inline notification actions
type TakeActionRequest struct {
	ActionType string `json:"action_type" validate:"required"`
}

// UpdateNotificationPreferencesRequest for updating preferences
type UpdateNotificationPreferencesRequest struct {
	EmailEnabled         *bool           `json:"email_enabled,omitempty"`
	EmailTypes           map[string]bool `json:"email_types,omitempty"`
	EmailFrequency       *EmailFrequency `json:"email_frequency,omitempty"`
	InAppEnabled         *bool           `json:"in_app_enabled,omitempty"`
	PushEnabled          *bool           `json:"push_enabled,omitempty"`
	InlineActionsEnabled *bool           `json:"inline_actions_enabled,omitempty"`
	CategoriesEnabled    map[string]bool `json:"categories_enabled,omitempty"`
}

// =====================================================
// WEBSOCKET MESSAGES
// =====================================================

// WSMessage represents a WebSocket message
type WSMessage struct {
	Type string      `json:"type"` // "notification", "ping", "pong", "error"
	Data interface{} `json:"data,omitempty"`
}

// WSNotificationMessage is sent when a new notification arrives
type WSNotificationMessage struct {
	Type         string                `json:"type"`
	Notification *NotificationResponse `json:"notification"`
}

// WSCountUpdateMessage is sent when unread count changes
type WSCountUpdateMessage struct {
	Type           string         `json:"type"`
	Total          int            `json:"total"`
	CategoryCounts map[string]int `json:"category_counts"`
}

// =====================================================
// HELPER METHODS
// =====================================================

// ToResponse converts a Notification to NotificationResponse
func (n *Notification) ToResponse() *NotificationResponse {
	resp := &NotificationResponse{
		ID:           n.ID,
		Type:         n.Type,
		Category:     n.Category,
		Title:        n.Title,
		Message:      n.Message,
		ActionURL:    n.ActionURL,
		IsRead:       n.IsRead,
		IsActionable: n.IsActionable,
		ActionType:   n.ActionType,
		ActionTaken:  n.ActionTaken,
		Metadata:     n.Metadata,
		CreatedAt:    n.CreatedAt,
	}

	// Add actor if available
	if n.ActorUser != nil {
		resp.Actor = &NotificationActor{
			ID:             n.ActorUser.ID,
			Username:       n.ActorUser.Username,
			DisplayName:    n.ActorUser.DisplayName,
			ProfilePicture: n.ActorUser.ProfilePicture,
			IsVerified:     n.ActorUser.IsVerified,
		}
	}

	return resp
}

// GetCategoryForType returns the category for a notification type
func GetCategoryForType(notifType NotificationType) NotificationCategory {
	switch notifType {
	case NotificationFollow,
		NotificationFollowBack,
		NotificationConnectionRequest,
		NotificationConnectionAccepted,
		NotificationConnectionRejected,
		NotificationCollaborationRequest,
		NotificationCollaborationAccepted,
		NotificationCollaborationRejected:
		return CategorySocial

	case NotificationMessage:
		return CategoryMessages

	case NotificationPostLike,
		NotificationPostComment,
		NotificationPostMention:
		return CategorySocial

	case NotificationProjectInvite,
		NotificationProjectUpdate:
		return CategoryProjects

	case NotificationCommunityInvite,
		NotificationCommunityPost:
		return CategoryCommunities

	case NotificationPaymentReceived,
		NotificationPaymentSent:
		return CategoryPayments

	case NotificationSystemAnnouncement:
		return CategorySystem

	default:
		return CategorySystem
	}
}

// ShouldSendEmail checks if this notification type should send email
func (p *NotificationPreferences) ShouldSendEmail(notifType NotificationType) bool {
	if !p.EmailEnabled {
		return false
	}

	if p.EmailFrequency == EmailFrequencyNever {
		return false
	}

	// Check if this specific type is enabled
	if enabled, exists := p.EmailTypes[string(notifType)]; exists {
		return enabled
	}

	// Default to false for unknown types
	return false
}

// IsCategoryEnabled checks if a category is enabled
func (p *NotificationPreferences) IsCategoryEnabled(category NotificationCategory) bool {
	if !p.InAppEnabled {
		return false
	}

	if enabled, exists := p.CategoriesEnabled[string(category)]; exists {
		return enabled
	}

	// Default to true for unknown categories
	return true
}

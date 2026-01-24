package models

import (
	"time"

	"github.com/google/uuid"
)

// Status represents a 24-hour story/status
type Status struct {
	ID              uuid.UUID `json:"id" db:"id"`
	UserID          uuid.UUID `json:"user_id" db:"user_id"`
	StatusType      string    `json:"status_type" db:"status_type"` // 'text', 'image', 'video'
	Content         *string   `json:"content,omitempty" db:"content"`
	MediaURL        *string   `json:"media_url,omitempty" db:"media_url"`
	MediaType       *string   `json:"media_type,omitempty" db:"media_type"`
	BackgroundColor string    `json:"background_color" db:"background_color"`

	// Engagement stats
	ViewsCount     int `json:"views_count" db:"views_count"`
	ReactionsCount int `json:"reactions_count" db:"reactions_count"`
	CommentsCount  int `json:"comments_count" db:"comments_count"`

	// Expiration (24 hours from creation)
	ExpiresAt time.Time `json:"expires_at" db:"expires_at"`

	// Timestamps
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`

	// Relations (populated by queries)
	Author       *User           `json:"author,omitempty"`
	IsViewed     bool            `json:"is_viewed" db:"is_viewed"` // Current user viewed this status
	UserReaction *string         `json:"user_reaction,omitempty"`  // Current user's reaction emoji
	Comments     []StatusComment `json:"comments,omitempty"`
}

// StatusComment represents a comment on a status
type StatusComment struct {
	ID        uuid.UUID  `json:"id" db:"id"`
	StatusID  uuid.UUID  `json:"status_id" db:"status_id"`
	UserID    uuid.UUID  `json:"user_id" db:"user_id"`
	Content   string     `json:"content" db:"content"`
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
	DeletedAt *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`

	// Relations
	Author *User `json:"author,omitempty"`
}

// StatusReaction represents an emoji reaction on a status
type StatusReaction struct {
	ID        uuid.UUID `json:"id" db:"id"`
	StatusID  uuid.UUID `json:"status_id" db:"status_id"`
	UserID    uuid.UUID `json:"user_id" db:"user_id"`
	Emoji     string    `json:"emoji" db:"emoji"` // '👍', '💯', '❤️', '🤝', '💡'
	CreatedAt time.Time `json:"created_at" db:"created_at"`

	// Relations
	User *User `json:"user,omitempty"`
}

// StatusView represents a view on a status
type StatusView struct {
	ID       uuid.UUID `json:"id" db:"id"`
	StatusID uuid.UUID `json:"status_id" db:"status_id"`
	UserID   uuid.UUID `json:"user_id" db:"user_id"`
	ViewedAt time.Time `json:"viewed_at" db:"viewed_at"`

	// Relations
	User *User `json:"user,omitempty"`
}

// CreateStatusRequest is the request body for creating a status
type CreateStatusRequest struct {
	StatusType      string  `json:"status_type" binding:"required,oneof=text image video"`
	Content         *string `json:"content,omitempty"`
	MediaURL        *string `json:"media_url,omitempty"`
	MediaType       *string `json:"media_type,omitempty"`
	BackgroundColor *string `json:"background_color,omitempty"` // Hex color for text statuses
}

// UpdateStatusRequest is the request body for updating a status (limited updates)
type UpdateStatusRequest struct {
	Content         *string `json:"content,omitempty"`
	BackgroundColor *string `json:"background_color,omitempty"`
}

// ReactToStatusRequest is the request body for reacting to a status
type ReactToStatusRequest struct {
	Emoji string `json:"emoji" binding:"required,oneof=👍 💯 ❤️ 🤝 💡"`
}

// CreateStatusCommentRequest is the request body for commenting on a status
type CreateStatusCommentRequest struct {
	Content string `json:"content" binding:"required,min=1,max=500"`
}

// StatusResponse is the API response for a status
type StatusResponse struct {
	Success bool    `json:"success"`
	Status  *Status `json:"status,omitempty"`
	Message string  `json:"message,omitempty"`
}

// StatusesResponse is the API response for multiple statuses
type StatusesResponse struct {
	Success  bool     `json:"success"`
	Statuses []Status `json:"statuses"`
	Total    int      `json:"total"`
	HasMore  bool     `json:"has_more"`
}

// StatusCommentsResponse is the API response for status comments
type StatusCommentsResponse struct {
	Success  bool            `json:"success"`
	Comments []StatusComment `json:"comments"`
	Total    int             `json:"total"`
	HasMore  bool            `json:"has_more"`
}

// Validate validates the status creation request
func (r *CreateStatusRequest) Validate() error {
	if r.StatusType == "text" {
		if r.Content == nil || *r.Content == "" {
			return &AppError{Code: "CONTENT_REQUIRED", Message: "Content is required for text statuses"}
		}
		if len(*r.Content) > 500 {
			return &AppError{Code: "CONTENT_TOO_LONG", Message: "Content must be 500 characters or less"}
		}
	} else if r.StatusType == "image" || r.StatusType == "video" {
		if r.MediaURL == nil || *r.MediaURL == "" {
			return &AppError{Code: "MEDIA_REQUIRED", Message: "Media URL is required for image/video statuses"}
		}
		if r.MediaType == nil || *r.MediaType == "" {
			return &AppError{Code: "MEDIA_TYPE_REQUIRED", Message: "Media type is required for image/video statuses"}
		}
	}
	return nil
}

// Status errors
var (
	ErrStatusNotFound     = &AppError{Code: "STATUS_NOT_FOUND", Message: "Status not found"}
	ErrStatusExpired      = &AppError{Code: "STATUS_EXPIRED", Message: "Status has expired"}
	ErrInvalidStatusType  = &AppError{Code: "INVALID_STATUS_TYPE", Message: "Invalid status type"}
	ErrStatusUnauthorized = &AppError{Code: "STATUS_UNAUTHORIZED", Message: "Not authorized to access this status"}
	ErrInvalidEmoji       = &AppError{Code: "INVALID_EMOJI", Message: "Invalid reaction emoji"}
	ErrCommentTooLong     = &AppError{Code: "COMMENT_TOO_LONG", Message: "Comment must be 500 characters or less"}
)

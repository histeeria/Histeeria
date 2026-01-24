package models

import (
	"time"

	"github.com/google/uuid"
)

// Comment represents a comment on a post
type Comment struct {
	ID              uuid.UUID  `json:"id"`
	PostID          uuid.UUID  `json:"post_id"`
	UserID          uuid.UUID  `json:"user_id"`
	ParentCommentID *uuid.UUID `json:"parent_comment_id,omitempty"`
	Content         string     `json:"content"`
	MediaURL        string     `json:"media_url,omitempty"`
	MediaType       string     `json:"media_type,omitempty"` // 'gif', 'image'
	LikesCount      int        `json:"likes_count"`
	RepliesCount    int        `json:"replies_count"`
	IsEdited        bool       `json:"is_edited"`
	EditedAt        *time.Time `json:"edited_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	DeletedAt       *time.Time `json:"deleted_at,omitempty"`

	// Relations (populated by queries)
	Author        *User     `json:"author,omitempty"`
	Replies       []Comment `json:"replies,omitempty"`
	IsLiked       bool      `json:"is_liked"` // Current user liked
	ParentComment *Comment  `json:"parent_comment,omitempty"`
}

// CreateCommentRequest is the request body for creating a comment
type CreateCommentRequest struct {
	PostID          uuid.UUID  `json:"post_id" binding:"required"`
	ParentCommentID *uuid.UUID `json:"parent_comment_id,omitempty"`
	Content         string     `json:"content" binding:"required,min=1,max=1000"`
	MediaURL        string     `json:"media_url,omitempty"`
	MediaType       string     `json:"media_type,omitempty"`
}

// UpdateCommentRequest is the request body for updating a comment
type UpdateCommentRequest struct {
	Content string `json:"content" binding:"required,min=1,max=1000"`
}

// CommentResponse is the API response for a comment
type CommentResponse struct {
	Success bool     `json:"success"`
	Comment *Comment `json:"comment,omitempty"`
	Message string   `json:"message,omitempty"`
}

// CommentsResponse is the API response for multiple comments
type CommentsResponse struct {
	Success  bool      `json:"success"`
	Comments []Comment `json:"comments"`
	Total    int       `json:"total"`
	Page     int       `json:"page"`
	Limit    int       `json:"limit"`
	HasMore  bool      `json:"has_more"`
}

// CommentLike represents a like on a comment
type CommentLike struct {
	ID        uuid.UUID `json:"id"`
	CommentID uuid.UUID `json:"comment_id"`
	UserID    uuid.UUID `json:"user_id"`
	CreatedAt time.Time `json:"created_at"`
	User      *User     `json:"user,omitempty"`
}

// Validate validates the comment creation request
func (r *CreateCommentRequest) Validate() error {
	if len(r.Content) == 0 {
		return &AppError{Code: "CONTENT_REQUIRED", Message: "Comment content is required"}
	}

	if len(r.Content) > 1000 {
		return &AppError{Code: "CONTENT_TOO_LONG", Message: "Comment must be 1000 characters or less"}
	}

	// If media is provided, validate type
	if r.MediaURL != "" && r.MediaType != "" {
		if r.MediaType != "gif" && r.MediaType != "image" {
			return &AppError{Code: "INVALID_MEDIA_TYPE", Message: "Only GIF and image are allowed in comments"}
		}
	}

	return nil
}

// IsReply returns true if this is a reply to another comment
func (c *Comment) IsReply() bool {
	return c.ParentCommentID != nil
}

// IsDeleted returns true if comment is soft-deleted
func (c *Comment) IsDeleted() bool {
	return c.DeletedAt != nil
}

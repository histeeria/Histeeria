package models

import (
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// Post represents a social media post (short post, poll, or article)
type Post struct {
	ID             uuid.UUID      `json:"id"`
	UserID         uuid.UUID      `json:"user_id"`
	PostType       string         `json:"post_type"` // 'post', 'poll', 'article'
	Content        string         `json:"content"`
	MediaURLs      pq.StringArray `json:"media_urls" db:"media_urls"`
	MediaTypes     pq.StringArray `json:"media_types" db:"media_types"`
	Visibility     string         `json:"visibility"`
	AllowsComments bool           `json:"allows_comments"`
	AllowsSharing  bool           `json:"allows_sharing"`

	// Engagement stats (denormalized)
	LikesCount    int `json:"likes_count"`
	CommentsCount int `json:"comments_count"`
	SharesCount   int `json:"shares_count"`
	ViewsCount    int `json:"views_count"`
	SavesCount    int `json:"saves_count"`

	// Features
	IsPinned   bool `json:"is_pinned"`
	IsFeatured bool `json:"is_featured"`
	IsNSFW     bool `json:"is_nsfw"`

	// Status
	IsPublished bool       `json:"is_published"`
	IsDraft     bool       `json:"is_draft"`
	PublishedAt *time.Time `json:"published_at"`

	// Timestamps
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `json:"deleted_at,omitempty"`

	// Relations (populated by queries)
	Author      *User     `json:"author,omitempty"`
	Poll        *Poll     `json:"poll,omitempty"`
	Article     *Article  `json:"article,omitempty"`
	IsLiked     bool      `json:"is_liked"` // Current user liked
	IsSaved     bool      `json:"is_saved"` // Current user saved
	TopComments []Comment `json:"top_comments,omitempty"`
	Hashtags    []string  `json:"hashtags,omitempty"`
}

// CreatePostRequest is the request body for creating a post
type CreatePostRequest struct {
	PostType       string   `json:"post_type" binding:"required,oneof=post poll article"`
	Content        string   `json:"content" binding:"required,max=125000"`
	MediaURLs      []string `json:"media_urls"`
	MediaTypes     []string `json:"media_types"`
	Visibility     string   `json:"visibility" binding:"oneof=public connections private"`
	AllowsComments bool     `json:"allows_comments"`
	AllowsSharing  bool     `json:"allows_sharing"`
	IsDraft        bool     `json:"is_draft"`
	IsNSFW         bool     `json:"is_nsfw"`

	// For polls
	Poll *CreatePollRequest `json:"poll,omitempty"`

	// For articles
	Article *CreateArticleRequest `json:"article,omitempty"`
}

// UpdatePostRequest is the request body for updating a post
type UpdatePostRequest struct {
	Content        *string `json:"content,omitempty"`
	Visibility     *string `json:"visibility,omitempty"`
	AllowsComments *bool   `json:"allows_comments,omitempty"`
	AllowsSharing  *bool   `json:"allows_sharing,omitempty"`
	IsNSFW         *bool   `json:"is_nsfw,omitempty"`
	IsPinned       *bool   `json:"is_pinned,omitempty"`
}

// PostResponse is the API response for a post
type PostResponse struct {
	Success bool   `json:"success"`
	Post    *Post  `json:"post,omitempty"`
	Message string `json:"message,omitempty"`
}

// PostsResponse is the API response for multiple posts
type PostsResponse struct {
	Success bool   `json:"success"`
	Posts   []Post `json:"posts"`
	Total   int    `json:"total"`
	Page    int    `json:"page"`
	Limit   int    `json:"limit"`
	HasMore bool   `json:"has_more"`
}

// PostLike represents a like on a post
type PostLike struct {
	ID        uuid.UUID `json:"id"`
	PostID    uuid.UUID `json:"post_id"`
	UserID    uuid.UUID `json:"user_id"`
	CreatedAt time.Time `json:"created_at"`
	User      *User     `json:"user,omitempty"`
}

// PostShare represents a share/repost
type PostShare struct {
	ID            uuid.UUID `json:"id"`
	PostID        uuid.UUID `json:"post_id"`
	UserID        uuid.UUID `json:"user_id"`
	RepostComment string    `json:"repost_comment,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
	User          *User     `json:"user,omitempty"`
	OriginalPost  *Post     `json:"original_post,omitempty"`
}

// SavedPost represents a bookmarked post
type SavedPost struct {
	ID             uuid.UUID `json:"id"`
	PostID         uuid.UUID `json:"post_id"`
	UserID         uuid.UUID `json:"user_id"`
	CollectionName string    `json:"collection_name"`
	SavedAt        time.Time `json:"saved_at"`
	Post           *Post     `json:"post,omitempty"`
}

// Validate validates the post creation request
func (r *CreatePostRequest) Validate() error {
	// Validate content length based on type
	if r.PostType == "post" && len(r.Content) > 3000 {
		return ErrContentTooLong
	}

	// Validate media limits
	if r.PostType == "post" {
		if len(r.MediaURLs) > 10 {
			return ErrTooManyImages
		}
		// Check for video count
		videoCount := 0
		for _, mediaType := range r.MediaTypes {
			if mediaType == "video" {
				videoCount++
			}
		}
		if videoCount > 1 {
			return ErrTooManyVideos
		}
	}

	// Poll must have poll data
	if r.PostType == "poll" && r.Poll == nil {
		return ErrPollDataRequired
	}

	// Article must have article data
	if r.PostType == "article" && r.Article == nil {
		return ErrArticleDataRequired
	}

	return nil
}

// Custom errors
var (
	ErrContentTooLong      = &AppError{Code: "CONTENT_TOO_LONG", Message: "Content exceeds maximum length"}
	ErrTooManyImages       = &AppError{Code: "TOO_MANY_IMAGES", Message: "Maximum 10 images per post"}
	ErrTooManyVideos       = &AppError{Code: "TOO_MANY_VIDEOS", Message: "Maximum 1 video per post"}
	ErrPollDataRequired    = &AppError{Code: "POLL_DATA_REQUIRED", Message: "Poll data is required for poll posts"}
	ErrArticleDataRequired = &AppError{Code: "ARTICLE_DATA_REQUIRED", Message: "Article data is required for article posts"}
	ErrPostNotFound        = &AppError{Code: "POST_NOT_FOUND", Message: "Post not found"}
	ErrUnauthorized        = &AppError{Code: "UNAUTHORIZED", Message: "Not authorized to perform this action"}
)

// AppError represents a custom application error
type AppError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func (e *AppError) Error() string {
	return e.Message
}

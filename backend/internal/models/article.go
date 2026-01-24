package models

import (
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/gosimple/slug"
)

// Article represents a long-form blog post or article
type Article struct {
	ID              uuid.UUID `json:"id"`
	PostID          uuid.UUID `json:"post_id"`
	Title           string    `json:"title"`
	Subtitle        string    `json:"subtitle,omitempty"`
	ContentHTML     string    `json:"content_html"`
	CoverImageURL   string    `json:"cover_image_url,omitempty"`
	MetaTitle       string    `json:"meta_title,omitempty"`
	MetaDescription string    `json:"meta_description,omitempty"`
	Slug            string    `json:"slug"`
	ReadTimeMinutes int       `json:"read_time_minutes"`
	Category        string    `json:"category,omitempty"`
	ViewsCount      int       `json:"views_count"`
	ReadsCount      int       `json:"reads_count"` // Full reads (scrolled to end)
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
	Tags            []string  `json:"tags,omitempty"`

	// Populated from post
	Post *Post `json:"post,omitempty"`
}

// CreateArticleRequest is the request body for creating an article
type CreateArticleRequest struct {
	Title           string   `json:"title" binding:"required,max=100"`
	Subtitle        string   `json:"subtitle,omitempty" binding:"max=150"`
	ContentHTML     string   `json:"content_html" binding:"required"`
	CoverImageURL   string   `json:"cover_image_url,omitempty"`
	MetaTitle       string   `json:"meta_title,omitempty" binding:"max=60"`
	MetaDescription string   `json:"meta_description,omitempty" binding:"max=160"`
	Category        string   `json:"category,omitempty" binding:"max=50"`
	Tags            []string `json:"tags,omitempty" binding:"max=5"`
}

// UpdateArticleRequest is the request body for updating an article
type UpdateArticleRequest struct {
	Title           *string  `json:"title,omitempty"`
	Subtitle        *string  `json:"subtitle,omitempty"`
	ContentHTML     *string  `json:"content_html,omitempty"`
	CoverImageURL   *string  `json:"cover_image_url,omitempty"`
	MetaTitle       *string  `json:"meta_title,omitempty"`
	MetaDescription *string  `json:"meta_description,omitempty"`
	Category        *string  `json:"category,omitempty"`
	Tags            []string `json:"tags,omitempty"`
}

// ArticleResponse is the API response for an article
type ArticleResponse struct {
	Success bool     `json:"success"`
	Article *Article `json:"article,omitempty"`
	Message string   `json:"message,omitempty"`
}

// Validate validates the article creation request
func (r *CreateArticleRequest) Validate() error {
	if len(r.Title) == 0 {
		return &AppError{Code: "TITLE_REQUIRED", Message: "Article title is required"}
	}

	if len(r.Title) > 100 {
		return &AppError{Code: "TITLE_TOO_LONG", Message: "Title must be 100 characters or less"}
	}

	if len(r.ContentHTML) == 0 {
		return &AppError{Code: "CONTENT_REQUIRED", Message: "Article content is required"}
	}

	if len(r.Tags) > 5 {
		return &AppError{Code: "TOO_MANY_TAGS", Message: "Maximum 5 tags allowed"}
	}

	return nil
}

// GenerateSlug creates a URL-friendly slug from the title
func (r *CreateArticleRequest) GenerateSlug() string {
	return slug.Make(r.Title)
}

// CalculateReadTime estimates reading time based on word count
// Assumes average reading speed of 200 words per minute
func (a *Article) CalculateReadTime() int {
	// Strip HTML tags for word count
	text := stripHTML(a.ContentHTML)
	words := len(strings.Fields(text))
	minutes := words / 200
	if minutes < 1 {
		return 1
	}
	return minutes
}

// stripHTML removes HTML tags from string (basic implementation)
func stripHTML(html string) string {
	// Simple tag removal - in production, use a proper HTML parser
	inTag := false
	var result strings.Builder

	for _, r := range html {
		if r == '<' {
			inTag = true
		} else if r == '>' {
			inTag = false
		} else if !inTag {
			result.WriteRune(r)
		}
	}

	return result.String()
}

// WordCount returns the word count of the article
func (a *Article) WordCount() int {
	text := stripHTML(a.ContentHTML)
	return len(strings.Fields(text))
}

// CharacterCount returns the character count (excluding HTML)
func (a *Article) CharacterCount() int {
	text := stripHTML(a.ContentHTML)
	return utf8.RuneCountInString(text)
}

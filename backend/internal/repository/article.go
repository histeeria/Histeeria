package repository

import (
	"context"
	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// ArticleRepository defines the interface for article data access
type ArticleRepository interface {
	// Article operations
	CreateArticle(ctx context.Context, article *models.Article) error
	GetArticle(ctx context.Context, articleID uuid.UUID) (*models.Article, error)
	GetArticleBySlug(ctx context.Context, slug string) (*models.Article, error)
	GetArticleByPostID(ctx context.Context, postID uuid.UUID) (*models.Article, error)
	UpdateArticle(ctx context.Context, articleID uuid.UUID, updates map[string]interface{}) error

	// Analytics
	IncrementViews(ctx context.Context, articleID uuid.UUID) error
	RecordRead(ctx context.Context, articleID, userID uuid.UUID) error

	// Tags
	AddTags(ctx context.Context, articleID uuid.UUID, tags []string) error
	GetArticleTags(ctx context.Context, articleID uuid.UUID) ([]string, error)
}

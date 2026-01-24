package repository

import (
	"context"
	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// CommentRepository defines the interface for comment data access
type CommentRepository interface {
	// Comment CRUD
	CreateComment(ctx context.Context, comment *models.Comment) error
	GetComment(ctx context.Context, commentID uuid.UUID) (*models.Comment, error)
	GetComments(ctx context.Context, postID uuid.UUID, limit, offset int) ([]models.Comment, int, error)
	GetCommentReplies(ctx context.Context, parentCommentID uuid.UUID, limit, offset int) ([]models.Comment, int, error)
	UpdateComment(ctx context.Context, commentID uuid.UUID, content string) error
	DeleteComment(ctx context.Context, commentID, userID uuid.UUID) error

	// Comment likes
	LikeComment(ctx context.Context, commentID, userID uuid.UUID) error
	UnlikeComment(ctx context.Context, commentID, userID uuid.UUID) error
	IsCommentLikedByUser(ctx context.Context, commentID, userID uuid.UUID) (bool, error)
	GetCommentLikes(ctx context.Context, commentID uuid.UUID, limit, offset int) ([]models.User, int, error)
}

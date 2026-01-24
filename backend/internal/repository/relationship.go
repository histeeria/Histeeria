package repository

import (
	"context"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// RelationshipRepository defines methods for relationship operations
type RelationshipRepository interface {
	// Relationship CRUD
	CreateRelationship(ctx context.Context, relationship *models.UserRelationship) error
	GetRelationship(ctx context.Context, fromUserID, toUserID uuid.UUID, relationshipType models.RelationshipType) (*models.UserRelationship, error)
	GetRelationshipByID(ctx context.Context, relationshipID uuid.UUID) (*models.UserRelationship, error)
	UpdateRelationshipStatus(ctx context.Context, relationshipID uuid.UUID, status models.RelationshipStatus) error
	DeleteRelationship(ctx context.Context, fromUserID, toUserID uuid.UUID, relationshipType models.RelationshipType) error

	// Relationship queries
	GetUserRelationships(ctx context.Context, userID uuid.UUID, relationshipType models.RelationshipType, status models.RelationshipStatus, asFrom bool, page, limit int) ([]*models.RelationshipListItem, int, error)
	GetRelationshipList(ctx context.Context, userID uuid.UUID, listType string, page, limit int) ([]*models.RelationshipListItem, int, error)
	GetRelationshipStats(ctx context.Context, userID uuid.UUID) (*models.RelationshipStats, error)
	GetRelationshipStatus(ctx context.Context, fromUserID, toUserID uuid.UUID) (*models.RelationshipStatusResponse, error)
	GetPendingRequests(ctx context.Context, userID uuid.UUID, incoming bool, page, limit int) ([]*models.RelationshipRequest, int, error)

	// Rate limiting
	GetRateLimit(ctx context.Context, userID uuid.UUID, actionType string) (*models.RelationshipRateLimit, error)
	CreateOrUpdateRateLimit(ctx context.Context, rateLimit *models.RelationshipRateLimit) error
	ResetRateLimit(ctx context.Context, userID uuid.UUID, actionType string) error

	// Spam detection
	GetSpamFlag(ctx context.Context, userID uuid.UUID, detectionType string) (*models.SpamFlag, error)
	CreateOrUpdateSpamFlag(ctx context.Context, spamFlag *models.SpamFlag) error
	GetUserSpamFlags(ctx context.Context, userID uuid.UUID) ([]*models.SpamFlag, error)

	// Helper methods
	CheckRelationshipExists(ctx context.Context, fromUserID, toUserID uuid.UUID, relationshipType models.RelationshipType) (bool, error)
	CountRecentActions(ctx context.Context, userID uuid.UUID, actionType string, since time.Time) (int, error)
}

package repository

import (
	"context"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// NotificationRepository defines the interface for notification data access
type NotificationRepository interface {
	// Notification CRUD
	Create(ctx context.Context, notification *models.Notification) error
	GetByID(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*models.Notification, error)
	GetByUser(ctx context.Context, userID uuid.UUID, category *models.NotificationCategory, unread *bool, limit int, offset int) ([]*models.Notification, int, error)
	GetUnreadCount(ctx context.Context, userID uuid.UUID, category *models.NotificationCategory) (int, error)
	GetCategoryCounts(ctx context.Context, userID uuid.UUID) (map[string]int, error)
	MarkAsRead(ctx context.Context, id uuid.UUID, userID uuid.UUID) error
	MarkAllAsRead(ctx context.Context, userID uuid.UUID, category *models.NotificationCategory) error
	Delete(ctx context.Context, id uuid.UUID, userID uuid.UUID) error
	UpdateActionTaken(ctx context.Context, id uuid.UUID, userID uuid.UUID) error

	// Preferences
	GetPreferences(ctx context.Context, userID uuid.UUID) (*models.NotificationPreferences, error)
	UpsertPreferences(ctx context.Context, prefs *models.NotificationPreferences) error

	// Cleanup
	DeleteExpired(ctx context.Context) (int, error)

	// Batch operations for digest
	GetUnreadForDigest(ctx context.Context, frequency models.EmailFrequency) (map[uuid.UUID][]*models.Notification, error)
}

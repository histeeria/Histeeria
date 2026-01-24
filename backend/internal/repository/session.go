package repository

import (
	"context"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// SessionRepository defines the data-access contract for user sessions
type SessionRepository interface {
	CreateSession(ctx context.Context, session *models.UserSession) error
	GetSessionByID(ctx context.Context, sessionID uuid.UUID) (*models.UserSession, error)
	GetSessionsByUserID(ctx context.Context, userID uuid.UUID) ([]*models.UserSession, error)
	GetSessionByTokenHash(ctx context.Context, tokenHash string) (*models.UserSession, error)
	DeleteSession(ctx context.Context, sessionID uuid.UUID) error
	DeleteSessionByTokenHash(ctx context.Context, tokenHash string) error
	DeleteAllUserSessions(ctx context.Context, userID uuid.UUID, exceptSessionID *uuid.UUID) error
	CleanupExpiredSessions(ctx context.Context) error
}


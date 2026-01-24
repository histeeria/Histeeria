package repository

import (
	"context"
	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// ExperienceRepository defines the data-access contract for user experiences
type ExperienceRepository interface {
	CreateExperience(ctx context.Context, exp *models.UserExperience) error
	GetExperienceByID(ctx context.Context, id uuid.UUID) (*models.UserExperience, error)
	GetUserExperiences(ctx context.Context, userID uuid.UUID) ([]*models.UserExperience, error)
	UpdateExperience(ctx context.Context, exp *models.UserExperience) error
	DeleteExperience(ctx context.Context, id uuid.UUID) error
}

// EducationRepository defines the data-access contract for user education
type EducationRepository interface {
	CreateEducation(ctx context.Context, edu *models.UserEducation) error
	GetEducationByID(ctx context.Context, id uuid.UUID) (*models.UserEducation, error)
	GetUserEducation(ctx context.Context, userID uuid.UUID) ([]*models.UserEducation, error)
	UpdateEducation(ctx context.Context, edu *models.UserEducation) error
	DeleteEducation(ctx context.Context, id uuid.UUID) error
}

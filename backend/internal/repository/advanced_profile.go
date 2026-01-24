package repository

import (
	"context"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// CompanyRepository defines the data-access contract for companies
type CompanyRepository interface {
	CreateCompany(ctx context.Context, company *models.Company) error
	GetCompanyByID(ctx context.Context, id uuid.UUID) (*models.Company, error)
	GetCompanyByName(ctx context.Context, name string) (*models.Company, error)
	SearchCompanies(ctx context.Context, query string, limit int) ([]*models.Company, error)
	UpdateCompany(ctx context.Context, company *models.Company) error
}

// CertificationRepository defines the data-access contract for user certifications
type CertificationRepository interface {
	CreateCertification(ctx context.Context, cert *models.UserCertification) error
	GetCertificationByID(ctx context.Context, id uuid.UUID) (*models.UserCertification, error)
	GetUserCertifications(ctx context.Context, userID uuid.UUID) ([]*models.UserCertification, error)
	UpdateCertification(ctx context.Context, cert *models.UserCertification) error
	DeleteCertification(ctx context.Context, id uuid.UUID) error
}

// SkillRepository defines the data-access contract for user skills
type SkillRepository interface {
	CreateSkill(ctx context.Context, skill *models.UserSkill) error
	GetSkillByID(ctx context.Context, id uuid.UUID) (*models.UserSkill, error)
	GetUserSkills(ctx context.Context, userID uuid.UUID) ([]*models.UserSkill, error)
	UpdateSkill(ctx context.Context, skill *models.UserSkill) error
	DeleteSkill(ctx context.Context, id uuid.UUID) error
}

// LanguageRepository defines the data-access contract for user languages
type LanguageRepository interface {
	CreateLanguage(ctx context.Context, lang *models.UserLanguage) error
	GetLanguageByID(ctx context.Context, id uuid.UUID) (*models.UserLanguage, error)
	GetUserLanguages(ctx context.Context, userID uuid.UUID) ([]*models.UserLanguage, error)
	UpdateLanguage(ctx context.Context, lang *models.UserLanguage) error
	DeleteLanguage(ctx context.Context, id uuid.UUID) error
}

// VolunteeringRepository defines the data-access contract for user volunteering
type VolunteeringRepository interface {
	CreateVolunteering(ctx context.Context, vol *models.UserVolunteering) error
	GetVolunteeringByID(ctx context.Context, id uuid.UUID) (*models.UserVolunteering, error)
	GetUserVolunteering(ctx context.Context, userID uuid.UUID) ([]*models.UserVolunteering, error)
	UpdateVolunteering(ctx context.Context, vol *models.UserVolunteering) error
	DeleteVolunteering(ctx context.Context, id uuid.UUID) error
}

// PublicationRepository defines the data-access contract for user publications
type PublicationRepository interface {
	CreatePublication(ctx context.Context, pub *models.UserPublication) error
	GetPublicationByID(ctx context.Context, id uuid.UUID) (*models.UserPublication, error)
	GetUserPublications(ctx context.Context, userID uuid.UUID) ([]*models.UserPublication, error)
	UpdatePublication(ctx context.Context, pub *models.UserPublication) error
	DeletePublication(ctx context.Context, id uuid.UUID) error
}

// InterestRepository defines the data-access contract for user interests
type InterestRepository interface {
	CreateInterest(ctx context.Context, interest *models.UserInterest) error
	GetInterestByID(ctx context.Context, id uuid.UUID) (*models.UserInterest, error)
	GetUserInterests(ctx context.Context, userID uuid.UUID) ([]*models.UserInterest, error)
	UpdateInterest(ctx context.Context, interest *models.UserInterest) error
	DeleteInterest(ctx context.Context, id uuid.UUID) error
}

// AchievementRepository defines the data-access contract for user achievements
type AchievementRepository interface {
	CreateAchievement(ctx context.Context, achievement *models.UserAchievement) error
	GetAchievementByID(ctx context.Context, id uuid.UUID) (*models.UserAchievement, error)
	GetUserAchievements(ctx context.Context, userID uuid.UUID) ([]*models.UserAchievement, error)
	UpdateAchievement(ctx context.Context, achievement *models.UserAchievement) error
	DeleteAchievement(ctx context.Context, id uuid.UUID) error
}

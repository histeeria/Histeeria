package account

import (
	"context"
	"time"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	apperr "histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// ExperienceEducationService handles experience and education business logic
type ExperienceEducationService struct {
	expRepo repository.ExperienceRepository
	eduRepo repository.EducationRepository
}

// NewExperienceEducationService creates a new service
func NewExperienceEducationService(expRepo repository.ExperienceRepository, eduRepo repository.EducationRepository) *ExperienceEducationService {
	return &ExperienceEducationService{
		expRepo: expRepo,
		eduRepo: eduRepo,
	}
}

// --- Experience Methods ---

func (s *ExperienceEducationService) CreateExperience(ctx context.Context, userID uuid.UUID, req *models.CreateExperienceRequest) (*models.UserExperience, error) {
	// Parse dates
	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		return nil, apperr.New(apperr.ErrBadRequest.Code, "Invalid start date format. Use YYYY-MM-DD")
	}

	var endDate *time.Time
	if req.EndDate != nil && *req.EndDate != "" {
		parsed, err := time.Parse("2006-01-02", *req.EndDate)
		if err != nil {
			return nil, apperr.New(apperr.ErrBadRequest.Code, "Invalid end date format. Use YYYY-MM-DD")
		}
		endDate = &parsed
	}

	// Validate: if is_current is true, end_date must be null
	if req.IsCurrent && endDate != nil {
		return nil, apperr.New(apperr.ErrBadRequest.Code, "Current position cannot have an end date")
	}

	exp := &models.UserExperience{
		ID:             uuid.New(),
		UserID:         userID,
		CompanyName:    req.CompanyName,
		Title:          req.Title,
		EmploymentType: req.EmploymentType,
		StartDate:      startDate,
		EndDate:        endDate,
		IsCurrent:      req.IsCurrent,
		Description:    req.Description,
		IsPublic:       req.IsPublic,
		DisplayOrder:   0,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
	}

	if err := s.expRepo.CreateExperience(ctx, exp); err != nil {
		return nil, err
	}

	return exp, nil
}

func (s *ExperienceEducationService) GetUserExperiences(ctx context.Context, userID uuid.UUID, viewerID *uuid.UUID) ([]*models.UserExperience, error) {
	experiences, err := s.expRepo.GetUserExperiences(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Filter experiences based on visibility
	isOwner := viewerID != nil && *viewerID == userID
	if !isOwner {
		// Non-owners only see public experiences
		publicExperiences := make([]*models.UserExperience, 0)
		for _, exp := range experiences {
			if exp.IsPublic {
				publicExperiences = append(publicExperiences, exp)
			}
		}
		return publicExperiences, nil
	}

	return experiences, nil
}

func (s *ExperienceEducationService) UpdateExperience(ctx context.Context, userID uuid.UUID, expID uuid.UUID, req *models.UpdateExperienceRequest) error {
	// Fetch existing experience
	exp, err := s.expRepo.GetExperienceByID(ctx, expID)
	if err != nil {
		return err
	}

	// Verify ownership
	if exp.UserID != userID {
		return apperr.ErrForbidden
	}

	// Update fields
	if req.CompanyName != nil {
		exp.CompanyName = *req.CompanyName
	}
	if req.Title != nil {
		exp.Title = *req.Title
	}
	if req.EmploymentType != nil {
		exp.EmploymentType = req.EmploymentType
	}
	if req.StartDate != nil {
		startDate, err := time.Parse("2006-01-02", *req.StartDate)
		if err != nil {
			return apperr.New(apperr.ErrBadRequest.Code, "Invalid start date format")
		}
		exp.StartDate = startDate
	}
	if req.EndDate != nil {
		if *req.EndDate == "" {
			exp.EndDate = nil
		} else {
			endDate, err := time.Parse("2006-01-02", *req.EndDate)
			if err != nil {
				return apperr.New(apperr.ErrBadRequest.Code, "Invalid end date format")
			}
			exp.EndDate = &endDate
		}
	}
	if req.IsCurrent != nil {
		exp.IsCurrent = *req.IsCurrent
		if exp.IsCurrent {
			exp.EndDate = nil // Clear end date if marking as current
		}
	}
	if req.Description != nil {
		exp.Description = req.Description
	}
	if req.IsPublic != nil {
		exp.IsPublic = *req.IsPublic
	}

	exp.UpdatedAt = time.Now()

	return s.expRepo.UpdateExperience(ctx, exp)
}

func (s *ExperienceEducationService) DeleteExperience(ctx context.Context, userID uuid.UUID, expID uuid.UUID) error {
	// Fetch to verify ownership
	exp, err := s.expRepo.GetExperienceByID(ctx, expID)
	if err != nil {
		return err
	}

	if exp.UserID != userID {
		return apperr.ErrForbidden
	}

	return s.expRepo.DeleteExperience(ctx, expID)
}

// --- Education Methods ---

func (s *ExperienceEducationService) CreateEducation(ctx context.Context, userID uuid.UUID, req *models.CreateEducationRequest) (*models.UserEducation, error) {
	// Parse dates
	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		return nil, apperr.New(apperr.ErrBadRequest.Code, "Invalid start date format. Use YYYY-MM-DD")
	}

	var endDate *time.Time
	if req.EndDate != nil && *req.EndDate != "" {
		parsed, err := time.Parse("2006-01-02", *req.EndDate)
		if err != nil {
			return nil, apperr.New(apperr.ErrBadRequest.Code, "Invalid end date format. Use YYYY-MM-DD")
		}
		endDate = &parsed
	}

	// Validate: if is_current is true, end_date must be null
	if req.IsCurrent && endDate != nil {
		return nil, apperr.New(apperr.ErrBadRequest.Code, "Current education cannot have an end date")
	}

	edu := &models.UserEducation{
		ID:           uuid.New(),
		UserID:       userID,
		SchoolName:   req.SchoolName,
		Degree:       req.Degree,
		FieldOfStudy: req.FieldOfStudy,
		StartDate:    startDate,
		EndDate:      endDate,
		IsCurrent:    req.IsCurrent,
		Description:  req.Description,
		DisplayOrder: 0,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := s.eduRepo.CreateEducation(ctx, edu); err != nil {
		return nil, err
	}

	return edu, nil
}

func (s *ExperienceEducationService) GetUserEducation(ctx context.Context, userID uuid.UUID) ([]*models.UserEducation, error) {
	return s.eduRepo.GetUserEducation(ctx, userID)
}

func (s *ExperienceEducationService) UpdateEducation(ctx context.Context, userID uuid.UUID, eduID uuid.UUID, req *models.UpdateEducationRequest) error {
	// Fetch existing education
	edu, err := s.eduRepo.GetEducationByID(ctx, eduID)
	if err != nil {
		return err
	}

	// Verify ownership
	if edu.UserID != userID {
		return apperr.ErrForbidden
	}

	// Update fields
	if req.SchoolName != nil {
		edu.SchoolName = *req.SchoolName
	}
	if req.Degree != nil {
		edu.Degree = req.Degree
	}
	if req.FieldOfStudy != nil {
		edu.FieldOfStudy = req.FieldOfStudy
	}
	if req.StartDate != nil {
		startDate, err := time.Parse("2006-01-02", *req.StartDate)
		if err != nil {
			return apperr.New(apperr.ErrBadRequest.Code, "Invalid start date format")
		}
		edu.StartDate = startDate
	}
	if req.EndDate != nil {
		if *req.EndDate == "" {
			edu.EndDate = nil
		} else {
			endDate, err := time.Parse("2006-01-02", *req.EndDate)
			if err != nil {
				return apperr.New(apperr.ErrBadRequest.Code, "Invalid end date format")
			}
			edu.EndDate = &endDate
		}
	}
	if req.IsCurrent != nil {
		edu.IsCurrent = *req.IsCurrent
		if edu.IsCurrent {
			edu.EndDate = nil // Clear end date if marking as current
		}
	}
	if req.Description != nil {
		edu.Description = req.Description
	}

	edu.UpdatedAt = time.Now()

	return s.eduRepo.UpdateEducation(ctx, edu)
}

func (s *ExperienceEducationService) DeleteEducation(ctx context.Context, userID uuid.UUID, eduID uuid.UUID) error {
	// Fetch to verify ownership
	edu, err := s.eduRepo.GetEducationByID(ctx, eduID)
	if err != nil {
		return err
	}

	if edu.UserID != userID {
		return apperr.ErrForbidden
	}

	return s.eduRepo.DeleteEducation(ctx, eduID)
}

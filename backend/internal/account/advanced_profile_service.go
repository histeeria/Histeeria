package account

import (
	"context"
	"time"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	"histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// AdvancedProfileService handles advanced profile features business logic
type AdvancedProfileService struct {
	companyRepo      repository.CompanyRepository
	certRepo         repository.CertificationRepository
	skillRepo        repository.SkillRepository
	languageRepo     repository.LanguageRepository
	volunteeringRepo repository.VolunteeringRepository
	publicationRepo  repository.PublicationRepository
	interestRepo     repository.InterestRepository
	achievementRepo  repository.AchievementRepository
	experienceRepo   repository.ExperienceRepository
}

// NewAdvancedProfileService creates a new advanced profile service
func NewAdvancedProfileService(
	companyRepo repository.CompanyRepository,
	certRepo repository.CertificationRepository,
	skillRepo repository.SkillRepository,
	languageRepo repository.LanguageRepository,
	volunteeringRepo repository.VolunteeringRepository,
	publicationRepo repository.PublicationRepository,
	interestRepo repository.InterestRepository,
	achievementRepo repository.AchievementRepository,
	experienceRepo repository.ExperienceRepository,
) *AdvancedProfileService {
	return &AdvancedProfileService{
		companyRepo:      companyRepo,
		certRepo:         certRepo,
		skillRepo:        skillRepo,
		languageRepo:     languageRepo,
		volunteeringRepo: volunteeringRepo,
		publicationRepo:  publicationRepo,
		interestRepo:     interestRepo,
		achievementRepo:  achievementRepo,
		experienceRepo:   experienceRepo,
	}
}

// --- Company Methods ---

// CreateOrGetCompany creates a company or returns existing one
func (s *AdvancedProfileService) CreateOrGetCompany(ctx context.Context, name string) (*models.Company, error) {
	// Try to get existing company
	company, err := s.companyRepo.GetCompanyByName(ctx, name)
	if err == nil {
		return company, nil
	}

	// Company doesn't exist, create it
	company = &models.Company{
		ID:        uuid.New(),
		Name:      name,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if err := s.companyRepo.CreateCompany(ctx, company); err != nil {
		return nil, err
	}

	return company, nil
}

// SearchCompanies searches for companies by name
func (s *AdvancedProfileService) SearchCompanies(ctx context.Context, query string, limit int) ([]*models.Company, error) {
	if limit <= 0 {
		limit = 10
	}
	return s.companyRepo.SearchCompanies(ctx, query, limit)
}

// --- Certification Methods ---

// CreateCertification creates a new certification
func (s *AdvancedProfileService) CreateCertification(ctx context.Context, userID uuid.UUID, req *models.CreateCertificationRequest) (*models.UserCertification, error) {
	issueDate, err := time.Parse("2006-01-02", req.IssueDate)
	if err != nil {
		return nil, errors.ErrBadRequest
	}

	cert := &models.UserCertification{
		ID:        uuid.New(),
		UserID:    userID,
		Name:      req.Name,
		IssueDate: issueDate,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if req.IssuingOrganization != nil {
		cert.IssuingOrganization = req.IssuingOrganization
	}
	if req.ExpirationDate != nil {
		expDate, err := time.Parse("2006-01-02", *req.ExpirationDate)
		if err == nil {
			cert.ExpirationDate = &expDate
		}
	}
	if req.CredentialID != nil {
		cert.CredentialID = req.CredentialID
	}
	if req.CredentialURL != nil {
		cert.CredentialURL = req.CredentialURL
	}
	if req.Description != nil {
		cert.Description = req.Description
	}

	// Get max display order and add 1 (newest first)
	existing, _ := s.certRepo.GetUserCertifications(ctx, userID)
	cert.DisplayOrder = len(existing)

	if err := s.certRepo.CreateCertification(ctx, cert); err != nil {
		return nil, err
	}

	return cert, nil
}

// GetUserCertifications gets all certifications for a user
func (s *AdvancedProfileService) GetUserCertifications(ctx context.Context, userID uuid.UUID) ([]*models.UserCertification, error) {
	return s.certRepo.GetUserCertifications(ctx, userID)
}

// UpdateCertification updates a certification
func (s *AdvancedProfileService) UpdateCertification(ctx context.Context, userID, certID uuid.UUID, req *models.UpdateCertificationRequest) error {
	cert, err := s.certRepo.GetCertificationByID(ctx, certID)
	if err != nil {
		return err
	}

	if cert.UserID != userID {
		return errors.ErrForbidden
	}

	if req.Name != nil {
		cert.Name = *req.Name
	}
	if req.IssueDate != nil {
		issueDate, err := time.Parse("2006-01-02", *req.IssueDate)
		if err == nil {
			cert.IssueDate = issueDate
		}
	}
	if req.ExpirationDate != nil {
		if *req.ExpirationDate == "" {
			cert.ExpirationDate = nil
		} else {
			expDate, err := time.Parse("2006-01-02", *req.ExpirationDate)
			if err == nil {
				cert.ExpirationDate = &expDate
			}
		}
	}
	if req.IssuingOrganization != nil {
		cert.IssuingOrganization = req.IssuingOrganization
	}
	if req.CredentialID != nil {
		cert.CredentialID = req.CredentialID
	}
	if req.CredentialURL != nil {
		cert.CredentialURL = req.CredentialURL
	}
	if req.Description != nil {
		cert.Description = req.Description
	}

	cert.UpdatedAt = time.Now()

	return s.certRepo.UpdateCertification(ctx, cert)
}

// DeleteCertification deletes a certification
func (s *AdvancedProfileService) DeleteCertification(ctx context.Context, userID, certID uuid.UUID) error {
	cert, err := s.certRepo.GetCertificationByID(ctx, certID)
	if err != nil {
		return err
	}

	if cert.UserID != userID {
		return errors.ErrForbidden
	}

	return s.certRepo.DeleteCertification(ctx, certID)
}

// --- Skill Methods ---

// CreateSkill creates a new skill
func (s *AdvancedProfileService) CreateSkill(ctx context.Context, userID uuid.UUID, req *models.CreateSkillRequest) (*models.UserSkill, error) {
	existing, _ := s.skillRepo.GetUserSkills(ctx, userID)

	skill := &models.UserSkill{
		ID:           uuid.New(),
		UserID:       userID,
		SkillName:    req.SkillName,
		DisplayOrder: len(existing),
		CreatedAt:    time.Now(),
	}

	if req.ProficiencyLevel != nil {
		skill.ProficiencyLevel = req.ProficiencyLevel
	}
	if req.Category != nil {
		skill.Category = req.Category
	}

	if err := s.skillRepo.CreateSkill(ctx, skill); err != nil {
		return nil, err
	}

	return skill, nil
}

// GetUserSkills gets all skills for a user
func (s *AdvancedProfileService) GetUserSkills(ctx context.Context, userID uuid.UUID) ([]*models.UserSkill, error) {
	return s.skillRepo.GetUserSkills(ctx, userID)
}

// UpdateSkill updates a skill
func (s *AdvancedProfileService) UpdateSkill(ctx context.Context, userID, skillID uuid.UUID, req *models.UpdateSkillRequest) error {
	skill, err := s.skillRepo.GetSkillByID(ctx, skillID)
	if err != nil {
		return err
	}

	if skill.UserID != userID {
		return errors.ErrForbidden
	}

	if req.SkillName != nil {
		skill.SkillName = *req.SkillName
	}
	if req.ProficiencyLevel != nil {
		skill.ProficiencyLevel = req.ProficiencyLevel
	}
	if req.Category != nil {
		skill.Category = req.Category
	}

	return s.skillRepo.UpdateSkill(ctx, skill)
}

// DeleteSkill deletes a skill
func (s *AdvancedProfileService) DeleteSkill(ctx context.Context, userID, skillID uuid.UUID) error {
	skill, err := s.skillRepo.GetSkillByID(ctx, skillID)
	if err != nil {
		return err
	}

	if skill.UserID != userID {
		return errors.ErrForbidden
	}

	return s.skillRepo.DeleteSkill(ctx, skillID)
}

// --- Language Methods ---

// CreateLanguage creates a new language
func (s *AdvancedProfileService) CreateLanguage(ctx context.Context, userID uuid.UUID, req *models.CreateLanguageRequest) (*models.UserLanguage, error) {
	existing, _ := s.languageRepo.GetUserLanguages(ctx, userID)

	lang := &models.UserLanguage{
		ID:           uuid.New(),
		UserID:       userID,
		LanguageName: req.LanguageName,
		DisplayOrder: len(existing),
		CreatedAt:    time.Now(),
	}

	if req.ProficiencyLevel != nil {
		lang.ProficiencyLevel = req.ProficiencyLevel
	}

	if err := s.languageRepo.CreateLanguage(ctx, lang); err != nil {
		return nil, err
	}

	return lang, nil
}

// GetUserLanguages gets all languages for a user
func (s *AdvancedProfileService) GetUserLanguages(ctx context.Context, userID uuid.UUID) ([]*models.UserLanguage, error) {
	return s.languageRepo.GetUserLanguages(ctx, userID)
}

// UpdateLanguage updates a language
func (s *AdvancedProfileService) UpdateLanguage(ctx context.Context, userID, langID uuid.UUID, req *models.UpdateLanguageRequest) error {
	lang, err := s.languageRepo.GetLanguageByID(ctx, langID)
	if err != nil {
		return err
	}

	if lang.UserID != userID {
		return errors.ErrForbidden
	}

	if req.LanguageName != nil {
		lang.LanguageName = *req.LanguageName
	}
	if req.ProficiencyLevel != nil {
		lang.ProficiencyLevel = req.ProficiencyLevel
	}

	return s.languageRepo.UpdateLanguage(ctx, lang)
}

// DeleteLanguage deletes a language
func (s *AdvancedProfileService) DeleteLanguage(ctx context.Context, userID, langID uuid.UUID) error {
	lang, err := s.languageRepo.GetLanguageByID(ctx, langID)
	if err != nil {
		return err
	}

	if lang.UserID != userID {
		return errors.ErrForbidden
	}

	return s.languageRepo.DeleteLanguage(ctx, langID)
}

// --- Volunteering Methods ---

// CreateVolunteering creates a new volunteering entry
func (s *AdvancedProfileService) CreateVolunteering(ctx context.Context, userID uuid.UUID, req *models.CreateVolunteeringRequest) (*models.UserVolunteering, error) {
	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		return nil, errors.ErrBadRequest
	}

	existing, _ := s.volunteeringRepo.GetUserVolunteering(ctx, userID)

	vol := &models.UserVolunteering{
		ID:               uuid.New(),
		UserID:           userID,
		OrganizationName: req.OrganizationName,
		Role:             req.Role,
		StartDate:        startDate,
		IsCurrent:        req.IsCurrent,
		DisplayOrder:     len(existing),
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}

	if req.EndDate != nil && *req.EndDate != "" {
		endDate, err := time.Parse("2006-01-02", *req.EndDate)
		if err == nil {
			vol.EndDate = &endDate
		}
	}
	if req.Description != nil {
		vol.Description = req.Description
	}

	if err := s.volunteeringRepo.CreateVolunteering(ctx, vol); err != nil {
		return nil, err
	}

	return vol, nil
}

// GetUserVolunteering gets all volunteering for a user
func (s *AdvancedProfileService) GetUserVolunteering(ctx context.Context, userID uuid.UUID) ([]*models.UserVolunteering, error) {
	return s.volunteeringRepo.GetUserVolunteering(ctx, userID)
}

// UpdateVolunteering updates a volunteering entry
func (s *AdvancedProfileService) UpdateVolunteering(ctx context.Context, userID, volID uuid.UUID, req *models.UpdateVolunteeringRequest) error {
	vol, err := s.volunteeringRepo.GetVolunteeringByID(ctx, volID)
	if err != nil {
		return err
	}

	if vol.UserID != userID {
		return errors.ErrForbidden
	}

	if req.OrganizationName != nil {
		vol.OrganizationName = *req.OrganizationName
	}
	if req.Role != nil {
		vol.Role = *req.Role
	}
	if req.StartDate != nil {
		startDate, err := time.Parse("2006-01-02", *req.StartDate)
		if err == nil {
			vol.StartDate = startDate
		}
	}
	if req.EndDate != nil {
		if *req.EndDate == "" {
			vol.EndDate = nil
		} else {
			endDate, err := time.Parse("2006-01-02", *req.EndDate)
			if err == nil {
				vol.EndDate = &endDate
			}
		}
	}
	if req.IsCurrent != nil {
		vol.IsCurrent = *req.IsCurrent
	}
	if req.Description != nil {
		vol.Description = req.Description
	}

	vol.UpdatedAt = time.Now()

	return s.volunteeringRepo.UpdateVolunteering(ctx, vol)
}

// DeleteVolunteering deletes a volunteering entry
func (s *AdvancedProfileService) DeleteVolunteering(ctx context.Context, userID, volID uuid.UUID) error {
	vol, err := s.volunteeringRepo.GetVolunteeringByID(ctx, volID)
	if err != nil {
		return err
	}

	if vol.UserID != userID {
		return errors.ErrForbidden
	}

	return s.volunteeringRepo.DeleteVolunteering(ctx, volID)
}

// --- Publication Methods ---

// CreatePublication creates a new publication
func (s *AdvancedProfileService) CreatePublication(ctx context.Context, userID uuid.UUID, req *models.CreatePublicationRequest) (*models.UserPublication, error) {
	existing, _ := s.publicationRepo.GetUserPublications(ctx, userID)

	pub := &models.UserPublication{
		ID:           uuid.New(),
		UserID:       userID,
		Title:        req.Title,
		DisplayOrder: len(existing),
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if req.PublicationType != nil {
		pub.PublicationType = req.PublicationType
	}
	if req.Publisher != nil {
		pub.Publisher = req.Publisher
	}
	if req.PublicationDate != nil && *req.PublicationDate != "" {
		pubDate, err := time.Parse("2006-01-02", *req.PublicationDate)
		if err == nil {
			pub.PublicationDate = &pubDate
		}
	}
	if req.PublicationURL != nil {
		pub.PublicationURL = req.PublicationURL
	}
	if req.Description != nil {
		pub.Description = req.Description
	}

	if err := s.publicationRepo.CreatePublication(ctx, pub); err != nil {
		return nil, err
	}

	return pub, nil
}

// GetUserPublications gets all publications for a user
func (s *AdvancedProfileService) GetUserPublications(ctx context.Context, userID uuid.UUID) ([]*models.UserPublication, error) {
	return s.publicationRepo.GetUserPublications(ctx, userID)
}

// UpdatePublication updates a publication
func (s *AdvancedProfileService) UpdatePublication(ctx context.Context, userID, pubID uuid.UUID, req *models.UpdatePublicationRequest) error {
	pub, err := s.publicationRepo.GetPublicationByID(ctx, pubID)
	if err != nil {
		return err
	}

	if pub.UserID != userID {
		return errors.ErrForbidden
	}

	if req.Title != nil {
		pub.Title = *req.Title
	}
	if req.PublicationType != nil {
		pub.PublicationType = req.PublicationType
	}
	if req.Publisher != nil {
		pub.Publisher = req.Publisher
	}
	if req.PublicationDate != nil {
		if *req.PublicationDate == "" {
			pub.PublicationDate = nil
		} else {
			pubDate, err := time.Parse("2006-01-02", *req.PublicationDate)
			if err == nil {
				pub.PublicationDate = &pubDate
			}
		}
	}
	if req.PublicationURL != nil {
		pub.PublicationURL = req.PublicationURL
	}
	if req.Description != nil {
		pub.Description = req.Description
	}

	pub.UpdatedAt = time.Now()

	return s.publicationRepo.UpdatePublication(ctx, pub)
}

// DeletePublication deletes a publication
func (s *AdvancedProfileService) DeletePublication(ctx context.Context, userID, pubID uuid.UUID) error {
	pub, err := s.publicationRepo.GetPublicationByID(ctx, pubID)
	if err != nil {
		return err
	}

	if pub.UserID != userID {
		return errors.ErrForbidden
	}

	return s.publicationRepo.DeletePublication(ctx, pubID)
}

// --- Interest Methods ---

// CreateInterest creates a new interest
func (s *AdvancedProfileService) CreateInterest(ctx context.Context, userID uuid.UUID, req *models.CreateInterestRequest) (*models.UserInterest, error) {
	existing, _ := s.interestRepo.GetUserInterests(ctx, userID)

	interest := &models.UserInterest{
		ID:           uuid.New(),
		UserID:       userID,
		InterestName: req.InterestName,
		DisplayOrder: len(existing),
		CreatedAt:    time.Now(),
	}

	if req.Category != nil {
		interest.Category = req.Category
	}

	if err := s.interestRepo.CreateInterest(ctx, interest); err != nil {
		return nil, err
	}

	return interest, nil
}

// GetUserInterests gets all interests for a user
func (s *AdvancedProfileService) GetUserInterests(ctx context.Context, userID uuid.UUID) ([]*models.UserInterest, error) {
	return s.interestRepo.GetUserInterests(ctx, userID)
}

// UpdateInterest updates an interest
func (s *AdvancedProfileService) UpdateInterest(ctx context.Context, userID, interestID uuid.UUID, req *models.UpdateInterestRequest) error {
	interest, err := s.interestRepo.GetInterestByID(ctx, interestID)
	if err != nil {
		return err
	}

	if interest.UserID != userID {
		return errors.ErrForbidden
	}

	if req.InterestName != nil {
		interest.InterestName = *req.InterestName
	}
	if req.Category != nil {
		interest.Category = req.Category
	}

	return s.interestRepo.UpdateInterest(ctx, interest)
}

// DeleteInterest deletes an interest
func (s *AdvancedProfileService) DeleteInterest(ctx context.Context, userID, interestID uuid.UUID) error {
	interest, err := s.interestRepo.GetInterestByID(ctx, interestID)
	if err != nil {
		return err
	}

	if interest.UserID != userID {
		return errors.ErrForbidden
	}

	return s.interestRepo.DeleteInterest(ctx, interestID)
}

// --- Achievement Methods ---

// CreateAchievement creates a new achievement
func (s *AdvancedProfileService) CreateAchievement(ctx context.Context, userID uuid.UUID, req *models.CreateAchievementRequest) (*models.UserAchievement, error) {
	existing, _ := s.achievementRepo.GetUserAchievements(ctx, userID)

	achievement := &models.UserAchievement{
		ID:           uuid.New(),
		UserID:       userID,
		Title:        req.Title,
		DisplayOrder: len(existing),
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if req.AchievementType != nil {
		achievement.AchievementType = req.AchievementType
	}
	if req.IssuingOrganization != nil {
		achievement.IssuingOrganization = req.IssuingOrganization
	}
	if req.AchievementDate != nil && *req.AchievementDate != "" {
		aDate, err := time.Parse("2006-01-02", *req.AchievementDate)
		if err == nil {
			achievement.AchievementDate = &aDate
		}
	}
	if req.Description != nil {
		achievement.Description = req.Description
	}

	if err := s.achievementRepo.CreateAchievement(ctx, achievement); err != nil {
		return nil, err
	}

	return achievement, nil
}

// GetUserAchievements gets all achievements for a user
func (s *AdvancedProfileService) GetUserAchievements(ctx context.Context, userID uuid.UUID) ([]*models.UserAchievement, error) {
	return s.achievementRepo.GetUserAchievements(ctx, userID)
}

// UpdateAchievement updates an achievement
func (s *AdvancedProfileService) UpdateAchievement(ctx context.Context, userID, achievementID uuid.UUID, req *models.UpdateAchievementRequest) error {
	achievement, err := s.achievementRepo.GetAchievementByID(ctx, achievementID)
	if err != nil {
		return err
	}

	if achievement.UserID != userID {
		return errors.ErrForbidden
	}

	if req.Title != nil {
		achievement.Title = *req.Title
	}
	if req.AchievementType != nil {
		achievement.AchievementType = req.AchievementType
	}
	if req.IssuingOrganization != nil {
		achievement.IssuingOrganization = req.IssuingOrganization
	}
	if req.AchievementDate != nil {
		if *req.AchievementDate == "" {
			achievement.AchievementDate = nil
		} else {
			aDate, err := time.Parse("2006-01-02", *req.AchievementDate)
			if err == nil {
				achievement.AchievementDate = &aDate
			}
		}
	}
	if req.Description != nil {
		achievement.Description = req.Description
	}

	achievement.UpdatedAt = time.Now()

	return s.achievementRepo.UpdateAchievement(ctx, achievement)
}

// DeleteAchievement deletes an achievement
func (s *AdvancedProfileService) DeleteAchievement(ctx context.Context, userID, achievementID uuid.UUID) error {
	achievement, err := s.achievementRepo.GetAchievementByID(ctx, achievementID)
	if err != nil {
		return err
	}

	if achievement.UserID != userID {
		return errors.ErrForbidden
	}

	return s.achievementRepo.DeleteAchievement(ctx, achievementID)
}

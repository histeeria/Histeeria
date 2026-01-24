package models

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// User represents a user in the system
type User struct {
	ID                         uuid.UUID  `json:"id" db:"id"`
	Email                      string     `json:"email" db:"email"`
	EmailHash                  string     `json:"-" db:"email_hash"`
	Username                   string     `json:"username" db:"username"`
	PasswordHash               string     `json:"-" db:"password_hash"`
	DisplayName                string     `json:"display_name" db:"display_name"`
	Age                        int        `json:"age" db:"age"`
	IsEmailVerified            bool       `json:"is_email_verified" db:"is_email_verified"`
	EmailVerificationCode      *string    `json:"-" db:"email_verification_code"`
	EmailVerificationExpiresAt *time.Time `json:"-" db:"email_verification_expires_at"`
	PasswordResetToken         *string    `json:"-" db:"password_reset_token"`
	PasswordResetExpiresAt     *time.Time `json:"-" db:"password_reset_expires_at"`
	PendingEmail               *string    `json:"-" db:"pending_email"`
	PendingEmailCode           *string    `json:"-" db:"pending_email_code"`
	PendingEmailExpiresAt      *time.Time `json:"-" db:"pending_email_expires_at"`
	UsernameChangedAt          *time.Time `json:"-" db:"username_changed_at"`
	GoogleID                   *string    `json:"-" db:"google_id"`
	GitHubID                   *string    `json:"-" db:"github_id"`
	LinkedInID                 *string    `json:"-" db:"linkedin_id"`
	OAuthProvider              *string    `json:"oauth_provider,omitempty" db:"oauth_provider"`
	ProfilePicture             *string    `json:"profile_picture,omitempty" db:"profile_picture"`
	CoverPhoto                 *string    `json:"cover_photo,omitempty" db:"cover_photo"`
	IsActive                   bool       `json:"is_active" db:"is_active"`
	LastLoginAt                *time.Time `json:"last_login_at" db:"last_login_at"`
	LastUsedAt                 *time.Time `json:"last_used_at" db:"last_used_at"`
	CreatedAt                  time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt                  time.Time  `json:"updated_at" db:"updated_at"`

	// Profile System Phase 1 Fields
	Bio             *string            `json:"bio,omitempty" db:"bio"`
	Location        *string            `json:"location,omitempty" db:"location"`
	Gender          *string            `json:"gender,omitempty" db:"gender"`
	GenderCustom    *string            `json:"gender_custom,omitempty" db:"gender_custom"`
	Website         *string            `json:"website,omitempty" db:"website"`
	IsVerified      bool               `json:"is_verified" db:"is_verified"`
	ProfilePrivacy  string             `json:"profile_privacy" db:"profile_privacy"`
	FieldVisibility map[string]bool    `json:"field_visibility" db:"field_visibility"`
	StatVisibility  map[string]bool    `json:"stat_visibility" db:"stat_visibility"`
	Story           *string            `json:"story,omitempty" db:"story"`
	Ambition        *string            `json:"ambition,omitempty" db:"ambition"`
	PostsCount      int                `json:"posts_count" db:"posts_count"`
	ProjectsCount   int                `json:"projects_count" db:"projects_count"`
	FollowersCount  int                `json:"followers_count" db:"followers_count"`
	FollowingCount  int                `json:"following_count" db:"following_count"`
	SocialLinks     map[string]*string `json:"social_links,omitempty" db:"social_links"`
}

// UserSession represents a user session (optional for advanced session management)
type UserSession struct {
	ID         uuid.UUID `json:"id" db:"id"`
	UserID     uuid.UUID `json:"user_id" db:"user_id"`
	TokenHash  string    `json:"-" db:"token_hash"`
	DeviceInfo *string   `json:"device_info" db:"device_info"`
	IPAddress  *string   `json:"ip_address" db:"ip_address"`
	UserAgent  *string   `json:"user_agent" db:"user_agent"`
	ExpiresAt  time.Time `json:"expires_at" db:"expires_at"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}

// RegisterRequest represents the request payload for user registration
type RegisterRequest struct {
	Email            string  `json:"email" validate:"required,email"`
	Password         string  `json:"password" validate:"required,min=6"`
	DisplayName      string  `json:"display_name" validate:"required,min=2,max=50"`
	Username         string  `json:"username" validate:"required,min=3,max=20,alphanum"`
	Age              *int    `json:"age,omitempty" validate:"omitempty,min=13,max=120"`
	Gender           *string `json:"gender,omitempty" validate:"omitempty,oneof=male female non-binary prefer-not-to-say custom"`
	Bio              *string `json:"bio,omitempty" validate:"omitempty,max=200"`
	ProfilePicture   *string `json:"profile_picture,omitempty" validate:"omitempty,url"`
	VerificationCode *string `json:"verification_code,omitempty" validate:"omitempty,len=6"` // Optional: if provided, verify immediately
}

// LoginRequest represents the request payload for user login
type LoginRequest struct {
	EmailOrUsername string `json:"email_or_username" validate:"required"`
	Password        string `json:"password" validate:"required"`
}

// VerifyEmailRequest represents the request payload for email verification
type VerifyEmailRequest struct {
	Email            string `json:"email" validate:"required,email"`
	VerificationCode string `json:"verification_code" validate:"required,len=6"`
}

// ForgotPasswordRequest represents the request payload for password reset request
type ForgotPasswordRequest struct {
	Email string `json:"email" validate:"required,email"`
}

// ResetPasswordRequest represents the request payload for password reset
type ResetPasswordRequest struct {
	Token       string `json:"token" validate:"required"`
	NewPassword string `json:"new_password" validate:"required,min=6"`
}

// RefreshTokenRequest represents the request payload for token refresh
type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

// AuthResponse represents the response for authentication operations
type AuthResponse struct {
	Success   bool      `json:"success"`
	Message   string    `json:"message"`
	Token     string    `json:"token,omitempty"`
	ExpiresAt time.Time `json:"expires_at,omitempty"`
	User      *User     `json:"user,omitempty"`
	UserID    string    `json:"user_id,omitempty"`
}

// TokenResponse represents the response for token operations
type TokenResponse struct {
	Success   bool      `json:"success"`
	Message   string    `json:"message"`
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
}

// UserResponse represents the response for user operations
type UserResponse struct {
	Success bool  `json:"success"`
	User    *User `json:"user"`
}

// MessageResponse represents a simple message response
type MessageResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

// JWTClaims represents the JWT token claims
type JWTClaims struct {
	UserID   string `json:"user_id"`
	Email    string `json:"email"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// UpdateProfileRequest represents the request payload for updating user profile
type UpdateProfileRequest struct {
	DisplayName    *string `json:"display_name,omitempty" validate:"omitempty,min=2,max=50"`
	Age            *int    `json:"age,omitempty" validate:"omitempty,min=13,max=120"`
	ProfilePicture *string `json:"profile_picture,omitempty" validate:"omitempty,url"`
}

// ChangePasswordRequest represents the request payload for changing password
type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" validate:"required"`
	NewPassword     string `json:"new_password" validate:"required,min=8"`
	ConfirmPassword string `json:"confirm_password" validate:"required,min=8"`
}

// DeleteAccountRequest represents the request payload for account deletion
type DeleteAccountRequest struct {
	Password     string `json:"password" validate:"required"`
	Confirmation string `json:"confirmation" validate:"required,eqfield=DELETE MY ACCOUNT"`
}

// ChangeEmailRequest represents the request payload for initiating email change
type ChangeEmailRequest struct {
	NewEmail string `json:"new_email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
}

// VerifyEmailChangeRequest represents the request payload for verifying new email
type VerifyEmailChangeRequest struct {
	VerificationCode string `json:"verification_code" validate:"required,len=6"`
}

// ChangeUsernameRequest represents the request payload for changing username
type ChangeUsernameRequest struct {
	NewUsername string `json:"new_username" validate:"required,min=3,max=20,alphanum"`
	Password    string `json:"password" validate:"required"`
}

// DeactivateAccountRequest represents the request payload for account deactivation
type DeactivateAccountRequest struct {
	Password string `json:"password" validate:"required"`
	Reason   string `json:"reason,omitempty"`
}

// SessionsResponse represents the response containing active sessions
type SessionsResponse struct {
	Success  bool           `json:"success"`
	Sessions []*UserSession `json:"sessions"`
}

// UpdateBasicProfileRequest represents the request payload for updating basic profile info
type UpdateBasicProfileRequest struct {
	DisplayName  *string `json:"display_name,omitempty" validate:"omitempty,min=2,max=100"`
	Bio          *string `json:"bio,omitempty" validate:"omitempty,max=150"`
	Location     *string `json:"location,omitempty" validate:"omitempty,max=100"`
	Gender       *string `json:"gender,omitempty" validate:"omitempty,oneof=male female non-binary prefer-not-to-say custom"`
	GenderCustom *string `json:"gender_custom,omitempty" validate:"omitempty,max=50"`
	Age          *int    `json:"age,omitempty" validate:"omitempty,min=13,max=120"`
	Website      *string `json:"website,omitempty" validate:"omitempty,url"`
}

// UpdatePrivacySettingsRequest represents the request payload for updating privacy settings
type UpdatePrivacySettingsRequest struct {
	ProfilePrivacy  string          `json:"profile_privacy" validate:"required,oneof=public private connections"`
	FieldVisibility map[string]bool `json:"field_visibility" validate:"required"`
}

// UpdateStoryRequest represents the request payload for updating story section
type UpdateStoryRequest struct {
	Story *string `json:"story" validate:"omitempty,max=1000"`
}

// UpdateAmbitionRequest represents the request payload for updating ambition section
type UpdateAmbitionRequest struct {
	Ambition *string `json:"ambition" validate:"omitempty,max=200"`
}

// UpdateSocialLinksRequest represents the request payload for updating social media links
type UpdateSocialLinksRequest struct {
	Twitter   *string `json:"twitter,omitempty" validate:"omitempty,url"`
	Instagram *string `json:"instagram,omitempty" validate:"omitempty,url"`
	Facebook  *string `json:"facebook,omitempty" validate:"omitempty,url"`
	LinkedIn  *string `json:"linkedin,omitempty" validate:"omitempty,url"`
	GitHub    *string `json:"github,omitempty" validate:"omitempty,url"`
	YouTube   *string `json:"youtube,omitempty" validate:"omitempty,url"`
}

// PublicProfileResponse represents a public-facing user profile with privacy filtering applied
type PublicProfileResponse struct {
	ID             uuid.UUID          `json:"id"`
	Username       string             `json:"username"`
	DisplayName    string             `json:"display_name"`
	ProfilePicture *string            `json:"profile_picture,omitempty"`
	CoverPhoto     *string            `json:"cover_photo,omitempty"`
	IsVerified     bool               `json:"is_verified"`
	Bio            *string            `json:"bio,omitempty"`
	Location       *string            `json:"location,omitempty"`
	Gender         *string            `json:"gender,omitempty"`
	GenderCustom   *string            `json:"gender_custom,omitempty"`
	Age            *int               `json:"age,omitempty"`
	Website        *string            `json:"website,omitempty"`
	JoinedAt       time.Time          `json:"joined_at"`
	Story          *string            `json:"story,omitempty"`
	Ambition       *string            `json:"ambition,omitempty"`
	PostsCount     int                `json:"posts_count"`
	ProjectsCount  int                `json:"projects_count"`
	FollowersCount int                `json:"followers_count"`
	FollowingCount int                `json:"following_count"`
	IsOwnProfile   bool               `json:"is_own_profile"`
	ProfilePrivacy *string            `json:"profile_privacy,omitempty"` // Only sent for own profile
	StatVisibility map[string]bool    `json:"stat_visibility,omitempty"` // Only sent for own profile
	SocialLinks    map[string]*string `json:"social_links,omitempty"`
}

// UserExperience represents a user's work experience entry
type UserExperience struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	UserID         uuid.UUID  `json:"user_id" db:"user_id"`
	CompanyName    string     `json:"company_name" db:"company_name"`
	CompanyID      *uuid.UUID `json:"company_id,omitempty" db:"company_id"`
	Title          string     `json:"title" db:"title"`
	EmploymentType *string    `json:"employment_type,omitempty" db:"employment_type"`
	StartDate      time.Time  `json:"start_date" db:"start_date"`
	EndDate        *time.Time `json:"end_date,omitempty" db:"end_date"`
	IsCurrent      bool       `json:"is_current" db:"is_current"`
	Description    *string    `json:"description,omitempty" db:"description"`
	IsPublic       bool       `json:"is_public" db:"is_public"`
	DisplayOrder   int        `json:"display_order" db:"display_order"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
}

// Company represents a company for experience entries
type Company struct {
	ID        uuid.UUID `json:"id" db:"id"`
	Name      string    `json:"name" db:"name"`
	LogoURL   *string   `json:"logo_url,omitempty" db:"logo_url"`
	Website   *string   `json:"website,omitempty" db:"website"`
	Industry  *string   `json:"industry,omitempty" db:"industry"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

// UserCertification represents a user's certification
type UserCertification struct {
	ID                  uuid.UUID  `json:"id" db:"id"`
	UserID              uuid.UUID  `json:"user_id" db:"user_id"`
	Name                string     `json:"name" db:"name"`
	IssuingOrganization *string    `json:"issuing_organization,omitempty" db:"issuing_organization"`
	IssueDate           time.Time  `json:"issue_date" db:"issue_date"`
	ExpirationDate      *time.Time `json:"expiration_date,omitempty" db:"expiration_date"`
	CredentialID        *string    `json:"credential_id,omitempty" db:"credential_id"`
	CredentialURL       *string    `json:"credential_url,omitempty" db:"credential_url"`
	Description         *string    `json:"description,omitempty" db:"description"`
	DisplayOrder        int        `json:"display_order" db:"display_order"`
	CreatedAt           time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at" db:"updated_at"`
}

// UserSkill represents a user's skill
type UserSkill struct {
	ID               uuid.UUID `json:"id" db:"id"`
	UserID           uuid.UUID `json:"user_id" db:"user_id"`
	SkillName        string    `json:"skill_name" db:"skill_name"`
	ProficiencyLevel *string   `json:"proficiency_level,omitempty" db:"proficiency_level"`
	Category         *string   `json:"category,omitempty" db:"category"`
	DisplayOrder     int       `json:"display_order" db:"display_order"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
}

// UserLanguage represents a user's language
type UserLanguage struct {
	ID               uuid.UUID `json:"id" db:"id"`
	UserID           uuid.UUID `json:"user_id" db:"user_id"`
	LanguageName     string    `json:"language_name" db:"language_name"`
	ProficiencyLevel *string   `json:"proficiency_level,omitempty" db:"proficiency_level"`
	DisplayOrder     int       `json:"display_order" db:"display_order"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
}

// UserVolunteering represents a user's volunteering experience
type UserVolunteering struct {
	ID               uuid.UUID  `json:"id" db:"id"`
	UserID           uuid.UUID  `json:"user_id" db:"user_id"`
	OrganizationName string     `json:"organization_name" db:"organization_name"`
	Role             string     `json:"role" db:"role"`
	StartDate        time.Time  `json:"start_date" db:"start_date"`
	EndDate          *time.Time `json:"end_date,omitempty" db:"end_date"`
	IsCurrent        bool       `json:"is_current" db:"is_current"`
	Description      *string    `json:"description,omitempty" db:"description"`
	DisplayOrder     int        `json:"display_order" db:"display_order"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at" db:"updated_at"`
}

// UserPublication represents a user's publication
type UserPublication struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	UserID          uuid.UUID  `json:"user_id" db:"user_id"`
	Title           string     `json:"title" db:"title"`
	PublicationType *string    `json:"publication_type,omitempty" db:"publication_type"`
	Publisher       *string    `json:"publisher,omitempty" db:"publisher"`
	PublicationDate *time.Time `json:"publication_date,omitempty" db:"publication_date"`
	PublicationURL  *string    `json:"publication_url,omitempty" db:"publication_url"`
	Description     *string    `json:"description,omitempty" db:"description"`
	DisplayOrder    int        `json:"display_order" db:"display_order"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

// UserInterest represents a user's interest
type UserInterest struct {
	ID           uuid.UUID `json:"id" db:"id"`
	UserID       uuid.UUID `json:"user_id" db:"user_id"`
	InterestName string    `json:"interest_name" db:"interest_name"`
	Category     *string   `json:"category,omitempty" db:"category"`
	DisplayOrder int       `json:"display_order" db:"display_order"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// UserAchievement represents a user's achievement
type UserAchievement struct {
	ID                  uuid.UUID  `json:"id" db:"id"`
	UserID              uuid.UUID  `json:"user_id" db:"user_id"`
	Title               string     `json:"title" db:"title"`
	AchievementType     *string    `json:"achievement_type,omitempty" db:"achievement_type"`
	IssuingOrganization *string    `json:"issuing_organization,omitempty" db:"issuing_organization"`
	AchievementDate     *time.Time `json:"achievement_date,omitempty" db:"achievement_date"`
	Description         *string    `json:"description,omitempty" db:"description"`
	DisplayOrder        int        `json:"display_order" db:"display_order"`
	CreatedAt           time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at" db:"updated_at"`
}

// UserEducation represents a user's education entry
type UserEducation struct {
	ID           uuid.UUID  `json:"id" db:"id"`
	UserID       uuid.UUID  `json:"user_id" db:"user_id"`
	SchoolName   string     `json:"school_name" db:"school_name"`
	Degree       *string    `json:"degree,omitempty" db:"degree"`
	FieldOfStudy *string    `json:"field_of_study,omitempty" db:"field_of_study"`
	StartDate    time.Time  `json:"start_date" db:"start_date"`
	EndDate      *time.Time `json:"end_date,omitempty" db:"end_date"`
	IsCurrent    bool       `json:"is_current" db:"is_current"`
	Description  *string    `json:"description,omitempty" db:"description"`
	DisplayOrder int        `json:"display_order" db:"display_order"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`
}

// CreateExperienceRequest represents the request to add experience
type CreateExperienceRequest struct {
	CompanyName    string  `json:"company_name" validate:"required,max=150"`
	Title          string  `json:"title" validate:"required,max=150"`
	EmploymentType *string `json:"employment_type,omitempty" validate:"omitempty,oneof=full-time part-time contract internship freelance self-employed"`
	StartDate      string  `json:"start_date" validate:"required"` // YYYY-MM-DD
	EndDate        *string `json:"end_date,omitempty"`             // YYYY-MM-DD or null
	IsCurrent      bool    `json:"is_current"`
	Description    *string `json:"description,omitempty" validate:"omitempty,max=200"`
	IsPublic       bool    `json:"is_public"`
}

// UpdateExperienceRequest represents the request to update experience
type UpdateExperienceRequest struct {
	CompanyName    *string `json:"company_name,omitempty" validate:"omitempty,max=150"`
	Title          *string `json:"title,omitempty" validate:"omitempty,max=150"`
	EmploymentType *string `json:"employment_type,omitempty" validate:"omitempty,oneof=full-time part-time contract internship freelance self-employed"`
	StartDate      *string `json:"start_date,omitempty"` // YYYY-MM-DD
	EndDate        *string `json:"end_date,omitempty"`   // YYYY-MM-DD or null
	IsCurrent      *bool   `json:"is_current,omitempty"`
	Description    *string `json:"description,omitempty" validate:"omitempty,max=200"`
	IsPublic       *bool   `json:"is_public,omitempty"`
}

// CreateEducationRequest represents the request to add education
type CreateEducationRequest struct {
	SchoolName   string  `json:"school_name" validate:"required,max=150"`
	Degree       *string `json:"degree,omitempty" validate:"omitempty,max=150"`
	FieldOfStudy *string `json:"field_of_study,omitempty" validate:"omitempty,max=150"`
	StartDate    string  `json:"start_date" validate:"required"` // YYYY-MM-DD
	EndDate      *string `json:"end_date,omitempty"`             // YYYY-MM-DD or null
	IsCurrent    bool    `json:"is_current"`
	Description  *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// UpdateEducationRequest represents the request to update education
type UpdateEducationRequest struct {
	SchoolName   *string `json:"school_name,omitempty" validate:"omitempty,max=150"`
	Degree       *string `json:"degree,omitempty" validate:"omitempty,max=150"`
	FieldOfStudy *string `json:"field_of_study,omitempty" validate:"omitempty,max=150"`
	StartDate    *string `json:"start_date,omitempty"` // YYYY-MM-DD
	EndDate      *string `json:"end_date,omitempty"`   // YYYY-MM-DD or null
	IsCurrent    *bool   `json:"is_current,omitempty"`
	Description  *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// ToUser converts User model to a safe version without sensitive data
func (u *User) ToSafeUser() *User {
	return &User{
		ID:              u.ID,
		Email:           u.Email,
		Username:        u.Username,
		DisplayName:     u.DisplayName,
		Age:             u.Age,
		IsEmailVerified: u.IsEmailVerified,
		OAuthProvider:   u.OAuthProvider,
		ProfilePicture:  u.ProfilePicture,
		CoverPhoto:      u.CoverPhoto,
		IsActive:        u.IsActive,
		LastLoginAt:     u.LastLoginAt,
		CreatedAt:       u.CreatedAt,
		UpdatedAt:       u.UpdatedAt,
		Bio:             u.Bio,
		Location:        u.Location,
		Gender:          u.Gender,
		GenderCustom:    u.GenderCustom,
		Website:         u.Website,
		IsVerified:      u.IsVerified,
		ProfilePrivacy:  u.ProfilePrivacy,
		FieldVisibility: u.FieldVisibility,
		StatVisibility:  u.StatVisibility,
		Story:           u.Story,
		Ambition:        u.Ambition,
		PostsCount:      u.PostsCount,
		ProjectsCount:   u.ProjectsCount,
		FollowersCount:  u.FollowersCount,
		FollowingCount:  u.FollowingCount,
		SocialLinks:     u.SocialLinks,
	}
}

// Request/Response models for advanced profile features

// CreateCertificationRequest represents request to add certification
type CreateCertificationRequest struct {
	Name                string  `json:"name" validate:"required,max=200"`
	IssuingOrganization *string `json:"issuing_organization,omitempty" validate:"omitempty,max=150"`
	IssueDate           string  `json:"issue_date" validate:"required"` // YYYY-MM-DD
	ExpirationDate      *string `json:"expiration_date,omitempty"`      // YYYY-MM-DD
	CredentialID        *string `json:"credential_id,omitempty" validate:"omitempty,max=100"`
	CredentialURL       *string `json:"credential_url,omitempty" validate:"omitempty,url"`
	Description         *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// UpdateCertificationRequest represents request to update certification
type UpdateCertificationRequest struct {
	Name                *string `json:"name,omitempty" validate:"omitempty,max=200"`
	IssuingOrganization *string `json:"issuing_organization,omitempty" validate:"omitempty,max=150"`
	IssueDate           *string `json:"issue_date,omitempty"`
	ExpirationDate      *string `json:"expiration_date,omitempty"`
	CredentialID        *string `json:"credential_id,omitempty" validate:"omitempty,max=100"`
	CredentialURL       *string `json:"credential_url,omitempty" validate:"omitempty,url"`
	Description         *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// CreateSkillRequest represents request to add skill
type CreateSkillRequest struct {
	SkillName        string  `json:"skill_name" validate:"required,max=100"`
	ProficiencyLevel *string `json:"proficiency_level,omitempty" validate:"omitempty,oneof=beginner intermediate advanced expert"`
	Category         *string `json:"category,omitempty" validate:"omitempty,max=50"`
}

// UpdateSkillRequest represents request to update skill
type UpdateSkillRequest struct {
	SkillName        *string `json:"skill_name,omitempty" validate:"omitempty,max=100"`
	ProficiencyLevel *string `json:"proficiency_level,omitempty" validate:"omitempty,oneof=beginner intermediate advanced expert"`
	Category         *string `json:"category,omitempty" validate:"omitempty,max=50"`
}

// CreateLanguageRequest represents request to add language
type CreateLanguageRequest struct {
	LanguageName     string  `json:"language_name" validate:"required,max=100"`
	ProficiencyLevel *string `json:"proficiency_level,omitempty" validate:"omitempty,oneof=basic conversational fluent native"`
}

// UpdateLanguageRequest represents request to update language
type UpdateLanguageRequest struct {
	LanguageName     *string `json:"language_name,omitempty" validate:"omitempty,max=100"`
	ProficiencyLevel *string `json:"proficiency_level,omitempty" validate:"omitempty,oneof=basic conversational fluent native"`
}

// CreateVolunteeringRequest represents request to add volunteering
type CreateVolunteeringRequest struct {
	OrganizationName string  `json:"organization_name" validate:"required,max=150"`
	Role             string  `json:"role" validate:"required,max=150"`
	StartDate        string  `json:"start_date" validate:"required"` // YYYY-MM-DD
	EndDate          *string `json:"end_date,omitempty"`
	IsCurrent        bool    `json:"is_current"`
	Description      *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// UpdateVolunteeringRequest represents request to update volunteering
type UpdateVolunteeringRequest struct {
	OrganizationName *string `json:"organization_name,omitempty" validate:"omitempty,max=150"`
	Role             *string `json:"role,omitempty" validate:"omitempty,max=150"`
	StartDate        *string `json:"start_date,omitempty"`
	EndDate          *string `json:"end_date,omitempty"`
	IsCurrent        *bool   `json:"is_current,omitempty"`
	Description      *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// CreatePublicationRequest represents request to add publication
type CreatePublicationRequest struct {
	Title           string  `json:"title" validate:"required,max=300"`
	PublicationType *string `json:"publication_type,omitempty" validate:"omitempty,max=50"`
	Publisher       *string `json:"publisher,omitempty" validate:"omitempty,max=150"`
	PublicationDate *string `json:"publication_date,omitempty"` // YYYY-MM-DD
	PublicationURL  *string `json:"publication_url,omitempty" validate:"omitempty,url"`
	Description     *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// UpdatePublicationRequest represents request to update publication
type UpdatePublicationRequest struct {
	Title           *string `json:"title,omitempty" validate:"omitempty,max=300"`
	PublicationType *string `json:"publication_type,omitempty" validate:"omitempty,max=50"`
	Publisher       *string `json:"publisher,omitempty" validate:"omitempty,max=150"`
	PublicationDate *string `json:"publication_date,omitempty"`
	PublicationURL  *string `json:"publication_url,omitempty" validate:"omitempty,url"`
	Description     *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// CreateInterestRequest represents request to add interest
type CreateInterestRequest struct {
	InterestName string  `json:"interest_name" validate:"required,max=100"`
	Category     *string `json:"category,omitempty" validate:"omitempty,max=50"`
}

// UpdateInterestRequest represents request to update interest
type UpdateInterestRequest struct {
	InterestName *string `json:"interest_name,omitempty" validate:"omitempty,max=100"`
	Category     *string `json:"category,omitempty" validate:"omitempty,max=50"`
}

// CreateAchievementRequest represents request to add achievement
type CreateAchievementRequest struct {
	Title               string  `json:"title" validate:"required,max=200"`
	AchievementType     *string `json:"achievement_type,omitempty" validate:"omitempty,max=50"`
	IssuingOrganization *string `json:"issuing_organization,omitempty" validate:"omitempty,max=150"`
	AchievementDate     *string `json:"achievement_date,omitempty"` // YYYY-MM-DD
	Description         *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// UpdateAchievementRequest represents request to update achievement
type UpdateAchievementRequest struct {
	Title               *string `json:"title,omitempty" validate:"omitempty,max=200"`
	AchievementType     *string `json:"achievement_type,omitempty" validate:"omitempty,max=50"`
	IssuingOrganization *string `json:"issuing_organization,omitempty" validate:"omitempty,max=150"`
	AchievementDate     *string `json:"achievement_date,omitempty"`
	Description         *string `json:"description,omitempty" validate:"omitempty,max=200"`
}

// CreateCompanyRequest represents request to create/find company
type CreateCompanyRequest struct {
	Name     string  `json:"name" validate:"required,max=150"`
	LogoURL  *string `json:"logo_url,omitempty" validate:"omitempty,url"`
	Website  *string `json:"website,omitempty" validate:"omitempty,url"`
	Industry *string `json:"industry,omitempty" validate:"omitempty,max=100"`
}

// UpdateExperienceRequest - Add CompanyID
type UpdateExperienceRequestWithCompany struct {
	CompanyName    *string    `json:"company_name,omitempty" validate:"omitempty,max=150"`
	CompanyID      *uuid.UUID `json:"company_id,omitempty"`
	Title          *string    `json:"title,omitempty" validate:"omitempty,max=150"`
	EmploymentType *string    `json:"employment_type,omitempty" validate:"omitempty,oneof=full-time part-time contract internship freelance self-employed"`
	StartDate      *string    `json:"start_date,omitempty"`
	EndDate        *string    `json:"end_date,omitempty"`
	IsCurrent      *bool      `json:"is_current,omitempty"`
	Description    *string    `json:"description,omitempty" validate:"omitempty,max=200"`
	IsPublic       *bool      `json:"is_public,omitempty"`
}

// CreateExperienceRequest - Add CompanyID
type CreateExperienceRequestWithCompany struct {
	CompanyName    string     `json:"company_name" validate:"required,max=150"`
	CompanyID      *uuid.UUID `json:"company_id,omitempty"`
	Title          string     `json:"title" validate:"required,max=150"`
	EmploymentType *string    `json:"employment_type,omitempty" validate:"omitempty,oneof=full-time part-time contract internship freelance self-employed"`
	StartDate      string     `json:"start_date" validate:"required"`
	EndDate        *string    `json:"end_date,omitempty"`
	IsCurrent      bool       `json:"is_current"`
	Description    *string    `json:"description,omitempty" validate:"omitempty,max=200"`
	IsPublic       bool       `json:"is_public"`
}

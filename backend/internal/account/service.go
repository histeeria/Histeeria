package account

import (
	"context"
	"fmt"
	"log"
	"mime/multipart"
	"time"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	"histeeria-backend/internal/utils"
	"histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// AccountService handles account management business logic
type AccountService struct {
	userRepo    repository.UserRepository
	sessionRepo repository.SessionRepository
	emailSvc    *utils.EmailService
	storageSvc  *utils.StorageService
}

// NewAccountService creates a new account service
func NewAccountService(userRepo repository.UserRepository, sessionRepo repository.SessionRepository, emailSvc *utils.EmailService, storageSvc *utils.StorageService) *AccountService {
	return &AccountService{
		userRepo:    userRepo,
		sessionRepo: sessionRepo,
		emailSvc:    emailSvc,
		storageSvc:  storageSvc,
	}
}

// GetProfile retrieves the user's profile
func (s *AccountService) GetProfile(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	return user.ToSafeUser(), nil
}

// UpdateProfile updates user profile fields
func (s *AccountService) UpdateProfile(ctx context.Context, userID uuid.UUID, req *models.UpdateProfileRequest) (*models.User, error) {
	// Validate the request
	if err := validateUpdateProfile(req); err != nil {
		return nil, err
	}

	// Get current user to verify existence
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Build updates map with only provided fields
	updates := make(map[string]interface{})

	if req.DisplayName != nil {
		updates["display_name"] = *req.DisplayName
	}

	if req.Age != nil {
		updates["age"] = *req.Age
	}

	if req.ProfilePicture != nil {
		updates["profile_picture"] = *req.ProfilePicture
	}

	// If no fields to update, return current user
	if len(updates) == 0 {
		return user.ToSafeUser(), nil
	}

	// Update profile
	if err := s.userRepo.UpdateProfile(ctx, userID, updates); err != nil {
		return nil, err
	}

	// Fetch updated user
	updatedUser, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	return updatedUser.ToSafeUser(), nil
}

// ChangePassword changes the user's password
func (s *AccountService) ChangePassword(ctx context.Context, userID uuid.UUID, req *models.ChangePasswordRequest) error {
	// Validate the request
	if err := validateChangePassword(req); err != nil {
		return err
	}

	// Get current user
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}

	// Check if user has a password (OAuth users might not)
	if user.PasswordHash == "" {
		return errors.NewAppError(400, "Cannot change password for OAuth-only accounts. Please set a password first.")
	}

	// Verify current password
	if !utils.CheckPasswordHash(req.CurrentPassword, user.PasswordHash) {
		return errors.NewAppError(401, "Current password is incorrect")
	}

	// Check new password matches confirmation
	if req.NewPassword != req.ConfirmPassword {
		return errors.NewAppError(400, "New password and confirmation do not match")
	}

	// Check new password is different from current
	if utils.CheckPasswordHash(req.NewPassword, user.PasswordHash) {
		return errors.NewAppError(400, "New password must be different from current password")
	}

	// Hash new password
	newPasswordHash, err := utils.HashPassword(req.NewPassword)
	if err != nil {
		return errors.ErrInternalServer
	}

	// Update password
	if err := s.userRepo.UpdatePassword(ctx, userID, newPasswordHash); err != nil {
		return err
	}

	// Send notification email asynchronously
	go s.emailSvc.SendPasswordChangedEmail(user.Email, user.DisplayName)

	return nil
}

// DeleteAccount permanently deletes a user account
func (s *AccountService) DeleteAccount(ctx context.Context, userID uuid.UUID, req *models.DeleteAccountRequest) error {
	// Validate the request
	if err := validateDeleteAccount(req); err != nil {
		return err
	}

	// Get current user
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}

	// Verify password (if user has one)
	if user.PasswordHash != "" {
		if !utils.CheckPasswordHash(req.Password, user.PasswordHash) {
			return errors.NewAppError(401, "Password is incorrect")
		}
	}

	// Verify confirmation text
	if req.Confirmation != "DELETE MY ACCOUNT" {
		return errors.NewAppError(400, "Confirmation text must be exactly 'DELETE MY ACCOUNT'")
	}

	// Send notification email before deletion
	go s.emailSvc.SendAccountDeletedEmail(user.Email, user.DisplayName)

	// Delete the user
	if err := s.userRepo.DeleteUser(ctx, userID); err != nil {
		return err
	}

	return nil
}

// ChangeEmail initiates the email change process
func (s *AccountService) ChangeEmail(ctx context.Context, userID uuid.UUID, req *models.ChangeEmailRequest) error {
	// Validate request
	if err := validateChangeEmail(req); err != nil {
		return err
	}

	// Get current user
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}

	// Verify password
	if user.PasswordHash != "" {
		if !utils.CheckPasswordHash(req.Password, user.PasswordHash) {
			return errors.NewAppError(401, "Password is incorrect")
		}
	}

	// Normalize new email
	newEmail := utils.NormalizeEmail(req.NewEmail)

	// Check if new email is same as current
	if newEmail == user.Email {
		return errors.NewAppError(400, "New email must be different from current email")
	}

	// Check if new email already exists
	exists, err := s.userRepo.CheckEmailExists(ctx, newEmail)
	if err != nil {
		return errors.ErrInternalServer
	}
	if exists {
		return errors.NewAppError(409, "Email already in use")
	}

	// Generate verification code
	code := s.emailSvc.GenerateVerificationCode()
	expiresAt := time.Now().Add(1 * time.Hour)

	// Store pending email change
	if err := s.userRepo.InitiateEmailChange(ctx, userID, newEmail, code, expiresAt); err != nil {
		return err
	}

	// Send verification email to NEW email address
	go s.emailSvc.SendEmailChangeVerificationEmail(newEmail, code)

	// Send notification to OLD email address (security best practice)
	go s.emailSvc.SendEmailChangeNotificationToOldEmail(user.Email, user.DisplayName, newEmail)

	return nil
}

// VerifyEmailChange completes the email change process
func (s *AccountService) VerifyEmailChange(ctx context.Context, userID uuid.UUID, req *models.VerifyEmailChangeRequest) error {
	// Validate request
	if err := validateVerifyEmailChange(req); err != nil {
		return err
	}

	// Complete the email change
	if err := s.userRepo.VerifyEmailChange(ctx, userID, req.VerificationCode); err != nil {
		return err
	}

	return nil
}

// ChangeUsername changes the user's username
func (s *AccountService) ChangeUsername(ctx context.Context, userID uuid.UUID, req *models.ChangeUsernameRequest) error {
	// Validate request
	if err := validateChangeUsername(req); err != nil {
		return err
	}

	// Get current user
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}

	// Verify password
	if user.PasswordHash != "" {
		if !utils.CheckPasswordHash(req.Password, user.PasswordHash) {
			return errors.NewAppError(401, "Password is incorrect")
		}
	}

	// Normalize new username
	newUsername := utils.NormalizeUsername(req.NewUsername)

	// Check if new username is same as current
	if newUsername == user.Username {
		return errors.NewAppError(400, "New username must be different from current username")
	}

	// Check if username already exists
	exists, err := s.userRepo.CheckUsernameExists(ctx, newUsername)
	if err != nil {
		return errors.ErrInternalServer
	}
	if exists {
		return errors.NewAppError(409, "Username already taken")
	}

	// Check if user changed username recently (optional: enforce 30-day limit)
	if user.UsernameChangedAt != nil {
		daysSinceLastChange := time.Since(*user.UsernameChangedAt).Hours() / 24
		if daysSinceLastChange < 30 {
			return errors.NewAppError(400, fmt.Sprintf("You can only change your username once every 30 days. Please wait %.0f more days.", 30-daysSinceLastChange))
		}
	}

	// Store old username for email notification
	oldUsername := user.Username

	// Update username
	if err := s.userRepo.ChangeUsername(ctx, userID, newUsername); err != nil {
		return err
	}

	// Send notification email
	go s.emailSvc.SendUsernameChangedEmail(user.Email, user.DisplayName, oldUsername, newUsername)

	return nil
}

// DeactivateAccount soft deletes the user account
func (s *AccountService) DeactivateAccount(ctx context.Context, userID uuid.UUID, req *models.DeactivateAccountRequest) error {
	// Validate request
	if err := validateDeactivateAccount(req); err != nil {
		return err
	}

	// Get current user
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}

	// Verify password (if user has one)
	if user.PasswordHash != "" {
		if !utils.CheckPasswordHash(req.Password, user.PasswordHash) {
			return errors.NewAppError(401, "Password is incorrect")
		}
	}

	// Deactivate account
	if err := s.userRepo.DeactivateAccount(ctx, userID); err != nil {
		return err
	}

	// Note: For reactivation, you'd need a separate endpoint that sets is_active back to true

	return nil
}

// GetActiveSessions retrieves all active sessions for a user
func (s *AccountService) GetActiveSessions(ctx context.Context, userID uuid.UUID) ([]*models.UserSession, error) {
	sessions, err := s.sessionRepo.GetSessionsByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Filter out expired sessions
	now := time.Now()
	activeSessions := make([]*models.UserSession, 0)
	for _, session := range sessions {
		if session.ExpiresAt.After(now) {
			activeSessions = append(activeSessions, session)
		}
	}

	return activeSessions, nil
}

// DeleteSession logs out from a specific session/device
func (s *AccountService) DeleteSession(ctx context.Context, userID, sessionID uuid.UUID) error {
	// Get the session to verify it belongs to the user
	session, err := s.sessionRepo.GetSessionByID(ctx, sessionID)
	if err != nil {
		return err
	}

	// Verify the session belongs to the requesting user
	if session.UserID != userID {
		return errors.NewAppError(403, "You can only delete your own sessions")
	}

	// Delete the session
	if err := s.sessionRepo.DeleteSession(ctx, sessionID); err != nil {
		return err
	}

	return nil
}

// LogoutAllDevices logs out from all devices except current (optional)
func (s *AccountService) LogoutAllDevices(ctx context.Context, userID uuid.UUID, currentSessionID *uuid.UUID) error {
	// Delete all sessions for the user, optionally except the current one
	if err := s.sessionRepo.DeleteAllUserSessions(ctx, userID, currentSessionID); err != nil {
		return err
	}

	return nil
}

// Validation functions

func validateUpdateProfile(req *models.UpdateProfileRequest) error {
	// At least one field must be provided
	if req.DisplayName == nil && req.Age == nil && req.ProfilePicture == nil {
		return errors.NewAppError(400, "At least one field must be provided for update")
	}

	// Validate display name
	if req.DisplayName != nil {
		name := *req.DisplayName
		if len(name) < 2 || len(name) > 50 {
			return errors.NewAppError(400, "Display name must be between 2 and 50 characters")
		}
	}

	// Validate age
	if req.Age != nil {
		age := *req.Age
		if age < 13 || age > 120 {
			return errors.NewAppError(400, "Age must be between 13 and 120")
		}
	}

	// Profile picture validation (URL format) is handled by validator tag

	return nil
}

func validateChangePassword(req *models.ChangePasswordRequest) error {
	if req.CurrentPassword == "" {
		return errors.NewAppError(400, "Current password is required")
	}

	if req.NewPassword == "" {
		return errors.NewAppError(400, "New password is required")
	}

	if len(req.NewPassword) < 8 {
		return errors.NewAppError(400, "New password must be at least 8 characters long")
	}

	if req.ConfirmPassword == "" {
		return errors.NewAppError(400, "Password confirmation is required")
	}

	return nil
}

func validateDeleteAccount(req *models.DeleteAccountRequest) error {
	if req.Password == "" {
		return errors.NewAppError(400, "Password is required")
	}

	if req.Confirmation != "DELETE MY ACCOUNT" {
		return errors.NewAppError(400, fmt.Sprintf("Confirmation must be exactly 'DELETE MY ACCOUNT', got '%s'", req.Confirmation))
	}

	return nil
}

// UploadProfilePicture uploads a profile picture and updates user profile
func (s *AccountService) UploadProfilePicture(ctx context.Context, userID uuid.UUID, file multipart.File, header *multipart.FileHeader) (string, error) {
	// Get current user
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return "", fmt.Errorf("failed to get user: %w", err)
	}

	// Upload new picture
	pictureURL, err := s.storageSvc.UploadProfilePicture(ctx, userID, file, header)
	if err != nil {
		return "", fmt.Errorf("failed to upload profile picture: %w", err)
	}

	// Delete old picture if it exists and is from our storage
	if user.ProfilePicture != nil && *user.ProfilePicture != "" {
		// Only delete if it's from our Supabase storage (contains our bucket name)
		go s.storageSvc.DeleteProfilePicture(context.Background(), *user.ProfilePicture)
	}

	// Update user profile with new picture URL
	updates := map[string]interface{}{
		"profile_picture": pictureURL,
	}
	if err := s.userRepo.UpdateProfile(ctx, userID, updates); err != nil {
		log.Printf("[AccountService] Failed to update profile with picture URL: %v", err)
		// If profile update fails, try to clean up uploaded file
		go s.storageSvc.DeleteProfilePicture(context.Background(), pictureURL)
		return "", fmt.Errorf("failed to update profile: %w", err)
	}

	log.Printf("[AccountService] Profile picture uploaded successfully for user %s: %s", userID, pictureURL)

	return pictureURL, nil
}

// UploadCoverPhoto uploads a cover photo and updates user profile
func (s *AccountService) UploadCoverPhoto(ctx context.Context, userID uuid.UUID, file multipart.File, header *multipart.FileHeader) (string, error) {
	// Get current user
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return "", fmt.Errorf("failed to get user: %w", err)
	}

	// Upload new cover photo
	coverPhotoURL, err := s.storageSvc.UploadCoverPhoto(ctx, userID, file, header)
	if err != nil {
		return "", fmt.Errorf("failed to upload cover photo: %w", err)
	}

	// Delete old cover photo if it exists and is from our storage
	if user.CoverPhoto != nil && *user.CoverPhoto != "" {
		// Only delete if it's from our Supabase storage (contains our bucket name)
		go s.storageSvc.DeleteCoverPhoto(context.Background(), *user.CoverPhoto)
	}

	// Update user profile with new cover photo URL
	updates := map[string]interface{}{
		"cover_photo": coverPhotoURL,
	}
	if err := s.userRepo.UpdateProfile(ctx, userID, updates); err != nil {
		log.Printf("[AccountService] Failed to update profile with cover photo URL: %v", err)
		// If profile update fails, try to clean up uploaded file
		go s.storageSvc.DeleteCoverPhoto(context.Background(), coverPhotoURL)
		return "", fmt.Errorf("failed to update profile: %w", err)
	}

	log.Printf("[AccountService] Cover photo uploaded successfully for user %s: %s", userID, coverPhotoURL)

	return coverPhotoURL, nil
}

// ExportUserData exports all user data for GDPR compliance
// UpdateStatVisibility updates which stats are visible on user's profile
func (s *AccountService) UpdateStatVisibility(ctx context.Context, userID uuid.UUID, statVisibility map[string]bool) error {
	return s.userRepo.UpdateStatVisibility(ctx, userID, statVisibility)
}

// UpdateLastUsed updates the user's last used timestamp
func (s *AccountService) UpdateLastUsed(ctx context.Context, userID uuid.UUID) error {
	return s.userRepo.UpdateLastUsed(ctx, userID)
}

// BlockUser blocks a user (complete barrier - no messaging, content hidden)
func (s *AccountService) BlockUser(ctx context.Context, blockerID, blockedID uuid.UUID) error {
	if blockerID == blockedID {
		return fmt.Errorf("cannot block yourself")
	}
	return s.userRepo.BlockUser(ctx, blockerID, blockedID)
}

// UnblockUser unblocks a user
func (s *AccountService) UnblockUser(ctx context.Context, blockerID, blockedID uuid.UUID) error {
	return s.userRepo.UnblockUser(ctx, blockerID, blockedID)
}

// RestrictUser restricts a user (their content is hidden from feed)
func (s *AccountService) RestrictUser(ctx context.Context, restrictorID, restrictedID uuid.UUID) error {
	if restrictorID == restrictedID {
		return fmt.Errorf("cannot restrict yourself")
	}
	return s.userRepo.RestrictUser(ctx, restrictorID, restrictedID)
}

// UnrestrictUser unrestricts a user
func (s *AccountService) UnrestrictUser(ctx context.Context, restrictorID, restrictedID uuid.UUID) error {
	return s.userRepo.UnrestrictUser(ctx, restrictorID, restrictedID)
}

// ReportUser reports a user for moderation purposes
func (s *AccountService) ReportUser(ctx context.Context, reporterID, reportedID uuid.UUID, reason, description string) error {
	if reporterID == reportedID {
		return fmt.Errorf("cannot report yourself")
	}
	if reason == "" {
		return fmt.Errorf("reason is required")
	}
	return s.userRepo.ReportUser(ctx, reporterID, reportedID, reason, description)
}

func (s *AccountService) ExportUserData(ctx context.Context, userID uuid.UUID) (map[string]interface{}, error) {
	// Get user data
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Get sessions
	sessions, err := s.sessionRepo.GetSessionsByUserID(ctx, userID)
	if err != nil {
		// If sessions fail, continue with user data only
		sessions = []*models.UserSession{}
	}

	// Prepare export data
	exportData := map[string]interface{}{
		"personal_information": map[string]interface{}{
			"id":           user.ID,
			"email":        user.Email,
			"username":     user.Username,
			"display_name": user.DisplayName,
			"age":          user.Age,
		},
		"account_status": map[string]interface{}{
			"is_email_verified": user.IsEmailVerified,
			"is_active":         user.IsActive,
			"oauth_provider":    user.OAuthProvider,
		},
		"profile": map[string]interface{}{
			"profile_picture": user.ProfilePicture,
		},
		"account_dates": map[string]interface{}{
			"created_at":          user.CreatedAt,
			"updated_at":          user.UpdatedAt,
			"last_login_at":       user.LastLoginAt,
			"username_changed_at": user.UsernameChangedAt,
		},
		"active_sessions": sessions,
		"export_metadata": map[string]interface{}{
			"exported_at":    time.Now(),
			"export_version": "1.0",
			"format":         "JSON",
		},
	}

	return exportData, nil
}

func validateChangeEmail(req *models.ChangeEmailRequest) error {
	if req.NewEmail == "" {
		return errors.NewAppError(400, "New email is required")
	}

	if req.Password == "" {
		return errors.NewAppError(400, "Password is required")
	}

	return nil
}

func validateVerifyEmailChange(req *models.VerifyEmailChangeRequest) error {
	if req.VerificationCode == "" {
		return errors.NewAppError(400, "Verification code is required")
	}

	if len(req.VerificationCode) != 6 {
		return errors.NewAppError(400, "Verification code must be 6 digits")
	}

	return nil
}

func validateChangeUsername(req *models.ChangeUsernameRequest) error {
	if req.NewUsername == "" {
		return errors.NewAppError(400, "New username is required")
	}

	if len(req.NewUsername) < 3 || len(req.NewUsername) > 20 {
		return errors.NewAppError(400, "Username must be between 3 and 20 characters")
	}

	if req.Password == "" {
		return errors.NewAppError(400, "Password is required")
	}

	return nil
}

func validateDeactivateAccount(req *models.DeactivateAccountRequest) error {
	if req.Password == "" {
		return errors.NewAppError(400, "Password is required")
	}

	return nil
}

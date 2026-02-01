package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"net/http"
	"time"

	"histeeria-backend/internal/cache"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/queue"
	"histeeria-backend/internal/repository"
	"histeeria-backend/internal/utils"
	"histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// AuthService handles authentication business logic
type AuthService struct {
	userRepo      repository.UserRepository
	emailSvc      *utils.EmailService
	queueProvider queue.QueueProvider // Queue provider for async email sending
	jwtSvc        *utils.JWTService
	blacklist     *utils.TokenBlacklist
	cacheProvider cache.CacheProvider // Generic cache provider (Redis or Memory)
}

// NewAuthService creates a new authentication service
func NewAuthService(
	userRepo repository.UserRepository,
	emailSvc *utils.EmailService,
	queueProvider queue.QueueProvider,
	jwtSvc *utils.JWTService,
	blacklist *utils.TokenBlacklist,
) *AuthService {
	return &AuthService{
		userRepo:      userRepo,
		emailSvc:      emailSvc,
		queueProvider: queueProvider,
		jwtSvc:        jwtSvc,
		blacklist:     blacklist,
		cacheProvider: nil, // Will be set if Redis is available
	}
}

// SetCacheProvider sets the cache provider for OTP caching
func (s *AuthService) SetCacheProvider(provider cache.CacheProvider) {
	s.cacheProvider = provider
}

// RegisterUser handles user registration
func (s *AuthService) RegisterUser(ctx context.Context, req *models.RegisterRequest) (*models.AuthResponse, error) {
	// Validate input
	if err := utils.ValidateRegistration(req); err != nil {
		return nil, err
	}

	// Normalize inputs
	email := utils.NormalizeEmail(req.Email)
	username := utils.NormalizeUsername(req.Username)

	// Check if email already exists
	emailExists, err := s.userRepo.CheckEmailExists(ctx, email)
	if err != nil {
		return nil, err
	}
	if emailExists {
		return nil, errors.ErrEmailAlreadyExists
	}

	// Check if username already exists
	usernameExists, err := s.userRepo.CheckUsernameExists(ctx, username)
	if err != nil {
		return nil, err
	}
	if usernameExists {
		return nil, errors.ErrUsernameExists
	}

	// Hash password
	passwordHash, err := utils.HashPassword(req.Password)
	if err != nil {
		return nil, errors.ErrInternalServer
	}

	// Generate email hash for privacy-preserving lookups
	emailHash := utils.GenerateEmailHash(email)

	// Handle verification code
	var verificationCode string
	var expiresAt time.Time
	var isEmailVerified bool

	if req.VerificationCode != nil {
		// OTP was provided - verify and consume it (delete from Redis)
		verified, err := s.ConsumeSignupOTP(ctx, email, *req.VerificationCode)
		if err == nil && verified {
			// OTP is valid - email is pre-verified
			isEmailVerified = true
			verificationCode = "" // No need to store code
			expiresAt = time.Now()
		} else {
			// OTP invalid or expired - generate new one
			verificationCode = s.emailSvc.GenerateVerificationCode()
			expiresAt = time.Now().Add(10 * time.Minute)
			isEmailVerified = false
		}
	} else {
		// Generate new verification code
		verificationCode = s.emailSvc.GenerateVerificationCode()
		expiresAt = time.Now().Add(10 * time.Minute) // 10 minutes expiry
		isEmailVerified = false
	}

	// Create user
	user := &models.User{
		ID:              uuid.New(),
		Email:           email,
		EmailHash:       emailHash,
		Username:        username,
		PasswordHash:    passwordHash,
		DisplayName:     req.DisplayName,
		Age:             18, // Default age, will be set if provided
		IsEmailVerified: isEmailVerified,
		EmailVerificationCode: func() *string {
			if verificationCode != "" {
				return &verificationCode
			}
			return nil
		}(),
		EmailVerificationExpiresAt: func() *time.Time {
			if !expiresAt.IsZero() {
				return &expiresAt
			}
			return nil
		}(),
		IsActive:  true,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	// Set optional fields
	if req.Age != nil {
		user.Age = *req.Age
	}
	if req.Gender != nil {
		user.Gender = req.Gender
	}
	if req.Bio != nil {
		user.Bio = req.Bio
	}
	if req.ProfilePicture != nil {
		user.ProfilePicture = req.ProfilePicture
	}

	// Save user to database
	if err := s.userRepo.CreateUser(ctx, user); err != nil {
		return nil, err
	}

	// If email is already verified (OTP was pre-verified), generate token immediately
	if isEmailVerified {
		// Generate JWT token
		token, err := s.jwtSvc.GenerateToken(user)
		if err != nil {
			log.Printf("[AuthService] RegisterUser - Token generation failed: %v", err)
		} else {
			// Update last login
			s.userRepo.UpdateLastLogin(ctx, user.ID)

			// Queue welcome email (async)
			if s.queueProvider != nil {
				if err := queue.QueueWelcomeEmail(ctx, s.queueProvider, user.Email, user.DisplayName); err != nil {
					log.Printf("[AuthService] Failed to queue welcome email: %v", err)
					// Don't fail registration if email queuing fails
				}
			} else {
				// Fallback to direct send if queue not available
				go s.emailSvc.SendWelcomeEmail(user.Email, user.DisplayName)
			}

			return &models.AuthResponse{
				Success:   true,
				Message:   "Registration and email verification successful",
				Token:     token,
				ExpiresAt: time.Now().Add(30 * 24 * time.Hour),
				User:      user.ToSafeUser(),
				UserID:    user.ID.String(),
			}, nil
		}
	}

	// Queue verification email (if code wasn't provided or verification failed)
	if !isEmailVerified && verificationCode != "" {
		if s.queueProvider != nil {
			if err := queue.QueueVerificationEmail(ctx, s.queueProvider, email, verificationCode); err != nil {
				log.Printf("[AuthService] Failed to queue verification email: %v", err)
				// Fallback to direct send if queue fails
				if fallbackErr := s.emailSvc.SendVerificationEmail(email, verificationCode); fallbackErr != nil {
					log.Printf("[AuthService] Failed to send verification email (fallback): %v", fallbackErr)
				}
			}
		} else {
			// Fallback to direct send if queue not available
			if err := s.emailSvc.SendVerificationEmail(email, verificationCode); err != nil {
				log.Printf("[AuthService] Failed to send verification email: %v", err)
			}
		}
	}

	// Return user object even if not verified, so frontend can proceed
	// Frontend will handle email verification separately if needed
	return &models.AuthResponse{
		Success: true,
		Message: "Registration successful. Please check your email for verification code.",
		User:    user.ToSafeUser(), // Include user object even if not verified
		UserID:  user.ID.String(),
	}, nil
}

// VerifyEmail handles email verification
func (s *AuthService) VerifyEmail(ctx context.Context, req *models.VerifyEmailRequest) (*models.AuthResponse, error) {
	// Validate input
	if err := utils.ValidateEmailVerification(req); err != nil {
		return nil, err
	}

	// Normalize email
	email := utils.NormalizeEmail(req.Email)

	// Verify email with code
	if err := s.userRepo.VerifyEmail(ctx, email, req.VerificationCode); err != nil {
		return nil, err
	}

	// Get user
	user, err := s.userRepo.GetUserByEmail(ctx, email)
	if err != nil {
		return nil, err
	}

	// Generate JWT token
	token, err := s.jwtSvc.GenerateToken(user)
	if err != nil {
		log.Printf("[AuthService] VerifyEmail - Token generation failed: %v", err)
		return nil, errors.ErrInternalServer
	}

	// Update last login
	s.userRepo.UpdateLastLogin(ctx, user.ID)

	// Queue welcome email (async)
	if s.queueProvider != nil {
		if err := queue.QueueWelcomeEmail(ctx, s.queueProvider, user.Email, user.DisplayName); err != nil {
			log.Printf("[AuthService] Failed to queue welcome email: %v", err)
			// Fallback to direct send if queue fails
			go s.emailSvc.SendWelcomeEmail(user.Email, user.DisplayName)
		}
	} else {
		// Fallback to direct send if queue not available
		go s.emailSvc.SendWelcomeEmail(user.Email, user.DisplayName)
	}

	return &models.AuthResponse{
		Success:   true,
		Message:   "Email verified successfully",
		Token:     token,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour), // 30 days
		User:      user.ToSafeUser(),
	}, nil
}

// LoginUser handles user login
func (s *AuthService) LoginUser(ctx context.Context, req *models.LoginRequest) (*models.AuthResponse, error) {
	// Validate input
	if err := utils.ValidateLogin(req); err != nil {
		return nil, err
	}

	// Normalize input
	emailOrUsername := utils.NormalizeEmail(req.EmailOrUsername)

	// Get user by email or username
	user, err := s.userRepo.GetUserByEmailOrUsername(ctx, emailOrUsername)
	if err != nil {
		return nil, errors.ErrInvalidCredentials
	}

	// Check if user is active
	if !user.IsActive {
		return nil, errors.ErrUserInactive
	}

	// Verify password
	if !utils.CheckPasswordHash(req.Password, user.PasswordHash) {
		return nil, errors.ErrInvalidCredentials
	}

	// Check if email is verified
	if !user.IsEmailVerified {
		return nil, errors.ErrEmailNotVerified
	}

	// Generate JWT token
	token, err := s.jwtSvc.GenerateToken(user)
	if err != nil {
		return nil, errors.ErrInternalServer
	}

	// Update last login
	s.userRepo.UpdateLastLogin(ctx, user.ID)

	return &models.AuthResponse{
		Success:   true,
		Message:   "Login successful",
		Token:     token,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour), // 30 days
		User:      user.ToSafeUser(),
	}, nil
}

// ForgotPassword handles password reset request
func (s *AuthService) ForgotPassword(ctx context.Context, req *models.ForgotPasswordRequest) (*models.MessageResponse, error) {
	// Validate input
	if err := utils.ValidateForgotPassword(req); err != nil {
		return nil, err
	}

	// Normalize email
	email := utils.NormalizeEmail(req.Email)

	// Check if user exists
	_, err := s.userRepo.GetUserByEmail(ctx, email)
	if err != nil {
		// Don't reveal if user exists or not for security
		return &models.MessageResponse{
			Success: true,
			Message: "If the email exists, a password reset link has been sent.",
		}, nil
	}

	// Generate reset token
	resetToken, err := generateResetToken()
	if err != nil {
		return nil, errors.ErrInternalServer
	}

	// Set expiry (1 hour)
	expiresAt := time.Now().Add(1 * time.Hour)

	// Update user with reset token
	if err := s.userRepo.UpdatePasswordReset(ctx, email, resetToken, expiresAt); err != nil {
		return nil, errors.ErrInternalServer
	}

	// Queue password reset email (async)
	if s.queueProvider != nil {
		if err := queue.QueuePasswordResetEmail(ctx, s.queueProvider, email, resetToken); err != nil {
			log.Printf("[AuthService] Failed to queue password reset email: %v", err)
			// Fallback to direct send if queue fails
			if fallbackErr := s.emailSvc.SendPasswordResetEmail(email, resetToken); fallbackErr != nil {
				log.Printf("[AuthService] Failed to send password reset email (fallback): %v", fallbackErr)
			}
		}
	} else {
		// Fallback to direct send if queue not available
		if err := s.emailSvc.SendPasswordResetEmail(email, resetToken); err != nil {
			log.Printf("[AuthService] Failed to send password reset email: %v", err)
		}
	}

	return &models.MessageResponse{
		Success: true,
		Message: "If the email exists, a password reset link has been sent.",
	}, nil
}

// ResetPassword handles password reset
func (s *AuthService) ResetPassword(ctx context.Context, req *models.ResetPasswordRequest) (*models.MessageResponse, error) {
	// Validate input
	if err := utils.ValidateResetPassword(req); err != nil {
		return nil, err
	}

	// Hash new password
	newPasswordHash, err := utils.HashPassword(req.NewPassword)
	if err != nil {
		return nil, errors.ErrInternalServer
	}

	// Reset password
	if err := s.userRepo.ResetPassword(ctx, req.Token, newPasswordHash); err != nil {
		return nil, err
	}

	return &models.MessageResponse{
		Success: true,
		Message: "Password reset successfully",
	}, nil
}

// GetCurrentUser retrieves current user information
func (s *AuthService) GetCurrentUser(ctx context.Context, userID uuid.UUID) (*models.UserResponse, error) {
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	return &models.UserResponse{
		Success: true,
		User:    user.ToSafeUser(),
	}, nil
}

// RefreshToken handles token refresh
func (s *AuthService) RefreshToken(ctx context.Context, userID uuid.UUID) (*models.TokenResponse, error) {
	// Get user
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Check if user is active
	if !user.IsActive {
		return nil, errors.ErrUserInactive
	}

	// Generate new token
	token, err := s.jwtSvc.GenerateToken(user)
	if err != nil {
		return nil, errors.ErrInternalServer
	}

	return &models.TokenResponse{
		Success:   true,
		Message:   "Token refreshed successfully",
		Token:     token,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour), // 30 days
	}, nil
}

// LogoutUser handles user logout by blacklisting the token
func (s *AuthService) LogoutUser(ctx context.Context, userID uuid.UUID, token string) (*models.MessageResponse, error) {
	// Validate the token first to get expiry
	claims, err := s.jwtSvc.ValidateToken(token)
	if err != nil {
		// Even if token is invalid/expired, we return success
		// to prevent token enumeration attacks
		return &models.MessageResponse{
			Success: true,
			Message: "Logged out successfully",
		}, nil
	}

	// Add token to blacklist until it expires
	// The blacklist service will automatically clean it up
	if s.blacklist != nil {
		s.blacklist.Add(token, claims.ExpiresAt.Time)
	}

	return &models.MessageResponse{
		Success: true,
		Message: "Logged out successfully",
	}, nil
}

// CheckUsernameExists checks if username is available
func (s *AuthService) CheckUsernameExists(ctx context.Context, username string) (bool, error) {
	return s.userRepo.CheckUsernameExists(ctx, username)
}

// SendOTPForSignup sends an OTP to email for signup flow (before registration)
// This allows users to verify their email before completing registration
func (s *AuthService) SendOTPForSignup(ctx context.Context, email string) (*models.MessageResponse, error) {
	// Normalize email
	normalizedEmail := utils.NormalizeEmail(email)

	// Check if email already exists
	emailExists, err := s.userRepo.CheckEmailExists(ctx, normalizedEmail)
	if err != nil {
		return nil, err
	}
	if emailExists {
		return nil, errors.ErrEmailAlreadyExists
	}

	// Generate verification code
	verificationCode := s.emailSvc.GenerateVerificationCode()

	// Store OTP in cache with 10 minute expiry
	if s.cacheProvider != nil {
		otpKey := fmt.Sprintf("signup_otp:%s", normalizedEmail)
		if err := s.cacheProvider.Set(ctx, otpKey, verificationCode, 10*time.Minute); err != nil {
			log.Printf("[AuthService] Failed to store OTP in cache: %v", err)
			// Continue anyway - OTP will be sent but not cached
		}
	} else {
		log.Printf("[AuthService] WARNING: No cache provider configured, OTP for %s will not be cached", normalizedEmail)
	}

	// Queue verification email (async)
	if s.queueProvider != nil {
		if err := queue.QueueVerificationEmail(ctx, s.queueProvider, normalizedEmail, verificationCode); err != nil {
			log.Printf("[AuthService] Failed to queue verification email: %v", err)
			// Fallback to direct send if queue fails
			if fallbackErr := s.emailSvc.SendVerificationEmail(normalizedEmail, verificationCode); fallbackErr != nil {
				return nil, errors.ErrEmailSendError
			}
		}
	} else {
		// Fallback to direct send if queue not available
		if err := s.emailSvc.SendVerificationEmail(normalizedEmail, verificationCode); err != nil {
			return nil, errors.ErrEmailSendError
		}
	}

	return &models.MessageResponse{
		Success: true,
		Message: "Verification code sent to your email",
	}, nil
}

// VerifySignupOTP verifies OTP from signup flow (before registration)
// Note: This does NOT delete the OTP - it will be deleted during registration
// This allows the OTP to be verified on the OTP screen and then used during registration
func (s *AuthService) VerifySignupOTP(ctx context.Context, email, code string) (bool, error) {
	normalizedEmail := utils.NormalizeEmail(email)

	if s.cacheProvider == nil {
		return false, errors.NewAppError(http.StatusInternalServerError, "Cache provider not configured", "Server error")
	}

	otpKey := fmt.Sprintf("signup_otp:%s", normalizedEmail)

	// Get OTP from cache
	storedCode, err := s.cacheProvider.Get(ctx, otpKey)
	if err != nil {
		if cache.IsCacheMiss(err) {
			// OTP not found or expired
			return false, errors.ErrVerificationCodeExpired
		}
		return false, errors.ErrInternalServer
	}

	// Verify code matches (but don't delete - let registration delete it)
	if storedCode != code {
		return false, errors.ErrInvalidVerificationCode
	}

	return true, nil
}

// ConsumeSignupOTP verifies and deletes OTP from signup flow (used during registration)
func (s *AuthService) ConsumeSignupOTP(ctx context.Context, email, code string) (bool, error) {
	normalizedEmail := utils.NormalizeEmail(email)

	if s.cacheProvider == nil {
		return false, errors.NewAppError(http.StatusInternalServerError, "Cache provider not configured", "Server error")
	}

	otpKey := fmt.Sprintf("signup_otp:%s", normalizedEmail)

	// Get OTP from cache
	storedCode, err := s.cacheProvider.Get(ctx, otpKey)
	if err != nil {
		if cache.IsCacheMiss(err) {
			// OTP not found or expired
			return false, errors.ErrVerificationCodeExpired
		}
		return false, errors.ErrInternalServer
	}

	// Verify code matches
	if storedCode != code {
		return false, errors.ErrInvalidVerificationCode
	}

	// Delete OTP after successful verification (consumed during registration)
	s.cacheProvider.Delete(ctx, otpKey)

	return true, nil
}

// CompleteOAuthProfile completes OAuth user profile with additional required information
func (s *AuthService) CompleteOAuthProfile(ctx context.Context, userID uuid.UUID, req *struct {
	Password       string
	Username       string
	DisplayName    string
	Gender         *string
	Age            *int
	Bio            *string
	ProfilePicture *string
}) (*models.AuthResponse, error) {
	// Get user
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Check if user is OAuth user
	if user.OAuthProvider == nil {
		return nil, errors.NewAppError(http.StatusBadRequest, "User is not an OAuth user", "Only OAuth users can complete profile this way")
	}

	// Normalize username
	normalizedUsername := utils.NormalizeUsername(req.Username)

	// Check if username is already taken by another user
	exists, err := s.userRepo.CheckUsernameExists(ctx, normalizedUsername)
	if err != nil {
		return nil, err
	}
	if exists && user.Username != normalizedUsername {
		return nil, errors.ErrUsernameExists
	}

	// Hash password
	passwordHash, err := utils.HashPassword(req.Password)
	if err != nil {
		return nil, errors.ErrInternalServer
	}

	// Update user
	user.Username = normalizedUsername
	user.DisplayName = req.DisplayName
	user.PasswordHash = passwordHash
	if req.Gender != nil {
		user.Gender = req.Gender
	}
	if req.Age != nil {
		user.Age = *req.Age
	}
	if req.Bio != nil {
		user.Bio = req.Bio
	}
	if req.ProfilePicture != nil {
		user.ProfilePicture = req.ProfilePicture
	}
	user.UpdatedAt = time.Now()

	if err := s.userRepo.UpdateUser(ctx, user); err != nil {
		return nil, err
	}

	// Generate new JWT token with updated user info
	token, err := s.jwtSvc.GenerateToken(user)
	if err != nil {
		return nil, errors.ErrInternalServer
	}

	return &models.AuthResponse{
		Success:   true,
		Message:   "Profile completed successfully",
		Token:     token,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour),
		User:      user.ToSafeUser(),
	}, nil
}

// generateResetToken generates a secure random token for password reset
func generateResetToken() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

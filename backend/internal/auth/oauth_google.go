package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"time"

	"histeeria-backend/internal/config"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	"histeeria-backend/internal/utils"
	"histeeria-backend/pkg/errors"

	"github.com/google/uuid"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

// GoogleOAuthService handles Google OAuth authentication
type GoogleOAuthService struct {
	config   *oauth2.Config
	userRepo repository.UserRepository
	jwtSvc   *utils.JWTService
}

// GoogleUserInfo represents user information from Google
type GoogleUserInfo struct {
	ID            string `json:"id"`
	Email         string `json:"email"`
	VerifiedEmail bool   `json:"verified_email"`
	Name          string `json:"name"`
	GivenName     string `json:"given_name"`
	FamilyName    string `json:"family_name"`
	Picture       string `json:"picture"`
}

// NewGoogleOAuthService creates a new Google OAuth service
func NewGoogleOAuthService(cfg *config.GoogleConfig, userRepo repository.UserRepository, jwtSvc *utils.JWTService) *GoogleOAuthService {
	return &GoogleOAuthService{
		config: &oauth2.Config{
			ClientID:     cfg.ClientID,
			ClientSecret: cfg.ClientSecret,
			RedirectURL:  cfg.RedirectURL,
			Scopes: []string{
				"https://www.googleapis.com/auth/userinfo.email",
				"https://www.googleapis.com/auth/userinfo.profile",
			},
			Endpoint: google.Endpoint,
		},
		userRepo: userRepo,
		jwtSvc:   jwtSvc,
	}
}

// GetAuthURL returns the Google OAuth authorization URL
func (s *GoogleOAuthService) GetAuthURL(state string) string {
	return s.config.AuthCodeURL(state, oauth2.AccessTypeOffline)
}

// HandleCallback processes the Google OAuth callback
func (s *GoogleOAuthService) HandleCallback(ctx context.Context, code string) (*models.AuthResponse, error) {
	// Exchange authorization code for token
	token, err := s.config.Exchange(ctx, code)
	if err != nil {
		log.Printf("[GoogleOAuth] Failed to exchange code: %v", err)
		return nil, fmt.Errorf("failed to exchange authorization code: %w", err)
	}

	// Get user information from Google
	client := s.config.Client(ctx, token)
	resp, err := client.Get("https://www.googleapis.com/oauth2/v2/userinfo")
	if err != nil {
		log.Printf("[GoogleOAuth] Failed to get user info: %v", err)
		return nil, fmt.Errorf("failed to get user information: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("[GoogleOAuth] Failed to read user info: %v", err)
		return nil, fmt.Errorf("failed to read user information: %w", err)
	}

	var googleUser GoogleUserInfo
	if err := json.Unmarshal(data, &googleUser); err != nil {
		log.Printf("[GoogleOAuth] Failed to parse user info: %v", err)
		return nil, fmt.Errorf("failed to parse user information: %w", err)
	}

	// Validate email is verified
	if !googleUser.VerifiedEmail {
		return nil, errors.ErrEmailNotVerified
	}

	// Check if user exists by Google ID
	user, err := s.userRepo.GetUserByGoogleID(ctx, googleUser.ID)

	if err != nil {
		// Check if user exists by email (account linking)
		existingUser, emailErr := s.userRepo.GetUserByEmail(ctx, googleUser.Email)
		if emailErr == nil {
			// User exists with this email - link Google account
			existingUser.GoogleID = &googleUser.ID
			if existingUser.OAuthProvider == nil {
				provider := "google"
				existingUser.OAuthProvider = &provider
			}
			if googleUser.Picture != "" {
				existingUser.ProfilePicture = &googleUser.Picture
			}
			existingUser.IsEmailVerified = true // Google verified

			if err := s.userRepo.UpdateUser(ctx, existingUser); err != nil {
				log.Printf("[GoogleOAuth] Failed to link Google account: %v", err)
				return nil, errors.ErrDatabaseError
			}

			user = existingUser
		} else {
			// Create new user
			username := utils.GenerateUsernameFromEmail(googleUser.Email)

			// Ensure unique username
			username = utils.GenerateUniqueUsername(username, func(u string) bool {
				exists, _ := s.userRepo.CheckUsernameExists(ctx, u)
				return exists
			})

			provider := "google"
			user = &models.User{
				ID:              uuid.New(),
				Email:           googleUser.Email,
				EmailHash:       utils.GenerateEmailHash(googleUser.Email),
				Username:        username,
				PasswordHash:    "", // OAuth users don't have password
				DisplayName:     googleUser.Name,
				Age:             18,   // Default age
				IsEmailVerified: true, // Google verified
				GoogleID:        &googleUser.ID,
				OAuthProvider:   &provider,
				ProfilePicture:  &googleUser.Picture,
				IsActive:        true,
				CreatedAt:       time.Now(),
				UpdatedAt:       time.Now(),
			}

			if err := s.userRepo.CreateUser(ctx, user); err != nil {
				log.Printf("[GoogleOAuth] Failed to create user: %v", err)
				return nil, err
			}
		}
	}

	// Check if user is active
	if !user.IsActive {
		return nil, errors.ErrUserInactive
	}

	// Generate JWT token
	jwtToken, err := s.jwtSvc.GenerateToken(user)
	if err != nil {
		log.Printf("[GoogleOAuth] Failed to generate token: %v", err)
		return nil, errors.ErrInternalServer
	}

	// Update last login
	s.userRepo.UpdateLastLogin(ctx, user.ID)

	return &models.AuthResponse{
		Success:   true,
		Message:   "Google authentication successful",
		Token:     jwtToken,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour),
		User:      user.ToSafeUser(),
	}, nil
}

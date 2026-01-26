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
)

// LinkedInOAuthService handles LinkedIn OAuth authentication
type LinkedInOAuthService struct {
	config   *oauth2.Config
	userRepo repository.UserRepository
	jwtSvc   *utils.JWTService
}

// LinkedInUserInfo represents user information from LinkedIn
type LinkedInUserInfo struct {
	Sub           string `json:"sub"` // LinkedIn user ID
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
	Name          string `json:"name"`
	GivenName     string `json:"given_name"`
	FamilyName    string `json:"family_name"`
	Picture       string `json:"picture"`
}

// NewLinkedInOAuthService creates a new LinkedIn OAuth service
func NewLinkedInOAuthService(cfg *config.LinkedInConfig, userRepo repository.UserRepository, jwtSvc *utils.JWTService) *LinkedInOAuthService {
	return &LinkedInOAuthService{
		config: &oauth2.Config{
			ClientID:     cfg.ClientID,
			ClientSecret: cfg.ClientSecret,
			RedirectURL:  cfg.RedirectURL,
			Scopes:       []string{"openid", "profile", "email"},
			Endpoint: oauth2.Endpoint{
				AuthURL:  "https://www.linkedin.com/oauth/v2/authorization",
				TokenURL: "https://www.linkedin.com/oauth/v2/accessToken",
			},
		},
		userRepo: userRepo,
		jwtSvc:   jwtSvc,
	}
}

// GetAuthURL returns the LinkedIn OAuth authorization URL
func (s *LinkedInOAuthService) GetAuthURL(state string) string {
	return s.config.AuthCodeURL(state)
}

// HandleCallback processes the LinkedIn OAuth callback
func (s *LinkedInOAuthService) HandleCallback(ctx context.Context, code string) (*models.AuthResponse, error) {
	// Exchange authorization code for token
	token, err := s.config.Exchange(ctx, code)
	if err != nil {
		log.Printf("[LinkedInOAuth] Failed to exchange code: %v", err)
		return nil, fmt.Errorf("failed to exchange authorization code: %w", err)
	}

	// Get user information from LinkedIn (using OpenID Connect userinfo endpoint)
	client := s.config.Client(ctx, token)
	resp, err := client.Get("https://api.linkedin.com/v2/userinfo")
	if err != nil {
		log.Printf("[LinkedInOAuth] Failed to get user info: %v", err)
		return nil, fmt.Errorf("failed to get user information: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("[LinkedInOAuth] Failed to read user info: %v", err)
		return nil, fmt.Errorf("failed to read user information: %w", err)
	}

	var linkedinUser LinkedInUserInfo
	if err := json.Unmarshal(data, &linkedinUser); err != nil {
		log.Printf("[LinkedInOAuth] Failed to parse user info: %v", err)
		return nil, fmt.Errorf("failed to parse user information: %w", err)
	}

	// Validate email is verified
	if !linkedinUser.EmailVerified {
		return nil, errors.ErrEmailNotVerified
	}

	if linkedinUser.Email == "" {
		return nil, fmt.Errorf("no email provided by LinkedIn")
	}

	// Check if user exists by LinkedIn ID
	user, err := s.userRepo.GetUserByLinkedInID(ctx, linkedinUser.Sub)

	if err != nil {
		// Check if user exists by email (account linking)
		existingUser, emailErr := s.userRepo.GetUserByEmail(ctx, linkedinUser.Email)
		if emailErr == nil {
			// User exists - link LinkedIn account
			existingUser.LinkedInID = &linkedinUser.Sub
			if existingUser.OAuthProvider == nil {
				provider := "linkedin"
				existingUser.OAuthProvider = &provider
			}
			if linkedinUser.Picture != "" {
				existingUser.ProfilePicture = &linkedinUser.Picture
			}
			existingUser.IsEmailVerified = true

			if err := s.userRepo.UpdateUser(ctx, existingUser); err != nil {
				log.Printf("[LinkedInOAuth] Failed to link LinkedIn account: %v", err)
				return nil, errors.ErrDatabaseError
			}

			user = existingUser
		} else {
			// Create new user
			username := utils.GenerateUsernameFromEmail(linkedinUser.Email)

			username = utils.GenerateUniqueUsername(username, func(u string) bool {
				exists, _ := s.userRepo.CheckUsernameExists(ctx, u)
				return exists
			})

			displayName := linkedinUser.Name
			if displayName == "" {
				displayName = linkedinUser.GivenName + " " + linkedinUser.FamilyName
			}

			provider := "linkedin"
			user = &models.User{
				ID:              uuid.New(),
				Email:           linkedinUser.Email,
				EmailHash:       utils.GenerateEmailHash(linkedinUser.Email),
				Username:        username,
				PasswordHash:    "",
				DisplayName:     displayName,
				Age:             18,
				IsEmailVerified: true,
				LinkedInID:      &linkedinUser.Sub,
				OAuthProvider:   &provider,
				ProfilePicture:  &linkedinUser.Picture,
				IsActive:        true,
				CreatedAt:       time.Now(),
				UpdatedAt:       time.Now(),
			}

			if err := s.userRepo.CreateUser(ctx, user); err != nil {
				log.Printf("[LinkedInOAuth] Failed to create user: %v", err)
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
		log.Printf("[LinkedInOAuth] Failed to generate token: %v", err)
		return nil, errors.ErrInternalServer
	}

	// Update last login
	s.userRepo.UpdateLastLogin(ctx, user.ID)

	return &models.AuthResponse{
		Success:   true,
		Message:   "LinkedIn authentication successful",
		Token:     jwtToken,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour),
		User:      user.ToSafeUser(),
	}, nil
}

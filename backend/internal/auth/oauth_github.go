package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"strconv"
	"time"

	"histeeria-backend/internal/config"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	"histeeria-backend/internal/utils"
	"histeeria-backend/pkg/errors"

	"github.com/google/uuid"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/github"
)

// GitHubOAuthService handles GitHub OAuth authentication
type GitHubOAuthService struct {
	config   *oauth2.Config
	userRepo repository.UserRepository
	jwtSvc   *utils.JWTService
}

// GitHubUserInfo represents user information from GitHub
type GitHubUserInfo struct {
	ID        int    `json:"id"`
	Login     string `json:"login"`
	Email     string `json:"email"`
	Name      string `json:"name"`
	AvatarURL string `json:"avatar_url"`
	Bio       string `json:"bio"`
}

// GitHubEmailInfo represents email information from GitHub
type GitHubEmailInfo struct {
	Email      string `json:"email"`
	Primary    bool   `json:"primary"`
	Verified   bool   `json:"verified"`
	Visibility string `json:"visibility"`
}

// NewGitHubOAuthService creates a new GitHub OAuth service
func NewGitHubOAuthService(cfg *config.GitHubConfig, userRepo repository.UserRepository, jwtSvc *utils.JWTService) *GitHubOAuthService {
	return &GitHubOAuthService{
		config: &oauth2.Config{
			ClientID:     cfg.ClientID,
			ClientSecret: cfg.ClientSecret,
			RedirectURL:  cfg.RedirectURL,
			Scopes:       []string{"user:email", "read:user"},
			Endpoint:     github.Endpoint,
		},
		userRepo: userRepo,
		jwtSvc:   jwtSvc,
	}
}

// GetAuthURL returns the GitHub OAuth authorization URL
func (s *GitHubOAuthService) GetAuthURL(state string) string {
	return s.config.AuthCodeURL(state)
}

// HandleCallback processes the GitHub OAuth callback
func (s *GitHubOAuthService) HandleCallback(ctx context.Context, code string) (*models.AuthResponse, error) {
	// Exchange authorization code for token
	token, err := s.config.Exchange(ctx, code)
	if err != nil {
		log.Printf("[GitHubOAuth] Failed to exchange code: %v", err)
		return nil, fmt.Errorf("failed to exchange authorization code: %w", err)
	}

	client := s.config.Client(ctx, token)

	// Get user information
	resp, err := client.Get("https://api.github.com/user")
	if err != nil {
		log.Printf("[GitHubOAuth] Failed to get user info: %v", err)
		return nil, fmt.Errorf("failed to get user information: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("[GitHubOAuth] Failed to read user info: %v", err)
		return nil, fmt.Errorf("failed to read user information: %w", err)
	}

	var githubUser GitHubUserInfo
	if err := json.Unmarshal(data, &githubUser); err != nil {
		log.Printf("[GitHubOAuth] Failed to parse user info: %v", err)
		return nil, fmt.Errorf("failed to parse user information: %w", err)
	}

	// GitHub might not return email in user endpoint, fetch from emails endpoint
	if githubUser.Email == "" {
		emailResp, err := client.Get("https://api.github.com/user/emails")
		if err == nil {
			defer emailResp.Body.Close()
			emailData, err := io.ReadAll(emailResp.Body)
			if err == nil {
				var emails []GitHubEmailInfo
				if err := json.Unmarshal(emailData, &emails); err == nil {
					// Find primary verified email
					for _, email := range emails {
						if email.Primary && email.Verified {
							githubUser.Email = email.Email
							break
						}
					}
					// Fallback to first verified email
					if githubUser.Email == "" {
						for _, email := range emails {
							if email.Verified {
								githubUser.Email = email.Email
								break
							}
						}
					}
				}
			}
		}
	}

	if githubUser.Email == "" {
		return nil, fmt.Errorf("no verified email found in GitHub account")
	}

	// Check if user exists by GitHub ID
	githubIDStr := strconv.Itoa(githubUser.ID)
	user, err := s.userRepo.GetUserByGitHubID(ctx, githubIDStr)

	if err != nil {
		// Check if user exists by email (account linking)
		existingUser, emailErr := s.userRepo.GetUserByEmail(ctx, githubUser.Email)
		if emailErr == nil {
			// User exists - link GitHub account
			existingUser.GitHubID = &githubIDStr
			if existingUser.OAuthProvider == nil {
				provider := "github"
				existingUser.OAuthProvider = &provider
			}
			if githubUser.AvatarURL != "" {
				existingUser.ProfilePicture = &githubUser.AvatarURL
			}
			existingUser.IsEmailVerified = true

			if err := s.userRepo.UpdateUser(ctx, existingUser); err != nil {
				log.Printf("[GitHubOAuth] Failed to link GitHub account: %v", err)
				return nil, errors.ErrDatabaseError
			}

			user = existingUser
		} else {
			// Create new user
			username := githubUser.Login
			if username == "" {
				username = utils.GenerateUsernameFromEmail(githubUser.Email)
			}

			username = utils.GenerateUniqueUsername(username, func(u string) bool {
				exists, _ := s.userRepo.CheckUsernameExists(ctx, u)
				return exists
			})

			displayName := githubUser.Name
			if displayName == "" {
				displayName = githubUser.Login
			}

			provider := "github"
			user = &models.User{
				ID:              uuid.New(),
				Email:           githubUser.Email,
				EmailHash:       utils.GenerateEmailHash(githubUser.Email),
				Username:        username,
				PasswordHash:    "",
				DisplayName:     displayName,
				Age:             18,
				IsEmailVerified: true,
				GitHubID:        &githubIDStr,
				OAuthProvider:   &provider,
				ProfilePicture:  &githubUser.AvatarURL,
				IsActive:        true,
				CreatedAt:       time.Now(),
				UpdatedAt:       time.Now(),
			}

			if err := s.userRepo.CreateUser(ctx, user); err != nil {
				log.Printf("[GitHubOAuth] Failed to create user: %v", err)
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
		log.Printf("[GitHubOAuth] Failed to generate token: %v", err)
		return nil, errors.ErrInternalServer
	}

	// Update last login
	s.userRepo.UpdateLastLogin(ctx, user.ID)

	return &models.AuthResponse{
		Success:   true,
		Message:   "GitHub authentication successful",
		Token:     jwtToken,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour),
		User:      user.ToSafeUser(),
	}, nil
}

package auth

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"histeeria-backend/internal/cache"
	"histeeria-backend/internal/config"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	"histeeria-backend/internal/utils"
	"histeeria-backend/pkg/errors"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// AuthHandlers handles HTTP requests for authentication
type AuthHandlers struct {
	authSvc           *AuthService
	multiAccountSvc   *MultiAccountService
	jwtSvc            *utils.JWTService
	rateLimiter       *utils.RateLimiter      // Legacy rate limiter (kept for backward compatibility)
	distributedLimiter cache.RateLimiterInterface // Distributed rate limiter (Redis or in-memory)
	config            *config.Config
	googleOAuth       *GoogleOAuthService
	githubOAuth       *GitHubOAuthService
	linkedinOAuth     *LinkedInOAuthService
	sessionRepo       repository.SessionRepository
}

// NewAuthHandlers creates new authentication handlers
func NewAuthHandlers(
	authSvc *AuthService,
	multiAccountSvc *MultiAccountService,
	jwtSvc *utils.JWTService,
	rateLimiter *utils.RateLimiter,              // Legacy rate limiter (kept for backward compatibility)
	distributedLimiter cache.RateLimiterInterface, // Distributed rate limiter (Redis or in-memory)
	cfg *config.Config,
	googleOAuth *GoogleOAuthService,
	githubOAuth *GitHubOAuthService,
	linkedinOAuth *LinkedInOAuthService,
	sessionRepo repository.SessionRepository,
) *AuthHandlers {
	return &AuthHandlers{
		authSvc:           authSvc,
		multiAccountSvc:   multiAccountSvc,
		jwtSvc:            jwtSvc,
		rateLimiter:       rateLimiter,
		distributedLimiter: distributedLimiter,
		config:            cfg,
		googleOAuth:       googleOAuth,
		githubOAuth:       githubOAuth,
		linkedinOAuth:     linkedinOAuth,
		sessionRepo:       sessionRepo,
	}
}

// Helper function to create session from login
func (h *AuthHandlers) createSession(ctx context.Context, userID uuid.UUID, token string, c *gin.Context) error {
	// Hash the token for storage
	tokenHash := utils.HashToken(token)

	// Extract device info from request
	userAgent := c.GetHeader("User-Agent")
	ipAddress := c.ClientIP()

	// Create session
	session := &models.UserSession{
		UserID:    userID,
		TokenHash: tokenHash,
		UserAgent: &userAgent,
		IPAddress: &ipAddress,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour), // 30 days - same as JWT
		CreatedAt: time.Now(),
	}

	return h.sessionRepo.CreateSession(ctx, session)
}

// RegisterHandler handles user registration
func (h *AuthHandlers) RegisterHandler(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
			"error":   err.Error(),
		})
		return
	}

	response, err := h.authSvc.RegisterUser(c.Request.Context(), &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// VerifyEmailHandler handles email verification
func (h *AuthHandlers) VerifyEmailHandler(c *gin.Context) {
	var req models.VerifyEmailRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
			"error":   err.Error(),
		})
		return
	}

	response, err := h.authSvc.VerifyEmail(c.Request.Context(), &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	// Create session after successful email verification (login)
	if response.User != nil && response.Token != "" {
		go h.createSession(c.Request.Context(), response.User.ID, response.Token, c)
	}

	c.JSON(http.StatusOK, response)
}

// LoginHandler handles user login
func (h *AuthHandlers) LoginHandler(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
			"error":   err.Error(),
		})
		return
	}

	response, err := h.authSvc.LoginUser(c.Request.Context(), &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	// Create session to track this login
	if response.User != nil && response.Token != "" {
		go h.createSession(c.Request.Context(), response.User.ID, response.Token, c)
	}

	c.JSON(http.StatusOK, response)
}

// ForgotPasswordHandler handles password reset request
func (h *AuthHandlers) ForgotPasswordHandler(c *gin.Context) {
	var req models.ForgotPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
			"error":   err.Error(),
		})
		return
	}

	response, err := h.authSvc.ForgotPassword(c.Request.Context(), &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// ResetPasswordHandler handles password reset
func (h *AuthHandlers) ResetPasswordHandler(c *gin.Context) {
	var req models.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
			"error":   err.Error(),
		})
		return
	}

	response, err := h.authSvc.ResetPassword(c.Request.Context(), &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// MeHandler handles getting current user information
func (h *AuthHandlers) MeHandler(c *gin.Context) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "User not authenticated",
		})
		return
	}

	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	response, err := h.authSvc.GetCurrentUser(c.Request.Context(), userID)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// RefreshHandler handles token refresh
func (h *AuthHandlers) RefreshHandler(c *gin.Context) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "User not authenticated",
		})
		return
	}

	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	response, err := h.authSvc.RefreshToken(c.Request.Context(), userID)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// LogoutHandler handles user logout
func (h *AuthHandlers) LogoutHandler(c *gin.Context) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "User not authenticated",
		})
		return
	}

	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	// Extract token from Authorization header for blacklisting
	authHeader := c.GetHeader("Authorization")
	var token string
	if authHeader != "" {
		tokenParts := strings.Split(authHeader, " ")
		if len(tokenParts) == 2 && tokenParts[0] == "Bearer" {
			token = tokenParts[1]
		}
	}

	response, err := h.authSvc.LogoutUser(c.Request.Context(), userID, token)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	// Delete session from database
	if token != "" {
		tokenHash := utils.HashToken(token)
		go h.sessionRepo.DeleteSessionByTokenHash(c.Request.Context(), tokenHash)
	}

	c.JSON(http.StatusOK, response)
}

// GoogleLoginHandler initiates Google OAuth flow
func (h *AuthHandlers) GoogleLoginHandler(c *gin.Context) {
	// Generate state token for CSRF protection
	state := uuid.New().String()

	// Get Google auth URL
	authURL := h.googleOAuth.GetAuthURL(state)

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"auth_url": authURL,
		"state":    state, // Return state to frontend for validation
	})
}

// GoogleExchangeHandler exchanges Google OAuth code for token
func (h *AuthHandlers) GoogleExchangeHandler(c *gin.Context) {
	type ExchangeRequest struct {
		Code string `json:"code"`
	}

	var req ExchangeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
		})
		return
	}

	// Handle callback
	response, err := h.googleOAuth.HandleCallback(c.Request.Context(), req.Code)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	// Create session for OAuth login
	if response.User != nil && response.Token != "" {
		go h.createSession(c.Request.Context(), response.User.ID, response.Token, c)
	}

	c.JSON(http.StatusOK, response)
}

// GoogleCallbackHandler handles Google OAuth callback
func (h *AuthHandlers) GoogleCallbackHandler(c *gin.Context) {
	// Get authorization code and state
	code := c.Query("code")
	state := c.Query("state")

	if code == "" {
		// Redirect to frontend with error
		c.Redirect(http.StatusTemporaryRedirect, "http://localhost:3001/auth/callback?error=no_code&provider=google")
		return
	}

	// For direct callback from OAuth provider, redirect to frontend with code and state
	// Frontend will then call backend API to exchange code for token
	redirectURL := fmt.Sprintf("http://localhost:3001/auth/callback?provider=google&code=%s&state=%s",
		code, state)
	c.Redirect(http.StatusTemporaryRedirect, redirectURL)
}

// GitHubLoginHandler initiates GitHub OAuth flow
func (h *AuthHandlers) GitHubLoginHandler(c *gin.Context) {
	// Generate state token for CSRF protection
	state := uuid.New().String()

	// Get GitHub auth URL
	authURL := h.githubOAuth.GetAuthURL(state)

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"auth_url": authURL,
		"state":    state,
	})
}

// GitHubExchangeHandler exchanges GitHub OAuth code for token
func (h *AuthHandlers) GitHubExchangeHandler(c *gin.Context) {
	type ExchangeRequest struct {
		Code string `json:"code"`
	}

	var req ExchangeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
		})
		return
	}

	response, err := h.githubOAuth.HandleCallback(c.Request.Context(), req.Code)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	// Create session for OAuth login
	if response.User != nil && response.Token != "" {
		go h.createSession(c.Request.Context(), response.User.ID, response.Token, c)
	}

	c.JSON(http.StatusOK, response)
}

// GitHubCallbackHandler handles GitHub OAuth callback
func (h *AuthHandlers) GitHubCallbackHandler(c *gin.Context) {
	// Get authorization code and state
	code := c.Query("code")
	state := c.Query("state")

	if code == "" {
		c.Redirect(http.StatusTemporaryRedirect, "http://localhost:3001/auth/callback?error=no_code&provider=github")
		return
	}

	redirectURL := fmt.Sprintf("http://localhost:3001/auth/callback?provider=github&code=%s&state=%s",
		code, state)
	c.Redirect(http.StatusTemporaryRedirect, redirectURL)
}

// LinkedInLoginHandler initiates LinkedIn OAuth flow
func (h *AuthHandlers) LinkedInLoginHandler(c *gin.Context) {
	// Generate state token for CSRF protection
	state := uuid.New().String()

	// Get LinkedIn auth URL
	authURL := h.linkedinOAuth.GetAuthURL(state)

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"auth_url": authURL,
		"state":    state,
	})
}

// LinkedInExchangeHandler exchanges LinkedIn OAuth code for token
func (h *AuthHandlers) LinkedInExchangeHandler(c *gin.Context) {
	type ExchangeRequest struct {
		Code string `json:"code"`
	}

	var req ExchangeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
		})
		return
	}

	response, err := h.linkedinOAuth.HandleCallback(c.Request.Context(), req.Code)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	// Create session for OAuth login
	if response.User != nil && response.Token != "" {
		go h.createSession(c.Request.Context(), response.User.ID, response.Token, c)
	}

	c.JSON(http.StatusOK, response)
}

// LinkedInCallbackHandler handles LinkedIn OAuth callback
func (h *AuthHandlers) LinkedInCallbackHandler(c *gin.Context) {
	// Get authorization code and state
	code := c.Query("code")
	state := c.Query("state")

	if code == "" {
		c.Redirect(http.StatusTemporaryRedirect, "http://localhost:3001/auth/callback?error=no_code&provider=linkedin")
		return
	}

	redirectURL := fmt.Sprintf("http://localhost:3001/auth/callback?provider=linkedin&code=%s&state=%s",
		code, state)
	c.Redirect(http.StatusTemporaryRedirect, redirectURL)
}

// SendSignupOTPHandler sends OTP for signup flow
func (h *AuthHandlers) SendSignupOTPHandler(c *gin.Context) {
	var req struct {
		Email string `json:"email" validate:"required,email"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
			"error":   err.Error(),
		})
		return
	}

	response, err := h.authSvc.SendOTPForSignup(c.Request.Context(), req.Email)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// VerifySignupOTPHandler verifies OTP for signup flow (before registration)
func (h *AuthHandlers) VerifySignupOTPHandler(c *gin.Context) {
	var req struct {
		Email string `json:"email" validate:"required,email"`
		Code  string `json:"code" validate:"required,len=6"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
			"error":   err.Error(),
		})
		return
	}

	verified, err := h.authSvc.VerifySignupOTP(c.Request.Context(), req.Email, req.Code)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	if !verified {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid verification code",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Verification code is valid",
	})
}

// CheckUsernameHandler handles username availability check
func (h *AuthHandlers) CheckUsernameHandler(c *gin.Context) {
	username := c.Query("username")
	if username == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Username parameter is required",
		})
		return
	}

	// Normalize username
	normalizedUsername := utils.NormalizeUsername(username)

	// Validate username format
	if len(normalizedUsername) < 3 || len(normalizedUsername) > 20 {
		c.JSON(http.StatusOK, gin.H{
			"success":   true,
			"available": false,
			"message":   "Username must be between 3 and 20 characters",
		})
		return
	}

	// Check if username exists
	exists, err := h.authSvc.CheckUsernameExists(c.Request.Context(), normalizedUsername)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to check username availability",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"available": !exists,
		"message":   map[bool]string{true: "Username is available", false: "Username is already taken"}[!exists],
	})
}

// OAuthCompleteProfileHandler handles OAuth profile completion
func (h *AuthHandlers) OAuthCompleteProfileHandler(c *gin.Context) {
	// Get user ID from JWT (set by auth middleware)
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "User not authenticated",
		})
		return
	}

	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	var req struct {
		Password       string  `json:"password" validate:"required,min=8"`
		Username       string  `json:"username" validate:"required,min=3,max=20,alphanum"`
		DisplayName    string  `json:"display_name" validate:"required,min=2,max=50"`
		Gender         *string `json:"gender,omitempty"`
		Age            *int    `json:"age,omitempty" validate:"omitempty,min=13,max=120"`
		Bio            *string `json:"bio,omitempty" validate:"omitempty,max=200"`
		ProfilePicture *string `json:"profile_picture,omitempty"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request data",
			"error":   err.Error(),
		})
		return
	}

	// Convert to service struct format (without JSON tags)
	serviceReq := struct {
		Password       string
		Username       string
		DisplayName    string
		Gender         *string
		Age            *int
		Bio            *string
		ProfilePicture *string
	}{
		Password:       req.Password,
		Username:       req.Username,
		DisplayName:    req.DisplayName,
		Gender:         req.Gender,
		Age:            req.Age,
		Bio:            req.Bio,
		ProfilePicture: req.ProfilePicture,
	}

	response, err := h.authSvc.CompleteOAuthProfile(c.Request.Context(), userID, &serviceReq)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   appErr.Details,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// SetupRoutes sets up authentication routes with rate limiting
func (h *AuthHandlers) SetupRoutes(r *gin.RouterGroup) {
	auth := r.Group("/auth")
	{
		// Public routes (no authentication required, but rate limited)
		// Use distributed rate limiter (works across multiple servers)
		auth.POST("/register",
			RegisterRateLimitMiddleware(h.distributedLimiter),
			h.RegisterHandler)
		auth.POST("/verify-email", h.VerifyEmailHandler)
		auth.POST("/login",
			LoginRateLimitMiddleware(h.distributedLimiter),
			h.LoginHandler)
		auth.POST("/forgot-password", h.ForgotPasswordHandler)
		auth.POST("/reset-password",
			PasswordResetRateLimitMiddleware(h.distributedLimiter),
			h.ResetPasswordHandler)

		// Send OTP for signup (before registration)
		auth.POST("/send-signup-otp", h.SendSignupOTPHandler)

		// Verify OTP for signup (before registration)
		auth.POST("/verify-signup-otp", h.VerifySignupOTPHandler)

		// Username availability check
		auth.GET("/check-username", h.CheckUsernameHandler)

		// OAuth routes
		auth.GET("/google/login", h.GoogleLoginHandler)
		auth.GET("/google/callback", h.GoogleCallbackHandler)
		auth.POST("/google/exchange", h.GoogleExchangeHandler)
		auth.GET("/github/login", h.GitHubLoginHandler)
		auth.GET("/github/callback", h.GitHubCallbackHandler)
		auth.POST("/github/exchange", h.GitHubExchangeHandler)
		auth.GET("/linkedin/login", h.LinkedInLoginHandler)
		auth.GET("/linkedin/callback", h.LinkedInCallbackHandler)
		auth.POST("/linkedin/exchange", h.LinkedInExchangeHandler)

		// Protected routes (authentication required)
		auth.GET("/me", JWTAuthMiddleware(h.jwtSvc), h.MeHandler)
		auth.POST("/refresh", JWTAuthMiddleware(h.jwtSvc), h.RefreshHandler)
		auth.POST("/logout", JWTAuthMiddleware(h.jwtSvc), h.LogoutHandler)
		auth.POST("/oauth/complete-profile", JWTAuthMiddleware(h.jwtSvc), h.OAuthCompleteProfileHandler)

		// Multi-account routes (Instagram-style account switching)
		auth.GET("/accounts", JWTAuthMiddleware(h.jwtSvc), h.GetLinkedAccounts)
		auth.POST("/accounts/link", JWTAuthMiddleware(h.jwtSvc), h.LinkAccount)
		auth.POST("/accounts/switch", JWTAuthMiddleware(h.jwtSvc), h.SwitchAccount)
		auth.DELETE("/accounts/unlink/:userId", JWTAuthMiddleware(h.jwtSvc), h.UnlinkAccount)
		auth.POST("/accounts/primary", JWTAuthMiddleware(h.jwtSvc), h.SetPrimaryAccount)
	}
}

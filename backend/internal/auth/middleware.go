package auth

import (
	"log"
	"net/http"
	"strings"
	"time"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/utils"
	"histeeria-backend/pkg/errors"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// JWTAuthMiddleware validates JWT tokens
func JWTAuthMiddleware(jwtSvc *utils.JWTService) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get token from Authorization header
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Authorization header required",
			})
			c.Abort()
			return
		}

		// Check if header starts with "Bearer "
		tokenParts := strings.Split(authHeader, " ")
		if len(tokenParts) != 2 || tokenParts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Invalid authorization header format",
			})
			c.Abort()
			return
		}

		token := tokenParts[1]

		// Validate token
		claims, err := jwtSvc.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Invalid or expired token",
			})
			c.Abort()
			return
		}

		// Set user information in context
		c.Set("user_id", claims.UserID)
		c.Set("user_email", claims.Email)
		c.Set("user_username", claims.Username)

		// Sliding Window Token Refresh
		// If token is more than halfway to expiry (15+ days old), issue a new one
		timeUntilExpiry := time.Until(claims.ExpiresAt.Time)
		halfLife := 15 * 24 * time.Hour // Half of 30 days

		if timeUntilExpiry < halfLife {
			// Token is past halfway - issue a fresh 30-day token
			userID, _ := uuid.Parse(claims.UserID)
			user := &models.User{
				ID:       userID,
				Email:    claims.Email,
				Username: claims.Username,
			}

			newToken, err := jwtSvc.GenerateToken(user)
			if err == nil {
				// Send new token in response header for frontend to update
				c.Header("X-New-Token", newToken)
				log.Printf("[Auth] Token refreshed for user %s (was expiring in %v, refreshed to 30 days)", claims.UserID, timeUntilExpiry)
			}
		}

		// Continue to next handler
		c.Next()
	}
}

// OptionalJWTAuthMiddleware creates a middleware that doesn't require authentication
// but sets user info if token is present
func OptionalJWTAuthMiddleware(jwtSvc *utils.JWTService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.Next()
			return
		}

		tokenParts := strings.Split(authHeader, " ")
		if len(tokenParts) != 2 || tokenParts[0] != "Bearer" {
			c.Next()
			return
		}

		token := tokenParts[1]
		claims, err := jwtSvc.ValidateToken(token)
		if err != nil {
			c.Next()
			return
		}

		// Set user information in context
		c.Set("user_id", claims.UserID)
		c.Set("user_email", claims.Email)
		c.Set("user_username", claims.Username)

		c.Next()
	}
}

// GetCurrentUserID extracts user ID from context
func GetCurrentUserID(c *gin.Context) (string, error) {
	userID, exists := c.Get("user_id")
	if !exists {
		return "", errors.ErrUnauthorized
	}

	userIDStr, ok := userID.(string)
	if !ok {
		return "", errors.ErrUnauthorized
	}

	return userIDStr, nil
}

// GetCurrentUserEmail extracts user email from context
func GetCurrentUserEmail(c *gin.Context) (string, error) {
	email, exists := c.Get("user_email")
	if !exists {
		return "", errors.ErrUnauthorized
	}

	emailStr, ok := email.(string)
	if !ok {
		return "", errors.ErrUnauthorized
	}

	return emailStr, nil
}

// GetCurrentUserUsername extracts username from context
func GetCurrentUserUsername(c *gin.Context) (string, error) {
	username, exists := c.Get("user_username")
	if !exists {
		return "", errors.ErrUnauthorized
	}

	usernameStr, ok := username.(string)
	if !ok {
		return "", errors.ErrUnauthorized
	}

	return usernameStr, nil
}

// Note: jwtService needs to be initialized in the handlers file
// This will be resolved when we update the handlers to include the JWT service

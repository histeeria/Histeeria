package auth

import (
	"net/http"

	"histeeria-backend/internal/utils"
	"histeeria-backend/pkg/errors"

	"github.com/gin-gonic/gin"
)

// AdminAuthMiddleware checks if the authenticated user has admin privileges
// TODO: Implement proper admin role checking based on your user model
// This is a placeholder that needs to be implemented based on your admin system
func AdminAuthMiddleware(jwtSvc *utils.JWTService) gin.HandlerFunc {
	return func(c *gin.Context) {
		// First verify JWT token
		userID, exists := c.Get("user_id")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Authentication required",
			})
			c.Abort()
			return
		}

		// TODO: Check if user has admin role
		// This requires:
		// 1. Add 'role' or 'is_admin' field to user model
		// 2. Query user from database to check admin status
		// 3. Cache admin status in JWT token or session for performance
		
		// Example implementation (commented out):
		// userRepo := repository.GetUserRepository() // You'll need to inject this
		// user, err := userRepo.GetUserByID(c.Request.Context(), userID.(uuid.UUID))
		// if err != nil || !user.IsAdmin {
		//     c.JSON(http.StatusForbidden, gin.H{
		//         "success": false,
		//         "message": "Admin access required",
		//     })
		//     c.Abort()
		//     return
		// }

		// For now, this middleware will allow all authenticated users
		// SECURITY WARNING: This is a placeholder. Implement proper admin checking before production!
		_ = userID

		// Set admin flag in context
		c.Set("is_admin", true)
		c.Next()
	}
}

// RequireAdmin is a helper that returns 403 if user is not admin
func RequireAdmin(c *gin.Context) bool {
	isAdmin, exists := c.Get("is_admin")
	if !exists || !isAdmin.(bool) {
		appErr := errors.ErrForbidden
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
		})
		c.Abort()
		return false
	}
	return true
}

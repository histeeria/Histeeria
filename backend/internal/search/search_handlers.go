package search

import (
	"log"
	"net/http"
	"strconv"

	"histeeria-backend/pkg/errors"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// SearchHandlers handles HTTP requests for search
type SearchHandlers struct {
	service *SearchService
}

// NewSearchHandlers creates new search handlers
func NewSearchHandlers(service *SearchService) *SearchHandlers {
	return &SearchHandlers{
		service: service,
	}
}

// SearchUsers handles GET /api/v1/search/users
func (h *SearchHandlers) SearchUsers(c *gin.Context) {
	// Get search query
	query := c.Query("q")
	log.Printf("[SearchHandler] SearchUsers called with query: '%s'", query)
	
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Search query is required",
		})
		return
	}
	
	// Minimum query length for better results (reduced to 2 characters)
	if len(query) < 2 {
		log.Printf("[SearchHandler] Query too short (len=%d), returning empty results", len(query))
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"users":   []interface{}{},
			"total":   0,
			"page":    1,
			"limit":   20,
			"message": "Please enter at least 2 characters to search",
		})
		return
	}

	// Get pagination params
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	log.Printf("[SearchHandler] Calling service.SearchUsers with query='%s', page=%d, limit=%d", query, page, limit)
	
	// Search users
	users, total, err := h.service.SearchUsers(c.Request.Context(), query, page, limit)
	if err != nil {
		log.Printf("[SearchHandler] Error from service.SearchUsers: %v", err)
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
		})
		return
	}

	log.Printf("[SearchHandler] Found %d users (total: %d)", len(users), total)

	// Convert to safe user objects (remove sensitive data)
	safeUsers := make([]interface{}, 0, len(users))
	for _, user := range users {
		safeUser := map[string]interface{}{
			"id":              user.ID,
			"username":        user.Username,
			"display_name":    user.DisplayName,
			"profile_picture": user.ProfilePicture,
			"bio":             user.Bio,
			"location":        user.Location,
			"is_verified":     user.IsVerified,
			"followers_count": user.FollowersCount,
			"following_count": user.FollowingCount,
		}
		safeUsers = append(safeUsers, safeUser)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"users":   safeUsers,
		"total":   total,
		"page":    page,
		"limit":   limit,
	})
}

// SearchPosts handles GET /api/v1/search/posts
func (h *SearchHandlers) SearchPosts(c *gin.Context) {
	// Get search query first
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Search query is required",
		})
		return
	}
	
	// Minimum query length for better results (reduced to 2 characters)
	if len(query) < 2 {
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"posts":   []interface{}{},
			"total":   0,
			"page":    1,
			"limit":   20,
			"message": "Please enter at least 2 characters to search",
		})
		return
	}
	
	// Get current user ID from context (optional - can search without auth)
	userID := uuid.Nil // Default to nil UUID if not authenticated
	if userIDVal, exists := c.Get("userID"); exists {
		if userIDStr, ok := userIDVal.(string); ok {
			if parsedID, err := uuid.Parse(userIDStr); err == nil {
				userID = parsedID
			}
		}
	}

	// Get pagination params
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	// Search posts
	posts, total, err := h.service.SearchPosts(c.Request.Context(), query, userID, page, limit)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"posts":   posts,
		"total":   total,
		"page":    page,
		"limit":   limit,
	})
}

// SetupRoutes registers search routes
func (h *SearchHandlers) SetupRoutes(router *gin.RouterGroup) {
	search := router.Group("/search")
	{
		search.GET("/users", h.SearchUsers)
		search.GET("/posts", h.SearchPosts)
	}
}

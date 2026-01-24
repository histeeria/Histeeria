package social

import (
	"log"
	"net/http"
	"strconv"

	"histeeria-backend/internal/models"
	"histeeria-backend/pkg/errors"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// RelationshipHandlers handles HTTP requests for relationships
type RelationshipHandlers struct {
	service *RelationshipService
}

// NewRelationshipHandlers creates new relationship handlers
func NewRelationshipHandlers(service *RelationshipService) *RelationshipHandlers {
	return &RelationshipHandlers{
		service: service,
	}
}

// FollowUser handles POST /api/v1/relationships/follow/:userId
func (h *RelationshipHandlers) FollowUser(c *gin.Context) {
	log.Println("[FollowHandler] === FOLLOW REQUEST RECEIVED ===")

	// Get current user ID from JWT
	userID, exists := c.Get("user_id")
	if !exists {
		log.Println("[FollowHandler] No user_id in context - unauthorized")
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Unauthorized",
		})
		return
	}
	log.Printf("[FollowHandler] User ID from JWT: %v", userID)

	fromUserID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	// Get target user ID from URL
	targetUserIDStr := c.Param("userId")
	toUserID, err := uuid.Parse(targetUserIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid target user ID",
		})
		return
	}

	// Cannot follow yourself
	if fromUserID == toUserID {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "You cannot follow yourself",
		})
		return
	}

	// Call service
	log.Printf("[FollowHandler] Calling FollowUser service: from=%s to=%s", fromUserID, toUserID)
	response, err := h.service.FollowUser(c.Request.Context(), fromUserID, toUserID)
	if err != nil {
		log.Printf("[FollowHandler] FollowUser service error: %v", err)
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   err.Error(),
		})
		return
	}
	log.Printf("[FollowHandler] FollowUser service completed successfully")

	if !response.Success {
		c.JSON(http.StatusOK, response)
		return
	}

	c.JSON(http.StatusCreated, response)
}

// ConnectWithUser handles POST /api/v1/relationships/connect/:userId
func (h *RelationshipHandlers) ConnectWithUser(c *gin.Context) {
	// Get current user ID from JWT
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Unauthorized",
		})
		return
	}

	fromUserID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	// Get target user ID from URL
	targetUserIDStr := c.Param("userId")
	toUserID, err := uuid.Parse(targetUserIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid target user ID",
		})
		return
	}

	// Cannot connect with yourself
	if fromUserID == toUserID {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "You cannot connect with yourself",
		})
		return
	}

	// Parse request body
	var req struct {
		Message *string `json:"message"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		// Message is optional, so don't fail if body is empty
	}

	// Call service
	response, err := h.service.ConnectWithUser(c.Request.Context(), fromUserID, toUserID, req.Message)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
		})
		return
	}

	if !response.Success {
		c.JSON(http.StatusOK, response)
		return
	}

	c.JSON(http.StatusCreated, response)
}

// CollaborateWithUser handles POST /api/v1/relationships/collaborate/:userId
func (h *RelationshipHandlers) CollaborateWithUser(c *gin.Context) {
	// Get current user ID from JWT
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Unauthorized",
		})
		return
	}

	fromUserID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	// Get target user ID from URL
	targetUserIDStr := c.Param("userId")
	toUserID, err := uuid.Parse(targetUserIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid target user ID",
		})
		return
	}

	// Cannot collaborate with yourself
	if fromUserID == toUserID {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "You cannot collaborate with yourself",
		})
		return
	}

	// Parse request body
	var req struct {
		Message *string `json:"message"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		// Message is optional
	}

	// Call service
	response, err := h.service.CollaborateWithUser(c.Request.Context(), fromUserID, toUserID, req.Message)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
		})
		return
	}

	if !response.Success {
		c.JSON(http.StatusOK, response)
		return
	}

	c.JSON(http.StatusCreated, response)
}

// AcceptRequest handles POST /api/v1/relationships/requests/:requestId/accept
func (h *RelationshipHandlers) AcceptRequest(c *gin.Context) {
	// Get current user ID from JWT
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Unauthorized",
		})
		return
	}

	currentUserID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	// Get request ID from URL
	requestIDStr := c.Param("requestId")
	requestID, err := uuid.Parse(requestIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request ID",
		})
		return
	}

	// Call service
	response, err := h.service.AcceptRelationshipRequest(c.Request.Context(), currentUserID, requestID)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// RejectRequest handles POST /api/v1/relationships/requests/:requestId/reject
func (h *RelationshipHandlers) RejectRequest(c *gin.Context) {
	// Get current user ID from JWT
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Unauthorized",
		})
		return
	}

	currentUserID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	// Get request ID from URL
	requestIDStr := c.Param("requestId")
	requestID, err := uuid.Parse(requestIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request ID",
		})
		return
	}

	// Call service
	response, err := h.service.RejectRelationshipRequest(c.Request.Context(), currentUserID, requestID)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// RemoveRelationship handles DELETE /api/v1/relationships/:userId/:type
func (h *RelationshipHandlers) RemoveRelationship(c *gin.Context) {
	// Get current user ID from JWT
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Unauthorized",
		})
		return
	}

	fromUserID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	// Get target user ID from URL
	targetUserIDStr := c.Param("userId")
	toUserID, err := uuid.Parse(targetUserIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid target user ID",
		})
		return
	}

	// Get relationship type from URL
	relationshipTypeStr := c.Param("type")
	var relationshipType models.RelationshipType
	switch relationshipTypeStr {
	case "following":
		relationshipType = models.RelationshipFollowing
	case "connected":
		relationshipType = models.RelationshipConnected
	case "collaborating":
		relationshipType = models.RelationshipCollaborating
	default:
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid relationship type. Must be: following, connected, or collaborating",
		})
		return
	}

	// Call service
	response, err := h.service.RemoveRelationship(c.Request.Context(), fromUserID, toUserID, relationshipType)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// GetRelationshipStatus handles GET /api/v1/relationships/status/:userId
func (h *RelationshipHandlers) GetRelationshipStatus(c *gin.Context) {
	// Get current user ID from JWT (optional for this endpoint)
	var fromUserID uuid.UUID
	userID, exists := c.Get("user_id")
	if exists {
		var err error
		fromUserID, err = uuid.Parse(userID.(string))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"message": "Invalid user ID",
			})
			return
		}
	}

	// Get target user ID from URL
	targetUserIDStr := c.Param("userId")
	toUserID, err := uuid.Parse(targetUserIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid target user ID",
		})
		return
	}

	if fromUserID == uuid.Nil {
		// Not authenticated, return empty status
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"status": &models.RelationshipStatusResponse{
				IsFollowing:     false,
				IsFollower:      false,
				IsConnected:     false,
				IsCollaborating: false,
				HasPending:      false,
				IsBlocked:       false,
			},
		})
		return
	}

	// Call service
	status, err := h.service.GetRelationshipStatus(c.Request.Context(), fromUserID, toUserID)
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
		"status":  status,
	})
}

// GetRelationshipStats handles GET /api/v1/relationships/stats
func (h *RelationshipHandlers) GetRelationshipStats(c *gin.Context) {
	// Get current user ID from JWT
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Unauthorized",
		})
		return
	}

	currentUserID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	// Call service
	stats, err := h.service.GetRelationshipStats(c.Request.Context(), currentUserID)
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
		"stats":   stats,
	})
}

// GetRateLimitStatus handles GET /api/v1/relationships/rate-limit-status
func (h *RelationshipHandlers) GetRateLimitStatus(c *gin.Context) {
	// Get current user ID from JWT
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Unauthorized",
		})
		return
	}

	currentUserID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	// Get action type from query param (default to all)
	actionType := c.Query("action")
	if actionType == "" {
		actionType = "follow" // Default
	}

	// Call service
	rateLimitStatus, err := h.service.GetRateLimitInfo(c.Request.Context(), currentUserID, actionType)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
		})
		return
	}

	// Get all three action types
	followLimit, _ := h.service.GetRateLimitInfo(c.Request.Context(), currentUserID, "follow")
	connectLimit, _ := h.service.GetRateLimitInfo(c.Request.Context(), currentUserID, "connect")
	collabLimit, _ := h.service.GetRateLimitInfo(c.Request.Context(), currentUserID, "collaborate")

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"rate_limits": gin.H{
			"follow":      followLimit,
			"connect":     connectLimit,
			"collaborate": collabLimit,
		},
		"requested": rateLimitStatus,
	})
}

// GetFollowers handles GET /api/v1/relationships/followers
func (h *RelationshipHandlers) GetFollowers(c *gin.Context) {
	// Get current user ID from JWT (for authorization check)
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Unauthorized",
		})
		return
	}

	// Get pagination params
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	// Get target user ID (whose followers/following to fetch)
	// If not provided, use current user
	targetUserIDStr := c.Query("user_id")
	var targetUserID uuid.UUID
	var err error

	if targetUserIDStr != "" {
		targetUserID, err = uuid.Parse(targetUserIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"message": "Invalid user ID",
			})
			return
		}
	} else {
		// Default to current user if no user_id provided
		userID, _ := c.Get("user_id")
		targetUserID, err = uuid.Parse(userID.(string))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"message": "Invalid user ID",
			})
			return
		}
	}

	// Determine list type from URL path
	listType := "followers"
	if c.FullPath() == "/api/v1/relationships/following" {
		listType = "following"
	} else if c.FullPath() == "/api/v1/relationships/connections" {
		listType = "connections"
	} else if c.FullPath() == "/api/v1/relationships/collaborators" {
		listType = "collaborators"
	} else if c.FullPath() == "/api/v1/relationships/pending" {
		listType = "pending"
	}

	log.Printf("[GetFollowers] Fetching %s for user %s", listType, targetUserID)

	// Get relationships list
	users, total, err := h.service.GetRelationshipList(c.Request.Context(), targetUserID, listType, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to fetch relationships",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"users":   users,
		"total":   total,
		"page":    page,
		"limit":   limit,
	})
}

// SetupRoutes registers relationship routes
func (h *RelationshipHandlers) SetupRoutes(router *gin.RouterGroup) {
	relationships := router.Group("/relationships")
	{
		// Relationship actions
		relationships.POST("/follow/:userId", h.FollowUser)
		relationships.POST("/connect/:userId", h.ConnectWithUser)
		relationships.POST("/collaborate/:userId", h.CollaborateWithUser)

		// Request management
		relationships.POST("/requests/:requestId/accept", h.AcceptRequest)
		relationships.POST("/requests/:requestId/reject", h.RejectRequest)

		// Remove relationships
		relationships.DELETE("/:userId/:type", h.RemoveRelationship)

		// Status and stats
		relationships.GET("/status/:userId", h.GetRelationshipStatus)
		relationships.GET("/stats", h.GetRelationshipStats)
		relationships.GET("/rate-limit-status", h.GetRateLimitStatus)

		// Lists (simplified for now)
		relationships.GET("/followers", h.GetFollowers)
		relationships.GET("/following", h.GetFollowers)
		relationships.GET("/connections", h.GetFollowers)
		relationships.GET("/collaborators", h.GetFollowers)
		relationships.GET("/pending", h.GetFollowers)
	}
}

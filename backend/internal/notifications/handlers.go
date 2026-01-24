package notifications

import (
	"net/http"
	"strconv"

	"histeeria-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handlers manages notification HTTP handlers
type Handlers struct {
	service *NotificationService
}

// NewHandlers creates new notification handlers
func NewHandlers(service *NotificationService) *Handlers {
	return &Handlers{
		service: service,
	}
}

// =====================================================
// GET NOTIFICATIONS
// =====================================================

// GetNotifications handles GET /api/v1/notifications
func (h *Handlers) GetNotifications(c *gin.Context) {
	// Get current user ID from context
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

	// Parse query parameters
	categoryStr := c.Query("category")
	unreadStr := c.Query("unread")
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	// Parse limit and offset
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 || limit > 100 {
		limit = 20
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	// Parse category
	var category *models.NotificationCategory
	if categoryStr != "" {
		cat := models.NotificationCategory(categoryStr)
		category = &cat
	}

	// Parse unread filter
	var unread *bool
	if unreadStr != "" {
		unreadBool := unreadStr == "true"
		unread = &unreadBool
	}

	// Get notifications
	notifications, total, unreadCount, err := h.service.GetNotifications(
		c.Request.Context(),
		currentUserID,
		category,
		unread,
		limit,
		offset,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to fetch notifications",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"notifications": notifications,
		"total":         total,
		"unread":        unreadCount,
		"limit":         limit,
		"offset":        offset,
	})
}

// GetUnreadCount handles GET /api/v1/notifications/unread-count
func (h *Handlers) GetUnreadCount(c *gin.Context) {
	// Get current user ID from context
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

	// Parse category filter (optional)
	categoryStr := c.Query("category")
	var category *models.NotificationCategory
	if categoryStr != "" {
		cat := models.NotificationCategory(categoryStr)
		category = &cat
	}

	// Get total count
	total, err := h.service.GetUnreadCount(c.Request.Context(), currentUserID, category)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to fetch unread count",
		})
		return
	}

	// Get category counts
	categoryCounts, err := h.service.GetCategoryCounts(c.Request.Context(), currentUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to fetch category counts",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":         true,
		"total":           total,
		"category_counts": categoryCounts,
	})
}

// =====================================================
// UPDATE NOTIFICATIONS
// =====================================================

// MarkAsRead handles PATCH /api/v1/notifications/:id/read
func (h *Handlers) MarkAsRead(c *gin.Context) {
	// Get current user ID from context
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

	// Get notification ID from URL
	notificationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid notification ID",
		})
		return
	}

	// Mark as read
	if err := h.service.MarkAsRead(c.Request.Context(), notificationID, currentUserID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to mark as read",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Notification marked as read",
	})
}

// MarkAllAsRead handles PATCH /api/v1/notifications/read-all
func (h *Handlers) MarkAllAsRead(c *gin.Context) {
	// Get current user ID from context
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

	// Parse request body
	var req struct {
		Category *string `json:"category,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		// No body is fine, mark all
	}

	// Parse category
	var category *models.NotificationCategory
	if req.Category != nil {
		cat := models.NotificationCategory(*req.Category)
		category = &cat
	}

	// Mark all as read
	if err := h.service.MarkAllAsRead(c.Request.Context(), currentUserID, category); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to mark all as read",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "All notifications marked as read",
	})
}

// =====================================================
// DELETE NOTIFICATIONS
// =====================================================

// DeleteNotification handles DELETE /api/v1/notifications/:id
func (h *Handlers) DeleteNotification(c *gin.Context) {
	// Get current user ID from context
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

	// Get notification ID from URL
	notificationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid notification ID",
		})
		return
	}

	// Delete notification
	if err := h.service.DeleteNotification(c.Request.Context(), notificationID, currentUserID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to delete notification",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Notification deleted",
	})
}

// =====================================================
// INLINE ACTIONS
// =====================================================

// TakeAction handles POST /api/v1/notifications/:id/action
func (h *Handlers) TakeAction(c *gin.Context) {
	// Get current user ID from context
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

	// Get notification ID from URL
	notificationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid notification ID",
		})
		return
	}

	// Parse request body
	var req models.TakeActionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request body",
		})
		return
	}

	// Take action
	if err := h.service.TakeAction(c.Request.Context(), notificationID, currentUserID, req.ActionType); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Action taken successfully",
	})
}

// =====================================================
// PREFERENCES
// =====================================================

// GetPreferences handles GET /api/v1/notifications/preferences
func (h *Handlers) GetPreferences(c *gin.Context) {
	// Get current user ID from context
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

	// Get preferences
	prefs, err := h.service.GetPreferences(c.Request.Context(), currentUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to fetch preferences",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"preferences": prefs,
	})
}

// UpdatePreferences handles PATCH /api/v1/notifications/preferences
func (h *Handlers) UpdatePreferences(c *gin.Context) {
	// Get current user ID from context
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

	// Parse request body
	var req models.UpdateNotificationPreferencesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request body",
		})
		return
	}

	// Update preferences
	if err := h.service.UpdatePreferences(c.Request.Context(), currentUserID, &req); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to update preferences",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Preferences updated successfully",
	})
}

// =====================================================
// SETUP ROUTES
// =====================================================

// SetupRoutes registers notification routes
func (h *Handlers) SetupRoutes(router *gin.RouterGroup) {
	notifications := router.Group("/notifications")
	{
		// List and count
		notifications.GET("", h.GetNotifications)
		notifications.GET("/unread-count", h.GetUnreadCount)

		// Update
		notifications.PATCH("/:id/read", h.MarkAsRead)
		notifications.PATCH("/read-all", h.MarkAllAsRead)

		// Delete
		notifications.DELETE("/:id", h.DeleteNotification)

		// Actions
		notifications.POST("/:id/action", h.TakeAction)

		// Preferences
		notifications.GET("/preferences", h.GetPreferences)
		notifications.PATCH("/preferences", h.UpdatePreferences)
	}
}

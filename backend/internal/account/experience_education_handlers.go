package account

import (
	"net/http"

	"histeeria-backend/internal/models"
	"histeeria-backend/pkg/errors"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ExperienceEducationHandlers handles HTTP requests for experiences and education
type ExperienceEducationHandlers struct {
	service *ExperienceEducationService
}

// NewExperienceEducationHandlers creates new handlers
func NewExperienceEducationHandlers(service *ExperienceEducationService) *ExperienceEducationHandlers {
	return &ExperienceEducationHandlers{
		service: service,
	}
}

// --- Experience Handlers ---

// CreateExperience handles POST /api/v1/account/experiences
func (h *ExperienceEducationHandlers) CreateExperience(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
		return
	}

	id, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID"})
		return
	}

	var req models.CreateExperienceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	exp, err := h.service.CreateExperience(c.Request.Context(), id, &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success":    true,
		"message":    "Experience added successfully",
		"experience": exp,
	})
}

// GetUserExperiences handles GET /api/v1/profile/:username/experiences
func (h *ExperienceEducationHandlers) GetUserExperiences(c *gin.Context) {
	username := c.Param("username")
	if username == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Username is required"})
		return
	}

	// TODO: Fetch user by username first to get userID
	// For now, simplified implementation returns empty array

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"experiences": []models.UserExperience{},
	})
}

// UpdateExperience handles PATCH /api/v1/account/experiences/:id
func (h *ExperienceEducationHandlers) UpdateExperience(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
		return
	}

	id, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID"})
		return
	}

	expID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid experience ID"})
		return
	}

	var req models.UpdateExperienceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	if err := h.service.UpdateExperience(c.Request.Context(), id, expID, &req); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Experience updated successfully",
	})
}

// DeleteExperience handles DELETE /api/v1/account/experiences/:id
func (h *ExperienceEducationHandlers) DeleteExperience(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
		return
	}

	id, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID"})
		return
	}

	expID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid experience ID"})
		return
	}

	if err := h.service.DeleteExperience(c.Request.Context(), id, expID); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Experience deleted successfully",
	})
}

// --- Education Handlers ---

// CreateEducation handles POST /api/v1/account/education
func (h *ExperienceEducationHandlers) CreateEducation(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
		return
	}

	id, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID"})
		return
	}

	var req models.CreateEducationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	edu, err := h.service.CreateEducation(c.Request.Context(), id, &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success":   true,
		"message":   "Education added successfully",
		"education": edu,
	})
}

// GetUserEducation handles GET /api/v1/profile/:username/education
func (h *ExperienceEducationHandlers) GetUserEducation(c *gin.Context) {
	username := c.Param("username")
	if username == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Username is required"})
		return
	}

	// Simplified for initial implementation
	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"education": []models.UserEducation{},
	})
}

// UpdateEducation handles PATCH /api/v1/account/education/:id
func (h *ExperienceEducationHandlers) UpdateEducation(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
		return
	}

	id, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID"})
		return
	}

	eduID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid education ID"})
		return
	}

	var req models.UpdateEducationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	if err := h.service.UpdateEducation(c.Request.Context(), id, eduID, &req); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Education updated successfully",
	})
}

// DeleteEducation handles DELETE /api/v1/account/education/:id
func (h *ExperienceEducationHandlers) DeleteEducation(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
		return
	}

	id, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID"})
		return
	}

	eduID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid education ID"})
		return
	}

	if err := h.service.DeleteEducation(c.Request.Context(), id, eduID); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Education deleted successfully",
	})
}

// GetMyExperiences handles GET /api/v1/account/experiences
func (h *ExperienceEducationHandlers) GetMyExperiences(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
		return
	}

	id, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID"})
		return
	}

	experiences, err := h.service.GetUserExperiences(c.Request.Context(), id, &id)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   err.Error(), // Add detailed error for debugging
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"experiences": experiences,
	})
}

// GetMyEducation handles GET /api/v1/account/education
func (h *ExperienceEducationHandlers) GetMyEducation(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Unauthorized"})
		return
	}

	id, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID"})
		return
	}

	education, err := h.service.GetUserEducation(c.Request.Context(), id)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{
			"success": false,
			"message": appErr.Message,
			"error":   err.Error(), // Add detailed error for debugging
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"education": education,
	})
}

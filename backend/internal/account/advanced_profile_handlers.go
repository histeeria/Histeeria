package account

import (
	"net/http"
	"strconv"

	"histeeria-backend/internal/models"
	"histeeria-backend/pkg/errors"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// --- Certification Handlers ---

// CreateCertification handles POST /api/v1/account/certifications
func (h *AccountHandlers) CreateCertification(c *gin.Context) {
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

	var req models.CreateCertificationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	cert, err := h.advancedProfileSvc.CreateCertification(c.Request.Context(), id, &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"message":       "Certification added successfully",
		"certification": cert,
	})
}

// GetMyCertifications handles GET /api/v1/account/certifications
func (h *AccountHandlers) GetMyCertifications(c *gin.Context) {
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

	certs, err := h.advancedProfileSvc.GetUserCertifications(c.Request.Context(), id)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":        true,
		"certifications": certs,
	})
}

// UpdateCertification handles PATCH /api/v1/account/certifications/:id
func (h *AccountHandlers) UpdateCertification(c *gin.Context) {
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

	certIDStr := c.Param("id")
	certID, err := uuid.Parse(certIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid certification ID"})
		return
	}

	var req models.UpdateCertificationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	if err := h.advancedProfileSvc.UpdateCertification(c.Request.Context(), id, certID, &req); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Certification updated successfully",
	})
}

// DeleteCertification handles DELETE /api/v1/account/certifications/:id
func (h *AccountHandlers) DeleteCertification(c *gin.Context) {
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

	certIDStr := c.Param("id")
	certID, err := uuid.Parse(certIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid certification ID"})
		return
	}

	if err := h.advancedProfileSvc.DeleteCertification(c.Request.Context(), id, certID); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Certification deleted successfully",
	})
}

// --- Skill Handlers ---

// CreateSkill handles POST /api/v1/account/skills
func (h *AccountHandlers) CreateSkill(c *gin.Context) {
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

	var req models.CreateSkillRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	skill, err := h.advancedProfileSvc.CreateSkill(c.Request.Context(), id, &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Skill added successfully",
		"skill":   skill,
	})
}

// GetMySkills handles GET /api/v1/account/skills
func (h *AccountHandlers) GetMySkills(c *gin.Context) {
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

	skills, err := h.advancedProfileSvc.GetUserSkills(c.Request.Context(), id)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"skills":  skills,
	})
}

// UpdateSkill handles PATCH /api/v1/account/skills/:id
func (h *AccountHandlers) UpdateSkill(c *gin.Context) {
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

	skillIDStr := c.Param("id")
	skillID, err := uuid.Parse(skillIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid skill ID"})
		return
	}

	var req models.UpdateSkillRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	if err := h.advancedProfileSvc.UpdateSkill(c.Request.Context(), id, skillID, &req); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Skill updated successfully",
	})
}

// DeleteSkill handles DELETE /api/v1/account/skills/:id
func (h *AccountHandlers) DeleteSkill(c *gin.Context) {
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

	skillIDStr := c.Param("id")
	skillID, err := uuid.Parse(skillIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid skill ID"})
		return
	}

	if err := h.advancedProfileSvc.DeleteSkill(c.Request.Context(), id, skillID); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Skill deleted successfully",
	})
}

// --- Language Handlers ---

// CreateLanguage handles POST /api/v1/account/languages
func (h *AccountHandlers) CreateLanguage(c *gin.Context) {
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

	var req models.CreateLanguageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	lang, err := h.advancedProfileSvc.CreateLanguage(c.Request.Context(), id, &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"message":  "Language added successfully",
		"language": lang,
	})
}

// GetMyLanguages handles GET /api/v1/account/languages
func (h *AccountHandlers) GetMyLanguages(c *gin.Context) {
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

	langs, err := h.advancedProfileSvc.GetUserLanguages(c.Request.Context(), id)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"languages": langs,
	})
}

// UpdateLanguage handles PATCH /api/v1/account/languages/:id
func (h *AccountHandlers) UpdateLanguage(c *gin.Context) {
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

	langIDStr := c.Param("id")
	langID, err := uuid.Parse(langIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid language ID"})
		return
	}

	var req models.UpdateLanguageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	if err := h.advancedProfileSvc.UpdateLanguage(c.Request.Context(), id, langID, &req); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Language updated successfully",
	})
}

// DeleteLanguage handles DELETE /api/v1/account/languages/:id
func (h *AccountHandlers) DeleteLanguage(c *gin.Context) {
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

	langIDStr := c.Param("id")
	langID, err := uuid.Parse(langIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid language ID"})
		return
	}

	if err := h.advancedProfileSvc.DeleteLanguage(c.Request.Context(), id, langID); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Language deleted successfully",
	})
}

// --- Volunteering Handlers ---

// CreateVolunteering handles POST /api/v1/account/volunteering
func (h *AccountHandlers) CreateVolunteering(c *gin.Context) {
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

	var req models.CreateVolunteeringRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	vol, err := h.advancedProfileSvc.CreateVolunteering(c.Request.Context(), id, &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"message":      "Volunteering added successfully",
		"volunteering": vol,
	})
}

// GetMyVolunteering handles GET /api/v1/account/volunteering
func (h *AccountHandlers) GetMyVolunteering(c *gin.Context) {
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

	vols, err := h.advancedProfileSvc.GetUserVolunteering(c.Request.Context(), id)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"volunteering": vols,
	})
}

// UpdateVolunteering handles PATCH /api/v1/account/volunteering/:id
func (h *AccountHandlers) UpdateVolunteering(c *gin.Context) {
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

	volIDStr := c.Param("id")
	volID, err := uuid.Parse(volIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid volunteering ID"})
		return
	}

	var req models.UpdateVolunteeringRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	if err := h.advancedProfileSvc.UpdateVolunteering(c.Request.Context(), id, volID, &req); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Volunteering updated successfully",
	})
}

// DeleteVolunteering handles DELETE /api/v1/account/volunteering/:id
func (h *AccountHandlers) DeleteVolunteering(c *gin.Context) {
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

	volIDStr := c.Param("id")
	volID, err := uuid.Parse(volIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid volunteering ID"})
		return
	}

	if err := h.advancedProfileSvc.DeleteVolunteering(c.Request.Context(), id, volID); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Volunteering deleted successfully",
	})
}

// --- Publication Handlers ---

// CreatePublication handles POST /api/v1/account/publications
func (h *AccountHandlers) CreatePublication(c *gin.Context) {
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

	var req models.CreatePublicationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	pub, err := h.advancedProfileSvc.CreatePublication(c.Request.Context(), id, &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"message":     "Publication added successfully",
		"publication": pub,
	})
}

// GetMyPublications handles GET /api/v1/account/publications
func (h *AccountHandlers) GetMyPublications(c *gin.Context) {
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

	pubs, err := h.advancedProfileSvc.GetUserPublications(c.Request.Context(), id)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"publications": pubs,
	})
}

// UpdatePublication handles PATCH /api/v1/account/publications/:id
func (h *AccountHandlers) UpdatePublication(c *gin.Context) {
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

	pubIDStr := c.Param("id")
	pubID, err := uuid.Parse(pubIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid publication ID"})
		return
	}

	var req models.UpdatePublicationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	if err := h.advancedProfileSvc.UpdatePublication(c.Request.Context(), id, pubID, &req); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Publication updated successfully",
	})
}

// DeletePublication handles DELETE /api/v1/account/publications/:id
func (h *AccountHandlers) DeletePublication(c *gin.Context) {
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

	pubIDStr := c.Param("id")
	pubID, err := uuid.Parse(pubIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid publication ID"})
		return
	}

	if err := h.advancedProfileSvc.DeletePublication(c.Request.Context(), id, pubID); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Publication deleted successfully",
	})
}

// --- Interest Handlers ---

// CreateInterest handles POST /api/v1/account/interests
func (h *AccountHandlers) CreateInterest(c *gin.Context) {
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

	var req models.CreateInterestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	interest, err := h.advancedProfileSvc.CreateInterest(c.Request.Context(), id, &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"message":  "Interest added successfully",
		"interest": interest,
	})
}

// GetMyInterests handles GET /api/v1/account/interests
func (h *AccountHandlers) GetMyInterests(c *gin.Context) {
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

	interests, err := h.advancedProfileSvc.GetUserInterests(c.Request.Context(), id)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"interests": interests,
	})
}

// UpdateInterest handles PATCH /api/v1/account/interests/:id
func (h *AccountHandlers) UpdateInterest(c *gin.Context) {
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

	interestIDStr := c.Param("id")
	interestID, err := uuid.Parse(interestIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid interest ID"})
		return
	}

	var req models.UpdateInterestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	if err := h.advancedProfileSvc.UpdateInterest(c.Request.Context(), id, interestID, &req); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Interest updated successfully",
	})
}

// DeleteInterest handles DELETE /api/v1/account/interests/:id
func (h *AccountHandlers) DeleteInterest(c *gin.Context) {
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

	interestIDStr := c.Param("id")
	interestID, err := uuid.Parse(interestIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid interest ID"})
		return
	}

	if err := h.advancedProfileSvc.DeleteInterest(c.Request.Context(), id, interestID); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Interest deleted successfully",
	})
}

// --- Achievement Handlers ---

// CreateAchievement handles POST /api/v1/account/achievements
func (h *AccountHandlers) CreateAchievement(c *gin.Context) {
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

	var req models.CreateAchievementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	achievement, err := h.advancedProfileSvc.CreateAchievement(c.Request.Context(), id, &req)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"message":     "Achievement added successfully",
		"achievement": achievement,
	})
}

// GetMyAchievements handles GET /api/v1/account/achievements
func (h *AccountHandlers) GetMyAchievements(c *gin.Context) {
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

	achievements, err := h.advancedProfileSvc.GetUserAchievements(c.Request.Context(), id)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"achievements": achievements,
	})
}

// UpdateAchievement handles PATCH /api/v1/account/achievements/:id
func (h *AccountHandlers) UpdateAchievement(c *gin.Context) {
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

	achievementIDStr := c.Param("id")
	achievementID, err := uuid.Parse(achievementIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid achievement ID"})
		return
	}

	var req models.UpdateAchievementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	if err := h.advancedProfileSvc.UpdateAchievement(c.Request.Context(), id, achievementID, &req); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Achievement updated successfully",
	})
}

// DeleteAchievement handles DELETE /api/v1/account/achievements/:id
func (h *AccountHandlers) DeleteAchievement(c *gin.Context) {
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

	achievementIDStr := c.Param("id")
	achievementID, err := uuid.Parse(achievementIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid achievement ID"})
		return
	}

	if err := h.advancedProfileSvc.DeleteAchievement(c.Request.Context(), id, achievementID); err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Achievement deleted successfully",
	})
}

// --- Company Handlers ---

// SearchCompanies handles GET /api/v1/account/companies/search
func (h *AccountHandlers) SearchCompanies(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Query parameter 'q' is required"})
		return
	}

	limit := 10
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	companies, err := h.advancedProfileSvc.SearchCompanies(c.Request.Context(), query, limit)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"companies": companies,
	})
}

// CreateCompany handles POST /api/v1/account/companies
func (h *AccountHandlers) CreateCompany(c *gin.Context) {
	var req models.CreateCompanyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body"})
		return
	}

	company, err := h.advancedProfileSvc.CreateOrGetCompany(c.Request.Context(), req.Name)
	if err != nil {
		appErr := errors.GetAppError(err)
		c.JSON(appErr.Code, gin.H{"success": false, "message": appErr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Company created or retrieved successfully",
		"company": company,
	})
}

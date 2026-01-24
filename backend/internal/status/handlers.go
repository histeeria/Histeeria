package status

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"histeeria-backend/internal/messaging"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handlers manages HTTP handlers for statuses
type Handlers struct {
	service        *Service
	storageService *utils.StorageService
	mediaOptimizer *messaging.MediaOptimizer
}

// NewHandlers creates new status handlers
func NewHandlers(service *Service, storageService *utils.StorageService, mediaOptimizer *messaging.MediaOptimizer) *Handlers {
	return &Handlers{
		service:        service,
		storageService: storageService,
		mediaOptimizer: mediaOptimizer,
	}
}

// sanitizeFilename removes non-ASCII characters, spaces, and special characters from filename
func sanitizeFilename(filename string) string {
	ext := filepath.Ext(filename)
	nameWithoutExt := strings.TrimSuffix(filename, ext)
	nameWithoutExt = strings.ReplaceAll(nameWithoutExt, " ", "_")
	reg := regexp.MustCompile(`[^a-zA-Z0-9_-]+`)
	nameWithoutExt = reg.ReplaceAllString(nameWithoutExt, "")
	if nameWithoutExt == "" {
		nameWithoutExt = "file"
	}
	if len(nameWithoutExt) > 100 {
		nameWithoutExt = nameWithoutExt[:100]
	}
	ext = strings.ToLower(ext)
	ext = regexp.MustCompile(`[^a-zA-Z0-9.]+`).ReplaceAllString(ext, "")
	if ext == "" {
		ext = ".bin"
	}
	return nameWithoutExt + ext
}

// ============================================
// STATUS CRUD ENDPOINTS
// ============================================

// CreateStatus handles POST /api/v1/statuses
func (h *Handlers) CreateStatus(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var req models.CreateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	status, err := h.service.CreateStatus(c.Request.Context(), &req, uid)
	if err != nil {
		if appErr, ok := err.(*models.AppError); ok {
			c.JSON(http.StatusBadRequest, gin.H{"error": appErr.Message, "code": appErr.Code})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, models.StatusResponse{
		Success: true,
		Status:  status,
		Message: "Status created successfully",
	})
}

// GetStatus handles GET /api/v1/statuses/:id
func (h *Handlers) GetStatus(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	// Get viewer ID (optional)
	var viewerID uuid.UUID
	if userID, exists := c.Get("user_id"); exists {
		viewerID, _ = uuid.Parse(userID.(string))
	}

	status, err := h.service.GetStatus(c.Request.Context(), statusID, viewerID)
	if err != nil {
		if err == models.ErrStatusNotFound || err == models.ErrStatusExpired {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.StatusResponse{
		Success: true,
		Status:  status,
	})
}

// GetUserStatuses handles GET /api/v1/statuses/user/:userID
func (h *Handlers) GetUserStatuses(c *gin.Context) {
	userID, err := uuid.Parse(c.Param("userID"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get viewer ID (optional)
	var viewerID uuid.UUID
	if userIDFromContext, exists := c.Get("user_id"); exists {
		viewerID, _ = uuid.Parse(userIDFromContext.(string))
	}

	limit := 50
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	statuses, err := h.service.GetUserStatuses(c.Request.Context(), userID, viewerID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.StatusesResponse{
		Success:  true,
		Statuses: statuses,
		Total:    len(statuses),
		HasMore:  false,
	})
}

// GetStatusesForFeed handles GET /api/v1/statuses/feed
func (h *Handlers) GetStatusesForFeed(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	limit := 100
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	statuses, err := h.service.GetStatusesForFeed(c.Request.Context(), uid, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.StatusesResponse{
		Success:  true,
		Statuses: statuses,
		Total:    len(statuses),
		HasMore:  false,
	})
}

// DeleteStatus handles DELETE /api/v1/statuses/:id
func (h *Handlers) DeleteStatus(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, _ := uuid.Parse(userID.(string))

	if err := h.service.DeleteStatus(c.Request.Context(), statusID, uid); err != nil {
		if err == models.ErrStatusUnauthorized {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Status deleted successfully",
	})
}

// ============================================
// STATUS VIEWS
// ============================================

// ViewStatus handles POST /api/v1/statuses/:id/view
func (h *Handlers) ViewStatus(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, _ := uuid.Parse(userID.(string))

	if err := h.service.ViewStatus(c.Request.Context(), statusID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "View recorded",
	})
}

// GetStatusViews handles GET /api/v1/statuses/:id/views
func (h *Handlers) GetStatusViews(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	limit := 100
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 && parsed <= 200 {
			limit = parsed
		}
	}

	views, err := h.service.GetStatusViews(c.Request.Context(), statusID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"views":   views,
	})
}

// ============================================
// STATUS REACTIONS
// ============================================

// ReactToStatus handles POST /api/v1/statuses/:id/react
func (h *Handlers) ReactToStatus(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, _ := uuid.Parse(userID.(string))

	var req models.ReactToStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.service.ReactToStatus(c.Request.Context(), statusID, uid, req.Emoji); err != nil {
		if err == models.ErrInvalidEmoji || err == models.ErrStatusNotFound || err == models.ErrStatusExpired {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Reaction added",
	})
}

// RemoveStatusReaction handles DELETE /api/v1/statuses/:id/react
func (h *Handlers) RemoveStatusReaction(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, _ := uuid.Parse(userID.(string))

	if err := h.service.RemoveStatusReaction(c.Request.Context(), statusID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Reaction removed",
	})
}

// GetStatusReactions handles GET /api/v1/statuses/:id/reactions
func (h *Handlers) GetStatusReactions(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	limit := 50
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	reactions, err := h.service.GetStatusReactions(c.Request.Context(), statusID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"reactions": reactions,
	})
}

// ============================================
// STATUS COMMENTS
// ============================================

// CreateStatusComment handles POST /api/v1/statuses/:id/comments
func (h *Handlers) CreateStatusComment(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, _ := uuid.Parse(userID.(string))

	var req models.CreateStatusCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	comment, err := h.service.CreateStatusComment(c.Request.Context(), statusID, uid, req.Content)
	if err != nil {
		if err == models.ErrCommentTooLong || err == models.ErrStatusNotFound || err == models.ErrStatusExpired {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"comment": comment,
		"message": "Comment created successfully",
	})
}

// GetStatusComments handles GET /api/v1/statuses/:id/comments
func (h *Handlers) GetStatusComments(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	limit := 50
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	offset := 0
	if offsetStr := c.Query("offset"); offsetStr != "" {
		if parsed, err := strconv.Atoi(offsetStr); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	comments, total, err := h.service.GetStatusComments(c.Request.Context(), statusID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.StatusCommentsResponse{
		Success:  true,
		Comments: comments,
		Total:    total,
		HasMore:  len(comments) == limit && offset+len(comments) < total,
	})
}

// DeleteStatusComment handles DELETE /api/v1/statuses/comments/:id
func (h *Handlers) DeleteStatusComment(c *gin.Context) {
	commentID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid comment ID"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, _ := uuid.Parse(userID.(string))

	if err := h.service.DeleteStatusComment(c.Request.Context(), commentID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Comment deleted successfully",
	})
}

// ============================================
// STATUS MESSAGE REPLIES
// ============================================

// CreateStatusMessageReply handles POST /api/v1/statuses/:id/message-reply
func (h *Handlers) CreateStatusMessageReply(c *gin.Context) {
	statusID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status ID"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	fromUserID, _ := uuid.Parse(userID.(string))

	var req struct {
		ToUserID uuid.UUID `json:"to_user_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	replyID, err := h.service.CreateStatusMessageReply(c.Request.Context(), statusID, fromUserID, req.ToUserID)
	if err != nil {
		if err == models.ErrStatusNotFound || err == models.ErrStatusExpired {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"reply_id": replyID,
		"message":  "Message reply record created",
	})
}

// ============================================
// MEDIA UPLOAD ENDPOINTS
// ============================================

// UploadStatusImage handles POST /api/v1/statuses/upload-image
func (h *Handlers) UploadStatusImage(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get quality parameter
	quality := c.DefaultQuery("quality", "standard")
	var optimizeQuality messaging.OptimizeImageQuality
	if quality == "hd" {
		optimizeQuality = messaging.QualityHD
	} else {
		optimizeQuality = messaging.QualityStandard
	}

	// Get file from form
	file, _, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No image file provided"})
		return
	}
	defer file.Close()

	// Read file
	fileData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	// Validate image
	isValid, _, err := h.mediaOptimizer.ValidateImage(fileData)
	if !isValid || err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid image format"})
		return
	}

	// Optimize image
	optimizedData, newFormat, err := h.mediaOptimizer.OptimizeImageFromBytes(fileData, optimizeQuality)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to optimize image"})
		return
	}

	// Upload to Supabase Storage (use "statuses" bucket or "public" bucket)
	fileName := fmt.Sprintf("statuses/%s/%s_%d.%s", uid.String(), uuid.New().String(), time.Now().Unix(), newFormat)
	uploadedURL, err := h.storageService.UploadFile(c.Request.Context(), "statuses", fileName, bytes.NewReader(optimizedData), "image/"+newFormat)
	if err != nil {
		log.Printf("[UploadStatusImage] Failed to upload: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload image"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"media_url":  uploadedURL,
		"media_type": "image/" + newFormat,
	})
}

// UploadStatusVideo handles POST /api/v1/statuses/upload-video
func (h *Handlers) UploadStatusVideo(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	uid, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get video file from form
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No video file provided"})
		return
	}
	defer file.Close()

	// Validate file size (max 100MB for status videos)
	maxSize := int64(100 * 1024 * 1024)
	fileSize := header.Size
	contentType := header.Header.Get("Content-Type")
	if fileSize > maxSize {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Video too large (max 100MB). Your file: %.1fMB", float64(fileSize)/(1024*1024))})
		return
	}

	// Read video file
	fileData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	// Sanitize filename
	sanitizedFilename := sanitizeFilename(header.Filename)

	// Upload video to Supabase Storage
	videoFileName := fmt.Sprintf("statuses/%s/video_%s_%s", uid.String(), uuid.New().String(), sanitizedFilename)
	uploadedURL, err := h.storageService.UploadFile(c.Request.Context(), "statuses", videoFileName, bytes.NewReader(fileData), contentType)
	if err != nil {
		log.Printf("[UploadStatusVideo] Failed to upload: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to upload video: %v", err)})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"media_url":  uploadedURL,
		"media_type": contentType,
	})
}

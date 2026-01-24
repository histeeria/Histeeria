package messaging

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

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// sanitizeFilename removes non-ASCII characters, spaces, and special characters from filename
// Keeps only alphanumeric, dots, hyphens, and underscores
func sanitizeFilename(filename string) string {
	// Get file extension first
	ext := filepath.Ext(filename)
	nameWithoutExt := strings.TrimSuffix(filename, ext)

	// Remove or replace invalid characters
	// Replace spaces with underscores
	nameWithoutExt = strings.ReplaceAll(nameWithoutExt, " ", "_")

	// Remove non-ASCII and special characters (keep only alphanumeric, dash, underscore)
	reg := regexp.MustCompile(`[^a-zA-Z0-9_-]+`)
	nameWithoutExt = reg.ReplaceAllString(nameWithoutExt, "")

	// If filename becomes empty after sanitization, use a default name
	if nameWithoutExt == "" {
		nameWithoutExt = "file"
	}

	// Limit length to avoid overly long filenames (max 100 chars)
	if len(nameWithoutExt) > 100 {
		nameWithoutExt = nameWithoutExt[:100]
	}

	// Sanitize extension too (remove non-alphanumeric except dot)
	ext = strings.ToLower(ext)
	ext = regexp.MustCompile(`[^a-zA-Z0-9.]+`).ReplaceAllString(ext, "")

	// If no extension, default to .bin
	if ext == "" {
		ext = ".bin"
	}

	return nameWithoutExt + ext
}

// MessageHandlers handles HTTP requests for messaging
type MessageHandlers struct {
	service        *MessagingService
	deliverySvc    *DeliveryService // WhatsApp-style delivery service
	storageService *utils.StorageService
	mediaOptimizer *MediaOptimizer
}

// NewMessageHandlers creates new message handlers
func NewMessageHandlers(
	service *MessagingService,
	deliverySvc *DeliveryService,
	storageService *utils.StorageService,
	mediaOptimizer *MediaOptimizer,
) *MessageHandlers {
	return &MessageHandlers{
		service:        service,
		deliverySvc:    deliverySvc,
		storageService: storageService,
		mediaOptimizer: mediaOptimizer,
	}
}

// ============================================
// CONVERSATIONS
// ============================================

// GetConversations handles GET /api/v1/conversations
func (h *MessageHandlers) GetConversations(c *gin.Context) {
	// Get current user ID from JWT
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

	// Parse pagination
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	// Get conversations
	conversations, err := h.service.GetConversations(c.Request.Context(), uid, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"conversations": conversations,
		"total":         len(conversations),
		"limit":         limit,
		"offset":        offset,
		"has_more":      len(conversations) == limit,
	})
}

// GetConversation handles GET /api/v1/conversations/:id
func (h *MessageHandlers) GetConversation(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	conversation, err := h.service.GetConversation(c.Request.Context(), conversationID, uid)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"conversation": conversation,
	})
}

// StartConversation handles POST /api/v1/conversations/:userId
func (h *MessageHandlers) StartConversation(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	otherUserID, err := uuid.Parse(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	if uid == otherUserID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot start conversation with yourself"})
		return
	}

	conversation, err := h.service.StartConversation(c.Request.Context(), uid, otherUserID)
	if err != nil {
		log.Printf("[MessageHandlers] Failed to start conversation: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"conversation": conversation,
	})
}

// GetUnreadCount handles GET /api/v1/conversations/unread-count
func (h *MessageHandlers) GetUnreadCount(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	count, err := h.service.GetUnreadCount(c.Request.Context(), uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"total":   count,
	})
}

// ============================================
// MESSAGES
// ============================================

// GetMessages handles GET /api/v1/conversations/:id/messages
func (h *MessageHandlers) GetMessages(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	// Parse pagination
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	messages, err := h.service.GetMessages(c.Request.Context(), conversationID, uid, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"messages": messages,
		"total":    len(messages),
		"limit":    limit,
		"offset":   offset,
		"has_more": len(messages) == limit,
	})
}

// SendMessage handles POST /api/v1/conversations/:id/messages
func (h *MessageHandlers) SendMessage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	// Read request body for debugging (before parsing)
	bodyBytes, _ := io.ReadAll(c.Request.Body)
	c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
	log.Printf("[MessageHandlers] Raw request body: %s", string(bodyBytes))

	var req models.MessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("[MessageHandlers] JSON parsing error: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Debug logging for E2EE
	hasEncrypted := req.EncryptedContent != nil && *req.EncryptedContent != ""
	hasIV := req.IV != nil && *req.IV != ""
	log.Printf("[MessageHandlers] Parsed - Content: '%s' (len: %d), EncryptedContent: %v, IV: %v", 
		req.Content, len(req.Content), hasEncrypted, hasIV)
	if req.EncryptedContent != nil {
		log.Printf("[MessageHandlers] EncryptedContent value: '%s' (len: %d)", *req.EncryptedContent, len(*req.EncryptedContent))
	}
	if req.IV != nil {
		log.Printf("[MessageHandlers] IV value: '%s' (len: %d)", *req.IV, len(*req.IV))
	}

	// Set default message type if not provided
	if req.MessageType == "" {
		req.MessageType = models.MessageTypeText
	}

	message, err := h.service.SendMessage(c.Request.Context(), conversationID, uid, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": message,
		"temp_id": req.TempID, // Return temp_id for optimistic UI mapping
	})
}

// MarkAsRead handles PATCH /api/v1/conversations/:id/read
func (h *MessageHandlers) MarkAsRead(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	if err := h.service.MarkAsRead(c.Request.Context(), conversationID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Messages marked as read",
	})
}

// DeleteMessage handles DELETE /api/v1/messages/:id
func (h *MessageHandlers) DeleteMessage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	if err := h.service.DeleteMessage(c.Request.Context(), messageID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Message deleted",
	})
}

// SearchMessages handles GET /api/v1/messages/search
func (h *MessageHandlers) SearchMessages(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Search query is required"})
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	messages, err := h.service.SearchMessages(c.Request.Context(), uid, query, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"messages": messages,
		"query":    query,
	})
}

// ============================================
// ATTACHMENTS
// ============================================

// UploadImage handles POST /api/v1/messages/upload-image
func (h *MessageHandlers) UploadImage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	// Get quality parameter
	quality := c.DefaultQuery("quality", "standard")
	var optimizeQuality OptimizeImageQuality
	if quality == "hd" {
		optimizeQuality = QualityHD
	} else {
		optimizeQuality = QualityStandard
	}

	// Get file from form
	file, header, err := c.Request.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No image file provided"})
		return
	}
	defer file.Close()

	// Validate file size
	if err := ValidateFileSize(header.Size, "image_"+quality); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

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

	// Upload to Supabase Storage (private bucket)
	fileName := fmt.Sprintf("messages/%s/%s_%d.%s", uid.String(), uuid.New().String(), time.Now().Unix(), newFormat)
	filePath, err := h.storageService.UploadFile(c.Request.Context(), "chat-attachments", fileName, bytes.NewReader(optimizedData), "image/"+newFormat)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload image"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     filePath, // Store file path, not public URL
		"name":    header.Filename,
		"size":    len(optimizedData),
		"type":    "image/" + newFormat,
		"format":  newFormat,
	})
}

// UploadAudio handles POST /api/v1/messages/upload-audio
func (h *MessageHandlers) UploadAudio(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	log.Printf("[UploadAudio] Request from user: %s", uid.String())

	// Get file from form
	file, header, err := c.Request.FormFile("audio")
	if err != nil {
		log.Printf("[UploadAudio] Failed to get file from form: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "No audio file provided"})
		return
	}
	defer file.Close()

	log.Printf("[UploadAudio] File received: %s, Size: %d, Type: %s", header.Filename, header.Size, header.Header.Get("Content-Type"))

	// Validate file size
	if err := ValidateFileSize(header.Size, "audio"); err != nil {
		log.Printf("[UploadAudio] File size validation failed: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Read file
	fileData, err := io.ReadAll(file)
	if err != nil {
		log.Printf("[UploadAudio] Failed to read file: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	log.Printf("[UploadAudio] File data read successfully: %d bytes", len(fileData))

	// Validate audio
	isValid, err := h.mediaOptimizer.ValidateAudio(fileData, header.Header.Get("Content-Type"))
	if !isValid {
		log.Printf("[UploadAudio] Audio validation failed: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid audio format: " + err.Error()})
		return
	}

	log.Printf("[UploadAudio] Audio validation passed")

	// Determine file extension from content type
	contentType := header.Header.Get("Content-Type")
	ext := ".webm" // default
	if contentType == "audio/m4a" || contentType == "audio/aac" || contentType == "audio/x-m4a" || contentType == "audio/mp4" {
		ext = ".m4a"
	} else if contentType == "audio/mp3" || contentType == "audio/mpeg" {
		ext = ".mp3"
	} else if contentType == "audio/ogg" {
		ext = ".ogg"
	}

	// Upload to Supabase Storage (private bucket)
	fileName := fmt.Sprintf("messages/%s/audio_%s_%d%s", uid.String(), uuid.New().String(), time.Now().Unix(), ext)
	log.Printf("[UploadAudio] Uploading to Supabase: bucket=chat-attachments, fileName=%s, contentType=%s", fileName, contentType)

	// Upload returns file path (bucket/path) for private bucket
	filePath, err := h.storageService.UploadFile(c.Request.Context(), "chat-attachments", fileName, bytes.NewReader(fileData), contentType)
	if err != nil {
		log.Printf("[UploadAudio] Supabase upload failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to upload audio: %v", err)})
		return
	}

	log.Printf("[UploadAudio] Upload successful: %s", filePath)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     filePath, // Store file path, not public URL
		"name":    header.Filename,
		"size":    len(fileData),
		"type":    contentType,
	})
}

// UploadFile handles POST /api/v1/messages/upload-file
func (h *MessageHandlers) UploadFile(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	log.Printf("[UploadFile] Request from user: %s", uid.String())

	// Get file from form
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		log.Printf("[UploadFile] Failed to get file from form: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file provided"})
		return
	}
	defer file.Close()

	log.Printf("[UploadFile] File received: %s, Size: %d, Type: %s", header.Filename, header.Size, header.Header.Get("Content-Type"))

	// Validate file size
	if err := ValidateFileSize(header.Size, "file"); err != nil {
		log.Printf("[UploadFile] File size validation failed: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Read file
	fileData, err := io.ReadAll(file)
	if err != nil {
		log.Printf("[UploadFile] Failed to read file: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	log.Printf("[UploadFile] File data read successfully: %d bytes", len(fileData))

	// Sanitize filename - remove non-ASCII characters and spaces
	sanitizedFilename := sanitizeFilename(header.Filename)

	// Upload to Supabase Storage
	fileName := fmt.Sprintf("messages/%s/file_%s_%s", uid.String(), uuid.New().String(), sanitizedFilename)
	log.Printf("[UploadFile] Original filename: %s, Sanitized: %s", header.Filename, sanitizedFilename)
	log.Printf("[UploadFile] Uploading to Supabase: bucket=chat-attachments, fileName=%s", fileName)

	filePath, err := h.storageService.UploadFile(c.Request.Context(), "chat-attachments", fileName, bytes.NewReader(fileData), header.Header.Get("Content-Type"))
	if err != nil {
		log.Printf("[UploadFile] Supabase upload failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to upload file: %v", err)})
		return
	}

	log.Printf("[UploadFile] Upload successful: %s", filePath)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     filePath, // Store file path, not public URL
		"name":    header.Filename, // Return original filename for display
		"size":    header.Size,
		"type":    header.Header.Get("Content-Type"),
	})
}

// UploadVideo handles POST /api/v1/messages/upload-video
func (h *MessageHandlers) UploadVideo(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	log.Printf("[UploadVideo] Request from user: %s", uid.String())

	// Get video file from form
	file, header, err := c.Request.FormFile("video")
	if err != nil {
		log.Printf("[UploadVideo] Failed to get file from form: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "No video file provided"})
		return
	}
	defer file.Close()

	log.Printf("[UploadVideo] File received: %s, Size: %d, Type: %s", header.Filename, header.Size, header.Header.Get("Content-Type"))

	// Validate file size (max 100MB for videos)
	maxSize := int64(100 * 1024 * 1024)
	if header.Size > maxSize {
		log.Printf("[UploadVideo] File too large: %d bytes (max %d)", header.Size, maxSize)
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Video too large (max 100MB). Your file: %.1fMB", float64(header.Size)/(1024*1024))})
		return
	}

	// Read video file
	fileData, err := io.ReadAll(file)
	if err != nil {
		log.Printf("[UploadVideo] Failed to read file: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	log.Printf("[UploadVideo] File data read successfully: %d bytes", len(fileData))

	// Sanitize filename
	sanitizedFilename := sanitizeFilename(header.Filename)

	// Upload video to Supabase Storage
	videoFileName := fmt.Sprintf("messages/%s/video_%s_%s", uid.String(), uuid.New().String(), sanitizedFilename)
	log.Printf("[UploadVideo] Uploading to Supabase: bucket=chat-attachments, fileName=%s", videoFileName)

	filePath, err := h.storageService.UploadFile(c.Request.Context(), "chat-attachments", videoFileName, bytes.NewReader(fileData), header.Header.Get("Content-Type"))
	if err != nil {
		log.Printf("[UploadVideo] Supabase upload failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to upload video: %v", err)})
		return
	}

	log.Printf("[UploadVideo] Video upload successful: %s", filePath)

	// Get optional thumbnail from form (base64 or file)
	var thumbnailPath string
	thumbnailFile, thumbnailHeader, err := c.Request.FormFile("thumbnail")
	if err == nil {
		defer thumbnailFile.Close()

		// Read thumbnail
		thumbnailData, err := io.ReadAll(thumbnailFile)
		if err == nil {
			// Upload thumbnail (private bucket)
			thumbnailFileName := fmt.Sprintf("messages/%s/thumb_%s.jpg", uid.String(), uuid.New().String())
			thumbnailPath, _ = h.storageService.UploadFile(c.Request.Context(), "chat-attachments", thumbnailFileName, bytes.NewReader(thumbnailData), thumbnailHeader.Header.Get("Content-Type"))
			log.Printf("[UploadVideo] Thumbnail uploaded: %s", thumbnailPath)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"url":           filePath, // Store file path, not public URL
		"thumbnail_url": thumbnailPath, // Store thumbnail path, not public URL
		"name":          header.Filename,
		"size":          header.Size,
		"type":          header.Header.Get("Content-Type"),
	})
}

// ============================================
// REACTIONS
// ============================================

// AddReaction handles POST /api/v1/messages/:id/reactions
func (h *MessageHandlers) AddReaction(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	var req models.ReactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	reaction, err := h.service.AddReaction(c.Request.Context(), messageID, uid, req.Emoji)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// If reaction is nil, it was toggled off (removed)
	if reaction == nil {
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"removed": true,
			"message": "Reaction removed",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success":  true,
		"reaction": reaction,
	})
}

// RemoveReaction handles DELETE /api/v1/messages/:id/reactions
func (h *MessageHandlers) RemoveReaction(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	if err := h.service.RemoveReaction(c.Request.Context(), messageID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Reaction removed",
	})
}

// ============================================
// STARRED MESSAGES
// ============================================

// StarMessage handles POST /api/v1/messages/:id/star
func (h *MessageHandlers) StarMessage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	if err := h.service.StarMessage(c.Request.Context(), messageID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Message starred",
	})
}

// UnstarMessage handles DELETE /api/v1/messages/:id/star
func (h *MessageHandlers) UnstarMessage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	if err := h.service.UnstarMessage(c.Request.Context(), messageID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Message unstarred",
	})
}

// GetStarredMessages handles GET /api/v1/messages/starred
func (h *MessageHandlers) GetStarredMessages(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	messages, err := h.service.GetStarredMessages(c.Request.Context(), uid, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"messages": messages,
	})
}

// ============================================
// TYPING INDICATORS
// ============================================

// StartTyping handles POST /api/v1/conversations/:id/typing/start
func (h *MessageHandlers) StartTyping(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	// Parse request body for is_recording flag
	var req struct {
		IsRecording bool `json:"is_recording"`
	}
	c.ShouldBindJSON(&req)

	if err := h.service.StartTyping(c.Request.Context(), conversationID, uid, req.IsRecording); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// StopTyping handles POST /api/v1/conversations/:id/typing/stop
func (h *MessageHandlers) StopTyping(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	if err := h.service.StopTyping(c.Request.Context(), conversationID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// ============================================
// PRESENCE
// ============================================

// GetUserPresence handles GET /api/v1/users/:id/presence
func (h *MessageHandlers) GetUserPresence(c *gin.Context) {
	targetUserID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	isOnline, lastSeen, err := h.service.GetUserPresence(c.Request.Context(), targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"user_id":   targetUserID,
		"is_online": isOnline,
		"last_seen": lastSeen,
	})
}

// GetBulkPresence handles GET /api/v1/users/presence/bulk
func (h *MessageHandlers) GetBulkPresence(c *gin.Context) {
	// Get user IDs from query parameter (comma-separated)
	userIDsStr := c.Query("user_ids")
	if userIDsStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_ids parameter required"})
		return
	}

	// Parse user IDs
	userIDStrings := splitByComma(userIDsStr)
	userIDs := make([]uuid.UUID, 0, len(userIDStrings))

	for _, idStr := range userIDStrings {
		id, err := uuid.Parse(idStr)
		if err != nil {
			continue
		}
		userIDs = append(userIDs, id)
	}

	if len(userIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No valid user IDs provided"})
		return
	}

	presence, err := h.service.GetMultiplePresence(c.Request.Context(), userIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"presence": presence,
	})
}

// ============================================
// HELPERS
// ============================================

func splitByComma(s string) []string {
	result := []string{}
	current := ""

	for _, char := range s {
		if char == ',' {
			if current != "" {
				result = append(result, current)
				current = ""
			}
		} else {
			current += string(char)
		}
	}

	if current != "" {
		result = append(result, current)
	}

	return result
}

// ============================================
// PIN MESSAGE HANDLERS
// ============================================

// PinMessage handles POST /api/v1/messages/:id/pin
func (h *MessageHandlers) PinMessage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	if err := h.service.PinMessage(c.Request.Context(), messageID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Message pinned"})
}

// UnpinMessage handles DELETE /api/v1/messages/:id/pin
func (h *MessageHandlers) UnpinMessage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	if err := h.service.UnpinMessage(c.Request.Context(), messageID, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Message unpinned"})
}

// GetPinnedMessages handles GET /api/v1/conversations/:id/pinned
func (h *MessageHandlers) GetPinnedMessages(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	messages, err := h.service.GetPinnedMessages(c.Request.Context(), conversationID, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"messages": messages,
	})
}

// ============================================
// EDIT MESSAGE HANDLERS
// ============================================

// EditMessage handles PATCH /api/v1/messages/:id
func (h *MessageHandlers) EditMessage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	var req models.EditMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.service.EditMessage(c.Request.Context(), messageID, uid, req.Content); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Message edited"})
}

// GetMessageEditHistory handles GET /api/v1/messages/:id/edit-history
func (h *MessageHandlers) GetMessageEditHistory(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	history, err := h.service.GetMessageEditHistory(c.Request.Context(), messageID, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"history": history,
	})
}

// ============================================
// FORWARD MESSAGE HANDLERS
// ============================================

// ForwardMessage handles POST /api/v1/messages/:id/forward
func (h *MessageHandlers) ForwardMessage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	var req models.ForwardMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	forwardedMsg, err := h.service.ForwardMessage(c.Request.Context(), messageID, req.ToConversationID, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": forwardedMsg,
	})
}

// ============================================
// SEARCH MESSAGES HANDLER
// ============================================

// SearchConversationMessages handles GET /api/v1/conversations/:id/search
func (h *MessageHandlers) SearchConversationMessages(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := uuid.Parse(userID.(string))

	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Search query required"})
		return
	}

	limit := 50
	offset := 0

	if limitStr := c.Query("limit"); limitStr != "" {
		fmt.Sscanf(limitStr, "%d", &limit)
	}

	if offsetStr := c.Query("offset"); offsetStr != "" {
		fmt.Sscanf(offsetStr, "%d", &offset)
	}

	messages, err := h.service.SearchConversationMessages(c.Request.Context(), conversationID, uid, query, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"messages": messages,
		"total":    len(messages),
	})
}

// ============================================
// DELIVERY TRACKING ENDPOINTS (WhatsApp-Style)
// ============================================

// GetPendingMessages handles GET /api/v1/messages/pending
// Returns all pending messages for the current user (for sync on app open)
func (h *MessageHandlers) GetPendingMessages(c *gin.Context) {
	if h.deliverySvc == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Delivery service not available"})
		return
	}

	// Get current user ID from JWT
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

	// Get pending messages
	response, err := h.deliverySvc.GetPendingMessages(c.Request.Context(), uid)
	if err != nil {
		log.Printf("[Delivery] Failed to get pending messages: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get pending messages"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"messages": response.Messages,
		"total":    response.TotalPending,
		"synced_at": response.SyncedAt,
	})
}

// MarkMessageDelivered handles POST /api/v1/messages/:id/mark-delivered
// Marks a message as delivered (WhatsApp-style double tick ✓✓)
func (h *MessageHandlers) MarkMessageDelivered(c *gin.Context) {
	if h.deliverySvc == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Delivery service not available"})
		return
	}

	// Get current user ID from JWT
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

	// Get message ID from URL
	messageIDStr := c.Param("id")
	messageID, err := uuid.Parse(messageIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	// Mark message as delivered
	status, err := h.deliverySvc.MarkMessageDelivered(c.Request.Context(), messageID, uid)
	if err != nil {
		log.Printf("[Delivery] Failed to mark message delivered: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark message delivered"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"status":  status,
	})
}

// MarkConversationDelivered handles POST /api/v1/conversations/:id/mark-delivered
// Marks all messages in a conversation as delivered (batch operation)
func (h *MessageHandlers) MarkConversationDelivered(c *gin.Context) {
	if h.deliverySvc == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Delivery service not available"})
		return
	}

	// Get current user ID from JWT
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

	// Get conversation ID from URL
	conversationIDStr := c.Param("id")
	conversationID, err := uuid.Parse(conversationIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	// Mark conversation as delivered
	count, err := h.deliverySvc.MarkMessagesDelivered(c.Request.Context(), conversationID, uid)
	if err != nil {
		log.Printf("[Delivery] Failed to mark conversation delivered: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark conversation delivered"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"count":   count,
		"message": fmt.Sprintf("Marked %d messages as delivered", count),
	})
}

// MarkMessageRead handles POST /api/v1/messages/:id/read
// Marks a message as read (WhatsApp-style blue ticks)
func (h *MessageHandlers) MarkMessageReadEndpoint(c *gin.Context) {
	if h.deliverySvc == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Delivery service not available"})
		return
	}

	// Get current user ID from JWT
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

	// Get message ID from URL
	messageIDStr := c.Param("id")
	messageID, err := uuid.Parse(messageIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	// Mark message as read
	err = h.deliverySvc.MarkMessageRead(c.Request.Context(), messageID, uid)
	if err != nil {
		log.Printf("[Delivery] Failed to mark message read: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark message read"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Message marked as read",
	})
}

// ============================================
// E2EE KEY EXCHANGE
// ============================================

// ExchangePublicKey handles POST /api/v1/conversations/:id/keys
// Stores the current user's public key for the conversation
func (h *MessageHandlers) ExchangePublicKey(c *gin.Context) {
	// Get current user ID from JWT
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

	// Get conversation ID
	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	// Verify user is a participant in the conversation
	_, err = h.service.GetConversation(c.Request.Context(), conversationID, uid)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "User is not a participant in this conversation"})
		return
	}

	// Parse request body
	var req struct {
		PublicKey string `json:"public_key" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: public_key is required"})
		return
	}

	// Store public key using the service
	err = h.service.StorePublicKey(c.Request.Context(), conversationID, uid, req.PublicKey)
	if err != nil {
		log.Printf("[E2EE] Failed to store public key: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store public key"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Public key stored successfully",
	})
}

// GetConversationPublicKey handles GET /api/v1/conversations/:id/keys
// Retrieves the other user's public key for the conversation
func (h *MessageHandlers) GetConversationPublicKey(c *gin.Context) {
	// Get current user ID from JWT
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

	// Get conversation ID
	conversationID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid conversation ID"})
		return
	}

	// Get conversation to find the other user
	conversation, err := h.service.GetConversation(c.Request.Context(), conversationID, uid)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "User is not a participant in this conversation"})
		return
	}

	// Determine the other user's ID
	var otherUserID uuid.UUID
	if conversation.Participant1ID == uid {
		otherUserID = conversation.Participant2ID
	} else {
		otherUserID = conversation.Participant1ID
	}

	// Get the other user's public key
	publicKey, err := h.service.GetPublicKey(c.Request.Context(), conversationID, otherUserID)
	if err != nil {
		log.Printf("[E2EE] Failed to get public key: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Public key not found for this conversation"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"public_key": publicKey,
		"user_id":    otherUserID.String(),
	})
}

// GetFileSignedURL handles GET /api/v1/files/:messageId/download
// Generates a signed URL for a file attachment with authorization checks
func (h *MessageHandlers) GetFileSignedURL(c *gin.Context) {
	// Get current user ID from JWT
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

	// Get message ID from URL
	messageID, err := uuid.Parse(c.Param("messageId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	// Get message to verify user has access and get file path
	message, err := h.service.GetMessageByID(c.Request.Context(), messageID, uid)
	if err != nil {
		log.Printf("[GetFileSignedURL] Failed to get message: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Message not found"})
		return
	}

	// Verify user is a participant in the conversation
	_, err = h.service.GetConversation(c.Request.Context(), message.ConversationID, uid)
	if err != nil {
		log.Printf("[GetFileSignedURL] User %s is not a participant in conversation %s", uid, message.ConversationID)
		c.JSON(http.StatusForbidden, gin.H{"error": "Access denied"})
		return
	}

	// Check if message has an attachment
	if message.AttachmentURL == nil || *message.AttachmentURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Message has no attachment"})
		return
	}

	// Extract file path from attachment URL
	// Old format: https://xxx.supabase.co/storage/v1/object/public/bucket/path
	// New format: bucket/path (stored directly)
	filePath := *message.AttachmentURL

	// Handle legacy public URLs - extract path
	if strings.Contains(filePath, "/storage/v1/object/public/") {
		// Extract bucket/path from public URL
		parts := strings.Split(filePath, "/storage/v1/object/public/")
		if len(parts) < 2 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file URL format"})
			return
		}
		filePath = parts[1]
	}

	// Get expiration from query parameter (default 1 hour)
	expirationSeconds := 3600
	if expStr := c.Query("expires_in"); expStr != "" {
		if exp, err := strconv.Atoi(expStr); err == nil && exp > 0 && exp <= 86400 {
			expirationSeconds = exp // Max 24 hours
		}
	}

	// Generate signed URL
	signedURL, err := h.storageService.GenerateSignedURL(c.Request.Context(), filePath, expirationSeconds)
	if err != nil {
		log.Printf("[GetFileSignedURL] Failed to generate signed URL: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate download URL"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"signed_url": signedURL,
		"expires_in": expirationSeconds,
	})
}

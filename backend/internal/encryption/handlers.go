package encryption

import (
	"encoding/base64"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handlers provides HTTP handlers for E2EE key management
type Handlers struct {
	keyService *KeyService
}

// NewHandlers creates new E2EE handlers
func NewHandlers(keyService *KeyService) *Handlers {
	return &Handlers{
		keyService: keyService,
	}
}

// SetupRoutes sets up E2EE routes
func (h *Handlers) SetupRoutes(rg *gin.RouterGroup) {
	keys := rg.Group("/keys")
	{
		// Identity keys
		keys.POST("/identity", h.RegisterIdentityKey)
		keys.GET("/identity/:userId", h.GetIdentityKey)

		// Pre-keys
		keys.POST("/prekeys", h.UploadPreKeys)
		keys.GET("/prekeys/count", h.GetPreKeyCount)

		// Signed pre-keys
		keys.POST("/signed-prekey", h.UploadSignedPreKey)
		keys.GET("/signed-prekey/:userId", h.GetSignedPreKey)

		// Key bundles (for session establishment)
		keys.GET("/bundle/:userId", h.GetKeyBundle)

		// Sessions
		keys.POST("/sessions", h.CreateSession)
		keys.GET("/sessions/:conversationId", h.GetSession)
		keys.PATCH("/sessions/:sessionId/state", h.UpdateSessionState)

		// Verification
		keys.GET("/fingerprint/:userId", h.GetKeyFingerprint)
	}
}

// ============================================
// IDENTITY KEY HANDLERS
// ============================================

// RegisterIdentityKeyRequest represents the request to register an identity key
type RegisterIdentityKeyRequest struct {
	PublicKey string `json:"public_key" binding:"required"` // Base64-encoded
}

// RegisterIdentityKey registers a user's identity key
// POST /api/v1/keys/identity
func (h *Handlers) RegisterIdentityKey(c *gin.Context) {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req RegisterIdentityKeyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	// Decode base64 public key
	publicKey, err := base64.StdEncoding.DecodeString(req.PublicKey)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid public key encoding"})
		return
	}

	if err := h.keyService.RegisterIdentityKey(c.Request.Context(), userID, publicKey); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "identity key registered"})
}

// GetIdentityKey retrieves a user's identity key
// GET /api/v1/keys/identity/:userId
func (h *Handlers) GetIdentityKey(c *gin.Context) {
	userIDStr := c.Param("userId")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	key, err := h.keyService.GetIdentityKey(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if key == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "identity key not found"})
		return
	}

	c.JSON(http.StatusOK, key)
}

// ============================================
// PRE-KEY HANDLERS
// ============================================

// UploadPreKeysRequest represents the request to upload pre-keys
type UploadPreKeysRequest struct {
	PreKeys []PreKeyUpload `json:"pre_keys" binding:"required,min=1,max=100"`
}

// UploadPreKeys uploads a batch of pre-keys
// POST /api/v1/keys/prekeys
func (h *Handlers) UploadPreKeys(c *gin.Context) {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req UploadPreKeysRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	if err := h.keyService.UploadPreKeys(c.Request.Context(), userID, req.PreKeys); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "pre-keys uploaded",
		"count":   len(req.PreKeys),
	})
}

// GetPreKeyCount returns the number of available pre-keys
// GET /api/v1/keys/prekeys/count
func (h *Handlers) GetPreKeyCount(c *gin.Context) {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	count, err := h.keyService.GetAvailablePreKeyCount(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"count":     count,
		"low_count": count < 20, // Suggest client to upload more
	})
}

// ============================================
// SIGNED PRE-KEY HANDLERS
// ============================================

// UploadSignedPreKeyRequest represents the request to upload a signed pre-key
type UploadSignedPreKeyRequest struct {
	KeyID     int    `json:"key_id" binding:"required"`
	PublicKey string `json:"public_key" binding:"required"` // Base64-encoded
	Signature string `json:"signature" binding:"required"`  // Base64-encoded
}

// UploadSignedPreKey uploads a signed pre-key
// POST /api/v1/keys/signed-prekey
func (h *Handlers) UploadSignedPreKey(c *gin.Context) {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req UploadSignedPreKeyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	// Decode base64 values
	publicKey, err := base64.StdEncoding.DecodeString(req.PublicKey)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid public key encoding"})
		return
	}

	signature, err := base64.StdEncoding.DecodeString(req.Signature)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid signature encoding"})
		return
	}

	if err := h.keyService.UploadSignedPreKey(c.Request.Context(), userID, req.KeyID, publicKey, signature); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "signed pre-key uploaded"})
}

// GetSignedPreKey retrieves a user's signed pre-key
// GET /api/v1/keys/signed-prekey/:userId
func (h *Handlers) GetSignedPreKey(c *gin.Context) {
	userIDStr := c.Param("userId")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	key, err := h.keyService.GetSignedPreKey(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if key == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "signed pre-key not found"})
		return
	}

	c.JSON(http.StatusOK, key)
}

// ============================================
// KEY BUNDLE HANDLER
// ============================================

// GetKeyBundle retrieves a user's key bundle for session establishment
// GET /api/v1/keys/bundle/:userId
func (h *Handlers) GetKeyBundle(c *gin.Context) {
	userIDStr := c.Param("userId")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	bundle, err := h.keyService.GetKeyBundle(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, bundle)
}

// ============================================
// SESSION HANDLERS
// ============================================

// CreateSessionRequest represents the request to create a session
type CreateSessionRequest struct {
	ConversationID string `json:"conversation_id" binding:"required"`
	ResponderID    string `json:"responder_id" binding:"required"`
}

// CreateSession creates a new E2EE session
// POST /api/v1/keys/sessions
func (h *Handlers) CreateSession(c *gin.Context) {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req CreateSessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	conversationID, err := uuid.Parse(req.ConversationID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}

	responderID, err := uuid.Parse(req.ResponderID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid responder ID"})
		return
	}

	session, err := h.keyService.CreateSession(c.Request.Context(), conversationID, userID, responderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, session)
}

// GetSession retrieves a session by conversation ID
// GET /api/v1/keys/sessions/:conversationId
func (h *Handlers) GetSession(c *gin.Context) {
	conversationIDStr := c.Param("conversationId")
	conversationID, err := uuid.Parse(conversationIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}

	session, err := h.keyService.GetSession(c.Request.Context(), conversationID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if session == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
		return
	}

	c.JSON(http.StatusOK, session)
}

// UpdateSessionStateRequest represents the request to update session state
type UpdateSessionStateRequest struct {
	RatchetState  string `json:"ratchet_state" binding:"required"` // Base64-encoded
	MessageNumber int    `json:"message_number" binding:"required"`
}

// UpdateSessionState updates the ratchet state of a session
// PATCH /api/v1/keys/sessions/:sessionId/state
func (h *Handlers) UpdateSessionState(c *gin.Context) {
	sessionIDStr := c.Param("sessionId")
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session ID"})
		return
	}

	var req UpdateSessionStateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	if err := h.keyService.UpdateSessionState(c.Request.Context(), sessionID, req.RatchetState, req.MessageNumber); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "session state updated"})
}

// ============================================
// VERIFICATION HANDLER
// ============================================

// GetKeyFingerprint retrieves a user's key fingerprint for verification
// GET /api/v1/keys/fingerprint/:userId
func (h *Handlers) GetKeyFingerprint(c *gin.Context) {
	userIDStr := c.Param("userId")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	fingerprint, err := h.keyService.GetKeyFingerprint(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"user_id":     userID,
		"fingerprint": fingerprint,
	})
}

// ============================================
// HELPER FUNCTIONS
// ============================================

// getUserIDFromContext extracts user ID from Gin context
func getUserIDFromContext(c *gin.Context) (uuid.UUID, error) {
	userIDInterface, exists := c.Get("user_id")
	if !exists {
		return uuid.Nil, http.ErrNoCookie
	}

	userIDStr, ok := userIDInterface.(string)
	if !ok {
		return uuid.Nil, http.ErrNoCookie
	}

	return uuid.Parse(userIDStr)
}

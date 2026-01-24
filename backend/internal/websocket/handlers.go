package websocket

import (
	"log"
	"net/http"

	"histeeria-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// In production, verify the origin
		// For now, allow all origins (adjust for your needs)
		return true
	},
}

// Handlers manages WebSocket HTTP handlers
type Handlers struct {
	manager *Manager
	jwtSvc  *utils.JWTService
}

// NewHandlers creates new WebSocket handlers
func NewHandlers(manager *Manager, jwtSvc *utils.JWTService) *Handlers {
	return &Handlers{
		manager: manager,
		jwtSvc:  jwtSvc,
	}
}

// HandleWebSocket upgrades HTTP connection to WebSocket
func (h *Handlers) HandleWebSocket(c *gin.Context) {
	log.Printf("[WebSocket] WebSocket upgrade request received from %s", c.ClientIP())
	log.Printf("[WebSocket] Request headers: Upgrade=%s, Connection=%s", c.GetHeader("Upgrade"), c.GetHeader("Connection"))

	// Extract JWT token from query parameter or header
	token := c.Query("token")
	if token == "" {
		token = c.GetHeader("Authorization")
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}
	}

	if token == "" {
		log.Println("[WebSocket] ❌ No token provided")
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "No authentication token provided",
		})
		return
	}

	log.Printf("[WebSocket] Token provided (length: %d)", len(token))

	// Validate JWT token
	claims, err := h.jwtSvc.ValidateToken(token)
	if err != nil {
		log.Printf("[WebSocket] ❌ Invalid token: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Invalid authentication token",
		})
		return
	}

	log.Printf("[WebSocket] ✅ Token validated for user: %s", claims.UserID)

	// Extract user ID from claims
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		log.Printf("[WebSocket] ❌ Invalid user_id format: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid user ID",
		})
		return
	}

	log.Printf("[WebSocket] Attempting to upgrade connection for user: %s", userID)

	// Upgrade HTTP connection to WebSocket
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("[WebSocket] ❌ Failed to upgrade connection: %v", err)
		// Don't call c.JSON after upgrade attempt fails - connection might be in bad state
		return
	}

	log.Printf("[WebSocket] ✅ Connection upgraded successfully for user: %s", userID)

	// Register the connection
	connection := h.manager.Register(userID, conn)

	log.Printf("[WebSocket] ✅ User %s connected successfully (connection id: %s)", userID, connection.ID)
}

// SetupRoutes registers WebSocket routes
func (h *Handlers) SetupRoutes(router *gin.RouterGroup) {
	router.GET("/ws", h.HandleWebSocket)
}

// GetStats returns WebSocket statistics (for monitoring/debugging)
func (h *Handlers) GetStats(c *gin.Context) {
	stats := gin.H{
		"success":           true,
		"total_connections": h.manager.GetTotalConnections(),
		"connected_users":   h.manager.GetConnectedUsers(),
	}

	c.JSON(http.StatusOK, stats)
}

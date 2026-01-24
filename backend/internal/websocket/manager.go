package websocket

import (
	"context"
	"encoding/json"
	"log"
	"sync"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

const (
	// Time allowed to write a message to the peer
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer
	pongWait = 60 * time.Second

	// Send pings to peer with this period (must be less than pongWait)
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer
	maxMessageSize = 512

	// Maximum connections per user
	maxConnectionsPerUser = 5
)

// Connection represents a single WebSocket connection
type Connection struct {
	ID       uuid.UUID
	UserID   uuid.UUID
	Conn     *websocket.Conn
	Send     chan []byte
	Manager  *Manager
	mu       sync.Mutex
	isClosed bool
}

// PendingMessage represents a message awaiting acknowledgment
type PendingMessage struct {
	ID           string
	RecipientID  uuid.UUID
	Payload      []byte
	SentAt       time.Time
	RetryCount   int
	MaxRetries   int
	Acknowledged bool
}

// Manager manages all WebSocket connections (Hub pattern)
type Manager struct {
	// Registered connections mapped by user ID
	connections map[uuid.UUID][]*Connection

	// Register requests from connections
	register chan *Connection

	// Unregister requests from connections
	unregister chan *Connection

	// Broadcast messages to specific users
	broadcast chan *BroadcastMessage

	// Mutex for thread-safe operations
	mu sync.RWMutex

	// Context for graceful shutdown
	ctx context.Context

	// Cancel function
	cancel context.CancelFunc

	// Pending messages awaiting acknowledgment (messageID -> pending message)
	pendingMessages map[string]*PendingMessage
	pendingMu       sync.RWMutex

	// ACK timeout duration
	ackTimeout time.Duration
}

// BroadcastMessage represents a message to be broadcast to specific users
type BroadcastMessage struct {
	UserIDs []uuid.UUID
	Message []byte
}

// NewManager creates a new WebSocket manager
func NewManager() *Manager {
	ctx, cancel := context.WithCancel(context.Background())
	m := &Manager{
		connections:     make(map[uuid.UUID][]*Connection),
		register:        make(chan *Connection, 256),
		unregister:      make(chan *Connection, 256),
		broadcast:       make(chan *BroadcastMessage, 1024),
		ctx:             ctx,
		cancel:          cancel,
		pendingMessages: make(map[string]*PendingMessage),
		ackTimeout:      5 * time.Second,
	}

	// Start retry goroutine for pending messages
	go m.retryPendingMessages()

	return m
}

// Run starts the manager's main loop
func (m *Manager) Run() {
	log.Println("[WebSocket] Manager started")
	defer log.Println("[WebSocket] Manager stopped")

	for {
		select {
		case conn := <-m.register:
			m.handleRegister(conn)

		case conn := <-m.unregister:
			m.handleUnregister(conn)

		case message := <-m.broadcast:
			m.handleBroadcast(message)

		case <-m.ctx.Done():
			m.shutdown()
			return
		}
	}
}

// Register adds a new connection
func (m *Manager) Register(userID uuid.UUID, conn *websocket.Conn) *Connection {
	connection := &Connection{
		ID:      uuid.New(),
		UserID:  userID,
		Conn:    conn,
		Send:    make(chan []byte, 256),
		Manager: m,
	}

	m.register <- connection

	// Start goroutines for this connection
	go connection.writePump()
	go connection.readPump()

	return connection
}

// Unregister removes a connection
func (m *Manager) Unregister(conn *Connection) {
	m.unregister <- conn
}

// BroadcastToUser sends a message to all connections of a specific user
func (m *Manager) BroadcastToUser(userID uuid.UUID, message []byte) {
	m.broadcast <- &BroadcastMessage{
		UserIDs: []uuid.UUID{userID},
		Message: message,
	}
}

// BroadcastToUsers sends a message to all connections of multiple users
func (m *Manager) BroadcastToUsers(userIDs []uuid.UUID, message []byte) {
	m.broadcast <- &BroadcastMessage{
		UserIDs: userIDs,
		Message: message,
	}
}

// BroadcastNotification sends a notification to a user via WebSocket
func (m *Manager) BroadcastNotification(userID uuid.UUID, notification *models.NotificationResponse) {
	message := models.WSMessage{
		Type: "notification",
		Data: notification,
	}

	messageBytes, err := json.Marshal(message)
	if err != nil {
		log.Printf("[WebSocket] Failed to marshal notification: %v", err)
		return
	}

	m.BroadcastToUser(userID, messageBytes)
}

// BroadcastCountUpdate sends an unread count update to a user
func (m *Manager) BroadcastCountUpdate(userID uuid.UUID, total int, categoryCounts map[string]int) {
	message := models.WSMessage{
		Type: "count_update",
		Data: map[string]interface{}{
			"total":           total,
			"category_counts": categoryCounts,
		},
	}

	messageBytes, err := json.Marshal(message)
	if err != nil {
		log.Printf("[WebSocket] Failed to marshal count update: %v", err)
		return
	}

	m.BroadcastToUser(userID, messageBytes)
}

// GetConnectionCount returns the number of active connections for a user
func (m *Manager) GetConnectionCount(userID uuid.UUID) int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.connections[userID])
}

// GetTotalConnections returns the total number of active connections
func (m *Manager) GetTotalConnections() int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	total := 0
	for _, conns := range m.connections {
		total += len(conns)
	}
	return total
}

// GetConnectedUsers returns the number of unique connected users
func (m *Manager) GetConnectedUsers() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.connections)
}

// Shutdown gracefully shuts down the manager
func (m *Manager) Shutdown() {
	m.cancel()
}

// =====================================================
// INTERNAL HANDLERS
// =====================================================

func (m *Manager) handleRegister(conn *Connection) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Check connection limit per user
	if len(m.connections[conn.UserID]) >= maxConnectionsPerUser {
		log.Printf("[WebSocket] User %s reached max connections (%d), closing oldest", conn.UserID, maxConnectionsPerUser)
		// Close the oldest connection
		if len(m.connections[conn.UserID]) > 0 {
			oldest := m.connections[conn.UserID][0]
			oldest.Close()
			m.connections[conn.UserID] = m.connections[conn.UserID][1:]
		}
	}

	// Add new connection
	m.connections[conn.UserID] = append(m.connections[conn.UserID], conn)
	log.Printf("[WebSocket] User %s connected (id: %s), total connections: %d", conn.UserID, conn.ID, len(m.connections[conn.UserID]))
}

func (m *Manager) handleUnregister(conn *Connection) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if connections, ok := m.connections[conn.UserID]; ok {
		// Find and remove the connection
		for i, c := range connections {
			if c.ID == conn.ID {
				// Close the connection's send channel
				close(c.Send)

				// Remove from slice
				m.connections[conn.UserID] = append(connections[:i], connections[i+1:]...)

				// If no more connections for this user, remove the user entry
				if len(m.connections[conn.UserID]) == 0 {
					delete(m.connections, conn.UserID)
					log.Printf("[WebSocket] User %s disconnected (no more connections)", conn.UserID)
				} else {
					log.Printf("[WebSocket] User %s connection closed (id: %s), remaining: %d", conn.UserID, conn.ID, len(m.connections[conn.UserID]))
				}
				break
			}
		}
	}
}

func (m *Manager) handleBroadcast(message *BroadcastMessage) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, userID := range message.UserIDs {
		if connections, ok := m.connections[userID]; ok {
			for _, conn := range connections {
				select {
				case conn.Send <- message.Message:
					// Message sent successfully
				default:
					// Buffer full, close connection
					log.Printf("[WebSocket] Connection buffer full for user %s, closing", userID)
					go m.Unregister(conn)
				}
			}
		}
	}
}

func (m *Manager) shutdown() {
	m.mu.Lock()
	defer m.mu.Unlock()

	log.Println("[WebSocket] Shutting down, closing all connections...")

	for userID, connections := range m.connections {
		for _, conn := range connections {
			conn.Close()
		}
		delete(m.connections, userID)
	}

	log.Println("[WebSocket] All connections closed")
}

// =====================================================
// CONNECTION METHODS
// =====================================================

// readPump pumps messages from the WebSocket connection to the manager
func (conn *Connection) readPump() {
	defer func() {
		conn.Manager.Unregister(conn)
		conn.Conn.Close()
	}()

	conn.Conn.SetReadLimit(maxMessageSize)
	conn.Conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.Conn.SetPongHandler(func(string) error {
		conn.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := conn.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[WebSocket] Error reading from connection: %v", err)
			}
			break
		}

		// Handle incoming messages (ping, mark as read, etc.)
		conn.handleMessage(message)
	}
}

// writePump pumps messages from the manager to the WebSocket connection
func (conn *Connection) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		conn.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-conn.Send:
			conn.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Channel closed
				conn.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := conn.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Flush any additional messages in the queue
			n := len(conn.Send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-conn.Send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			conn.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := conn.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// handleMessage processes incoming messages from the client
func (conn *Connection) handleMessage(message []byte) {
	var msg models.WSMessage
	if err := json.Unmarshal(message, &msg); err != nil {
		log.Printf("[WebSocket] Failed to unmarshal message: %v", err)
		return
	}

	switch msg.Type {
	case "ping":
		// Respond with pong
		pong := models.WSMessage{Type: "pong"}
		if pongBytes, err := json.Marshal(pong); err == nil {
			conn.Send <- pongBytes
		}

	case "pong":
		// Client responded to ping, update read deadline
		conn.Conn.SetReadDeadline(time.Now().Add(pongWait))

	default:
		log.Printf("[WebSocket] Unknown message type: %s", msg.Type)
	}
}

// Close closes the connection
func (conn *Connection) Close() {
	conn.mu.Lock()
	defer conn.mu.Unlock()

	if !conn.isClosed {
		conn.isClosed = true
		conn.Conn.Close()
	}
}

// SendMessage sends a message to this specific connection
func (conn *Connection) SendMessage(message []byte) error {
	conn.mu.Lock()
	defer conn.mu.Unlock()

	if conn.isClosed {
		return websocket.ErrCloseSent
	}

	select {
	case conn.Send <- message:
		return nil
	default:
		return websocket.ErrCloseSent
	}
}

// =====================================================
// ACK TRACKING & MESSAGING ENHANCEMENTS
// =====================================================

// SendWithACK sends a message to a user and tracks it for acknowledgment
func (m *Manager) SendWithACK(userID uuid.UUID, messageID string, payload interface{}, maxRetries int) error {
	// Marshal payload to JSON
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	// Create pending message
	pending := &PendingMessage{
		ID:           messageID,
		RecipientID:  userID,
		Payload:      payloadBytes,
		SentAt:       time.Now(),
		RetryCount:   0,
		MaxRetries:   maxRetries,
		Acknowledged: false,
	}

	// Store in pending messages
	m.pendingMu.Lock()
	m.pendingMessages[messageID] = pending
	m.pendingMu.Unlock()

	// Send the message
	m.BroadcastToUser(userID, payloadBytes)

	log.Printf("[WebSocket] Sent message %s to user %s with ACK tracking", messageID, userID)
	return nil
}

// HandleACK processes an acknowledgment from a client
func (m *Manager) HandleACK(messageID string, userID uuid.UUID) {
	m.pendingMu.Lock()
	defer m.pendingMu.Unlock()

	if pending, exists := m.pendingMessages[messageID]; exists {
		if pending.RecipientID == userID {
			pending.Acknowledged = true
			delete(m.pendingMessages, messageID)
			log.Printf("[WebSocket] Message %s acknowledged by user %s", messageID, userID)
		}
	}
}

// retryPendingMessages periodically retries unacknowledged messages
func (m *Manager) retryPendingMessages() {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			m.retryUnacknowledged()
		case <-m.ctx.Done():
			return
		}
	}
}

// retryUnacknowledged retries sending unacknowledged messages
func (m *Manager) retryUnacknowledged() {
	m.pendingMu.Lock()
	defer m.pendingMu.Unlock()

	now := time.Now()
	toDelete := []string{}

	for messageID, pending := range m.pendingMessages {
		if pending.Acknowledged {
			toDelete = append(toDelete, messageID)
			continue
		}

		// Check if message has timed out
		if now.Sub(pending.SentAt) > m.ackTimeout {
			if pending.RetryCount < pending.MaxRetries {
				// Retry sending
				pending.RetryCount++
				pending.SentAt = now

				// Check if user is still connected
				if m.IsUserConnected(pending.RecipientID) {
					m.BroadcastToUser(pending.RecipientID, pending.Payload)
					log.Printf("[WebSocket] Retrying message %s to user %s (attempt %d/%d)",
						messageID, pending.RecipientID, pending.RetryCount, pending.MaxRetries)
				} else {
					log.Printf("[WebSocket] User %s not connected, keeping message %s in queue",
						pending.RecipientID, messageID)
				}
			} else {
				// Max retries reached, give up
				log.Printf("[WebSocket] Message %s failed after %d retries", messageID, pending.MaxRetries)
				toDelete = append(toDelete, messageID)
			}
		}
	}

	// Clean up acknowledged or failed messages
	for _, messageID := range toDelete {
		delete(m.pendingMessages, messageID)
	}
}

// IsUserConnected checks if a user has any active connections
func (m *Manager) IsUserConnected(userID uuid.UUID) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()

	connections, exists := m.connections[userID]
	return exists && len(connections) > 0
}

// BroadcastToUserWithData sends structured data to a user (converts to JSON)
func (m *Manager) BroadcastToUserWithData(userID uuid.UUID, data interface{}) error {
	messageBytes, err := json.Marshal(data)
	if err != nil {
		return err
	}

	m.BroadcastToUser(userID, messageBytes)
	return nil
}

// GetPendingMessageCount returns the count of pending messages
func (m *Manager) GetPendingMessageCount() int {
	m.pendingMu.RLock()
	defer m.pendingMu.RUnlock()
	return len(m.pendingMessages)
}

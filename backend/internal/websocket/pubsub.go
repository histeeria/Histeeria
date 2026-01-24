package websocket

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/google/uuid"
)

// ============================================
// REDIS PUB/SUB FOR MULTI-INSTANCE WEBSOCKET SCALING
// ============================================

// PubSubManager handles Redis Pub/Sub for distributed WebSocket events
type PubSubManager struct {
	redis    *redis.Client
	manager  *Manager
	ctx      context.Context
	cancel   context.CancelFunc
	enabled  bool
	channels []string
}

// PubSubMessage represents a message to be broadcast via Pub/Sub
type PubSubMessage struct {
	Type    string          `json:"type"`
	UserIDs []string        `json:"user_ids"`
	Payload json.RawMessage `json:"payload"`
}

// NewPubSubManager creates a new Pub/Sub manager
func NewPubSubManager(redisClient *redis.Client, wsManager *Manager) *PubSubManager {
	ctx, cancel := context.WithCancel(context.Background())

	return &PubSubManager{
		redis:    redisClient,
		manager:  wsManager,
		ctx:      ctx,
		cancel:   cancel,
		enabled:  redisClient != nil,
		channels: []string{"ws:broadcast", "ws:notification", "ws:message"},
	}
}

// Start begins listening to Pub/Sub channels
func (ps *PubSubManager) Start() {
	if !ps.enabled {
		log.Println("[PubSub] Redis not available, running in single-instance mode")
		return
	}

	log.Println("[PubSub] Starting Redis Pub/Sub listener...")

	// Subscribe to channels
	pubsub := ps.redis.Subscribe(ps.ctx, ps.channels...)

	// Wait for subscription confirmation
	_, err := pubsub.Receive(ps.ctx)
	if err != nil {
		log.Printf("[PubSub] Failed to subscribe: %v", err)
		ps.enabled = false
		return
	}

	log.Printf("[PubSub] Subscribed to channels: %v", ps.channels)

	// Start receiving messages
	go ps.receiveMessages(pubsub)
}

// Stop stops the Pub/Sub listener
func (ps *PubSubManager) Stop() {
	log.Println("[PubSub] Stopping...")
	ps.cancel()
}

// receiveMessages processes incoming Pub/Sub messages
func (ps *PubSubManager) receiveMessages(pubsub *redis.PubSub) {
	defer pubsub.Close()

	ch := pubsub.Channel()

	for {
		select {
		case <-ps.ctx.Done():
			log.Println("[PubSub] Stopped")
			return

		case msg := <-ch:
			if msg == nil {
				continue
			}

			ps.handleMessage(msg)
		}
	}
}

// handleMessage processes a single Pub/Sub message
func (ps *PubSubManager) handleMessage(msg *redis.Message) {
	var pubsubMsg PubSubMessage
	if err := json.Unmarshal([]byte(msg.Payload), &pubsubMsg); err != nil {
		log.Printf("[PubSub] Failed to unmarshal message: %v", err)
		return
	}

	// Convert string UUIDs to uuid.UUID
	userIDs := make([]interface{}, len(pubsubMsg.UserIDs))
	for i, idStr := range pubsubMsg.UserIDs {
		userIDs[i] = idStr
	}

	// Broadcast to connected users on this instance
	switch pubsubMsg.Type {
	case "broadcast":
		ps.broadcastToUsers(pubsubMsg.UserIDs, pubsubMsg.Payload)
	case "notification":
		ps.broadcastNotification(pubsubMsg.UserIDs, pubsubMsg.Payload)
	default:
		log.Printf("[PubSub] Unknown message type: %s", pubsubMsg.Type)
	}
}

// broadcastToUsers sends a message to specific users on this instance
func (ps *PubSubManager) broadcastToUsers(userIDStrs []string, payload json.RawMessage) {
	ps.manager.mu.RLock()
	defer ps.manager.mu.RUnlock()

	for _, userIDStr := range userIDStrs {
		// Parse UUID from string
		userID, err := uuid.Parse(userIDStr)
		if err != nil {
			log.Printf("[PubSub] Invalid user ID %s: %v", userIDStr, err)
			continue
		}

		// Check if user is connected to this instance
		if connections, ok := ps.manager.connections[userID]; ok {
			for _, conn := range connections {
				select {
				case conn.Send <- payload:
					// Message sent
				default:
					// Buffer full, log warning
					log.Printf("[PubSub] Buffer full for user %s", userID)
				}
			}
		}
	}
}

// broadcastNotification sends a notification to users on this instance
func (ps *PubSubManager) broadcastNotification(userIDStrs []string, payload json.RawMessage) {
	// Same as broadcast for now, can be customized
	ps.broadcastToUsers(userIDStrs, payload)
}

// PublishBroadcast publishes a broadcast message to all instances
func (ps *PubSubManager) PublishBroadcast(userIDStrs []string, payload interface{}) error {
	if !ps.enabled {
		// Fallback to local broadcast
		return nil
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	msg := PubSubMessage{
		Type:    "broadcast",
		UserIDs: userIDStrs,
		Payload: payloadBytes,
	}

	msgBytes, err := json.Marshal(msg)
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	return ps.redis.Publish(ctx, "ws:broadcast", msgBytes).Err()
}

// PublishNotification publishes a notification to all instances
func (ps *PubSubManager) PublishNotification(userIDStrs []string, payload interface{}) error {
	if !ps.enabled {
		return nil
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	msg := PubSubMessage{
		Type:    "notification",
		UserIDs: userIDStrs,
		Payload: payloadBytes,
	}

	msgBytes, err := json.Marshal(msg)
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	return ps.redis.Publish(ctx, "ws:notification", msgBytes).Err()
}

// IsEnabled returns whether Pub/Sub is enabled
func (ps *PubSubManager) IsEnabled() bool {
	return ps.enabled
}

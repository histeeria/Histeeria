package messaging

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/websocket"

	"github.com/google/uuid"
)

// DeliveryService handles WhatsApp-style store-and-forward messaging
// Messages are stored until delivered, then scheduled for deletion
//
// This service extends the base MessageRepository with delivery tracking capabilities.
// It requires the following additional methods to be implemented in the repository:
// - GetPendingMessagesForUser(ctx, userID) ([]*models.Message, error)
// - MarkMessageDelivered(ctx, messageID) error
// - MarkConversationDelivered(ctx, conversationID, recipientID) (int, error)
// - CleanupDeliveredMessages(ctx) (int, error)
// - CleanupUndeliveredMessages(ctx) (int, error)
//
// These methods map to the database functions created in 05_messaging.sql

// DeliveryRepository extends MessageRepository with delivery tracking
type DeliveryRepository interface {
	// Existing methods from MessageRepository that we need
	GetMessage(ctx context.Context, messageID uuid.UUID) (*models.Message, error)
	GetConversation(ctx context.Context, conversationID uuid.UUID) (*models.Conversation, error)
	GetConversationMessages(ctx context.Context, conversationID uuid.UUID, limit, offset int) ([]*models.Message, error)
	UpdateMessageStatus(ctx context.Context, messageID uuid.UUID, status models.MessageStatus) error
	MarkMessagesAsRead(ctx context.Context, conversationID, readerID uuid.UUID) error

	// New delivery tracking methods
	GetPendingMessagesForUser(ctx context.Context, userID uuid.UUID) ([]*models.Message, error)
	MarkMessageDelivered(ctx context.Context, messageID uuid.UUID) error
	MarkConversationDelivered(ctx context.Context, conversationID uuid.UUID, recipientID uuid.UUID) (int, error)
	CleanupDeliveredMessages(ctx context.Context) (int, error)
	CleanupUndeliveredMessages(ctx context.Context) (int, error)
}

// DeliveryService handles message delivery tracking
type DeliveryService struct {
	repo      DeliveryRepository
	wsManager *websocket.Manager
}

// NewDeliveryService creates a new delivery service
func NewDeliveryService(repo DeliveryRepository, wsManager *websocket.Manager) *DeliveryService {
	return &DeliveryService{
		repo:      repo,
		wsManager: wsManager,
	}
}

// PendingMessage represents a message awaiting delivery
type PendingMessage struct {
	ID             uuid.UUID          `json:"id"`
	ConversationID uuid.UUID          `json:"conversation_id"`
	SenderID       uuid.UUID          `json:"sender_id"`
	Content        string             `json:"content"`
	MessageType    models.MessageType `json:"message_type"`
	AttachmentURL  *string            `json:"attachment_url,omitempty"`
	AttachmentName *string            `json:"attachment_name,omitempty"`
	AttachmentType *string            `json:"attachment_type,omitempty"`
	CreatedAt      time.Time          `json:"created_at"`
	ReplyToID      *uuid.UUID         `json:"reply_to_id,omitempty"`
}

// DeliveryStatus represents the delivery status response
type DeliveryStatus struct {
	MessageID       uuid.UUID  `json:"message_id"`
	Status          string     `json:"status"` // sent, delivered, read
	DeliveredAt     *time.Time `json:"delivered_at,omitempty"`
	ReadAt          *time.Time `json:"read_at,omitempty"`
	DeleteScheduled *time.Time `json:"delete_scheduled,omitempty"`
}

// MessageSyncResponse is sent when user syncs pending messages
type MessageSyncResponse struct {
	Messages     []PendingMessage `json:"messages"`
	TotalPending int              `json:"total_pending"`
	SyncedAt     time.Time        `json:"synced_at"`
}

// ============================================
// CORE DELIVERY METHODS
// ============================================

// GetPendingMessages retrieves all pending messages for a user
// Called when user connects/opens app to sync their messages
func (s *DeliveryService) GetPendingMessages(ctx context.Context, userID uuid.UUID) (*MessageSyncResponse, error) {
	messages, err := s.repo.GetPendingMessagesForUser(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get pending messages: %w", err)
	}

	// Convert to pending message format using existing Message model fields
	pending := make([]PendingMessage, 0, len(messages))
	for _, msg := range messages {
		pending = append(pending, PendingMessage{
			ID:             msg.ID,
			ConversationID: msg.ConversationID,
			SenderID:       msg.SenderID,
			Content:        msg.Content,
			MessageType:    msg.MessageType,
			AttachmentURL:  msg.AttachmentURL,
			AttachmentName: msg.AttachmentName,
			AttachmentType: msg.AttachmentType,
			CreatedAt:      msg.CreatedAt,
			ReplyToID:      msg.ReplyToID,
		})
	}

	return &MessageSyncResponse{
		Messages:     pending,
		TotalPending: len(pending),
		SyncedAt:     time.Now(),
	}, nil
}

// MarkMessageDelivered marks a message as delivered and schedules deletion
// Called when recipient downloads/receives the message
func (s *DeliveryService) MarkMessageDelivered(ctx context.Context, messageID uuid.UUID, recipientID uuid.UUID) (*DeliveryStatus, error) {
	// Update message status
	err := s.repo.MarkMessageDelivered(ctx, messageID)
	if err != nil {
		return nil, fmt.Errorf("failed to mark message delivered: %w", err)
	}

	now := time.Now()
	deleteTime := now.Add(24 * time.Hour)

	// Get message to notify sender
	msg, err := s.repo.GetMessage(ctx, messageID)
	if err == nil && msg != nil {
		// Notify sender of delivery (double tick ✓✓)
		s.notifyDeliveryStatus(msg.SenderID, messageID, "delivered", &now, nil)
	}

	return &DeliveryStatus{
		MessageID:       messageID,
		Status:          "delivered",
		DeliveredAt:     &now,
		DeleteScheduled: &deleteTime,
	}, nil
}

// MarkMessagesDelivered marks multiple messages as delivered (batch)
// Called when user opens a conversation
func (s *DeliveryService) MarkMessagesDelivered(ctx context.Context, conversationID uuid.UUID, recipientID uuid.UUID) (int, error) {
	count, err := s.repo.MarkConversationDelivered(ctx, conversationID, recipientID)
	if err != nil {
		return 0, fmt.Errorf("failed to mark conversation delivered: %w", err)
	}

	// Notify sender about delivery
	if count > 0 {
		go s.notifyConversationDelivered(context.Background(), conversationID, recipientID)
	}

	return count, nil
}

// MarkMessageRead marks a message as read
func (s *DeliveryService) MarkMessageRead(ctx context.Context, messageID uuid.UUID, readerID uuid.UUID) error {
	err := s.repo.UpdateMessageStatus(ctx, messageID, models.MessageStatusRead)
	if err != nil {
		return fmt.Errorf("failed to mark message read: %w", err)
	}

	now := time.Now()

	// Get message to notify sender
	msg, err := s.repo.GetMessage(ctx, messageID)
	if err == nil && msg != nil {
		// Notify sender of read (blue ticks)
		s.notifyDeliveryStatus(msg.SenderID, messageID, "read", nil, &now)
	}

	return nil
}

// ============================================
// CLEANUP JOBS
// ============================================

// CleanupDeliveredMessages deletes messages that have been delivered
// and past their grace period (24 hours)
// Should be called by a scheduled job (hourly)
func (s *DeliveryService) CleanupDeliveredMessages(ctx context.Context) (int, error) {
	count, err := s.repo.CleanupDeliveredMessages(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to cleanup delivered messages: %w", err)
	}

	if count > 0 {
		log.Printf("[Delivery] Cleaned up %d delivered messages", count)
	}

	return count, nil
}

// CleanupUndeliveredMessages deletes messages that were never delivered
// (recipient offline for 30+ days)
// Should be called by a scheduled job (daily)
func (s *DeliveryService) CleanupUndeliveredMessages(ctx context.Context) (int, error) {
	count, err := s.repo.CleanupUndeliveredMessages(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to cleanup undelivered messages: %w", err)
	}

	if count > 0 {
		log.Printf("[Delivery] Cleaned up %d undelivered messages (30+ days old)", count)
	}

	return count, nil
}

// ============================================
// WEBSOCKET NOTIFICATIONS
// ============================================

// notifyDeliveryStatus sends delivery status update via WebSocket
func (s *DeliveryService) notifyDeliveryStatus(userID uuid.UUID, messageID uuid.UUID, status string, deliveredAt, readAt *time.Time) {
	notification := models.WSMessage{
		Type: "message_status",
		Data: map[string]interface{}{
			"message_id":   messageID.String(),
			"status":       status,
			"delivered_at": deliveredAt,
			"read_at":      readAt,
		},
	}

	data, err := json.Marshal(notification)
	if err != nil {
		log.Printf("[Delivery] Failed to marshal notification: %v", err)
		return
	}

	s.wsManager.BroadcastToUser(userID, data)
}

// notifyConversationDelivered notifies sender about bulk delivery
func (s *DeliveryService) notifyConversationDelivered(ctx context.Context, conversationID uuid.UUID, recipientID uuid.UUID) {
	conv, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil || conv == nil {
		return
	}

	// Determine the sender (the other participant)
	var senderID uuid.UUID
	if conv.Participant1ID == recipientID {
		senderID = conv.Participant2ID
	} else {
		senderID = conv.Participant1ID
	}

	notification := models.WSMessage{
		Type: "conversation_delivered",
		Data: map[string]interface{}{
			"conversation_id": conversationID.String(),
			"delivered_at":    time.Now(),
		},
	}

	data, err := json.Marshal(notification)
	if err != nil {
		return
	}

	s.wsManager.BroadcastToUser(senderID, data)
}

package repository

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// DeliveryRepositoryAdapter adapts MessageRepository to DeliveryRepository interface
// Implements WhatsApp-style store-and-forward delivery tracking
type DeliveryRepositoryAdapter struct {
	baseRepo MessageRepository
	supabaseURL string
	supabaseKey string
}

// NewDeliveryRepositoryAdapter creates a new delivery repository adapter
func NewDeliveryRepositoryAdapter(baseRepo MessageRepository, supabaseURL, supabaseKey string) *DeliveryRepositoryAdapter {
	return &DeliveryRepositoryAdapter{
		baseRepo: baseRepo,
		supabaseURL: supabaseURL,
		supabaseKey: supabaseKey,
	}
}

// Implement MessageRepository methods (delegate to baseRepo)
func (r *DeliveryRepositoryAdapter) GetOrCreateConversation(ctx context.Context, user1ID, user2ID uuid.UUID) (*models.Conversation, error) {
	return r.baseRepo.GetOrCreateConversation(ctx, user1ID, user2ID)
}

func (r *DeliveryRepositoryAdapter) GetConversation(ctx context.Context, conversationID uuid.UUID) (*models.Conversation, error) {
	return r.baseRepo.GetConversation(ctx, conversationID)
}

func (r *DeliveryRepositoryAdapter) GetUserConversations(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.Conversation, error) {
	return r.baseRepo.GetUserConversations(ctx, userID, limit, offset)
}

func (r *DeliveryRepositoryAdapter) UpdateConversationTyping(ctx context.Context, conversationID, userID uuid.UUID, isTyping bool) error {
	return r.baseRepo.UpdateConversationTyping(ctx, conversationID, userID, isTyping)
}

func (r *DeliveryRepositoryAdapter) MarkConversationAsRead(ctx context.Context, conversationID, userID uuid.UUID) error {
	return r.baseRepo.MarkConversationAsRead(ctx, conversationID, userID)
}

func (r *DeliveryRepositoryAdapter) DeleteConversation(ctx context.Context, conversationID, userID uuid.UUID) error {
	return r.baseRepo.DeleteConversation(ctx, conversationID, userID)
}

func (r *DeliveryRepositoryAdapter) GetUnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	return r.baseRepo.GetUnreadCount(ctx, userID)
}

func (r *DeliveryRepositoryAdapter) CreateMessage(ctx context.Context, message *models.Message) error {
	return r.baseRepo.CreateMessage(ctx, message)
}

func (r *DeliveryRepositoryAdapter) GetMessage(ctx context.Context, messageID uuid.UUID) (*models.Message, error) {
	return r.baseRepo.GetMessage(ctx, messageID)
}

func (r *DeliveryRepositoryAdapter) GetConversationMessages(ctx context.Context, conversationID uuid.UUID, limit, offset int) ([]*models.Message, error) {
	return r.baseRepo.GetConversationMessages(ctx, conversationID, limit, offset)
}

func (r *DeliveryRepositoryAdapter) UpdateMessageStatus(ctx context.Context, messageID uuid.UUID, status models.MessageStatus) error {
	return r.baseRepo.UpdateMessageStatus(ctx, messageID, status)
}

func (r *DeliveryRepositoryAdapter) MarkMessagesAsRead(ctx context.Context, conversationID, readerID uuid.UUID) error {
	return r.baseRepo.MarkMessagesAsRead(ctx, conversationID, readerID)
}

func (r *DeliveryRepositoryAdapter) DeleteMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	return r.baseRepo.DeleteMessage(ctx, messageID, userID)
}

func (r *DeliveryRepositoryAdapter) SearchMessages(ctx context.Context, userID uuid.UUID, query string, limit, offset int) ([]*models.Message, error) {
	return r.baseRepo.SearchMessages(ctx, userID, query, limit, offset)
}

func (r *DeliveryRepositoryAdapter) SearchConversationMessages(ctx context.Context, conversationID uuid.UUID, query string, limit, offset int) ([]*models.Message, error) {
	return r.baseRepo.SearchConversationMessages(ctx, conversationID, query, limit, offset)
}

func (r *DeliveryRepositoryAdapter) PinMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	return r.baseRepo.PinMessage(ctx, messageID, userID)
}

func (r *DeliveryRepositoryAdapter) UnpinMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	return r.baseRepo.UnpinMessage(ctx, messageID, userID)
}

func (r *DeliveryRepositoryAdapter) GetPinnedMessages(ctx context.Context, conversationID uuid.UUID) ([]*models.Message, error) {
	return r.baseRepo.GetPinnedMessages(ctx, conversationID)
}

func (r *DeliveryRepositoryAdapter) EditMessage(ctx context.Context, messageID uuid.UUID, newContent string, editorID uuid.UUID) error {
	return r.baseRepo.EditMessage(ctx, messageID, newContent, editorID)
}

func (r *DeliveryRepositoryAdapter) GetMessageEditHistory(ctx context.Context, messageID uuid.UUID) ([]map[string]interface{}, error) {
	return r.baseRepo.GetMessageEditHistory(ctx, messageID)
}

func (r *DeliveryRepositoryAdapter) ForwardMessage(ctx context.Context, messageID uuid.UUID, toConversationID uuid.UUID, forwarderID uuid.UUID) (*models.Message, error) {
	return r.baseRepo.ForwardMessage(ctx, messageID, toConversationID, forwarderID)
}

func (r *DeliveryRepositoryAdapter) AddReaction(ctx context.Context, messageID, userID uuid.UUID, emoji string) (*models.MessageReaction, error) {
	return r.baseRepo.AddReaction(ctx, messageID, userID, emoji)
}

func (r *DeliveryRepositoryAdapter) RemoveReaction(ctx context.Context, reactionID uuid.UUID) error {
	return r.baseRepo.RemoveReaction(ctx, reactionID)
}

func (r *DeliveryRepositoryAdapter) RemoveUserReaction(ctx context.Context, messageID, userID uuid.UUID) error {
	return r.baseRepo.RemoveUserReaction(ctx, messageID, userID)
}

func (r *DeliveryRepositoryAdapter) GetMessageReactions(ctx context.Context, messageID uuid.UUID) ([]*models.MessageReaction, error) {
	return r.baseRepo.GetMessageReactions(ctx, messageID)
}

func (r *DeliveryRepositoryAdapter) StarMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	return r.baseRepo.StarMessage(ctx, messageID, userID)
}

func (r *DeliveryRepositoryAdapter) UnstarMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	return r.baseRepo.UnstarMessage(ctx, messageID, userID)
}

func (r *DeliveryRepositoryAdapter) GetStarredMessages(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.Message, error) {
	return r.baseRepo.GetStarredMessages(ctx, userID, limit, offset)
}

func (r *DeliveryRepositoryAdapter) IsMessageStarred(ctx context.Context, messageID, userID uuid.UUID) (bool, error) {
	return r.baseRepo.IsMessageStarred(ctx, messageID, userID)
}

// ============================================
// DELIVERY TRACKING METHODS
// ============================================

// GetPendingMessagesForUser retrieves all pending messages for a user
// Calls the database function get_pending_messages(user_id)
func (r *DeliveryRepositoryAdapter) GetPendingMessagesForUser(ctx context.Context, userID uuid.UUID) ([]*models.Message, error) {
	// Call Supabase RPC function: get_pending_messages
	endpoint := fmt.Sprintf("%s/rest/v1/rpc/get_pending_messages", r.supabaseURL)
	
	reqBody := map[string]interface{}{
		"p_user_id": userID.String(),
	}
	
	reqBodyJSON, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}
	
	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewBuffer(reqBodyJSON))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apikey", r.supabaseKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseKey)
	req.Header.Set("Prefer", "return=representation")
	
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to call RPC: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("RPC call failed: %d - %s", resp.StatusCode, string(body))
	}
	
	var results []struct {
		MessageID      uuid.UUID `json:"message_id"`
		ConversationID uuid.UUID `json:"conversation_id"`
		SenderID       uuid.UUID `json:"sender_id"`
		Content        *string   `json:"content"`
		EncryptedContent *string `json:"encrypted_content"`
		EncryptionVersion int    `json:"encryption_version"`
		MessageType    string   `json:"message_type"`
		CreatedAt      string   `json:"created_at"`
		ReplyToID      *uuid.UUID `json:"reply_to_id"`
		AttachmentURL  *string  `json:"attachment_url"`
		AttachmentName *string  `json:"attachment_name"`
		AttachmentType *string  `json:"attachment_type"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}
	
	// Convert to Message models
	messages := make([]*models.Message, 0, len(results))
	for _, res := range results {
		createdAt, _ := time.Parse(time.RFC3339, res.CreatedAt)
		
		// Use encrypted_content if available, otherwise use content
		content := ""
		if res.EncryptedContent != nil && *res.EncryptedContent != "" {
			content = *res.EncryptedContent
		} else if res.Content != nil {
			content = *res.Content
		}
		
		msg := &models.Message{
			ID:             res.MessageID,
			ConversationID: res.ConversationID,
			SenderID:       res.SenderID,
			Content:        content,
			MessageType:    models.MessageType(res.MessageType),
			CreatedAt:      createdAt,
			ReplyToID:      res.ReplyToID,
			AttachmentURL:  res.AttachmentURL,
			AttachmentName: res.AttachmentName,
			AttachmentType: res.AttachmentType,
			Status:         models.MessageStatusSent,
		}
		messages = append(messages, msg)
	}
	
	return messages, nil
}

// MarkMessageDelivered marks a message as delivered and schedules deletion
// Calls the database function mark_message_delivered(message_id)
func (r *DeliveryRepositoryAdapter) MarkMessageDelivered(ctx context.Context, messageID uuid.UUID) error {
	endpoint := fmt.Sprintf("%s/rest/v1/rpc/mark_message_delivered", r.supabaseURL)
	
	reqBody := map[string]interface{}{
		"p_message_id": messageID.String(),
	}
	
	reqBodyJSON, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}
	
	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewBuffer(reqBodyJSON))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}
	
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apikey", r.supabaseKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseKey)
	
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to call RPC: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("RPC call failed: %d - %s", resp.StatusCode, string(body))
	}
	
	return nil
}

// MarkConversationDelivered marks all messages in a conversation as delivered
// Calls the database function mark_conversation_delivered(conversation_id, recipient_id)
func (r *DeliveryRepositoryAdapter) MarkConversationDelivered(ctx context.Context, conversationID, recipientID uuid.UUID) (int, error) {
	endpoint := fmt.Sprintf("%s/rest/v1/rpc/mark_conversation_delivered", r.supabaseURL)
	
	reqBody := map[string]interface{}{
		"p_conversation_id": conversationID.String(),
		"p_recipient_id":    recipientID.String(),
	}
	
	reqBodyJSON, err := json.Marshal(reqBody)
	if err != nil {
		return 0, fmt.Errorf("failed to marshal request: %w", err)
	}
	
	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewBuffer(reqBodyJSON))
	if err != nil {
		return 0, fmt.Errorf("failed to create request: %w", err)
	}
	
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apikey", r.supabaseKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseKey)
	req.Header.Set("Prefer", "return=representation")
	
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("failed to call RPC: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("RPC call failed: %d - %s", resp.StatusCode, string(body))
	}
	
	var result struct {
		Count int `json:"mark_conversation_delivered"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		// If response is empty, assume 0
		return 0, nil
	}
	
	return result.Count, nil
}

// CleanupDeliveredMessages deletes messages that have been delivered and past grace period
// Calls the database function cleanup_delivered_messages()
func (r *DeliveryRepositoryAdapter) CleanupDeliveredMessages(ctx context.Context) (int, error) {
	endpoint := fmt.Sprintf("%s/rest/v1/rpc/cleanup_delivered_messages", r.supabaseURL)
	
	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, nil)
	if err != nil {
		return 0, fmt.Errorf("failed to create request: %w", err)
	}
	
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apikey", r.supabaseKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseKey)
	req.Header.Set("Prefer", "return=representation")
	
	client := &http.Client{Timeout: 10 * time.Minute}
	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("failed to call RPC: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("RPC call failed: %d - %s", resp.StatusCode, string(body))
	}
	
	var result struct {
		Count int `json:"cleanup_delivered_messages"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return 0, nil
	}
	
	return result.Count, nil
}

// CleanupUndeliveredMessages deletes messages that were never delivered (30+ days old)
// Calls the database function cleanup_undelivered_messages()
func (r *DeliveryRepositoryAdapter) CleanupUndeliveredMessages(ctx context.Context) (int, error) {
	endpoint := fmt.Sprintf("%s/rest/v1/rpc/cleanup_undelivered_messages", r.supabaseURL)
	
	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, nil)
	if err != nil {
		return 0, fmt.Errorf("failed to create request: %w", err)
	}
	
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apikey", r.supabaseKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseKey)
	req.Header.Set("Prefer", "return=representation")
	
	client := &http.Client{Timeout: 15 * time.Minute}
	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("failed to call RPC: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("RPC call failed: %d - %s", resp.StatusCode, string(body))
	}
	
	var result struct {
		Count int `json:"cleanup_undelivered_messages"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return 0, nil
	}
	
	return result.Count, nil
}

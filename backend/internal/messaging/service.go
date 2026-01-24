package messaging

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"histeeria-backend/internal/cache"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	"histeeria-backend/internal/websocket"

	"github.com/google/uuid"
)

// NotificationService interface for creating notifications
type NotificationService interface {
	CreateNotification(ctx context.Context, notification *models.Notification) error
}

// MessagingService handles all messaging business logic
type MessagingService struct {
	repo         repository.MessageRepository
	cache        *cache.MessageCacheService
	wsManager    *websocket.Manager
	userRepo     repository.UserRepository
	notifService NotificationService
	// E2EE public key storage (conversationID:userID -> publicKey)
	publicKeys sync.Map
}

// NewMessagingService creates a new messaging service
func NewMessagingService(
	repo repository.MessageRepository,
	cache *cache.MessageCacheService,
	wsManager *websocket.Manager,
	userRepo repository.UserRepository,
	notifService NotificationService,
) *MessagingService {
	return &MessagingService{
		repo:         repo,
		cache:        cache,
		wsManager:    wsManager,
		userRepo:     userRepo,
		notifService: notifService,
	}
}

// SetNotificationService sets the notification service (called after initialization to avoid circular dependency)
func (s *MessagingService) SetNotificationService(notificationService NotificationService) {
	s.notifService = notificationService
}

// ============================================
// CONVERSATIONS
// ============================================

// GetConversations retrieves user's conversations with caching
func (s *MessagingService) GetConversations(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.Conversation, error) {
	// Try cache first (for initial load) - only if cache is available
	if offset == 0 && s.cache != nil {
		cached, err := s.cache.GetCachedConversations(ctx, userID)
		if err == nil && cached != nil {
			log.Printf("[Messaging] Returning %d cached conversations for user %s", len(cached), userID)
			return cached, nil
		}
	}

	// Fetch from database
	conversations, err := s.repo.GetUserConversations(ctx, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get conversations: %w", err)
	}

	// Enrich with presence information - use WebSocket manager for real-time status
	for _, conv := range conversations {
		if conv.OtherUser != nil {
			// Check if user is currently connected via WebSocket
			isOnline := s.wsManager.IsUserConnected(conv.OtherUser.ID)
			conv.IsOnline = isOnline

			// Get last seen from cache if offline
			if !isOnline && s.cache != nil {
				_, lastSeen, _ := s.cache.GetUserPresence(ctx, conv.OtherUser.ID)
				if !lastSeen.IsZero() {
					conv.LastSeen = &lastSeen
				}
			}
		}
	}

	// Cache for next time (only first page)
	if offset == 0 && s.cache != nil {
		s.cache.CacheConversations(ctx, userID, conversations)
	}

	return conversations, nil
}

// GetConversation retrieves a single conversation
func (s *MessagingService) GetConversation(ctx context.Context, conversationID, userID uuid.UUID) (*models.Conversation, error) {
	conversation, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil {
		return nil, err
	}

	// Verify user is participant
	if conversation.Participant1ID != userID && conversation.Participant2ID != userID {
		return nil, fmt.Errorf("user is not a participant in this conversation")
	}

	// Set other user
	if conversation.Participant1ID == userID {
		conversation.OtherUser = conversation.Participant2
		conversation.UnreadCount = conversation.UnreadCountP1
	} else {
		conversation.OtherUser = conversation.Participant1
		conversation.UnreadCount = conversation.UnreadCountP2
	}

	// Get presence - use WebSocket manager for real-time status
	if conversation.OtherUser != nil {
		// Check if user is currently connected via WebSocket
		isOnline := s.wsManager.IsUserConnected(conversation.OtherUser.ID)
		conversation.IsOnline = isOnline

		// Get last seen from cache if offline
		if !isOnline && s.cache != nil {
			_, lastSeen, _ := s.cache.GetUserPresence(ctx, conversation.OtherUser.ID)
			if !lastSeen.IsZero() {
				conversation.LastSeen = &lastSeen
			}
		}
	}

	return conversation, nil
}

// StartConversation creates or retrieves a conversation with another user
func (s *MessagingService) StartConversation(ctx context.Context, user1ID, user2ID uuid.UUID) (*models.Conversation, error) {
	conversation, err := s.repo.GetOrCreateConversation(ctx, user1ID, user2ID)
	if err != nil {
		return nil, err
	}

	// Set other user
	if conversation.Participant1ID == user1ID {
		conversation.OtherUser = conversation.Participant2
		conversation.UnreadCount = conversation.UnreadCountP1
	} else {
		conversation.OtherUser = conversation.Participant1
		conversation.UnreadCount = conversation.UnreadCountP2
	}

	// Invalidate cache
	if s.cache != nil {
		s.cache.InvalidateUserConversations(ctx, user1ID)
		s.cache.InvalidateUserConversations(ctx, user2ID)
	}

	return conversation, nil
}

// GetUnreadCount returns total unread message count
func (s *MessagingService) GetUnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	// Try cache first - only if cache is available
	if s.cache != nil {
		total, err := s.cache.GetTotalUnread(ctx, userID)
		if err == nil && total > 0 {
			return total, nil
		}
	}

	// Fall back to database
	return s.repo.GetUnreadCount(ctx, userID)
}

// ============================================
// MESSAGES
// ============================================

// SendMessage sends a new message in a conversation
func (s *MessagingService) SendMessage(ctx context.Context, conversationID, senderID uuid.UUID, req *models.MessageRequest) (*models.Message, error) {
	// Get conversation to find recipient
	conversation, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil {
		return nil, fmt.Errorf("conversation not found: %w", err)
	}

	// Verify sender is participant
	if conversation.Participant1ID != senderID && conversation.Participant2ID != senderID {
		return nil, fmt.Errorf("sender is not a participant in this conversation")
	}

	// Determine recipient
	var recipientID uuid.UUID
	if conversation.Participant1ID == senderID {
		recipientID = conversation.Participant2ID
	} else {
		recipientID = conversation.Participant1ID
	}

	// Create message - prioritize encrypted content over plaintext
	message := &models.Message{
		ConversationID: conversationID,
		SenderID:       senderID,
		MessageType:    req.MessageType,
		AttachmentURL:  req.AttachmentURL,
		AttachmentName: req.AttachmentName,
		AttachmentSize: req.AttachmentSize,
		AttachmentType: req.AttachmentType,
		ReplyToID:      req.ReplyToID,
		Status:         models.MessageStatusSent,
		CreatedAt:      time.Now(),
	}
	
	// Determine if message is encrypted or plaintext
	// Check for IV first (more reliable indicator of encryption)
	hasEncryptedContent := (req.IV != nil && *req.IV != "") || (req.EncryptedContent != nil && *req.EncryptedContent != "")
	
	if hasEncryptedContent {
		// E2EE encrypted message: content must be empty string (not NULL due to gorm:"not null")
		// Validate that encrypted content is actually provided
		if req.EncryptedContent == nil || *req.EncryptedContent == "" {
			return nil, fmt.Errorf("encrypted_content is required when IV is provided")
		}
		if req.IV == nil || *req.IV == "" {
			return nil, fmt.Errorf("IV is required for encrypted messages")
		}
		message.Content = ""
		message.EncryptedContent = req.EncryptedContent
		message.ContentIV = req.IV
		log.Printf("[Messaging] 🔐 Message sent with E2EE encryption (encrypted_content length: %d, IV length: %d)", 
			len(*req.EncryptedContent), len(*req.IV))
	} else {
		// Plaintext message: use content field
		// Allow empty content for file/image/video messages that have attachments
		hasAttachment := req.AttachmentURL != nil && *req.AttachmentURL != ""
		isMediaMessage := req.MessageType == models.MessageTypeFile || 
			req.MessageType == models.MessageTypeImage || 
			req.MessageType == models.MessageTypeVideo
		
		if req.Content == "" && !hasAttachment && !isMediaMessage {
			return nil, fmt.Errorf("message content cannot be empty")
		}
		message.Content = req.Content
		message.EncryptedContent = nil
		message.ContentIV = nil
		log.Printf("[Messaging] ⚠️ Message sent in PLAINTEXT (no E2EE), content length: %d", len(req.Content))
	}

	// Save to database
	if err := s.repo.CreateMessage(ctx, message); err != nil {
		return nil, fmt.Errorf("failed to create message: %w", err)
	}

	// Update sender's last seen (they're active sending messages)
	if s.cache != nil {
		s.cache.SetUserOnline(ctx, senderID)

		// Update cache
		s.cache.PrependMessage(ctx, message)
		s.cache.IncrementUnread(ctx, conversationID, recipientID)

		// Invalidate conversation list cache
		s.cache.InvalidateUserConversations(ctx, senderID)
		s.cache.InvalidateUserConversations(ctx, recipientID)
	}

	// CRITICAL: Broadcast to BOTH sender and recipient for real-time consistency
	// This ensures both clients see the message instantly, preventing ordering issues
	
	// Broadcast to recipient (IsMine = false)
	messageCopyForRecipient := *message
	messageCopyForRecipient.IsMine = false
	go s.broadcastNewMessage(recipientID, &messageCopyForRecipient)
	
	// ALSO broadcast to sender (IsMine = true) - ensures sender sees their own message via WebSocket too
	// This prevents the need for page reload and ensures consistency
	messageCopyForSender := *message
	messageCopyForSender.IsMine = true
	go s.broadcastNewMessage(senderID, &messageCopyForSender)

	// Set IsMine = true for sender (HTTP response)
	message.IsMine = true

	// Mark as delivered if recipient is online
	if s.wsManager.IsUserConnected(recipientID) {
		go s.markAsDelivered(ctx, message.ID)
	}

	// Create notification for recipient (async to not block)
	if s.notifService != nil {
		go s.createMessageNotification(recipientID, senderID, message)
	}

	log.Printf("[Messaging] Message %s sent from %s to %s in conversation %s",
		message.ID, senderID, recipientID, conversationID)

	return message, nil
}

// GetMessages retrieves messages for a conversation with caching
func (s *MessagingService) GetMessages(ctx context.Context, conversationID, userID uuid.UUID, limit, offset int) ([]*models.Message, error) {
	// Verify user is participant
	conversation, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil {
		return nil, err
	}

	if conversation.Participant1ID != userID && conversation.Participant2ID != userID {
		return nil, fmt.Errorf("user is not a participant in this conversation")
	}

	// Try cache for recent messages (offset = 0) - only if cache is available
	if offset == 0 && s.cache != nil {
		cached, err := s.cache.GetCachedMessages(ctx, conversationID, limit)
		if err == nil && cached != nil && len(cached) > 0 {
			log.Printf("[Messaging] Returning %d cached messages for conversation %s", len(cached), conversationID)

			// CRITICAL: Set IsMine field for cached messages
			for _, msg := range cached {
				msg.IsMine = msg.SenderID == userID
			}

			// Mark as read in background
			go s.markConversationAsRead(ctx, conversationID, userID)

			return cached, nil
		}
	}

	// Fetch from database
	messages, err := s.repo.GetConversationMessages(ctx, conversationID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get messages: %w", err)
	}

	// CRITICAL: Set IsMine field for ALL messages
	for _, msg := range messages {
		msg.IsMine = msg.SenderID == userID
	}

	// Cache if first page
	if offset == 0 && s.cache != nil {
		s.cache.CacheMessages(ctx, conversationID, messages)
	}

	// Mark as read in background
	go s.markConversationAsRead(ctx, conversationID, userID)

	return messages, nil
}

// MarkAsRead marks messages in a conversation as read
func (s *MessagingService) MarkAsRead(ctx context.Context, conversationID, userID uuid.UUID) error {
	// Update database
	if err := s.repo.MarkConversationAsRead(ctx, conversationID, userID); err != nil {
		return err
	}

	if err := s.repo.MarkMessagesAsRead(ctx, conversationID, userID); err != nil {
		return err
	}

	// Update user's last seen (they're active reading messages)
	if s.cache != nil {
		s.cache.SetUserOnline(ctx, userID)

		// Update cache
		s.cache.ResetUnread(ctx, conversationID, userID)
	}

	// Broadcast read receipt to sender
	conversation, _ := s.repo.GetConversation(ctx, conversationID)
	if conversation != nil {
		var otherUserID uuid.UUID
		if conversation.Participant1ID == userID {
			otherUserID = conversation.Participant2ID
		} else {
			otherUserID = conversation.Participant1ID
		}

		go s.broadcastReadReceipt(otherUserID, conversationID)
	}

	log.Printf("[Messaging] Messages marked as read for user %s in conversation %s", userID, conversationID)
	return nil
}

// DeleteMessage soft-deletes a message for a user
func (s *MessagingService) DeleteMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	// Get message first
	message, err := s.repo.GetMessage(ctx, messageID)
	if err != nil {
		return err
	}

	// Verify user is either sender or a participant
	conversation, err := s.repo.GetConversation(ctx, message.ConversationID)
	if err != nil {
		return err
	}

	isSender := message.SenderID == userID
	isParticipant := conversation.Participant1ID == userID || conversation.Participant2ID == userID

	if !isParticipant {
		return fmt.Errorf("user is not a participant in this conversation")
	}

	// Delete in database
	if err := s.repo.DeleteMessage(ctx, messageID, userID); err != nil {
		return err
	}

	// Invalidate cache
	s.cache.InvalidateConversationCache(ctx, message.ConversationID)

	// Broadcast deletion via WebSocket
	var otherUserID uuid.UUID
	if conversation.Participant1ID == userID {
		otherUserID = conversation.Participant2ID
	} else {
		otherUserID = conversation.Participant1ID
	}

	// If sender deleted (unsend), notify the other person
	if isSender {
		go s.broadcastMessageDeleted(otherUserID, message.ConversationID, messageID, true) // deleted for everyone
	}

	log.Printf("[Messaging] 🗑️ Message %s deleted for user %s (sender: %v)", messageID, userID, isSender)
	return nil
}

// SearchMessages searches messages by content
func (s *MessagingService) SearchMessages(ctx context.Context, userID uuid.UUID, query string, limit, offset int) ([]*models.Message, error) {
	messages, err := s.repo.SearchMessages(ctx, userID, query, limit, offset)
	if err != nil {
		return nil, err
	}

	// Set IsMine field for search results
	for _, msg := range messages {
		msg.IsMine = msg.SenderID == userID
	}

	return messages, nil
}

// ============================================
// TYPING INDICATORS
// ============================================

// StartTyping sets typing indicator for a user in a conversation
func (s *MessagingService) StartTyping(ctx context.Context, conversationID, userID uuid.UUID, isRecording bool) error {
	// Update database
	if err := s.repo.UpdateConversationTyping(ctx, conversationID, userID, true); err != nil {
		return err
	}

	// Update cache
	if s.cache != nil {
		s.cache.SetTyping(ctx, conversationID, userID)
	}

	// Get other user
	conversation, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil {
		return err
	}

	var otherUserID uuid.UUID
	if conversation.Participant1ID == userID {
		otherUserID = conversation.Participant2ID
	} else {
		otherUserID = conversation.Participant1ID
	}

	// Broadcast typing indicator with recording status
	go s.broadcastTyping(otherUserID, conversationID, userID, true, isRecording)

	return nil
}

// StopTyping removes typing indicator
func (s *MessagingService) StopTyping(ctx context.Context, conversationID, userID uuid.UUID) error {
	// Update database
	if err := s.repo.UpdateConversationTyping(ctx, conversationID, userID, false); err != nil {
		return err
	}

	// Update cache
	if s.cache != nil {
		s.cache.ClearTyping(ctx, conversationID, userID)
	}

	// Get other user
	conversation, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil {
		return err
	}

	var otherUserID uuid.UUID
	if conversation.Participant1ID == userID {
		otherUserID = conversation.Participant2ID
	} else {
		otherUserID = conversation.Participant1ID
	}

	// Broadcast stop typing (not recording)
	go s.broadcastTyping(otherUserID, conversationID, userID, false, false)

	return nil
}

// ============================================
// REACTIONS
// ============================================

// AddReaction adds an emoji reaction to a message (or toggles it off if already exists)
func (s *MessagingService) AddReaction(ctx context.Context, messageID, userID uuid.UUID, emoji string) (*models.MessageReaction, error) {
	reaction, err := s.repo.AddReaction(ctx, messageID, userID, emoji)
	if err != nil {
		return nil, err
	}

	// Get message to find conversation
	message, _ := s.repo.GetMessage(ctx, messageID)
	if message != nil {
		// Invalidate cache
		if s.cache != nil {
			s.cache.InvalidateConversationCache(ctx, message.ConversationID)
		}

		// Broadcast reaction to other user
		conversation, _ := s.repo.GetConversation(ctx, message.ConversationID)
		if conversation != nil {
			var otherUserID uuid.UUID
			if conversation.Participant1ID == userID {
				otherUserID = conversation.Participant2ID
			} else {
				otherUserID = conversation.Participant1ID
			}

			// If reaction is nil, it was toggled off (removed)
			if reaction == nil {
				log.Printf("[Messaging] Reaction %s toggled off (removed) from message %s by user %s", emoji, messageID, userID)
				go s.broadcastReactionRemoved(otherUserID, message.ConversationID, messageID, emoji)
			} else {
				log.Printf("[Messaging] Reaction %s added to message %s by user %s", emoji, messageID, userID)
				go s.broadcastReaction(otherUserID, message.ConversationID, messageID, reaction)
			}
		}
	}

	return reaction, nil
}

// RemoveReaction removes a reaction from a message
func (s *MessagingService) RemoveReaction(ctx context.Context, messageID, userID uuid.UUID) error {
	// Get message first
	message, err := s.repo.GetMessage(ctx, messageID)
	if err != nil {
		return err
	}

	// Remove reaction
	if err := s.repo.RemoveUserReaction(ctx, messageID, userID); err != nil {
		return err
	}

	// Invalidate cache
	s.cache.InvalidateConversationCache(ctx, message.ConversationID)

	log.Printf("[Messaging] Reaction removed from message %s by user %s", messageID, userID)
	return nil
}

// ============================================
// STARRED MESSAGES
// ============================================

// StarMessage stars a message for a user
func (s *MessagingService) StarMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	return s.repo.StarMessage(ctx, messageID, userID)
}

// UnstarMessage unstars a message
func (s *MessagingService) UnstarMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	return s.repo.UnstarMessage(ctx, messageID, userID)
}

// GetStarredMessages retrieves starred messages
func (s *MessagingService) GetStarredMessages(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.Message, error) {
	messages, err := s.repo.GetStarredMessages(ctx, userID, limit, offset)
	if err != nil {
		return nil, err
	}

	// Set IsMine field for starred messages
	for _, msg := range messages {
		msg.IsMine = msg.SenderID == userID
	}

	return messages, nil
}

// ============================================
// PRESENCE
// ============================================

// SetUserOnline marks a user as online
func (s *MessagingService) SetUserOnline(ctx context.Context, userID uuid.UUID) error {
	if s.cache != nil {
		return s.cache.SetUserOnline(ctx, userID)
	}
	return nil
}

// SetUserOffline marks a user as offline
func (s *MessagingService) SetUserOffline(ctx context.Context, userID uuid.UUID) error {
	if s.cache != nil {
		return s.cache.SetUserOffline(ctx, userID)
	}
	return nil
}

// GetUserPresence retrieves a user's presence status
func (s *MessagingService) GetUserPresence(ctx context.Context, userID uuid.UUID) (bool, time.Time, error) {
	if s.cache != nil {
		return s.cache.GetUserPresence(ctx, userID)
	}
	return false, time.Time{}, nil
}

// GetMultiplePresence retrieves presence for multiple users
func (s *MessagingService) GetMultiplePresence(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID]*models.PresenceInfo, error) {
	if s.cache != nil {
		return s.cache.GetMultiplePresence(ctx, userIDs)
	}
	return make(map[uuid.UUID]*models.PresenceInfo), nil
}

// ============================================
// WEBSOCKET HELPERS
// ============================================

func (s *MessagingService) broadcastNewMessage(recipientID uuid.UUID, message *models.Message) {
	// CRITICAL: Broadcast IMMEDIATELY via WebSocket for real-time delivery
	// Use message's actual timestamp for consistency (not current time)
	envelope := models.WSMessageEnvelope{
		ID:             message.ID.String(),
		Type:           models.WSMessageTypeNewMessage,
		Channel:        "messaging",
		ConversationID: &message.ConversationID,
		Data:           message,
		Timestamp:      message.CreatedAt.Unix(), // Use message timestamp for proper ordering
	}

	// Broadcast to recipient (non-blocking, instant)
	// Check if user is connected - if not, they'll get it on next connection via pending messages
	if s.wsManager.IsUserConnected(recipientID) {
		s.wsManager.BroadcastToUserWithData(recipientID, envelope)
		log.Printf("[Messaging] 📡 WebSocket broadcast sent to user %s for message %s", recipientID, message.ID)
	} else {
		log.Printf("[Messaging] ⚠️ User %s not connected, message will be delivered via pending sync", recipientID)
	}
}

func (s *MessagingService) createMessageNotification(recipientID, senderID uuid.UUID, message *models.Message) {
	ctx := context.Background()

	// Don't send notification if recipient is online (they see it via WebSocket)
	if s.wsManager.IsUserConnected(recipientID) {
		log.Printf("[Messaging] Skipping notification - recipient %s is online", recipientID)
		return
	}

	// Get sender info
	sender, err := s.userRepo.GetUserByID(ctx, senderID)
	if err != nil {
		log.Printf("[Messaging] Failed to get sender info for notification: %v", err)
		return
	}

	// Truncate message content for notification
	content := message.Content
	if len(content) > 50 {
		content = content[:50] + "..."
	}
	if content == "" {
		content = "[Media]" // For audio/image without text
	}

	messageStr := fmt.Sprintf("%s: %s", sender.DisplayName, content)
	actionURL := fmt.Sprintf("/messages?conversationId=%s", message.ConversationID)

	notification := &models.Notification{
		UserID:     recipientID,
		Type:       models.NotificationMessage,
		Category:   models.CategoryMessages,
		Title:      "New Message",
		Message:    &messageStr,
		ActorID:    &senderID,
		TargetID:   &message.ID,
		TargetType: stringPtr("message"),
		ActionURL:  &actionURL,
		Metadata: map[string]interface{}{
			"conversation_id": message.ConversationID.String(),
			"message_id":      message.ID.String(),
		},
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().AddDate(0, 0, 30), // Expire in 30 days
	}

	// Only create notification if notification service is available
	if s.notifService != nil {
		if err := s.notifService.CreateNotification(ctx, notification); err != nil {
			log.Printf("[Messaging] Failed to create message notification: %v", err)
		}
	} else {
		log.Printf("[Messaging] Notification service not available, skipping notification creation")
	}
}

func stringPtr(s string) *string {
	return &s
}

func (s *MessagingService) broadcastTyping(recipientID, conversationID, typerID uuid.UUID, isTyping bool, isRecording bool) {
	msgType := models.WSMessageTypeTyping
	if !isTyping {
		msgType = models.WSMessageTypeStopTyping
	}

	// Fetch typing user details
	typer, err := s.userRepo.GetUserByID(context.Background(), typerID)
	if err != nil {
		log.Printf("[MessagingService] broadcastTyping - Failed to fetch typer details: %v", err)
		return
	}

	envelope := models.WSMessageEnvelope{
		ID:             uuid.New().String(),
		Type:           msgType,
		Channel:        "messaging",
		ConversationID: &conversationID,
		Data: models.TypingInfo{
			ConversationID: conversationID,
			UserID:         typerID,
			DisplayName:    typer.DisplayName,
			IsTyping:       isTyping,
			IsRecording:    isRecording, // Now properly set!
		},
		Timestamp: time.Now().Unix(),
	}

	log.Printf("[MessagingService] Broadcasting typing: user=%s, typing=%v, recording=%v", typer.DisplayName, isTyping, isRecording)
	s.wsManager.BroadcastToUserWithData(recipientID, envelope)
}

func (s *MessagingService) broadcastReadReceipt(recipientID, conversationID uuid.UUID) {
	readAt := time.Now().Format(time.RFC3339)

	envelope := models.WSMessageEnvelope{
		ID:             uuid.New().String(),
		Type:           models.WSMessageTypeMessageRead,
		Channel:        "messaging",
		ConversationID: &conversationID,
		Data: map[string]interface{}{
			"conversation_id": conversationID.String(),
			"read_at":         readAt,
		},
		Timestamp: time.Now().Unix(),
	}

	s.wsManager.BroadcastToUserWithData(recipientID, envelope)
	log.Printf("[Messaging] 💙 Broadcasted read receipt for conversation %s to sender %s", conversationID, recipientID)
}

func (s *MessagingService) broadcastReaction(recipientID, conversationID, messageID uuid.UUID, reaction *models.MessageReaction) {
	envelope := models.WSMessageEnvelope{
		ID:             uuid.New().String(),
		Type:           models.WSMessageTypeReaction,
		Channel:        "messaging",
		ConversationID: &conversationID,
		Data: map[string]interface{}{
			"message_id": messageID,
			"reaction":   reaction,
		},
		Timestamp: time.Now().Unix(),
	}

	s.wsManager.BroadcastToUserWithData(recipientID, envelope)
	log.Printf("[Messaging] Broadcasted reaction to user %s for message %s", recipientID, messageID)
}

func (s *MessagingService) broadcastReactionRemoved(recipientID, conversationID, messageID uuid.UUID, emoji string) {
	envelope := models.WSMessageEnvelope{
		ID:             uuid.New().String(),
		Type:           "reaction_removed",
		Channel:        "messaging",
		ConversationID: &conversationID,
		Data: map[string]interface{}{
			"message_id": messageID,
			"emoji":      emoji,
		},
		Timestamp: time.Now().Unix(),
	}

	s.wsManager.BroadcastToUserWithData(recipientID, envelope)
	log.Printf("[Messaging] Broadcasted reaction removal to user %s for message %s", recipientID, messageID)
}

func (s *MessagingService) broadcastMessageDeleted(recipientID, conversationID, messageID uuid.UUID, deletedForEveryone bool) {
	envelope := models.WSMessageEnvelope{
		ID:             uuid.New().String(),
		Type:           models.WSMessageTypeMessageDeleted,
		Channel:        "messaging",
		ConversationID: &conversationID,
		Data: map[string]interface{}{
			"conversation_id":      conversationID.String(),
			"message_id":           messageID.String(),
			"deleted_for_everyone": deletedForEveryone,
		},
		Timestamp: time.Now().Unix(),
	}

	s.wsManager.BroadcastToUserWithData(recipientID, envelope)
	log.Printf("[Messaging] 🗑️ Broadcasted message_deleted for message %s to user %s", messageID, recipientID)
}

func (s *MessagingService) markAsDelivered(ctx context.Context, messageID uuid.UUID) {
	time.Sleep(100 * time.Millisecond) // Small delay to ensure message is received

	// Update status in database
	if err := s.repo.UpdateMessageStatus(ctx, messageID, models.MessageStatusDelivered); err != nil {
		log.Printf("[Messaging] Failed to mark message as delivered: %v", err)
		return
	}

	// Get message to find conversation and sender
	message, err := s.repo.GetMessage(ctx, messageID)
	if err != nil {
		log.Printf("[Messaging] Failed to get message for delivery broadcast: %v", err)
		return
	}

	deliveredAt := time.Now().Format(time.RFC3339)

	// Broadcast to sender (delivered status update)
	envelope := models.WSMessageEnvelope{
		ID:             messageID.String(),
		Type:           "message_delivered",
		Channel:        "messaging",
		ConversationID: &message.ConversationID,
		Data: map[string]interface{}{
			"message_id":      messageID.String(),
			"conversation_id": message.ConversationID.String(),
			"delivered_at":    deliveredAt,
		},
		Timestamp: time.Now().Unix(),
	}

	s.wsManager.BroadcastToUserWithData(message.SenderID, envelope)
	log.Printf("[Messaging] 📬 Broadcasted delivered status for message %s to sender %s", messageID, message.SenderID)
}

func (s *MessagingService) markConversationAsRead(ctx context.Context, conversationID, userID uuid.UUID) {
	s.MarkAsRead(ctx, conversationID, userID)
}

// ============================================
// PIN MESSAGES
// ============================================

// PinMessage pins a message in a conversation
func (s *MessagingService) PinMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	// Pin first (most critical operation)
	if err := s.repo.PinMessage(ctx, messageID, userID); err != nil {
		return err
	}

	// Everything else happens asynchronously for speed
	go func() {
		message, err := s.repo.GetMessage(context.Background(), messageID)
		if err != nil {
			log.Printf("[Messaging] Failed to get message for pin broadcast: %v", err)
			return
		}

		if s.cache != nil {
			s.cache.InvalidateConversationCache(context.Background(), message.ConversationID)
		}

		// Broadcast pin event to other user
		conversation, _ := s.repo.GetConversation(context.Background(), message.ConversationID)
		if conversation != nil {
			var otherUserID uuid.UUID
			if conversation.Participant1ID == userID {
				otherUserID = conversation.Participant2ID
			} else {
				otherUserID = conversation.Participant1ID
			}

			s.broadcastMessagePinned(otherUserID, message.ConversationID, messageID)
		}

		log.Printf("[Messaging] Message %s pinned by user %s", messageID, userID)
	}()

	return nil
}

// UnpinMessage unpins a message
func (s *MessagingService) UnpinMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	// Unpin first (most critical operation)
	if err := s.repo.UnpinMessage(ctx, messageID, userID); err != nil {
		return err
	}

	// Everything else happens asynchronously for speed
	go func() {
		message, err := s.repo.GetMessage(context.Background(), messageID)
		if err != nil {
			log.Printf("[Messaging] Failed to get message for unpin broadcast: %v", err)
			return
		}

		if s.cache != nil {
			s.cache.InvalidateConversationCache(context.Background(), message.ConversationID)
		}

		// Broadcast unpin event
		conversation, _ := s.repo.GetConversation(context.Background(), message.ConversationID)
		if conversation != nil {
			var otherUserID uuid.UUID
			if conversation.Participant1ID == userID {
				otherUserID = conversation.Participant2ID
			} else {
				otherUserID = conversation.Participant1ID
			}

			s.broadcastMessageUnpinned(otherUserID, message.ConversationID, messageID)
		}

		log.Printf("[Messaging] Message %s unpinned by user %s", messageID, userID)
	}()

	return nil
}

// GetPinnedMessages retrieves all pinned messages in a conversation
func (s *MessagingService) GetPinnedMessages(ctx context.Context, conversationID, userID uuid.UUID) ([]*models.Message, error) {
	messages, err := s.repo.GetPinnedMessages(ctx, conversationID)
	if err != nil {
		return nil, err
	}

	// Set IsMine flag (IsPinned is already set by repository based on pinned_at)
	for _, msg := range messages {
		msg.IsMine = msg.SenderID == userID
	}

	return messages, nil
}

// ============================================
// EDIT MESSAGES
// ============================================

// EditMessage updates the content of a message
func (s *MessagingService) EditMessage(ctx context.Context, messageID, userID uuid.UUID, newContent string) error {
	// Verify user owns the message
	message, err := s.repo.GetMessage(ctx, messageID)
	if err != nil {
		return err
	}

	if message.SenderID != userID {
		return fmt.Errorf("unauthorized: cannot edit another user's message")
	}

	conversationID := message.ConversationID

	// Edit the message
	if err := s.repo.EditMessage(ctx, messageID, newContent, userID); err != nil {
		return err
	}

	// Everything else happens asynchronously for speed
	go func() {
		s.cache.InvalidateConversationCache(context.Background(), conversationID)

		// Get updated message for broadcast
		updatedMsg, err := s.repo.GetMessage(context.Background(), messageID)
		if err != nil {
			log.Printf("[Messaging] Failed to get updated message: %v", err)
			return
		}

		// Broadcast edit event to other user
		conversation, _ := s.repo.GetConversation(context.Background(), conversationID)
		if conversation != nil {
			var otherUserID uuid.UUID
			if conversation.Participant1ID == userID {
				otherUserID = conversation.Participant2ID
			} else {
				otherUserID = conversation.Participant1ID
			}

			s.broadcastMessageEdited(otherUserID, conversationID, updatedMsg)
		}

		log.Printf("[Messaging] Message %s edited by user %s", messageID, userID)
	}()

	return nil
}

// GetMessageEditHistory retrieves the edit history for a message
func (s *MessagingService) GetMessageEditHistory(ctx context.Context, messageID, userID uuid.UUID) ([]map[string]interface{}, error) {
	// Verify user is part of the conversation
	message, err := s.repo.GetMessage(ctx, messageID)
	if err != nil {
		return nil, err
	}

	conversation, err := s.repo.GetConversation(ctx, message.ConversationID)
	if err != nil {
		return nil, err
	}

	if conversation.Participant1ID != userID && conversation.Participant2ID != userID {
		return nil, fmt.Errorf("unauthorized: not part of this conversation")
	}

	return s.repo.GetMessageEditHistory(ctx, messageID)
}

// ============================================
// FORWARD MESSAGES
// ============================================

// ForwardMessage forwards a message to another conversation
func (s *MessagingService) ForwardMessage(ctx context.Context, messageID, toConversationID, userID uuid.UUID) (*models.Message, error) {
	// Verify user has access to the original message
	originalMsg, err := s.repo.GetMessage(ctx, messageID)
	if err != nil {
		return nil, err
	}

	originalConv, err := s.repo.GetConversation(ctx, originalMsg.ConversationID)
	if err != nil {
		return nil, err
	}

	if originalConv.Participant1ID != userID && originalConv.Participant2ID != userID {
		return nil, fmt.Errorf("unauthorized: not part of original conversation")
	}

	// Verify user has access to target conversation
	targetConv, err := s.repo.GetConversation(ctx, toConversationID)
	if err != nil {
		return nil, err
	}

	if targetConv.Participant1ID != userID && targetConv.Participant2ID != userID {
		return nil, fmt.Errorf("unauthorized: not part of target conversation")
	}

	// Forward the message
	forwardedMsg, err := s.repo.ForwardMessage(ctx, messageID, toConversationID, userID)
	if err != nil {
		return nil, err
	}

	if s.cache != nil {
		s.cache.InvalidateConversationCache(ctx, toConversationID)
	}

	// Broadcast to the other participant in target conversation
	var otherUserID uuid.UUID
	if targetConv.Participant1ID == userID {
		otherUserID = targetConv.Participant2ID
	} else {
		otherUserID = targetConv.Participant1ID
	}

	// Mark as delivered immediately (before returning)
	if err := s.repo.UpdateMessageStatus(ctx, forwardedMsg.ID, models.MessageStatusDelivered); err != nil {
		log.Printf("[Messaging] Warning: Failed to mark forwarded message as delivered: %v", err)
	} else {
		// Refresh message to get updated delivered_at timestamp
		updatedMsg, err := s.repo.GetMessage(ctx, forwardedMsg.ID)
		if err == nil {
			forwardedMsg = updatedMsg
		}
	}

	// Broadcast new message
	go s.broadcastNewMessage(otherUserID, forwardedMsg)

	// Check if recipient is online, if not send notification
	if !s.wsManager.IsUserConnected(otherUserID) && s.notifService != nil {
		go s.createMessageNotification(otherUserID, userID, forwardedMsg)
	}

	log.Printf("[Messaging] Message %s forwarded to conversation %s by user %s", messageID, toConversationID, userID)
	forwardedMsg.IsMine = true
	return forwardedMsg, nil
}

// ============================================
// SEARCH IN CONVERSATION
// ============================================

// SearchConversationMessages searches messages within a specific conversation
func (s *MessagingService) SearchConversationMessages(ctx context.Context, conversationID, userID uuid.UUID, query string, limit, offset int) ([]*models.Message, error) {
	// Verify user is part of the conversation
	conversation, err := s.repo.GetConversation(ctx, conversationID)
	if err != nil {
		return nil, err
	}

	if conversation.Participant1ID != userID && conversation.Participant2ID != userID {
		return nil, fmt.Errorf("unauthorized: not part of this conversation")
	}

	messages, err := s.repo.SearchConversationMessages(ctx, conversationID, query, limit, offset)
	if err != nil {
		return nil, err
	}

	// Set IsMine flag
	for _, msg := range messages {
		msg.IsMine = msg.SenderID == userID
	}

	return messages, nil
}

// ============================================
// BROADCAST HELPERS FOR NEW FEATURES
// ============================================

func (s *MessagingService) broadcastMessagePinned(recipientID, conversationID, messageID uuid.UUID) {
	envelope := models.WSMessageEnvelope{
		ID:             uuid.New().String(),
		Type:           models.WSMessageTypeMessagePinned,
		Channel:        "messaging",
		ConversationID: &conversationID,
		Data: map[string]interface{}{
			"message_id": messageID,
		},
		Timestamp: time.Now().Unix(),
	}

	s.wsManager.BroadcastToUserWithData(recipientID, envelope)
	log.Printf("[Messaging] Broadcasted message pinned to user %s", recipientID)
}

func (s *MessagingService) broadcastMessageUnpinned(recipientID, conversationID, messageID uuid.UUID) {
	envelope := models.WSMessageEnvelope{
		ID:             uuid.New().String(),
		Type:           models.WSMessageTypeMessageUnpinned,
		Channel:        "messaging",
		ConversationID: &conversationID,
		Data: map[string]interface{}{
			"message_id": messageID,
		},
		Timestamp: time.Now().Unix(),
	}

	s.wsManager.BroadcastToUserWithData(recipientID, envelope)
	log.Printf("[Messaging] Broadcasted message unpinned to user %s", recipientID)
}

func (s *MessagingService) broadcastMessageEdited(recipientID, conversationID uuid.UUID, message *models.Message) {
	message.IsMine = false // For recipient
	envelope := models.WSMessageEnvelope{
		ID:             uuid.New().String(),
		Type:           models.WSMessageTypeMessageEdited,
		Channel:        "messaging",
		ConversationID: &conversationID,
		Data: map[string]interface{}{
			"message": message,
		},
		Timestamp: time.Now().Unix(),
	}

	s.wsManager.BroadcastToUserWithData(recipientID, envelope)
	log.Printf("[Messaging] Broadcasted message edited to user %s", recipientID)
}

// ============================================
// E2EE KEY EXCHANGE
// ============================================

// StorePublicKey stores a user's public key for a conversation (database-backed)
func (s *MessagingService) StorePublicKey(ctx context.Context, conversationID, userID uuid.UUID, publicKey string) error {
	if publicKey == "" {
		return fmt.Errorf("public key cannot be empty")
	}

	// Store in database (key version 1 for now, can be incremented for rotation)
	err := s.repo.StoreConversationKey(ctx, conversationID, userID, publicKey, 1)
	if err != nil {
		return fmt.Errorf("failed to store key in database: %w", err)
	}

	// Also cache in memory for fast access
	key := fmt.Sprintf("%s:%s", conversationID.String(), userID.String())
	s.publicKeys.Store(key, publicKey)

	log.Printf("[E2EE] ✅ Stored public key in database for conversation %s, user %s", conversationID, userID)
	return nil
}

// GetPublicKey retrieves a user's public key for a conversation (database-backed)
func (s *MessagingService) GetPublicKey(ctx context.Context, conversationID, userID uuid.UUID) (string, error) {
	// Try memory cache first
	key := fmt.Sprintf("%s:%s", conversationID.String(), userID.String())
	if value, ok := s.publicKeys.Load(key); ok {
		if publicKey, ok := value.(string); ok && publicKey != "" {
			log.Printf("[E2EE] ✅ Retrieved key from memory cache for conversation %s, user %s", conversationID, userID)
			return publicKey, nil
		}
	}

	// Fall back to database
	publicKey, err := s.repo.GetConversationKey(ctx, conversationID, userID)
	if err != nil {
		return "", fmt.Errorf("public key not found for conversation %s, user %s: %w", conversationID, userID, err)
	}

	// Cache in memory for next time
	s.publicKeys.Store(key, publicKey)
	log.Printf("[E2EE] ✅ Retrieved key from database and cached for conversation %s, user %s", conversationID, userID)

	return publicKey, nil
}

// GetMessageByID retrieves a single message by ID and verifies user has access
func (s *MessagingService) GetMessageByID(ctx context.Context, messageID, userID uuid.UUID) (*models.Message, error) {
	// Get message from repository
	message, err := s.repo.GetMessage(ctx, messageID)
	if err != nil {
		return nil, fmt.Errorf("message not found: %w", err)
	}

	// Verify user is a participant in the conversation
	conversation, err := s.repo.GetConversation(ctx, message.ConversationID)
	if err != nil {
		return nil, fmt.Errorf("conversation not found: %w", err)
	}

	if conversation.Participant1ID != userID && conversation.Participant2ID != userID {
		return nil, fmt.Errorf("user is not a participant in this conversation")
	}

	// Set IsMine field
	message.IsMine = message.SenderID == userID

	return message, nil
}

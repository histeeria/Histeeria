package repository

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// supabaseUser is a helper for unmarshaling Supabase User with string timestamps
type supabaseUser struct {
	ID             uuid.UUID `json:"id"`
	Email          string    `json:"email"`
	Username       string    `json:"username"`
	DisplayName    string    `json:"display_name"`
	ProfilePicture *string   `json:"profile_picture"`
	IsVerified     bool      `json:"is_verified"`
	IsActive       bool      `json:"is_active"`
	LastLoginAt    *string   `json:"last_login_at"`
	CreatedAt      string    `json:"created_at"`
	UpdatedAt      string    `json:"updated_at"`
}

func (su *supabaseUser) toUser() (*models.User, error) {
	if su == nil {
		return nil, nil
	}

	user := &models.User{
		ID:             su.ID,
		Email:          su.Email,
		Username:       su.Username,
		DisplayName:    su.DisplayName,
		ProfilePicture: su.ProfilePicture,
		IsVerified:     su.IsVerified,
		IsActive:       su.IsActive,
	}

	if su.LastLoginAt != nil && *su.LastLoginAt != "" {
		t, err := parseSupabaseTime(*su.LastLoginAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse last_login_at: %w", err)
		}
		user.LastLoginAt = &t
	}

	if su.CreatedAt != "" {
		t, err := parseSupabaseTime(su.CreatedAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse created_at: %w", err)
		}
		user.CreatedAt = t
	}

	if su.UpdatedAt != "" {
		t, err := parseSupabaseTime(su.UpdatedAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse updated_at: %w", err)
		}
		user.UpdatedAt = t
	}

	return user, nil
}

// supabaseMessage is a helper for unmarshaling Message with string timestamps
type supabaseMessage struct {
	ID               uuid.UUID          `json:"id"`
	ConversationID   uuid.UUID          `json:"conversation_id"`
	SenderID         uuid.UUID          `json:"sender_id"`
	Content          string             `json:"content"`
	EncryptedContent *string            `json:"encrypted_content"` // E2EE encrypted content
	ContentIV        *string            `json:"content_iv"`        // Initialization vector for decryption
	MessageType      models.MessageType `json:"message_type"`
	AttachmentURL    *string            `json:"attachment_url"`
	AttachmentName   *string            `json:"attachment_name"`
	AttachmentSize   *int               `json:"attachment_size"`
	AttachmentType   *string            `json:"attachment_type"`
	// Video-specific fields
	ThumbnailURL  *string              `json:"thumbnail_url"`
	VideoDuration *int                 `json:"video_duration"`
	VideoWidth    *int                 `json:"video_width"`
	VideoHeight   *int                 `json:"video_height"`
	Status        models.MessageStatus `json:"status"`
	DeliveredAt   *string              `json:"delivered_at"`
	ReadAt        *string              `json:"read_at"`
	DeletedBy     []string             `json:"deleted_by"`
	ReplyToID     *uuid.UUID           `json:"reply_to_id"`
	CreatedAt     string               `json:"created_at"`
	UpdatedAt     string               `json:"updated_at"`
	// Pin feature
	PinnedAt *string    `json:"pinned_at"`
	PinnedBy *uuid.UUID `json:"pinned_by"`
	// Edit feature
	EditedAt        *string `json:"edited_at"`
	EditCount       int     `json:"edit_count"`
	OriginalContent *string `json:"original_content"`
	// Forward feature
	ForwardedFromID *uuid.UUID `json:"forwarded_from_id"`
	IsForwarded     bool       `json:"is_forwarded"`
	// Relations
	Sender    *supabaseUser            `json:"sender"`
	ReplyTo   *supabaseMessage         `json:"reply_to"`
	Reactions []map[string]interface{} `json:"reactions"`
}

func (sm *supabaseMessage) toMessage() (*models.Message, error) {
	if sm == nil {
		return nil, nil
	}

	msg := &models.Message{
		ID:               sm.ID,
		ConversationID:   sm.ConversationID,
		SenderID:         sm.SenderID,
		Content:          sm.Content,
		EncryptedContent: sm.EncryptedContent, // E2EE encrypted content
		ContentIV:        sm.ContentIV,        // Initialization vector for decryption
		MessageType:      sm.MessageType,
		AttachmentURL:    sm.AttachmentURL,
		AttachmentName:   sm.AttachmentName,
		AttachmentSize:   sm.AttachmentSize,
		AttachmentType:   sm.AttachmentType,
		// Video-specific fields
		ThumbnailURL:  sm.ThumbnailURL,
		VideoDuration: sm.VideoDuration,
		VideoWidth:    sm.VideoWidth,
		VideoHeight:   sm.VideoHeight,
		Status:        sm.Status,
		ReplyToID:     sm.ReplyToID,
	}

	// Convert sender
	if sm.Sender != nil {
		sender, err := sm.Sender.toUser()
		if err != nil {
			return nil, fmt.Errorf("failed to parse sender: %w", err)
		}
		msg.Sender = sender
	}

	// Convert reply-to message
	if sm.ReplyTo != nil {
		replyTo, err := sm.ReplyTo.toMessage()
		if err != nil {
			return nil, fmt.Errorf("failed to parse reply_to: %w", err)
		}
		msg.ReplyToMessage = replyTo
	}

	// Parse timestamps
	if sm.DeliveredAt != nil && *sm.DeliveredAt != "" {
		t, err := parseSupabaseTime(*sm.DeliveredAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse delivered_at: %w", err)
		}
		msg.DeliveredAt = &t
	}

	if sm.ReadAt != nil && *sm.ReadAt != "" {
		t, err := parseSupabaseTime(*sm.ReadAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse read_at: %w", err)
		}
		msg.ReadAt = &t
	}

	if sm.CreatedAt != "" {
		t, err := parseSupabaseTime(sm.CreatedAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse created_at: %w", err)
		}
		msg.CreatedAt = t
	}

	if sm.UpdatedAt != "" {
		t, err := parseSupabaseTime(sm.UpdatedAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse updated_at: %w", err)
		}
		msg.UpdatedAt = t
	}

	// Parse pin timestamp
	if sm.PinnedAt != nil && *sm.PinnedAt != "" {
		t, err := parseSupabaseTime(*sm.PinnedAt)
		if err != nil {
			log.Printf("Warning: failed to parse pinned_at: %v", err)
		} else {
			msg.PinnedAt = &t
		}
	}

	// Parse edit timestamp
	if sm.EditedAt != nil && *sm.EditedAt != "" {
		t, err := parseSupabaseTime(*sm.EditedAt)
		if err != nil {
			log.Printf("Warning: failed to parse edited_at: %v", err)
		} else {
			msg.EditedAt = &t
		}
	}

	// Set other new fields
	msg.PinnedBy = sm.PinnedBy
	msg.EditCount = sm.EditCount
	msg.OriginalContent = sm.OriginalContent
	msg.ForwardedFromID = sm.ForwardedFromID
	msg.IsForwarded = sm.IsForwarded

	// Set IsPinned based on whether pinned_at is not null
	msg.IsPinned = msg.PinnedAt != nil

	return msg, nil
}

// supabaseConversation is a helper struct for unmarshaling Supabase timestamps
type supabaseConversation struct {
	ID                   uuid.UUID     `json:"id"`
	Participant1ID       uuid.UUID     `json:"participant1_id"`
	Participant2ID       uuid.UUID     `json:"participant2_id"`
	LastMessageContent   *string       `json:"last_message_content"`
	LastMessageEncrypted *string       `json:"last_message_encrypted"`
	LastMessageIV        *string       `json:"last_message_iv"`
	LastMessageSenderID  *uuid.UUID    `json:"last_message_sender_id"`
	LastMessageAt        *string       `json:"last_message_at"` // String to handle Supabase format
	UnreadCountP1        int           `json:"unread_count_p1"`
	UnreadCountP2        int           `json:"unread_count_p2"`
	P1Typing             bool          `json:"p1_typing"`
	P2Typing             bool          `json:"p2_typing"`
	P1TypingAt           *string       `json:"p1_typing_at"` // String to handle Supabase format
	P2TypingAt           *string       `json:"p2_typing_at"` // String to handle Supabase format
	CreatedAt            string        `json:"created_at"`   // String to handle Supabase format
	UpdatedAt            string        `json:"updated_at"`   // String to handle Supabase format
	Participant1         *supabaseUser `json:"participant1"`
	Participant2         *supabaseUser `json:"participant2"`
}

// parseSupabaseTime parses Supabase timestamp format (with or without timezone)
func parseSupabaseTime(s string) (time.Time, error) {
	if s == "" {
		return time.Time{}, nil
	}
	// Try RFC3339 first
	t, err := time.Parse(time.RFC3339, s)
	if err == nil {
		return t, nil
	}
	// Try without timezone (Supabase format)
	t, err = time.Parse("2006-01-02T15:04:05.999999", s)
	if err == nil {
		return t.UTC(), nil // Assume UTC
	}
	// Try without microseconds
	t, err = time.Parse("2006-01-02T15:04:05", s)
	if err == nil {
		return t.UTC(), nil
	}
	return time.Time{}, err
}

// toConversation converts supabaseConversation to models.Conversation
func (sc *supabaseConversation) toConversation() (*models.Conversation, error) {
	conv := &models.Conversation{
		ID:                   sc.ID,
		Participant1ID:       sc.Participant1ID,
		Participant2ID:       sc.Participant2ID,
		LastMessageContent:   sc.LastMessageContent,
		LastMessageEncrypted: sc.LastMessageEncrypted,
		LastMessageIV:        sc.LastMessageIV,
		LastMessageSenderID:  sc.LastMessageSenderID,
		UnreadCountP1:        sc.UnreadCountP1,
		UnreadCountP2:        sc.UnreadCountP2,
		P1Typing:             sc.P1Typing,
		P2Typing:             sc.P2Typing,
	}

	// Convert participant users
	if sc.Participant1 != nil {
		user1, err := sc.Participant1.toUser()
		if err != nil {
			return nil, fmt.Errorf("failed to parse participant1: %w", err)
		}
		conv.Participant1 = user1
	}

	if sc.Participant2 != nil {
		user2, err := sc.Participant2.toUser()
		if err != nil {
			return nil, fmt.Errorf("failed to parse participant2: %w", err)
		}
		conv.Participant2 = user2
	}

	// Parse timestamps
	if sc.LastMessageAt != nil && *sc.LastMessageAt != "" {
		t, err := parseSupabaseTime(*sc.LastMessageAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse last_message_at: %w", err)
		}
		conv.LastMessageAt = &t
	}

	if sc.P1TypingAt != nil && *sc.P1TypingAt != "" {
		t, err := parseSupabaseTime(*sc.P1TypingAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse p1_typing_at: %w", err)
		}
		conv.P1TypingAt = &t
	}

	if sc.P2TypingAt != nil && *sc.P2TypingAt != "" {
		t, err := parseSupabaseTime(*sc.P2TypingAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse p2_typing_at: %w", err)
		}
		conv.P2TypingAt = &t
	}

	if sc.CreatedAt != "" {
		t, err := parseSupabaseTime(sc.CreatedAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse created_at: %w", err)
		}
		conv.CreatedAt = t
	}

	if sc.UpdatedAt != "" {
		t, err := parseSupabaseTime(sc.UpdatedAt)
		if err != nil {
			return nil, fmt.Errorf("failed to parse updated_at: %w", err)
		}
		conv.UpdatedAt = t
	}

	return conv, nil
}

type supabaseMessageRepository struct {
	supabaseURL string
	apiKey      string
	httpClient  *http.Client
}

// NewSupabaseMessageRepository creates a new Supabase message repository using PostgREST
func NewSupabaseMessageRepository(supabaseURL, serviceKey string) (MessageRepository, error) {
	return &supabaseMessageRepository{
		supabaseURL: supabaseURL,
		apiKey:      serviceKey,
		httpClient:  &http.Client{Timeout: 30 * time.Second},
	}, nil
}

// Helper to build URLs
func (r *supabaseMessageRepository) conversationsURL(query url.Values) string {
	base := fmt.Sprintf("%s/rest/v1/conversations", r.supabaseURL)
	if len(query) > 0 {
		return fmt.Sprintf("%s?%s", base, query.Encode())
	}
	return base
}

func (r *supabaseMessageRepository) messagesURL(query url.Values) string {
	base := fmt.Sprintf("%s/rest/v1/messages", r.supabaseURL)
	if len(query) > 0 {
		return fmt.Sprintf("%s?%s", base, query.Encode())
	}
	return base
}

func (r *supabaseMessageRepository) reactionsURL(query url.Values) string {
	base := fmt.Sprintf("%s/rest/v1/message_reactions", r.supabaseURL)
	if len(query) > 0 {
		return fmt.Sprintf("%s?%s", base, query.Encode())
	}
	return base
}

func (r *supabaseMessageRepository) starredURL(query url.Values) string {
	base := fmt.Sprintf("%s/rest/v1/starred_messages", r.supabaseURL)
	if len(query) > 0 {
		return fmt.Sprintf("%s?%s", base, query.Encode())
	}
	return base
}

// Helper to set common headers
func (r *supabaseMessageRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

// ============================================
// CONVERSATIONS
// ============================================

// GetOrCreateConversation finds existing conversation or creates new one
func (r *supabaseMessageRepository) GetOrCreateConversation(ctx context.Context, user1ID, user2ID uuid.UUID) (*models.Conversation, error) {
	// Try to find existing conversation (check both directions)
	query := url.Values{}
	query.Set("or", fmt.Sprintf("(and(participant1_id.eq.%s,participant2_id.eq.%s),and(participant1_id.eq.%s,participant2_id.eq.%s))",
		user1ID, user2ID, user2ID, user1ID))
	query.Set("select", "*,participant1:participant1_id(*),participant2:participant2_id(*)")
	query.Set("limit", "1")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.conversationsURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var sbConversations []supabaseConversation
	if err := json.NewDecoder(resp.Body).Decode(&sbConversations); err != nil {
		return nil, err
	}

	if len(sbConversations) > 0 {
		// Convert and set other user
		conv, err := sbConversations[0].toConversation()
		if err != nil {
			return nil, err
		}
		if conv.Participant1ID == user1ID {
			conv.OtherUser = conv.Participant2
		} else {
			conv.OtherUser = conv.Participant1
		}
		return conv, nil
	}

	// Create new conversation
	newConv := map[string]interface{}{
		"participant1_id": user1ID.String(),
		"participant2_id": user2ID.String(),
	}

	payload, _ := json.Marshal(newConv)
	req, _ = http.NewRequestWithContext(ctx, http.MethodPost, r.conversationsURL(nil), bytes.NewReader(payload))
	r.setHeaders(req, "return=representation")

	resp, err = r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var created []supabaseConversation
	if err := json.NewDecoder(resp.Body).Decode(&created); err != nil {
		return nil, err
	}

	if len(created) == 0 {
		return nil, fmt.Errorf("failed to create conversation")
	}

	return created[0].toConversation()
}

// GetConversation retrieves a conversation by ID
func (r *supabaseMessageRepository) GetConversation(ctx context.Context, conversationID uuid.UUID) (*models.Conversation, error) {
	query := url.Values{}
	query.Set("id", "eq."+conversationID.String())
	query.Set("select", "*,participant1:participant1_id(*),participant2:participant2_id(*)")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.conversationsURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var sbConversations []supabaseConversation
	if err := json.NewDecoder(resp.Body).Decode(&sbConversations); err != nil {
		return nil, err
	}

	if len(sbConversations) == 0 {
		return nil, fmt.Errorf("conversation not found")
	}

	return sbConversations[0].toConversation()
}

// GetUserConversations retrieves all conversations for a user
func (r *supabaseMessageRepository) GetUserConversations(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.Conversation, error) {
	query := url.Values{}
	// Filter: user is participant AND has at least one message (Instagram-style)
	query.Set("or", fmt.Sprintf("(participant1_id.eq.%s,participant2_id.eq.%s)", userID, userID))
	query.Set("last_message_at", "not.is.null") // Only conversations with messages
	query.Set("select", "*,participant1:participant1_id(*),participant2:participant2_id(*)")
	query.Set("order", "last_message_at.desc.nullslast,created_at.desc")
	query.Set("limit", fmt.Sprintf("%d", limit))
	query.Set("offset", fmt.Sprintf("%d", offset))

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.conversationsURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var sbConversations []supabaseConversation
	if err := json.NewDecoder(resp.Body).Decode(&sbConversations); err != nil {
		return nil, err
	}

	// Convert and set OtherUser and UnreadCount for each conversation
	conversations := make([]*models.Conversation, 0, len(sbConversations))
	for _, sbConv := range sbConversations {
		conv, err := sbConv.toConversation()
		if err != nil {
			log.Printf("Failed to convert conversation: %v", err)
			continue
		}

		if conv.Participant1ID == userID {
			conv.OtherUser = conv.Participant2
			conv.UnreadCount = conv.UnreadCountP1

			// CRITICAL FIX: Check if typing state is stale (older than 3 seconds)
			// Don't use database typing - it persists forever!
			if conv.P2Typing && conv.P2TypingAt != nil {
				elapsed := time.Since(*conv.P2TypingAt).Seconds()
				if elapsed < 3 {
					conv.IsTyping = true // Only show if recent (< 3 seconds)
				} else {
					conv.IsTyping = false // Stale typing state - ignore!
					log.Printf("[GetUserConversations] Ignoring stale typing state (%.1fs old)", elapsed)
				}
			} else {
				conv.IsTyping = false
			}
		} else {
			conv.OtherUser = conv.Participant1
			conv.UnreadCount = conv.UnreadCountP2

			// CRITICAL FIX: Check if typing state is stale (older than 3 seconds)
			if conv.P1Typing && conv.P1TypingAt != nil {
				elapsed := time.Since(*conv.P1TypingAt).Seconds()
				if elapsed < 3 {
					conv.IsTyping = true // Only show if recent (< 3 seconds)
				} else {
					conv.IsTyping = false // Stale typing state - ignore!
					log.Printf("[GetUserConversations] Ignoring stale typing state (%.1fs old)", elapsed)
				}
			} else {
				conv.IsTyping = false
			}
		}
		conversations = append(conversations, conv)
	}

	return conversations, nil
}

// UpdateConversationTyping updates typing indicator
func (r *supabaseMessageRepository) UpdateConversationTyping(ctx context.Context, conversationID, userID uuid.UUID, isTyping bool) error {
	// First get conversation to determine which participant
	conv, err := r.GetConversation(ctx, conversationID)
	if err != nil {
		return err
	}

	updates := make(map[string]interface{})
	now := time.Now().Format(time.RFC3339)

	if conv.Participant1ID == userID {
		updates["p1_typing"] = isTyping
		if isTyping {
			updates["p1_typing_at"] = now
		}
	} else {
		updates["p2_typing"] = isTyping
		if isTyping {
			updates["p2_typing_at"] = now
		}
	}

	payload, _ := json.Marshal(updates)
	query := url.Values{}
	query.Set("id", "eq."+conversationID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.conversationsURL(query), bytes.NewReader(payload))
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}

// MarkConversationAsRead resets unread count for a user
func (r *supabaseMessageRepository) MarkConversationAsRead(ctx context.Context, conversationID, userID uuid.UUID) error {
	conv, err := r.GetConversation(ctx, conversationID)
	if err != nil {
		return err
	}

	updates := make(map[string]interface{})
	if conv.Participant1ID == userID {
		updates["unread_count_p1"] = 0
	} else {
		updates["unread_count_p2"] = 0
	}

	payload, _ := json.Marshal(updates)
	query := url.Values{}
	query.Set("id", "eq."+conversationID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.conversationsURL(query), bytes.NewReader(payload))
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}

// DeleteConversation soft-deletes a conversation
func (r *supabaseMessageRepository) DeleteConversation(ctx context.Context, conversationID, userID uuid.UUID) error {
	// Note: Soft delete by adding user to deleted_by array would require RPC function
	// For now, just return nil (implement in Phase 2)
	log.Printf("[MessageRepo] DeleteConversation not yet implemented")
	return nil
}

// GetUnreadCount returns total unread count for a user
func (r *supabaseMessageRepository) GetUnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	// Use RPC function from migration
	rpcURL := fmt.Sprintf("%s/rest/v1/rpc/get_user_total_unread_count", r.supabaseURL)

	payload := map[string]interface{}{
		"user_uuid": userID.String(),
	}

	body, _ := json.Marshal(payload)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, rpcURL, bytes.NewReader(body))
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	var count int
	if err := json.NewDecoder(resp.Body).Decode(&count); err != nil {
		return 0, err
	}

	return count, nil
}

// ============================================
// MESSAGES
// ============================================

// CreateMessage creates a new message
func (r *supabaseMessageRepository) CreateMessage(ctx context.Context, message *models.Message) error {
	// Determine if message is encrypted
	isEncrypted := message.EncryptedContent != nil && *message.EncryptedContent != ""

	payload := map[string]interface{}{
		"conversation_id": message.ConversationID.String(),
		"sender_id":       message.SenderID.String(),
		"message_type":    string(message.MessageType),
		"status":          string(message.Status),
	}

	// Handle content based on encryption status
	// For encrypted messages, content MUST be empty string (not NULL) to satisfy constraint
	// For plaintext messages, content must be non-empty
	if isEncrypted {
		// Encrypted message: explicitly set content to empty string
		payload["content"] = ""
	} else {
		// Plaintext message: use the provided content
		payload["content"] = message.Content
	}

	// E2EE encrypted content fields
	if isEncrypted {
		payload["encrypted_content"] = *message.EncryptedContent
		if message.ContentIV != nil && *message.ContentIV != "" {
			payload["content_iv"] = *message.ContentIV
		}
	}

	if message.AttachmentURL != nil {
		payload["attachment_url"] = *message.AttachmentURL
	}
	if message.AttachmentName != nil {
		payload["attachment_name"] = *message.AttachmentName
	}
	if message.AttachmentSize != nil {
		payload["attachment_size"] = *message.AttachmentSize
	}
	if message.AttachmentType != nil {
		payload["attachment_type"] = *message.AttachmentType
	}
	if message.ReplyToID != nil {
		payload["reply_to_id"] = message.ReplyToID.String()
	}

	// Forward feature
	if message.ForwardedFromID != nil {
		payload["forwarded_from_id"] = message.ForwardedFromID.String()
		payload["is_forwarded"] = true
	}
	if message.IsForwarded {
		payload["is_forwarded"] = true
	}

	body, _ := json.Marshal(payload)

	// Request with full reply_to data populated
	query := url.Values{}
	query.Set("select", "*,sender:sender_id(id,username,display_name,profile_picture),reply_to:reply_to_id(id,content,message_type,sender_id,sender:sender_id(id,username,display_name,profile_picture))")

	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.messagesURL(query), bytes.NewReader(body))
	r.setHeaders(req, "return=representation")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to create message: %s", string(body))
	}

	var created []supabaseMessage
	if err := json.NewDecoder(resp.Body).Decode(&created); err != nil {
		return err
	}

	if len(created) > 0 {
		convertedMsg, err := created[0].toMessage()
		if err != nil {
			return fmt.Errorf("failed to convert created message: %w", err)
		}
		// Update the message with full data including reply_to
		*message = *convertedMsg
		log.Printf("[MessageRepo] Created message with reply_to: %v", message.ReplyToMessage != nil)
	}

	return nil
}

// GetMessage retrieves a single message
func (r *supabaseMessageRepository) GetMessage(ctx context.Context, messageID uuid.UUID) (*models.Message, error) {
	query := url.Values{}
	query.Set("id", "eq."+messageID.String())
	query.Set("select", "*,sender:sender_id(id,username,display_name,profile_picture),reply_to:reply_to_id(id,content,message_type,sender_id,sender:sender_id(id,username,display_name,profile_picture)),reactions:message_reactions(*,user:user_id(id,username,display_name,profile_picture))")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.messagesURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var sbMessages []supabaseMessage
	if err := json.NewDecoder(resp.Body).Decode(&sbMessages); err != nil {
		return nil, err
	}

	if len(sbMessages) == 0 {
		return nil, fmt.Errorf("message not found")
	}

	return sbMessages[0].toMessage()
}

// GetConversationMessages retrieves messages for a conversation (paginated)
func (r *supabaseMessageRepository) GetConversationMessages(ctx context.Context, conversationID uuid.UUID, limit, offset int) ([]*models.Message, error) {
	query := url.Values{}
	query.Set("conversation_id", "eq."+conversationID.String())
	query.Set("select", "*,sender:sender_id(id,username,display_name,profile_picture),reply_to:reply_to_id(id,content,message_type,sender_id,sender:sender_id(id,username,display_name,profile_picture)),reactions:message_reactions(*,user:user_id(id,username,display_name,profile_picture))")
	query.Set("order", "created_at.desc") // Descending order (newest first) - client will reverse for display
	query.Set("limit", fmt.Sprintf("%d", limit))
	query.Set("offset", fmt.Sprintf("%d", offset))

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.messagesURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var sbMessages []*supabaseMessage
	if err := json.NewDecoder(resp.Body).Decode(&sbMessages); err != nil {
		return nil, err
	}

	// Convert messages
	messages := make([]*models.Message, 0, len(sbMessages))
	for _, sbMsg := range sbMessages {
		msg, err := sbMsg.toMessage()
		if err != nil {
			log.Printf("Failed to convert message: %v", err)
			continue
		}
		messages = append(messages, msg)
	}

	// Already in ascending order (oldest first) from database query
	// No need to reverse anymore
	log.Printf("[MessageRepo] Returning %d messages in chronological order (oldest first)", len(messages))

	return messages, nil
}

// UpdateMessageStatus updates message status
func (r *supabaseMessageRepository) UpdateMessageStatus(ctx context.Context, messageID uuid.UUID, status models.MessageStatus) error {
	updates := map[string]interface{}{
		"status":     string(status),
		"updated_at": time.Now().Format(time.RFC3339),
	}

	if status == models.MessageStatusDelivered {
		updates["delivered_at"] = time.Now().Format(time.RFC3339)
	} else if status == models.MessageStatusRead {
		updates["read_at"] = time.Now().Format(time.RFC3339)
	}

	payload, _ := json.Marshal(updates)
	query := url.Values{}
	query.Set("id", "eq."+messageID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.messagesURL(query), bytes.NewReader(payload))
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}

// MarkMessagesAsRead marks all unread messages in a conversation as read
func (r *supabaseMessageRepository) MarkMessagesAsRead(ctx context.Context, conversationID, readerID uuid.UUID) error {
	updates := map[string]interface{}{
		"status":     string(models.MessageStatusRead),
		"read_at":    time.Now().Format(time.RFC3339),
		"updated_at": time.Now().Format(time.RFC3339),
	}

	payload, _ := json.Marshal(updates)
	query := url.Values{}
	query.Set("conversation_id", "eq."+conversationID.String())
	query.Set("sender_id", "neq."+readerID.String())
	query.Set("status", "neq.read")

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.messagesURL(query), bytes.NewReader(payload))
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}

// DeleteMessage soft-deletes a message for a user
func (r *supabaseMessageRepository) DeleteMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	// Note: Soft delete requires RPC function or array manipulation
	// For Phase 1, mark implementation as TODO
	log.Printf("[MessageRepo] DeleteMessage not yet fully implemented")
	return nil
}

// SearchMessages searches messages by content
func (r *supabaseMessageRepository) SearchMessages(ctx context.Context, userID uuid.UUID, searchQuery string, limit, offset int) ([]*models.Message, error) {
	// Note: Full-text search requires RPC function or advanced PostgREST features
	// For Phase 1, return empty results
	log.Printf("[MessageRepo] SearchMessages not yet implemented")
	return []*models.Message{}, nil
}

// ============================================
// REACTIONS
// ============================================

// AddReaction adds an emoji reaction to a message
func (r *supabaseMessageRepository) AddReaction(ctx context.Context, messageID, userID uuid.UUID, emoji string) (*models.MessageReaction, error) {
	payload := map[string]interface{}{
		"message_id": messageID.String(),
		"user_id":    userID.String(),
		"emoji":      emoji,
	}

	body, _ := json.Marshal(payload)

	// Include user data in the response
	query := url.Values{}
	query.Set("select", "*,user:user_id(id,username,display_name,profile_picture)")

	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.reactionsURL(query), bytes.NewReader(body))
	r.setHeaders(req, "return=representation,resolution=merge-duplicates")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	// Log response details
	bodyBytes, _ := io.ReadAll(resp.Body)
	log.Printf("[MessageRepo] AddReaction response - Status: %d, Body: %s", resp.StatusCode, string(bodyBytes))

	// Handle 409 Conflict (reaction already exists) - toggle it off
	if resp.StatusCode == http.StatusConflict {
		log.Printf("[MessageRepo] Reaction already exists, removing it (toggle behavior)")
		if err := r.RemoveUserReaction(ctx, messageID, userID); err != nil {
			return nil, fmt.Errorf("failed to remove existing reaction: %w", err)
		}
		// Return nil to indicate successful toggle (removal)
		return nil, nil
	}

	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to add reaction (status %d): %s", resp.StatusCode, string(bodyBytes))
	}

	// Re-read body for decoding - use helper struct for timestamp parsing
	bodyReader := bytes.NewReader(bodyBytes)

	// Helper struct to handle Supabase timestamp format
	type supabaseReaction struct {
		ID        uuid.UUID     `json:"id"`
		MessageID uuid.UUID     `json:"message_id"`
		UserID    uuid.UUID     `json:"user_id"`
		Emoji     string        `json:"emoji"`
		CreatedAt string        `json:"created_at"` // String to parse manually
		User      *supabaseUser `json:"user,omitempty"`
	}

	var supabaseReactions []supabaseReaction
	if err := json.NewDecoder(bodyReader).Decode(&supabaseReactions); err != nil {
		log.Printf("[MessageRepo] Failed to decode reaction response: %v, Body: %s", err, string(bodyBytes))
		return nil, fmt.Errorf("failed to decode reaction: %v", err)
	}

	if len(supabaseReactions) == 0 {
		return nil, fmt.Errorf("failed to create reaction - empty response")
	}

	// Convert to models.MessageReaction
	sbReaction := supabaseReactions[0]
	reaction := &models.MessageReaction{
		ID:        sbReaction.ID,
		MessageID: sbReaction.MessageID,
		UserID:    sbReaction.UserID,
		Emoji:     sbReaction.Emoji,
	}

	// Parse timestamp
	if sbReaction.CreatedAt != "" {
		createdAt, err := parseSupabaseTime(sbReaction.CreatedAt)
		if err != nil {
			log.Printf("[MessageRepo] Warning: Failed to parse created_at, using now: %v", err)
			createdAt = time.Now()
		}
		reaction.CreatedAt = createdAt
	}

	// Convert user if present
	if sbReaction.User != nil {
		user, err := sbReaction.User.toUser()
		if err == nil {
			reaction.User = user
		}
	}

	log.Printf("[MessageRepo] ✅ Reaction added successfully: %s", emoji)
	return reaction, nil
}

// RemoveReaction removes a reaction by ID
func (r *supabaseMessageRepository) RemoveReaction(ctx context.Context, reactionID uuid.UUID) error {
	query := url.Values{}
	query.Set("id", "eq."+reactionID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.reactionsURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}

// RemoveUserReaction removes a user's reaction from a message
func (r *supabaseMessageRepository) RemoveUserReaction(ctx context.Context, messageID, userID uuid.UUID) error {
	query := url.Values{}
	query.Set("message_id", "eq."+messageID.String())
	query.Set("user_id", "eq."+userID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.reactionsURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}

// GetMessageReactions retrieves all reactions for a message
func (r *supabaseMessageRepository) GetMessageReactions(ctx context.Context, messageID uuid.UUID) ([]*models.MessageReaction, error) {
	query := url.Values{}
	query.Set("message_id", "eq."+messageID.String())
	query.Set("select", "*,user:user_id(*)")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.reactionsURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var reactions []*models.MessageReaction
	if err := json.NewDecoder(resp.Body).Decode(&reactions); err != nil {
		return nil, err
	}

	return reactions, nil
}

// ============================================
// STARRED MESSAGES
// ============================================

// StarMessage stars a message for a user
func (r *supabaseMessageRepository) StarMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	payload := map[string]interface{}{
		"user_id":    userID.String(),
		"message_id": messageID.String(),
	}

	body, _ := json.Marshal(payload)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.starredURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "resolution=ignore-duplicates")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}

// UnstarMessage removes star from a message
func (r *supabaseMessageRepository) UnstarMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	query := url.Values{}
	query.Set("user_id", "eq."+userID.String())
	query.Set("message_id", "eq."+messageID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.starredURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	return nil
}

// GetStarredMessages retrieves all starred messages for a user
func (r *supabaseMessageRepository) GetStarredMessages(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.Message, error) {
	query := url.Values{}
	query.Set("user_id", "eq."+userID.String())
	query.Set("select", "message:message_id(*,sender:sender_id(*),reply_to:reply_to_id(*),reactions:message_reactions(*))")
	query.Set("order", "starred_at.desc")
	query.Set("limit", fmt.Sprintf("%d", limit))
	query.Set("offset", fmt.Sprintf("%d", offset))

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.starredURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var starred []struct {
		Message *supabaseMessage `json:"message"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&starred); err != nil {
		return nil, err
	}

	messages := make([]*models.Message, 0, len(starred))
	for _, s := range starred {
		if s.Message != nil {
			msg, err := s.Message.toMessage()
			if err != nil {
				log.Printf("Failed to convert starred message: %v", err)
				continue
			}
			msg.IsStarred = true
			messages = append(messages, msg)
		}
	}

	return messages, nil
}

// IsMessageStarred checks if a message is starred by a user
func (r *supabaseMessageRepository) IsMessageStarred(ctx context.Context, messageID, userID uuid.UUID) (bool, error) {
	query := url.Values{}
	query.Set("user_id", "eq."+userID.String())
	query.Set("message_id", "eq."+messageID.String())
	query.Set("select", "id")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.starredURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	var results []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return false, err
	}

	return len(results) > 0, nil
}

// ============================================
// PIN MESSAGES
// ============================================

// PinMessage pins a message in a conversation
func (r *supabaseMessageRepository) PinMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	now := time.Now().Format(time.RFC3339)
	updates := map[string]interface{}{
		"pinned_at": now,
		"pinned_by": userID.String(),
	}

	payload, _ := json.Marshal(updates)
	query := url.Values{}
	query.Set("id", "eq."+messageID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.messagesURL(query), bytes.NewReader(payload))
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("failed to pin message, status: %d", resp.StatusCode)
	}

	log.Printf("[MessageRepo] ✅ Message %s pinned", messageID)
	return nil
}

// UnpinMessage unpins a message
func (r *supabaseMessageRepository) UnpinMessage(ctx context.Context, messageID, userID uuid.UUID) error {
	updates := map[string]interface{}{
		"pinned_at": nil,
		"pinned_by": nil,
	}

	payload, _ := json.Marshal(updates)
	query := url.Values{}
	query.Set("id", "eq."+messageID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.messagesURL(query), bytes.NewReader(payload))
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("failed to unpin message, status: %d", resp.StatusCode)
	}

	log.Printf("[MessageRepo] ✅ Message %s unpinned", messageID)
	return nil
}

// GetPinnedMessages retrieves all pinned messages in a conversation
func (r *supabaseMessageRepository) GetPinnedMessages(ctx context.Context, conversationID uuid.UUID) ([]*models.Message, error) {
	query := url.Values{}
	query.Set("conversation_id", "eq."+conversationID.String())
	query.Set("pinned_at", "not.is.null")
	query.Set("select", "*,sender:sender_id(id,username,display_name,profile_picture),reply_to:reply_to_id(id,content,message_type,sender_id,sender:sender_id(id,username,display_name,profile_picture)),reactions:message_reactions(*,user:user_id(id,username,display_name,profile_picture))")
	query.Set("order", "pinned_at.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.messagesURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var sbMessages []*supabaseMessage
	if err := json.NewDecoder(resp.Body).Decode(&sbMessages); err != nil {
		return nil, err
	}

	messages := make([]*models.Message, 0, len(sbMessages))
	for _, sbMsg := range sbMessages {
		msg, err := sbMsg.toMessage()
		if err != nil {
			log.Printf("Failed to convert message: %v", err)
			continue
		}
		// IsPinned is already set in toMessage() based on pinned_at != nil
		messages = append(messages, msg)
	}

	return messages, nil
}

// ============================================
// EDIT MESSAGES
// ============================================

// EditMessage updates the content of a message
func (r *supabaseMessageRepository) EditMessage(ctx context.Context, messageID uuid.UUID, newContent string, editorID uuid.UUID) error {
	// First, get the original message to save its content to history
	originalMsg, err := r.GetMessage(ctx, messageID)
	if err != nil {
		return fmt.Errorf("failed to get original message: %w", err)
	}

	// Save edit history
	historyPayload := map[string]interface{}{
		"message_id":       messageID.String(),
		"previous_content": originalMsg.Content,
		"edited_by":        editorID.String(),
		"edited_at":        time.Now().Format(time.RFC3339),
	}

	historyBody, _ := json.Marshal(historyPayload)
	historyReq, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.editHistoryURL(nil), bytes.NewReader(historyBody))
	r.setHeaders(historyReq, "")

	historyResp, err := r.httpClient.Do(historyReq)
	if err != nil {
		log.Printf("[MessageRepo] Warning: Failed to save edit history: %v", err)
	} else {
		historyResp.Body.Close()
	}

	// Update the message
	now := time.Now().Format(time.RFC3339)
	updates := map[string]interface{}{
		"content":    newContent,
		"edited_at":  now,
		"edit_count": originalMsg.EditCount + 1,
	}

	// Store original content if this is the first edit
	if originalMsg.EditCount == 0 {
		updates["original_content"] = originalMsg.Content
	}

	payload, _ := json.Marshal(updates)
	query := url.Values{}
	query.Set("id", "eq."+messageID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.messagesURL(query), bytes.NewReader(payload))
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("failed to edit message, status: %d", resp.StatusCode)
	}

	log.Printf("[MessageRepo] ✅ Message %s edited (edit count: %d)", messageID, originalMsg.EditCount+1)
	return nil
}

// GetMessageEditHistory retrieves the edit history for a message
func (r *supabaseMessageRepository) GetMessageEditHistory(ctx context.Context, messageID uuid.UUID) ([]map[string]interface{}, error) {
	query := url.Values{}
	query.Set("message_id", "eq."+messageID.String())
	query.Set("order", "edited_at.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.editHistoryURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var history []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&history); err != nil {
		return nil, err
	}

	return history, nil
}

// ============================================
// FORWARD MESSAGES
// ============================================

// ForwardMessage creates a forwarded copy of a message in another conversation
func (r *supabaseMessageRepository) ForwardMessage(ctx context.Context, messageID uuid.UUID, toConversationID uuid.UUID, forwarderID uuid.UUID) (*models.Message, error) {
	// Get the original message
	originalMsg, err := r.GetMessage(ctx, messageID)
	if err != nil {
		return nil, fmt.Errorf("failed to get original message: %w", err)
	}

	// Create new message with forwarded flag
	newMsg := &models.Message{
		ConversationID:  toConversationID,
		SenderID:        forwarderID,
		Content:         originalMsg.Content,
		MessageType:     originalMsg.MessageType,
		AttachmentURL:   originalMsg.AttachmentURL,
		AttachmentName:  originalMsg.AttachmentName,
		AttachmentSize:  originalMsg.AttachmentSize,
		AttachmentType:  originalMsg.AttachmentType,
		ForwardedFromID: &messageID,
		IsForwarded:     true,
		Status:          models.MessageStatusSent,
	}

	// Create the forwarded message
	if err := r.CreateMessage(ctx, newMsg); err != nil {
		return nil, fmt.Errorf("failed to create forwarded message: %w", err)
	}

	log.Printf("[MessageRepo] ✅ Message %s forwarded to conversation %s", messageID, toConversationID)
	return newMsg, nil
}

// ============================================
// SEARCH MESSAGES IN CONVERSATION
// ============================================

// SearchConversationMessages searches messages within a specific conversation
func (r *supabaseMessageRepository) SearchConversationMessages(ctx context.Context, conversationID uuid.UUID, searchQuery string, limit, offset int) ([]*models.Message, error) {
	query := url.Values{}
	query.Set("conversation_id", "eq."+conversationID.String())
	query.Set("content", "ilike.*"+searchQuery+"*")
	query.Set("select", "*,sender:sender_id(id,username,display_name,profile_picture),reply_to:reply_to_id(id,content,message_type,sender_id,sender:sender_id(id,username,display_name,profile_picture)),reactions:message_reactions(*,user:user_id(id,username,display_name,profile_picture))")
	query.Set("order", "created_at.desc")
	query.Set("limit", fmt.Sprintf("%d", limit))
	query.Set("offset", fmt.Sprintf("%d", offset))

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.messagesURL(query), nil)
	r.setHeaders(req, "")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var sbMessages []*supabaseMessage
	if err := json.NewDecoder(resp.Body).Decode(&sbMessages); err != nil {
		return nil, err
	}

	messages := make([]*models.Message, 0, len(sbMessages))
	for _, sbMsg := range sbMessages {
		msg, err := sbMsg.toMessage()
		if err != nil {
			log.Printf("Failed to convert message: %v", err)
			continue
		}
		messages = append(messages, msg)
	}

	log.Printf("[MessageRepo] Found %d messages matching '%s' in conversation %s", len(messages), searchQuery, conversationID)
	return messages, nil
}

// ============================================
// HELPER METHODS FOR NEW TABLES
// ============================================

func (r *supabaseMessageRepository) editHistoryURL(query url.Values) string {
	baseURL := fmt.Sprintf("%s/rest/v1/message_edit_history", r.supabaseURL)
	if len(query) > 0 {
		return fmt.Sprintf("%s?%s", baseURL, query.Encode())
	}
	return baseURL
}

func (r *supabaseMessageRepository) conversationKeysURL(query url.Values) string {
	baseURL := fmt.Sprintf("%s/rest/v1/conversation_keys", r.supabaseURL)
	if len(query) > 0 {
		return fmt.Sprintf("%s?%s", baseURL, query.Encode())
	}
	return baseURL
}

// ============================================
// E2EE KEY STORAGE
// ============================================

// StoreConversationKey stores a user's public key for a conversation
func (r *supabaseMessageRepository) StoreConversationKey(ctx context.Context, conversationID, userID uuid.UUID, publicKey string, keyVersion int) error {
	if publicKey == "" {
		return fmt.Errorf("public key cannot be empty")
	}

	// Check if key already exists for this conversation/user/version
	query := url.Values{}
	query.Set("conversation_id", fmt.Sprintf("eq.%s", conversationID))
	query.Set("user_id", fmt.Sprintf("eq.%s", userID))
	query.Set("key_version", fmt.Sprintf("eq.%d", keyVersion))
	query.Set("revoked_at", "is.null")
	query.Set("select", "id")

	checkURL := r.conversationKeysURL(query)
	req, err := http.NewRequestWithContext(ctx, "GET", checkURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "return=representation")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to check existing key: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		var existing []map[string]interface{}
		if err := json.NewDecoder(resp.Body).Decode(&existing); err == nil && len(existing) > 0 {
			// Key exists, update it
			keyID := existing[0]["id"].(string)
			updateURL := fmt.Sprintf("%s/rest/v1/conversation_keys?id=eq.%s", r.supabaseURL, keyID)

			updateData := map[string]interface{}{
				"public_key": publicKey,
				"updated_at": time.Now().Format(time.RFC3339),
			}

			jsonData, err := json.Marshal(updateData)
			if err != nil {
				return fmt.Errorf("failed to marshal update data: %w", err)
			}

			updateReq, err := http.NewRequestWithContext(ctx, "PATCH", updateURL, bytes.NewBuffer(jsonData))
			if err != nil {
				return fmt.Errorf("failed to create update request: %w", err)
			}

			r.setHeaders(updateReq, "return=representation")
			updateResp, err := http.DefaultClient.Do(updateReq)
			if err != nil {
				return fmt.Errorf("failed to update key: %w", err)
			}
			defer updateResp.Body.Close()

			if updateResp.StatusCode >= 200 && updateResp.StatusCode < 300 {
				log.Printf("[E2EE] Updated existing key for conversation %s, user %s", conversationID, userID)
				return nil
			}
		}
	}

	// Key doesn't exist, create new one
	createURL := r.conversationKeysURL(nil)

	keyData := map[string]interface{}{
		"conversation_id": conversationID.String(),
		"user_id":         userID.String(),
		"public_key":      publicKey,
		"key_type":        "RSA-OAEP",
		"key_version":     keyVersion,
	}

	jsonData, err := json.Marshal(keyData)
	if err != nil {
		return fmt.Errorf("failed to marshal key data: %w", err)
	}

	createReq, err := http.NewRequestWithContext(ctx, "POST", createURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(createReq, "return=representation")
	createResp, err := http.DefaultClient.Do(createReq)
	if err != nil {
		return fmt.Errorf("failed to store key: %w", err)
	}
	defer createResp.Body.Close()

	if createResp.StatusCode >= 200 && createResp.StatusCode < 300 {
		log.Printf("[E2EE] Stored new key for conversation %s, user %s, version %d", conversationID, userID, keyVersion)
		return nil
	}

	body, _ := io.ReadAll(createResp.Body)
	return fmt.Errorf("failed to store key: status %d, body: %s", createResp.StatusCode, string(body))
}

// GetConversationKey retrieves a user's active public key for a conversation
func (r *supabaseMessageRepository) GetConversationKey(ctx context.Context, conversationID, userID uuid.UUID) (string, error) {
	query := url.Values{}
	query.Set("conversation_id", fmt.Sprintf("eq.%s", conversationID))
	query.Set("user_id", fmt.Sprintf("eq.%s", userID))
	query.Set("revoked_at", "is.null")
	query.Set("order", "key_version.desc")
	query.Set("limit", "1")
	query.Set("select", "public_key")

	url := r.conversationKeysURL(query)
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to get key: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		var keys []struct {
			PublicKey string `json:"public_key"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&keys); err != nil {
			return "", fmt.Errorf("failed to decode response: %w", err)
		}

		if len(keys) > 0 {
			return keys[0].PublicKey, nil
		}
	}

	return "", fmt.Errorf("public key not found for conversation %s, user %s", conversationID, userID)
}

// RevokeConversationKey revokes a key (marks as revoked)
func (r *supabaseMessageRepository) RevokeConversationKey(ctx context.Context, conversationID, userID uuid.UUID, keyVersion int) error {
	query := url.Values{}
	query.Set("conversation_id", fmt.Sprintf("eq.%s", conversationID))
	query.Set("user_id", fmt.Sprintf("eq.%s", userID))
	query.Set("key_version", fmt.Sprintf("eq.%d", keyVersion))

	url := r.conversationKeysURL(query)

	updateData := map[string]interface{}{
		"revoked_at": time.Now().Format(time.RFC3339),
	}

	jsonData, err := json.Marshal(updateData)
	if err != nil {
		return fmt.Errorf("failed to marshal update data: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "PATCH", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	r.setHeaders(req, "return=representation")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to revoke key: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		log.Printf("[E2EE] Revoked key for conversation %s, user %s, version %d", conversationID, userID, keyVersion)
		return nil
	}

	body, _ := io.ReadAll(resp.Body)
	return fmt.Errorf("failed to revoke key: status %d, body: %s", resp.StatusCode, string(body))
}

package models

import (
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// MessageType represents the type of message content
type MessageType string

const (
	MessageTypeText   MessageType = "text"
	MessageTypeImage  MessageType = "image"
	MessageTypeFile   MessageType = "file"
	MessageTypeVideo  MessageType = "video"
	MessageTypeAudio  MessageType = "audio"
	MessageTypeSystem MessageType = "system"
)

// MessageStatus represents the delivery status of a message
type MessageStatus string

const (
	MessageStatusSent      MessageStatus = "sent"      // Message sent from sender (✓)
	MessageStatusDelivered MessageStatus = "delivered" // Message received by server/recipient (✓✓)
	MessageStatusRead      MessageStatus = "read"      // Message read by recipient (✓✓ blue)
)

// Conversation represents a 1-on-1 chat between two users
type Conversation struct {
	ID                   uuid.UUID  `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	Participant1ID       uuid.UUID  `json:"participant1_id" gorm:"type:uuid;not null"`
	Participant2ID       uuid.UUID  `json:"participant2_id" gorm:"type:uuid;not null"`
	LastMessageContent   *string    `json:"last_message_content"`
	LastMessageEncrypted *string    `json:"last_message_encrypted"`
	LastMessageIV        *string    `json:"last_message_iv"`
	LastMessageSenderID  *uuid.UUID `json:"last_message_sender_id" gorm:"type:uuid"`
	LastMessageAt        *time.Time `json:"last_message_at"`
	UnreadCountP1        int        `json:"unread_count_p1" gorm:"default:0"`
	UnreadCountP2        int        `json:"unread_count_p2" gorm:"default:0"`
	P1Typing             bool       `json:"p1_typing" gorm:"default:false"`
	P2Typing             bool       `json:"p2_typing" gorm:"default:false"`
	P1TypingAt           *time.Time `json:"p1_typing_at"`
	P2TypingAt           *time.Time `json:"p2_typing_at"`
	CreatedAt            time.Time  `json:"created_at" gorm:"default:now()"`
	UpdatedAt            time.Time  `json:"updated_at" gorm:"default:now()"`

	// Joined data (not in database, populated in queries)
	Participant1 *User `json:"participant1,omitempty" gorm:"foreignKey:Participant1ID"`
	Participant2 *User `json:"participant2,omitempty" gorm:"foreignKey:Participant2ID"`

	// Computed fields (set in business logic based on current user)
	OtherUser   *User      `json:"other_user,omitempty" gorm:"-"` // The other person in the conversation
	UnreadCount int        `json:"unread_count" gorm:"-"`         // Current user's unread count
	IsTyping    bool       `json:"is_typing" gorm:"-"`            // Is other user typing
	IsOnline    bool       `json:"is_online,omitempty" gorm:"-"`  // Is other user online (from Redis)
	LastSeen    *time.Time `json:"last_seen,omitempty" gorm:"-"`  // Other user's last seen (from Redis)
}

// Message represents a single message in a conversation
type Message struct {
	ID               uuid.UUID   `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	ConversationID   uuid.UUID   `json:"conversation_id" gorm:"type:uuid;not null"`
	SenderID         uuid.UUID   `json:"sender_id" gorm:"type:uuid;not null"`
	Content          string      `json:"content" gorm:"not null"`                         // Plaintext (for backward compatibility, but should be empty if encrypted)
	EncryptedContent *string     `json:"encrypted_content,omitempty" gorm:"type:text"`    // E2EE encrypted content
	ContentIV        *string     `json:"iv,omitempty" gorm:"column:content_iv;type:text"` // Initialization vector for decryption
	MessageType      MessageType `json:"message_type" gorm:"default:'text'"`
	AttachmentURL    *string     `json:"attachment_url"`
	AttachmentName   *string     `json:"attachment_name"`
	AttachmentSize   *int        `json:"attachment_size"`
	AttachmentType   *string     `json:"attachment_type"`
	// Video-specific fields
	ThumbnailURL  *string        `json:"thumbnail_url,omitempty"`
	VideoDuration *int           `json:"video_duration,omitempty"` // Duration in seconds
	VideoWidth    *int           `json:"video_width,omitempty"`
	VideoHeight   *int           `json:"video_height,omitempty"`
	Status        MessageStatus  `json:"status" gorm:"default:'sent'"`
	DeliveredAt   *time.Time     `json:"delivered_at"`
	ReadAt        *time.Time     `json:"read_at"`
	DeletedBy     pq.StringArray `json:"deleted_by,omitempty" gorm:"type:uuid[]"`
	ReplyToID     *uuid.UUID     `json:"reply_to_id" gorm:"type:uuid"`
	CreatedAt     time.Time      `json:"created_at" gorm:"default:now()"`
	UpdatedAt     time.Time      `json:"updated_at" gorm:"default:now()"`

	// Pin feature
	PinnedAt *time.Time `json:"pinned_at,omitempty"`
	PinnedBy *uuid.UUID `json:"pinned_by,omitempty" gorm:"type:uuid"`

	// Edit feature
	EditedAt        *time.Time `json:"edited_at,omitempty"`
	EditCount       int        `json:"edit_count" gorm:"default:0"`
	OriginalContent *string    `json:"original_content,omitempty"`

	// Forward feature
	ForwardedFromID *uuid.UUID `json:"forwarded_from_id,omitempty" gorm:"type:uuid"`
	IsForwarded     bool       `json:"is_forwarded" gorm:"default:false"`

	// Joined data (populated in queries)
	Sender         *User              `json:"sender,omitempty" gorm:"foreignKey:SenderID"`
	ReplyToMessage *Message           `json:"reply_to,omitempty" gorm:"foreignKey:ReplyToID"`
	Reactions      []*MessageReaction `json:"reactions,omitempty" gorm:"foreignKey:MessageID"`

	// Computed fields
	IsMine    bool `json:"is_mine" gorm:"-"`    // Is this message from current user
	IsStarred bool `json:"is_starred" gorm:"-"` // Is this message starred by current user
	IsPinned  bool `json:"is_pinned" gorm:"-"`  // Is this message pinned in conversation
}

// MessageReaction represents an emoji reaction on a message
type MessageReaction struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	MessageID uuid.UUID `json:"message_id" gorm:"type:uuid;not null"`
	UserID    uuid.UUID `json:"user_id" gorm:"type:uuid;not null"`
	Emoji     string    `json:"emoji" gorm:"not null"`
	CreatedAt time.Time `json:"created_at" gorm:"default:now()"`

	// Joined data
	User *User `json:"user,omitempty" gorm:"foreignKey:UserID"`
}

// StarredMessage represents a user's starred/bookmarked message
type StarredMessage struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	UserID    uuid.UUID `json:"user_id" gorm:"type:uuid;not null"`
	MessageID uuid.UUID `json:"message_id" gorm:"type:uuid;not null"`
	StarredAt time.Time `json:"starred_at" gorm:"default:now()"`

	// Joined data
	Message *Message `json:"message,omitempty" gorm:"foreignKey:MessageID"`
}

// WebSocket message types for real-time messaging
type WSMessageType string

const (
	WSMessageTypeNewMessage       WSMessageType = "new_message"
	WSMessageTypeMessageRead      WSMessageType = "message_read"
	WSMessageTypeMessageDelivered WSMessageType = "message_delivered"
	WSMessageTypeTyping           WSMessageType = "typing"
	WSMessageTypeStopTyping       WSMessageType = "stop_typing"
	WSMessageTypeReaction         WSMessageType = "reaction"
	WSMessageTypeReactionRemoved  WSMessageType = "reaction_removed"
	WSMessageTypeMessageDeleted   WSMessageType = "message_deleted"
	WSMessageTypeMessageEdited    WSMessageType = "message_edited"
	WSMessageTypeMessagePinned    WSMessageType = "message_pinned"
	WSMessageTypeMessageUnpinned  WSMessageType = "message_unpinned"
	WSMessageTypeOnline           WSMessageType = "online"
	WSMessageTypeOffline          WSMessageType = "offline"
	WSMessageTypeACK              WSMessageType = "ack"
)

// WSMessageEnvelope wraps WebSocket messages with metadata for routing and acknowledgment
type WSMessageEnvelope struct {
	ID             string        `json:"id"`                        // Unique ID for ACK tracking
	Type           WSMessageType `json:"type"`                      // Message type for routing
	Channel        string        `json:"channel"`                   // Channel name (e.g., "messaging")
	ConversationID *uuid.UUID    `json:"conversation_id,omitempty"` // Associated conversation
	Data           interface{}   `json:"data"`                      // Actual payload
	Timestamp      int64         `json:"timestamp"`                 // Unix timestamp
}

// PresenceInfo represents a user's online/offline status
type PresenceInfo struct {
	UserID   uuid.UUID  `json:"user_id"`
	IsOnline bool       `json:"is_online"`
	LastSeen *time.Time `json:"last_seen,omitempty"`
}

// TypingInfo represents typing indicator information
type TypingInfo struct {
	ConversationID uuid.UUID `json:"conversation_id"`
	UserID         uuid.UUID `json:"user_id"`
	DisplayName    string    `json:"display_name"`
	IsTyping       bool      `json:"is_typing"`
	IsRecording    bool      `json:"is_recording"`
}

// MessageRequest represents a request to send a message
type MessageRequest struct {
	Content          string      `json:"content"`           // Plaintext (for backward compatibility, empty if encrypted)
	EncryptedContent *string     `json:"encrypted_content"` // E2EE encrypted content (preferred)
	IV               *string     `json:"iv"`                // Initialization vector for decryption
	MessageType      MessageType `json:"message_type"`
	AttachmentURL    *string     `json:"attachment_url"`
	AttachmentName   *string     `json:"attachment_name"`
	AttachmentSize   *int        `json:"attachment_size"`
	AttachmentType   *string     `json:"attachment_type"`
	ReplyToID        *uuid.UUID  `json:"reply_to_id"`
	TempID           *string     `json:"temp_id"` // For optimistic UI tracking
}

// ReactionRequest represents a request to add a reaction
type ReactionRequest struct {
	Emoji string `json:"emoji" binding:"required"`
}

// EditMessageRequest represents a request to edit a message
type EditMessageRequest struct {
	Content string `json:"content" binding:"required"`
}

// ForwardMessageRequest represents a request to forward a message
type ForwardMessageRequest struct {
	ToConversationID uuid.UUID `json:"to_conversation_id" binding:"required"`
}

// ConversationListResponse represents paginated conversation list
type ConversationListResponse struct {
	Conversations []*Conversation `json:"conversations"`
	Total         int             `json:"total"`
	Limit         int             `json:"limit"`
	Offset        int             `json:"offset"`
	HasMore       bool            `json:"has_more"`
}

// MessageListResponse represents paginated message list
type MessageListResponse struct {
	Messages []*Message `json:"messages"`
	Total    int        `json:"total"`
	Limit    int        `json:"limit"`
	Offset   int        `json:"offset"`
	HasMore  bool       `json:"has_more"`
}

// UnreadCountResponse represents unread message counts
type UnreadCountResponse struct {
	Total          int            `json:"total"`
	ByConversation map[string]int `json:"by_conversation,omitempty"`
}

// MediaUploadResponse represents response after media upload
type MediaUploadResponse struct {
	URL  string `json:"url"`
	Name string `json:"name"`
	Size int    `json:"size"`
	Type string `json:"type"`
}

// TableName overrides for GORM
func (Conversation) TableName() string {
	return "conversations"
}

func (Message) TableName() string {
	return "messages"
}

func (MessageReaction) TableName() string {
	return "message_reactions"
}

func (StarredMessage) TableName() string {
	return "starred_messages"
}

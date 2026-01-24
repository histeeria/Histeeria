package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// These types mirror the types in encryption package to avoid circular imports
// They must match the structure in internal/encryption/key_service.go

// IdentityKey represents a user's long-term identity key
type IdentityKey struct {
	UserID    uuid.UUID `json:"user_id"`
	PublicKey string    `json:"public_key"` // Base64-encoded
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// PreKey represents a one-time pre-key for key exchange
type PreKey struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	PublicKey string    `json:"public_key"` // Base64-encoded
	KeyID     int       `json:"key_id"`     // Sequential key ID
	IsUsed    bool      `json:"is_used"`
	CreatedAt time.Time `json:"created_at"`
}

// SignedPreKey represents a signed pre-key (longer-lived than regular pre-keys)
type SignedPreKey struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	PublicKey string    `json:"public_key"` // Base64-encoded
	Signature string    `json:"signature"`  // Base64-encoded signature
	KeyID     int       `json:"key_id"`
	CreatedAt time.Time `json:"created_at"`
}

// ConversationSession represents an E2EE session between two users
type ConversationSession struct {
	ID             uuid.UUID `json:"id"`
	ConversationID uuid.UUID `json:"conversation_id"`
	InitiatorID    uuid.UUID `json:"initiator_id"`
	ResponderID    uuid.UUID `json:"responder_id"`
	SessionKey     string    `json:"session_key"`       // Encrypted session key
	RatchetState   string    `json:"ratchet_state"`     // Double ratchet state (encrypted)
	MessageNumber  int       `json:"message_number"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// KeyRepository defines the interface for E2EE key management data access
type KeyRepository interface {
	// Identity key operations
	SaveIdentityKey(ctx context.Context, key *IdentityKey) error
	GetIdentityKey(ctx context.Context, userID uuid.UUID) (*IdentityKey, error)

	// Pre-key operations
	SavePreKeys(ctx context.Context, keys []*PreKey) error
	GetPreKeyCount(ctx context.Context, userID uuid.UUID) (int, error)
	ConsumePreKey(ctx context.Context, userID uuid.UUID) (*PreKey, error)

	// Signed pre-key operations
	SaveSignedPreKey(ctx context.Context, key *SignedPreKey) error
	GetSignedPreKey(ctx context.Context, userID uuid.UUID) (*SignedPreKey, error)
	DeleteSignedPreKey(ctx context.Context, userID uuid.UUID) error

	// Session operations
	SaveSession(ctx context.Context, session *ConversationSession) error
	GetSession(ctx context.Context, conversationID uuid.UUID) (*ConversationSession, error)
	UpdateSessionState(ctx context.Context, sessionID uuid.UUID, ratchetState string, messageNumber int) error
	CleanupSessions(ctx context.Context, olderThan time.Time) (int, error)
}

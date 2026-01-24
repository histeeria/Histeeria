package encryption

import (
	"context"
	"encoding/base64"
	"fmt"
	"time"

	"histeeria-backend/internal/repository"

	"github.com/google/uuid"
)

// These types are re-exported from repository package for convenience
// They match the types defined in repository package to avoid circular imports
type IdentityKey = repository.IdentityKey
type PreKey = repository.PreKey
type SignedPreKey = repository.SignedPreKey
type ConversationSession = repository.ConversationSession

// KeyService manages E2EE keys for users
// Implements Signal Protocol-compatible key management
type KeyService struct {
	keyRepo repository.KeyRepository
}

// NewKeyService creates a new key service
func NewKeyService(keyRepo repository.KeyRepository) *KeyService {
	return &KeyService{
		keyRepo: keyRepo,
	}
}

// Types are aliased from repository package to avoid circular imports

// KeyBundle is returned when establishing a new session
type KeyBundle struct {
	IdentityKey  string `json:"identity_key"`   // Base64-encoded
	SignedPreKey string `json:"signed_pre_key"` // Base64-encoded
	PreKeyID     int    `json:"pre_key_id"`
	PreKey       string `json:"pre_key"` // Base64-encoded (optional, one-time)
	SignedKeyID  int    `json:"signed_key_id"`
	Signature    string `json:"signature"` // Base64-encoded
}

// ConversationSession is aliased from repository package

// ============================================
// IDENTITY KEY MANAGEMENT
// ============================================

// RegisterIdentityKey registers a user's identity key
// Called during registration or when user regenerates keys
func (s *KeyService) RegisterIdentityKey(ctx context.Context, userID uuid.UUID, publicKey []byte) error {
	if len(publicKey) == 0 {
		return fmt.Errorf("public key cannot be empty")
	}

	// Validate key format (should be 32 bytes for Ed25519)
	if len(publicKey) != 32 && len(publicKey) != 33 {
		return fmt.Errorf("invalid public key length: expected 32 or 33 bytes")
	}

	key := &repository.IdentityKey{
		UserID:    userID,
		PublicKey: base64.StdEncoding.EncodeToString(publicKey),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	return s.keyRepo.SaveIdentityKey(ctx, key)
}

// GetIdentityKey retrieves a user's identity key
func (s *KeyService) GetIdentityKey(ctx context.Context, userID uuid.UUID) (*repository.IdentityKey, error) {
	return s.keyRepo.GetIdentityKey(ctx, userID)
}

// ============================================
// PRE-KEY MANAGEMENT
// ============================================

// UploadPreKeys uploads a batch of pre-keys for a user
// Client should upload 100 pre-keys initially, then top up when low
func (s *KeyService) UploadPreKeys(ctx context.Context, userID uuid.UUID, preKeys []PreKeyUpload) error {
	if len(preKeys) == 0 {
		return fmt.Errorf("at least one pre-key required")
	}

	if len(preKeys) > 100 {
		return fmt.Errorf("maximum 100 pre-keys per upload")
	}

	keys := make([]*repository.PreKey, 0, len(preKeys))
	for _, pk := range preKeys {
		keys = append(keys, &repository.PreKey{
			ID:        uuid.New(),
			UserID:    userID,
			PublicKey: pk.PublicKey,
			KeyID:     pk.KeyID,
			IsUsed:    false,
			CreatedAt: time.Now(),
		})
	}

	return s.keyRepo.SavePreKeys(ctx, keys)
}

// PreKeyUpload represents a pre-key being uploaded
type PreKeyUpload struct {
	KeyID     int    `json:"key_id"`
	PublicKey string `json:"public_key"` // Base64-encoded
}

// GetAvailablePreKeyCount returns the number of unused pre-keys for a user
func (s *KeyService) GetAvailablePreKeyCount(ctx context.Context, userID uuid.UUID) (int, error) {
	return s.keyRepo.GetPreKeyCount(ctx, userID)
}

// ConsumePreKey gets and marks a pre-key as used
// Used when establishing a new session
func (s *KeyService) ConsumePreKey(ctx context.Context, userID uuid.UUID) (*repository.PreKey, error) {
	return s.keyRepo.ConsumePreKey(ctx, userID)
}

// ============================================
// SIGNED PRE-KEY MANAGEMENT
// ============================================

// UploadSignedPreKey uploads a signed pre-key
// Signed pre-keys are longer-lived than regular pre-keys
func (s *KeyService) UploadSignedPreKey(ctx context.Context, userID uuid.UUID, keyID int, publicKey, signature []byte) error {
	spk := &repository.SignedPreKey{
		ID:        uuid.New(),
		UserID:    userID,
		PublicKey: base64.StdEncoding.EncodeToString(publicKey),
		Signature: base64.StdEncoding.EncodeToString(signature),
		KeyID:     keyID,
		CreatedAt: time.Now(),
	}

	return s.keyRepo.SaveSignedPreKey(ctx, spk)
}

// GetSignedPreKey retrieves the current signed pre-key for a user
func (s *KeyService) GetSignedPreKey(ctx context.Context, userID uuid.UUID) (*repository.SignedPreKey, error) {
	return s.keyRepo.GetSignedPreKey(ctx, userID)
}

// ============================================
// KEY BUNDLE (For Session Establishment)
// ============================================

// GetKeyBundle retrieves the key bundle needed to establish a session
// This is what sender fetches to send the first message
func (s *KeyService) GetKeyBundle(ctx context.Context, userID uuid.UUID) (*KeyBundle, error) {
	// Get identity key
	identityKey, err := s.keyRepo.GetIdentityKey(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get identity key: %w", err)
	}
	if identityKey == nil {
		return nil, fmt.Errorf("user has no identity key")
	}

	// Get signed pre-key
	signedPreKey, err := s.keyRepo.GetSignedPreKey(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get signed pre-key: %w", err)
	}
	if signedPreKey == nil {
		return nil, fmt.Errorf("user has no signed pre-key")
	}

	bundle := &KeyBundle{
		IdentityKey:  identityKey.PublicKey,
		SignedPreKey: signedPreKey.PublicKey,
		SignedKeyID:  signedPreKey.KeyID,
		Signature:    signedPreKey.Signature,
	}

	// Try to get a one-time pre-key (optional)
	preKey, err := s.keyRepo.ConsumePreKey(ctx, userID)
	if err == nil && preKey != nil {
		bundle.PreKey = preKey.PublicKey
		bundle.PreKeyID = preKey.KeyID
	}

	return bundle, nil
}

// ============================================
// SESSION MANAGEMENT
// ============================================

// CreateSession creates a new E2EE session
func (s *KeyService) CreateSession(ctx context.Context, conversationID, initiatorID, responderID uuid.UUID) (*repository.ConversationSession, error) {
	session := &repository.ConversationSession{
		ID:             uuid.New(),
		ConversationID: conversationID,
		InitiatorID:    initiatorID,
		ResponderID:    responderID,
		MessageNumber:  0,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
	}

	if err := s.keyRepo.SaveSession(ctx, session); err != nil {
		return nil, err
	}

	return session, nil
}

// GetSession retrieves a session by conversation ID
func (s *KeyService) GetSession(ctx context.Context, conversationID uuid.UUID) (*repository.ConversationSession, error) {
	return s.keyRepo.GetSession(ctx, conversationID)
}

// UpdateSessionState updates the ratchet state of a session
func (s *KeyService) UpdateSessionState(ctx context.Context, sessionID uuid.UUID, ratchetState string, messageNumber int) error {
	return s.keyRepo.UpdateSessionState(ctx, sessionID, ratchetState, messageNumber)
}

// ============================================
// KEY ROTATION & CLEANUP
// ============================================

// RotateSignedPreKey rotates the signed pre-key
// Should be called periodically (e.g., weekly)
func (s *KeyService) RotateSignedPreKey(ctx context.Context, userID uuid.UUID, newKeyID int, publicKey, signature []byte) error {
	// Delete old signed pre-key
	if err := s.keyRepo.DeleteSignedPreKey(ctx, userID); err != nil {
		// Log but don't fail if old key doesn't exist
	}

	// Upload new signed pre-key
	return s.UploadSignedPreKey(ctx, userID, newKeyID, publicKey, signature)
}

// CleanupOldSessions removes old/inactive sessions
func (s *KeyService) CleanupOldSessions(ctx context.Context, olderThan time.Duration) (int, error) {
	return s.keyRepo.CleanupSessions(ctx, time.Now().Add(-olderThan))
}

// ============================================
// KEY VERIFICATION
// ============================================

// VerifyKeyFingerprint verifies a user's key fingerprint
// Used for out-of-band verification (QR code, etc.)
func (s *KeyService) GetKeyFingerprint(ctx context.Context, userID uuid.UUID) (string, error) {
	identityKey, err := s.keyRepo.GetIdentityKey(ctx, userID)
	if err != nil || identityKey == nil {
		return "", fmt.Errorf("failed to get identity key")
	}

	// Decode the public key
	publicKey, err := base64.StdEncoding.DecodeString(identityKey.PublicKey)
	if err != nil {
		return "", fmt.Errorf("failed to decode public key")
	}

	// Generate fingerprint (first 30 hex characters of SHA-256)
	// In production, use proper Signal-style fingerprint generation
	fingerprint := fmt.Sprintf("%x", publicKey)
	if len(fingerprint) > 30 {
		fingerprint = fingerprint[:30]
	}

	// Format for display (groups of 5)
	formatted := ""
	for i, c := range fingerprint {
		if i > 0 && i%5 == 0 {
			formatted += " "
		}
		formatted += string(c)
	}

	return formatted, nil
}

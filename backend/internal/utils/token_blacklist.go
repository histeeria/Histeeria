package utils

import (
	"crypto/sha256"
	"encoding/hex"
	"sync"
	"time"
)

// TokenBlacklist manages blacklisted JWT tokens in memory
// Tokens are stored by their SHA256 hash for security
type TokenBlacklist struct {
	entries     sync.Map // map[string]*BlacklistEntry
	cleanupStop chan struct{}
}

// BlacklistEntry represents a blacklisted token with expiry
type BlacklistEntry struct {
	expiresAt time.Time
}

// NewTokenBlacklist creates a new token blacklist
func NewTokenBlacklist() *TokenBlacklist {
	tb := &TokenBlacklist{
		cleanupStop: make(chan struct{}),
	}

	// Start cleanup goroutine to remove expired entries
	go tb.startCleanup()

	return tb
}

// Add adds a token to the blacklist until it expires
// tokenExpiry is when the token itself expires (we blacklist until then)
func (tb *TokenBlacklist) Add(token string, tokenExpiry time.Time) {
	// Hash the token for storage (don't store full token)
	tokenHash := tb.hashToken(token)

	entry := &BlacklistEntry{
		expiresAt: tokenExpiry,
	}

	tb.entries.Store(tokenHash, entry)
}

// IsBlacklisted checks if a token is blacklisted
func (tb *TokenBlacklist) IsBlacklisted(token string) bool {
	tokenHash := tb.hashToken(token)

	entryInterface, ok := tb.entries.Load(tokenHash)
	if !ok {
		return false
	}

	entry := entryInterface.(*BlacklistEntry)

	// Check if entry has expired (token itself expired)
	if time.Now().After(entry.expiresAt) {
		// Remove expired entry
		tb.entries.Delete(tokenHash)
		return false
	}

	return true
}

// hashToken creates a SHA256 hash of the token
// This ensures we don't store the actual token in memory
func (tb *TokenBlacklist) hashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}

// startCleanup runs periodic cleanup to remove expired entries
func (tb *TokenBlacklist) startCleanup() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			tb.cleanup()
		case <-tb.cleanupStop:
			return
		}
	}
}

// cleanup removes entries that have expired
func (tb *TokenBlacklist) cleanup() {
	now := time.Now()

	tb.entries.Range(func(key, value interface{}) bool {
		entry := value.(*BlacklistEntry)
		if now.After(entry.expiresAt) {
			tb.entries.Delete(key)
		}
		return true
	})
}

// Stop stops the cleanup goroutine (useful for testing or graceful shutdown)
func (tb *TokenBlacklist) Stop() {
	select {
	case <-tb.cleanupStop:
		// Already closed
	default:
		close(tb.cleanupStop)
	}
}

// Size returns the number of blacklisted tokens (for monitoring)
func (tb *TokenBlacklist) Size() int {
	count := 0
	tb.entries.Range(func(key, value interface{}) bool {
		count++
		return true
	})
	return count
}

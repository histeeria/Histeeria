package utils

import (
	"crypto/sha256"
	"fmt"
	"strings"
)

// GenerateEmailHash generates a SHA-256 hash of the normalized (lowercase, trimmed) email
// This is used for privacy-preserving email lookups (prevents enumeration attacks)
func GenerateEmailHash(email string) string {
	// Normalize email (lowercase, trim)
	normalized := strings.ToLower(strings.TrimSpace(email))

	// Generate SHA-256 hash
	hash := sha256.Sum256([]byte(normalized))

	// Return as hex string (64 characters)
	return fmt.Sprintf("%x", hash)
}

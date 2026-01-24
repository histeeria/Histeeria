package utils

import (
	"fmt"
	"strings"
)

// GenerateUsernameFromEmail creates a username from an email address
func GenerateUsernameFromEmail(email string) string {
	parts := strings.Split(email, "@")
	if len(parts) > 0 {
		username := strings.ToLower(parts[0])
		// Remove special characters, keep only alphanumeric
		username = strings.Map(func(r rune) rune {
			if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
				return r
			}
			return -1
		}, username)

		// Ensure username is not empty and has minimum length
		if len(username) < 3 {
			return "user" + GenerateRandomString(6)
		}
		return username
	}
	return "user" + GenerateRandomString(6)
}

// GenerateRandomString generates a random alphanumeric string
func GenerateRandomString(length int) string {
	const chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	result := make([]byte, length)
	for i := range result {
		result[i] = chars[i%len(chars)]
	}
	return string(result)
}

// SanitizeUsername ensures username meets requirements
func SanitizeUsername(username string) string {
	// Convert to lowercase
	username = strings.ToLower(username)

	// Remove special characters
	username = strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			return r
		}
		return -1
	}, username)

	// Ensure minimum length
	if len(username) < 3 {
		return username + "user"
	}

	// Ensure maximum length
	if len(username) > 20 {
		return username[:20]
	}

	return username
}

// GenerateUniqueUsername generates a unique username with numeric suffix if needed
func GenerateUniqueUsername(base string, checkExists func(string) bool) string {
	base = SanitizeUsername(base)

	// Try base username first
	if !checkExists(base) {
		return base
	}

	// Try with numbers 1-999
	for i := 1; i < 1000; i++ {
		candidate := fmt.Sprintf("%s%d", base, i)
		if len(candidate) > 20 {
			// Truncate base to make room for number
			base = base[:20-len(fmt.Sprintf("%d", i))]
			candidate = fmt.Sprintf("%s%d", base, i)
		}
		if !checkExists(candidate) {
			return candidate
		}
	}

	// Fallback: use random string
	return "user" + GenerateRandomString(10)
}

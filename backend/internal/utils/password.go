package utils

import (
	"golang.org/x/crypto/bcrypt"
)

// HashPassword hashes a password using bcrypt
func HashPassword(password string) (string, error) {
	// Use cost factor 12 for good security vs performance balance
	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		return "", err
	}
	return string(hashedBytes), nil
}

// CheckPasswordHash compares a password with its hash
func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// ValidatePasswordStrength validates password strength
func ValidatePasswordStrength(password string) error {
	if len(password) < 6 {
		return &PasswordError{
			Message: "Password must be at least 6 characters long",
		}
	}

	// Add more password strength checks if needed
	// For now, we'll keep it simple as requested (minimum 6 characters)

	return nil
}

// PasswordError represents a password validation error
type PasswordError struct {
	Message string
}

func (e *PasswordError) Error() string {
	return e.Message
}

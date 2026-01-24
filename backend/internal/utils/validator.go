package utils

import (
	"regexp"
	"strings"
	"unicode"

	"histeeria-backend/internal/models"
	"histeeria-backend/pkg/errors"
)

// ValidateRegistration validates registration request
func ValidateRegistration(req *models.RegisterRequest) error {
	// Validate email
	if !ValidateEmailFormat(req.Email) {
		return errors.ErrInvalidEmail
	}

	// Validate password
	if err := ValidatePasswordStrength(req.Password); err != nil {
		return errors.ErrInvalidPassword
	}

	// Validate display name
	if err := ValidateDisplayName(req.DisplayName); err != nil {
		return errors.ErrInvalidDisplayName
	}

	// Validate username
	if err := ValidateUsername(req.Username); err != nil {
		return errors.ErrInvalidUsername
	}

	// Validate age if provided
	if req.Age != nil {
		if err := ValidateAge(*req.Age); err != nil {
		return errors.ErrInvalidAge
		}
	}

	return nil
}

// ValidateLogin validates login request
func ValidateLogin(req *models.LoginRequest) error {
	if strings.TrimSpace(req.EmailOrUsername) == "" {
		return errors.ErrInvalidInput
	}

	if strings.TrimSpace(req.Password) == "" {
		return errors.ErrInvalidInput
	}

	return nil
}

// ValidateEmailVerification validates email verification request
func ValidateEmailVerification(req *models.VerifyEmailRequest) error {
	if !ValidateEmailFormat(req.Email) {
		return errors.ErrInvalidEmail
	}

	if len(req.VerificationCode) != 6 {
		return errors.ErrInvalidVerificationCode
	}

	// Check if verification code contains only digits
	for _, char := range req.VerificationCode {
		if !unicode.IsDigit(char) {
			return errors.ErrInvalidVerificationCode
		}
	}

	return nil
}

// ValidateForgotPassword validates forgot password request
func ValidateForgotPassword(req *models.ForgotPasswordRequest) error {
	if !ValidateEmailFormat(req.Email) {
		return errors.ErrInvalidEmail
	}

	return nil
}

// ValidateResetPassword validates reset password request
func ValidateResetPassword(req *models.ResetPasswordRequest) error {
	if strings.TrimSpace(req.Token) == "" {
		return errors.ErrInvalidResetToken
	}

	if err := ValidatePasswordStrength(req.NewPassword); err != nil {
		return errors.ErrInvalidPassword
	}

	return nil
}

// ValidateDisplayName validates display name
func ValidateDisplayName(displayName string) error {
	displayName = strings.TrimSpace(displayName)

	if len(displayName) < 2 || len(displayName) > 50 {
		return errors.ErrInvalidDisplayName
	}

	// Check for valid characters (letters, numbers, spaces, and basic punctuation)
	for _, char := range displayName {
		if !unicode.IsLetter(char) && !unicode.IsDigit(char) &&
			!unicode.IsSpace(char) && char != '.' && char != '-' && char != '_' {
			return errors.ErrInvalidDisplayName
		}
	}

	return nil
}

// ValidateUsername validates username
func ValidateUsername(username string) error {
	username = strings.TrimSpace(username)

	if len(username) < 3 || len(username) > 20 {
		return errors.ErrInvalidUsername
	}

	// Check if username contains only alphanumeric characters and underscores
	matched, err := regexp.MatchString(`^[a-zA-Z0-9_]+$`, username)
	if err != nil || !matched {
		return errors.ErrInvalidUsername
	}

	// Check if username starts with a letter or number
	if !unicode.IsLetter(rune(username[0])) && !unicode.IsDigit(rune(username[0])) {
		return errors.ErrInvalidUsername
	}

	return nil
}

// ValidateAge validates age
func ValidateAge(age int) error {
	if age < 13 || age > 120 {
		return errors.ErrInvalidAge
	}
	return nil
}

// SanitizeInput sanitizes user input
func SanitizeInput(input string) string {
	// Remove leading/trailing whitespace
	input = strings.TrimSpace(input)

	// Remove potentially dangerous characters
	input = strings.ReplaceAll(input, "<", "&lt;")
	input = strings.ReplaceAll(input, ">", "&gt;")
	input = strings.ReplaceAll(input, "\"", "&quot;")
	input = strings.ReplaceAll(input, "'", "&#x27;")
	input = strings.ReplaceAll(input, "&", "&amp;")

	return input
}

// NormalizeEmail normalizes email address
func NormalizeEmail(email string) string {
	email = strings.TrimSpace(email)
	email = strings.ToLower(email)
	return email
}

// NormalizeUsername normalizes username
func NormalizeUsername(username string) string {
	username = strings.TrimSpace(username)
	username = strings.ToLower(username)
	return username
}

package errors

import (
	"fmt"
	"net/http"
)

// AppError represents an application error with HTTP status code
type AppError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Details string `json:"details,omitempty"`
}

func (e *AppError) Error() string {
	if e.Details != "" {
		return fmt.Sprintf("%s: %s", e.Message, e.Details)
	}
	return e.Message
}

// NewAppError creates a new application error
func NewAppError(code int, message string, details ...string) *AppError {
	err := &AppError{
		Code:    code,
		Message: message,
	}
	if len(details) > 0 {
		err.Details = details[0]
	}
	return err
}

// New creates a new application error (alias for NewAppError for convenience)
func New(code int, message string, details ...string) *AppError {
	return NewAppError(code, message, details...)
}

// Predefined errors
var (
	// Authentication errors
	ErrInvalidCredentials = NewAppError(http.StatusUnauthorized, "Invalid email or password")
	ErrEmailNotVerified   = NewAppError(http.StatusUnauthorized, "Email not verified")
	ErrInvalidToken       = NewAppError(http.StatusUnauthorized, "Invalid or expired token")
	ErrTokenExpired       = NewAppError(http.StatusUnauthorized, "Token has expired")
	ErrUnauthorized       = NewAppError(http.StatusUnauthorized, "Unauthorized access")

	// Validation errors
	ErrInvalidInput       = NewAppError(http.StatusBadRequest, "Invalid input data")
	ErrEmailAlreadyExists = NewAppError(http.StatusConflict, "Email already exists")
	ErrUsernameExists     = NewAppError(http.StatusConflict, "Username already exists")
	ErrInvalidEmail       = NewAppError(http.StatusBadRequest, "Invalid email format")
	ErrInvalidPassword    = NewAppError(http.StatusBadRequest, "Password must be at least 6 characters")
	ErrInvalidUsername    = NewAppError(http.StatusBadRequest, "Username must be 3-20 characters, alphanumeric and underscore only")
	ErrInvalidAge         = NewAppError(http.StatusBadRequest, "Age must be between 13 and 120")
	ErrInvalidDisplayName = NewAppError(http.StatusBadRequest, "Display name must be 2-50 characters")

	// Email verification errors
	ErrInvalidVerificationCode = NewAppError(http.StatusBadRequest, "Invalid verification code")
	ErrVerificationCodeExpired = NewAppError(http.StatusBadRequest, "Verification code has expired")
	ErrEmailAlreadyVerified    = NewAppError(http.StatusBadRequest, "Email already verified")

	// Password reset errors
	ErrInvalidResetToken   = NewAppError(http.StatusBadRequest, "Invalid reset token")
	ErrResetTokenExpired   = NewAppError(http.StatusBadRequest, "Reset token has expired")
	ErrPasswordResetFailed = NewAppError(http.StatusInternalServerError, "Password reset failed")

	// User errors
	ErrUserNotFound      = NewAppError(http.StatusNotFound, "User not found")
	ErrUserInactive      = NewAppError(http.StatusForbidden, "User account is inactive")
	ErrUserAlreadyExists = NewAppError(http.StatusConflict, "User already exists")
	ErrForbidden         = NewAppError(http.StatusForbidden, "Access forbidden")

	// Multi-account errors
	ErrAccountsAlreadyLinked = NewAppError(http.StatusConflict, "Accounts are already linked")

	// Request errors
	ErrBadRequest = NewAppError(http.StatusBadRequest, "Bad request")

	// Rate limiting errors
	ErrTooManyRequests = NewAppError(http.StatusTooManyRequests, "Too many requests")

	// Server errors
	ErrInternalServer = NewAppError(http.StatusInternalServerError, "Internal server error")
	ErrDatabaseError  = NewAppError(http.StatusInternalServerError, "Database error")
	ErrEmailSendError = NewAppError(http.StatusInternalServerError, "Failed to send email")
)

// IsAppError checks if an error is an AppError
func IsAppError(err error) bool {
	_, ok := err.(*AppError)
	return ok
}

// GetAppError extracts AppError from an error
func GetAppError(err error) *AppError {
	if appErr, ok := err.(*AppError); ok {
		return appErr
	}
	// If it's a wrapped error, try to extract the underlying AppError
	if unwrapped, ok := err.(interface{ Unwrap() error }); ok {
		if appErr, ok := unwrapped.Unwrap().(*AppError); ok {
			return appErr
		}
	}
	// Return error with details from the error message
	return &AppError{
		Code:    http.StatusInternalServerError,
		Message: "Internal server error",
		Details: err.Error(),
	}
}

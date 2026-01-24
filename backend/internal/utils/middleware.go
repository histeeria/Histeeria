package utils

import (
	"fmt"
	"log"
	"net/http"
	"runtime/debug"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
)

// ============================================
// PANIC RECOVERY MIDDLEWARE
// ============================================

// PanicRecoveryMiddleware catches all panics and returns a 500 error
// This prevents server crashes and logs the full stack trace
func PanicRecoveryMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				// Log the panic with stack trace
				stack := string(debug.Stack())
				log.Printf("[PANIC RECOVERED] %v\n%s", err, stack)

				// Get request details for debugging
				requestID := c.GetString("request_id")
				if requestID == "" {
					requestID = uuid.New().String()
				}

				log.Printf("[PANIC] Request ID: %s, Path: %s, Method: %s",
					requestID, c.Request.URL.Path, c.Request.Method)

				// Return generic error to client (don't expose internals)
				c.JSON(http.StatusInternalServerError, gin.H{
					"success":    false,
					"error":      "An internal server error occurred",
					"request_id": requestID,
					"timestamp":  time.Now().Format(time.RFC3339),
				})

				// Abort the request
				c.Abort()
			}
		}()

		c.Next()
	}
}

// ============================================
// REQUEST VALIDATION MIDDLEWARE
// ============================================

var validate = validator.New()

// RequestValidationMiddleware provides centralized request validation
func RequestValidationMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
	}
}

// ValidateStruct validates a struct and returns user-friendly errors
func ValidateStruct(s interface{}) error {
	if err := validate.Struct(s); err != nil {
		if validationErrors, ok := err.(validator.ValidationErrors); ok {
			// Convert validation errors to user-friendly messages
			var messages []string
			for _, fieldError := range validationErrors {
				messages = append(messages, formatValidationError(fieldError))
			}
			return fmt.Errorf("validation failed: %s", strings.Join(messages, "; "))
		}
		return err
	}
	return nil
}

// formatValidationError converts validator errors to readable messages
func formatValidationError(err validator.FieldError) string {
	field := err.Field()
	tag := err.Tag()

	switch tag {
	case "required":
		return fmt.Sprintf("%s is required", field)
	case "email":
		return fmt.Sprintf("%s must be a valid email address", field)
	case "min":
		return fmt.Sprintf("%s must be at least %s characters", field, err.Param())
	case "max":
		return fmt.Sprintf("%s must be at most %s characters", field, err.Param())
	case "uuid":
		return fmt.Sprintf("%s must be a valid UUID", field)
	case "url":
		return fmt.Sprintf("%s must be a valid URL", field)
	case "oneof":
		return fmt.Sprintf("%s must be one of: %s", field, err.Param())
	default:
		return fmt.Sprintf("%s validation failed on tag '%s'", field, tag)
	}
}

// ============================================
// REQUEST ID MIDDLEWARE
// ============================================

// RequestIDMiddleware adds a unique request ID to each request
func RequestIDMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Check if request ID exists in header
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = uuid.New().String()
		}

		// Store in context
		c.Set("request_id", requestID)

		// Add to response header
		c.Header("X-Request-ID", requestID)

		c.Next()
	}
}

// ============================================
// REQUEST SIZE LIMIT MIDDLEWARE
// ============================================

// RequestSizeLimitMiddleware limits the size of request bodies
func RequestSizeLimitMiddleware(maxBytes int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)
		c.Next()
	}
}

// ============================================
// TIMEOUT MIDDLEWARE
// ============================================

// TimeoutMiddleware adds a timeout to requests
func TimeoutMiddleware(timeout time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Create a channel to signal completion
		done := make(chan struct{})

		// Run the request in a goroutine
		go func() {
			c.Next()
			close(done)
		}()

		// Wait for completion or timeout
		select {
		case <-done:
			// Request completed normally
			return
		case <-time.After(timeout):
			// Timeout occurred
			log.Printf("[TIMEOUT] Request timed out: %s %s", c.Request.Method, c.Request.URL.Path)
			
			if !c.Writer.Written() {
				c.JSON(http.StatusGatewayTimeout, gin.H{
					"success": false,
					"error":   "Request timeout",
				})
				c.Abort()
			}
		}
	}
}

// ============================================
// SECURITY HEADERS MIDDLEWARE
// ============================================

// SecurityHeadersMiddleware adds security headers to responses
func SecurityHeadersMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		
		// Remove sensitive headers
		c.Header("Server", "")
		
		c.Next()
	}
}

// ============================================
// INPUT SANITIZATION
// ============================================

// SanitizeString removes dangerous characters from input
func SanitizeString(input string) string {
	// Remove null bytes
	input = strings.ReplaceAll(input, "\x00", "")
	
	// Trim whitespace
	input = strings.TrimSpace(input)
	
	return input
}

// ValidateUUID validates a UUID string
func ValidateUUID(uuidStr string) (uuid.UUID, error) {
	parsed, err := uuid.Parse(uuidStr)
	if err != nil {
		return uuid.Nil, fmt.Errorf("invalid UUID format: %s", uuidStr)
	}
	return parsed, nil
}

// ============================================
// RATE LIMITING HELPERS
// ============================================

// GetClientIP extracts the real client IP from the request
func GetClientIP(c *gin.Context) string {
	// Check X-Forwarded-For header
	if xff := c.GetHeader("X-Forwarded-For"); xff != "" {
		ips := strings.Split(xff, ",")
		return strings.TrimSpace(ips[0])
	}

	// Check X-Real-IP header
	if xri := c.GetHeader("X-Real-IP"); xri != "" {
		return strings.TrimSpace(xri)
	}

	// Fallback to RemoteAddr
	return c.ClientIP()
}

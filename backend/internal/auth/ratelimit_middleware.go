package auth

import (
	"context"
	"net"
	"net/http"
	"strconv"
	"time"

	"histeeria-backend/internal/cache"

	"github.com/gin-gonic/gin"
)

// ============================================
// DISTRIBUTED RATE LIMIT MIDDLEWARE
// ============================================

// DistributedRateLimitMiddleware creates a middleware using the hybrid rate limiter
// Works with Redis (distributed) or in-memory (single server) automatically
func DistributedRateLimitMiddleware(limiter cache.RateLimiterInterface, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip rate limiting for WebSocket upgrade requests
		// WebSocket connections are long-lived and shouldn't be rate limited like HTTP requests
		if c.GetHeader("Upgrade") == "websocket" || c.GetHeader("Connection") == "Upgrade" {
			c.Next()
			return
		}

		// Extract IP address
		ip := extractClientIP(c)

		// Use IP-based rate limiting
		key := cache.IPRateLimitKey(ip)

		// Check rate limit
		allowed, remaining, resetTime := limiter.Allow(c.Request.Context(), key, limit, window)

		// Set rate limit headers (RFC 6585)
		c.Header("X-RateLimit-Limit", strconv.Itoa(limit))
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))

		// Add header indicating if distributed rate limiting is active
		if limiter.IsDistributed() {
			c.Header("X-RateLimit-Type", "distributed")
		} else {
			c.Header("X-RateLimit-Type", "local")
		}

		if !allowed {
			retryAfter := int(time.Until(resetTime).Seconds())
			if retryAfter < 0 {
				retryAfter = 0
			}

			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success":     false,
				"message":     "Too many requests. Please try again later.",
				"error":       "rate_limit_exceeded",
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// UserRateLimitMiddleware creates per-user rate limiting (requires authentication)
func UserRateLimitMiddleware(limiter cache.RateLimiterInterface, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get user ID from context (set by JWT middleware)
		userID, exists := c.Get("user_id")
		if !exists {
			// Fallback to IP-based if no user
			ip := extractClientIP(c)
			userID = ip
		}

		key := cache.UserRateLimitKey(userID.(string))

		allowed, remaining, resetTime := limiter.Allow(c.Request.Context(), key, limit, window)

		c.Header("X-RateLimit-Limit", strconv.Itoa(limit))
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))

		if !allowed {
			retryAfter := int(time.Until(resetTime).Seconds())
			if retryAfter < 0 {
				retryAfter = 0
			}

			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success":     false,
				"message":     "Too many requests. Please try again later.",
				"error":       "rate_limit_exceeded",
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// EndpointRateLimitMiddleware creates endpoint-specific rate limiting
func EndpointRateLimitMiddleware(limiter cache.RateLimiterInterface, endpoint string, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Combine user/IP with endpoint
		var key string

		userID, exists := c.Get("user_id")
		if exists {
			key = cache.APIRateLimitKey(userID.(string), endpoint)
		} else {
			ip := extractClientIP(c)
			key = cache.APIRateLimitKey(ip, endpoint)
		}

		allowed, remaining, resetTime := limiter.Allow(c.Request.Context(), key, limit, window)

		c.Header("X-RateLimit-Limit", strconv.Itoa(limit))
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))

		if !allowed {
			retryAfter := int(time.Until(resetTime).Seconds())
			if retryAfter < 0 {
				retryAfter = 0
			}

			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success":     false,
				"message":     "Too many requests for this endpoint. Please try again later.",
				"error":       "rate_limit_exceeded",
				"endpoint":    endpoint,
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// LoginRateLimitMiddleware creates strict rate limiting for login attempts
func LoginRateLimitMiddleware(limiter cache.RateLimiterInterface) gin.HandlerFunc {
	// 5 login attempts per 15 minutes per IP
	return func(c *gin.Context) {
		ip := extractClientIP(c)
		key := cache.LoginRateLimitKey(ip)

		// Strict limits for login: 5 attempts per 15 min
		allowed, remaining, resetTime := limiter.Allow(c.Request.Context(), key, 5, 15*time.Minute)

		c.Header("X-RateLimit-Limit", "5")
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))

		if !allowed {
			retryAfter := int(time.Until(resetTime).Seconds())
			if retryAfter < 0 {
				retryAfter = 0
			}

			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success":     false,
				"message":     "Too many login attempts. Please try again later.",
				"error":       "login_rate_limit_exceeded",
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// RegisterRateLimitMiddleware creates strict rate limiting for registration
func RegisterRateLimitMiddleware(limiter cache.RateLimiterInterface) gin.HandlerFunc {
	// 3 registration attempts per hour per IP
	return func(c *gin.Context) {
		ip := extractClientIP(c)
		key := cache.RegisterRateLimitKey(ip)

		allowed, remaining, resetTime := limiter.Allow(c.Request.Context(), key, 3, time.Hour)

		c.Header("X-RateLimit-Limit", "3")
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))

		if !allowed {
			retryAfter := int(time.Until(resetTime).Seconds())
			if retryAfter < 0 {
				retryAfter = 0
			}

			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success":     false,
				"message":     "Too many registration attempts. Please try again later.",
				"error":       "register_rate_limit_exceeded",
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// PasswordResetRateLimitMiddleware creates strict rate limiting for password reset
func PasswordResetRateLimitMiddleware(limiter cache.RateLimiterInterface) gin.HandlerFunc {
	// 3 password reset requests per hour per IP
	return func(c *gin.Context) {
		ip := extractClientIP(c)
		key := cache.PasswordResetRateLimitKey(ip)

		allowed, remaining, resetTime := limiter.Allow(c.Request.Context(), key, 3, time.Hour)

		c.Header("X-RateLimit-Limit", "3")
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))

		if !allowed {
			retryAfter := int(time.Until(resetTime).Seconds())
			if retryAfter < 0 {
				retryAfter = 0
			}

			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success":     false,
				"message":     "Too many password reset requests. Please try again later.",
				"error":       "password_reset_rate_limit_exceeded",
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// MessageRateLimitMiddleware creates rate limiting for message sending
func MessageRateLimitMiddleware(limiter cache.RateLimiterInterface) gin.HandlerFunc {
	// 60 messages per minute per user
	return func(c *gin.Context) {
		userID, exists := c.Get("user_id")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Authentication required",
				"error":   "unauthorized",
			})
			c.Abort()
			return
		}

		key := cache.MessageRateLimitKey(userID.(string))

		allowed, remaining, resetTime := limiter.Allow(c.Request.Context(), key, 60, time.Minute)

		c.Header("X-RateLimit-Limit", "60")
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))

		if !allowed {
			retryAfter := int(time.Until(resetTime).Seconds())
			if retryAfter < 0 {
				retryAfter = 0
			}

			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success":     false,
				"message":     "Message rate limit exceeded. Please slow down.",
				"error":       "message_rate_limit_exceeded",
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// ============================================
// LEGACY MIDDLEWARE (for backward compatibility)
// ============================================

// LegacyRateLimiter wraps the old utils.RateLimiter interface
type LegacyRateLimiter interface {
	Allow(ip string, limit int, window time.Duration) (bool, int, time.Time)
}

// RateLimitMiddleware creates a middleware using the legacy rate limiter
// Kept for backward compatibility
func RateLimitMiddleware(limit int, window time.Duration, rateLimiter LegacyRateLimiter) gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := extractClientIP(c)

		allowed, remaining, resetTime := rateLimiter.Allow(ip, limit, window)

		c.Header("X-RateLimit-Limit", strconv.Itoa(limit))
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))

		if !allowed {
			retryAfter := int(time.Until(resetTime).Seconds())
			if retryAfter < 0 {
				retryAfter = 0
			}

			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success":     false,
				"message":     "Too many requests. Please try again later.",
				"error":       "Rate limit exceeded",
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// ============================================
// HELPER FUNCTIONS
// ============================================

// extractClientIP extracts the real client IP from the request
func extractClientIP(c *gin.Context) string {
	// Check X-Forwarded-For header first (for proxies/load balancers)
	forwardedFor := c.GetHeader("X-Forwarded-For")
	if forwardedFor != "" {
		// Take the first IP (original client)
		ips := splitCommaIPs(forwardedFor)
		if len(ips) > 0 {
			return ips[0]
		}
	}

	// Check X-Real-IP header
	realIP := c.GetHeader("X-Real-IP")
	if realIP != "" {
		return realIP
	}

	// Fallback to RemoteAddr
	ip := c.ClientIP()
	if ip == "" {
		ip = c.RemoteIP()
	}

	// Strip port if present
	if host, _, err := net.SplitHostPort(ip); err == nil {
		return host
	}

	return ip
}

// splitCommaIPs splits comma-separated IPs
func splitCommaIPs(s string) []string {
	var result []string
	current := ""

	for _, char := range s {
		if char == ',' || char == ' ' {
			if current != "" {
				result = append(result, current)
				current = ""
			}
		} else {
			current += string(char)
		}
	}

	if current != "" {
		result = append(result, current)
	}

	return result
}

// ============================================
// RATE LIMIT CONFIGS
// ============================================

// RateLimitConfig holds rate limit configuration
type RateLimitConfig struct {
	GeneralLimit   int           // Requests per window for general API
	GeneralWindow  time.Duration // Window duration for general API
	LoginLimit     int           // Login attempts per window
	LoginWindow    time.Duration // Window duration for login
	RegisterLimit  int           // Registration attempts per window
	RegisterWindow time.Duration // Window duration for registration
	MessageLimit   int           // Messages per window
	MessageWindow  time.Duration // Window duration for messages
}

// DefaultRateLimitConfig returns sensible defaults
func DefaultRateLimitConfig() RateLimitConfig {
	return RateLimitConfig{
		GeneralLimit:   100,              // 100 requests
		GeneralWindow:  time.Minute,      // per minute
		LoginLimit:     5,                // 5 login attempts
		LoginWindow:    15 * time.Minute, // per 15 minutes
		RegisterLimit:  3,                // 3 registrations
		RegisterWindow: time.Hour,        // per hour
		MessageLimit:   60,               // 60 messages
		MessageWindow:  time.Minute,      // per minute
	}
}

// ============================================
// RATE LIMIT STATUS HANDLER
// ============================================

// GetRateLimitStatus returns current rate limit status for debugging
func GetRateLimitStatus(limiter cache.RateLimiterInterface) gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := extractClientIP(c)

		config := DefaultRateLimitConfig()

		// Get remaining for each limit type
		generalRemaining := limiter.GetRemaining(
			context.Background(),
			cache.IPRateLimitKey(ip),
			config.GeneralLimit,
			config.GeneralWindow,
		)

		loginRemaining := limiter.GetRemaining(
			context.Background(),
			cache.LoginRateLimitKey(ip),
			config.LoginLimit,
			config.LoginWindow,
		)

		c.JSON(http.StatusOK, gin.H{
			"ip":          ip,
			"distributed": limiter.IsDistributed(),
			"limits": gin.H{
				"general": gin.H{
					"limit":     config.GeneralLimit,
					"remaining": generalRemaining,
					"window":    config.GeneralWindow.String(),
				},
				"login": gin.H{
					"limit":     config.LoginLimit,
					"remaining": loginRemaining,
					"window":    config.LoginWindow.String(),
				},
			},
		})
	}
}

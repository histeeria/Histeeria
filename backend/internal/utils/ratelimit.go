package utils

import (
	"net"
	"sync"
	"time"
)

// RateLimiter implements in-memory rate limiting with token bucket algorithm
// and forgiveness mechanism for handling legitimate errors
type RateLimiter struct {
	entries      sync.Map // map[string]*LimitEntry
	forgiveness  int      // Number of extra requests allowed beyond limit
	cleanupStop  chan struct{}
	cleanupMutex sync.Mutex
}

// LimitEntry stores rate limit state for a single IP address
type LimitEntry struct {
	tokens          int           // Current tokens in bucket
	lastRefill      time.Time     // Last time tokens were refilled
	forgivenessUsed int           // Number of forgiveness requests used
	window          time.Duration // Rate limit window duration
	limit           int           // Maximum tokens (rate limit)
	mutex           sync.Mutex
}

// NewRateLimiter creates a new rate limiter with forgiveness support
func NewRateLimiter(forgiveness int) *RateLimiter {
	rl := &RateLimiter{
		forgiveness: forgiveness,
		cleanupStop: make(chan struct{}),
	}

	// Start cleanup goroutine to remove expired entries
	go rl.startCleanup()

	return rl
}

// Allow checks if a request from the given IP is allowed under the rate limit
// Returns: allowed, remaining tokens, reset time
func (rl *RateLimiter) Allow(ip string, limit int, window time.Duration) (bool, int, time.Time) {
	now := time.Now()

	// Get or create entry for this IP
	entryInterface, _ := rl.entries.LoadOrStore(ip, &LimitEntry{
		tokens:     limit,
		lastRefill: now,
		window:     window,
		limit:      limit,
	})

	entry := entryInterface.(*LimitEntry)
	entry.mutex.Lock()
	defer entry.mutex.Unlock()

	// Refill tokens based on time passed
	timeSinceRefill := now.Sub(entry.lastRefill)
	if timeSinceRefill > 0 {
		// Calculate how many tokens to add based on refill rate
		refillRate := window / time.Duration(limit) // Time per token
		tokensToAdd := int(timeSinceRefill / refillRate)

		if tokensToAdd > 0 {
			entry.tokens = min(entry.limit, entry.tokens+tokensToAdd)
			entry.lastRefill = now
			// Reset forgiveness if tokens are available
			if entry.tokens > 0 {
				entry.forgivenessUsed = 0
			}
		}
	}

	// Calculate reset time
	resetTime := entry.lastRefill.Add(window)

	// Check if we have tokens available
	if entry.tokens > 0 {
		entry.tokens--
		return true, entry.tokens, resetTime
	}

	// No tokens, check if forgiveness is available
	if entry.forgivenessUsed < rl.forgiveness {
		entry.forgivenessUsed++
		return true, 0, resetTime // Allowed via forgiveness, but no tokens remaining
	}

	// Both tokens and forgiveness exhausted
	return false, 0, resetTime
}

// GetRemaining returns the remaining tokens for an IP without consuming
func (rl *RateLimiter) GetRemaining(ip string, limit int, window time.Duration) int {
	entryInterface, ok := rl.entries.Load(ip)
	if !ok {
		return limit
	}

	entry := entryInterface.(*LimitEntry)
	entry.mutex.Lock()
	defer entry.mutex.Unlock()

	// Refill tokens
	now := time.Now()
	timeSinceRefill := now.Sub(entry.lastRefill)
	if timeSinceRefill > 0 {
		refillRate := window / time.Duration(limit)
		tokensToAdd := int(timeSinceRefill / refillRate)
		if tokensToAdd > 0 {
			entry.tokens = min(entry.limit, entry.tokens+tokensToAdd)
			entry.lastRefill = now
		}
	}

	return max(0, entry.tokens)
}

// startCleanup runs periodic cleanup to remove expired entries
func (rl *RateLimiter) startCleanup() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			rl.cleanup()
		case <-rl.cleanupStop:
			return
		}
	}
}

// cleanup removes entries that haven't been accessed in 2x the window duration
func (rl *RateLimiter) cleanup() {
	now := time.Now()

	rl.entries.Range(func(key, value interface{}) bool {
		entry := value.(*LimitEntry)
		entry.mutex.Lock()
		lastAccess := entry.lastRefill
		window := entry.window
		entry.mutex.Unlock()

		// Remove entries that haven't been accessed in 2x the window
		if now.Sub(lastAccess) > 2*window {
			rl.entries.Delete(key)
		}
		return true
	})
}

// Stop stops the cleanup goroutine (useful for testing or graceful shutdown)
func (rl *RateLimiter) Stop() {
	rl.cleanupMutex.Lock()
	defer rl.cleanupMutex.Unlock()

	select {
	case <-rl.cleanupStop:
		// Already closed
	default:
		close(rl.cleanupStop)
	}
}

// extractIP extracts the real IP address from the request
// Handles X-Forwarded-For header for proxies and load balancers
func ExtractIP(remoteAddr, forwardedFor string) string {
	// Check X-Forwarded-For header first (for proxies/load balancers)
	if forwardedFor != "" {
		// X-Forwarded-For can contain multiple IPs, take the first one
		ips := splitIPs(forwardedFor)
		if len(ips) > 0 {
			return ips[0]
		}
	}

	// Fallback to RemoteAddr
	if remoteAddr != "" {
		host, _, err := net.SplitHostPort(remoteAddr)
		if err == nil {
			return host
		}
		return remoteAddr
	}

	return "unknown"
}

// splitIPs splits comma-separated IP addresses
func splitIPs(ipString string) []string {
	var ips []string
	current := ""

	for _, char := range ipString {
		if char == ',' || char == ' ' {
			if current != "" {
				ips = append(ips, current)
				current = ""
			}
		} else {
			current += string(char)
		}
	}

	if current != "" {
		ips = append(ips, current)
	}

	return ips
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// max returns the maximum of two integers
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

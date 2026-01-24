package cache

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/go-redis/redis/v8"
)

// ============================================
// UNIFIED RATE LIMITER INTERFACE
// ============================================

// RateLimiterInterface defines the contract for rate limiting
// Can be implemented by both distributed (Redis) and local (in-memory) limiters
type RateLimiterInterface interface {
	// Allow checks if a request is allowed under the rate limit
	// Returns: allowed, remaining, resetTime
	Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, int, time.Time)

	// AllowWithForgiveness adds burst capacity for legitimate spikes
	AllowWithForgiveness(ctx context.Context, key string, limit int, window time.Duration, forgiveness int) (bool, int, time.Time)

	// GetRemaining returns remaining requests without consuming
	GetRemaining(ctx context.Context, key string, limit int, window time.Duration) int

	// Reset clears the rate limit for a key
	Reset(ctx context.Context, key string) error

	// IsDistributed returns true if this limiter works across multiple servers
	IsDistributed() bool
}

// ============================================
// DISTRIBUTED RATE LIMITER (Redis-based)
// ============================================

// DistributedRateLimiter implements Redis-based rate limiting with sliding window
// Works across multiple server instances (distributed deployments)
type DistributedRateLimiter struct {
	redis     *redis.Client
	keyPrefix string
}

// NewDistributedRateLimiter creates a new Redis-based rate limiter
func NewDistributedRateLimiter(redisClient *redis.Client) *DistributedRateLimiter {
	return &DistributedRateLimiter{
		redis:     redisClient,
		keyPrefix: "ratelimit:",
	}
}

// NewDistributedRateLimiterFromProvider creates a rate limiter from a RedisProvider
func NewDistributedRateLimiterFromProvider(provider *RedisProvider) *DistributedRateLimiter {
	if provider == nil || !provider.IsAvailable() {
		return nil
	}
	return &DistributedRateLimiter{
		redis:     provider.GetClient(),
		keyPrefix: "ratelimit:",
	}
}

// Allow checks if a request is allowed under the rate limit
// Uses sliding window log algorithm for accuracy
func (rl *DistributedRateLimiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, int, time.Time) {
	if rl.redis == nil {
		// Fallback: allow all requests (should not happen if properly initialized)
		return true, limit, time.Now().Add(window)
	}

	now := time.Now()
	windowStart := now.Add(-window)
	resetTime := now.Add(window)

	redisKey := fmt.Sprintf("%s%s", rl.keyPrefix, key)

	// Lua script for atomic sliding window rate limiting
	// This is much more efficient than multiple Redis commands
	script := redis.NewScript(`
		local key = KEYS[1]
		local now = tonumber(ARGV[1])
		local window_start = tonumber(ARGV[2])
		local limit = tonumber(ARGV[3])
		local window_ms = tonumber(ARGV[4])

		-- Remove expired entries (outside the window)
		redis.call('ZREMRANGEBYSCORE', key, '-inf', window_start)

		-- Count current requests in window
		local current = redis.call('ZCARD', key)

		if current < limit then
			-- Add new request with timestamp as score
			redis.call('ZADD', key, now, now .. '-' .. math.random(1000000))
			-- Set expiry on the key
			redis.call('PEXPIRE', key, window_ms)
			return {1, limit - current - 1}  -- allowed, remaining
		else
			return {0, 0}  -- not allowed, no remaining
		end
	`)

	result, err := script.Run(ctx, rl.redis, []string{redisKey},
		now.UnixMilli(),
		windowStart.UnixMilli(),
		limit,
		window.Milliseconds(),
	).Result()

	if err != nil {
		// Redis error - allow request but log warning
		return true, limit, resetTime
	}

	// Parse result
	res := result.([]interface{})
	allowed := res[0].(int64) == 1
	remaining := int(res[1].(int64))

	return allowed, remaining, resetTime
}

// AllowWithForgiveness adds forgiveness for legitimate burst traffic
func (rl *DistributedRateLimiter) AllowWithForgiveness(ctx context.Context, key string, limit int, window time.Duration, forgiveness int) (bool, int, time.Time) {
	// Try normal rate limit first
	allowed, remaining, resetTime := rl.Allow(ctx, key, limit, window)

	if allowed {
		return true, remaining, resetTime
	}

	// Check forgiveness bucket
	if forgiveness > 0 {
		forgivenessKey := key + ":forgiveness"
		forgivenessAllowed, forgivenessRemaining, _ := rl.Allow(ctx, forgivenessKey, forgiveness, window)
		if forgivenessAllowed {
			return true, forgivenessRemaining, resetTime
		}
	}

	return false, 0, resetTime
}

// GetRemaining returns remaining requests without consuming
func (rl *DistributedRateLimiter) GetRemaining(ctx context.Context, key string, limit int, window time.Duration) int {
	if rl.redis == nil {
		return limit
	}

	now := time.Now()
	windowStart := now.Add(-window)
	redisKey := fmt.Sprintf("%s%s", rl.keyPrefix, key)

	// Remove expired and count
	rl.redis.ZRemRangeByScore(ctx, redisKey, "-inf", fmt.Sprintf("%d", windowStart.UnixMilli()))
	count, err := rl.redis.ZCard(ctx, redisKey).Result()
	if err != nil {
		return limit
	}

	remaining := limit - int(count)
	if remaining < 0 {
		remaining = 0
	}

	return remaining
}

// Reset clears the rate limit for a key
func (rl *DistributedRateLimiter) Reset(ctx context.Context, key string) error {
	if rl.redis == nil {
		return nil
	}

	redisKey := fmt.Sprintf("%s%s", rl.keyPrefix, key)
	return rl.redis.Del(ctx, redisKey).Err()
}

// IsDistributed returns true for Redis-based limiter
func (rl *DistributedRateLimiter) IsDistributed() bool {
	return true
}

// ============================================
// IN-MEMORY RATE LIMITER (Single Server)
// ============================================

// InMemoryRateLimiter implements rate limiting for single-server deployments
type InMemoryRateLimiter struct {
	entries     sync.Map // map[string]*limitEntry
	forgiveness int
	cleanupStop chan struct{}
}

type limitEntry struct {
	tokens          int
	lastRefill      time.Time
	forgivenessUsed int
	window          time.Duration
	limit           int
	mutex           sync.Mutex
}

// NewInMemoryRateLimiter creates a new in-memory rate limiter
func NewInMemoryRateLimiter(forgiveness int) *InMemoryRateLimiter {
	rl := &InMemoryRateLimiter{
		forgiveness: forgiveness,
		cleanupStop: make(chan struct{}),
	}

	// Start cleanup goroutine
	go rl.startCleanup()

	return rl
}

// Allow checks if a request is allowed
func (rl *InMemoryRateLimiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, int, time.Time) {
	now := time.Now()

	// Get or create entry
	entryInterface, _ := rl.entries.LoadOrStore(key, &limitEntry{
		tokens:     limit,
		lastRefill: now,
		window:     window,
		limit:      limit,
	})

	entry := entryInterface.(*limitEntry)
	entry.mutex.Lock()
	defer entry.mutex.Unlock()

	// Refill tokens
	timeSinceRefill := now.Sub(entry.lastRefill)
	if timeSinceRefill > 0 {
		refillRate := window / time.Duration(limit)
		tokensToAdd := int(timeSinceRefill / refillRate)

		if tokensToAdd > 0 {
			entry.tokens = min(entry.limit, entry.tokens+tokensToAdd)
			entry.lastRefill = now
			if entry.tokens > 0 {
				entry.forgivenessUsed = 0
			}
		}
	}

	resetTime := entry.lastRefill.Add(window)

	if entry.tokens > 0 {
		entry.tokens--
		return true, entry.tokens, resetTime
	}

	return false, 0, resetTime
}

// AllowWithForgiveness adds forgiveness for burst traffic
func (rl *InMemoryRateLimiter) AllowWithForgiveness(ctx context.Context, key string, limit int, window time.Duration, forgiveness int) (bool, int, time.Time) {
	allowed, remaining, resetTime := rl.Allow(ctx, key, limit, window)

	if allowed {
		return true, remaining, resetTime
	}

	// Check internal forgiveness
	entryInterface, ok := rl.entries.Load(key)
	if !ok {
		return false, 0, resetTime
	}

	entry := entryInterface.(*limitEntry)
	entry.mutex.Lock()
	defer entry.mutex.Unlock()

	if entry.forgivenessUsed < forgiveness {
		entry.forgivenessUsed++
		return true, 0, resetTime
	}

	return false, 0, resetTime
}

// GetRemaining returns remaining requests without consuming
func (rl *InMemoryRateLimiter) GetRemaining(ctx context.Context, key string, limit int, window time.Duration) int {
	entryInterface, ok := rl.entries.Load(key)
	if !ok {
		return limit
	}

	entry := entryInterface.(*limitEntry)
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

	if entry.tokens < 0 {
		return 0
	}
	return entry.tokens
}

// Reset clears the rate limit for a key
func (rl *InMemoryRateLimiter) Reset(ctx context.Context, key string) error {
	rl.entries.Delete(key)
	return nil
}

// IsDistributed returns false for in-memory limiter
func (rl *InMemoryRateLimiter) IsDistributed() bool {
	return false
}

// startCleanup runs periodic cleanup
func (rl *InMemoryRateLimiter) startCleanup() {
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

// cleanup removes expired entries
func (rl *InMemoryRateLimiter) cleanup() {
	now := time.Now()

	rl.entries.Range(func(key, value interface{}) bool {
		entry := value.(*limitEntry)
		entry.mutex.Lock()
		lastAccess := entry.lastRefill
		window := entry.window
		entry.mutex.Unlock()

		if now.Sub(lastAccess) > 2*window {
			rl.entries.Delete(key)
		}
		return true
	})
}

// Stop stops the cleanup goroutine
func (rl *InMemoryRateLimiter) Stop() {
	select {
	case <-rl.cleanupStop:
		// Already closed
	default:
		close(rl.cleanupStop)
	}
}

// ============================================
// HYBRID RATE LIMITER (Auto-selects best option)
// ============================================

// HybridRateLimiter uses Redis when available, falls back to in-memory
type HybridRateLimiter struct {
	distributed *DistributedRateLimiter
	inmemory    *InMemoryRateLimiter
}

// NewHybridRateLimiter creates a rate limiter that uses Redis when available
func NewHybridRateLimiter(redisClient *redis.Client, forgiveness int) *HybridRateLimiter {
	rl := &HybridRateLimiter{
		inmemory: NewInMemoryRateLimiter(forgiveness),
	}

	if redisClient != nil {
		rl.distributed = NewDistributedRateLimiter(redisClient)
	}

	return rl
}

// NewHybridRateLimiterFromProvider creates from a RedisProvider
func NewHybridRateLimiterFromProvider(provider *RedisProvider, forgiveness int) *HybridRateLimiter {
	rl := &HybridRateLimiter{
		inmemory: NewInMemoryRateLimiter(forgiveness),
	}

	if provider != nil && provider.IsAvailable() {
		rl.distributed = NewDistributedRateLimiterFromProvider(provider)
	}

	return rl
}

// Allow checks rate limit using best available limiter
func (rl *HybridRateLimiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, int, time.Time) {
	if rl.distributed != nil {
		return rl.distributed.Allow(ctx, key, limit, window)
	}
	return rl.inmemory.Allow(ctx, key, limit, window)
}

// AllowWithForgiveness adds forgiveness
func (rl *HybridRateLimiter) AllowWithForgiveness(ctx context.Context, key string, limit int, window time.Duration, forgiveness int) (bool, int, time.Time) {
	if rl.distributed != nil {
		return rl.distributed.AllowWithForgiveness(ctx, key, limit, window, forgiveness)
	}
	return rl.inmemory.AllowWithForgiveness(ctx, key, limit, window, forgiveness)
}

// GetRemaining returns remaining without consuming
func (rl *HybridRateLimiter) GetRemaining(ctx context.Context, key string, limit int, window time.Duration) int {
	if rl.distributed != nil {
		return rl.distributed.GetRemaining(ctx, key, limit, window)
	}
	return rl.inmemory.GetRemaining(ctx, key, limit, window)
}

// Reset clears rate limit for a key
func (rl *HybridRateLimiter) Reset(ctx context.Context, key string) error {
	if rl.distributed != nil {
		return rl.distributed.Reset(ctx, key)
	}
	return rl.inmemory.Reset(ctx, key)
}

// IsDistributed returns true if using Redis
func (rl *HybridRateLimiter) IsDistributed() bool {
	return rl.distributed != nil
}

// Stop cleans up resources
func (rl *HybridRateLimiter) Stop() {
	rl.inmemory.Stop()
}

// ============================================
// RATE LIMIT KEY HELPERS
// ============================================

// LoginRateLimitKey creates a key for login attempts
func LoginRateLimitKey(ip string) string {
	return fmt.Sprintf("login:%s", ip)
}

// RegisterRateLimitKey creates a key for registration
func RegisterRateLimitKey(ip string) string {
	return fmt.Sprintf("register:%s", ip)
}

// PasswordResetRateLimitKey creates a key for password reset
func PasswordResetRateLimitKey(ip string) string {
	return fmt.Sprintf("reset:%s", ip)
}

// APIRateLimitKey creates a key for general API requests
func APIRateLimitKey(userID, endpoint string) string {
	return fmt.Sprintf("api:%s:%s", userID, endpoint)
}

// MessageRateLimitKey creates a key for message sending
func MessageRateLimitKey(userID string) string {
	return fmt.Sprintf("message:%s", userID)
}

// IPRateLimitKey creates a key for IP-based rate limiting
func IPRateLimitKey(ip string) string {
	return fmt.Sprintf("ip:%s", ip)
}

// UserRateLimitKey creates a key for user-based rate limiting
func UserRateLimitKey(userID string) string {
	return fmt.Sprintf("user:%s", userID)
}

// min helper
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

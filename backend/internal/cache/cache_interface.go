package cache

import (
	"context"
	"time"
)

// CacheProvider is the interface that any cache implementation must satisfy
// This allows switching between Redis, Memcached, in-memory, or any other cache
type CacheProvider interface {
	// Basic operations
	Get(ctx context.Context, key string) (string, error)
	Set(ctx context.Context, key string, value string, ttl time.Duration) error
	Delete(ctx context.Context, key string) error
	Exists(ctx context.Context, key string) (bool, error)

	// Batch operations
	MGet(ctx context.Context, keys []string) ([]string, error)
	MSet(ctx context.Context, items map[string]string, ttl time.Duration) error
	MDelete(ctx context.Context, keys []string) error

	// List operations
	LPush(ctx context.Context, key string, values ...string) error
	LRange(ctx context.Context, key string, start, stop int64) ([]string, error)
	LTrim(ctx context.Context, key string, start, stop int64) error

	// Hash operations
	HGet(ctx context.Context, key, field string) (string, error)
	HSet(ctx context.Context, key string, fields map[string]string) error
	HGetAll(ctx context.Context, key string) (map[string]string, error)
	HDel(ctx context.Context, key string, fields ...string) error
	HIncrBy(ctx context.Context, key, field string, incr int64) (int64, error)

	// Atomic operations
	Incr(ctx context.Context, key string) (int64, error)
	Decr(ctx context.Context, key string) (int64, error)
	SetNX(ctx context.Context, key string, value string, ttl time.Duration) (bool, error)

	// TTL operations
	Expire(ctx context.Context, key string, ttl time.Duration) error
	TTL(ctx context.Context, key string) (time.Duration, error)

	// Pattern operations
	Keys(ctx context.Context, pattern string) ([]string, error)
	Scan(ctx context.Context, cursor uint64, pattern string, count int64) ([]string, uint64, error)

	// Pub/Sub (for distributed WebSocket)
	Publish(ctx context.Context, channel string, message string) error
	Subscribe(ctx context.Context, channels ...string) (Subscription, error)

	// Health
	Ping(ctx context.Context) error
	Close() error

	// Info
	IsAvailable() bool
}

// Subscription represents a pub/sub subscription
type Subscription interface {
	Channel() <-chan Message
	Close() error
}

// Message represents a pub/sub message
type Message struct {
	Channel string
	Payload string
}

// ErrCacheMiss is returned when a key is not found in cache
var ErrCacheMiss = &CacheError{Code: "CACHE_MISS", Message: "key not found in cache"}

// ErrCacheUnavailable is returned when cache is not available
var ErrCacheUnavailable = &CacheError{Code: "CACHE_UNAVAILABLE", Message: "cache service unavailable"}

// CacheError represents a cache-specific error
type CacheError struct {
	Code    string
	Message string
	Err     error
}

func (e *CacheError) Error() string {
	if e.Err != nil {
		return e.Message + ": " + e.Err.Error()
	}
	return e.Message
}

func (e *CacheError) Unwrap() error {
	return e.Err
}

// IsCacheMiss returns true if the error is a cache miss
func IsCacheMiss(err error) bool {
	if err == nil {
		return false
	}
	if ce, ok := err.(*CacheError); ok {
		return ce.Code == "CACHE_MISS"
	}
	return false
}

// IsCacheUnavailable returns true if the cache service is unavailable
func IsCacheUnavailable(err error) bool {
	if err == nil {
		return false
	}
	if ce, ok := err.(*CacheError); ok {
		return ce.Code == "CACHE_UNAVAILABLE"
	}
	return false
}

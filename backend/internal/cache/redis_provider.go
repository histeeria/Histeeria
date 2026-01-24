package cache

import (
	"context"
	"crypto/tls"
	"fmt"
	"time"

	"github.com/go-redis/redis/v8"
)

// RedisProvider implements CacheProvider using Redis
type RedisProvider struct {
	client    *redis.Client
	available bool
}

// RedisConfig holds Redis configuration
type RedisConfig struct {
	Host      string
	Port      string
	Password  string
	DB        int
	PoolSize  int
	EnableTLS bool // For cloud providers like Upstash
}

// NewRedisProvider creates a new Redis cache provider
func NewRedisProvider(cfg *RedisConfig) (*RedisProvider, error) {
	if cfg.PoolSize == 0 {
		cfg.PoolSize = 10
	}

	opts := &redis.Options{
		Addr:     fmt.Sprintf("%s:%s", cfg.Host, cfg.Port),
		Password: cfg.Password,
		DB:       cfg.DB,
		PoolSize: cfg.PoolSize,
	}

	// Enable TLS for cloud Redis providers (Upstash, Redis Cloud, etc.)
	if cfg.EnableTLS {
		opts.TLSConfig = &tls.Config{
			MinVersion: tls.VersionTLS12,
		}
	}

	client := redis.NewClient(opts)

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return &RedisProvider{client: client, available: false}, nil
	}

	return &RedisProvider{client: client, available: true}, nil
}

// ============================================
// BASIC OPERATIONS
// ============================================

func (r *RedisProvider) Get(ctx context.Context, key string) (string, error) {
	if !r.available {
		return "", ErrCacheUnavailable
	}

	val, err := r.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return "", ErrCacheMiss
	}
	if err != nil {
		return "", &CacheError{Code: "GET_ERROR", Message: "failed to get key", Err: err}
	}
	return val, nil
}

func (r *RedisProvider) Set(ctx context.Context, key string, value string, ttl time.Duration) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	if err := r.client.Set(ctx, key, value, ttl).Err(); err != nil {
		return &CacheError{Code: "SET_ERROR", Message: "failed to set key", Err: err}
	}
	return nil
}

func (r *RedisProvider) Delete(ctx context.Context, key string) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	if err := r.client.Del(ctx, key).Err(); err != nil {
		return &CacheError{Code: "DELETE_ERROR", Message: "failed to delete key", Err: err}
	}
	return nil
}

func (r *RedisProvider) Exists(ctx context.Context, key string) (bool, error) {
	if !r.available {
		return false, ErrCacheUnavailable
	}

	count, err := r.client.Exists(ctx, key).Result()
	if err != nil {
		return false, &CacheError{Code: "EXISTS_ERROR", Message: "failed to check key existence", Err: err}
	}
	return count > 0, nil
}

// ============================================
// BATCH OPERATIONS
// ============================================

func (r *RedisProvider) MGet(ctx context.Context, keys []string) ([]string, error) {
	if !r.available {
		return nil, ErrCacheUnavailable
	}

	vals, err := r.client.MGet(ctx, keys...).Result()
	if err != nil {
		return nil, &CacheError{Code: "MGET_ERROR", Message: "failed to get multiple keys", Err: err}
	}

	result := make([]string, len(vals))
	for i, v := range vals {
		if v != nil {
			result[i] = v.(string)
		}
	}
	return result, nil
}

func (r *RedisProvider) MSet(ctx context.Context, items map[string]string, ttl time.Duration) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	pipe := r.client.Pipeline()
	for k, v := range items {
		pipe.Set(ctx, k, v, ttl)
	}
	_, err := pipe.Exec(ctx)
	if err != nil {
		return &CacheError{Code: "MSET_ERROR", Message: "failed to set multiple keys", Err: err}
	}
	return nil
}

func (r *RedisProvider) MDelete(ctx context.Context, keys []string) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	if err := r.client.Del(ctx, keys...).Err(); err != nil {
		return &CacheError{Code: "MDELETE_ERROR", Message: "failed to delete multiple keys", Err: err}
	}
	return nil
}

// ============================================
// LIST OPERATIONS
// ============================================

func (r *RedisProvider) LPush(ctx context.Context, key string, values ...string) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	args := make([]interface{}, len(values))
	for i, v := range values {
		args[i] = v
	}

	if err := r.client.LPush(ctx, key, args...).Err(); err != nil {
		return &CacheError{Code: "LPUSH_ERROR", Message: "failed to push to list", Err: err}
	}
	return nil
}

func (r *RedisProvider) LRange(ctx context.Context, key string, start, stop int64) ([]string, error) {
	if !r.available {
		return nil, ErrCacheUnavailable
	}

	vals, err := r.client.LRange(ctx, key, start, stop).Result()
	if err != nil {
		return nil, &CacheError{Code: "LRANGE_ERROR", Message: "failed to get list range", Err: err}
	}
	return vals, nil
}

func (r *RedisProvider) LTrim(ctx context.Context, key string, start, stop int64) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	if err := r.client.LTrim(ctx, key, start, stop).Err(); err != nil {
		return &CacheError{Code: "LTRIM_ERROR", Message: "failed to trim list", Err: err}
	}
	return nil
}

// ============================================
// HASH OPERATIONS
// ============================================

func (r *RedisProvider) HGet(ctx context.Context, key, field string) (string, error) {
	if !r.available {
		return "", ErrCacheUnavailable
	}

	val, err := r.client.HGet(ctx, key, field).Result()
	if err == redis.Nil {
		return "", ErrCacheMiss
	}
	if err != nil {
		return "", &CacheError{Code: "HGET_ERROR", Message: "failed to get hash field", Err: err}
	}
	return val, nil
}

func (r *RedisProvider) HSet(ctx context.Context, key string, fields map[string]string) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	args := make([]interface{}, 0, len(fields)*2)
	for k, v := range fields {
		args = append(args, k, v)
	}

	if err := r.client.HSet(ctx, key, args...).Err(); err != nil {
		return &CacheError{Code: "HSET_ERROR", Message: "failed to set hash fields", Err: err}
	}
	return nil
}

func (r *RedisProvider) HGetAll(ctx context.Context, key string) (map[string]string, error) {
	if !r.available {
		return nil, ErrCacheUnavailable
	}

	val, err := r.client.HGetAll(ctx, key).Result()
	if err != nil {
		return nil, &CacheError{Code: "HGETALL_ERROR", Message: "failed to get all hash fields", Err: err}
	}
	return val, nil
}

func (r *RedisProvider) HDel(ctx context.Context, key string, fields ...string) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	if err := r.client.HDel(ctx, key, fields...).Err(); err != nil {
		return &CacheError{Code: "HDEL_ERROR", Message: "failed to delete hash fields", Err: err}
	}
	return nil
}

func (r *RedisProvider) HIncrBy(ctx context.Context, key, field string, incr int64) (int64, error) {
	if !r.available {
		return 0, ErrCacheUnavailable
	}

	val, err := r.client.HIncrBy(ctx, key, field, incr).Result()
	if err != nil {
		return 0, &CacheError{Code: "HINCRBY_ERROR", Message: "failed to increment hash field", Err: err}
	}
	return val, nil
}

// ============================================
// ATOMIC OPERATIONS
// ============================================

func (r *RedisProvider) Incr(ctx context.Context, key string) (int64, error) {
	if !r.available {
		return 0, ErrCacheUnavailable
	}

	val, err := r.client.Incr(ctx, key).Result()
	if err != nil {
		return 0, &CacheError{Code: "INCR_ERROR", Message: "failed to increment key", Err: err}
	}
	return val, nil
}

func (r *RedisProvider) Decr(ctx context.Context, key string) (int64, error) {
	if !r.available {
		return 0, ErrCacheUnavailable
	}

	val, err := r.client.Decr(ctx, key).Result()
	if err != nil {
		return 0, &CacheError{Code: "DECR_ERROR", Message: "failed to decrement key", Err: err}
	}
	return val, nil
}

func (r *RedisProvider) SetNX(ctx context.Context, key string, value string, ttl time.Duration) (bool, error) {
	if !r.available {
		return false, ErrCacheUnavailable
	}

	ok, err := r.client.SetNX(ctx, key, value, ttl).Result()
	if err != nil {
		return false, &CacheError{Code: "SETNX_ERROR", Message: "failed to set if not exists", Err: err}
	}
	return ok, nil
}

// ============================================
// TTL OPERATIONS
// ============================================

func (r *RedisProvider) Expire(ctx context.Context, key string, ttl time.Duration) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	if err := r.client.Expire(ctx, key, ttl).Err(); err != nil {
		return &CacheError{Code: "EXPIRE_ERROR", Message: "failed to set expiry", Err: err}
	}
	return nil
}

func (r *RedisProvider) TTL(ctx context.Context, key string) (time.Duration, error) {
	if !r.available {
		return 0, ErrCacheUnavailable
	}

	ttl, err := r.client.TTL(ctx, key).Result()
	if err != nil {
		return 0, &CacheError{Code: "TTL_ERROR", Message: "failed to get TTL", Err: err}
	}
	return ttl, nil
}

// ============================================
// PATTERN OPERATIONS
// ============================================

func (r *RedisProvider) Keys(ctx context.Context, pattern string) ([]string, error) {
	if !r.available {
		return nil, ErrCacheUnavailable
	}

	keys, err := r.client.Keys(ctx, pattern).Result()
	if err != nil {
		return nil, &CacheError{Code: "KEYS_ERROR", Message: "failed to get keys", Err: err}
	}
	return keys, nil
}

func (r *RedisProvider) Scan(ctx context.Context, cursor uint64, pattern string, count int64) ([]string, uint64, error) {
	if !r.available {
		return nil, 0, ErrCacheUnavailable
	}

	keys, newCursor, err := r.client.Scan(ctx, cursor, pattern, count).Result()
	if err != nil {
		return nil, 0, &CacheError{Code: "SCAN_ERROR", Message: "failed to scan keys", Err: err}
	}
	return keys, newCursor, nil
}

// ============================================
// PUB/SUB
// ============================================

func (r *RedisProvider) Publish(ctx context.Context, channel string, message string) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	if err := r.client.Publish(ctx, channel, message).Err(); err != nil {
		return &CacheError{Code: "PUBLISH_ERROR", Message: "failed to publish message", Err: err}
	}
	return nil
}

func (r *RedisProvider) Subscribe(ctx context.Context, channels ...string) (Subscription, error) {
	if !r.available {
		return nil, ErrCacheUnavailable
	}

	pubsub := r.client.Subscribe(ctx, channels...)
	return &RedisSubscription{pubsub: pubsub}, nil
}

// RedisSubscription implements Subscription for Redis
type RedisSubscription struct {
	pubsub  *redis.PubSub
	msgChan chan Message
	done    chan struct{}
}

func (s *RedisSubscription) Channel() <-chan Message {
	if s.msgChan != nil {
		return s.msgChan
	}

	s.msgChan = make(chan Message, 100)
	s.done = make(chan struct{})

	go func() {
		ch := s.pubsub.Channel()
		for {
			select {
			case msg, ok := <-ch:
				if !ok {
					close(s.msgChan)
					return
				}
				s.msgChan <- Message{
					Channel: msg.Channel,
					Payload: msg.Payload,
				}
			case <-s.done:
				return
			}
		}
	}()

	return s.msgChan
}

func (s *RedisSubscription) Close() error {
	close(s.done)
	return s.pubsub.Close()
}

// ============================================
// HEALTH & LIFECYCLE
// ============================================

func (r *RedisProvider) Ping(ctx context.Context) error {
	if !r.available {
		return ErrCacheUnavailable
	}

	if err := r.client.Ping(ctx).Err(); err != nil {
		r.available = false
		return &CacheError{Code: "PING_ERROR", Message: "failed to ping Redis", Err: err}
	}
	return nil
}

func (r *RedisProvider) Close() error {
	if r.client != nil {
		return r.client.Close()
	}
	return nil
}

func (r *RedisProvider) IsAvailable() bool {
	return r.available
}

// GetClient returns the underlying Redis client (for advanced use cases)
func (r *RedisProvider) GetClient() *redis.Client {
	return r.client
}

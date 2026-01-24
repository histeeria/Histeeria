package cache

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// MemoryProvider implements CacheProvider using in-memory storage
// Use for development, testing, or as a fallback when Redis is unavailable
// NOTE: This is single-instance only - not suitable for distributed deployments
type MemoryProvider struct {
	data    map[string]*memoryItem
	lists   map[string][]string
	hashes  map[string]map[string]string
	mu      sync.RWMutex
	pubsub  *memoryPubSub
}

type memoryItem struct {
	value   string
	expires time.Time
}

type memoryPubSub struct {
	subscribers map[string][]chan Message
	mu          sync.RWMutex
}

// NewMemoryProvider creates a new in-memory cache provider
func NewMemoryProvider() *MemoryProvider {
	m := &MemoryProvider{
		data:   make(map[string]*memoryItem),
		lists:  make(map[string][]string),
		hashes: make(map[string]map[string]string),
		pubsub: &memoryPubSub{
			subscribers: make(map[string][]chan Message),
		},
	}

	// Start cleanup goroutine
	go m.cleanup()

	return m
}

// cleanup removes expired items periodically
func (m *MemoryProvider) cleanup() {
	ticker := time.NewTicker(1 * time.Minute)
	for range ticker.C {
		m.mu.Lock()
		now := time.Now()
		for k, v := range m.data {
			if !v.expires.IsZero() && v.expires.Before(now) {
				delete(m.data, k)
			}
		}
		m.mu.Unlock()
	}
}

// ============================================
// BASIC OPERATIONS
// ============================================

func (m *MemoryProvider) Get(ctx context.Context, key string) (string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	item, ok := m.data[key]
	if !ok {
		return "", ErrCacheMiss
	}

	if !item.expires.IsZero() && item.expires.Before(time.Now()) {
		return "", ErrCacheMiss
	}

	return item.value, nil
}

func (m *MemoryProvider) Set(ctx context.Context, key string, value string, ttl time.Duration) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	var expires time.Time
	if ttl > 0 {
		expires = time.Now().Add(ttl)
	}

	m.data[key] = &memoryItem{
		value:   value,
		expires: expires,
	}
	return nil
}

func (m *MemoryProvider) Delete(ctx context.Context, key string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.data, key)
	delete(m.lists, key)
	delete(m.hashes, key)
	return nil
}

func (m *MemoryProvider) Exists(ctx context.Context, key string) (bool, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	item, ok := m.data[key]
	if !ok {
		return false, nil
	}

	if !item.expires.IsZero() && item.expires.Before(time.Now()) {
		return false, nil
	}

	return true, nil
}

// ============================================
// BATCH OPERATIONS
// ============================================

func (m *MemoryProvider) MGet(ctx context.Context, keys []string) ([]string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	result := make([]string, len(keys))
	now := time.Now()

	for i, key := range keys {
		if item, ok := m.data[key]; ok {
			if item.expires.IsZero() || item.expires.After(now) {
				result[i] = item.value
			}
		}
	}

	return result, nil
}

func (m *MemoryProvider) MSet(ctx context.Context, items map[string]string, ttl time.Duration) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	var expires time.Time
	if ttl > 0 {
		expires = time.Now().Add(ttl)
	}

	for k, v := range items {
		m.data[k] = &memoryItem{
			value:   v,
			expires: expires,
		}
	}

	return nil
}

func (m *MemoryProvider) MDelete(ctx context.Context, keys []string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, key := range keys {
		delete(m.data, key)
		delete(m.lists, key)
		delete(m.hashes, key)
	}

	return nil
}

// ============================================
// LIST OPERATIONS
// ============================================

func (m *MemoryProvider) LPush(ctx context.Context, key string, values ...string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, ok := m.lists[key]; !ok {
		m.lists[key] = make([]string, 0)
	}

	// Prepend values (reverse order to match Redis behavior)
	newList := make([]string, 0, len(values)+len(m.lists[key]))
	for i := len(values) - 1; i >= 0; i-- {
		newList = append(newList, values[i])
	}
	newList = append(newList, m.lists[key]...)
	m.lists[key] = newList

	return nil
}

func (m *MemoryProvider) LRange(ctx context.Context, key string, start, stop int64) ([]string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	list, ok := m.lists[key]
	if !ok {
		return []string{}, nil
	}

	length := int64(len(list))
	if start < 0 {
		start = length + start
	}
	if stop < 0 {
		stop = length + stop
	}

	if start < 0 {
		start = 0
	}
	if stop >= length {
		stop = length - 1
	}

	if start > stop || start >= length {
		return []string{}, nil
	}

	return list[start : stop+1], nil
}

func (m *MemoryProvider) LTrim(ctx context.Context, key string, start, stop int64) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	list, ok := m.lists[key]
	if !ok {
		return nil
	}

	length := int64(len(list))
	if start < 0 {
		start = length + start
	}
	if stop < 0 {
		stop = length + stop
	}

	if start < 0 {
		start = 0
	}
	if stop >= length {
		stop = length - 1
	}

	if start > stop || start >= length {
		m.lists[key] = []string{}
		return nil
	}

	m.lists[key] = list[start : stop+1]
	return nil
}

// ============================================
// HASH OPERATIONS
// ============================================

func (m *MemoryProvider) HGet(ctx context.Context, key, field string) (string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	hash, ok := m.hashes[key]
	if !ok {
		return "", ErrCacheMiss
	}

	value, ok := hash[field]
	if !ok {
		return "", ErrCacheMiss
	}

	return value, nil
}

func (m *MemoryProvider) HSet(ctx context.Context, key string, fields map[string]string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, ok := m.hashes[key]; !ok {
		m.hashes[key] = make(map[string]string)
	}

	for k, v := range fields {
		m.hashes[key][k] = v
	}

	return nil
}

func (m *MemoryProvider) HGetAll(ctx context.Context, key string) (map[string]string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	hash, ok := m.hashes[key]
	if !ok {
		return make(map[string]string), nil
	}

	// Return a copy
	result := make(map[string]string, len(hash))
	for k, v := range hash {
		result[k] = v
	}

	return result, nil
}

func (m *MemoryProvider) HDel(ctx context.Context, key string, fields ...string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	hash, ok := m.hashes[key]
	if !ok {
		return nil
	}

	for _, field := range fields {
		delete(hash, field)
	}

	return nil
}

func (m *MemoryProvider) HIncrBy(ctx context.Context, key, field string, incr int64) (int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, ok := m.hashes[key]; !ok {
		m.hashes[key] = make(map[string]string)
	}

	var current int64
	if val, ok := m.hashes[key][field]; ok {
		fmt.Sscanf(val, "%d", &current)
	}

	current += incr
	m.hashes[key][field] = fmt.Sprintf("%d", current)

	return current, nil
}

// ============================================
// ATOMIC OPERATIONS
// ============================================

func (m *MemoryProvider) Incr(ctx context.Context, key string) (int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	var current int64
	if item, ok := m.data[key]; ok {
		fmt.Sscanf(item.value, "%d", &current)
	}

	current++
	m.data[key] = &memoryItem{value: fmt.Sprintf("%d", current)}

	return current, nil
}

func (m *MemoryProvider) Decr(ctx context.Context, key string) (int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	var current int64
	if item, ok := m.data[key]; ok {
		fmt.Sscanf(item.value, "%d", &current)
	}

	current--
	m.data[key] = &memoryItem{value: fmt.Sprintf("%d", current)}

	return current, nil
}

func (m *MemoryProvider) SetNX(ctx context.Context, key string, value string, ttl time.Duration) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, ok := m.data[key]; ok {
		return false, nil
	}

	var expires time.Time
	if ttl > 0 {
		expires = time.Now().Add(ttl)
	}

	m.data[key] = &memoryItem{
		value:   value,
		expires: expires,
	}

	return true, nil
}

// ============================================
// TTL OPERATIONS
// ============================================

func (m *MemoryProvider) Expire(ctx context.Context, key string, ttl time.Duration) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if item, ok := m.data[key]; ok {
		item.expires = time.Now().Add(ttl)
	}

	return nil
}

func (m *MemoryProvider) TTL(ctx context.Context, key string) (time.Duration, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	item, ok := m.data[key]
	if !ok {
		return -2, nil // Key doesn't exist
	}

	if item.expires.IsZero() {
		return -1, nil // No expiry
	}

	ttl := time.Until(item.expires)
	if ttl < 0 {
		return -2, nil // Expired
	}

	return ttl, nil
}

// ============================================
// PATTERN OPERATIONS
// ============================================

func (m *MemoryProvider) Keys(ctx context.Context, pattern string) ([]string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	keys := make([]string, 0)
	for k := range m.data {
		if matchPattern(pattern, k) {
			keys = append(keys, k)
		}
	}

	return keys, nil
}

func (m *MemoryProvider) Scan(ctx context.Context, cursor uint64, pattern string, count int64) ([]string, uint64, error) {
	keys, err := m.Keys(ctx, pattern)
	if err != nil {
		return nil, 0, err
	}

	// Simple implementation - return all at once
	return keys, 0, nil
}

// matchPattern matches a key against a Redis-like pattern
func matchPattern(pattern, key string) bool {
	// Simple implementation - only supports * wildcard
	if pattern == "*" {
		return true
	}

	// Check if pattern starts/ends with *
	if len(pattern) > 0 && pattern[0] == '*' {
		suffix := pattern[1:]
		return len(key) >= len(suffix) && key[len(key)-len(suffix):] == suffix
	}

	if len(pattern) > 0 && pattern[len(pattern)-1] == '*' {
		prefix := pattern[:len(pattern)-1]
		return len(key) >= len(prefix) && key[:len(prefix)] == prefix
	}

	return pattern == key
}

// ============================================
// PUB/SUB
// ============================================

func (m *MemoryProvider) Publish(ctx context.Context, channel string, message string) error {
	m.pubsub.mu.RLock()
	subs := m.pubsub.subscribers[channel]
	m.pubsub.mu.RUnlock()

	for _, ch := range subs {
		select {
		case ch <- Message{Channel: channel, Payload: message}:
		default:
			// Channel full, skip
		}
	}

	return nil
}

func (m *MemoryProvider) Subscribe(ctx context.Context, channels ...string) (Subscription, error) {
	msgChan := make(chan Message, 100)

	m.pubsub.mu.Lock()
	for _, channel := range channels {
		if m.pubsub.subscribers[channel] == nil {
			m.pubsub.subscribers[channel] = make([]chan Message, 0)
		}
		m.pubsub.subscribers[channel] = append(m.pubsub.subscribers[channel], msgChan)
	}
	m.pubsub.mu.Unlock()

	return &memorySubscription{
		channels: channels,
		msgChan:  msgChan,
		pubsub:   m.pubsub,
	}, nil
}

type memorySubscription struct {
	channels []string
	msgChan  chan Message
	pubsub   *memoryPubSub
}

func (s *memorySubscription) Channel() <-chan Message {
	return s.msgChan
}

func (s *memorySubscription) Close() error {
	s.pubsub.mu.Lock()
	defer s.pubsub.mu.Unlock()

	for _, channel := range s.channels {
		subs := s.pubsub.subscribers[channel]
		for i, ch := range subs {
			if ch == s.msgChan {
				s.pubsub.subscribers[channel] = append(subs[:i], subs[i+1:]...)
				break
			}
		}
	}

	close(s.msgChan)
	return nil
}

// ============================================
// HEALTH & LIFECYCLE
// ============================================

func (m *MemoryProvider) Ping(ctx context.Context) error {
	return nil // Always available
}

func (m *MemoryProvider) Close() error {
	return nil
}

func (m *MemoryProvider) IsAvailable() bool {
	return true // Always available
}

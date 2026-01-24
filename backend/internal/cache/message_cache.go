package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"histeeria-backend/internal/models"

	"github.com/go-redis/redis/v8"
	"github.com/google/uuid"
)

// MessageCacheService handles caching for messaging system
type MessageCacheService struct {
	redis *redis.Client
}

// NewMessageCacheService creates a new message cache service
func NewMessageCacheService(redisClient *redis.Client) *MessageCacheService {
	return &MessageCacheService{
		redis: redisClient,
	}
}

// Redis key patterns
const (
	// Message caching - stores last 20 messages per conversation
	keyConversationMessages = "msg:conv:%s" // LIST

	// Conversation list caching - stores user's conversation list
	keyUserConversations = "conv:list:%s" // STRING (JSON)

	// Presence tracking - online status and last seen
	keyUserPresence = "presence:%s" // HASH (is_online, last_seen)

	// Typing indicators - short-lived keys
	keyTyping = "typing:%s:%s" // STRING (3s TTL), conversation_id:user_id

	// Unread counts - per conversation per user
	keyUnreadCounts = "unread:%s" // HASH (conversation_id -> count)
)

// ============================================
// MESSAGE CACHING
// ============================================

// CacheMessages caches the last 20 messages for a conversation
func (s *MessageCacheService) CacheMessages(ctx context.Context, conversationID uuid.UUID, messages []*models.Message) error {
	if len(messages) == 0 {
		return nil
	}

	key := fmt.Sprintf(keyConversationMessages, conversationID.String())

	// Delete existing cache
	s.redis.Del(ctx, key)

	// Add messages to list (newest first)
	for i := len(messages) - 1; i >= 0; i-- {
		msgJSON, err := json.Marshal(messages[i])
		if err != nil {
			return fmt.Errorf("failed to marshal message: %w", err)
		}

		if err := s.redis.LPush(ctx, key, msgJSON).Err(); err != nil {
			return fmt.Errorf("failed to cache message: %w", err)
		}
	}

	// Keep only last 20 messages
	s.redis.LTrim(ctx, key, 0, 19)

	// Set expiry to 1 hour
	s.redis.Expire(ctx, key, 1*time.Hour)

	return nil
}

// GetCachedMessages retrieves cached messages for a conversation
func (s *MessageCacheService) GetCachedMessages(ctx context.Context, conversationID uuid.UUID, limit int) ([]*models.Message, error) {
	key := fmt.Sprintf(keyConversationMessages, conversationID.String())

	// Get messages from list
	results, err := s.redis.LRange(ctx, key, 0, int64(limit-1)).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, nil // Cache miss
		}
		return nil, fmt.Errorf("failed to get cached messages: %w", err)
	}

	if len(results) == 0 {
		return nil, nil // Cache miss
	}

	messages := make([]*models.Message, 0, len(results))
	for _, result := range results {
		var msg models.Message
		if err := json.Unmarshal([]byte(result), &msg); err != nil {
			continue // Skip malformed messages
		}
		messages = append(messages, &msg)
	}

	// Reverse to show oldest first
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, nil
}

// InvalidateConversationCache removes cached messages for a conversation
func (s *MessageCacheService) InvalidateConversationCache(ctx context.Context, conversationID uuid.UUID) error {
	key := fmt.Sprintf(keyConversationMessages, conversationID.String())
	return s.redis.Del(ctx, key).Err()
}

// PrependMessage adds a new message to the cache
func (s *MessageCacheService) PrependMessage(ctx context.Context, message *models.Message) error {
	key := fmt.Sprintf(keyConversationMessages, message.ConversationID.String())

	msgJSON, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	// Add to beginning of list
	s.redis.LPush(ctx, key, msgJSON)

	// Keep only last 20
	s.redis.LTrim(ctx, key, 0, 19)

	// Refresh expiry
	s.redis.Expire(ctx, key, 1*time.Hour)

	return nil
}

// ============================================
// CONVERSATION LIST CACHING
// ============================================

// CacheConversations caches a user's conversation list
func (s *MessageCacheService) CacheConversations(ctx context.Context, userID uuid.UUID, conversations []*models.Conversation) error {
	key := fmt.Sprintf(keyUserConversations, userID.String())

	data, err := json.Marshal(conversations)
	if err != nil {
		return fmt.Errorf("failed to marshal conversations: %w", err)
	}

	// Cache for 5 minutes
	return s.redis.Set(ctx, key, data, 5*time.Minute).Err()
}

// GetCachedConversations retrieves cached conversation list
func (s *MessageCacheService) GetCachedConversations(ctx context.Context, userID uuid.UUID) ([]*models.Conversation, error) {
	key := fmt.Sprintf(keyUserConversations, userID.String())

	data, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, nil // Cache miss
		}
		return nil, fmt.Errorf("failed to get cached conversations: %w", err)
	}

	var conversations []*models.Conversation
	if err := json.Unmarshal([]byte(data), &conversations); err != nil {
		return nil, fmt.Errorf("failed to unmarshal conversations: %w", err)
	}

	return conversations, nil
}

// InvalidateUserConversations removes cached conversation list
func (s *MessageCacheService) InvalidateUserConversations(ctx context.Context, userID uuid.UUID) error {
	key := fmt.Sprintf(keyUserConversations, userID.String())
	return s.redis.Del(ctx, key).Err()
}

// ============================================
// PRESENCE TRACKING
// ============================================

// SetUserOnline marks a user as online
func (s *MessageCacheService) SetUserOnline(ctx context.Context, userID uuid.UUID) error {
	key := fmt.Sprintf(keyUserPresence, userID.String())

	// Set online status with 90s TTL (auto-expire if not refreshed)
	err := s.redis.HSet(ctx, key, map[string]interface{}{
		"is_online": "true",
		"last_seen": time.Now().Unix(),
	}).Err()

	if err != nil {
		return err
	}

	// Set TTL
	return s.redis.Expire(ctx, key, 90*time.Second).Err()
}

// SetUserOffline marks a user as offline
func (s *MessageCacheService) SetUserOffline(ctx context.Context, userID uuid.UUID) error {
	key := fmt.Sprintf(keyUserPresence, userID.String())

	return s.redis.HSet(ctx, key, map[string]interface{}{
		"is_online": "false",
		"last_seen": time.Now().Unix(),
	}).Err()
}

// GetUserPresence retrieves a user's presence status
func (s *MessageCacheService) GetUserPresence(ctx context.Context, userID uuid.UUID) (isOnline bool, lastSeen time.Time, err error) {
	key := fmt.Sprintf(keyUserPresence, userID.String())

	result, err := s.redis.HGetAll(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return false, time.Time{}, nil
		}
		return false, time.Time{}, err
	}

	if len(result) == 0 {
		return false, time.Time{}, nil
	}

	isOnline = result["is_online"] == "true"

	if lastSeenStr, ok := result["last_seen"]; ok {
		var lastSeenUnix int64
		fmt.Sscanf(lastSeenStr, "%d", &lastSeenUnix)
		lastSeen = time.Unix(lastSeenUnix, 0)
	}

	return isOnline, lastSeen, nil
}

// GetMultiplePresence retrieves presence for multiple users (batch operation)
func (s *MessageCacheService) GetMultiplePresence(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID]*models.PresenceInfo, error) {
	result := make(map[uuid.UUID]*models.PresenceInfo)

	// Use pipeline for efficiency
	pipe := s.redis.Pipeline()
	cmds := make(map[uuid.UUID]*redis.StringStringMapCmd)

	for _, userID := range userIDs {
		key := fmt.Sprintf(keyUserPresence, userID.String())
		cmds[userID] = pipe.HGetAll(ctx, key)
	}

	if _, err := pipe.Exec(ctx); err != nil && err != redis.Nil {
		return nil, err
	}

	for userID, cmd := range cmds {
		data, err := cmd.Result()
		if err != nil || len(data) == 0 {
			result[userID] = &models.PresenceInfo{
				UserID:   userID,
				IsOnline: false,
			}
			continue
		}

		isOnline := data["is_online"] == "true"
		var lastSeen *time.Time

		if lastSeenStr, ok := data["last_seen"]; ok {
			var lastSeenUnix int64
			fmt.Sscanf(lastSeenStr, "%d", &lastSeenUnix)
			t := time.Unix(lastSeenUnix, 0)
			lastSeen = &t
		}

		result[userID] = &models.PresenceInfo{
			UserID:   userID,
			IsOnline: isOnline,
			LastSeen: lastSeen,
		}
	}

	return result, nil
}

// ============================================
// TYPING INDICATORS
// ============================================

// SetTyping sets a user as typing in a conversation
func (s *MessageCacheService) SetTyping(ctx context.Context, conversationID, userID uuid.UUID) error {
	key := fmt.Sprintf(keyTyping, conversationID.String(), userID.String())

	// Set with 3s TTL (auto-expire if not refreshed)
	return s.redis.Set(ctx, key, "1", 3*time.Second).Err()
}

// ClearTyping removes typing indicator for a user
func (s *MessageCacheService) ClearTyping(ctx context.Context, conversationID, userID uuid.UUID) error {
	key := fmt.Sprintf(keyTyping, conversationID.String(), userID.String())
	return s.redis.Del(ctx, key).Err()
}

// GetTypingUsers returns list of users currently typing in a conversation
func (s *MessageCacheService) GetTypingUsers(ctx context.Context, conversationID uuid.UUID) ([]uuid.UUID, error) {
	// Scan for all typing keys for this conversation
	pattern := fmt.Sprintf(keyTyping, conversationID.String(), "*")

	var cursor uint64
	var keys []string

	for {
		var err error
		var batch []string

		batch, cursor, err = s.redis.Scan(ctx, cursor, pattern, 10).Result()
		if err != nil {
			return nil, err
		}

		keys = append(keys, batch...)

		if cursor == 0 {
			break
		}
	}

	// Extract user IDs from keys
	userIDs := make([]uuid.UUID, 0, len(keys))
	for _, key := range keys {
		// Key format: typing:{conversation_id}:{user_id}
		var convID, userID string
		fmt.Sscanf(key, "typing:%s:%s", &convID, &userID)

		if parsedUserID, err := uuid.Parse(userID); err == nil {
			userIDs = append(userIDs, parsedUserID)
		}
	}

	return userIDs, nil
}

// ============================================
// UNREAD COUNTS
// ============================================

// IncrementUnread increments unread count for a conversation
func (s *MessageCacheService) IncrementUnread(ctx context.Context, conversationID, userID uuid.UUID) error {
	key := fmt.Sprintf(keyUnreadCounts, userID.String())

	return s.redis.HIncrBy(ctx, key, conversationID.String(), 1).Err()
}

// ResetUnread resets unread count for a conversation
func (s *MessageCacheService) ResetUnread(ctx context.Context, conversationID, userID uuid.UUID) error {
	key := fmt.Sprintf(keyUnreadCounts, userID.String())

	return s.redis.HDel(ctx, key, conversationID.String()).Err()
}

// GetUnreadCounts retrieves all unread counts for a user
func (s *MessageCacheService) GetUnreadCounts(ctx context.Context, userID uuid.UUID) (map[uuid.UUID]int, error) {
	key := fmt.Sprintf(keyUnreadCounts, userID.String())

	result, err := s.redis.HGetAll(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return make(map[uuid.UUID]int), nil
		}
		return nil, err
	}

	counts := make(map[uuid.UUID]int)
	for convIDStr, countStr := range result {
		convID, err := uuid.Parse(convIDStr)
		if err != nil {
			continue
		}

		var count int
		fmt.Sscanf(countStr, "%d", &count)
		counts[convID] = count
	}

	return counts, nil
}

// GetTotalUnread returns total unread message count for a user
func (s *MessageCacheService) GetTotalUnread(ctx context.Context, userID uuid.UUID) (int, error) {
	counts, err := s.GetUnreadCounts(ctx, userID)
	if err != nil {
		return 0, err
	}

	total := 0
	for _, count := range counts {
		total += count
	}

	return total, nil
}

// ============================================
// CLEANUP METHODS
// ============================================

// CleanupStalePresence removes presence keys that haven't been updated (called periodically)
func (s *MessageCacheService) CleanupStalePresence(ctx context.Context) error {
	// Presence keys with TTL will auto-expire, but we can force cleanup if needed
	// This is optional as Redis handles TTL automatically
	return nil
}

// CleanupExpiredTyping removes expired typing indicators (called periodically)
func (s *MessageCacheService) CleanupExpiredTyping(ctx context.Context) error {
	// Typing keys with TTL will auto-expire
	// This is optional as Redis handles TTL automatically
	return nil
}

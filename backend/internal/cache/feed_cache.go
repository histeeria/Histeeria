package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// FeedCacheService handles caching for the feed system
// Uses the CacheProvider interface for platform independence
type FeedCacheService struct {
	cache    CacheProvider
	enabled  bool
	keyPrefix string
}

// FeedCacheConfig holds configuration for feed caching
type FeedCacheConfig struct {
	HomeFeedTTL       time.Duration
	ExploreFeedTTL    time.Duration
	PostTTL           time.Duration
	HashtagFeedTTL    time.Duration
	TrendingTTL       time.Duration
	UserPostsTTL      time.Duration
}

// DefaultFeedCacheConfig returns sensible defaults
func DefaultFeedCacheConfig() *FeedCacheConfig {
	return &FeedCacheConfig{
		HomeFeedTTL:     5 * time.Minute,
		ExploreFeedTTL:  15 * time.Minute,
		PostTTL:         30 * time.Minute,
		HashtagFeedTTL:  10 * time.Minute,
		TrendingTTL:     5 * time.Minute,
		UserPostsTTL:    10 * time.Minute,
	}
}

// Key patterns
const (
	keyHomeFeed        = "feed:home:%s"
	keyFollowingFeed   = "feed:following:%s"
	keyExploreFeed     = "feed:explore"
	keyPost            = "post:%s"
	keySavedFeed       = "feed:saved:%s"
	keyHashtagFeed     = "feed:hashtag:%s"
	keyTrendingHashtags = "trending:hashtags"
	keyUserPosts       = "posts:user:%s"
)

// TTL values (configurable via FeedCacheConfig in production)
var (
	homeFeedTTL      = 5 * time.Minute
	exploreFeedTTL   = 15 * time.Minute
	postTTL          = 30 * time.Minute
	hashtagFeedTTL   = 10 * time.Minute
	trendingTTL      = 5 * time.Minute
)

// NewFeedCacheService creates a new feed cache service
func NewFeedCacheService(cache CacheProvider) *FeedCacheService {
	return &FeedCacheService{
		cache:     cache,
		enabled:   cache != nil && cache.IsAvailable(),
		keyPrefix: "",
	}
}

// NewFeedCacheServiceWithConfig creates a feed cache service with custom config
func NewFeedCacheServiceWithConfig(cache CacheProvider, config *FeedCacheConfig) *FeedCacheService {
	if config != nil {
		homeFeedTTL = config.HomeFeedTTL
		exploreFeedTTL = config.ExploreFeedTTL
		postTTL = config.PostTTL
		hashtagFeedTTL = config.HashtagFeedTTL
		trendingTTL = config.TrendingTTL
	}

	return NewFeedCacheService(cache)
}

// IsEnabled returns whether caching is enabled
func (s *FeedCacheService) IsEnabled() bool {
	return s.enabled
}

// ============================================
// HOME FEED CACHING
// ============================================

// CachedFeedResult represents a cached feed with metadata
type CachedFeedResult struct {
	PostIDs   []uuid.UUID `json:"post_ids"`
	Total     int         `json:"total"`
	CachedAt  time.Time   `json:"cached_at"`
	ExpiresAt time.Time   `json:"expires_at"`
}

// CacheHomeFeed caches a user's home feed post IDs
func (s *FeedCacheService) CacheHomeFeed(ctx context.Context, userID uuid.UUID, postIDs []uuid.UUID, total int) error {
	if !s.enabled {
		return nil
	}

	key := fmt.Sprintf(keyHomeFeed, userID.String())

	result := CachedFeedResult{
		PostIDs:   postIDs,
		Total:     total,
		CachedAt:  time.Now(),
		ExpiresAt: time.Now().Add(homeFeedTTL),
	}

	data, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("failed to marshal feed: %w", err)
	}

	return s.cache.Set(ctx, key, string(data), homeFeedTTL)
}

// GetCachedHomeFeed retrieves cached home feed
func (s *FeedCacheService) GetCachedHomeFeed(ctx context.Context, userID uuid.UUID) (*CachedFeedResult, error) {
	if !s.enabled {
		return nil, nil
	}

	key := fmt.Sprintf(keyHomeFeed, userID.String())

	data, err := s.cache.Get(ctx, key)
	if err != nil {
		if IsCacheMiss(err) {
			return nil, nil
		}
		return nil, err
	}

	var result CachedFeedResult
	if err := json.Unmarshal([]byte(data), &result); err != nil {
		return nil, fmt.Errorf("failed to unmarshal feed: %w", err)
	}

	return &result, nil
}

// InvalidateHomeFeed removes cached home feed for a user
func (s *FeedCacheService) InvalidateHomeFeed(ctx context.Context, userID uuid.UUID) error {
	if !s.enabled {
		return nil
	}

	key := fmt.Sprintf(keyHomeFeed, userID.String())
	return s.cache.Delete(ctx, key)
}

// InvalidateFollowerFeeds invalidates feeds for all followers
// Call this when a user creates a new post
func (s *FeedCacheService) InvalidateFollowerFeeds(ctx context.Context, followerIDs []uuid.UUID) error {
	if !s.enabled || len(followerIDs) == 0 {
		return nil
	}

	keys := make([]string, len(followerIDs))
	for i, id := range followerIDs {
		keys[i] = fmt.Sprintf(keyHomeFeed, id.String())
	}

	return s.cache.MDelete(ctx, keys)
}

// ============================================
// POST CACHING
// ============================================

// CachePost caches an individual post
func (s *FeedCacheService) CachePost(ctx context.Context, post *models.Post) error {
	if !s.enabled {
		return nil
	}

	key := fmt.Sprintf(keyPost, post.ID.String())

	data, err := json.Marshal(post)
	if err != nil {
		return fmt.Errorf("failed to marshal post: %w", err)
	}

	return s.cache.Set(ctx, key, string(data), postTTL)
}

// GetCachedPost retrieves a cached post
func (s *FeedCacheService) GetCachedPost(ctx context.Context, postID uuid.UUID) (*models.Post, error) {
	if !s.enabled {
		return nil, nil
	}

	key := fmt.Sprintf(keyPost, postID.String())

	data, err := s.cache.Get(ctx, key)
	if err != nil {
		if IsCacheMiss(err) {
			return nil, nil
		}
		return nil, err
	}

	var post models.Post
	if err := json.Unmarshal([]byte(data), &post); err != nil {
		return nil, fmt.Errorf("failed to unmarshal post: %w", err)
	}

	return &post, nil
}

// GetCachedPosts retrieves multiple posts (batch)
// Returns: found posts, missing IDs, error
func (s *FeedCacheService) GetCachedPosts(ctx context.Context, postIDs []uuid.UUID) (map[uuid.UUID]*models.Post, []uuid.UUID, error) {
	if !s.enabled || len(postIDs) == 0 {
		return nil, postIDs, nil
	}

	keys := make([]string, len(postIDs))
	for i, id := range postIDs {
		keys[i] = fmt.Sprintf(keyPost, id.String())
	}

	values, err := s.cache.MGet(ctx, keys)
	if err != nil {
		return nil, postIDs, err
	}

	posts := make(map[uuid.UUID]*models.Post)
	misses := make([]uuid.UUID, 0)

	for i, value := range values {
		if value == "" {
			misses = append(misses, postIDs[i])
			continue
		}

		var post models.Post
		if err := json.Unmarshal([]byte(value), &post); err != nil {
			misses = append(misses, postIDs[i])
			continue
		}

		posts[postIDs[i]] = &post
	}

	return posts, misses, nil
}

// InvalidatePost removes a cached post
func (s *FeedCacheService) InvalidatePost(ctx context.Context, postID uuid.UUID) error {
	if !s.enabled {
		return nil
	}

	key := fmt.Sprintf(keyPost, postID.String())
	return s.cache.Delete(ctx, key)
}

// UpdatePostEngagement updates engagement counts without full refresh
func (s *FeedCacheService) UpdatePostEngagement(ctx context.Context, postID uuid.UUID, field string, delta int) error {
	if !s.enabled {
		return nil
	}

	post, err := s.GetCachedPost(ctx, postID)
	if err != nil || post == nil {
		return err
	}

	switch field {
	case "likes":
		post.LikesCount += delta
		if post.LikesCount < 0 {
			post.LikesCount = 0
		}
	case "comments":
		post.CommentsCount += delta
		if post.CommentsCount < 0 {
			post.CommentsCount = 0
		}
	case "shares":
		post.SharesCount += delta
		if post.SharesCount < 0 {
			post.SharesCount = 0
		}
	case "views":
		post.ViewsCount += delta
	}

	return s.CachePost(ctx, post)
}

// ============================================
// EXPLORE FEED CACHING (Shared across users)
// ============================================

// CacheExploreFeed caches the explore/trending feed
func (s *FeedCacheService) CacheExploreFeed(ctx context.Context, postIDs []uuid.UUID, total int) error {
	if !s.enabled {
		return nil
	}

	result := CachedFeedResult{
		PostIDs:   postIDs,
		Total:     total,
		CachedAt:  time.Now(),
		ExpiresAt: time.Now().Add(exploreFeedTTL),
	}

	data, err := json.Marshal(result)
	if err != nil {
		return err
	}

	return s.cache.Set(ctx, keyExploreFeed, string(data), exploreFeedTTL)
}

// GetCachedExploreFeed retrieves cached explore feed
func (s *FeedCacheService) GetCachedExploreFeed(ctx context.Context) (*CachedFeedResult, error) {
	if !s.enabled {
		return nil, nil
	}

	data, err := s.cache.Get(ctx, keyExploreFeed)
	if err != nil {
		if IsCacheMiss(err) {
			return nil, nil
		}
		return nil, err
	}

	var result CachedFeedResult
	if err := json.Unmarshal([]byte(data), &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// ============================================
// HASHTAG CACHING
// ============================================

// CacheHashtagFeed caches posts for a hashtag
func (s *FeedCacheService) CacheHashtagFeed(ctx context.Context, hashtag string, postIDs []uuid.UUID, total int) error {
	if !s.enabled {
		return nil
	}

	key := fmt.Sprintf(keyHashtagFeed, hashtag)

	result := CachedFeedResult{
		PostIDs:   postIDs,
		Total:     total,
		CachedAt:  time.Now(),
		ExpiresAt: time.Now().Add(hashtagFeedTTL),
	}

	data, err := json.Marshal(result)
	if err != nil {
		return err
	}

	return s.cache.Set(ctx, key, string(data), hashtagFeedTTL)
}

// GetCachedHashtagFeed retrieves cached hashtag feed
func (s *FeedCacheService) GetCachedHashtagFeed(ctx context.Context, hashtag string) (*CachedFeedResult, error) {
	if !s.enabled {
		return nil, nil
	}

	key := fmt.Sprintf(keyHashtagFeed, hashtag)

	data, err := s.cache.Get(ctx, key)
	if err != nil {
		if IsCacheMiss(err) {
			return nil, nil
		}
		return nil, err
	}

	var result CachedFeedResult
	if err := json.Unmarshal([]byte(data), &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// ============================================
// TRENDING HASHTAGS
// ============================================

// TrendingHashtag represents a trending hashtag
type TrendingHashtag struct {
	Tag           string    `json:"tag"`
	PostsCount    int       `json:"posts_count"`
	TrendingScore float64   `json:"trending_score"`
	CachedAt      time.Time `json:"cached_at"`
}

// CacheTrendingHashtags caches trending hashtags
func (s *FeedCacheService) CacheTrendingHashtags(ctx context.Context, hashtags []TrendingHashtag) error {
	if !s.enabled {
		return nil
	}

	data, err := json.Marshal(hashtags)
	if err != nil {
		return err
	}

	return s.cache.Set(ctx, keyTrendingHashtags, string(data), trendingTTL)
}

// GetCachedTrendingHashtags retrieves cached trending hashtags
func (s *FeedCacheService) GetCachedTrendingHashtags(ctx context.Context) ([]TrendingHashtag, error) {
	if !s.enabled {
		return nil, nil
	}

	data, err := s.cache.Get(ctx, keyTrendingHashtags)
	if err != nil {
		if IsCacheMiss(err) {
			return nil, nil
		}
		return nil, err
	}

	var hashtags []TrendingHashtag
	if err := json.Unmarshal([]byte(data), &hashtags); err != nil {
		return nil, err
	}

	return hashtags, nil
}

// ============================================
// CACHE WARMING & UTILITIES
// ============================================

// WarmUserFeed pre-caches a user's feed (call during login or background)
func (s *FeedCacheService) WarmUserFeed(ctx context.Context, userID uuid.UUID, posts []models.Post, total int) error {
	if !s.enabled || len(posts) == 0 {
		return nil
	}

	// Cache individual posts
	postIDs := make([]uuid.UUID, len(posts))
	items := make(map[string]string)

	for i := range posts {
		post := &posts[i]
		postIDs[i] = post.ID

		data, err := json.Marshal(post)
		if err != nil {
			continue
		}

		key := fmt.Sprintf(keyPost, post.ID.String())
		items[key] = string(data)
	}

	// Batch set posts
	if len(items) > 0 {
		if err := s.cache.MSet(ctx, items, postTTL); err != nil {
			log.Printf("[FeedCache] Failed to warm posts: %v", err)
		}
	}

	// Cache feed index
	return s.CacheHomeFeed(ctx, userID, postIDs, total)
}

// ClearAllFeeds clears all feed caches (use sparingly)
func (s *FeedCacheService) ClearAllFeeds(ctx context.Context) error {
	if !s.enabled {
		return nil
	}

	patterns := []string{"feed:*", "post:*", "trending:*"}

	for _, pattern := range patterns {
		keys, err := s.cache.Keys(ctx, pattern)
		if err != nil {
			continue
		}

		if len(keys) > 0 {
			if err := s.cache.MDelete(ctx, keys); err != nil {
				log.Printf("[FeedCache] Failed to clear keys for pattern %s: %v", pattern, err)
			}
		}
	}

	return nil
}

// GetCacheStats returns cache statistics
func (s *FeedCacheService) GetCacheStats(ctx context.Context) map[string]interface{} {
	return map[string]interface{}{
		"enabled":   s.enabled,
		"available": s.cache != nil && s.cache.IsAvailable(),
	}
}

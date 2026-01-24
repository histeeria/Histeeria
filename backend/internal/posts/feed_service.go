package posts

import (
	"context"
	"fmt"
	"log"

	"histeeria-backend/internal/cache"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"

	"github.com/google/uuid"
)

// FeedService handles feed generation and caching
type FeedService struct {
	postRepo         repository.PostRepository
	relationshipRepo repository.RelationshipRepository
	feedCache        *cache.FeedCacheService
}

// NewFeedService creates a new feed service
func NewFeedService(
	postRepo repository.PostRepository,
	relationshipRepo repository.RelationshipRepository,
) *FeedService {
	return &FeedService{
		postRepo:         postRepo,
		relationshipRepo: relationshipRepo,
	}
}

// NewFeedServiceWithCache creates a new feed service with caching support
func NewFeedServiceWithCache(
	postRepo repository.PostRepository,
	relationshipRepo repository.RelationshipRepository,
	feedCache *cache.FeedCacheService,
) *FeedService {
	return &FeedService{
		postRepo:         postRepo,
		relationshipRepo: relationshipRepo,
		feedCache:        feedCache,
	}
}

// SetFeedCache sets the feed cache service (for backward compatibility)
func (s *FeedService) SetFeedCache(feedCache *cache.FeedCacheService) {
	s.feedCache = feedCache
}

// GetHomeFeed retrieves the home feed for a user with caching
// Algorithm: Chronological feed from following + own posts
func (s *FeedService) GetHomeFeed(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, int, error) {
	// Only use cache for first page (offset 0) to avoid complexity
	if s.feedCache != nil && s.feedCache.IsEnabled() && offset == 0 {
		// Try to get from cache
		cached, err := s.feedCache.GetCachedHomeFeed(ctx, userID)
		if err != nil {
			log.Printf("[FeedService] Cache error for home feed: %v", err)
		} else if cached != nil && len(cached.PostIDs) > 0 {
			// Cache hit - get posts by IDs
			posts, missingIDs, err := s.feedCache.GetCachedPosts(ctx, cached.PostIDs[:min(limit, len(cached.PostIDs))])
			if err != nil {
				log.Printf("[FeedService] Cache error getting posts: %v", err)
			} else if len(missingIDs) == 0 {
				// Full cache hit!
				result := make([]models.Post, 0, len(posts))
				for _, id := range cached.PostIDs[:min(limit, len(cached.PostIDs))] {
					if post, ok := posts[id]; ok {
						result = append(result, *post)
					}
				}
				log.Printf("[FeedService] Home feed cache HIT for user %s (%d posts)", userID, len(result))
				return result, cached.Total, nil
			}
			// Partial cache hit - fall through to database
			log.Printf("[FeedService] Home feed partial cache hit (%d missing)", len(missingIDs))
		}
	}

	// Cache miss or disabled - get from database
	posts, total, err := s.postRepo.GetHomeFeed(ctx, userID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get home feed: %w", err)
	}

	// Cache the result for first page
	if s.feedCache != nil && s.feedCache.IsEnabled() && offset == 0 && len(posts) > 0 {
		go func() {
			// Cache in background to not block response
			bgCtx := context.Background()
			if err := s.feedCache.WarmUserFeed(bgCtx, userID, posts, total); err != nil {
				log.Printf("[FeedService] Failed to cache home feed: %v", err)
			} else {
				log.Printf("[FeedService] Home feed cached for user %s", userID)
			}
		}()
	}

	return posts, total, nil
}

// GetFollowingFeed retrieves posts only from users the viewer follows
func (s *FeedService) GetFollowingFeed(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, int, error) {
	return s.postRepo.GetFollowingFeed(ctx, userID, limit, offset)
}

// GetExploreFeed retrieves trending/popular posts for discovery with caching
// filter can be: "posts", "polls", "articles", or "" for all
func (s *FeedService) GetExploreFeed(ctx context.Context, userID uuid.UUID, limit, offset int, filter string) ([]models.Post, int, error) {
	// Only cache first page
	if s.feedCache != nil && s.feedCache.IsEnabled() && offset == 0 {
		cached, err := s.feedCache.GetCachedExploreFeed(ctx)
		if err != nil {
			log.Printf("[FeedService] Cache error for explore feed: %v", err)
		} else if cached != nil && len(cached.PostIDs) > 0 {
			// Cache hit - get posts by IDs
			posts, missingIDs, err := s.feedCache.GetCachedPosts(ctx, cached.PostIDs[:min(limit, len(cached.PostIDs))])
			if err != nil {
				log.Printf("[FeedService] Cache error getting explore posts: %v", err)
			} else if len(missingIDs) == 0 {
				result := make([]models.Post, 0, len(posts))
				for _, id := range cached.PostIDs[:min(limit, len(cached.PostIDs))] {
					if post, ok := posts[id]; ok {
						result = append(result, *post)
					}
				}
				log.Printf("[FeedService] Explore feed cache HIT (%d posts)", len(result))
				return result, cached.Total, nil
			}
		}
	}

	// Cache miss - get from database
	posts, total, err := s.postRepo.GetExploreFeed(ctx, userID, limit, offset, filter)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get explore feed: %w", err)
	}

	// Cache the result for first page (explore feed is shared across users)
	if s.feedCache != nil && s.feedCache.IsEnabled() && offset == 0 && len(posts) > 0 {
		go func() {
			bgCtx := context.Background()
			
			// Cache individual posts
			for i := range posts {
				s.feedCache.CachePost(bgCtx, &posts[i])
			}
			
			// Cache feed index
			postIDs := make([]uuid.UUID, len(posts))
			for i, p := range posts {
				postIDs[i] = p.ID
			}
			if err := s.feedCache.CacheExploreFeed(bgCtx, postIDs, total); err != nil {
				log.Printf("[FeedService] Failed to cache explore feed: %v", err)
			} else {
				log.Printf("[FeedService] Explore feed cached")
			}
		}()
	}

	return posts, total, nil
}

// GetUserFeed retrieves posts by a specific user
func (s *FeedService) GetUserFeed(ctx context.Context, username string, viewerID uuid.UUID, limit, offset int) ([]models.Post, int, error) {
	// This would require a user repository reference
	// For now, return empty
	return []models.Post{}, 0, nil
}

// GetSavedFeed retrieves user's saved/bookmarked posts
func (s *FeedService) GetSavedFeed(ctx context.Context, userID uuid.UUID, collection string, limit, offset int) ([]models.Post, int, error) {
	return s.postRepo.GetSavedPosts(ctx, userID, collection, limit, offset)
}

// GetHashtagFeed retrieves posts with a specific hashtag with caching
func (s *FeedService) GetHashtagFeed(ctx context.Context, hashtag string, viewerID uuid.UUID, limit, offset int) ([]models.Post, int, error) {
	// Only cache first page
	if s.feedCache != nil && s.feedCache.IsEnabled() && offset == 0 {
		cached, err := s.feedCache.GetCachedHashtagFeed(ctx, hashtag)
		if err != nil {
			log.Printf("[FeedService] Cache error for hashtag feed: %v", err)
		} else if cached != nil && len(cached.PostIDs) > 0 {
			posts, missingIDs, err := s.feedCache.GetCachedPosts(ctx, cached.PostIDs[:min(limit, len(cached.PostIDs))])
			if err != nil {
				log.Printf("[FeedService] Cache error getting hashtag posts: %v", err)
			} else if len(missingIDs) == 0 {
				result := make([]models.Post, 0, len(posts))
				for _, id := range cached.PostIDs[:min(limit, len(cached.PostIDs))] {
					if post, ok := posts[id]; ok {
						result = append(result, *post)
					}
				}
				log.Printf("[FeedService] Hashtag #%s feed cache HIT (%d posts)", hashtag, len(result))
				return result, cached.Total, nil
			}
		}
	}

	// Cache miss - get from database
	posts, total, err := s.postRepo.GetHashtagFeed(ctx, hashtag, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get hashtag feed: %w", err)
	}

	// Cache the result
	if s.feedCache != nil && s.feedCache.IsEnabled() && offset == 0 && len(posts) > 0 {
		go func() {
			bgCtx := context.Background()
			
			// Cache individual posts
			for i := range posts {
				s.feedCache.CachePost(bgCtx, &posts[i])
			}
			
			// Cache feed index
			postIDs := make([]uuid.UUID, len(posts))
			for i, p := range posts {
				postIDs[i] = p.ID
			}
			if err := s.feedCache.CacheHashtagFeed(bgCtx, hashtag, postIDs, total); err != nil {
				log.Printf("[FeedService] Failed to cache hashtag feed: %v", err)
			}
		}()
	}

	return posts, total, nil
}

// SearchPosts searches posts by query
func (s *FeedService) SearchPosts(ctx context.Context, query string, userID uuid.UUID, limit, offset int) ([]models.Post, int, error) {
	return s.postRepo.SearchPosts(ctx, query, userID, limit, offset)
}

// ============================================
// CACHE INVALIDATION METHODS
// ============================================

// InvalidateUserFeed invalidates a user's home feed cache
// Call when user follows/unfollows someone or changes preferences
func (s *FeedService) InvalidateUserFeed(ctx context.Context, userID uuid.UUID) error {
	if s.feedCache == nil || !s.feedCache.IsEnabled() {
		return nil
	}
	return s.feedCache.InvalidateHomeFeed(ctx, userID)
}

// InvalidateFollowerFeeds invalidates home feeds for all followers of a user
// Call when a user creates, updates, or deletes a post
func (s *FeedService) InvalidateFollowerFeeds(ctx context.Context, userID uuid.UUID) error {
	if s.feedCache == nil || !s.feedCache.IsEnabled() {
		return nil
	}

	// Get follower IDs using GetUserRelationships
	// asFrom=false means we want users who have a "following" relationship TO this user (i.e., followers)
	followers, _, err := s.relationshipRepo.GetUserRelationships(
		ctx,
		userID,
		models.RelationshipFollowing,
		models.RelationshipActive,
		false, // asFrom=false means get followers (people following this user)
		1,     // page
		1000,  // limit - get up to 1000 followers
	)
	if err != nil {
		return fmt.Errorf("failed to get followers: %w", err)
	}

	if len(followers) == 0 {
		return nil
	}

	followerIDs := make([]uuid.UUID, len(followers))
	for i, f := range followers {
		followerIDs[i] = f.UserID
	}

	return s.feedCache.InvalidateFollowerFeeds(ctx, followerIDs)
}

// InvalidatePost invalidates a specific post in cache
// Call when a post is updated or deleted
func (s *FeedService) InvalidatePost(ctx context.Context, postID uuid.UUID) error {
	if s.feedCache == nil || !s.feedCache.IsEnabled() {
		return nil
	}
	return s.feedCache.InvalidatePost(ctx, postID)
}

// UpdatePostEngagement updates engagement counts in cache without full invalidation
// Call when a post is liked, commented, or shared
func (s *FeedService) UpdatePostEngagement(ctx context.Context, postID uuid.UUID, field string, delta int) error {
	if s.feedCache == nil || !s.feedCache.IsEnabled() {
		return nil
	}
	return s.feedCache.UpdatePostEngagement(ctx, postID, field, delta)
}

// ============================================
// CACHE WARMING
// ============================================

// WarmExploreFeed warms the explore feed cache
// Call from background job
func (s *FeedService) WarmExploreFeed(ctx context.Context) error {
	if s.feedCache == nil || !s.feedCache.IsEnabled() {
		return nil
	}

	// Get explore feed from database (use a system user ID or uuid.Nil)
	// No filter for cache warming - cache all types
	posts, total, err := s.postRepo.GetExploreFeed(ctx, uuid.Nil, 50, 0, "")
	if err != nil {
		return fmt.Errorf("failed to get explore feed for warming: %w", err)
	}

	// Cache individual posts
	for i := range posts {
		s.feedCache.CachePost(ctx, &posts[i])
	}

	// Cache feed index
	postIDs := make([]uuid.UUID, len(posts))
	for i, p := range posts {
		postIDs[i] = p.ID
	}

	return s.feedCache.CacheExploreFeed(ctx, postIDs, total)
}

// GetCacheStats returns cache statistics
func (s *FeedService) GetCacheStats(ctx context.Context) map[string]interface{} {
	if s.feedCache == nil {
		return map[string]interface{}{
			"enabled": false,
		}
	}
	return s.feedCache.GetCacheStats(ctx)
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

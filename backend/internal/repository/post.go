package repository

import (
	"context"
	"histeeria-backend/internal/models"
	"time"

	"github.com/google/uuid"
)

// PostRepository defines the interface for post data access
type PostRepository interface {
	// Post CRUD
	CreatePost(ctx context.Context, post *models.Post) error
	GetPost(ctx context.Context, postID, viewerID uuid.UUID) (*models.Post, error)
	GetPostByID(ctx context.Context, postID uuid.UUID) (*models.Post, error)
	GetUserPosts(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, int, error)
	UpdatePost(ctx context.Context, postID uuid.UUID, updates map[string]interface{}) error
	DeletePost(ctx context.Context, postID, userID uuid.UUID) error

	// Feed queries
	GetHomeFeed(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, int, error)
	GetFollowingFeed(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, int, error)
	GetExploreFeed(ctx context.Context, userID uuid.UUID, limit, offset int, filter string) ([]models.Post, int, error)
	GetHashtagFeed(ctx context.Context, hashtag string, limit, offset int) ([]models.Post, int, error)

	// Engagement
	LikePost(ctx context.Context, postID, userID uuid.UUID) error
	UnlikePost(ctx context.Context, postID, userID uuid.UUID) error
	IsPostLikedByUser(ctx context.Context, postID, userID uuid.UUID) (bool, error)
	GetPostLikes(ctx context.Context, postID uuid.UUID, limit, offset int) ([]models.User, int, error)

	SharePost(ctx context.Context, postID, userID uuid.UUID, comment string) error
	UnsharePost(ctx context.Context, postID, userID uuid.UUID) error

	SavePost(ctx context.Context, postID, userID uuid.UUID, collection string) error
	UnsavePost(ctx context.Context, postID, userID uuid.UUID) error
	IsPostSavedByUser(ctx context.Context, postID, userID uuid.UUID) (bool, error)
	GetSavedPosts(ctx context.Context, userID uuid.UUID, collection string, limit, offset int) ([]models.Post, int, error)

	// Stats
	IncrementViews(ctx context.Context, postID, userID uuid.UUID) error
	RecordProfileVisitFromPost(ctx context.Context, postID, visitorID, profileOwnerID uuid.UUID) error
	
	// Insights
	GetPostReach(ctx context.Context, postID uuid.UUID) (int, error) // Unique users who viewed
	GetPostImpressions(ctx context.Context, postID uuid.UUID) (int, error) // Total views (including repeats)
	GetProfileVisitsFromPost(ctx context.Context, postID uuid.UUID) (int, error) // Profile visits from this post

	// Hashtags
	ExtractAndCreateHashtags(ctx context.Context, postID uuid.UUID, content string) error
	GetHashtagByTag(ctx context.Context, tag string) (*HashtagInfo, error)
	GetTrendingHashtags(ctx context.Context, limit int) ([]HashtagInfo, error)
	FollowHashtag(ctx context.Context, hashtagID, userID uuid.UUID) error
	UnfollowHashtag(ctx context.Context, hashtagID, userID uuid.UUID) error

	// Mentions
	ExtractAndCreateMentions(ctx context.Context, postID uuid.UUID, content string) error

	// Search
	SearchPosts(ctx context.Context, query string, userID uuid.UUID, limit, offset int) ([]models.Post, int, error)

	// User Activity
	GetUserLikedPosts(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, int, error)
	GetUserCommentedPosts(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, int, error)
	GetUserDeletedPosts(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, int, error)
	GetUserSharedPosts(ctx context.Context, userID uuid.UUID, postType string, limit, offset int) ([]models.Post, int, error)

	// Author loading
	LoadPostAuthor(ctx context.Context, post *models.Post) error

	// Since last visit counts
	GetPostsCountSince(ctx context.Context, since time.Time) (int, error)
	GetPollsCountSince(ctx context.Context, since time.Time) (int, error)
	GetArticlesCountSince(ctx context.Context, since time.Time) (int, error)

	// Since last visit content (actual posts, not just counts)
	GetPostsSince(ctx context.Context, userID uuid.UUID, since time.Time, limit, offset int) ([]models.Post, int, error)
	GetPollsSince(ctx context.Context, userID uuid.UUID, since time.Time, limit, offset int) ([]models.Post, int, error)
	GetArticlesSince(ctx context.Context, userID uuid.UUID, since time.Time, limit, offset int) ([]models.Post, int, error)

	// Post moderation
	RestrictPost(ctx context.Context, postID, userID uuid.UUID) error
	UnrestrictPost(ctx context.Context, postID, userID uuid.UUID) error
	IsPostRestrictedByUser(ctx context.Context, postID, userID uuid.UUID) (bool, error)
	GetRestrictedPostIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error)
}

// HashtagInfo represents hashtag information
type HashtagInfo struct {
	ID             uuid.UUID `json:"id"`
	Tag            string    `json:"tag"`
	PostsCount     int       `json:"posts_count"`
	FollowersCount int       `json:"followers_count"`
	TrendingScore  float64   `json:"trending_score"`
	CreatedAt      time.Time `json:"created_at"`
	IsFollowing    bool      `json:"is_following,omitempty"`
}

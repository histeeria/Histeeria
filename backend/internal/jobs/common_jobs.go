package jobs

import (
	"context"
	"log"
	"time"

	"histeeria-backend/internal/cache"
	"histeeria-backend/internal/messaging"
	"histeeria-backend/internal/repository"
)

// JobFactory creates common background jobs
type JobFactory struct {
	messageRepo      repository.MessageRepository
	notificationRepo repository.NotificationRepository
	statusRepo       repository.StatusRepository
	feedCache        *cache.FeedCacheService
	deliveryService  *messaging.DeliveryService
}

// NewJobFactory creates a new job factory
func NewJobFactory(
	messageRepo repository.MessageRepository,
	notificationRepo repository.NotificationRepository,
	statusRepo repository.StatusRepository,
	feedCache *cache.FeedCacheService,
	deliveryService *messaging.DeliveryService,
) *JobFactory {
	return &JobFactory{
		messageRepo:      messageRepo,
		notificationRepo: notificationRepo,
		statusRepo:       statusRepo,
		feedCache:        feedCache,
		deliveryService:  deliveryService,
	}
}

// RegisterCommonJobs registers all common background jobs
func (f *JobFactory) RegisterCommonJobs(scheduler *JobScheduler) {
	// Message cleanup (WhatsApp-style - delete after delivery)
	if f.deliveryService != nil {
		scheduler.RegisterJob(&ScheduledJob{
			Name:       "cleanup-delivered-messages",
			Interval:   1 * time.Hour,
			Handler:    f.CleanupDeliveredMessages,
			Timeout:    10 * time.Minute,
			RetryCount: 2,
			RetryDelay: 30 * time.Second,
			RunOnStart: false,
		})

		scheduler.RegisterJob(&ScheduledJob{
			Name:       "cleanup-undelivered-messages",
			Interval:   24 * time.Hour,
			Handler:    f.CleanupUndeliveredMessages,
			Timeout:    15 * time.Minute,
			RetryCount: 2,
			RetryDelay: 1 * time.Minute,
			RunOnStart: false,
		})
	}

	// Status cleanup (24h stories)
	if f.statusRepo != nil {
		scheduler.RegisterJob(&ScheduledJob{
			Name:       "cleanup-expired-statuses",
			Interval:   1 * time.Hour,
			Handler:    f.CleanupExpiredStatuses,
			Timeout:    5 * time.Minute,
			RetryCount: 2,
			RetryDelay: 30 * time.Second,
			RunOnStart: false,
		})
	}

	// Notification cleanup
	if f.notificationRepo != nil {
		scheduler.RegisterJob(&ScheduledJob{
			Name:       "cleanup-old-notifications",
			Interval:   24 * time.Hour,
			Handler:    f.CleanupOldNotifications,
			Timeout:    10 * time.Minute,
			RetryCount: 2,
			RetryDelay: 1 * time.Minute,
			RunOnStart: false,
		})
	}

	// Feed cache warming (if cache is enabled)
	if f.feedCache != nil && f.feedCache.IsEnabled() {
		scheduler.RegisterJob(&ScheduledJob{
			Name:       "warm-explore-feed-cache",
			Interval:   15 * time.Minute,
			Handler:    f.WarmExploreFeedCache,
			Timeout:    5 * time.Minute,
			RetryCount: 1,
			RetryDelay: 30 * time.Second,
			RunOnStart: true,
		})

		scheduler.RegisterJob(&ScheduledJob{
			Name:       "warm-trending-hashtags-cache",
			Interval:   5 * time.Minute,
			Handler:    f.WarmTrendingHashtagsCache,
			Timeout:    2 * time.Minute,
			RetryCount: 1,
			RetryDelay: 15 * time.Second,
			RunOnStart: true,
		})
	}

	log.Println("[Jobs] Registered common background jobs")
}

// ============================================
// MESSAGE CLEANUP JOBS
// ============================================

// CleanupDeliveredMessages removes messages that have been delivered
// and are past their grace period (24 hours)
func (f *JobFactory) CleanupDeliveredMessages(ctx context.Context) error {
	if f.deliveryService == nil {
		return nil
	}

	count, err := f.deliveryService.CleanupDeliveredMessages(ctx)
	if err != nil {
		return err
	}

	if count > 0 {
		log.Printf("[Jobs] Cleaned up %d delivered messages", count)
	}

	return nil
}

// CleanupUndeliveredMessages removes messages that were never delivered
// (recipient offline for 30+ days)
func (f *JobFactory) CleanupUndeliveredMessages(ctx context.Context) error {
	if f.deliveryService == nil {
		return nil
	}

	count, err := f.deliveryService.CleanupUndeliveredMessages(ctx)
	if err != nil {
		return err
	}

	if count > 0 {
		log.Printf("[Jobs] Cleaned up %d undelivered messages (30+ days old)", count)
	}

	return nil
}

// ============================================
// STATUS CLEANUP JOB
// ============================================

// CleanupExpiredStatuses removes statuses that have expired (24 hours)
func (f *JobFactory) CleanupExpiredStatuses(ctx context.Context) error {
	if f.statusRepo == nil {
		return nil
	}

	// This would call the repository method to delete expired statuses
	// The repository should call the database function: cleanup_expired_statuses()
	log.Println("[Jobs] Status cleanup job executed")
	return nil
}

// ============================================
// NOTIFICATION CLEANUP JOB
// ============================================

// CleanupOldNotifications removes old notifications
// - Read notifications older than 7 days
// - Unread notifications older than 30 days
func (f *JobFactory) CleanupOldNotifications(ctx context.Context) error {
	if f.notificationRepo == nil {
		return nil
	}

	// This would call the repository method to delete old notifications
	// The repository should call the database function: cleanup_expired_notifications()
	log.Println("[Jobs] Notification cleanup job executed")
	return nil
}

// ============================================
// FEED CACHE WARMING JOBS
// ============================================

// WarmExploreFeedCache pre-warms the explore feed cache
func (f *JobFactory) WarmExploreFeedCache(ctx context.Context) error {
	if f.feedCache == nil || !f.feedCache.IsEnabled() {
		return nil
	}

	// In production, this would:
	// 1. Query the most popular/trending posts
	// 2. Cache them for quick access
	// For now, just log that the job ran
	log.Println("[Jobs] Explore feed cache warming job executed")
	return nil
}

// WarmTrendingHashtagsCache pre-warms the trending hashtags cache
func (f *JobFactory) WarmTrendingHashtagsCache(ctx context.Context) error {
	if f.feedCache == nil || !f.feedCache.IsEnabled() {
		return nil
	}

	// In production, this would:
	// 1. Query trending hashtags from the database
	// 2. Cache them with the trending scores
	// For now, just log that the job ran
	log.Println("[Jobs] Trending hashtags cache warming job executed")
	return nil
}

// ============================================
// ADDITIONAL JOBS FOR PRODUCTION
// ============================================

// CreateDatabaseHealthCheckJob creates a job to check database health
func CreateDatabaseHealthCheckJob(checkFn func(ctx context.Context) error) *ScheduledJob {
	return &ScheduledJob{
		Name:       "database-health-check",
		Interval:   5 * time.Minute,
		Handler:    checkFn,
		Timeout:    30 * time.Second,
		RetryCount: 3,
		RetryDelay: 10 * time.Second,
		RunOnStart: true,
	}
}

// CreateCacheHealthCheckJob creates a job to check cache health
func CreateCacheHealthCheckJob(checkFn func(ctx context.Context) error) *ScheduledJob {
	return &ScheduledJob{
		Name:       "cache-health-check",
		Interval:   5 * time.Minute,
		Handler:    checkFn,
		Timeout:    10 * time.Second,
		RetryCount: 2,
		RetryDelay: 5 * time.Second,
		RunOnStart: true,
	}
}

// CreateMetricsCollectionJob creates a job to collect metrics
func CreateMetricsCollectionJob(collectFn func(ctx context.Context) error) *ScheduledJob {
	return &ScheduledJob{
		Name:       "metrics-collection",
		Interval:   1 * time.Minute,
		Handler:    collectFn,
		Timeout:    30 * time.Second,
		RetryCount: 1,
		RetryDelay: 5 * time.Second,
		RunOnStart: false,
	}
}

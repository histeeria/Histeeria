package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/go-redis/redis/v8"
)

// ============================================
// REDIS STREAMS QUEUE PROVIDER
// ============================================

// RedisQueueProvider implements QueueProvider using Redis Streams
type RedisQueueProvider struct {
	client       *redis.Client
	consumerName string
	groupName    string
}

// RedisQueueConfig holds configuration for the Redis queue
type RedisQueueConfig struct {
	ConsumerName string // Unique name for this consumer (e.g., "worker-1")
	GroupName    string // Consumer group name (e.g., "histeeria-workers")
}

// NewRedisQueueProvider creates a new Redis Streams queue provider
func NewRedisQueueProvider(client *redis.Client, cfg *RedisQueueConfig) *RedisQueueProvider {
	if cfg.ConsumerName == "" {
		cfg.ConsumerName = "consumer-" + generateJobID()[:8]
	}
	if cfg.GroupName == "" {
		cfg.GroupName = "histeeria-workers"
	}

	return &RedisQueueProvider{
		client:       client,
		consumerName: cfg.ConsumerName,
		groupName:    cfg.GroupName,
	}
}

// Enqueue adds a job to the queue using Redis XADD
func (rq *RedisQueueProvider) Enqueue(ctx context.Context, queueName string, job *Job) error {
	if rq.client == nil {
		return fmt.Errorf("redis client not available")
	}

	// Serialize job to JSON
	jobData, err := json.Marshal(job)
	if err != nil {
		return fmt.Errorf("failed to marshal job: %w", err)
	}

	// Add to stream
	_, err = rq.client.XAdd(ctx, &redis.XAddArgs{
		Stream: queueName,
		ID:     "*", // Auto-generate ID
		Values: map[string]interface{}{
			"job_id":   job.ID,
			"job_type": job.Type,
			"data":     string(jobData),
		},
	}).Result()

	if err != nil {
		return fmt.Errorf("failed to enqueue job: %w", err)
	}

	return nil
}

// Dequeue retrieves a job from the queue using Redis XREADGROUP
func (rq *RedisQueueProvider) Dequeue(ctx context.Context, queueName string, timeout time.Duration) (*Job, error) {
	if rq.client == nil {
		return nil, fmt.Errorf("redis client not available")
	}

	// Ensure consumer group exists
	rq.ensureConsumerGroup(ctx, queueName)

	// Read from stream with consumer group
	streams, err := rq.client.XReadGroup(ctx, &redis.XReadGroupArgs{
		Group:    rq.groupName,
		Consumer: rq.consumerName,
		Streams:  []string{queueName, ">"},
		Count:    1,
		Block:    timeout,
	}).Result()

	if err == redis.Nil {
		return nil, nil // No messages available
	}
	if err != nil {
		return nil, fmt.Errorf("failed to dequeue job: %w", err)
	}

	// Parse the message
	if len(streams) == 0 || len(streams[0].Messages) == 0 {
		return nil, nil
	}

	msg := streams[0].Messages[0]
	jobData, ok := msg.Values["data"].(string)
	if !ok {
		return nil, fmt.Errorf("invalid job data format")
	}

	var job Job
	if err := json.Unmarshal([]byte(jobData), &job); err != nil {
		return nil, fmt.Errorf("failed to unmarshal job: %w", err)
	}

	// Store message ID in metadata for acknowledgment
	job.SetMetadata("stream_id", msg.ID)

	return &job, nil
}

// Acknowledge marks a job as successfully processed using Redis XACK
func (rq *RedisQueueProvider) Acknowledge(ctx context.Context, queueName string, jobID string) error {
	if rq.client == nil {
		return fmt.Errorf("redis client not available")
	}

	// The jobID here is actually the stream message ID stored in metadata
	_, err := rq.client.XAck(ctx, queueName, rq.groupName, jobID).Result()
	if err != nil {
		return fmt.Errorf("failed to acknowledge job: %w", err)
	}

	// Also delete the message from the stream to free memory
	_, err = rq.client.XDel(ctx, queueName, jobID).Result()
	if err != nil {
		log.Printf("[Queue] Warning: failed to delete acknowledged message: %v", err)
	}

	return nil
}

// Reject marks a job as failed
func (rq *RedisQueueProvider) Reject(ctx context.Context, queueName string, jobID string, reason string) error {
	if rq.client == nil {
		return fmt.Errorf("redis client not available")
	}

	// Move to dead letter queue
	deadLetterQueue := queueName + ":dead"

	// Store failure info
	failureData := map[string]interface{}{
		"original_queue": queueName,
		"job_id":         jobID,
		"reason":         reason,
		"failed_at":      time.Now().Format(time.RFC3339),
	}

	_, err := rq.client.XAdd(ctx, &redis.XAddArgs{
		Stream: deadLetterQueue,
		ID:     "*",
		Values: failureData,
	}).Result()
	if err != nil {
		log.Printf("[Queue] Warning: failed to add to dead letter queue: %v", err)
	}

	// Acknowledge original message (removes from pending)
	_, err = rq.client.XAck(ctx, queueName, rq.groupName, jobID).Result()
	if err != nil {
		return fmt.Errorf("failed to reject job: %w", err)
	}

	return nil
}

// GetPendingCount returns the number of pending jobs
func (rq *RedisQueueProvider) GetPendingCount(ctx context.Context, queueName string) (int64, error) {
	if rq.client == nil {
		return 0, fmt.Errorf("redis client not available")
	}

	// Get stream length
	length, err := rq.client.XLen(ctx, queueName).Result()
	if err != nil {
		return 0, fmt.Errorf("failed to get pending count: %w", err)
	}

	return length, nil
}

// GetFailedCount returns the number of failed jobs
func (rq *RedisQueueProvider) GetFailedCount(ctx context.Context, queueName string) (int64, error) {
	if rq.client == nil {
		return 0, fmt.Errorf("redis client not available")
	}

	deadLetterQueue := queueName + ":dead"
	length, err := rq.client.XLen(ctx, deadLetterQueue).Result()
	if err != nil {
		return 0, fmt.Errorf("failed to get failed count: %w", err)
	}

	return length, nil
}

// RetryFailed moves failed jobs back to the queue
func (rq *RedisQueueProvider) RetryFailed(ctx context.Context, queueName string) (int64, error) {
	if rq.client == nil {
		return 0, fmt.Errorf("redis client not available")
	}

	deadLetterQueue := queueName + ":dead"

	// Get all messages from dead letter queue
	messages, err := rq.client.XRange(ctx, deadLetterQueue, "-", "+").Result()
	if err != nil {
		return 0, fmt.Errorf("failed to read dead letter queue: %w", err)
	}

	var retried int64
	for _, msg := range messages {
		// Re-add to main queue (simplified - would need original job data)
		_, err := rq.client.XAdd(ctx, &redis.XAddArgs{
			Stream: queueName,
			ID:     "*",
			Values: msg.Values,
		}).Result()
		if err != nil {
			log.Printf("[Queue] Warning: failed to retry message: %v", err)
			continue
		}

		// Remove from dead letter
		rq.client.XDel(ctx, deadLetterQueue, msg.ID)
		retried++
	}

	return retried, nil
}

// Ping checks if the queue is available
func (rq *RedisQueueProvider) Ping(ctx context.Context) error {
	if rq.client == nil {
		return fmt.Errorf("redis client not available")
	}
	return rq.client.Ping(ctx).Err()
}

// Close closes the connection
func (rq *RedisQueueProvider) Close() error {
	// Don't close the client here as it may be shared
	return nil
}

// ensureConsumerGroup creates the consumer group if it doesn't exist
func (rq *RedisQueueProvider) ensureConsumerGroup(ctx context.Context, queueName string) {
	// Try to create the group, ignore error if it already exists
	err := rq.client.XGroupCreateMkStream(ctx, queueName, rq.groupName, "0").Err()
	if err != nil && err.Error() != "BUSYGROUP Consumer Group name already exists" {
		log.Printf("[Queue] Warning: failed to create consumer group: %v", err)
	}
}

// GetConsumerInfo returns information about the consumer
func (rq *RedisQueueProvider) GetConsumerInfo() map[string]string {
	return map[string]string{
		"consumer_name": rq.consumerName,
		"group_name":    rq.groupName,
	}
}

// ClaimStaleMessages claims messages that have been pending too long
// This handles worker crashes/restarts
func (rq *RedisQueueProvider) ClaimStaleMessages(ctx context.Context, queueName string, maxIdleTime time.Duration) ([]*Job, error) {
	if rq.client == nil {
		return nil, fmt.Errorf("redis client not available")
	}

	// Get pending messages for this group
	pending, err := rq.client.XPendingExt(ctx, &redis.XPendingExtArgs{
		Stream: queueName,
		Group:  rq.groupName,
		Start:  "-",
		End:    "+",
		Count:  100,
	}).Result()

	if err != nil {
		return nil, fmt.Errorf("failed to get pending messages: %w", err)
	}

	var jobs []*Job
	for _, p := range pending {
		// Check if message has been idle for too long
		if p.Idle > maxIdleTime {
			// Claim the message
			claimed, err := rq.client.XClaim(ctx, &redis.XClaimArgs{
				Stream:   queueName,
				Group:    rq.groupName,
				Consumer: rq.consumerName,
				MinIdle:  maxIdleTime,
				Messages: []string{p.ID},
			}).Result()

			if err != nil {
				log.Printf("[Queue] Warning: failed to claim message %s: %v", p.ID, err)
				continue
			}

			// Parse claimed messages
			for _, msg := range claimed {
				jobData, ok := msg.Values["data"].(string)
				if !ok {
					continue
				}

				var job Job
				if err := json.Unmarshal([]byte(jobData), &job); err != nil {
					continue
				}

				job.SetMetadata("stream_id", msg.ID)
				job.Attempts++
				jobs = append(jobs, &job)
			}
		}
	}

	return jobs, nil
}

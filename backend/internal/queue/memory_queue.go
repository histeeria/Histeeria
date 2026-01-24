package queue

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// ============================================
// IN-MEMORY QUEUE PROVIDER
// ============================================

// MemoryQueueProvider implements QueueProvider using in-memory channels
// Suitable for development and single-server deployments
type MemoryQueueProvider struct {
	queues      map[string]chan *Job
	deadLetters map[string][]*deadLetterEntry
	mu          sync.RWMutex
	closed      bool
}

type deadLetterEntry struct {
	Job       *Job
	Reason    string
	FailedAt  time.Time
}

// NewMemoryQueueProvider creates a new in-memory queue provider
func NewMemoryQueueProvider() *MemoryQueueProvider {
	return &MemoryQueueProvider{
		queues:      make(map[string]chan *Job),
		deadLetters: make(map[string][]*deadLetterEntry),
	}
}

// getOrCreateQueue gets or creates a queue channel
func (mq *MemoryQueueProvider) getOrCreateQueue(queueName string) chan *Job {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	if queue, ok := mq.queues[queueName]; ok {
		return queue
	}

	// Create buffered channel with capacity 10000
	queue := make(chan *Job, 10000)
	mq.queues[queueName] = queue
	return queue
}

// Enqueue adds a job to the queue
func (mq *MemoryQueueProvider) Enqueue(ctx context.Context, queueName string, job *Job) error {
	mq.mu.RLock()
	if mq.closed {
		mq.mu.RUnlock()
		return fmt.Errorf("queue is closed")
	}
	mq.mu.RUnlock()

	queue := mq.getOrCreateQueue(queueName)

	select {
	case queue <- job:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	default:
		return fmt.Errorf("queue is full")
	}
}

// Dequeue retrieves a job from the queue
func (mq *MemoryQueueProvider) Dequeue(ctx context.Context, queueName string, timeout time.Duration) (*Job, error) {
	mq.mu.RLock()
	if mq.closed {
		mq.mu.RUnlock()
		return nil, fmt.Errorf("queue is closed")
	}
	mq.mu.RUnlock()

	queue := mq.getOrCreateQueue(queueName)

	// Create timeout context
	timeoutCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	select {
	case job := <-queue:
		job.SetMetadata("dequeued_at", time.Now().Format(time.RFC3339))
		return job, nil
	case <-timeoutCtx.Done():
		return nil, nil // Timeout - no job available
	}
}

// Acknowledge marks a job as successfully processed (no-op for in-memory)
func (mq *MemoryQueueProvider) Acknowledge(ctx context.Context, queueName string, jobID string) error {
	// In-memory queue doesn't need acknowledgment
	return nil
}

// Reject marks a job as failed
func (mq *MemoryQueueProvider) Reject(ctx context.Context, queueName string, jobID string, reason string) error {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	// Note: We can't recover the job from just the ID in this simple implementation
	// In production, you'd want to store pending jobs with their IDs
	entry := &deadLetterEntry{
		Job:      &Job{ID: jobID},
		Reason:   reason,
		FailedAt: time.Now(),
	}

	mq.deadLetters[queueName] = append(mq.deadLetters[queueName], entry)
	return nil
}

// GetPendingCount returns the number of pending jobs
func (mq *MemoryQueueProvider) GetPendingCount(ctx context.Context, queueName string) (int64, error) {
	mq.mu.RLock()
	defer mq.mu.RUnlock()

	if queue, ok := mq.queues[queueName]; ok {
		return int64(len(queue)), nil
	}
	return 0, nil
}

// GetFailedCount returns the number of failed jobs
func (mq *MemoryQueueProvider) GetFailedCount(ctx context.Context, queueName string) (int64, error) {
	mq.mu.RLock()
	defer mq.mu.RUnlock()

	if entries, ok := mq.deadLetters[queueName]; ok {
		return int64(len(entries)), nil
	}
	return 0, nil
}

// RetryFailed moves failed jobs back to the queue
func (mq *MemoryQueueProvider) RetryFailed(ctx context.Context, queueName string) (int64, error) {
	mq.mu.Lock()
	entries, ok := mq.deadLetters[queueName]
	if !ok || len(entries) == 0 {
		mq.mu.Unlock()
		return 0, nil
	}

	// Clear dead letters
	mq.deadLetters[queueName] = nil
	mq.mu.Unlock()

	var retried int64
	queue := mq.getOrCreateQueue(queueName)

	for _, entry := range entries {
		if entry.Job != nil {
			entry.Job.Attempts++
			select {
			case queue <- entry.Job:
				retried++
			default:
				// Queue full, ignore
			}
		}
	}

	return retried, nil
}

// Ping checks if the queue is available
func (mq *MemoryQueueProvider) Ping(ctx context.Context) error {
	mq.mu.RLock()
	defer mq.mu.RUnlock()

	if mq.closed {
		return fmt.Errorf("queue is closed")
	}
	return nil
}

// Close closes all queues
func (mq *MemoryQueueProvider) Close() error {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	mq.closed = true
	for name, queue := range mq.queues {
		close(queue)
		delete(mq.queues, name)
	}
	return nil
}

// GetQueueStats returns statistics for all queues
func (mq *MemoryQueueProvider) GetQueueStats() map[string]map[string]int64 {
	mq.mu.RLock()
	defer mq.mu.RUnlock()

	stats := make(map[string]map[string]int64)
	for name, queue := range mq.queues {
		stats[name] = map[string]int64{
			"pending": int64(len(queue)),
			"failed":  int64(len(mq.deadLetters[name])),
		}
	}
	return stats
}

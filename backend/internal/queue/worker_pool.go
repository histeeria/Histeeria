package queue

import (
	"context"
	"fmt"
	"log"
	"runtime/debug"
	"sync"
	"time"
)

// ============================================
// WORKER POOL
// ============================================

// WorkerPool manages multiple workers processing jobs from a queue
type WorkerPool struct {
	provider     QueueProvider
	queueName    string
	workers      int
	pollTime     int
	maxRetries   int
	handlers     map[string]JobHandler
	ctx          context.Context
	cancel       context.CancelFunc
	wg           sync.WaitGroup
	mu           sync.RWMutex
}

// WorkerPoolConfig holds worker pool configuration
type WorkerPoolConfig struct {
	Workers    int    // Number of concurrent workers
	QueueName  string // Name of the queue to process
	PollTime   int    // Poll interval in milliseconds
	MaxRetries int    // Maximum number of retries for failed jobs
}

// NewWorkerPool creates a new worker pool
func NewWorkerPool(provider QueueProvider, cfg *WorkerPoolConfig) *WorkerPool {
	if cfg.Workers <= 0 {
		cfg.Workers = 5
	}
	if cfg.PollTime <= 0 {
		cfg.PollTime = 1000 // 1 second default
	}
	if cfg.MaxRetries <= 0 {
		cfg.MaxRetries = 3
	}

	ctx, cancel := context.WithCancel(context.Background())

	return &WorkerPool{
		provider:   provider,
		queueName:  cfg.QueueName,
		workers:    cfg.Workers,
		pollTime:   cfg.PollTime,
		maxRetries: cfg.MaxRetries,
		handlers:   make(map[string]JobHandler),
		ctx:        ctx,
		cancel:     cancel,
	}
}

// RegisterHandler registers a job handler for a specific job type
func (wp *WorkerPool) RegisterHandler(jobType string, handler JobHandler) {
	wp.mu.Lock()
	defer wp.mu.Unlock()
	wp.handlers[jobType] = handler
}

// Start starts the worker pool
func (wp *WorkerPool) Start() {
	log.Printf("[WorkerPool] Starting %d workers for queue: %s", wp.workers, wp.queueName)

	for i := 0; i < wp.workers; i++ {
		wp.wg.Add(1)
		go wp.processJobs(i)
	}

	log.Printf("[WorkerPool] Workers started")
}

// Stop gracefully stops the worker pool
func (wp *WorkerPool) Stop() {
	log.Printf("[WorkerPool] Stopping workers...")
	wp.cancel()
	wp.wg.Wait()
	log.Printf("[WorkerPool] Workers stopped")
}

// processJobs is the main job processing loop for a worker
func (wp *WorkerPool) processJobs(workerID int) {
	defer wp.wg.Done()

	pollInterval := time.Duration(wp.pollTime) * time.Millisecond
	log.Printf("[WorkerPool-Worker %d] Started", workerID)

	for {
		select {
		case <-wp.ctx.Done():
			log.Printf("[WorkerPool-Worker %d] Stopped", workerID)
			return

		default:
			// Dequeue a job
			job, err := wp.provider.Dequeue(wp.ctx, wp.queueName, pollInterval)
			if err != nil {
				log.Printf("[WorkerPool-Worker %d] Error dequeuing: %v", workerID, err)
				time.Sleep(1 * time.Second)
				continue
			}

			// No job available
			if job == nil {
				continue
			}

			// Process the job
			wp.handleJob(workerID, job)
		}
	}
}

// handleJob processes a single job with panic recovery
func (wp *WorkerPool) handleJob(workerID int, job *Job) {
	defer func() {
		if r := recover(); r != nil {
			stack := string(debug.Stack())
			log.Printf("[WorkerPool-Worker %d] PANIC processing job %s: %v\n%s",
				workerID, job.ID, r, stack)

			// Get stream ID or use job ID
			streamID := job.GetMetadata("stream_id")
			if streamID == "" {
				streamID = job.ID
			}

			// Reject the job
			wp.provider.Reject(context.Background(), wp.queueName, streamID,
				fmt.Sprintf("panic: %v", r))
		}
	}()

	startTime := time.Now()
	log.Printf("[WorkerPool-Worker %d] Processing job %s (type: %s, attempt: %d/%d)",
		workerID, job.ID, job.Type, job.Attempts+1, wp.maxRetries)

	// Get handler
	wp.mu.RLock()
	handler, exists := wp.handlers[job.Type]
	wp.mu.RUnlock()

	if !exists {
		log.Printf("[WorkerPool-Worker %d] No handler for job type: %s", workerID, job.Type)
		streamID := job.GetMetadata("stream_id")
		if streamID == "" {
			streamID = job.ID
		}
		wp.provider.Reject(context.Background(), wp.queueName, streamID,
			fmt.Sprintf("no handler for type: %s", job.Type))
		return
	}

	// Create context with timeout
	jobCtx, cancel := context.WithTimeout(wp.ctx, 5*time.Minute)
	defer cancel()

	// Execute handler
	err := handler(jobCtx, job)

	// Get stream ID
	streamID := job.GetMetadata("stream_id")
	if streamID == "" {
		streamID = job.ID
	}

	if err != nil {
		job.Attempts++
		log.Printf("[WorkerPool-Worker %d] Job %s failed: %v (attempt %d/%d)",
			workerID, job.ID, err, job.Attempts, wp.maxRetries)

		// Retry if not exceeded max retries
		if job.Attempts < wp.maxRetries {
			job.SetMetadata("retry_count", fmt.Sprintf("%d", job.Attempts))
			job.SetMetadata("last_error", err.Error())

			if enqErr := wp.provider.Enqueue(context.Background(), wp.queueName, job); enqErr != nil {
				log.Printf("[WorkerPool-Worker %d] Failed to re-enqueue job %s: %v",
					workerID, job.ID, enqErr)
			} else {
				log.Printf("[WorkerPool-Worker %d] Re-queued job %s for retry",
					workerID, job.ID)
			}

			// Acknowledge original message
			wp.provider.Acknowledge(context.Background(), wp.queueName, streamID)
		} else {
			// Max retries exceeded
			log.Printf("[WorkerPool-Worker %d] Job %s exceeded max retries, moving to dead letter",
				workerID, job.ID)
			wp.provider.Reject(context.Background(), wp.queueName, streamID,
				fmt.Sprintf("max retries exceeded: %v", err))
		}
	} else {
		// Success
		duration := time.Since(startTime)
		log.Printf("[WorkerPool-Worker %d] Job %s completed in %v",
			workerID, job.ID, duration)

		// Acknowledge
		if ackErr := wp.provider.Acknowledge(context.Background(), wp.queueName, streamID); ackErr != nil {
			log.Printf("[WorkerPool-Worker %d] Failed to acknowledge job %s: %v",
				workerID, job.ID, ackErr)
		}
	}
}

// GetStats returns worker pool statistics
func (wp *WorkerPool) GetStats() map[string]interface{} {
	pending, _ := wp.provider.GetPendingCount(context.Background(), wp.queueName)
	failed, _ := wp.provider.GetFailedCount(context.Background(), wp.queueName)

	return map[string]interface{}{
		"queue_name": wp.queueName,
		"workers":    wp.workers,
		"pending":    pending,
		"failed":     failed,
	}
}

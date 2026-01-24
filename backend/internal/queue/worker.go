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
// QUEUE WORKER
// ============================================

// Worker processes jobs from the queue
type Worker struct {
	ID           string
	queue        QueueProvider
	queueName    string
	handlers     map[string]JobHandler
	concurrency  int
	pollInterval time.Duration
	ctx          context.Context
	cancel       context.CancelFunc
	wg           sync.WaitGroup
	mu           sync.RWMutex
}

// JobHandler is a function that processes a job
type JobHandler func(ctx context.Context, job *Job) error

// WorkerConfig holds worker configuration
type WorkerConfig struct {
	QueueName    string
	Concurrency  int           // Number of concurrent job processors
	PollInterval time.Duration // How often to poll for jobs
}

// NewWorker creates a new queue worker
func NewWorker(queue QueueProvider, cfg *WorkerConfig) *Worker {
	if cfg.Concurrency <= 0 {
		cfg.Concurrency = 5 // Default to 5 concurrent workers
	}
	if cfg.PollInterval <= 0 {
		cfg.PollInterval = 1 * time.Second
	}

	ctx, cancel := context.WithCancel(context.Background())

	return &Worker{
		ID:           generateJobID()[:8],
		queue:        queue,
		queueName:    cfg.QueueName,
		handlers:     make(map[string]JobHandler),
		concurrency:  cfg.Concurrency,
		pollInterval: cfg.PollInterval,
		ctx:          ctx,
		cancel:       cancel,
	}
}

// RegisterHandler registers a job handler for a specific job type
func (w *Worker) RegisterHandler(jobType string, handler JobHandler) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.handlers[jobType] = handler
	log.Printf("[Worker %s] Registered handler for job type: %s", w.ID, jobType)
}

// Start starts the worker
func (w *Worker) Start() {
	log.Printf("[Worker %s] Starting with %d concurrent processors for queue: %s",
		w.ID, w.concurrency, w.queueName)

	// Start multiple goroutines for concurrent processing
	for i := 0; i < w.concurrency; i++ {
		w.wg.Add(1)
		go w.processJobs(i)
	}

	log.Printf("[Worker %s] Started successfully", w.ID)
}

// Stop gracefully stops the worker
func (w *Worker) Stop() {
	log.Printf("[Worker %s] Stopping...", w.ID)
	w.cancel()
	w.wg.Wait()
	log.Printf("[Worker %s] Stopped", w.ID)
}

// processJobs is the main job processing loop
func (w *Worker) processJobs(workerNum int) {
	defer w.wg.Done()

	log.Printf("[Worker %s-%d] Started", w.ID, workerNum)
	defer log.Printf("[Worker %s-%d] Stopped", w.ID, workerNum)

	for {
		select {
		case <-w.ctx.Done():
			return

		default:
			// Dequeue a job (with timeout to avoid blocking indefinitely)
			job, err := w.queue.Dequeue(w.ctx, w.queueName, w.pollInterval)
			if err != nil {
				log.Printf("[Worker %s-%d] Error dequeuing job: %v", w.ID, workerNum, err)
				time.Sleep(1 * time.Second) // Backoff on error
				continue
			}

			// No job available, continue polling
			if job == nil {
				continue
			}

			// Process the job
			w.handleJob(workerNum, job)
		}
	}
}

// handleJob processes a single job with panic recovery
func (w *Worker) handleJob(workerNum int, job *Job) {
	defer func() {
		if r := recover(); r != nil {
			stack := string(debug.Stack())
			log.Printf("[Worker %s-%d] PANIC while processing job %s (type: %s): %v\n%s",
				w.ID, workerNum, job.ID, job.Type, r, stack)

			// Reject the job with panic information
			streamID := job.GetMetadata("stream_id")
			if streamID == "" {
				streamID = job.ID
			}

			w.queue.Reject(context.Background(), w.queueName, streamID,
				fmt.Sprintf("panic: %v", r))
		}
	}()

	startTime := time.Now()
	log.Printf("[Worker %s-%d] Processing job %s (type: %s, attempt: %d/%d)",
		w.ID, workerNum, job.ID, job.Type, job.Attempts+1, job.MaxRetry)

	// Get handler for this job type
	w.mu.RLock()
	handler, exists := w.handlers[job.Type]
	w.mu.RUnlock()

	if !exists {
		log.Printf("[Worker %s-%d] No handler registered for job type: %s",
			w.ID, workerNum, job.Type)
		
		streamID := job.GetMetadata("stream_id")
		if streamID == "" {
			streamID = job.ID
		}
		
		w.queue.Reject(context.Background(), w.queueName, streamID,
			fmt.Sprintf("no handler for job type: %s", job.Type))
		return
	}

	// Create context with timeout for job processing
	jobCtx, cancel := context.WithTimeout(w.ctx, 5*time.Minute)
	defer cancel()

	// Execute the handler
	err := handler(jobCtx, job)

	// Get stream ID for acknowledgment/rejection
	streamID := job.GetMetadata("stream_id")
	if streamID == "" {
		streamID = job.ID
	}

	if err != nil {
		job.Attempts++
		
		log.Printf("[Worker %s-%d] Job %s failed: %v (attempt %d/%d)",
			w.ID, workerNum, job.ID, err, job.Attempts, job.MaxRetry)

		// Check if we should retry
		if job.Attempts < job.MaxRetry {
			// Re-enqueue the job for retry
			job.SetMetadata("retry_count", fmt.Sprintf("%d", job.Attempts))
			job.SetMetadata("last_error", err.Error())
			
			if enqErr := w.queue.Enqueue(context.Background(), w.queueName, job); enqErr != nil {
				log.Printf("[Worker %s-%d] Failed to re-enqueue job %s: %v",
					w.ID, workerNum, job.ID, enqErr)
			} else {
				log.Printf("[Worker %s-%d] Re-queued job %s for retry",
					w.ID, workerNum, job.ID)
			}

			// Acknowledge the original message
			w.queue.Acknowledge(context.Background(), w.queueName, streamID)
		} else {
			// Max retries reached, move to dead letter
			log.Printf("[Worker %s-%d] Job %s exceeded max retries, moving to dead letter",
				w.ID, workerNum, job.ID)
			
			w.queue.Reject(context.Background(), w.queueName, streamID,
				fmt.Sprintf("max retries exceeded: %v", err))
		}
	} else {
		// Job succeeded
		duration := time.Since(startTime)
		log.Printf("[Worker %s-%d] Job %s completed successfully in %v",
			w.ID, workerNum, job.ID, duration)

		// Acknowledge the job
		if ackErr := w.queue.Acknowledge(context.Background(), w.queueName, streamID); ackErr != nil {
			log.Printf("[Worker %s-%d] Failed to acknowledge job %s: %v",
				w.ID, workerNum, job.ID, ackErr)
		}
	}
}

// GetStats returns worker statistics
func (w *Worker) GetStats() map[string]interface{} {
	pending, _ := w.queue.GetPendingCount(context.Background(), w.queueName)
	failed, _ := w.queue.GetFailedCount(context.Background(), w.queueName)

	return map[string]interface{}{
		"worker_id":   w.ID,
		"queue_name":  w.queueName,
		"concurrency": w.concurrency,
		"pending":     pending,
		"failed":      failed,
	}
}

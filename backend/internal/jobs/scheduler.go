package jobs

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
)

// JobScheduler manages background jobs with scheduling, retry, and monitoring
type JobScheduler struct {
	jobs       map[string]*ScheduledJob
	mu         sync.RWMutex
	ctx        context.Context
	cancel     context.CancelFunc
	wg         sync.WaitGroup
	running    bool
	errorLog   []JobError
	errorLogMu sync.Mutex
}

// ScheduledJob represents a job to be run on a schedule
type ScheduledJob struct {
	Name       string
	Interval   time.Duration
	Handler    JobHandler
	Timeout    time.Duration
	RetryCount int
	RetryDelay time.Duration
	LastRun    time.Time
	LastError  error
	RunCount   int64
	ErrorCount int64
	Enabled    bool
	RunOnStart bool // Whether to run immediately on start
}

// JobHandler is the function signature for job handlers
type JobHandler func(ctx context.Context) error

// JobError records a job execution error
type JobError struct {
	JobName   string
	Timestamp time.Time
	Error     error
}

// JobResult represents the result of a job execution
type JobResult struct {
	JobName   string        `json:"job_name"`
	StartTime time.Time     `json:"start_time"`
	EndTime   time.Time     `json:"end_time"`
	Duration  time.Duration `json:"duration"`
	Success   bool          `json:"success"`
	Error     string        `json:"error,omitempty"`
}

// NewJobScheduler creates a new job scheduler
func NewJobScheduler() *JobScheduler {
	ctx, cancel := context.WithCancel(context.Background())
	return &JobScheduler{
		jobs:     make(map[string]*ScheduledJob),
		ctx:      ctx,
		cancel:   cancel,
		errorLog: make([]JobError, 0, 100),
	}
}

// RegisterJob registers a new scheduled job
func (s *JobScheduler) RegisterJob(job *ScheduledJob) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if job.Name == "" {
		return fmt.Errorf("job name is required")
	}

	if job.Interval <= 0 {
		return fmt.Errorf("job interval must be positive")
	}

	if job.Handler == nil {
		return fmt.Errorf("job handler is required")
	}

	if job.Timeout == 0 {
		job.Timeout = 5 * time.Minute // Default timeout
	}

	if _, exists := s.jobs[job.Name]; exists {
		return fmt.Errorf("job %s already registered", job.Name)
	}

	job.Enabled = true
	s.jobs[job.Name] = job

	log.Printf("[Jobs] Registered job: %s (interval: %s)", job.Name, job.Interval)
	return nil
}

// UnregisterJob removes a job from the scheduler
func (s *JobScheduler) UnregisterJob(name string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.jobs, name)
	log.Printf("[Jobs] Unregistered job: %s", name)
}

// Start starts the job scheduler
func (s *JobScheduler) Start() {
	s.mu.Lock()
	if s.running {
		s.mu.Unlock()
		return
	}
	s.running = true

	// Copy jobs for iteration
	jobs := make([]*ScheduledJob, 0, len(s.jobs))
	for _, job := range s.jobs {
		if job.Enabled {
			jobs = append(jobs, job)
		}
	}
	s.mu.Unlock()

	log.Printf("[Jobs] Starting scheduler with %d jobs", len(jobs))

	// Start each job in its own goroutine
	for _, job := range jobs {
		s.wg.Add(1)
		go s.runJob(job)
	}
}

// Stop stops the job scheduler gracefully
func (s *JobScheduler) Stop() {
	s.mu.Lock()
	if !s.running {
		s.mu.Unlock()
		return
	}
	s.running = false
	s.mu.Unlock()

	log.Println("[Jobs] Stopping scheduler...")
	s.cancel()
	s.wg.Wait()
	log.Println("[Jobs] Scheduler stopped")
}

// runJob runs a single job on its schedule
func (s *JobScheduler) runJob(job *ScheduledJob) {
	defer s.wg.Done()

	// Run immediately if configured
	if job.RunOnStart {
		s.executeJob(job)
	}

	ticker := time.NewTicker(job.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			if job.Enabled {
				s.executeJob(job)
			}
		case <-s.ctx.Done():
			log.Printf("[Jobs] Stopping job: %s", job.Name)
			return
		}
	}
}

// executeJob executes a job with timeout and retry
func (s *JobScheduler) executeJob(job *ScheduledJob) {
	start := time.Now()
	log.Printf("[Jobs] Running job: %s", job.Name)

	// Create context with timeout
	ctx, cancel := context.WithTimeout(s.ctx, job.Timeout)
	defer cancel()

	var err error
	attempts := 0
	maxAttempts := job.RetryCount + 1

	for attempts < maxAttempts {
		attempts++

		// Execute the job
		err = s.safeExecute(ctx, job)

		if err == nil {
			break
		}

		// Log retry
		if attempts < maxAttempts {
			log.Printf("[Jobs] Job %s failed (attempt %d/%d): %v. Retrying in %s",
				job.Name, attempts, maxAttempts, err, job.RetryDelay)

			select {
			case <-time.After(job.RetryDelay):
			case <-ctx.Done():
				err = ctx.Err()
				break
			}
		}
	}

	// Update job stats
	s.mu.Lock()
	job.LastRun = time.Now()
	job.RunCount++
	if err != nil {
		job.ErrorCount++
		job.LastError = err
	} else {
		job.LastError = nil
	}
	s.mu.Unlock()

	// Log result
	duration := time.Since(start)
	if err != nil {
		log.Printf("[Jobs] Job %s completed with error in %s: %v", job.Name, duration, err)
		s.recordError(job.Name, err)
	} else {
		log.Printf("[Jobs] Job %s completed successfully in %s", job.Name, duration)
	}
}

// safeExecute runs a job handler with panic recovery
func (s *JobScheduler) safeExecute(ctx context.Context, job *ScheduledJob) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("job panicked: %v", r)
		}
	}()

	return job.Handler(ctx)
}

// recordError records a job error for monitoring
func (s *JobScheduler) recordError(jobName string, err error) {
	s.errorLogMu.Lock()
	defer s.errorLogMu.Unlock()

	s.errorLog = append(s.errorLog, JobError{
		JobName:   jobName,
		Timestamp: time.Now(),
		Error:     err,
	})

	// Keep only last 100 errors
	if len(s.errorLog) > 100 {
		s.errorLog = s.errorLog[1:]
	}
}

// EnableJob enables a job
func (s *JobScheduler) EnableJob(name string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if job, ok := s.jobs[name]; ok {
		job.Enabled = true
		log.Printf("[Jobs] Enabled job: %s", name)
	}
}

// DisableJob disables a job
func (s *JobScheduler) DisableJob(name string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if job, ok := s.jobs[name]; ok {
		job.Enabled = false
		log.Printf("[Jobs] Disabled job: %s", name)
	}
}

// RunJobNow runs a job immediately (outside of schedule)
func (s *JobScheduler) RunJobNow(name string) error {
	s.mu.RLock()
	job, ok := s.jobs[name]
	s.mu.RUnlock()

	if !ok {
		return fmt.Errorf("job %s not found", name)
	}

	go s.executeJob(job)
	return nil
}

// GetJobStats returns statistics for all jobs
func (s *JobScheduler) GetJobStats() []JobStats {
	s.mu.RLock()
	defer s.mu.RUnlock()

	stats := make([]JobStats, 0, len(s.jobs))
	for _, job := range s.jobs {
		var lastError string
		if job.LastError != nil {
			lastError = job.LastError.Error()
		}

		stats = append(stats, JobStats{
			Name:       job.Name,
			Interval:   job.Interval.String(),
			Enabled:    job.Enabled,
			LastRun:    job.LastRun,
			RunCount:   job.RunCount,
			ErrorCount: job.ErrorCount,
			LastError:  lastError,
		})
	}

	return stats
}

// JobStats represents statistics for a job
type JobStats struct {
	Name       string    `json:"name"`
	Interval   string    `json:"interval"`
	Enabled    bool      `json:"enabled"`
	LastRun    time.Time `json:"last_run"`
	RunCount   int64     `json:"run_count"`
	ErrorCount int64     `json:"error_count"`
	LastError  string    `json:"last_error,omitempty"`
}

// GetRecentErrors returns recent job errors
func (s *JobScheduler) GetRecentErrors(limit int) []JobError {
	s.errorLogMu.Lock()
	defer s.errorLogMu.Unlock()

	if limit <= 0 || limit > len(s.errorLog) {
		limit = len(s.errorLog)
	}

	// Return most recent errors
	start := len(s.errorLog) - limit
	if start < 0 {
		start = 0
	}

	result := make([]JobError, len(s.errorLog)-start)
	copy(result, s.errorLog[start:])

	return result
}

// IsRunning returns whether the scheduler is running
func (s *JobScheduler) IsRunning() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.running
}

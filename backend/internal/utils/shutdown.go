package utils

import (
	"context"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"
)

// ShutdownManager handles graceful shutdown of services
type ShutdownManager struct {
	callbacks []ShutdownCallback
	mu        sync.Mutex
	timeout   time.Duration
	logger    *Logger
}

// ShutdownCallback represents a function to call during shutdown
type ShutdownCallback struct {
	Name     string
	Fn       func(ctx context.Context) error
	Priority int // Higher priority = runs first
}

// NewShutdownManager creates a new shutdown manager
func NewShutdownManager(timeout time.Duration, logger *Logger) *ShutdownManager {
	if logger == nil {
		logger = GetLogger()
	}

	return &ShutdownManager{
		callbacks: make([]ShutdownCallback, 0),
		timeout:   timeout,
		logger:    logger,
	}
}

// Register registers a shutdown callback
func (sm *ShutdownManager) Register(name string, priority int, fn func(ctx context.Context) error) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	sm.callbacks = append(sm.callbacks, ShutdownCallback{
		Name:     name,
		Fn:       fn,
		Priority: priority,
	})

	sm.logger.Debug("Registered shutdown callback: %s (priority: %d)", name, priority)
}

// ListenForShutdown starts listening for shutdown signals
// Returns a channel that will be closed when shutdown signal is received
func (sm *ShutdownManager) ListenForShutdown() <-chan struct{} {
	quit := make(chan struct{})

	go func() {
		// Listen for SIGINT (Ctrl+C) and SIGTERM (Docker/K8s)
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

		sig := <-sigChan
		sm.logger.Info("Received shutdown signal: %v", sig)

		close(quit)
	}()

	return quit
}

// Shutdown performs graceful shutdown of all registered services
func (sm *ShutdownManager) Shutdown() error {
	sm.mu.Lock()
	callbacks := make([]ShutdownCallback, len(sm.callbacks))
	copy(callbacks, sm.callbacks)
	sm.mu.Unlock()

	// Sort by priority (higher priority first)
	for i := 0; i < len(callbacks)-1; i++ {
		for j := i + 1; j < len(callbacks); j++ {
			if callbacks[j].Priority > callbacks[i].Priority {
				callbacks[i], callbacks[j] = callbacks[j], callbacks[i]
			}
		}
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), sm.timeout)
	defer cancel()

	sm.logger.Info("Starting graceful shutdown (timeout: %s)", sm.timeout)

	// Execute callbacks
	var lastErr error
	for _, cb := range callbacks {
		sm.logger.Info("Shutting down: %s", cb.Name)
		
		if err := cb.Fn(ctx); err != nil {
			sm.logger.Error("Shutdown error for %s: %v", cb.Name, err)
			lastErr = err
		} else {
			sm.logger.Info("Shutdown complete: %s", cb.Name)
		}
	}

	sm.logger.Info("Graceful shutdown complete")
	return lastErr
}

// ============================================
// COMMON SHUTDOWN CALLBACKS
// ============================================

// HTTPServerShutdown creates a shutdown callback for HTTP servers
func HTTPServerShutdown(name string, shutdownFn func(ctx context.Context) error) ShutdownCallback {
	return ShutdownCallback{
		Name:     name,
		Fn:       shutdownFn,
		Priority: 100, // High priority - stop accepting requests first
	}
}

// DatabaseShutdown creates a shutdown callback for database connections
func DatabaseShutdown(name string, closeFn func() error) ShutdownCallback {
	return ShutdownCallback{
		Name: name,
		Fn: func(ctx context.Context) error {
			return closeFn()
		},
		Priority: 50, // Medium priority - close after HTTP server
	}
}

// CacheShutdown creates a shutdown callback for cache connections
func CacheShutdown(name string, closeFn func() error) ShutdownCallback {
	return ShutdownCallback{
		Name: name,
		Fn: func(ctx context.Context) error {
			return closeFn()
		},
		Priority: 40, // Lower than DB
	}
}

// WebSocketShutdown creates a shutdown callback for WebSocket manager
func WebSocketShutdown(name string, shutdownFn func()) ShutdownCallback {
	return ShutdownCallback{
		Name: name,
		Fn: func(ctx context.Context) error {
			shutdownFn()
			return nil
		},
		Priority: 90, // High priority - close connections before HTTP server
	}
}

// ============================================
// SIMPLE GRACEFUL SHUTDOWN HELPER
// ============================================

// GracefulShutdown is a simple helper for basic graceful shutdown
func GracefulShutdown(server interface{ Shutdown(context.Context) error }, timeout time.Duration) {
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("Server shutdown error: %v", err)
	}

	log.Println("Server shutdown complete")
}

// ============================================
// CLEANUP SCHEDULER
// ============================================

// CleanupScheduler runs periodic cleanup tasks
type CleanupScheduler struct {
	tasks  []CleanupTask
	mu     sync.Mutex
	stopCh chan struct{}
	logger *Logger
}

// CleanupTask represents a periodic cleanup task
type CleanupTask struct {
	Name     string
	Interval time.Duration
	Fn       func(ctx context.Context) error
}

// NewCleanupScheduler creates a new cleanup scheduler
func NewCleanupScheduler(logger *Logger) *CleanupScheduler {
	if logger == nil {
		logger = GetLogger()
	}

	return &CleanupScheduler{
		tasks:  make([]CleanupTask, 0),
		stopCh: make(chan struct{}),
		logger: logger,
	}
}

// AddTask adds a cleanup task
func (cs *CleanupScheduler) AddTask(name string, interval time.Duration, fn func(ctx context.Context) error) {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	cs.tasks = append(cs.tasks, CleanupTask{
		Name:     name,
		Interval: interval,
		Fn:       fn,
	})

	cs.logger.Debug("Registered cleanup task: %s (interval: %s)", name, interval)
}

// Start starts all cleanup tasks
func (cs *CleanupScheduler) Start() {
	cs.mu.Lock()
	tasks := make([]CleanupTask, len(cs.tasks))
	copy(tasks, cs.tasks)
	cs.mu.Unlock()

	for _, task := range tasks {
		go cs.runTask(task)
	}

	cs.logger.Info("Started %d cleanup tasks", len(tasks))
}

// runTask runs a single cleanup task periodically
func (cs *CleanupScheduler) runTask(task CleanupTask) {
	ticker := time.NewTicker(task.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
			
			if err := task.Fn(ctx); err != nil {
				cs.logger.Error("Cleanup task %s failed: %v", task.Name, err)
			} else {
				cs.logger.Debug("Cleanup task %s completed", task.Name)
			}
			
			cancel()

		case <-cs.stopCh:
			cs.logger.Info("Stopping cleanup task: %s", task.Name)
			return
		}
	}
}

// Stop stops all cleanup tasks
func (cs *CleanupScheduler) Stop() {
	close(cs.stopCh)
	cs.logger.Info("Cleanup scheduler stopped")
}

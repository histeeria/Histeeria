package utils

import (
	"context"
	"fmt"
	"net/http"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
)

// HealthChecker provides comprehensive health checking
type HealthChecker struct {
	redis     *redis.Client
	startTime time.Time
	checks    []HealthCheck
	mu        sync.RWMutex
}

// HealthCheck represents a single health check
type HealthCheck struct {
	Name    string
	Check   func(ctx context.Context) error
	Timeout time.Duration
}

// HealthStatus represents the overall health status
type HealthStatus struct {
	Status      string                   `json:"status"`       // healthy, degraded, unhealthy
	Service     string                   `json:"service"`
	Version     string                   `json:"version"`
	Uptime      string                   `json:"uptime"`
	Timestamp   string                   `json:"timestamp"`
	Checks      map[string]CheckResult   `json:"checks"`
	Stats       *RuntimeStats            `json:"stats,omitempty"`
}

// CheckResult represents the result of a single health check
type CheckResult struct {
	Status  string `json:"status"` // up, down
	Latency string `json:"latency,omitempty"`
	Error   string `json:"error,omitempty"`
}

// RuntimeStats contains runtime statistics
type RuntimeStats struct {
	Goroutines   int    `json:"goroutines"`
	MemoryAlloc  string `json:"memory_alloc"`
	MemoryTotal  string `json:"memory_total"`
	GCCycles     uint32 `json:"gc_cycles"`
	CPUs         int    `json:"cpus"`
}

// NewHealthChecker creates a new health checker
func NewHealthChecker(redis *redis.Client) *HealthChecker {
	hc := &HealthChecker{
		redis:     redis,
		startTime: time.Now(),
		checks:    make([]HealthCheck, 0),
	}

	// Add default Redis check if available
	if redis != nil {
		hc.AddCheck(HealthCheck{
			Name: "redis",
			Check: func(ctx context.Context) error {
				return redis.Ping(ctx).Err()
			},
			Timeout: 5 * time.Second,
		})
	}

	return hc
}

// AddCheck adds a health check
func (hc *HealthChecker) AddCheck(check HealthCheck) {
	hc.mu.Lock()
	defer hc.mu.Unlock()
	hc.checks = append(hc.checks, check)
}

// AddDatabaseCheck adds a database health check
func (hc *HealthChecker) AddDatabaseCheck(name string, checkFn func(ctx context.Context) error) {
	hc.AddCheck(HealthCheck{
		Name:    name,
		Check:   checkFn,
		Timeout: 10 * time.Second,
	})
}

// Check performs all health checks and returns status
func (hc *HealthChecker) Check(ctx context.Context, includeStats bool) *HealthStatus {
	hc.mu.RLock()
	checks := make([]HealthCheck, len(hc.checks))
	copy(checks, hc.checks)
	hc.mu.RUnlock()

	results := make(map[string]CheckResult)
	allHealthy := true
	anyDown := false

	// Run all checks concurrently
	var wg sync.WaitGroup
	var mu sync.Mutex

	for _, check := range checks {
		wg.Add(1)
		go func(c HealthCheck) {
			defer wg.Done()

			checkCtx, cancel := context.WithTimeout(ctx, c.Timeout)
			defer cancel()

			start := time.Now()
			err := c.Check(checkCtx)
			latency := time.Since(start)

			mu.Lock()
			defer mu.Unlock()

			if err != nil {
				results[c.Name] = CheckResult{
					Status:  "down",
					Latency: latency.String(),
					Error:   err.Error(),
				}
				anyDown = true
			} else {
				results[c.Name] = CheckResult{
					Status:  "up",
					Latency: latency.String(),
				}
			}
		}(check)
	}

	wg.Wait()

	// Determine overall status
	status := "healthy"
	if anyDown {
		status = "unhealthy"
	} else if !allHealthy {
		status = "degraded"
	}

	healthStatus := &HealthStatus{
		Status:    status,
		Service:   "histeeria-backend",
		Version:   "1.0.0",
		Uptime:    time.Since(hc.startTime).Round(time.Second).String(),
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Checks:    results,
	}

	if includeStats {
		healthStatus.Stats = hc.getRuntimeStats()
	}

	return healthStatus
}

// getRuntimeStats returns runtime statistics
func (hc *HealthChecker) getRuntimeStats() *RuntimeStats {
	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)

	return &RuntimeStats{
		Goroutines:   runtime.NumGoroutine(),
		MemoryAlloc:  formatBytes(mem.Alloc),
		MemoryTotal:  formatBytes(mem.TotalAlloc),
		GCCycles:     mem.NumGC,
		CPUs:         runtime.NumCPU(),
	}
}

// formatBytes formats bytes to human-readable string
func formatBytes(bytes uint64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := uint64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

// ============================================
// GIN HANDLERS
// ============================================

// HealthHandler returns a Gin handler for health checks
func (hc *HealthChecker) HealthHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Basic health check (fast)
		status := hc.Check(c.Request.Context(), false)

		httpStatus := http.StatusOK
		if status.Status == "unhealthy" {
			httpStatus = http.StatusServiceUnavailable
		}

		c.JSON(httpStatus, status)
	}
}

// ReadinessHandler returns a Gin handler for readiness checks
// Used by Kubernetes/Render to determine if the service can receive traffic
func (hc *HealthChecker) ReadinessHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		status := hc.Check(c.Request.Context(), false)

		if status.Status == "unhealthy" {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"status": "not_ready",
				"checks": status.Checks,
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"status": "ready",
		})
	}
}

// LivenessHandler returns a Gin handler for liveness checks
// Used by Kubernetes/Render to determine if the service should be restarted
func (hc *HealthChecker) LivenessHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Simple liveness check - just return OK if the process is running
		c.JSON(http.StatusOK, gin.H{
			"status": "alive",
			"uptime": time.Since(hc.startTime).Round(time.Second).String(),
		})
	}
}

// MetricsHandler returns a Gin handler for metrics (Prometheus-compatible)
func (hc *HealthChecker) MetricsHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		stats := hc.getRuntimeStats()
		status := hc.Check(c.Request.Context(), false)

		// Return metrics in Prometheus format
		var sb strings.Builder
		
		sb.WriteString("# HELP histeeria_up Service up status\n")
		sb.WriteString("# TYPE histeeria_up gauge\n")
		if status.Status == "healthy" {
			sb.WriteString("histeeria_up 1\n")
		} else {
			sb.WriteString("histeeria_up 0\n")
		}
		
		sb.WriteString("# HELP histeeria_goroutines Number of goroutines\n")
		sb.WriteString("# TYPE histeeria_goroutines gauge\n")
		sb.WriteString(fmt.Sprintf("histeeria_goroutines %d\n", stats.Goroutines))
		
		sb.WriteString("# HELP histeeria_uptime_seconds Uptime in seconds\n")
		sb.WriteString("# TYPE histeeria_uptime_seconds counter\n")
		sb.WriteString(fmt.Sprintf("histeeria_uptime_seconds %d\n", int(time.Since(hc.startTime).Seconds())))

		c.String(http.StatusOK, sb.String())
	}
}


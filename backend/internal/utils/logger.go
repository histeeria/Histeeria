package utils

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"runtime"
	"strings"
	"sync"
	"time"
)

// LogLevel represents the severity of a log message
type LogLevel int

const (
	LevelDebug LogLevel = iota
	LevelInfo
	LevelWarn
	LevelError
	LevelFatal
)

func (l LogLevel) String() string {
	switch l {
	case LevelDebug:
		return "DEBUG"
	case LevelInfo:
		return "INFO"
	case LevelWarn:
		return "WARN"
	case LevelError:
		return "ERROR"
	case LevelFatal:
		return "FATAL"
	default:
		return "UNKNOWN"
	}
}

// Logger provides structured logging with levels and context
type Logger struct {
	mu       sync.Mutex
	level    LogLevel
	format   string // "json" or "text"
	output   io.Writer
	context  map[string]interface{}
	service  string
}

// LogEntry represents a single log entry
type LogEntry struct {
	Timestamp string                 `json:"timestamp"`
	Level     string                 `json:"level"`
	Service   string                 `json:"service,omitempty"`
	Message   string                 `json:"message"`
	Context   map[string]interface{} `json:"context,omitempty"`
	Caller    string                 `json:"caller,omitempty"`
	Error     string                 `json:"error,omitempty"`
}

var (
	defaultLogger *Logger
	once          sync.Once
)

// NewLogger creates a new logger instance
func NewLogger(level, format, service string) *Logger {
	return &Logger{
		level:   parseLevel(level),
		format:  format,
		output:  os.Stdout,
		context: make(map[string]interface{}),
		service: service,
	}
}

// InitLogger initializes the default logger
func InitLogger(level, format, service string) *Logger {
	once.Do(func() {
		defaultLogger = NewLogger(level, format, service)
	})
	return defaultLogger
}

// GetLogger returns the default logger
func GetLogger() *Logger {
	if defaultLogger == nil {
		return NewLogger("info", "json", "histeeria-backend")
	}
	return defaultLogger
}

// parseLevel converts string level to LogLevel
func parseLevel(level string) LogLevel {
	switch strings.ToLower(level) {
	case "debug":
		return LevelDebug
	case "info":
		return LevelInfo
	case "warn", "warning":
		return LevelWarn
	case "error":
		return LevelError
	case "fatal":
		return LevelFatal
	default:
		return LevelInfo
	}
}

// With returns a new logger with additional context
func (l *Logger) With(key string, value interface{}) *Logger {
	newLogger := &Logger{
		level:   l.level,
		format:  l.format,
		output:  l.output,
		context: make(map[string]interface{}),
		service: l.service,
	}
	// Copy existing context
	for k, v := range l.context {
		newLogger.context[k] = v
	}
	// Add new context
	newLogger.context[key] = value
	return newLogger
}

// WithFields returns a new logger with multiple context fields
func (l *Logger) WithFields(fields map[string]interface{}) *Logger {
	newLogger := &Logger{
		level:   l.level,
		format:  l.format,
		output:  l.output,
		context: make(map[string]interface{}),
		service: l.service,
	}
	// Copy existing context
	for k, v := range l.context {
		newLogger.context[k] = v
	}
	// Add new fields
	for k, v := range fields {
		newLogger.context[k] = v
	}
	return newLogger
}

// WithError returns a new logger with error context
func (l *Logger) WithError(err error) *Logger {
	if err == nil {
		return l
	}
	return l.With("error", err.Error())
}

// log writes a log entry
func (l *Logger) log(level LogLevel, msg string, args ...interface{}) {
	if level < l.level {
		return
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	// Format message if args provided
	if len(args) > 0 {
		msg = fmt.Sprintf(msg, args...)
	}

	entry := LogEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339Nano),
		Level:     level.String(),
		Service:   l.service,
		Message:   msg,
		Context:   l.context,
	}

	// Add caller info for errors
	if level >= LevelError {
		_, file, line, ok := runtime.Caller(2)
		if ok {
			// Get just the filename, not the full path
			parts := strings.Split(file, "/")
			entry.Caller = fmt.Sprintf("%s:%d", parts[len(parts)-1], line)
		}
	}

	// Get error from context if present
	if errStr, ok := l.context["error"].(string); ok {
		entry.Error = errStr
		delete(l.context, "error") // Remove from context to avoid duplication
	}

	// Output based on format
	if l.format == "json" {
		l.outputJSON(entry)
	} else {
		l.outputText(entry)
	}
}

// outputJSON writes log as JSON
func (l *Logger) outputJSON(entry LogEntry) {
	data, err := json.Marshal(entry)
	if err != nil {
		fmt.Fprintf(l.output, "LOG_ERROR: %v\n", err)
		return
	}
	fmt.Fprintln(l.output, string(data))
}

// outputText writes log as human-readable text
func (l *Logger) outputText(entry LogEntry) {
	// Format: 2024-01-15T10:30:45Z [INFO] [service] message key=value
	var builder strings.Builder
	
	builder.WriteString(entry.Timestamp)
	builder.WriteString(" [")
	builder.WriteString(entry.Level)
	builder.WriteString("]")
	
	if entry.Service != "" {
		builder.WriteString(" [")
		builder.WriteString(entry.Service)
		builder.WriteString("]")
	}
	
	builder.WriteString(" ")
	builder.WriteString(entry.Message)
	
	// Add context
	for k, v := range entry.Context {
		builder.WriteString(" ")
		builder.WriteString(k)
		builder.WriteString("=")
		builder.WriteString(fmt.Sprintf("%v", v))
	}
	
	if entry.Error != "" {
		builder.WriteString(" error=\"")
		builder.WriteString(entry.Error)
		builder.WriteString("\"")
	}
	
	if entry.Caller != "" {
		builder.WriteString(" caller=")
		builder.WriteString(entry.Caller)
	}
	
	fmt.Fprintln(l.output, builder.String())
}

// Debug logs a debug message
func (l *Logger) Debug(msg string, args ...interface{}) {
	l.log(LevelDebug, msg, args...)
}

// Info logs an info message
func (l *Logger) Info(msg string, args ...interface{}) {
	l.log(LevelInfo, msg, args...)
}

// Warn logs a warning message
func (l *Logger) Warn(msg string, args ...interface{}) {
	l.log(LevelWarn, msg, args...)
}

// Error logs an error message
func (l *Logger) Error(msg string, args ...interface{}) {
	l.log(LevelError, msg, args...)
}

// Fatal logs a fatal message and exits
func (l *Logger) Fatal(msg string, args ...interface{}) {
	l.log(LevelFatal, msg, args...)
	os.Exit(1)
}

// ============================================
// CONVENIENCE FUNCTIONS (use default logger)
// ============================================

// Debug logs a debug message using the default logger
func Debug(msg string, args ...interface{}) {
	GetLogger().Debug(msg, args...)
}

// Info logs an info message using the default logger
func Info(msg string, args ...interface{}) {
	GetLogger().Info(msg, args...)
}

// Warn logs a warning message using the default logger
func Warn(msg string, args ...interface{}) {
	GetLogger().Warn(msg, args...)
}

// Error logs an error message using the default logger
func Error(msg string, args ...interface{}) {
	GetLogger().Error(msg, args...)
}

// Fatal logs a fatal message and exits using the default logger
func Fatal(msg string, args ...interface{}) {
	GetLogger().Fatal(msg, args...)
}

// ============================================
// REQUEST LOGGING MIDDLEWARE
// ============================================

// RequestLogFields returns common fields for request logging
func RequestLogFields(method, path, ip, userID string) map[string]interface{} {
	return map[string]interface{}{
		"method":  method,
		"path":    path,
		"ip":      ip,
		"user_id": userID,
	}
}

// ResponseLogFields returns fields for response logging
func ResponseLogFields(status int, latency time.Duration, size int) map[string]interface{} {
	return map[string]interface{}{
		"status":     status,
		"latency_ms": latency.Milliseconds(),
		"size":       size,
	}
}

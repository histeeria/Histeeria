package queue

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"time"
)

// ============================================
// QUEUE INTERFACE
// ============================================

// QueueProvider defines the interface for message queue implementations
type QueueProvider interface {
	// Enqueue adds a job to the queue
	Enqueue(ctx context.Context, queueName string, job *Job) error

	// Dequeue retrieves a job from the queue (blocks until job available or timeout)
	Dequeue(ctx context.Context, queueName string, timeout time.Duration) (*Job, error)

	// Acknowledge marks a job as successfully processed
	Acknowledge(ctx context.Context, queueName string, jobID string) error

	// Reject marks a job as failed (will be retried or moved to dead letter)
	Reject(ctx context.Context, queueName string, jobID string, reason string) error

	// GetPendingCount returns the number of pending jobs in a queue
	GetPendingCount(ctx context.Context, queueName string) (int64, error)

	// GetFailedCount returns the number of failed jobs
	GetFailedCount(ctx context.Context, queueName string) (int64, error)

	// RetryFailed moves failed jobs back to the queue
	RetryFailed(ctx context.Context, queueName string) (int64, error)

	// Ping checks if the queue is available
	Ping(ctx context.Context) error

	// Close closes the connection
	Close() error
}

// ============================================
// JOB STRUCTURE
// ============================================

// Job represents a task to be processed
type Job struct {
	ID        string            `json:"id"`
	Type      string            `json:"type"`
	Payload   json.RawMessage   `json:"payload"`
	Priority  int               `json:"priority"`
	Attempts  int               `json:"attempts"`
	MaxRetry  int               `json:"max_retry"`
	CreatedAt time.Time         `json:"created_at"`
	Metadata  map[string]string `json:"metadata,omitempty"`
}

// NewJob creates a new job with the given type and payload
func NewJob(jobType string, payload interface{}) (*Job, error) {
	data, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	return &Job{
		ID:        generateJobID(),
		Type:      jobType,
		Payload:   data,
		Priority:  0,
		Attempts:  0,
		MaxRetry:  3,
		CreatedAt: time.Now(),
		Metadata:  make(map[string]string),
	}, nil
}

// NewJobWithPriority creates a new job with priority
func NewJobWithPriority(jobType string, payload interface{}, priority int) (*Job, error) {
	job, err := NewJob(jobType, payload)
	if err != nil {
		return nil, err
	}
	job.Priority = priority
	return job, nil
}

// UnmarshalPayload unmarshals the payload into the provided struct
func (j *Job) UnmarshalPayload(v interface{}) error {
	return json.Unmarshal(j.Payload, v)
}

// SetMetadata adds metadata to the job
func (j *Job) SetMetadata(key, value string) {
	if j.Metadata == nil {
		j.Metadata = make(map[string]string)
	}
	j.Metadata[key] = value
}

// GetMetadata retrieves metadata from the job
func (j *Job) GetMetadata(key string) string {
	if j.Metadata == nil {
		return ""
	}
	return j.Metadata[key]
}

// ============================================
// QUEUE NAMES
// ============================================

const (
	// QueueEmail for sending emails
	QueueEmail = "queue:email"

	// QueueNotification for sending push notifications
	QueueNotification = "queue:notification"

	// QueueMedia for processing media files
	QueueMedia = "queue:media"

	// QueueFeed for feed updates/invalidation
	QueueFeed = "queue:feed"

	// QueueWebhook for webhook deliveries
	QueueWebhook = "queue:webhook"

	// QueueDefault for general tasks
	QueueDefault = "queue:default"
)

// ============================================
// JOB TYPES
// ============================================

const (
	// Email jobs
	JobTypeEmailWelcome       = "email:welcome"
	JobTypeEmailVerification  = "email:verification"
	JobTypeEmailPasswordReset = "email:password_reset"
	JobTypeEmailNotification  = "email:notification"

	// Notification jobs
	JobTypePushNotification  = "notification:push"
	JobTypeInAppNotification = "notification:in_app"

	// Media jobs
	JobTypeMediaCompress  = "media:compress"
	JobTypeMediaThumbnail = "media:thumbnail"
	JobTypeMediaTranscode = "media:transcode"
	JobTypeMediaDelete    = "media:delete"

	// Feed jobs
	JobTypeFeedInvalidate = "feed:invalidate"
	JobTypeFeedWarm       = "feed:warm"

	// Webhook jobs
	JobTypeWebhookDeliver = "webhook:deliver"
)

// ============================================
// HELPER FUNCTIONS
// ============================================

func generateJobID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// ============================================
// JOB PAYLOADS
// ============================================

// EmailJobPayload represents an email job payload
type EmailJobPayload struct {
	To       string            `json:"to"`
	Subject  string            `json:"subject"`
	Template string            `json:"template"`
	Data     map[string]string `json:"data"`
}

// NotificationJobPayload represents a notification job payload
type NotificationJobPayload struct {
	UserID  string            `json:"user_id"`
	Type    string            `json:"type"`
	Title   string            `json:"title"`
	Body    string            `json:"body"`
	Data    map[string]string `json:"data,omitempty"`
	Channel string            `json:"channel,omitempty"` // "push", "email", "in_app"
}

// MediaJobPayload represents a media processing job payload
type MediaJobPayload struct {
	MediaID   string                 `json:"media_id"`
	SourceURL string                 `json:"source_url"`
	TargetKey string                 `json:"target_key,omitempty"`
	Options   map[string]interface{} `json:"options,omitempty"`
}

// FeedInvalidatePayload represents a feed invalidation job payload
type FeedInvalidatePayload struct {
	UserID   string `json:"user_id"`
	FeedType string `json:"feed_type"` // "home", "explore", "hashtag"
	PostID   string `json:"post_id,omitempty"`
	Hashtag  string `json:"hashtag,omitempty"`
}

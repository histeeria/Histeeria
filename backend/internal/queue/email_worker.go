package queue

import (
	"context"
	"fmt"
	"log"
)

// ============================================
// EMAIL WORKER
// ============================================

// EmailSender interface for sending emails
type EmailSender interface {
	SendWelcomeEmail(to, name string) error
	SendVerificationEmail(to, code string) error
	SendPasswordResetEmail(to, token string) error
	SendNotificationEmail(to, subject, body string) error
}

// EmailWorker processes email jobs from the queue
type EmailWorker struct {
	pool   *WorkerPool
	sender EmailSender
}

// NewEmailWorker creates a new email worker
func NewEmailWorker(provider QueueProvider, sender EmailSender, workers int) *EmailWorker {
	cfg := &WorkerPoolConfig{
		Workers:    workers,
		QueueName:  QueueEmail,
		PollTime:   5000, // 5 seconds
		MaxRetries: 3,
	}

	pool := NewWorkerPool(provider, cfg)
	worker := &EmailWorker{
		pool:   pool,
		sender: sender,
	}

	// Register handlers
	pool.RegisterHandler(JobTypeEmailWelcome, worker.handleWelcome)
	pool.RegisterHandler(JobTypeEmailVerification, worker.handleVerification)
	pool.RegisterHandler(JobTypeEmailPasswordReset, worker.handlePasswordReset)
	pool.RegisterHandler(JobTypeEmailNotification, worker.handleNotification)

	return worker
}

// Start starts the email worker
func (w *EmailWorker) Start() {
	w.pool.Start()
}

// Stop stops the email worker
func (w *EmailWorker) Stop() {
	w.pool.Stop()
}

// GetStats returns worker statistics
func (w *EmailWorker) GetStats() map[string]interface{} {
	return w.pool.GetStats()
}

// handleWelcome handles welcome email jobs
func (w *EmailWorker) handleWelcome(ctx context.Context, job *Job) error {
	var payload struct {
		To   string `json:"to"`
		Name string `json:"name"`
	}

	if err := job.UnmarshalPayload(&payload); err != nil {
		return fmt.Errorf("invalid payload: %w", err)
	}

	log.Printf("[EmailWorker] Sending welcome email to: %s", payload.To)
	return w.sender.SendWelcomeEmail(payload.To, payload.Name)
}

// handleVerification handles verification email jobs
func (w *EmailWorker) handleVerification(ctx context.Context, job *Job) error {
	var payload struct {
		To   string `json:"to"`
		Code string `json:"code"`
	}

	if err := job.UnmarshalPayload(&payload); err != nil {
		return fmt.Errorf("invalid payload: %w", err)
	}

	log.Printf("[EmailWorker] Sending verification email to: %s", payload.To)
	return w.sender.SendVerificationEmail(payload.To, payload.Code)
}

// handlePasswordReset handles password reset email jobs
func (w *EmailWorker) handlePasswordReset(ctx context.Context, job *Job) error {
	var payload struct {
		To    string `json:"to"`
		Token string `json:"token"`
	}

	if err := job.UnmarshalPayload(&payload); err != nil {
		return fmt.Errorf("invalid payload: %w", err)
	}

	log.Printf("[EmailWorker] Sending password reset email to: %s", payload.To)
	return w.sender.SendPasswordResetEmail(payload.To, payload.Token)
}

// handleNotification handles notification email jobs
func (w *EmailWorker) handleNotification(ctx context.Context, job *Job) error {
	var payload EmailJobPayload

	if err := job.UnmarshalPayload(&payload); err != nil {
		return fmt.Errorf("invalid payload: %w", err)
	}

	log.Printf("[EmailWorker] Sending notification email to: %s, subject: %s", payload.To, payload.Subject)

	// Build body from template data (simplified)
	body := ""
	if payload.Data != nil {
		if b, ok := payload.Data["body"]; ok {
			body = b
		}
	}

	return w.sender.SendNotificationEmail(payload.To, payload.Subject, body)
}

// ============================================
// QUEUE HELPER FUNCTIONS
// ============================================

// QueueWelcomeEmail queues a welcome email
func QueueWelcomeEmail(ctx context.Context, provider QueueProvider, to, name string) error {
	job, err := NewJob(JobTypeEmailWelcome, map[string]string{
		"to":   to,
		"name": name,
	})
	if err != nil {
		return err
	}

	return provider.Enqueue(ctx, QueueEmail, job)
}

// QueueVerificationEmail queues a verification email
func QueueVerificationEmail(ctx context.Context, provider QueueProvider, to, code string) error {
	job, err := NewJob(JobTypeEmailVerification, map[string]string{
		"to":   to,
		"code": code,
	})
	if err != nil {
		return err
	}

	return provider.Enqueue(ctx, QueueEmail, job)
}

// QueuePasswordResetEmail queues a password reset email
func QueuePasswordResetEmail(ctx context.Context, provider QueueProvider, to, token string) error {
	job, err := NewJob(JobTypeEmailPasswordReset, map[string]string{
		"to":    to,
		"token": token,
	})
	if err != nil {
		return err
	}

	return provider.Enqueue(ctx, QueueEmail, job)
}

// QueueNotificationEmail queues a notification email
func QueueNotificationEmail(ctx context.Context, provider QueueProvider, to, subject, body string) error {
	payload := EmailJobPayload{
		To:      to,
		Subject: subject,
		Data:    map[string]string{"body": body},
	}

	job, err := NewJob(JobTypeEmailNotification, payload)
	if err != nil {
		return err
	}

	return provider.Enqueue(ctx, QueueEmail, job)
}

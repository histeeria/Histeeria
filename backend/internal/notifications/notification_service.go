package notifications

import (
	"context"
	"fmt"
	"log"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/queue"
	"histeeria-backend/internal/repository"
	"histeeria-backend/internal/websocket"

	"github.com/google/uuid"
)

// NotificationService handles notification business logic
type NotificationService struct {
	repo          repository.NotificationRepository
	userRepo      repository.UserRepository
	wsManager     *websocket.Manager
	factory       *NotificationFactory
	emailSvc      *EmailService
	queueProvider queue.QueueProvider // Queue provider for async email sending
}

// NewNotificationService creates a new notification service
func NewNotificationService(
	repo repository.NotificationRepository,
	userRepo repository.UserRepository,
	wsManager *websocket.Manager,
	emailSvc *EmailService,
	queueProvider queue.QueueProvider,
) *NotificationService {
	return &NotificationService{
		repo:          repo,
		userRepo:      userRepo,
		wsManager:     wsManager,
		factory:       NewNotificationFactory(),
		emailSvc:      emailSvc,
		queueProvider: queueProvider,
	}
}

// =====================================================
// CREATE NOTIFICATIONS
// =====================================================

// CreateNotification creates and delivers a notification
func (s *NotificationService) CreateNotification(ctx context.Context, notification *models.Notification) error {
	log.Printf("[NotificationService] Creating notification: type=%s user=%s", notification.Type, notification.UserID)

	// Check if user has in-app notifications enabled
	prefs, err := s.repo.GetPreferences(ctx, notification.UserID)
	if err != nil {
		log.Printf("[NotificationService] Failed to get preferences for user %s: %v", notification.UserID, err)
		// Continue anyway with default preferences
		prefs = &models.NotificationPreferences{
			InAppEnabled: true,
			EmailEnabled: false,
			CategoriesEnabled: map[string]bool{
				string(notification.Category): true,
			},
		}
	}

	// Check if in-app notifications are enabled
	if !prefs.InAppEnabled {
		log.Printf("[NotificationService] In-app notifications disabled for user %s", notification.UserID)
		return nil
	}

	// Check if this category is enabled
	if !prefs.IsCategoryEnabled(notification.Category) {
		log.Printf("[NotificationService] Category %s disabled for user %s", notification.Category, notification.UserID)
		return nil
	}

	// Save notification to database
	if err := s.repo.Create(ctx, notification); err != nil {
		log.Printf("[NotificationService] Failed to create notification: %v", err)
		return fmt.Errorf("failed to create notification: %w", err)
	}

	// Fetch actor user details if needed
	if notification.ActorID != nil && notification.ActorUser == nil {
		actor, err := s.userRepo.GetUserByID(ctx, *notification.ActorID)
		if err == nil {
			notification.ActorUser = actor
		}
	}

	// Send via WebSocket (real-time)
	s.sendViaWebSocket(notification)

	// Send via email if enabled and instant delivery
	if prefs.ShouldSendEmail(notification.Type) && prefs.EmailFrequency == models.EmailFrequencyInstant {
		// Get user email
		user, err := s.userRepo.GetUserByID(ctx, notification.UserID)
		if err == nil && user.Email != "" {
			// Build email subject and body from notification
			subject, body := s.buildNotificationEmail(notification)

			// Queue email (async) if queue provider is available
			if s.queueProvider != nil {
				if err := queue.QueueNotificationEmail(ctx, s.queueProvider, user.Email, subject, body); err != nil {
					log.Printf("[NotificationService] Failed to queue email to %s: %v", user.Email, err)
					// Fallback to direct send if queue fails
					if s.emailSvc != nil {
						go func() {
							if fallbackErr := s.emailSvc.SendNotificationEmail(context.Background(), user.Email, notification); fallbackErr != nil {
								log.Printf("[NotificationService] Failed to send email (fallback) to %s: %v", user.Email, fallbackErr)
							}
						}()
					}
				} else {
					log.Printf("[NotificationService] Email notification queued for user %s", notification.UserID)
				}
			} else if s.emailSvc != nil {
				// Fallback to direct send if queue not available
				go func() {
					if err := s.emailSvc.SendNotificationEmail(context.Background(), user.Email, notification); err != nil {
						log.Printf("[NotificationService] Failed to send email to %s: %v", user.Email, err)
					}
				}()
			}
		}
	}

	log.Printf("[NotificationService] Notification created successfully: id=%s", notification.ID)
	return nil
}

// buildNotificationEmail builds email subject and body from notification
func (s *NotificationService) buildNotificationEmail(notification *models.Notification) (subject, body string) {
	// Build subject based on notification type
	subject = fmt.Sprintf("New notification from Histeeria")

	// Build body from notification
	body = fmt.Sprintf("You have a new notification: %s", notification.Type)

	// Add actor info if available
	if notification.ActorUser != nil && notification.ActorUser.DisplayName != "" {
		body = fmt.Sprintf("%s from %s", body, notification.ActorUser.DisplayName)
	}

	return subject, body
}

// CreateBulkNotifications creates multiple notifications at once
func (s *NotificationService) CreateBulkNotifications(ctx context.Context, notifications []*models.Notification) error {
	for _, notification := range notifications {
		if err := s.CreateNotification(ctx, notification); err != nil {
			log.Printf("[NotificationService] Failed to create bulk notification: %v", err)
			// Continue with others
		}
	}
	return nil
}

// =====================================================
// READ NOTIFICATIONS
// =====================================================

// GetNotifications retrieves notifications for a user with filters
func (s *NotificationService) GetNotifications(
	ctx context.Context,
	userID uuid.UUID,
	category *models.NotificationCategory,
	unread *bool,
	limit int,
	offset int,
) ([]*models.NotificationResponse, int, int, error) {
	// Get notifications from repository
	notifications, total, err := s.repo.GetByUser(ctx, userID, category, unread, limit, offset)
	if err != nil {
		return nil, 0, 0, fmt.Errorf("failed to get notifications: %w", err)
	}

	// Get unread count
	unreadCount, err := s.repo.GetUnreadCount(ctx, userID, category)
	if err != nil {
		log.Printf("[NotificationService] Failed to get unread count: %v", err)
		unreadCount = 0
	}

	// Convert to response format
	responses := make([]*models.NotificationResponse, len(notifications))
	for i, notif := range notifications {
		responses[i] = notif.ToResponse()
	}

	return responses, total, unreadCount, nil
}

// GetNotificationByID retrieves a single notification
func (s *NotificationService) GetNotificationByID(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*models.NotificationResponse, error) {
	notification, err := s.repo.GetByID(ctx, id, userID)
	if err != nil {
		return nil, fmt.Errorf("notification not found: %w", err)
	}

	return notification.ToResponse(), nil
}

// GetUnreadCount gets the total unread count
func (s *NotificationService) GetUnreadCount(ctx context.Context, userID uuid.UUID, category *models.NotificationCategory) (int, error) {
	return s.repo.GetUnreadCount(ctx, userID, category)
}

// GetCategoryCounts gets unread counts per category
func (s *NotificationService) GetCategoryCounts(ctx context.Context, userID uuid.UUID) (map[string]int, error) {
	return s.repo.GetCategoryCounts(ctx, userID)
}

// =====================================================
// UPDATE NOTIFICATIONS
// =====================================================

// MarkAsRead marks a notification as read
func (s *NotificationService) MarkAsRead(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	if err := s.repo.MarkAsRead(ctx, id, userID); err != nil {
		return fmt.Errorf("failed to mark as read: %w", err)
	}

	// Send count update via WebSocket
	s.sendCountUpdate(ctx, userID)

	return nil
}

// MarkAllAsRead marks all notifications as read for a user
func (s *NotificationService) MarkAllAsRead(ctx context.Context, userID uuid.UUID, category *models.NotificationCategory) error {
	if err := s.repo.MarkAllAsRead(ctx, userID, category); err != nil {
		return fmt.Errorf("failed to mark all as read: %w", err)
	}

	// Send count update via WebSocket
	s.sendCountUpdate(ctx, userID)

	return nil
}

// DeleteNotification deletes a notification
func (s *NotificationService) DeleteNotification(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	if err := s.repo.Delete(ctx, id, userID); err != nil {
		return fmt.Errorf("failed to delete notification: %w", err)
	}

	// Send count update via WebSocket
	s.sendCountUpdate(ctx, userID)

	return nil
}

// =====================================================
// INLINE ACTIONS
// =====================================================

// TakeAction handles inline notification actions
func (s *NotificationService) TakeAction(ctx context.Context, id uuid.UUID, userID uuid.UUID, actionType string) error {
	// Get the notification
	notification, err := s.repo.GetByID(ctx, id, userID)
	if err != nil {
		return fmt.Errorf("notification not found: %w", err)
	}

	if !notification.IsActionable {
		return fmt.Errorf("notification is not actionable")
	}

	if notification.ActionTaken {
		return fmt.Errorf("action already taken")
	}

	// Validate action type matches
	if notification.ActionType != nil && *notification.ActionType != actionType {
		return fmt.Errorf("invalid action type: expected %s, got %s", *notification.ActionType, actionType)
	}

	// Mark action as taken
	if err := s.repo.UpdateActionTaken(ctx, id, userID); err != nil {
		return fmt.Errorf("failed to update action: %w", err)
	}

	log.Printf("[NotificationService] Action taken: notification=%s action=%s user=%s", id, actionType, userID)

	// Note: The actual action (follow back, accept connection, etc.) should be
	// handled by the calling code (e.g., relationship service)
	// This just marks the notification as acted upon

	return nil
}

// =====================================================
// PREFERENCES
// =====================================================

// GetPreferences retrieves notification preferences for a user
func (s *NotificationService) GetPreferences(ctx context.Context, userID uuid.UUID) (*models.NotificationPreferences, error) {
	return s.repo.GetPreferences(ctx, userID)
}

// UpdatePreferences updates notification preferences
func (s *NotificationService) UpdatePreferences(ctx context.Context, userID uuid.UUID, req *models.UpdateNotificationPreferencesRequest) error {
	// Get current preferences
	prefs, err := s.repo.GetPreferences(ctx, userID)
	if err != nil {
		// Create new preferences if they don't exist
		prefs = &models.NotificationPreferences{
			UserID:               userID,
			EmailEnabled:         true,
			EmailTypes:           make(map[string]bool),
			EmailFrequency:       models.EmailFrequencyInstant,
			InAppEnabled:         true,
			PushEnabled:          false,
			InlineActionsEnabled: true,
			CategoriesEnabled:    make(map[string]bool),
		}
	}

	// Update fields if provided
	if req.EmailEnabled != nil {
		prefs.EmailEnabled = *req.EmailEnabled
	}
	if req.EmailTypes != nil {
		prefs.EmailTypes = req.EmailTypes
	}
	if req.EmailFrequency != nil {
		prefs.EmailFrequency = *req.EmailFrequency
	}
	if req.InAppEnabled != nil {
		prefs.InAppEnabled = *req.InAppEnabled
	}
	if req.PushEnabled != nil {
		prefs.PushEnabled = *req.PushEnabled
	}
	if req.InlineActionsEnabled != nil {
		prefs.InlineActionsEnabled = *req.InlineActionsEnabled
	}
	if req.CategoriesEnabled != nil {
		prefs.CategoriesEnabled = req.CategoriesEnabled
	}

	// Save preferences
	if err := s.repo.UpsertPreferences(ctx, prefs); err != nil {
		return fmt.Errorf("failed to update preferences: %w", err)
	}

	log.Printf("[NotificationService] Preferences updated for user %s", userID)
	return nil
}

// =====================================================
// CLEANUP
// =====================================================

// DeleteExpiredNotifications deletes notifications that have passed their expiry date
func (s *NotificationService) DeleteExpiredNotifications(ctx context.Context) (int, error) {
	count, err := s.repo.DeleteExpired(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to delete expired notifications: %w", err)
	}

	log.Printf("[NotificationService] Deleted %d expired notifications", count)
	return count, nil
}

// =====================================================
// WEBSOCKET HELPERS
// =====================================================

// sendViaWebSocket sends a notification via WebSocket
func (s *NotificationService) sendViaWebSocket(notification *models.Notification) {
	if s.wsManager == nil {
		return
	}

	response := notification.ToResponse()
	s.wsManager.BroadcastNotification(notification.UserID, response)

	log.Printf("[NotificationService] Sent notification via WebSocket to user %s", notification.UserID)
}

// sendCountUpdate sends an unread count update via WebSocket
func (s *NotificationService) sendCountUpdate(ctx context.Context, userID uuid.UUID) {
	if s.wsManager == nil {
		return
	}

	// Get total unread count
	total, err := s.repo.GetUnreadCount(ctx, userID, nil)
	if err != nil {
		log.Printf("[NotificationService] Failed to get total unread count: %v", err)
		return
	}

	// Get category counts
	categoryCounts, err := s.repo.GetCategoryCounts(ctx, userID)
	if err != nil {
		log.Printf("[NotificationService] Failed to get category counts: %v", err)
		return
	}

	s.wsManager.BroadcastCountUpdate(userID, total, categoryCounts)

	log.Printf("[NotificationService] Sent count update via WebSocket to user %s (total: %d)", userID, total)
}

// =====================================================
// FACTORY METHODS (Convenience)
// =====================================================

// These methods provide convenient access to the factory for creating typed notifications

// CreateFollowNotification creates and sends a follow notification
func (s *NotificationService) CreateFollowNotification(ctx context.Context, followerID, followedID uuid.UUID, followerUsername string) error {
	notification := s.factory.NewFollowNotification(followerID, followedID, followerUsername)
	return s.CreateNotification(ctx, notification)
}

// CreateConnectionRequestNotification creates and sends a connection request notification
func (s *NotificationService) CreateConnectionRequestNotification(ctx context.Context, fromID, toID uuid.UUID, fromUsername string) error {
	notification := s.factory.NewConnectionRequestNotification(fromID, toID, fromUsername)
	return s.CreateNotification(ctx, notification)
}

// CreateConnectionAcceptedNotification creates and sends a connection accepted notification
func (s *NotificationService) CreateConnectionAcceptedNotification(ctx context.Context, acceptorID, requesterID uuid.UUID, acceptorUsername string) error {
	notification := s.factory.NewConnectionAcceptedNotification(acceptorID, requesterID, acceptorUsername)
	return s.CreateNotification(ctx, notification)
}

// CreateCollaborationRequestNotification creates and sends a collaboration request notification
func (s *NotificationService) CreateCollaborationRequestNotification(ctx context.Context, fromID, toID uuid.UUID, fromUsername string) error {
	notification := s.factory.NewCollaborationRequestNotification(fromID, toID, fromUsername)
	return s.CreateNotification(ctx, notification)
}

// CreateCollaborationAcceptedNotification creates and sends a collaboration accepted notification
func (s *NotificationService) CreateCollaborationAcceptedNotification(ctx context.Context, acceptorID, requesterID uuid.UUID, acceptorUsername string) error {
	notification := s.factory.NewCollaborationAcceptedNotification(acceptorID, requesterID, acceptorUsername)
	return s.CreateNotification(ctx, notification)
}

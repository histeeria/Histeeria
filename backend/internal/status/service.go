package status

import (
	"context"
	"fmt"
	"time"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"

	"github.com/google/uuid"
)

// Service handles status business logic
type Service struct {
	statusRepo repository.StatusRepository
}

// NewService creates a new status service
func NewService(statusRepo repository.StatusRepository) *Service {
	return &Service{
		statusRepo: statusRepo,
	}
}

// CreateStatus creates a new status (24-hour story)
func (s *Service) CreateStatus(ctx context.Context, req *models.CreateStatusRequest, userID uuid.UUID) (*models.Status, error) {
	// Validate request
	if err := req.Validate(); err != nil {
		return nil, err
	}

	// Create status
	status := &models.Status{
		UserID:          userID,
		StatusType:      req.StatusType,
		Content:         req.Content,
		MediaURL:        req.MediaURL,
		MediaType:       req.MediaType,
		BackgroundColor: "#1a1f3a",                      // Default
		ExpiresAt:       time.Now().Add(24 * time.Hour), // 24 hours from now
	}

	// Set background color for text statuses
	if req.BackgroundColor != nil && *req.BackgroundColor != "" {
		status.BackgroundColor = *req.BackgroundColor
	}

	// Create status in database
	if err := s.statusRepo.CreateStatus(ctx, status); err != nil {
		return nil, fmt.Errorf("failed to create status: %w", err)
	}

	return status, nil
}

// GetStatus retrieves a single status by ID
func (s *Service) GetStatus(ctx context.Context, statusID, viewerID uuid.UUID) (*models.Status, error) {
	status, err := s.statusRepo.GetStatus(ctx, statusID, viewerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get status: %w", err)
	}

	// Check if expired
	if time.Now().After(status.ExpiresAt) {
		return nil, models.ErrStatusExpired
	}

	// Record view if not already viewed (async in production)
	if !status.IsViewed && viewerID != uuid.Nil {
		go func() {
			s.statusRepo.CreateStatusView(context.Background(), statusID, viewerID)
		}()
	}

	return status, nil
}

// GetUserStatuses retrieves all active statuses for a user
func (s *Service) GetUserStatuses(ctx context.Context, userID, viewerID uuid.UUID, limit int) ([]models.Status, error) {
	if limit <= 0 {
		limit = 50
	}

	statuses, err := s.statusRepo.GetUserStatuses(ctx, userID, viewerID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get user statuses: %w", err)
	}

	// Filter expired statuses
	activeStatuses := make([]models.Status, 0)
	now := time.Now()
	for _, status := range statuses {
		if now.Before(status.ExpiresAt) {
			activeStatuses = append(activeStatuses, status)
		}
	}

	return activeStatuses, nil
}

// GetStatusesForFeed retrieves statuses from followed users for the feed
func (s *Service) GetStatusesForFeed(ctx context.Context, viewerID uuid.UUID, limit int) ([]models.Status, error) {
	if limit <= 0 {
		limit = 100
	}

	statuses, err := s.statusRepo.GetStatusesForFeed(ctx, viewerID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get feed statuses: %w", err)
	}

	// Filter expired statuses
	activeStatuses := make([]models.Status, 0)
	now := time.Now()
	for _, status := range statuses {
		if now.Before(status.ExpiresAt) {
			activeStatuses = append(activeStatuses, status)
		}
	}

	return activeStatuses, nil
}

// DeleteStatus deletes a status (only if owner)
func (s *Service) DeleteStatus(ctx context.Context, statusID, userID uuid.UUID) error {
	// Verify ownership
	status, err := s.statusRepo.GetStatus(ctx, statusID, userID)
	if err != nil {
		return fmt.Errorf("failed to get status: %w", err)
	}

	if status.UserID != userID {
		return models.ErrStatusUnauthorized
	}

	if err := s.statusRepo.DeleteStatus(ctx, statusID, userID); err != nil {
		return fmt.Errorf("failed to delete status: %w", err)
	}

	return nil
}

// ViewStatus records a view on a status
func (s *Service) ViewStatus(ctx context.Context, statusID, viewerID uuid.UUID) error {
	if err := s.statusRepo.CreateStatusView(ctx, statusID, viewerID); err != nil {
		return fmt.Errorf("failed to record view: %w", err)
	}
	return nil
}

// GetStatusViews retrieves views for a status
func (s *Service) GetStatusViews(ctx context.Context, statusID uuid.UUID, limit int) ([]models.StatusView, error) {
	if limit <= 0 {
		limit = 100
	}

	views, err := s.statusRepo.GetStatusViews(ctx, statusID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get status views: %w", err)
	}

	return views, nil
}

// ReactToStatus adds or updates a reaction on a status
func (s *Service) ReactToStatus(ctx context.Context, statusID, userID uuid.UUID, emoji string) error {
	// Validate emoji
	validEmojis := map[string]bool{"👍": true, "💯": true, "❤️": true, "🤝": true, "💡": true}
	if !validEmojis[emoji] {
		return models.ErrInvalidEmoji
	}

	if err := s.statusRepo.ReactToStatus(ctx, statusID, userID, emoji); err != nil {
		return fmt.Errorf("failed to react to status: %w", err)
	}

	return nil
}

// RemoveStatusReaction removes a reaction from a status
func (s *Service) RemoveStatusReaction(ctx context.Context, statusID, userID uuid.UUID) error {
	if err := s.statusRepo.RemoveStatusReaction(ctx, statusID, userID); err != nil {
		return fmt.Errorf("failed to remove reaction: %w", err)
	}

	return nil
}

// GetStatusReactions retrieves reactions for a status
func (s *Service) GetStatusReactions(ctx context.Context, statusID uuid.UUID, limit int) ([]models.StatusReaction, error) {
	if limit <= 0 {
		limit = 50
	}

	reactions, err := s.statusRepo.GetStatusReactions(ctx, statusID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get reactions: %w", err)
	}

	return reactions, nil
}

// CreateStatusComment creates a comment on a status
func (s *Service) CreateStatusComment(ctx context.Context, statusID, userID uuid.UUID, content string) (*models.StatusComment, error) {
	// Validate content
	if len(content) == 0 || len(content) > 500 {
		return nil, models.ErrCommentTooLong
	}

	// Verify status exists and is not expired
	status, err := s.statusRepo.GetStatus(ctx, statusID, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get status: %w", err)
	}

	if time.Now().After(status.ExpiresAt) {
		return nil, models.ErrStatusExpired
	}

	comment := &models.StatusComment{
		StatusID: statusID,
		UserID:   userID,
		Content:  content,
	}

	if err := s.statusRepo.CreateStatusComment(ctx, comment); err != nil {
		return nil, fmt.Errorf("failed to create comment: %w", err)
	}

	return comment, nil
}

// GetStatusComments retrieves comments for a status
func (s *Service) GetStatusComments(ctx context.Context, statusID uuid.UUID, limit, offset int) ([]models.StatusComment, int, error) {
	if limit <= 0 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	comments, total, err := s.statusRepo.GetStatusComments(ctx, statusID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get comments: %w", err)
	}

	return comments, total, nil
}

// DeleteStatusComment deletes a comment
func (s *Service) DeleteStatusComment(ctx context.Context, commentID, userID uuid.UUID) error {
	if err := s.statusRepo.DeleteStatusComment(ctx, commentID, userID); err != nil {
		return fmt.Errorf("failed to delete comment: %w", err)
	}

	return nil
}

// CreateStatusMessageReply creates a record of a direct message reply to a status
func (s *Service) CreateStatusMessageReply(ctx context.Context, statusID, fromUserID, toUserID uuid.UUID) (*uuid.UUID, error) {
	// Verify status exists and is not expired
	status, err := s.statusRepo.GetStatus(ctx, statusID, fromUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to get status: %w", err)
	}

	if time.Now().After(status.ExpiresAt) {
		return nil, models.ErrStatusExpired
	}

	// Verify toUserID is the status owner
	if status.UserID != toUserID {
		return nil, fmt.Errorf("status owner mismatch")
	}

	replyID, err := s.statusRepo.CreateStatusMessageReply(ctx, statusID, fromUserID, toUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to create status message reply: %w", err)
	}

	return replyID, nil
}

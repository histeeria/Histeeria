package social

import (
	"context"
	"time"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"

	"github.com/google/uuid"
)

const (
	// Spam detection thresholds
	RapidActionsThreshold  = 10              // 10 actions in short time is suspicious
	RapidActionsWindow     = 5 * time.Minute // Within 5 minutes
	MaxStrikesBeforeReview = 3               // 3 strikes = manual review required
)

// SpamDetector handles spam detection logic
type SpamDetector struct {
	relationshipRepo repository.RelationshipRepository
}

// NewSpamDetector creates a new spam detector
func NewSpamDetector(relationshipRepo repository.RelationshipRepository) *SpamDetector {
	return &SpamDetector{
		relationshipRepo: relationshipRepo,
	}
}

// DetectRapidActions checks for suspicious rapid actions
func (s *SpamDetector) DetectRapidActions(ctx context.Context, userID uuid.UUID, actionType string) (bool, error) {
	since := time.Now().Add(-RapidActionsWindow)
	count, err := s.relationshipRepo.CountRecentActions(ctx, userID, actionType, since)
	if err != nil {
		return false, err
	}

	// If more than threshold actions in the window, it's suspicious
	return count > RapidActionsThreshold, nil
}

// ApplyCooldownPenalty increases the cooldown multiplier
func (s *SpamDetector) ApplyCooldownPenalty(ctx context.Context, userID uuid.UUID, actionType string) error {
	rateLimit, err := s.relationshipRepo.GetRateLimit(ctx, userID, actionType)
	if err != nil {
		return err
	}

	if rateLimit == nil {
		// Create new rate limit with penalty
		rateLimit = &models.RelationshipRateLimit{
			UserID:             userID,
			ActionType:         actionType,
			ActionCount:        0,
			WindowStart:        time.Now(),
			CooldownMultiplier: 2.0, // Double the cooldown
		}
	} else {
		// Increase cooldown multiplier
		rateLimit.CooldownMultiplier = 2.0 // Set to 48 hours
	}

	return s.relationshipRepo.CreateOrUpdateRateLimit(ctx, rateLimit)
}

// FlagForReview flags a user for manual review after repeated violations
func (s *SpamDetector) FlagForReview(ctx context.Context, userID uuid.UUID, detectionType string) error {
	spamFlag, err := s.relationshipRepo.GetSpamFlag(ctx, userID, detectionType)
	if err != nil {
		return err
	}

	if spamFlag == nil {
		// Create new flag
		spamFlag = &models.SpamFlag{
			UserID:         userID,
			DetectionType:  detectionType,
			FlagCount:      1,
			LastFlaggedAt:  time.Now(),
			RequiresReview: false,
		}
	} else {
		// Increment flag count
		spamFlag.FlagCount++
		spamFlag.LastFlaggedAt = time.Now()

		// Flag for review if threshold reached
		if spamFlag.FlagCount >= MaxStrikesBeforeReview {
			spamFlag.RequiresReview = true
		}
	}

	return s.relationshipRepo.CreateOrUpdateSpamFlag(ctx, spamFlag)
}

// GetUserSpamStatus gets the current spam status for a user
func (s *SpamDetector) GetUserSpamStatus(ctx context.Context, userID uuid.UUID) (*SpamStatus, error) {
	flags, err := s.relationshipRepo.GetUserSpamFlags(ctx, userID)
	if err != nil {
		return nil, err
	}

	status := &SpamStatus{
		HasFlags:       len(flags) > 0,
		RequiresReview: false,
		TotalFlags:     0,
		Flags:          flags,
	}

	for _, flag := range flags {
		status.TotalFlags += flag.FlagCount
		if flag.RequiresReview {
			status.RequiresReview = true
		}
	}

	return status, nil
}

// CheckAndHandleSpam checks for spam and applies penalties if needed
func (s *SpamDetector) CheckAndHandleSpam(ctx context.Context, userID uuid.UUID, actionType string) error {
	// Check for rapid actions
	isRapid, err := s.DetectRapidActions(ctx, userID, actionType)
	if err != nil {
		return err
	}

	if !isRapid {
		return nil
	}

	// Apply cooldown penalty
	if err := s.ApplyCooldownPenalty(ctx, userID, actionType); err != nil {
		return err
	}

	// Flag for review
	detectionType := "rapid_" + actionType
	if err := s.FlagForReview(ctx, userID, detectionType); err != nil {
		return err
	}

	// Check if now requires review
	status, err := s.GetUserSpamStatus(ctx, userID)
	if err != nil {
		return err
	}

	if status.RequiresReview {
		return &models.SpamDetectionError{
			Message:        "Your account has been flagged for suspicious activity and requires manual review. Please contact support.",
			RequiresReview: true,
			FlagCount:      status.TotalFlags,
		}
	}

	// Just a warning with increased cooldown
	return &models.SpamDetectionError{
		Message:        "Slow down! You've been detected making too many actions too quickly. Your cooldown period has been increased.",
		RequiresReview: false,
		FlagCount:      status.TotalFlags,
	}
}

// SpamStatus represents the spam status of a user
type SpamStatus struct {
	HasFlags       bool               `json:"has_flags"`
	RequiresReview bool               `json:"requires_review"`
	TotalFlags     int                `json:"total_flags"`
	Flags          []*models.SpamFlag `json:"flags"`
}

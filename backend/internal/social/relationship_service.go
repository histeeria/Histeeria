package social

import (
	"context"
	"fmt"
	"log"
	"time"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"

	"github.com/google/uuid"
)

// Rate limit configuration (per 24 hours)
const (
	// New accounts (trust level 0)
	FollowLimitNew      = 30
	ConnectLimitNew     = 20
	CollaborateLimitNew = 5

	// Verified accounts (trust level 1)
	FollowLimitVerified      = 50
	ConnectLimitVerified     = 35
	CollaborateLimitVerified = 10

	// Base cooldown period
	BaseCooldownHours = 24
)

// RelationshipService handles relationship business logic
type RelationshipService struct {
	relationshipRepo    repository.RelationshipRepository
	userRepo            repository.UserRepository
	spamDetector        *SpamDetector
	notificationService NotificationService // Interface for notifications
}

// NotificationService interface for creating notifications (avoid circular dependency)
type NotificationService interface {
	CreateFollowNotification(ctx context.Context, followerID, followedID uuid.UUID, followerUsername string) error
	CreateConnectionRequestNotification(ctx context.Context, fromID, toID uuid.UUID, fromUsername string) error
	CreateConnectionAcceptedNotification(ctx context.Context, acceptorID, requesterID uuid.UUID, acceptorUsername string) error
	CreateCollaborationRequestNotification(ctx context.Context, fromID, toID uuid.UUID, fromUsername string) error
	CreateCollaborationAcceptedNotification(ctx context.Context, acceptorID, requesterID uuid.UUID, acceptorUsername string) error
}

// NewRelationshipService creates a new relationship service
func NewRelationshipService(relationshipRepo repository.RelationshipRepository, userRepo repository.UserRepository) *RelationshipService {
	return &RelationshipService{
		relationshipRepo: relationshipRepo,
		userRepo:         userRepo,
		spamDetector:     NewSpamDetector(relationshipRepo),
	}
}

// SetNotificationService sets the notification service (called after initialization to avoid circular dependency)
func (s *RelationshipService) SetNotificationService(notificationService NotificationService) {
	s.notificationService = notificationService
}

// FollowUser creates a follow relationship
func (s *RelationshipService) FollowUser(ctx context.Context, fromUserID, toUserID uuid.UUID) (*models.RelationshipResponse, error) {
	// Check rate limit
	rateLimitStatus, err := s.checkRateLimit(ctx, fromUserID, "follow")
	if err != nil {
		if rateLimitErr, ok := err.(*models.RateLimitError); ok {
			return &models.RelationshipResponse{
				Success:   false,
				Message:   rateLimitErr.Message,
				RateLimit: rateLimitErr.RateLimit,
			}, nil
		}
		return nil, err
	}

	// Check spam patterns
	if err := s.spamDetector.CheckAndHandleSpam(ctx, fromUserID, "follow"); err != nil {
		if spamErr, ok := err.(*models.SpamDetectionError); ok {
			return &models.RelationshipResponse{
				Success: false,
				Message: spamErr.Message,
			}, nil
		}
	}

	// Get target user to check privacy settings
	targetUser, err := s.userRepo.GetUserByID(ctx, toUserID)
	if err != nil {
		return nil, fmt.Errorf("target user not found")
	}

	// Cannot follow private profiles
	if targetUser.ProfilePrivacy == "private" {
		return &models.RelationshipResponse{
			Success: false,
			Message: "Cannot follow private profiles",
		}, nil
	}

	// Check if relationship already exists
	existing, err := s.relationshipRepo.GetRelationship(ctx, fromUserID, toUserID, models.RelationshipFollowing)
	if err != nil {
		return nil, err
	}

	if existing != nil {
		return &models.RelationshipResponse{
			Success: false,
			Message: "You are already following this user",
		}, nil
	}

	// Create follow relationship (always instant, no approval needed)
	relationship := &models.UserRelationship{
		FromUserID:       fromUserID,
		ToUserID:         toUserID,
		RelationshipType: models.RelationshipFollowing,
		Status:           models.RelationshipActive,
	}

	fmt.Printf("[RelationshipService] Creating follow relationship from %s to %s\n", fromUserID, toUserID)
	if err := s.relationshipRepo.CreateRelationship(ctx, relationship); err != nil {
		fmt.Printf("[RelationshipService] CreateRelationship failed: %v\n", err)
		return nil, err
	}
	fmt.Printf("[RelationshipService] Relationship created successfully\n")

	// Record the action for rate limiting
	if err := s.recordAction(ctx, fromUserID, "follow"); err != nil {
		fmt.Printf("[RelationshipService] recordAction failed: %v\n", err)
		return nil, err
	}

	// Update follower counts
	fmt.Printf("[RelationshipService] Updating follower counts\n")
	if err := s.updateFollowerCounts(ctx, fromUserID, toUserID, true); err != nil {
		// Log error but don't fail the operation (relationship still created)
		fmt.Printf("[RelationshipService] FAILED to update follower counts: %v\n", err)
	} else {
		fmt.Printf("[RelationshipService] Follower counts updated successfully\n")
	}

	// Send follow notification
	if s.notificationService != nil {
		fromUser, err := s.userRepo.GetUserByID(ctx, fromUserID)
		if err == nil {
			_ = s.notificationService.CreateFollowNotification(ctx, fromUserID, toUserID, fromUser.Username)
		}
	}

	fmt.Printf("[RelationshipService] Follow completed successfully\n")

	return &models.RelationshipResponse{
		Success:      true,
		Message:      "Successfully followed user",
		Relationship: relationship,
		RateLimit:    rateLimitStatus,
	}, nil
}

// ConnectWithUser creates a connection (may require approval)
func (s *RelationshipService) ConnectWithUser(ctx context.Context, fromUserID, toUserID uuid.UUID, message *string) (*models.RelationshipResponse, error) {
	// Check rate limit
	rateLimitStatus, err := s.checkRateLimit(ctx, fromUserID, "connect")
	if err != nil {
		if rateLimitErr, ok := err.(*models.RateLimitError); ok {
			return &models.RelationshipResponse{
				Success:   false,
				Message:   rateLimitErr.Message,
				RateLimit: rateLimitErr.RateLimit,
			}, nil
		}
		return nil, err
	}

	// Check spam patterns
	if err := s.spamDetector.CheckAndHandleSpam(ctx, fromUserID, "connect"); err != nil {
		if spamErr, ok := err.(*models.SpamDetectionError); ok {
			return &models.RelationshipResponse{
				Success: false,
				Message: spamErr.Message,
			}, nil
		}
	}

	// Get target user to check privacy settings
	targetUser, err := s.userRepo.GetUserByID(ctx, toUserID)
	if err != nil {
		return nil, fmt.Errorf("target user not found")
	}

	// Cannot connect with private profiles
	if targetUser.ProfilePrivacy == "private" {
		return &models.RelationshipResponse{
			Success: false,
			Message: "Cannot connect with private profiles",
		}, nil
	}

	// Check if already connected
	existing, err := s.relationshipRepo.GetRelationship(ctx, fromUserID, toUserID, models.RelationshipConnected)
	if err != nil {
		return nil, err
	}

	if existing != nil && existing.Status == models.RelationshipActive {
		return &models.RelationshipResponse{
			Success: false,
			Message: "You are already connected with this user",
		}, nil
	}

	if existing != nil && existing.Status == models.RelationshipPending {
		return &models.RelationshipResponse{
			Success: false,
			Message: "Your connection request is pending",
		}, nil
	}

	// Determine status based on target user's privacy
	status := models.RelationshipActive
	responseMessage := "Successfully connected"

	if targetUser.ProfilePrivacy == "connections" {
		// Requires approval
		status = models.RelationshipPending
		responseMessage = "Connection request sent. Waiting for approval."
	}

	// Create connection
	relationship := &models.UserRelationship{
		FromUserID:       fromUserID,
		ToUserID:         toUserID,
		RelationshipType: models.RelationshipConnected,
		Status:           status,
		RequestMessage:   message,
	}

	if err := s.relationshipRepo.CreateRelationship(ctx, relationship); err != nil {
		return nil, err
	}

	// If instant connection, also create reverse connection
	if status == models.RelationshipActive {
		reverseRelationship := &models.UserRelationship{
			FromUserID:       toUserID,
			ToUserID:         fromUserID,
			RelationshipType: models.RelationshipConnected,
			Status:           models.RelationshipActive,
		}
		if err := s.relationshipRepo.CreateRelationship(ctx, reverseRelationship); err != nil {
			// Rollback
			s.relationshipRepo.DeleteRelationship(ctx, fromUserID, toUserID, models.RelationshipConnected)
			return nil, err
		}
	}

	// Record the action for rate limiting
	if err := s.recordAction(ctx, fromUserID, "connect"); err != nil {
		return nil, err
	}

	// Send connection request notification (only if pending)
	if s.notificationService != nil && status == models.RelationshipPending {
		fromUser, err := s.userRepo.GetUserByID(ctx, fromUserID)
		if err == nil {
			_ = s.notificationService.CreateConnectionRequestNotification(ctx, fromUserID, toUserID, fromUser.Username)
		}
	}

	return &models.RelationshipResponse{
		Success:      true,
		Message:      responseMessage,
		Relationship: relationship,
		RateLimit:    rateLimitStatus,
	}, nil
}

// CollaborateWithUser creates a collaboration (always requires approval)
func (s *RelationshipService) CollaborateWithUser(ctx context.Context, fromUserID, toUserID uuid.UUID, message *string) (*models.RelationshipResponse, error) {
	// Check rate limit
	rateLimitStatus, err := s.checkRateLimit(ctx, fromUserID, "collaborate")
	if err != nil {
		if rateLimitErr, ok := err.(*models.RateLimitError); ok {
			return &models.RelationshipResponse{
				Success:   false,
				Message:   rateLimitErr.Message,
				RateLimit: rateLimitErr.RateLimit,
			}, nil
		}
		return nil, err
	}

	// Check spam patterns
	if err := s.spamDetector.CheckAndHandleSpam(ctx, fromUserID, "collaborate"); err != nil {
		if spamErr, ok := err.(*models.SpamDetectionError); ok {
			return &models.RelationshipResponse{
				Success: false,
				Message: spamErr.Message,
			}, nil
		}
	}

	// Must be connected first
	connectedRel, err := s.relationshipRepo.GetRelationship(ctx, fromUserID, toUserID, models.RelationshipConnected)
	if err != nil {
		return nil, err
	}

	if connectedRel == nil || connectedRel.Status != models.RelationshipActive {
		return &models.RelationshipResponse{
			Success: false,
			Message: "You must be connected with this user before collaborating",
		}, nil
	}

	// Check if already collaborating
	existing, err := s.relationshipRepo.GetRelationship(ctx, fromUserID, toUserID, models.RelationshipCollaborating)
	if err != nil {
		return nil, err
	}

	if existing != nil && existing.Status == models.RelationshipActive {
		return &models.RelationshipResponse{
			Success: false,
			Message: "You are already collaborating with this user",
		}, nil
	}

	if existing != nil && existing.Status == models.RelationshipPending {
		return &models.RelationshipResponse{
			Success: false,
			Message: "Your collaboration request is pending",
		}, nil
	}

	// Create collaboration request (always pending)
	relationship := &models.UserRelationship{
		FromUserID:       fromUserID,
		ToUserID:         toUserID,
		RelationshipType: models.RelationshipCollaborating,
		Status:           models.RelationshipPending,
		RequestMessage:   message,
	}

	if err := s.relationshipRepo.CreateRelationship(ctx, relationship); err != nil {
		return nil, err
	}

	// Record the action for rate limiting
	if err := s.recordAction(ctx, fromUserID, "collaborate"); err != nil {
		return nil, err
	}

	// Send collaboration request notification
	if s.notificationService != nil {
		fromUser, err := s.userRepo.GetUserByID(ctx, fromUserID)
		if err == nil {
			_ = s.notificationService.CreateCollaborationRequestNotification(ctx, fromUserID, toUserID, fromUser.Username)
		}
	}

	return &models.RelationshipResponse{
		Success:      true,
		Message:      "Collaboration request sent. Waiting for approval.",
		Relationship: relationship,
		RateLimit:    rateLimitStatus,
	}, nil
}

// AcceptRelationshipRequest accepts a pending relationship request
func (s *RelationshipService) AcceptRelationshipRequest(ctx context.Context, userID uuid.UUID, requestID uuid.UUID) (*models.RelationshipResponse, error) {
	// Get the request
	relationship, err := s.relationshipRepo.GetRelationshipByID(ctx, requestID)
	if err != nil {
		return nil, err
	}

	// Verify the request is for this user
	if relationship.ToUserID != userID {
		return &models.RelationshipResponse{
			Success: false,
			Message: "Unauthorized to accept this request",
		}, nil
	}

	// Verify it's pending
	if relationship.Status != models.RelationshipPending {
		return &models.RelationshipResponse{
			Success: false,
			Message: "This request is no longer pending",
		}, nil
	}

	// Update status to active
	if err := s.relationshipRepo.UpdateRelationshipStatus(ctx, requestID, models.RelationshipActive); err != nil {
		return nil, err
	}

	// For connections and collaborations, create reverse relationship
	if relationship.RelationshipType == models.RelationshipConnected || relationship.RelationshipType == models.RelationshipCollaborating {
		reverseRelationship := &models.UserRelationship{
			FromUserID:       relationship.ToUserID,
			ToUserID:         relationship.FromUserID,
			RelationshipType: relationship.RelationshipType,
			Status:           models.RelationshipActive,
		}
		if err := s.relationshipRepo.CreateRelationship(ctx, reverseRelationship); err != nil {
			return nil, err
		}
	}

	// Send acceptance notification
	if s.notificationService != nil {
		acceptorUser, err := s.userRepo.GetUserByID(ctx, userID)
		if err == nil {
			if relationship.RelationshipType == models.RelationshipConnected {
				_ = s.notificationService.CreateConnectionAcceptedNotification(ctx, userID, relationship.FromUserID, acceptorUser.Username)
			} else if relationship.RelationshipType == models.RelationshipCollaborating {
				_ = s.notificationService.CreateCollaborationAcceptedNotification(ctx, userID, relationship.FromUserID, acceptorUser.Username)
			}
		}
	}

	return &models.RelationshipResponse{
		Success:      true,
		Message:      "Request accepted successfully",
		Relationship: relationship,
	}, nil
}

// RejectRelationshipRequest rejects a pending relationship request
func (s *RelationshipService) RejectRelationshipRequest(ctx context.Context, userID uuid.UUID, requestID uuid.UUID) (*models.RelationshipResponse, error) {
	// Get the request
	relationship, err := s.relationshipRepo.GetRelationshipByID(ctx, requestID)
	if err != nil {
		return nil, err
	}

	// Verify the request is for this user
	if relationship.ToUserID != userID {
		return &models.RelationshipResponse{
			Success: false,
			Message: "Unauthorized to reject this request",
		}, nil
	}

	// Update status to rejected
	if err := s.relationshipRepo.UpdateRelationshipStatus(ctx, requestID, models.RelationshipRejected); err != nil {
		return nil, err
	}

	return &models.RelationshipResponse{
		Success: true,
		Message: "Request rejected successfully",
	}, nil
}

// RemoveRelationship removes a relationship
func (s *RelationshipService) RemoveRelationship(ctx context.Context, fromUserID, toUserID uuid.UUID, relationshipType models.RelationshipType) (*models.RelationshipResponse, error) {
	fmt.Printf("[RelationshipService] Removing relationship: from=%s to=%s type=%s\n", fromUserID, toUserID, relationshipType)

	// Delete the relationship
	if err := s.relationshipRepo.DeleteRelationship(ctx, fromUserID, toUserID, relationshipType); err != nil {
		fmt.Printf("[RelationshipService] Delete relationship failed: %v\n", err)
		return nil, err
	}
	fmt.Printf("[RelationshipService] Relationship deleted\n")

	// For connections and collaborations, also delete reverse relationship
	if relationshipType == models.RelationshipConnected || relationshipType == models.RelationshipCollaborating {
		fmt.Printf("[RelationshipService] Deleting reverse relationship\n")
		s.relationshipRepo.DeleteRelationship(ctx, toUserID, fromUserID, relationshipType)

		// When disconnecting, also unfollow both ways
		if relationshipType == models.RelationshipConnected {
			fmt.Printf("[RelationshipService] Also removing follow relationships\n")
			s.relationshipRepo.DeleteRelationship(ctx, fromUserID, toUserID, models.RelationshipFollowing)
			s.relationshipRepo.DeleteRelationship(ctx, toUserID, fromUserID, models.RelationshipFollowing)
			// Update counts for unfollow
			if err := s.updateFollowerCounts(ctx, fromUserID, toUserID, false); err != nil {
				fmt.Printf("[RelationshipService] Failed to update follower counts: %v\n", err)
			}
		}
	}

	// Update follower counts if it was a follow
	if relationshipType == models.RelationshipFollowing {
		fmt.Printf("[RelationshipService] Updating follower counts for unfollow\n")
		if err := s.updateFollowerCounts(ctx, fromUserID, toUserID, false); err != nil {
			fmt.Printf("[RelationshipService] Failed to update follower counts: %v\n", err)
		} else {
			fmt.Printf("[RelationshipService] Follower counts updated\n")
		}
	}

	return &models.RelationshipResponse{
		Success: true,
		Message: "Relationship removed successfully",
	}, nil
}

// GetRelationshipStatus gets the relationship status between two users
func (s *RelationshipService) GetRelationshipStatus(ctx context.Context, fromUserID, toUserID uuid.UUID) (*models.RelationshipStatusResponse, error) {
	return s.relationshipRepo.GetRelationshipStatus(ctx, fromUserID, toUserID)
}

// GetRelationshipStats gets relationship stats for a user
func (s *RelationshipService) GetRelationshipStats(ctx context.Context, userID uuid.UUID) (*models.RelationshipStats, error) {
	return s.relationshipRepo.GetRelationshipStats(ctx, userID)
}

// GetRelationshipList gets a list of users based on relationship type
func (s *RelationshipService) GetRelationshipList(ctx context.Context, userID uuid.UUID, listType string, page int, limit int) ([]map[string]interface{}, int, error) {
	log.Printf("[RelationshipService] Getting %s list for user %s (page: %d, limit: %d)", listType, userID, page, limit)

	// Get the list from repository
	items, total, err := s.relationshipRepo.GetRelationshipList(ctx, userID, listType, page, limit)
	if err != nil {
		log.Printf("[RelationshipService] Failed to get %s list: %v", listType, err)
		return nil, 0, err
	}

	// Convert to response format with user details
	users := make([]map[string]interface{}, 0, len(items))
	for _, item := range items {
		user, err := s.userRepo.GetUserByID(ctx, item.UserID)
		if err != nil {
			log.Printf("[RelationshipService] Failed to get user %s: %v", item.UserID, err)
			continue
		}

		userMap := map[string]interface{}{
			"id":              user.ID.String(),
			"username":        user.Username,
			"display_name":    user.DisplayName,
			"profile_picture": user.ProfilePicture,
			"is_verified":     user.IsVerified,
			"bio":             user.Bio,
			"followers_count": user.FollowersCount,
		}

		users = append(users, userMap)
	}

	log.Printf("[RelationshipService] Returning %d users (total: %d)", len(users), total)
	return users, total, nil
}

// GetRateLimitInfo gets the current rate limit status
func (s *RelationshipService) GetRateLimitInfo(ctx context.Context, userID uuid.UUID, actionType string) (*models.RateLimitStatus, error) {
	rateLimit, err := s.relationshipRepo.GetRateLimit(ctx, userID, actionType)
	if err != nil {
		return nil, err
	}

	// Get user trust level
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	trustLevel := user.IsVerified || user.IsEmailVerified
	limit := s.getLimitForAction(actionType, trustLevel)

	if rateLimit == nil {
		// No rate limit record yet
		return &models.RateLimitStatus{
			Action:             actionType,
			Limit:              limit,
			Used:               0,
			Remaining:          limit,
			ResetsAt:           time.Now().Add(BaseCooldownHours * time.Hour),
			CooldownMultiplier: 1.0,
		}, nil
	}

	// Check if window has expired
	cooldownDuration := time.Duration(BaseCooldownHours*rateLimit.CooldownMultiplier) * time.Hour
	if time.Since(rateLimit.WindowStart) > cooldownDuration {
		// Window expired, reset
		return &models.RateLimitStatus{
			Action:             actionType,
			Limit:              limit,
			Used:               0,
			Remaining:          limit,
			ResetsAt:           time.Now().Add(time.Duration(BaseCooldownHours*rateLimit.CooldownMultiplier) * time.Hour),
			CooldownMultiplier: rateLimit.CooldownMultiplier,
		}, nil
	}

	remaining := limit - rateLimit.ActionCount
	if remaining < 0 {
		remaining = 0
	}

	return &models.RateLimitStatus{
		Action:             actionType,
		Limit:              limit,
		Used:               rateLimit.ActionCount,
		Remaining:          remaining,
		ResetsAt:           rateLimit.WindowStart.Add(time.Duration(BaseCooldownHours*rateLimit.CooldownMultiplier) * time.Hour),
		CooldownMultiplier: rateLimit.CooldownMultiplier,
	}, nil
}

// checkRateLimit checks if the user is within rate limits
func (s *RelationshipService) checkRateLimit(ctx context.Context, userID uuid.UUID, actionType string) (*models.RateLimitStatus, error) {
	status, err := s.GetRateLimitInfo(ctx, userID, actionType)
	if err != nil {
		return nil, err
	}

	if status.Remaining <= 0 {
		timeUntilReset := time.Until(status.ResetsAt)
		hours := int(timeUntilReset.Hours())
		minutes := int(timeUntilReset.Minutes()) % 60

		message := fmt.Sprintf("You've reached your %s limit for today. Try again in %d hours and %d minutes.", actionType, hours, minutes)

		return nil, &models.RateLimitError{
			Message:   message,
			RateLimit: status,
		}
	}

	return status, nil
}

// recordAction records an action for rate limiting
func (s *RelationshipService) recordAction(ctx context.Context, userID uuid.UUID, actionType string) error {
	rateLimit, err := s.relationshipRepo.GetRateLimit(ctx, userID, actionType)
	if err != nil {
		return err
	}

	if rateLimit == nil {
		// Create new record
		rateLimit = &models.RelationshipRateLimit{
			UserID:             userID,
			ActionType:         actionType,
			ActionCount:        1,
			WindowStart:        time.Now(),
			CooldownMultiplier: 1.0,
		}
	} else {
		// Check if window expired
		cooldownDuration := time.Duration(BaseCooldownHours*rateLimit.CooldownMultiplier) * time.Hour
		if time.Since(rateLimit.WindowStart) > cooldownDuration {
			// Reset window
			rateLimit.ActionCount = 1
			rateLimit.WindowStart = time.Now()
			rateLimit.CooldownMultiplier = 1.0 // Reset multiplier
		} else {
			// Increment count
			rateLimit.ActionCount++
		}
	}

	return s.relationshipRepo.CreateOrUpdateRateLimit(ctx, rateLimit)
}

// getLimitForAction gets the limit for an action based on trust level
func (s *RelationshipService) getLimitForAction(actionType string, isVerified bool) int {
	switch actionType {
	case "follow":
		if isVerified {
			return FollowLimitVerified
		}
		return FollowLimitNew
	case "connect":
		if isVerified {
			return ConnectLimitVerified
		}
		return ConnectLimitNew
	case "collaborate":
		if isVerified {
			return CollaborateLimitVerified
		}
		return CollaborateLimitNew
	default:
		return 0
	}
}

// updateFollowerCounts updates the denormalized follower counts
func (s *RelationshipService) updateFollowerCounts(ctx context.Context, followerID, followedID uuid.UUID, isFollow bool) error {
	fmt.Printf("[updateFollowerCounts] followerID=%s followedID=%s isFollow=%v\n", followerID, followedID, isFollow)

	if isFollow {
		// Increment followed user's followers_count
		fmt.Printf("[updateFollowerCounts] Incrementing followers_count for user %s\n", followedID)
		if err := s.userRepo.IncrementFollowerCount(ctx, followedID); err != nil {
			fmt.Printf("[updateFollowerCounts] IncrementFollowerCount FAILED: %v\n", err)
			return err
		}
		fmt.Printf("[updateFollowerCounts] Followers count incremented successfully\n")

		// Increment follower's following_count
		fmt.Printf("[updateFollowerCounts] Incrementing following_count for user %s\n", followerID)
		if err := s.userRepo.IncrementFollowingCount(ctx, followerID); err != nil {
			fmt.Printf("[updateFollowerCounts] IncrementFollowingCount FAILED: %v\n", err)
			return err
		}
		fmt.Printf("[updateFollowerCounts] Following count incremented successfully\n")
	} else {
		// Decrement followed user's followers_count
		fmt.Printf("[updateFollowerCounts] Decrementing followers_count for user %s\n", followedID)
		if err := s.userRepo.DecrementFollowerCount(ctx, followedID); err != nil {
			fmt.Printf("[updateFollowerCounts] DecrementFollowerCount FAILED: %v\n", err)
			return err
		}

		// Decrement follower's following_count
		fmt.Printf("[updateFollowerCounts] Decrementing following_count for user %s\n", followerID)
		if err := s.userRepo.DecrementFollowingCount(ctx, followerID); err != nil {
			fmt.Printf("[updateFollowerCounts] DecrementFollowingCount FAILED: %v\n", err)
			return err
		}
	}

	fmt.Printf("[updateFollowerCounts] All counts updated successfully\n")
	return nil
}

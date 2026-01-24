package models

import (
	"time"

	"github.com/google/uuid"
)

// RelationshipType represents the type of relationship between users
type RelationshipType string

const (
	RelationshipFollowing     RelationshipType = "following"
	RelationshipConnected     RelationshipType = "connected"
	RelationshipCollaborating RelationshipType = "collaborating"
)

// RelationshipStatus represents the status of a relationship
type RelationshipStatus string

const (
	RelationshipActive   RelationshipStatus = "active"
	RelationshipPending  RelationshipStatus = "pending"
	RelationshipRejected RelationshipStatus = "rejected"
	RelationshipBlocked  RelationshipStatus = "blocked"
)

// UserRelationship represents a relationship between two users
type UserRelationship struct {
	ID               uuid.UUID          `json:"id" db:"id"`
	FromUserID       uuid.UUID          `json:"from_user_id" db:"from_user_id"`
	ToUserID         uuid.UUID          `json:"to_user_id" db:"to_user_id"`
	RelationshipType RelationshipType   `json:"relationship_type" db:"relationship_type"`
	Status           RelationshipStatus `json:"status" db:"status"`
	RequestMessage   *string            `json:"request_message,omitempty" db:"request_message"`
	CreatedAt        time.Time          `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time          `json:"updated_at" db:"updated_at"`
	AcceptedAt       *time.Time         `json:"accepted_at,omitempty" db:"accepted_at"`
}

// CreateRelationshipRequest represents the request to create a relationship
type CreateRelationshipRequest struct {
	TargetUserID     string  `json:"target_user_id" validate:"required,uuid"`
	RelationshipType string  `json:"relationship_type" validate:"required,oneof=following connected collaborating"`
	Message          *string `json:"message,omitempty" validate:"omitempty,min=10,max=200"`
}

// UpdateRelationshipStatusRequest represents the request to update relationship status
type UpdateRelationshipStatusRequest struct {
	Status string `json:"status" validate:"required,oneof=active rejected blocked"`
}

// RelationshipStats represents counts of different relationship types
type RelationshipStats struct {
	FollowersCount     int `json:"followers_count"`
	FollowingCount     int `json:"following_count"`
	ConnectionsCount   int `json:"connections_count"`
	CollaboratorsCount int `json:"collaborators_count"`
}

// RelationshipStatus represents the relationship status between two users
type RelationshipStatusResponse struct {
	IsFollowing     bool `json:"is_following"`
	IsFollower      bool `json:"is_follower"`
	IsConnected     bool `json:"is_connected"`
	IsCollaborating bool `json:"is_collaborating"`
	HasPending      bool `json:"has_pending"`
	IsBlocked       bool `json:"is_blocked"`
}

// RateLimitStatus represents the current rate limit status for a user
type RateLimitStatus struct {
	Action             string    `json:"action"`
	Limit              int       `json:"limit"`
	Used               int       `json:"used"`
	Remaining          int       `json:"remaining"`
	ResetsAt           time.Time `json:"resets_at"`
	CooldownMultiplier float64   `json:"cooldown_multiplier"`
}

// RelationshipRateLimit represents rate limiting data
type RelationshipRateLimit struct {
	ID                 uuid.UUID `json:"id" db:"id"`
	UserID             uuid.UUID `json:"user_id" db:"user_id"`
	ActionType         string    `json:"action_type" db:"action_type"`
	ActionCount        int       `json:"action_count" db:"action_count"`
	WindowStart        time.Time `json:"window_start" db:"window_start"`
	CooldownMultiplier float64   `json:"cooldown_multiplier" db:"cooldown_multiplier"`
	CreatedAt          time.Time `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time `json:"updated_at" db:"updated_at"`
}

// SpamFlag represents a spam detection flag
type SpamFlag struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	UserID         uuid.UUID  `json:"user_id" db:"user_id"`
	DetectionType  string     `json:"detection_type" db:"detection_type"`
	FlagCount      int        `json:"flag_count" db:"flag_count"`
	LastFlaggedAt  time.Time  `json:"last_flagged_at" db:"last_flagged_at"`
	RequiresReview bool       `json:"requires_review" db:"requires_review"`
	ReviewedAt     *time.Time `json:"reviewed_at,omitempty" db:"reviewed_at"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
}

// RelationshipListItem represents a user in a relationships list
type RelationshipListItem struct {
	UserID           uuid.UUID          `json:"user_id"`
	Username         string             `json:"username"`
	DisplayName      string             `json:"display_name"`
	ProfilePicture   *string            `json:"profile_picture"`
	Bio              *string            `json:"bio"`
	IsVerified       bool               `json:"is_verified"`
	RelationshipType RelationshipType   `json:"relationship_type"`
	Status           RelationshipStatus `json:"status"`
	CreatedAt        time.Time          `json:"created_at"`
}

// RelationshipRequest represents a pending relationship request
type RelationshipRequest struct {
	ID               uuid.UUID        `json:"id"`
	FromUser         *User            `json:"from_user"`
	ToUser           *User            `json:"to_user"`
	RelationshipType RelationshipType `json:"relationship_type"`
	RequestMessage   *string          `json:"request_message,omitempty"`
	CreatedAt        time.Time        `json:"created_at"`
}

// RelationshipResponse represents a successful relationship action response
type RelationshipResponse struct {
	Success      bool                        `json:"success"`
	Message      string                      `json:"message"`
	Relationship *UserRelationship           `json:"relationship,omitempty"`
	RateLimit    *RateLimitStatus            `json:"rate_limit,omitempty"`
	Status       *RelationshipStatusResponse `json:"status,omitempty"`
}

// RelationshipListResponse represents a list of relationships
type RelationshipListResponse struct {
	Success       bool                    `json:"success"`
	Relationships []*RelationshipListItem `json:"relationships"`
	Total         int                     `json:"total"`
	Page          int                     `json:"page"`
	Limit         int                     `json:"limit"`
}

// RelationshipStatsResponse represents relationship stats response
type RelationshipStatsResponse struct {
	Success bool               `json:"success"`
	Stats   *RelationshipStats `json:"stats"`
}

// RateLimitError represents a rate limit error with details
type RateLimitError struct {
	Message   string           `json:"message"`
	RateLimit *RateLimitStatus `json:"rate_limit"`
}

func (e *RateLimitError) Error() string {
	return e.Message
}

// SpamDetectionError represents a spam detection error
type SpamDetectionError struct {
	Message        string `json:"message"`
	RequiresReview bool   `json:"requires_review"`
	FlagCount      int    `json:"flag_count"`
}

func (e *SpamDetectionError) Error() string {
	return e.Message
}

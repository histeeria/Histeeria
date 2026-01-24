package repository

import (
	"context"
	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// PollRepository defines the interface for poll data access
type PollRepository interface {
	// Poll operations
	CreatePoll(ctx context.Context, poll *models.Poll, options []string) error
	GetPoll(ctx context.Context, pollID uuid.UUID) (*models.Poll, error)
	GetPollByPostID(ctx context.Context, postID uuid.UUID) (*models.Poll, error)
	ClosePoll(ctx context.Context, pollID uuid.UUID) error

	// Voting
	VotePoll(ctx context.Context, pollID, optionID, userID uuid.UUID) error
	ChangeVote(ctx context.Context, pollID, newOptionID, userID uuid.UUID) error
	GetUserVote(ctx context.Context, pollID, userID uuid.UUID) (*uuid.UUID, error)
	HasUserVoted(ctx context.Context, pollID, userID uuid.UUID) (bool, error)

	// Results
	GetPollResults(ctx context.Context, pollID, viewerID uuid.UUID) (*models.PollResults, error)
	GetPollOptions(ctx context.Context, pollID uuid.UUID) ([]models.PollOption, error)
}

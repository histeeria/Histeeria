package models

import (
	"time"

	"github.com/google/uuid"
)

// Poll represents an interactive poll
type Poll struct {
	ID                    uuid.UUID    `json:"id"`
	PostID                uuid.UUID    `json:"post_id"`
	Question              string       `json:"question"`
	DurationHours         int          `json:"duration_hours"`
	AllowMultipleVotes    bool         `json:"allow_multiple_votes"`
	ShowResultsBeforeVote bool         `json:"show_results_before_vote"`
	AllowVoteChanges      bool         `json:"allow_vote_changes"`
	AnonymousVotes        bool         `json:"anonymous_votes"`
	IsClosed              bool         `json:"is_closed"`
	ClosedAt              *time.Time   `json:"closed_at,omitempty"`
	EndsAt                time.Time    `json:"ends_at"`
	TotalVotes            int          `json:"total_votes"`
	CreatedAt             time.Time    `json:"created_at"`
	Options               []PollOption `json:"options,omitempty"`
	UserVote              *uuid.UUID   `json:"user_vote,omitempty"` // Option ID user voted for
}

// PollOption represents a poll choice
type PollOption struct {
	ID          uuid.UUID `json:"id"`
	PollID      uuid.UUID `json:"poll_id"`
	OptionText  string    `json:"option_text"`
	OptionIndex int       `json:"option_index"`
	VotesCount  int       `json:"votes_count"`
}

// PollVote represents a user's vote
type PollVote struct {
	ID       uuid.UUID `json:"id"`
	PollID   uuid.UUID `json:"poll_id"`
	OptionID uuid.UUID `json:"option_id"`
	UserID   uuid.UUID `json:"user_id"`
	VotedAt  time.Time `json:"voted_at"`
}

// CreatePollRequest is the request body for creating a poll
type CreatePollRequest struct {
	Question              string   `json:"question" binding:"required,max=280"`
	Options               []string `json:"options" binding:"required,min=2,max=4"`
	DurationHours         int      `json:"duration_hours" binding:"required,min=1,max=168"` // 1 hour to 1 week
	AllowMultipleVotes    bool     `json:"allow_multiple_votes"`
	ShowResultsBeforeVote bool     `json:"show_results_before_vote"`
	AllowVoteChanges      bool     `json:"allow_vote_changes"`
	AnonymousVotes        bool     `json:"anonymous_votes"`
}

// VotePollRequest is the request body for voting on a poll
type VotePollRequest struct {
	OptionID uuid.UUID `json:"option_id" binding:"required"`
}

// PollResults represents the results of a poll
type PollResults struct {
	Poll       *Poll              `json:"poll"`
	Options    []PollOptionResult `json:"options"`
	TotalVotes int                `json:"total_votes"`
	UserVoted  bool               `json:"user_voted"`
	UserVoteID *uuid.UUID         `json:"user_vote_id,omitempty"`
	TimeLeft   *time.Duration     `json:"time_left,omitempty"`
	IsEnded    bool               `json:"is_ended"`
}

// PollOptionResult represents poll option with percentage
type PollOptionResult struct {
	ID          uuid.UUID `json:"id"`
	OptionText  string    `json:"option_text"`
	OptionIndex int       `json:"option_index"`
	VotesCount  int       `json:"votes_count"`
	Percentage  float64   `json:"percentage"`
	IsUserVote  bool      `json:"is_user_vote"`
}

// Validate validates the poll creation request
func (r *CreatePollRequest) Validate() error {
	if len(r.Options) < 2 || len(r.Options) > 4 {
		return &AppError{Code: "INVALID_OPTIONS_COUNT", Message: "Polls must have 2-4 options"}
	}

	for _, option := range r.Options {
		if len(option) == 0 {
			return &AppError{Code: "EMPTY_OPTION", Message: "Poll options cannot be empty"}
		}
		if len(option) > 100 {
			return &AppError{Code: "OPTION_TOO_LONG", Message: "Poll options must be 100 characters or less"}
		}
	}

	if r.DurationHours < 1 || r.DurationHours > 168 {
		return &AppError{Code: "INVALID_DURATION", Message: "Poll duration must be between 1 hour and 1 week"}
	}

	return nil
}

// IsActive checks if poll is still active
func (p *Poll) IsActive() bool {
	return !p.IsClosed && time.Now().Before(p.EndsAt)
}

// TimeRemaining returns time left for voting
func (p *Poll) TimeRemaining() time.Duration {
	if !p.IsActive() {
		return 0
	}
	return time.Until(p.EndsAt)
}

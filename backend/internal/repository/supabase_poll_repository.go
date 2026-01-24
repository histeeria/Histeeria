package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// SupabasePollRepository implements PollRepository using Supabase
type SupabasePollRepository struct {
	*SupabasePostRepository
}

// NewSupabasePollRepository creates a new poll repository
func NewSupabasePollRepository(supabaseURL, serviceKey string) *SupabasePollRepository {
	return &SupabasePollRepository{
		SupabasePostRepository: NewSupabasePostRepository(supabaseURL, serviceKey),
	}
}

// CreatePoll creates a new poll with options
func (r *SupabasePollRepository) CreatePoll(ctx context.Context, poll *models.Poll, options []string) error {
	if poll.ID == uuid.Nil {
		poll.ID = uuid.New()
	}

	// Calculate end time
	poll.EndsAt = time.Now().Add(time.Duration(poll.DurationHours) * time.Hour)

	// Create poll
	payload := map[string]interface{}{
		"id":                       poll.ID,
		"post_id":                  poll.PostID,
		"question":                 poll.Question,
		"duration_hours":           poll.DurationHours,
		"allow_multiple_votes":     poll.AllowMultipleVotes,
		"show_results_before_vote": poll.ShowResultsBeforeVote,
		"allow_vote_changes":       poll.AllowVoteChanges,
		"anonymous_votes":          poll.AnonymousVotes,
		"ends_at":                  poll.EndsAt,
	}

	_, err := r.makeRequest("POST", "polls", "", payload)
	if err != nil {
		return fmt.Errorf("failed to create poll: %w", err)
	}

	// Create poll options
	for i, optionText := range options {
		optionPayload := map[string]interface{}{
			"poll_id":      poll.ID,
			"option_text":  optionText,
			"option_index": i,
		}

		if _, err := r.makeRequest("POST", "poll_options", "", optionPayload); err != nil {
			return fmt.Errorf("failed to create poll option: %w", err)
		}
	}

	return nil
}

// GetPoll retrieves a poll by ID
func (r *SupabasePollRepository) GetPoll(ctx context.Context, pollID uuid.UUID) (*models.Poll, error) {
	query := fmt.Sprintf("?id=eq.%s&select=*", pollID.String())

	data, err := r.makeRequest("GET", "polls", query, nil)
	if err != nil {
		return nil, err
	}

	// Parse as map first to handle timestamps
	var pollsData []map[string]interface{}
	if err := json.Unmarshal(data, &pollsData); err != nil {
		return nil, err
	}

	if len(pollsData) == 0 {
		return nil, fmt.Errorf("poll not found")
	}

	// Use the same parsing logic as GetPollByPostID
	pollData := pollsData[0]
	
	// Parse timestamps
	parseTime := func(val interface{}) *time.Time {
		if val == nil {
			return nil
		}
		str, ok := val.(string)
		if !ok {
			return nil
		}
		
		if t, err := time.Parse(time.RFC3339, str); err == nil {
			return &t
		}
		if t, err := time.Parse(time.RFC3339Nano, str); err == nil {
			return &t
		}
		
		utc, _ := time.LoadLocation("UTC")
		if !strings.Contains(str, "Z") && !strings.Contains(str, "+") && len(str) > 10 {
			parts := strings.Split(str, ".")
			if len(parts) == 2 {
				fractional := parts[1]
				if len(fractional) > 6 {
					fractional = fractional[:6]
				} else if len(fractional) < 6 {
					fractional = fractional + strings.Repeat("0", 6-len(fractional))
				}
				normalized := parts[0] + "." + fractional
				if t, err := time.ParseInLocation("2006-01-02T15:04:05.999999", normalized, utc); err == nil {
					return &t
				}
			} else {
				if t, err := time.ParseInLocation("2006-01-02T15:04:05", str, utc); err == nil {
					return &t
				}
			}
		}
		
		return nil
	}

	parseRequiredTime := func(val interface{}) time.Time {
		if t := parseTime(val); t != nil {
			return *t
		}
		return time.Now()
	}

	// Create poll from parsed data
	poll := &models.Poll{}
	
	// Parse IDs
	if id, ok := pollData["id"].(string); ok {
		if uuid, err := uuid.Parse(id); err == nil {
			poll.ID = uuid
		}
	}
	if postIDVal, ok := pollData["post_id"].(string); ok {
		if uuid, err := uuid.Parse(postIDVal); err == nil {
			poll.PostID = uuid
		}
	}
	
	// Parse strings
	if question, ok := pollData["question"].(string); ok {
		poll.Question = question
	}
	
	// Parse integers
	if durationHours, ok := pollData["duration_hours"].(float64); ok {
		poll.DurationHours = int(durationHours)
	}
	if totalVotes, ok := pollData["total_votes"].(float64); ok {
		poll.TotalVotes = int(totalVotes)
	}
	
	// Parse booleans
	if allowMultiple, ok := pollData["allow_multiple_votes"].(bool); ok {
		poll.AllowMultipleVotes = allowMultiple
	}
	if showResults, ok := pollData["show_results_before_vote"].(bool); ok {
		poll.ShowResultsBeforeVote = showResults
	}
	if allowChanges, ok := pollData["allow_vote_changes"].(bool); ok {
		poll.AllowVoteChanges = allowChanges
	}
	if anonymous, ok := pollData["anonymous_votes"].(bool); ok {
		poll.AnonymousVotes = anonymous
	}
	if isClosed, ok := pollData["is_closed"].(bool); ok {
		poll.IsClosed = isClosed
	}
	
	// Parse timestamps
	poll.CreatedAt = parseRequiredTime(pollData["created_at"])
	poll.EndsAt = parseRequiredTime(pollData["ends_at"])
	poll.ClosedAt = parseTime(pollData["closed_at"])

	// Load options
	options, _ := r.GetPollOptions(ctx, pollID)
	poll.Options = options

	return poll, nil
}

// GetPollByPostID retrieves a poll by post ID
func (r *SupabasePollRepository) GetPollByPostID(ctx context.Context, postID uuid.UUID) (*models.Poll, error) {
	query := fmt.Sprintf("?post_id=eq.%s&select=*", postID.String())
	fmt.Printf("[DEBUG] GetPollByPostID: querying for post_id=%s\n", postID.String())

	data, err := r.makeRequest("GET", "polls", query, nil)
	if err != nil {
		fmt.Printf("[DEBUG] GetPollByPostID: request failed: %v\n", err)
		return nil, fmt.Errorf("failed to fetch poll: %w", err)
	}

	responsePreview := string(data)
	if len(responsePreview) > 500 {
		responsePreview = responsePreview[:500] + "..."
	}
	fmt.Printf("[DEBUG] GetPollByPostID: received response: %s\n", responsePreview)

	// Parse as map first to handle timestamps
	var pollsData []map[string]interface{}
	if err := json.Unmarshal(data, &pollsData); err != nil {
		fmt.Printf("[DEBUG] GetPollByPostID: failed to unmarshal as map: %v\n", err)
		return nil, fmt.Errorf("failed to parse poll data: %w", err)
	}

	if len(pollsData) == 0 {
		fmt.Printf("[DEBUG] GetPollByPostID: no polls found for post_id=%s\n", postID.String())
		return nil, fmt.Errorf("poll not found for post %s", postID.String())
	}

	// Use the same parsing logic as batchLoadPolls
	pollData := pollsData[0]
	
	// Parse timestamps
	parseTime := func(val interface{}) *time.Time {
		if val == nil {
			return nil
		}
		str, ok := val.(string)
		if !ok {
			return nil
		}
		
		if t, err := time.Parse(time.RFC3339, str); err == nil {
			return &t
		}
		if t, err := time.Parse(time.RFC3339Nano, str); err == nil {
			return &t
		}
		
		utc, _ := time.LoadLocation("UTC")
		if !strings.Contains(str, "Z") && !strings.Contains(str, "+") && len(str) > 10 {
			parts := strings.Split(str, ".")
			if len(parts) == 2 {
				fractional := parts[1]
				if len(fractional) > 6 {
					fractional = fractional[:6]
				} else if len(fractional) < 6 {
					fractional = fractional + strings.Repeat("0", 6-len(fractional))
				}
				normalized := parts[0] + "." + fractional
				if t, err := time.ParseInLocation("2006-01-02T15:04:05.999999", normalized, utc); err == nil {
					return &t
				}
			} else {
				if t, err := time.ParseInLocation("2006-01-02T15:04:05", str, utc); err == nil {
					return &t
				}
			}
		}
		
		return nil
	}

	parseRequiredTime := func(val interface{}) time.Time {
		if t := parseTime(val); t != nil {
			return *t
		}
		return time.Now()
	}

	// Create poll from parsed data
	poll := &models.Poll{}
	
	// Parse IDs
	if id, ok := pollData["id"].(string); ok {
		if uuid, err := uuid.Parse(id); err == nil {
			poll.ID = uuid
		}
	}
	if postIDVal, ok := pollData["post_id"].(string); ok {
		if uuid, err := uuid.Parse(postIDVal); err == nil {
			poll.PostID = uuid
		}
	}
	
	// Parse strings
	if question, ok := pollData["question"].(string); ok {
		poll.Question = question
	}
	
	// Parse integers
	if durationHours, ok := pollData["duration_hours"].(float64); ok {
		poll.DurationHours = int(durationHours)
	}
	if totalVotes, ok := pollData["total_votes"].(float64); ok {
		poll.TotalVotes = int(totalVotes)
	}
	
	// Parse booleans
	if allowMultiple, ok := pollData["allow_multiple_votes"].(bool); ok {
		poll.AllowMultipleVotes = allowMultiple
	}
	if showResults, ok := pollData["show_results_before_vote"].(bool); ok {
		poll.ShowResultsBeforeVote = showResults
	}
	if allowChanges, ok := pollData["allow_vote_changes"].(bool); ok {
		poll.AllowVoteChanges = allowChanges
	}
	if anonymous, ok := pollData["anonymous_votes"].(bool); ok {
		poll.AnonymousVotes = anonymous
	}
	if isClosed, ok := pollData["is_closed"].(bool); ok {
		poll.IsClosed = isClosed
	}
	
	// Parse timestamps
	poll.CreatedAt = parseRequiredTime(pollData["created_at"])
	poll.EndsAt = parseRequiredTime(pollData["ends_at"])
	poll.ClosedAt = parseTime(pollData["closed_at"])

	// Load options
	options, _ := r.GetPollOptions(ctx, poll.ID)
	poll.Options = options

	fmt.Printf("[DEBUG] GetPollByPostID: successfully loaded poll %s for post %s\n", poll.ID.String(), postID.String())
	return poll, nil
}

// ClosePoll closes a poll (no more voting)
func (r *SupabasePollRepository) ClosePoll(ctx context.Context, pollID uuid.UUID) error {
	updates := map[string]interface{}{
		"is_closed": true,
		"closed_at": time.Now(),
	}

	query := fmt.Sprintf("?id=eq.%s", pollID.String())
	_, err := r.makeRequest("PATCH", "polls", query, updates)

	return err
}

// VotePoll records a vote for a poll option
func (r *SupabasePollRepository) VotePoll(ctx context.Context, pollID, optionID, userID uuid.UUID) error {
	// Check if poll allows voting
	poll, err := r.GetPoll(ctx, pollID)
	if err != nil {
		return err
	}

	if poll.IsClosed || time.Now().After(poll.EndsAt) {
		return fmt.Errorf("poll is closed")
	}

	// Check if user already voted
	hasVoted, _ := r.HasUserVoted(ctx, pollID, userID)
	if hasVoted {
		if !poll.AllowVoteChanges {
			return fmt.Errorf("vote changes not allowed")
		}
		// User has voted and changes are allowed - update the vote
		return r.ChangeVote(ctx, pollID, optionID, userID)
	}

	payload := map[string]interface{}{
		"poll_id":   pollID,
		"option_id": optionID,
		"user_id":   userID,
	}

	fmt.Printf("[DEBUG] Creating vote: poll_id=%s, option_id=%s, user_id=%s\n", pollID.String(), optionID.String(), userID.String())
	
	_, err = r.makeRequest("POST", "poll_votes", "", payload)
	if err != nil {
		if strings.Contains(err.Error(), "duplicate") || strings.Contains(err.Error(), "unique") {
			// Already voted - try to update instead
			fmt.Printf("[DEBUG] Duplicate vote detected, attempting to update\n")
			return r.ChangeVote(ctx, pollID, optionID, userID)
		}
		fmt.Printf("[DEBUG] ERROR: Failed to create vote: %v\n", err)
		return fmt.Errorf("failed to vote: %w", err)
	}

	fmt.Printf("[DEBUG] Vote created successfully\n")
	return nil
}

// ChangeVote changes a user's vote
func (r *SupabasePollRepository) ChangeVote(ctx context.Context, pollID, newOptionID, userID uuid.UUID) error {
	fmt.Printf("[DEBUG] Changing vote: poll_id=%s, new_option_id=%s, user_id=%s\n", pollID.String(), newOptionID.String(), userID.String())
	
	// Get existing vote to update it
	existingVote, err := r.GetUserVote(ctx, pollID, userID)
	if err != nil {
		return fmt.Errorf("failed to get existing vote: %w", err)
	}
	
	if existingVote == nil {
		// No existing vote, just create new one
		payload := map[string]interface{}{
			"poll_id":   pollID,
			"option_id": newOptionID,
			"user_id":   userID,
		}
		_, err = r.makeRequest("POST", "poll_votes", "", payload)
		return err
	}
	
	// Update existing vote
	updateQuery := fmt.Sprintf("?poll_id=eq.%s&user_id=eq.%s", pollID.String(), userID.String())
	payload := map[string]interface{}{
		"option_id": newOptionID,
	}
	
	_, err = r.makeRequest("PATCH", "poll_votes", updateQuery, payload)
	if err != nil {
		fmt.Printf("[DEBUG] ERROR: Failed to update vote: %v\n", err)
		return fmt.Errorf("failed to update vote: %w", err)
	}
	
	fmt.Printf("[DEBUG] Vote updated successfully\n")
	return nil
}

// GetUserVote retrieves the option ID a user voted for
func (r *SupabasePollRepository) GetUserVote(ctx context.Context, pollID, userID uuid.UUID) (*uuid.UUID, error) {
	query := fmt.Sprintf("?poll_id=eq.%s&user_id=eq.%s&select=option_id", pollID.String(), userID.String())

	data, err := r.makeRequest("GET", "poll_votes", query, nil)
	if err != nil {
		return nil, err
	}

	var votes []struct {
		OptionID uuid.UUID `json:"option_id"`
	}
	if err := json.Unmarshal(data, &votes); err != nil {
		return nil, err
	}

	if len(votes) == 0 {
		return nil, nil
	}

	return &votes[0].OptionID, nil
}

// HasUserVoted checks if a user has voted on a poll
func (r *SupabasePollRepository) HasUserVoted(ctx context.Context, pollID, userID uuid.UUID) (bool, error) {
	voteID, err := r.GetUserVote(ctx, pollID, userID)
	if err != nil {
		return false, err
	}
	return voteID != nil, nil
}

// GetPollResults retrieves poll results with percentages
func (r *SupabasePollRepository) GetPollResults(ctx context.Context, pollID, viewerID uuid.UUID) (*models.PollResults, error) {
	poll, err := r.GetPoll(ctx, pollID)
	if err != nil {
		return nil, err
	}

	// Check if user voted
	userVoteID, _ := r.GetUserVote(ctx, pollID, viewerID)
	hasVoted := userVoteID != nil

	// Build results
	results := &models.PollResults{
		Poll:       poll,
		Options:    make([]models.PollOptionResult, len(poll.Options)),
		TotalVotes: poll.TotalVotes,
		UserVoted:  hasVoted,
		UserVoteID: userVoteID,
		IsEnded:    poll.IsClosed || time.Now().After(poll.EndsAt),
	}

	// Calculate time left
	if !results.IsEnded {
		timeLeft := time.Until(poll.EndsAt)
		results.TimeLeft = &timeLeft
	}

	// Calculate percentages
	for i, option := range poll.Options {
		percentage := 0.0
		if poll.TotalVotes > 0 {
			percentage = (float64(option.VotesCount) / float64(poll.TotalVotes)) * 100
		}

		results.Options[i] = models.PollOptionResult{
			ID:          option.ID,
			OptionText:  option.OptionText,
			OptionIndex: option.OptionIndex,
			VotesCount:  option.VotesCount,
			Percentage:  percentage,
			IsUserVote:  userVoteID != nil && *userVoteID == option.ID,
		}
	}

	return results, nil
}

// GetPollOptions retrieves all options for a poll
func (r *SupabasePollRepository) GetPollOptions(ctx context.Context, pollID uuid.UUID) ([]models.PollOption, error) {
	query := fmt.Sprintf("?poll_id=eq.%s&select=*&order=option_index.asc", pollID.String())

	data, err := r.makeRequest("GET", "poll_options", query, nil)
	if err != nil {
		return nil, err
	}

	var options []models.PollOption
	if err := json.Unmarshal(data, &options); err != nil {
		return nil, err
	}

	return options, nil
}

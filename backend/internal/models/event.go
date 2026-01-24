package models

import (
	"encoding/json"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// FlexibleTime is a time.Time that can unmarshal from various date formats
type FlexibleTime struct {
	time.Time
}

// UnmarshalJSON implements json.Unmarshaler for FlexibleTime
func (ft *FlexibleTime) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return err
	}
	if s == "" || s == "null" {
		ft.Time = time.Time{}
		return nil
	}

	// Try RFC3339 first (standard format: "2006-01-02T15:04:05Z07:00")
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		ft.Time = t
		return nil
	}

	// Try RFC3339Nano
	if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
		ft.Time = t
		return nil
	}

	// Try ISO 8601 with Z (UTC): "2006-01-02T15:04:05Z" or "2006-01-02T15:04:05.999Z"
	if strings.HasSuffix(s, "Z") {
		formats := []string{
			"2006-01-02T15:04:05.999999999Z",
			"2006-01-02T15:04:05.999Z",
			"2006-01-02T15:04:05Z",
			"2006-01-02T15:04Z", // Without seconds
		}
		for _, format := range formats {
			if t, err := time.Parse(format, s); err == nil {
				ft.Time = t
				return nil
			}
		}
	}

	// Try formats without timezone (datetime-local format)
	// These are interpreted as local time, then converted to UTC
	formats := []string{
		"2006-01-02T15:04:05.999999999", // With nanoseconds
		"2006-01-02T15:04:05.999",       // With milliseconds
		"2006-01-02T15:04:05",           // With seconds, no timezone
		"2006-01-02T15:04",              // Without seconds, no timezone (datetime-local)
	}

	for _, format := range formats {
		if t, err := time.Parse(format, s); err == nil {
			// Parse as if it's in local timezone, then convert to UTC
			// This handles datetime-local input which is in user's local time
			ft.Time = t.UTC()
			return nil
		}
	}

	// If all parsing fails, return error
	return &time.ParseError{
		Layout:     time.RFC3339,
		Value:      s,
		LayoutElem: "2006-01-02T15:04:05Z07:00",
		ValueElem:  s,
		Message:    "unable to parse time",
	}
}

// MarshalJSON implements json.Marshaler for FlexibleTime
func (ft FlexibleTime) MarshalJSON() ([]byte, error) {
	if ft.Time.IsZero() {
		return []byte("null"), nil
	}
	return json.Marshal(ft.Time.Format(time.RFC3339))
}

// Event represents an event in the system
type Event struct {
	ID        uuid.UUID `json:"id"`
	CreatorID uuid.UUID `json:"creator_id"`

	// Basic Information
	Title         string  `json:"title"`
	Description   *string `json:"description,omitempty"`
	CoverImageURL *string `json:"cover_image_url,omitempty"`

	// Date & Time
	StartDate time.Time  `json:"start_date"`
	EndDate   *time.Time `json:"end_date,omitempty"`
	Timezone  string     `json:"timezone"`
	IsAllDay  bool       `json:"is_all_day"`

	// Location
	LocationType    string   `json:"location_type"` // 'physical', 'online', 'hybrid'
	LocationName    *string  `json:"location_name,omitempty"`
	LocationAddress *string  `json:"location_address,omitempty"`
	OnlinePlatform  *string  `json:"online_platform,omitempty"` // 'zoom', 'google_meet', 'teams', 'custom'
	OnlineLink      *string  `json:"online_link,omitempty"`
	Latitude        *float64 `json:"latitude,omitempty"`
	Longitude       *float64 `json:"longitude,omitempty"`

	// Event Details
	Category     *string        `json:"category,omitempty"`
	Tags         pq.StringArray `json:"tags,omitempty"`
	MaxAttendees *int           `json:"max_attendees,omitempty"`
	IsPublic     bool           `json:"is_public"`
	PasswordHash *string        `json:"-"` // Hashed password for private events (not exposed in JSON)

	// Pricing
	IsFree   bool     `json:"is_free"`
	Price    *float64 `json:"price,omitempty"`
	Currency string   `json:"currency"`

	// Approval System
	Status              string     `json:"status"` // 'draft', 'pending', 'approved', 'rejected', 'cancelled', 'completed'
	ApprovalToken       *string    `json:"-"`      // Token for approval email (not exposed)
	ApprovalRequestedAt *time.Time `json:"approval_requested_at,omitempty"`
	ApprovedAt          *time.Time `json:"approved_at,omitempty"`
	ApprovedBy          *uuid.UUID `json:"approved_by,omitempty"`
	RejectionReason     *string    `json:"rejection_reason,omitempty"`
	AutoApproved        bool       `json:"auto_approved"`

	// Metadata
	ViewsCount        int       `json:"views_count"`
	ApplicationsCount int       `json:"applications_count"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`

	// Relations (populated by queries)
	Creator             *User             `json:"creator,omitempty"`
	HasApplied          bool              `json:"has_applied"`           // Current user has applied
	Application         *EventApplication `json:"application,omitempty"` // Current user's application
	IsPasswordProtected bool              `json:"is_password_protected"` // Whether event requires password
}

// EventApplication represents a user's application/RSVP to an event
type EventApplication struct {
	ID      uuid.UUID `json:"id"`
	EventID uuid.UUID `json:"event_id"`
	UserID  uuid.UUID `json:"user_id"`

	// Application Status
	Status string `json:"status"` // 'pending', 'approved', 'rejected', 'cancelled', 'attended', 'no_show'

	// Application Information
	FullName       *string `json:"full_name,omitempty"`
	Email          *string `json:"email,omitempty"`
	Phone          *string `json:"phone,omitempty"`
	Organization   *string `json:"organization,omitempty"`
	AdditionalInfo *string `json:"additional_info,omitempty"`

	// Ticket Information
	TicketToken       string    `json:"ticket_token"`
	TicketNumber      string    `json:"ticket_number"`
	TicketGeneratedAt time.Time `json:"ticket_generated_at"`

	// Payment
	PaymentStatus        string   `json:"payment_status"` // 'not_required', 'pending', 'completed', 'refunded'
	PaymentAmount        *float64 `json:"payment_amount,omitempty"`
	PaymentTransactionID *string  `json:"payment_transaction_id,omitempty"`

	// Metadata
	AppliedAt   time.Time  `json:"applied_at"`
	ApprovedAt  *time.Time `json:"approved_at,omitempty"`
	CancelledAt *time.Time `json:"cancelled_at,omitempty"`

	// Relations
	Event *Event `json:"event,omitempty"`
	User  *User  `json:"user,omitempty"`
}

// EventApprovalRequest represents a request for event approval
type EventApprovalRequest struct {
	ID        uuid.UUID `json:"id"`
	EventID   uuid.UUID `json:"event_id"`
	CreatorID uuid.UUID `json:"creator_id"`

	// Approval Token
	ApprovalToken  string    `json:"approval_token"`
	TokenExpiresAt time.Time `json:"token_expires_at"`

	// Request Details
	RequestReason *string `json:"request_reason,omitempty"`
	Category      *string `json:"category,omitempty"`
	IsPrivate     bool    `json:"is_private"`

	// Status
	Status string `json:"status"` // 'pending', 'approved', 'rejected', 'expired'

	// Admin Response
	ReviewedBy *uuid.UUID `json:"reviewed_by,omitempty"`
	ReviewedAt *time.Time `json:"reviewed_at,omitempty"`
	AdminNotes *string    `json:"admin_notes,omitempty"`

	// Metadata
	RequestedAt time.Time  `json:"requested_at"`
	EmailSentAt *time.Time `json:"email_sent_at,omitempty"`

	// Relations
	Event   *Event `json:"event,omitempty"`
	Creator *User  `json:"creator,omitempty"`
}

// EventCategory represents event categories with auto-approval rules
type EventCategory struct {
	ID               uuid.UUID `json:"id"`
	Name             string    `json:"name"`
	RequiresApproval bool      `json:"requires_approval"`
	Description      *string   `json:"description,omitempty"`
	CreatedAt        time.Time `json:"created_at"`
}

// EventComment represents a comment on an event
type EventComment struct {
	ID              uuid.UUID  `json:"id"`
	EventID         uuid.UUID  `json:"event_id"`
	UserID          uuid.UUID  `json:"user_id"`
	Content         string     `json:"content"`
	ParentCommentID *uuid.UUID `json:"parent_comment_id,omitempty"`
	LikesCount      int        `json:"likes_count"`
	IsEdited        bool       `json:"is_edited"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`

	// Relations
	User    *User          `json:"user,omitempty"`
	Replies []EventComment `json:"replies,omitempty"`
	IsLiked bool           `json:"is_liked"` // Current user liked
}

// CreateEventRequest represents the request payload for creating an event
type CreateEventRequest struct {
	Title           string        `json:"title" binding:"required,min=3,max=255"`
	Description     *string       `json:"description,omitempty"`
	CoverImageURL   *string       `json:"cover_image_url,omitempty"`
	StartDate       FlexibleTime  `json:"start_date" binding:"required"`
	EndDate         *FlexibleTime `json:"end_date,omitempty"`
	Timezone        string        `json:"timezone"`
	IsAllDay        bool          `json:"is_all_day"`
	LocationType    string        `json:"location_type" binding:"required,oneof=physical online hybrid"`
	LocationName    *string       `json:"location_name,omitempty"`
	LocationAddress *string       `json:"location_address,omitempty"`
	OnlinePlatform  *string       `json:"online_platform,omitempty"`
	OnlineLink      *string       `json:"online_link,omitempty"`
	Latitude        *float64      `json:"latitude,omitempty"`
	Longitude       *float64      `json:"longitude,omitempty"`
	Category        *string       `json:"category,omitempty"`
	Tags            []string      `json:"tags,omitempty"`
	MaxAttendees    *int          `json:"max_attendees,omitempty"`
	IsPublic        bool          `json:"is_public"`
	Password        *string       `json:"password,omitempty"` // Plain password (will be hashed)
	IsFree          bool          `json:"is_free"`
	Price           *float64      `json:"price,omitempty"`
	Currency        string        `json:"currency"`
}

// ApplyToEventRequest represents the request payload for applying to an event
type ApplyToEventRequest struct {
	FullName       *string `json:"full_name,omitempty"`
	Email          *string `json:"email,omitempty"`
	Phone          *string `json:"phone,omitempty"`
	Organization   *string `json:"organization,omitempty"`
	AdditionalInfo *string `json:"additional_info,omitempty"`
	UseProfileData bool    `json:"use_profile_data"`   // Auto-fill from profile
	Password       *string `json:"password,omitempty"` // For private events
}

// ApproveEventRequest represents the request payload for approving/rejecting an event
type ApproveEventRequest struct {
	Status          string  `json:"status" binding:"required,oneof=approved rejected"`
	RejectionReason *string `json:"rejection_reason,omitempty"`
	AdminNotes      *string `json:"admin_notes,omitempty"`
}

// EventFilter represents filters for querying events
type EventFilter struct {
	Status       *string    `json:"status,omitempty"` // 'upcoming', 'past', 'all'
	Category     *string    `json:"category,omitempty"`
	IsPublic     *bool      `json:"is_public,omitempty"`
	LocationType *string    `json:"location_type,omitempty"`
	IsFree       *bool      `json:"is_free,omitempty"`
	StartDate    *time.Time `json:"start_date,omitempty"`
	EndDate      *time.Time `json:"end_date,omitempty"`
	Search       *string    `json:"search,omitempty"`
	Tags         []string   `json:"tags,omitempty"`
	Limit        int        `json:"limit"`
	Offset       int        `json:"offset"`
}

// EventStats represents statistics for an event
type EventStats struct {
	TotalApplications    int `json:"total_applications"`
	ApprovedApplications int `json:"approved_applications"`
	PendingApplications  int `json:"pending_applications"`
	ViewsCount           int `json:"views_count"`
}

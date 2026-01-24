package repository

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// SupabaseEventRepository implements EventRepository using Supabase REST API
type SupabaseEventRepository struct {
	supabaseURL string
	serviceKey  string
	client      *http.Client
}

// NewSupabaseEventRepository creates a new Supabase event repository
func NewSupabaseEventRepository(supabaseURL, serviceKey string) *SupabaseEventRepository {
	return &SupabaseEventRepository{
		supabaseURL: supabaseURL,
		serviceKey:  serviceKey,
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// Helper to make Supabase requests
func (r *SupabaseEventRepository) makeRequest(method, table, query string, body interface{}) ([]byte, error) {
	url := fmt.Sprintf("%s/rest/v1/%s%s", r.supabaseURL, table, query)

	var reqBody io.Reader
	if body != nil {
		jsonData, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request body: %w", err)
		}
		reqBody = bytes.NewBuffer(jsonData)
	}

	req, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", r.serviceKey)
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", r.serviceKey))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "return=representation")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode >= 400 {
		log.Printf("[SupabaseEventRepo] Error response (status %d): %s", resp.StatusCode, string(data))
		return nil, fmt.Errorf("supabase error (status %d): %s", resp.StatusCode, string(data))
	}

	return data, nil
}

// supabaseEvent represents the event structure from Supabase
type supabaseEvent struct {
	ID                  uuid.UUID     `json:"id"`
	CreatorID           uuid.UUID     `json:"creator_id"`
	Title               string        `json:"title"`
	Description         *string       `json:"description"`
	CoverImageURL       *string       `json:"cover_image_url"`
	StartDate           string        `json:"start_date"`
	EndDate             *string       `json:"end_date"`
	Timezone            string        `json:"timezone"`
	IsAllDay            bool          `json:"is_all_day"`
	LocationType        string        `json:"location_type"`
	LocationName        *string       `json:"location_name"`
	LocationAddress     *string       `json:"location_address"`
	OnlinePlatform      *string       `json:"online_platform"`
	OnlineLink          *string       `json:"online_link"`
	Latitude            *float64      `json:"latitude"`
	Longitude           *float64      `json:"longitude"`
	Category            *string       `json:"category"`
	Tags                []string      `json:"tags"`
	MaxAttendees        *int          `json:"max_attendees"`
	IsPublic            bool          `json:"is_public"`
	PasswordHash        *string       `json:"password_hash"`
	IsFree              bool          `json:"is_free"`
	Price               *float64      `json:"price"`
	Currency            string        `json:"currency"`
	Status              string        `json:"status"`
	ApprovalToken       *string       `json:"approval_token"`
	ApprovalRequestedAt *string       `json:"approval_requested_at"`
	ApprovedAt          *string       `json:"approved_at"`
	ApprovedBy          *uuid.UUID    `json:"approved_by"`
	RejectionReason     *string       `json:"rejection_reason"`
	AutoApproved        bool          `json:"auto_approved"`
	ViewsCount          int           `json:"views_count"`
	ApplicationsCount   int           `json:"applications_count"`
	CreatedAt           string        `json:"created_at"`
	UpdatedAt           string        `json:"updated_at"`
	Creator             *supabaseUser `json:"creator"`
}

func (se *supabaseEvent) toEvent() (*models.Event, error) {
	event := &models.Event{
		ID:                  se.ID,
		CreatorID:           se.CreatorID,
		Title:               se.Title,
		Description:         se.Description,
		CoverImageURL:       se.CoverImageURL,
		Timezone:            se.Timezone,
		IsAllDay:            se.IsAllDay,
		LocationType:        se.LocationType,
		LocationName:        se.LocationName,
		LocationAddress:     se.LocationAddress,
		OnlinePlatform:      se.OnlinePlatform,
		OnlineLink:          se.OnlineLink,
		Latitude:            se.Latitude,
		Longitude:           se.Longitude,
		Category:            se.Category,
		Tags:                pq.StringArray(se.Tags),
		MaxAttendees:        se.MaxAttendees,
		IsPublic:            se.IsPublic,
		PasswordHash:        se.PasswordHash,
		IsFree:              se.IsFree,
		Price:               se.Price,
		Currency:            se.Currency,
		Status:              se.Status,
		ApprovalToken:       se.ApprovalToken,
		ApprovedBy:          se.ApprovedBy,
		RejectionReason:     se.RejectionReason,
		AutoApproved:        se.AutoApproved,
		ViewsCount:          se.ViewsCount,
		ApplicationsCount:   se.ApplicationsCount,
		IsPasswordProtected: se.PasswordHash != nil && *se.PasswordHash != "",
	}

	// Parse timestamps
	if startDate, err := time.Parse(time.RFC3339, se.StartDate); err == nil {
		event.StartDate = startDate
	}
	if se.EndDate != nil {
		if endDate, err := time.Parse(time.RFC3339, *se.EndDate); err == nil {
			event.EndDate = &endDate
		}
	}
	if se.ApprovalRequestedAt != nil {
		if t, err := time.Parse(time.RFC3339, *se.ApprovalRequestedAt); err == nil {
			event.ApprovalRequestedAt = &t
		}
	}
	if se.ApprovedAt != nil {
		if t, err := time.Parse(time.RFC3339, *se.ApprovedAt); err == nil {
			event.ApprovedAt = &t
		}
	}
	if se.CreatedAt != "" {
		if t, err := time.Parse(time.RFC3339, se.CreatedAt); err == nil {
			event.CreatedAt = t
		}
	}
	if se.UpdatedAt != "" {
		if t, err := time.Parse(time.RFC3339, se.UpdatedAt); err == nil {
			event.UpdatedAt = t
		}
	}

	// Parse creator
	if se.Creator != nil {
		creator, err := se.Creator.toUser()
		if err == nil {
			event.Creator = creator
		}
	}

	return event, nil
}

// CreateEvent creates a new event
func (r *SupabaseEventRepository) CreateEvent(ctx context.Context, event *models.Event) error {
	if event.ID == uuid.Nil {
		event.ID = uuid.New()
	}

	log.Printf("[SupabaseEventRepo] Creating event: ID=%s, Title=%s, StartDate=%v", event.ID, event.Title, event.StartDate)

	payload := map[string]interface{}{
		"id":               event.ID,
		"creator_id":       event.CreatorID,
		"title":            event.Title,
		"description":      event.Description,
		"cover_image_url":  event.CoverImageURL,
		"start_date":       event.StartDate.Format(time.RFC3339),
		"timezone":         event.Timezone,
		"is_all_day":       event.IsAllDay,
		"location_type":    event.LocationType,
		"location_name":    event.LocationName,
		"location_address": event.LocationAddress,
		"online_platform":  event.OnlinePlatform,
		"online_link":      event.OnlineLink,
		"latitude":         event.Latitude,
		"longitude":        event.Longitude,
		"category":         event.Category,
		"tags":             []string(event.Tags), // Convert pq.StringArray to []string for JSON
		"max_attendees":    event.MaxAttendees,
		"is_public":        event.IsPublic,
		"password_hash":    event.PasswordHash,
		"is_free":          event.IsFree,
		"price":            event.Price,
		"currency":         event.Currency,
		"status":           event.Status,
		"approval_token":   event.ApprovalToken,
		"auto_approved":    event.AutoApproved,
	}

	if event.EndDate != nil {
		payload["end_date"] = event.EndDate.Format(time.RFC3339)
	}
	if event.ApprovalRequestedAt != nil {
		payload["approval_requested_at"] = event.ApprovalRequestedAt.Format(time.RFC3339)
	}
	if event.ApprovedAt != nil {
		payload["approved_at"] = event.ApprovedAt.Format(time.RFC3339)
	}

	_, err := r.makeRequest("POST", "events", "?select=*", payload)
	return err
}

// GetEventByID retrieves an event by ID
func (r *SupabaseEventRepository) GetEventByID(ctx context.Context, id uuid.UUID, userID *uuid.UUID) (*models.Event, error) {
	query := fmt.Sprintf("?id=eq.%s&select=*,creator:users!events_creator_id_fkey(id,username,display_name,profile_picture,is_verified)", id)

	data, err := r.makeRequest("GET", "events", query, nil)
	if err != nil {
		return nil, err
	}

	var events []supabaseEvent
	if err := json.Unmarshal(data, &events); err != nil {
		return nil, fmt.Errorf("failed to unmarshal events: %w", err)
	}

	if len(events) == 0 {
		return nil, fmt.Errorf("event not found")
	}

	event, err := events[0].toEvent()
	if err != nil {
		return nil, err
	}

	// Check if user has applied
	if userID != nil {
		application, _ := r.GetApplicationByEventAndUser(ctx, id, *userID)
		if application != nil {
			event.HasApplied = true
			event.Application = application
		}
	}

	return event, nil
}

// ListEvents lists events with filters
func (r *SupabaseEventRepository) ListEvents(ctx context.Context, filter *models.EventFilter, userID *uuid.UUID) ([]*models.Event, error) {
	var queryParams []string

	// Base condition: only show approved public events or user's own events
	// PostgREST OR syntax: or=(field1.operator.value1,field2.operator.value2)
	// For nested AND, we need to use a different approach
	// Always filter by approved status first
	queryParams = append(queryParams, "status=eq.approved")

	// For anonymous users, also filter by is_public=true
	// For logged-in users, RLS policies will handle showing their own events
	if userID == nil {
		queryParams = append(queryParams, "is_public=eq.true")
	}

	// Apply filters
	if filter.Status != nil {
		now := time.Now().Format(time.RFC3339)
		if *filter.Status == "upcoming" {
			queryParams = append(queryParams, fmt.Sprintf("start_date=gt.%s", url.QueryEscape(now)))
		} else if *filter.Status == "past" {
			queryParams = append(queryParams, fmt.Sprintf("start_date=lt.%s", url.QueryEscape(now)))
		}
	}

	if filter.Category != nil {
		queryParams = append(queryParams, fmt.Sprintf("category=eq.%s", url.QueryEscape(*filter.Category)))
	}

	if filter.IsPublic != nil {
		queryParams = append(queryParams, fmt.Sprintf("is_public=eq.%t", *filter.IsPublic))
	}

	if filter.LocationType != nil {
		queryParams = append(queryParams, fmt.Sprintf("location_type=eq.%s", url.QueryEscape(*filter.LocationType)))
	}

	if filter.IsFree != nil {
		queryParams = append(queryParams, fmt.Sprintf("is_free=eq.%t", *filter.IsFree))
	}

	if filter.Search != nil {
		// Search in title and description
		queryParams = append(queryParams, fmt.Sprintf("or=(title.ilike.*%s*,description.ilike.*%s*)", url.QueryEscape(*filter.Search), url.QueryEscape(*filter.Search)))
	}

	// Build query string
	query := strings.Join(queryParams, "&")
	query = fmt.Sprintf("?%s&select=*,creator:users!events_creator_id_fkey(id,username,display_name,profile_picture,is_verified)&order=start_date.asc&limit=%d&offset=%d",
		query, filter.Limit, filter.Offset)

	log.Printf("[SupabaseEventRepo] ListEvents query: %s", query)

	data, err := r.makeRequest("GET", "events", query, nil)
	if err != nil {
		return nil, err
	}

	var supabaseEvents []supabaseEvent
	if err := json.Unmarshal(data, &supabaseEvents); err != nil {
		return nil, fmt.Errorf("failed to unmarshal events: %w", err)
	}

	events := make([]*models.Event, len(supabaseEvents))
	for i, se := range supabaseEvents {
		event, err := se.toEvent()
		if err != nil {
			return nil, err
		}

		// Check if user has applied
		if userID != nil {
			application, _ := r.GetApplicationByEventAndUser(ctx, event.ID, *userID)
			if application != nil {
				event.HasApplied = true
				event.Application = application
			}
		}

		events[i] = event
	}

	return events, nil
}

// CreateApplication creates a new event application
func (r *SupabaseEventRepository) CreateApplication(ctx context.Context, application *models.EventApplication) error {
	if application.ID == uuid.Nil {
		application.ID = uuid.New()
	}

	payload := map[string]interface{}{
		"id":                     application.ID,
		"event_id":               application.EventID,
		"user_id":                application.UserID,
		"status":                 application.Status,
		"full_name":              application.FullName,
		"email":                  application.Email,
		"phone":                  application.Phone,
		"organization":           application.Organization,
		"additional_info":        application.AdditionalInfo,
		"ticket_token":           application.TicketToken,
		"ticket_number":          application.TicketNumber,
		"ticket_generated_at":    application.TicketGeneratedAt.Format(time.RFC3339),
		"payment_status":         application.PaymentStatus,
		"payment_amount":         application.PaymentAmount,
		"payment_transaction_id": application.PaymentTransactionID,
		"applied_at":             application.AppliedAt.Format(time.RFC3339),
	}

	if application.ApprovedAt != nil {
		payload["approved_at"] = application.ApprovedAt.Format(time.RFC3339)
	}

	_, err := r.makeRequest("POST", "event_applications", "?select=*", payload)
	return err
}

// GetApplicationByEventAndUser gets application by event and user
func (r *SupabaseEventRepository) GetApplicationByEventAndUser(ctx context.Context, eventID, userID uuid.UUID) (*models.EventApplication, error) {
	query := fmt.Sprintf("?event_id=eq.%s&user_id=eq.%s&select=*", eventID, userID)

	data, err := r.makeRequest("GET", "event_applications", query, nil)
	if err != nil {
		return nil, err
	}

	var applications []models.EventApplication
	if err := json.Unmarshal(data, &applications); err != nil {
		return nil, fmt.Errorf("failed to unmarshal applications: %w", err)
	}

	if len(applications) == 0 {
		return nil, fmt.Errorf("application not found")
	}

	return &applications[0], nil
}

// UpdateEvent updates an event
func (r *SupabaseEventRepository) UpdateEvent(ctx context.Context, event *models.Event) error {
	query := fmt.Sprintf("?id=eq.%s", event.ID)

	payload := map[string]interface{}{
		"title":            event.Title,
		"description":      event.Description,
		"cover_image_url":  event.CoverImageURL,
		"start_date":       event.StartDate.Format(time.RFC3339),
		"timezone":         event.Timezone,
		"is_all_day":       event.IsAllDay,
		"location_type":    event.LocationType,
		"location_name":    event.LocationName,
		"location_address": event.LocationAddress,
		"online_platform":  event.OnlinePlatform,
		"online_link":      event.OnlineLink,
		"latitude":         event.Latitude,
		"longitude":        event.Longitude,
		"category":         event.Category,
		"tags":             []string(event.Tags), // Convert pq.StringArray to []string for JSON
		"max_attendees":    event.MaxAttendees,
		"is_public":        event.IsPublic,
		"is_free":          event.IsFree,
		"price":            event.Price,
		"currency":         event.Currency,
		"status":           event.Status,
		"updated_at":       time.Now().Format(time.RFC3339),
	}

	if event.EndDate != nil {
		payload["end_date"] = event.EndDate.Format(time.RFC3339)
	}
	if event.PasswordHash != nil {
		payload["password_hash"] = event.PasswordHash
	}

	_, err := r.makeRequest("PATCH", "events", query, payload)
	return err
}

// GetCategoryByName gets category by name
func (r *SupabaseEventRepository) GetCategoryByName(ctx context.Context, name string) (*models.EventCategory, error) {
	query := fmt.Sprintf("?name=eq.%s&select=*", url.QueryEscape(name))

	data, err := r.makeRequest("GET", "event_categories", query, nil)
	if err != nil {
		return nil, err
	}

	var categories []models.EventCategory
	if err := json.Unmarshal(data, &categories); err != nil {
		return nil, fmt.Errorf("failed to unmarshal categories: %w", err)
	}

	if len(categories) == 0 {
		return nil, fmt.Errorf("category not found")
	}

	return &categories[0], nil
}

// IncrementEventViews increments event views count
func (r *SupabaseEventRepository) IncrementEventViews(ctx context.Context, eventID uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s", eventID)
	payload := map[string]interface{}{
		"views_count": "views_count+1",
	}

	_, err := r.makeRequest("PATCH", "events", query, payload)
	return err
}

// Stub implementations for remaining methods (to be completed)
func (r *SupabaseEventRepository) DeleteEvent(ctx context.Context, eventID uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s", eventID)
	_, err := r.makeRequest("DELETE", "events", query, nil)
	return err
}

func (r *SupabaseEventRepository) GetEventsByCreator(ctx context.Context, creatorID uuid.UUID, limit, offset int) ([]*models.Event, error) {
	query := fmt.Sprintf("?creator_id=eq.%s&select=*,creator:users!events_creator_id_fkey(id,username,display_name,profile_picture,is_verified)&order=created_at.desc&limit=%d&offset=%d",
		creatorID, limit, offset)

	data, err := r.makeRequest("GET", "events", query, nil)
	if err != nil {
		return nil, err
	}

	var supabaseEvents []supabaseEvent
	if err := json.Unmarshal(data, &supabaseEvents); err != nil {
		return nil, fmt.Errorf("failed to unmarshal events: %w", err)
	}

	events := make([]*models.Event, len(supabaseEvents))
	for i, se := range supabaseEvents {
		event, err := se.toEvent()
		if err != nil {
			return nil, err
		}
		events[i] = event
	}

	return events, nil
}

func (r *SupabaseEventRepository) GetUpcomingEvents(ctx context.Context, limit, offset int, userID *uuid.UUID) ([]*models.Event, error) {
	filter := &models.EventFilter{
		Status: stringPtr("upcoming"),
		Limit:  limit,
		Offset: offset,
	}
	return r.ListEvents(ctx, filter, userID)
}

func (r *SupabaseEventRepository) GetPastEvents(ctx context.Context, limit, offset int, userID *uuid.UUID) ([]*models.Event, error) {
	filter := &models.EventFilter{
		Status: stringPtr("past"),
		Limit:  limit,
		Offset: offset,
	}
	return r.ListEvents(ctx, filter, userID)
}

func (r *SupabaseEventRepository) SearchEvents(ctx context.Context, query string, limit, offset int, userID *uuid.UUID) ([]*models.Event, error) {
	// Implementation for search
	filter := &models.EventFilter{
		Search: &query,
		Limit:  limit,
		Offset: offset,
	}
	return r.ListEvents(ctx, filter, userID)
}

func (r *SupabaseEventRepository) GetApplicationByID(ctx context.Context, id uuid.UUID) (*models.EventApplication, error) {
	query := fmt.Sprintf("?id=eq.%s&select=*", id)

	data, err := r.makeRequest("GET", "event_applications", query, nil)
	if err != nil {
		return nil, err
	}

	var applications []models.EventApplication
	if err := json.Unmarshal(data, &applications); err != nil {
		return nil, fmt.Errorf("failed to unmarshal applications: %w", err)
	}

	if len(applications) == 0 {
		return nil, fmt.Errorf("application not found")
	}

	return &applications[0], nil
}

func (r *SupabaseEventRepository) GetApplicationsByEvent(ctx context.Context, eventID uuid.UUID, limit, offset int) ([]*models.EventApplication, error) {
	query := fmt.Sprintf("?event_id=eq.%s&select=*&order=applied_at.desc&limit=%d&offset=%d", eventID, limit, offset)

	data, err := r.makeRequest("GET", "event_applications", query, nil)
	if err != nil {
		return nil, err
	}

	var applications []models.EventApplication
	if err := json.Unmarshal(data, &applications); err != nil {
		return nil, fmt.Errorf("failed to unmarshal applications: %w", err)
	}

	result := make([]*models.EventApplication, len(applications))
	for i := range applications {
		result[i] = &applications[i]
	}

	return result, nil
}

func (r *SupabaseEventRepository) GetApplicationsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.EventApplication, error) {
	query := fmt.Sprintf("?user_id=eq.%s&select=*&order=applied_at.desc&limit=%d&offset=%d", userID, limit, offset)

	data, err := r.makeRequest("GET", "event_applications", query, nil)
	if err != nil {
		return nil, err
	}

	var applications []models.EventApplication
	if err := json.Unmarshal(data, &applications); err != nil {
		return nil, fmt.Errorf("failed to unmarshal applications: %w", err)
	}

	result := make([]*models.EventApplication, len(applications))
	for i := range applications {
		result[i] = &applications[i]
	}

	return result, nil
}

func (r *SupabaseEventRepository) UpdateApplication(ctx context.Context, application *models.EventApplication) error {
	query := fmt.Sprintf("?id=eq.%s", application.ID)

	payload := map[string]interface{}{
		"status":                 application.Status,
		"full_name":              application.FullName,
		"email":                  application.Email,
		"phone":                  application.Phone,
		"organization":           application.Organization,
		"additional_info":        application.AdditionalInfo,
		"payment_status":         application.PaymentStatus,
		"payment_amount":         application.PaymentAmount,
		"payment_transaction_id": application.PaymentTransactionID,
	}

	if application.ApprovedAt != nil {
		payload["approved_at"] = application.ApprovedAt.Format(time.RFC3339)
	}
	if application.CancelledAt != nil {
		payload["cancelled_at"] = application.CancelledAt.Format(time.RFC3339)
	}

	_, err := r.makeRequest("PATCH", "event_applications", query, payload)
	return err
}

func (r *SupabaseEventRepository) DeleteApplication(ctx context.Context, applicationID uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s", applicationID)
	_, err := r.makeRequest("DELETE", "event_applications", query, nil)
	return err
}

func (r *SupabaseEventRepository) CreateApprovalRequest(ctx context.Context, request *models.EventApprovalRequest) error {
	if request.ID == uuid.Nil {
		request.ID = uuid.New()
	}

	payload := map[string]interface{}{
		"id":               request.ID,
		"event_id":         request.EventID,
		"creator_id":       request.CreatorID,
		"approval_token":   request.ApprovalToken,
		"token_expires_at": request.TokenExpiresAt.Format(time.RFC3339),
		"request_reason":   request.RequestReason,
		"category":         request.Category,
		"is_private":       request.IsPrivate,
		"status":           request.Status,
		"requested_at":     request.RequestedAt.Format(time.RFC3339),
	}

	if request.ReviewedBy != nil {
		payload["reviewed_by"] = request.ReviewedBy
	}
	if request.ReviewedAt != nil {
		payload["reviewed_at"] = request.ReviewedAt.Format(time.RFC3339)
	}
	if request.AdminNotes != nil {
		payload["admin_notes"] = request.AdminNotes
	}
	if request.EmailSentAt != nil {
		payload["email_sent_at"] = request.EmailSentAt.Format(time.RFC3339)
	}

	_, err := r.makeRequest("POST", "event_approval_requests", "?select=*", payload)
	return err
}

func (r *SupabaseEventRepository) GetApprovalRequestByToken(ctx context.Context, token string) (*models.EventApprovalRequest, error) {
	query := fmt.Sprintf("?approval_token=eq.%s&select=*", url.QueryEscape(token))

	data, err := r.makeRequest("GET", "event_approval_requests", query, nil)
	if err != nil {
		return nil, err
	}

	var requests []models.EventApprovalRequest
	if err := json.Unmarshal(data, &requests); err != nil {
		return nil, fmt.Errorf("failed to unmarshal approval requests: %w", err)
	}

	if len(requests) == 0 {
		return nil, fmt.Errorf("approval request not found")
	}

	return &requests[0], nil
}

func (r *SupabaseEventRepository) GetApprovalRequestByEvent(ctx context.Context, eventID uuid.UUID) (*models.EventApprovalRequest, error) {
	query := fmt.Sprintf("?event_id=eq.%s&select=*", eventID)

	data, err := r.makeRequest("GET", "event_approval_requests", query, nil)
	if err != nil {
		return nil, err
	}

	var requests []models.EventApprovalRequest
	if err := json.Unmarshal(data, &requests); err != nil {
		return nil, fmt.Errorf("failed to unmarshal approval requests: %w", err)
	}

	if len(requests) == 0 {
		return nil, fmt.Errorf("approval request not found")
	}

	return &requests[0], nil
}

func (r *SupabaseEventRepository) UpdateApprovalRequest(ctx context.Context, request *models.EventApprovalRequest) error {
	query := fmt.Sprintf("?id=eq.%s", request.ID)

	payload := map[string]interface{}{
		"status":      request.Status,
		"admin_notes": request.AdminNotes,
	}

	if request.ReviewedBy != nil {
		payload["reviewed_by"] = request.ReviewedBy
	}
	if request.ReviewedAt != nil {
		payload["reviewed_at"] = request.ReviewedAt.Format(time.RFC3339)
	}

	_, err := r.makeRequest("PATCH", "event_approval_requests", query, payload)
	return err
}

func (r *SupabaseEventRepository) GetPendingApprovalRequests(ctx context.Context, limit, offset int) ([]*models.EventApprovalRequest, error) {
	query := fmt.Sprintf("?status=eq.pending&select=*&order=requested_at.desc&limit=%d&offset=%d", limit, offset)

	data, err := r.makeRequest("GET", "event_approval_requests", query, nil)
	if err != nil {
		return nil, err
	}

	var requests []models.EventApprovalRequest
	if err := json.Unmarshal(data, &requests); err != nil {
		return nil, fmt.Errorf("failed to unmarshal approval requests: %w", err)
	}

	result := make([]*models.EventApprovalRequest, len(requests))
	for i := range requests {
		result[i] = &requests[i]
	}

	return result, nil
}

func (r *SupabaseEventRepository) GetAllCategories(ctx context.Context) ([]*models.EventCategory, error) {
	query := "?select=*&order=name.asc"

	data, err := r.makeRequest("GET", "event_categories", query, nil)
	if err != nil {
		return nil, err
	}

	var categories []models.EventCategory
	if err := json.Unmarshal(data, &categories); err != nil {
		return nil, fmt.Errorf("failed to unmarshal categories: %w", err)
	}

	result := make([]*models.EventCategory, len(categories))
	for i := range categories {
		result[i] = &categories[i]
	}

	return result, nil
}

func (r *SupabaseEventRepository) CreateEventComment(ctx context.Context, comment *models.EventComment) error {
	if comment.ID == uuid.Nil {
		comment.ID = uuid.New()
	}

	payload := map[string]interface{}{
		"id":                comment.ID,
		"event_id":          comment.EventID,
		"user_id":           comment.UserID,
		"content":           comment.Content,
		"parent_comment_id": comment.ParentCommentID,
		"likes_count":       comment.LikesCount,
		"is_edited":         comment.IsEdited,
		"created_at":        comment.CreatedAt.Format(time.RFC3339),
		"updated_at":        comment.UpdatedAt.Format(time.RFC3339),
	}

	_, err := r.makeRequest("POST", "event_comments", "?select=*", payload)
	return err
}

func (r *SupabaseEventRepository) GetEventComments(ctx context.Context, eventID uuid.UUID, limit, offset int, userID *uuid.UUID) ([]*models.EventComment, error) {
	query := fmt.Sprintf("?event_id=eq.%s&parent_comment_id=is.null&select=*&order=created_at.desc&limit=%d&offset=%d",
		eventID, limit, offset)

	data, err := r.makeRequest("GET", "event_comments", query, nil)
	if err != nil {
		return nil, err
	}

	var comments []models.EventComment
	if err := json.Unmarshal(data, &comments); err != nil {
		return nil, fmt.Errorf("failed to unmarshal comments: %w", err)
	}

	result := make([]*models.EventComment, len(comments))
	for i := range comments {
		result[i] = &comments[i]
	}

	return result, nil
}

func (r *SupabaseEventRepository) UpdateEventComment(ctx context.Context, comment *models.EventComment) error {
	query := fmt.Sprintf("?id=eq.%s", comment.ID)

	payload := map[string]interface{}{
		"content":    comment.Content,
		"is_edited":  true,
		"updated_at": time.Now().Format(time.RFC3339),
	}

	_, err := r.makeRequest("PATCH", "event_comments", query, payload)
	return err
}

func (r *SupabaseEventRepository) DeleteEventComment(ctx context.Context, commentID uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s", commentID)
	_, err := r.makeRequest("DELETE", "event_comments", query, nil)
	return err
}

func (r *SupabaseEventRepository) GetEventStats(ctx context.Context, eventID uuid.UUID) (*models.EventStats, error) {
	// Get applications count
	applications, err := r.GetApplicationsByEvent(ctx, eventID, 1000, 0)
	if err != nil {
		return nil, err
	}

	stats := &models.EventStats{
		TotalApplications: len(applications),
	}

	for _, app := range applications {
		if app.Status == "approved" {
			stats.ApprovedApplications++
		} else if app.Status == "pending" {
			stats.PendingApplications++
		}
	}

	// Get views count
	event, err := r.GetEventByID(ctx, eventID, nil)
	if err != nil {
		return nil, err
	}
	stats.ViewsCount = event.ViewsCount

	return stats, nil
}

// Helper function
func stringPtr(s string) *string {
	return &s
}

package repository

import (
	"context"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// EventRepository defines the data-access contract for events
type EventRepository interface {
	// Event CRUD
	CreateEvent(ctx context.Context, event *models.Event) error
	GetEventByID(ctx context.Context, id uuid.UUID, userID *uuid.UUID) (*models.Event, error)
	UpdateEvent(ctx context.Context, event *models.Event) error
	DeleteEvent(ctx context.Context, eventID uuid.UUID) error

	// Event Queries
	ListEvents(ctx context.Context, filter *models.EventFilter, userID *uuid.UUID) ([]*models.Event, error)
	GetEventsByCreator(ctx context.Context, creatorID uuid.UUID, limit, offset int) ([]*models.Event, error)
	GetUpcomingEvents(ctx context.Context, limit, offset int, userID *uuid.UUID) ([]*models.Event, error)
	GetPastEvents(ctx context.Context, limit, offset int, userID *uuid.UUID) ([]*models.Event, error)
	SearchEvents(ctx context.Context, query string, limit, offset int, userID *uuid.UUID) ([]*models.Event, error)

	// Event Applications
	CreateApplication(ctx context.Context, application *models.EventApplication) error
	GetApplicationByID(ctx context.Context, id uuid.UUID) (*models.EventApplication, error)
	GetApplicationByEventAndUser(ctx context.Context, eventID, userID uuid.UUID) (*models.EventApplication, error)
	GetApplicationsByEvent(ctx context.Context, eventID uuid.UUID, limit, offset int) ([]*models.EventApplication, error)
	GetApplicationsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.EventApplication, error)
	UpdateApplication(ctx context.Context, application *models.EventApplication) error
	DeleteApplication(ctx context.Context, applicationID uuid.UUID) error

	// Event Approval
	CreateApprovalRequest(ctx context.Context, request *models.EventApprovalRequest) error
	GetApprovalRequestByToken(ctx context.Context, token string) (*models.EventApprovalRequest, error)
	GetApprovalRequestByEvent(ctx context.Context, eventID uuid.UUID) (*models.EventApprovalRequest, error)
	UpdateApprovalRequest(ctx context.Context, request *models.EventApprovalRequest) error
	GetPendingApprovalRequests(ctx context.Context, limit, offset int) ([]*models.EventApprovalRequest, error)

	// Event Categories
	GetCategoryByName(ctx context.Context, name string) (*models.EventCategory, error)
	GetAllCategories(ctx context.Context) ([]*models.EventCategory, error)

	// Event Comments
	CreateEventComment(ctx context.Context, comment *models.EventComment) error
	GetEventComments(ctx context.Context, eventID uuid.UUID, limit, offset int, userID *uuid.UUID) ([]*models.EventComment, error)
	UpdateEventComment(ctx context.Context, comment *models.EventComment) error
	DeleteEventComment(ctx context.Context, commentID uuid.UUID) error

	// Event Stats
	IncrementEventViews(ctx context.Context, eventID uuid.UUID) error
	GetEventStats(ctx context.Context, eventID uuid.UUID) (*models.EventStats, error)
}

// EventStats represents statistics for an event
type EventStats struct {
	TotalApplications    int `json:"total_applications"`
	ApprovedApplications int `json:"approved_applications"`
	PendingApplications  int `json:"pending_applications"`
	ViewsCount           int `json:"views_count"`
}

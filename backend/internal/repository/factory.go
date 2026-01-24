package repository

import (
	"fmt"
	"strings"

	"histeeria-backend/internal/config"
)

// NewUserRepository creates a concrete UserRepository based on config.
// provider values: "supabase" (default), "postgres" (future), etc.
func NewUserRepository(cfg *config.Config) (UserRepository, error) {
	provider := strings.ToLower(strings.TrimSpace(cfg.Server.DataProvider))
	if provider == "" {
		provider = "supabase" // default
	}

	// Supabase via PostgREST
	if provider == "supabase" {
		return NewSupabaseUserRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey), nil
	}

	return nil, fmt.Errorf("unsupported data provider: %s", provider)
}

// NewSessionRepository creates a concrete SessionRepository based on config
func NewSessionRepository(cfg *config.Config) (SessionRepository, error) {
	provider := strings.ToLower(strings.TrimSpace(cfg.Server.DataProvider))
	if provider == "" {
		provider = "supabase" // default
	}

	// Supabase via PostgREST
	if provider == "supabase" {
		return NewSupabaseSessionRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey), nil
	}

	return nil, fmt.Errorf("unsupported data provider: %s", provider)
}

// NewRelationshipRepository creates a concrete RelationshipRepository based on config
func NewRelationshipRepository(cfg *config.Config) (RelationshipRepository, error) {
	provider := strings.ToLower(strings.TrimSpace(cfg.Server.DataProvider))
	if provider == "" {
		provider = "supabase" // default
	}

	// Supabase via PostgREST
	if provider == "supabase" {
		return NewSupabaseRelationshipRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey), nil
	}

	return nil, fmt.Errorf("unsupported data provider: %s", provider)
}

// NewNotificationRepository creates a concrete NotificationRepository based on config
func NewNotificationRepository(cfg *config.Config) (NotificationRepository, error) {
	provider := strings.ToLower(strings.TrimSpace(cfg.Server.DataProvider))
	if provider == "" {
		provider = "supabase" // default
	}

	// Supabase via PostgREST
	if provider == "supabase" {
		return NewSupabaseNotificationRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey), nil
	}

	return nil, fmt.Errorf("unsupported data provider: %s", provider)
}

// NewMessageRepository creates a concrete MessageRepository based on config
func NewMessageRepository(cfg *config.Config) (MessageRepository, error) {
	provider := strings.ToLower(strings.TrimSpace(cfg.Server.DataProvider))
	if provider == "" {
		provider = "supabase" // default
	}

	// Supabase via GORM
	if provider == "supabase" {
		return NewSupabaseMessageRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	}

	return nil, fmt.Errorf("unsupported data provider: %s", provider)
}

// NewEventRepository creates a concrete EventRepository based on config
func NewEventRepository(cfg *config.Config) (EventRepository, error) {
	provider := strings.ToLower(strings.TrimSpace(cfg.Server.DataProvider))
	if provider == "" {
		provider = "supabase" // default
	}

	// Supabase via PostgREST
	if provider == "supabase" {
		return NewSupabaseEventRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey), nil
	}

	return nil, fmt.Errorf("unsupported data provider: %s", provider)
}

// NewCourseRepository creates a concrete CourseRepository based on config
func NewCourseRepository(cfg *config.Config) (CourseRepository, error) {
	provider := strings.ToLower(strings.TrimSpace(cfg.Server.DataProvider))
	if provider == "" {
		provider = "supabase" // default
	}

	// Supabase via PostgREST
	if provider == "supabase" {
		return NewSupabaseCourseRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey), nil
	}

	return nil, fmt.Errorf("unsupported data provider: %s", provider)
}

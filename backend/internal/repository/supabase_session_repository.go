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
	"time"

	"histeeria-backend/internal/models"
	apperr "histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// SupabaseSessionRepository implements SessionRepository for Supabase
type SupabaseSessionRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

// NewSupabaseSessionRepository creates a new Supabase session repository
func NewSupabaseSessionRepository(baseURL, apiKey string) *SupabaseSessionRepository {
	return &SupabaseSessionRepository{
		baseURL: baseURL,
		apiKey:  apiKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseSessionRepository) sessionsURL(query url.Values) string {
	u := fmt.Sprintf("%s/rest/v1/user_sessions", r.baseURL)
	if len(query) > 0 {
		u += "?" + query.Encode()
	}
	return u
}

func (r *SupabaseSessionRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

// CreateSession creates a new session
func (r *SupabaseSessionRepository) CreateSession(ctx context.Context, session *models.UserSession) error {
	sessionData := map[string]interface{}{
		"user_id":     session.UserID,
		"token_hash":  session.TokenHash,
		"device_info": session.DeviceInfo,
		"ip_address":  session.IPAddress,
		"user_agent":  session.UserAgent,
		"expires_at":  session.ExpiresAt,
		"created_at":  time.Now(),
	}

	body, err := json.Marshal(sessionData)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.sessionsURL(nil), bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=representation")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateSession failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	// Parse response to get created session with ID
	var sessions []models.UserSession
	if err := json.NewDecoder(resp.Body).Decode(&sessions); err != nil {
		return apperr.ErrDatabaseError
	}

	if len(sessions) > 0 {
		session.ID = sessions[0].ID
		session.CreatedAt = sessions[0].CreatedAt
	}

	return nil
}

// GetSessionByID retrieves a session by its ID
func (r *SupabaseSessionRepository) GetSessionByID(ctx context.Context, sessionID uuid.UUID) (*models.UserSession, error) {
	q := url.Values{}
	q.Set("id", "eq."+sessionID.String())
	q.Set("select", "*")

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.sessionsURL(q), nil)
	if err != nil {
		return nil, apperr.ErrInternalServer
	}

	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return nil, apperr.ErrDatabaseError
	}

	var sessions []models.UserSession
	if err := json.NewDecoder(resp.Body).Decode(&sessions); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(sessions) == 0 {
		return nil, apperr.NewAppError(404, "Session not found")
	}

	return &sessions[0], nil
}

// GetSessionsByUserID retrieves all sessions for a user
func (r *SupabaseSessionRepository) GetSessionsByUserID(ctx context.Context, userID uuid.UUID) ([]*models.UserSession, error) {
	q := url.Values{}
	q.Set("user_id", "eq."+userID.String())
	q.Set("select", "*")
	q.Set("order", "created_at.desc")

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.sessionsURL(q), nil)
	if err != nil {
		return nil, apperr.ErrInternalServer
	}

	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return nil, apperr.ErrDatabaseError
	}

	var sessions []models.UserSession
	if err := json.NewDecoder(resp.Body).Decode(&sessions); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	// Convert to pointer slice
	result := make([]*models.UserSession, len(sessions))
	for i := range sessions {
		result[i] = &sessions[i]
	}

	return result, nil
}

// GetSessionByTokenHash retrieves a session by token hash
func (r *SupabaseSessionRepository) GetSessionByTokenHash(ctx context.Context, tokenHash string) (*models.UserSession, error) {
	q := url.Values{}
	q.Set("token_hash", "eq."+tokenHash)
	q.Set("select", "*")

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.sessionsURL(q), nil)
	if err != nil {
		return nil, apperr.ErrInternalServer
	}

	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return nil, apperr.ErrDatabaseError
	}

	var sessions []models.UserSession
	if err := json.NewDecoder(resp.Body).Decode(&sessions); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(sessions) == 0 {
		return nil, apperr.NewAppError(404, "Session not found")
	}

	return &sessions[0], nil
}

// DeleteSession deletes a specific session
func (r *SupabaseSessionRepository) DeleteSession(ctx context.Context, sessionID uuid.UUID) error {
	q := url.Values{}
	q.Set("id", "eq."+sessionID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, r.sessionsURL(q), nil)
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] DeleteSession failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// DeleteSessionByTokenHash deletes a session by token hash
func (r *SupabaseSessionRepository) DeleteSessionByTokenHash(ctx context.Context, tokenHash string) error {
	q := url.Values{}
	q.Set("token_hash", "eq."+tokenHash)

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, r.sessionsURL(q), nil)
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] DeleteSessionByTokenHash failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// DeleteAllUserSessions deletes all sessions for a user (optionally except current session)
func (r *SupabaseSessionRepository) DeleteAllUserSessions(ctx context.Context, userID uuid.UUID, exceptSessionID *uuid.UUID) error {
	q := url.Values{}
	q.Set("user_id", "eq."+userID.String())

	// If we want to keep the current session, exclude it
	if exceptSessionID != nil {
		q.Set("id", "neq."+exceptSessionID.String())
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, r.sessionsURL(q), nil)
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] DeleteAllUserSessions failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// CleanupExpiredSessions removes expired sessions
func (r *SupabaseSessionRepository) CleanupExpiredSessions(ctx context.Context) error {
	q := url.Values{}
	q.Set("expires_at", "lt."+time.Now().Format(time.RFC3339))

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, r.sessionsURL(q), nil)
	if err != nil {
		return apperr.ErrInternalServer
	}

	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CleanupExpiredSessions failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}


package repository

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"histeeria-backend/internal/models"
	apperr "histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// SupabaseExperienceRepository implements ExperienceRepository using Supabase PostgREST
type SupabaseExperienceRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabaseExperienceRepository(baseURL, serviceRoleKey string) *SupabaseExperienceRepository {
	return &SupabaseExperienceRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseExperienceRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseExperienceRepository) experiencesURL(q url.Values) string {
	u := r.baseURL + "/user_experiences"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseExperienceRepository) CreateExperience(ctx context.Context, exp *models.UserExperience) error {
	// Build creation map with properly formatted dates
	data := map[string]interface{}{
		"id":            exp.ID.String(),
		"user_id":       exp.UserID.String(),
		"company_name":  exp.CompanyName,
		"title":         exp.Title,
		"start_date":    exp.StartDate.Format("2006-01-02"),
		"is_current":    exp.IsCurrent,
		"is_public":     exp.IsPublic,
		"display_order": exp.DisplayOrder,
		"created_at":    exp.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
		"updated_at":    exp.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if exp.EmploymentType != nil {
		data["employment_type"] = *exp.EmploymentType
	}

	if exp.EndDate != nil {
		data["end_date"] = exp.EndDate.Format("2006-01-02")
	}

	if exp.Description != nil {
		data["description"] = *exp.Description
	}

	body, err := json.Marshal(data)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.experiencesURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateExperience failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

func (r *SupabaseExperienceRepository) GetExperienceByID(ctx context.Context, id uuid.UUID) (*models.UserExperience, error) {
	q := url.Values{}
	q.Set("id", "eq."+id.String())
	q.Set("limit", "1")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.experiencesURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, apperr.ErrUserNotFound
	}

	// Read body first
	bodyBytes, _ := io.ReadAll(resp.Body)

	// Parse manually to handle date fields
	var rawExperiences []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &rawExperiences); err != nil {
		log.Printf("[Supabase] GetExperienceByID unmarshal failed: %v", err)
		return nil, apperr.ErrDatabaseError
	}

	if len(rawExperiences) == 0 {
		return nil, apperr.ErrUserNotFound
	}

	raw := rawExperiences[0]
	exp := &models.UserExperience{}

	if idStr, ok := raw["id"].(string); ok {
		exp.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		exp.UserID, _ = uuid.Parse(userIDStr)
	}
	if companyName, ok := raw["company_name"].(string); ok {
		exp.CompanyName = companyName
	}
	if title, ok := raw["title"].(string); ok {
		exp.Title = title
	}
	if employmentType, ok := raw["employment_type"].(string); ok && employmentType != "" {
		exp.EmploymentType = &employmentType
	}
	if isCurrent, ok := raw["is_current"].(bool); ok {
		exp.IsCurrent = isCurrent
	}
	if isPublic, ok := raw["is_public"].(bool); ok {
		exp.IsPublic = isPublic
	}
	if description, ok := raw["description"].(string); ok && description != "" {
		exp.Description = &description
	}
	if displayOrder, ok := raw["display_order"].(float64); ok {
		exp.DisplayOrder = int(displayOrder)
	}

	// Parse dates (DATE format: "2024-01-15")
	if startDateStr, ok := raw["start_date"].(string); ok {
		if t, err := time.Parse("2006-01-02", startDateStr); err == nil {
			exp.StartDate = t
		}
	}
	if endDateStr, ok := raw["end_date"].(string); ok && endDateStr != "" {
		if t, err := time.Parse("2006-01-02", endDateStr); err == nil {
			exp.EndDate = &t
		}
	}
	if createdAtStr, ok := raw["created_at"].(string); ok {
		if t := parseFlexibleTime(createdAtStr); !t.IsZero() {
			exp.CreatedAt = t
		}
	}
	if updatedAtStr, ok := raw["updated_at"].(string); ok {
		if t := parseFlexibleTime(updatedAtStr); !t.IsZero() {
			exp.UpdatedAt = t
		}
	}

	return exp, nil
}

func (r *SupabaseExperienceRepository) GetUserExperiences(ctx context.Context, userID uuid.UUID) ([]*models.UserExperience, error) {
	q := url.Values{}
	q.Set("user_id", "eq."+userID.String())
	q.Set("order", "display_order.desc,start_date.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.experiencesURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		log.Printf("[Supabase] GetUserExperiences request failed: %v", err)
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] GetUserExperiences failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		// If table doesn't exist, return empty array instead of error
		if resp.StatusCode == 404 || resp.StatusCode == 400 {
			return []*models.UserExperience{}, nil
		}
		return nil, apperr.ErrDatabaseError
	}

	// Read body first
	bodyBytes, _ := io.ReadAll(resp.Body)

	// Parse manually to handle date fields
	var rawExperiences []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &rawExperiences); err != nil {
		log.Printf("[Supabase] GetUserExperiences unmarshal failed: %v", err)
		return nil, apperr.ErrDatabaseError
	}

	experiences := make([]*models.UserExperience, 0, len(rawExperiences))
	for _, raw := range rawExperiences {
		exp := &models.UserExperience{}

		if idStr, ok := raw["id"].(string); ok {
			exp.ID, _ = uuid.Parse(idStr)
		}
		if userIDStr, ok := raw["user_id"].(string); ok {
			exp.UserID, _ = uuid.Parse(userIDStr)
		}
		if companyName, ok := raw["company_name"].(string); ok {
			exp.CompanyName = companyName
		}
		if title, ok := raw["title"].(string); ok {
			exp.Title = title
		}
		if employmentType, ok := raw["employment_type"].(string); ok && employmentType != "" {
			exp.EmploymentType = &employmentType
		}
		if isCurrent, ok := raw["is_current"].(bool); ok {
			exp.IsCurrent = isCurrent
		}
		if isPublic, ok := raw["is_public"].(bool); ok {
			exp.IsPublic = isPublic
		}
		if description, ok := raw["description"].(string); ok && description != "" {
			exp.Description = &description
		}
		if displayOrder, ok := raw["display_order"].(float64); ok {
			exp.DisplayOrder = int(displayOrder)
		}

		// Parse dates (DATE format: "2024-01-15")
		if startDateStr, ok := raw["start_date"].(string); ok {
			if t, err := time.Parse("2006-01-02", startDateStr); err == nil {
				exp.StartDate = t
			}
		}
		if endDateStr, ok := raw["end_date"].(string); ok && endDateStr != "" {
			if t, err := time.Parse("2006-01-02", endDateStr); err == nil {
				exp.EndDate = &t
			}
		}
		if createdAtStr, ok := raw["created_at"].(string); ok {
			if t := parseFlexibleTime(createdAtStr); !t.IsZero() {
				exp.CreatedAt = t
			}
		}
		if updatedAtStr, ok := raw["updated_at"].(string); ok {
			if t := parseFlexibleTime(updatedAtStr); !t.IsZero() {
				exp.UpdatedAt = t
			}
		}

		experiences = append(experiences, exp)
	}

	return experiences, nil
}

func (r *SupabaseExperienceRepository) UpdateExperience(ctx context.Context, exp *models.UserExperience) error {
	// Build update map with only the fields to update
	update := map[string]interface{}{
		"company_name":  exp.CompanyName,
		"title":         exp.Title,
		"start_date":    exp.StartDate.Format("2006-01-02"),
		"is_current":    exp.IsCurrent,
		"is_public":     exp.IsPublic,
		"display_order": exp.DisplayOrder,
		"updated_at":    time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if exp.EmploymentType != nil {
		update["employment_type"] = *exp.EmploymentType
	} else {
		update["employment_type"] = nil
	}

	if exp.EndDate != nil {
		update["end_date"] = exp.EndDate.Format("2006-01-02")
	} else {
		update["end_date"] = nil
	}

	if exp.Description != nil {
		update["description"] = *exp.Description
	} else {
		update["description"] = nil
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+exp.ID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.experiencesURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateExperience failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

func (r *SupabaseExperienceRepository) DeleteExperience(ctx context.Context, id uuid.UUID) error {
	q := url.Values{}
	q.Set("id", "eq."+id.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.experiencesURL(q), nil)
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return apperr.ErrDatabaseError
	}

	return nil
}

// SupabaseEducationRepository implements EducationRepository using Supabase PostgREST
type SupabaseEducationRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabaseEducationRepository(baseURL, serviceRoleKey string) *SupabaseEducationRepository {
	return &SupabaseEducationRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseEducationRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseEducationRepository) educationURL(q url.Values) string {
	u := r.baseURL + "/user_education"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseEducationRepository) CreateEducation(ctx context.Context, edu *models.UserEducation) error {
	// Build creation map with properly formatted dates
	data := map[string]interface{}{
		"id":            edu.ID.String(),
		"user_id":       edu.UserID.String(),
		"school_name":   edu.SchoolName,
		"start_date":    edu.StartDate.Format("2006-01-02"),
		"is_current":    edu.IsCurrent,
		"display_order": edu.DisplayOrder,
		"created_at":    edu.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
		"updated_at":    edu.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if edu.Degree != nil {
		data["degree"] = *edu.Degree
	}

	if edu.FieldOfStudy != nil {
		data["field_of_study"] = *edu.FieldOfStudy
	}

	if edu.EndDate != nil {
		data["end_date"] = edu.EndDate.Format("2006-01-02")
	}

	if edu.Description != nil {
		data["description"] = *edu.Description
	}

	body, err := json.Marshal(data)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.educationURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateEducation failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

func (r *SupabaseEducationRepository) GetEducationByID(ctx context.Context, id uuid.UUID) (*models.UserEducation, error) {
	q := url.Values{}
	q.Set("id", "eq."+id.String())
	q.Set("limit", "1")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.educationURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, apperr.ErrUserNotFound
	}

	// Read body first
	bodyBytes, _ := io.ReadAll(resp.Body)

	// Parse manually to handle date fields
	var rawEducation []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &rawEducation); err != nil {
		log.Printf("[Supabase] GetEducationByID unmarshal failed: %v", err)
		return nil, apperr.ErrDatabaseError
	}

	if len(rawEducation) == 0 {
		return nil, apperr.ErrUserNotFound
	}

	raw := rawEducation[0]
	edu := &models.UserEducation{}

	if idStr, ok := raw["id"].(string); ok {
		edu.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		edu.UserID, _ = uuid.Parse(userIDStr)
	}
	if schoolName, ok := raw["school_name"].(string); ok {
		edu.SchoolName = schoolName
	}
	if degree, ok := raw["degree"].(string); ok && degree != "" {
		edu.Degree = &degree
	}
	if fieldOfStudy, ok := raw["field_of_study"].(string); ok && fieldOfStudy != "" {
		edu.FieldOfStudy = &fieldOfStudy
	}
	if isCurrent, ok := raw["is_current"].(bool); ok {
		edu.IsCurrent = isCurrent
	}
	if description, ok := raw["description"].(string); ok && description != "" {
		edu.Description = &description
	}
	if displayOrder, ok := raw["display_order"].(float64); ok {
		edu.DisplayOrder = int(displayOrder)
	}

	// Parse dates (DATE format: "2024-01-15")
	if startDateStr, ok := raw["start_date"].(string); ok {
		if t, err := time.Parse("2006-01-02", startDateStr); err == nil {
			edu.StartDate = t
		}
	}
	if endDateStr, ok := raw["end_date"].(string); ok && endDateStr != "" {
		if t, err := time.Parse("2006-01-02", endDateStr); err == nil {
			edu.EndDate = &t
		}
	}
	if createdAtStr, ok := raw["created_at"].(string); ok {
		if t := parseFlexibleTime(createdAtStr); !t.IsZero() {
			edu.CreatedAt = t
		}
	}
	if updatedAtStr, ok := raw["updated_at"].(string); ok {
		if t := parseFlexibleTime(updatedAtStr); !t.IsZero() {
			edu.UpdatedAt = t
		}
	}

	return edu, nil
}

func (r *SupabaseEducationRepository) GetUserEducation(ctx context.Context, userID uuid.UUID) ([]*models.UserEducation, error) {
	q := url.Values{}
	q.Set("user_id", "eq."+userID.String())
	q.Set("order", "display_order.desc,start_date.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.educationURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		log.Printf("[Supabase] GetUserEducation request failed: %v", err)
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] GetUserEducation failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		// If table doesn't exist, return empty array instead of error
		if resp.StatusCode == 404 || resp.StatusCode == 400 {
			return []*models.UserEducation{}, nil
		}
		return nil, apperr.ErrDatabaseError
	}

	// Read body first
	bodyBytes, _ := io.ReadAll(resp.Body)

	// Parse manually to handle date fields
	var rawEducation []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &rawEducation); err != nil {
		log.Printf("[Supabase] GetUserEducation unmarshal failed: %v", err)
		return nil, apperr.ErrDatabaseError
	}

	education := make([]*models.UserEducation, 0, len(rawEducation))
	for _, raw := range rawEducation {
		edu := &models.UserEducation{}

		if idStr, ok := raw["id"].(string); ok {
			edu.ID, _ = uuid.Parse(idStr)
		}
		if userIDStr, ok := raw["user_id"].(string); ok {
			edu.UserID, _ = uuid.Parse(userIDStr)
		}
		if schoolName, ok := raw["school_name"].(string); ok {
			edu.SchoolName = schoolName
		}
		if degree, ok := raw["degree"].(string); ok && degree != "" {
			edu.Degree = &degree
		}
		if fieldOfStudy, ok := raw["field_of_study"].(string); ok && fieldOfStudy != "" {
			edu.FieldOfStudy = &fieldOfStudy
		}
		if isCurrent, ok := raw["is_current"].(bool); ok {
			edu.IsCurrent = isCurrent
		}
		if description, ok := raw["description"].(string); ok && description != "" {
			edu.Description = &description
		}
		if displayOrder, ok := raw["display_order"].(float64); ok {
			edu.DisplayOrder = int(displayOrder)
		}

		// Parse dates (DATE format: "2024-01-15")
		if startDateStr, ok := raw["start_date"].(string); ok {
			if t, err := time.Parse("2006-01-02", startDateStr); err == nil {
				edu.StartDate = t
			}
		}
		if endDateStr, ok := raw["end_date"].(string); ok && endDateStr != "" {
			if t, err := time.Parse("2006-01-02", endDateStr); err == nil {
				edu.EndDate = &t
			}
		}
		if createdAtStr, ok := raw["created_at"].(string); ok {
			if t := parseFlexibleTime(createdAtStr); !t.IsZero() {
				edu.CreatedAt = t
			}
		}
		if updatedAtStr, ok := raw["updated_at"].(string); ok {
			if t := parseFlexibleTime(updatedAtStr); !t.IsZero() {
				edu.UpdatedAt = t
			}
		}

		education = append(education, edu)
	}

	return education, nil
}

func (r *SupabaseEducationRepository) UpdateEducation(ctx context.Context, edu *models.UserEducation) error {
	// Build update map with only the fields to update
	update := map[string]interface{}{
		"school_name":   edu.SchoolName,
		"start_date":    edu.StartDate.Format("2006-01-02"),
		"is_current":    edu.IsCurrent,
		"display_order": edu.DisplayOrder,
		"updated_at":    time.Now().Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if edu.Degree != nil {
		update["degree"] = *edu.Degree
	} else {
		update["degree"] = nil
	}

	if edu.FieldOfStudy != nil {
		update["field_of_study"] = *edu.FieldOfStudy
	} else {
		update["field_of_study"] = nil
	}

	if edu.EndDate != nil {
		update["end_date"] = edu.EndDate.Format("2006-01-02")
	} else {
		update["end_date"] = nil
	}

	if edu.Description != nil {
		update["description"] = *edu.Description
	} else {
		update["description"] = nil
	}

	body, err := json.Marshal(update)
	if err != nil {
		return apperr.ErrInternalServer
	}

	q := url.Values{}
	q.Set("id", "eq."+edu.ID.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.educationURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateEducation failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

func (r *SupabaseEducationRepository) DeleteEducation(ctx context.Context, id uuid.UUID) error {
	q := url.Values{}
	q.Set("id", "eq."+id.String())

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.educationURL(q), nil)
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return apperr.ErrDatabaseError
	}

	return nil
}

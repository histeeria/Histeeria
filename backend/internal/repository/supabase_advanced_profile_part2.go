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
	apperr "histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// SupabaseLanguageRepository implements LanguageRepository
type SupabaseLanguageRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabaseLanguageRepository(baseURL, serviceRoleKey string) *SupabaseLanguageRepository {
	return &SupabaseLanguageRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseLanguageRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseLanguageRepository) languagesURL(q url.Values) string {
	u := r.baseURL + "/user_languages"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseLanguageRepository) CreateLanguage(ctx context.Context, lang *models.UserLanguage) error {
	data := map[string]interface{}{
		"id":            lang.ID.String(),
		"user_id":       lang.UserID.String(),
		"language_name": lang.LanguageName,
		"display_order": lang.DisplayOrder,
		"created_at":    lang.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if lang.ProficiencyLevel != nil {
		data["proficiency_level"] = *lang.ProficiencyLevel
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.languagesURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateLanguage failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabaseLanguageRepository) GetLanguageByID(ctx context.Context, id uuid.UUID) (*models.UserLanguage, error) {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))
	q.Set("select", "*")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.languagesURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return nil, apperr.ErrDatabaseError
	}

	var langs []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &langs); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(langs) == 0 {
		return nil, apperr.New(404, "Resource not found")
	}

	return r.parseLanguage(langs[0])
}

func (r *SupabaseLanguageRepository) GetUserLanguages(ctx context.Context, userID uuid.UUID) ([]*models.UserLanguage, error) {
	q := url.Values{}
	q.Set("user_id", fmt.Sprintf("eq.%s", userID.String()))
	q.Set("select", "*")
	q.Set("order", "display_order.desc,created_at.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.languagesURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		if resp.StatusCode == 404 {
			return []*models.UserLanguage{}, nil
		}
		return nil, apperr.ErrDatabaseError
	}

	var raw []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &raw); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	langs := make([]*models.UserLanguage, 0, len(raw))
	for _, rawItem := range raw {
		lang, err := r.parseLanguage(rawItem)
		if err != nil {
			continue
		}
		langs = append(langs, lang)
	}

	return langs, nil
}

func (r *SupabaseLanguageRepository) parseLanguage(raw map[string]interface{}) (*models.UserLanguage, error) {
	lang := &models.UserLanguage{}
	if idStr, ok := raw["id"].(string); ok {
		lang.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		lang.UserID, _ = uuid.Parse(userIDStr)
	}
	if name, ok := raw["language_name"].(string); ok {
		lang.LanguageName = name
	}
	if level, ok := raw["proficiency_level"].(string); ok && level != "" {
		lang.ProficiencyLevel = &level
	}
	if order, ok := raw["display_order"].(float64); ok {
		lang.DisplayOrder = int(order)
	}
	if createdAt, ok := raw["created_at"].(string); ok {
		lang.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	return lang, nil
}

func (r *SupabaseLanguageRepository) UpdateLanguage(ctx context.Context, lang *models.UserLanguage) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", lang.ID.String()))

	data := map[string]interface{}{
		"language_name": lang.LanguageName,
		"display_order": lang.DisplayOrder,
	}

	if lang.ProficiencyLevel != nil {
		data["proficiency_level"] = *lang.ProficiencyLevel
	} else {
		data["proficiency_level"] = nil
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.languagesURL(q), bytes.NewReader(body))
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

func (r *SupabaseLanguageRepository) DeleteLanguage(ctx context.Context, id uuid.UUID) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.languagesURL(q), nil)
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

// SupabaseVolunteeringRepository implements VolunteeringRepository
type SupabaseVolunteeringRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabaseVolunteeringRepository(baseURL, serviceRoleKey string) *SupabaseVolunteeringRepository {
	return &SupabaseVolunteeringRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseVolunteeringRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseVolunteeringRepository) volunteeringURL(q url.Values) string {
	u := r.baseURL + "/user_volunteering"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseVolunteeringRepository) CreateVolunteering(ctx context.Context, vol *models.UserVolunteering) error {
	data := map[string]interface{}{
		"id":                vol.ID.String(),
		"user_id":           vol.UserID.String(),
		"organization_name": vol.OrganizationName,
		"role":              vol.Role,
		"start_date":        vol.StartDate.Format("2006-01-02"),
		"is_current":        vol.IsCurrent,
		"display_order":     vol.DisplayOrder,
		"created_at":        vol.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
		"updated_at":        vol.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if vol.EndDate != nil {
		data["end_date"] = vol.EndDate.Format("2006-01-02")
	}
	if vol.Description != nil {
		data["description"] = *vol.Description
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.volunteeringURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateVolunteering failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabaseVolunteeringRepository) GetVolunteeringByID(ctx context.Context, id uuid.UUID) (*models.UserVolunteering, error) {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))
	q.Set("select", "*")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.volunteeringURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return nil, apperr.ErrDatabaseError
	}

	var vols []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &vols); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(vols) == 0 {
		return nil, apperr.New(404, "Resource not found")
	}

	return r.parseVolunteering(vols[0])
}

func (r *SupabaseVolunteeringRepository) GetUserVolunteering(ctx context.Context, userID uuid.UUID) ([]*models.UserVolunteering, error) {
	q := url.Values{}
	q.Set("user_id", fmt.Sprintf("eq.%s", userID.String()))
	q.Set("select", "*")
	q.Set("order", "display_order.desc,created_at.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.volunteeringURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		if resp.StatusCode == 404 {
			return []*models.UserVolunteering{}, nil
		}
		return nil, apperr.ErrDatabaseError
	}

	var raw []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &raw); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	vols := make([]*models.UserVolunteering, 0, len(raw))
	for _, rawItem := range raw {
		vol, err := r.parseVolunteering(rawItem)
		if err != nil {
			continue
		}
		vols = append(vols, vol)
	}

	return vols, nil
}

func (r *SupabaseVolunteeringRepository) parseVolunteering(raw map[string]interface{}) (*models.UserVolunteering, error) {
	vol := &models.UserVolunteering{}
	if idStr, ok := raw["id"].(string); ok {
		vol.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		vol.UserID, _ = uuid.Parse(userIDStr)
	}
	if org, ok := raw["organization_name"].(string); ok {
		vol.OrganizationName = org
	}
	if role, ok := raw["role"].(string); ok {
		vol.Role = role
	}
	if startDate, ok := raw["start_date"].(string); ok {
		vol.StartDate, _ = time.Parse("2006-01-02", startDate)
	}
	if endDate, ok := raw["end_date"].(string); ok && endDate != "" {
		parsed, _ := time.Parse("2006-01-02", endDate)
		vol.EndDate = &parsed
	}
	if isCurrent, ok := raw["is_current"].(bool); ok {
		vol.IsCurrent = isCurrent
	}
	if desc, ok := raw["description"].(string); ok && desc != "" {
		vol.Description = &desc
	}
	if order, ok := raw["display_order"].(float64); ok {
		vol.DisplayOrder = int(order)
	}
	if createdAt, ok := raw["created_at"].(string); ok {
		vol.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	if updatedAt, ok := raw["updated_at"].(string); ok {
		vol.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	}
	return vol, nil
}

func (r *SupabaseVolunteeringRepository) UpdateVolunteering(ctx context.Context, vol *models.UserVolunteering) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", vol.ID.String()))

	data := map[string]interface{}{
		"organization_name": vol.OrganizationName,
		"role":              vol.Role,
		"start_date":        vol.StartDate.Format("2006-01-02"),
		"is_current":        vol.IsCurrent,
		"display_order":     vol.DisplayOrder,
		"updated_at":        vol.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if vol.EndDate != nil {
		data["end_date"] = vol.EndDate.Format("2006-01-02")
	} else {
		data["end_date"] = nil
	}
	if vol.Description != nil {
		data["description"] = *vol.Description
	} else {
		data["description"] = nil
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.volunteeringURL(q), bytes.NewReader(body))
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

func (r *SupabaseVolunteeringRepository) DeleteVolunteering(ctx context.Context, id uuid.UUID) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.volunteeringURL(q), nil)
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

// SupabasePublicationRepository implements PublicationRepository
type SupabasePublicationRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabasePublicationRepository(baseURL, serviceRoleKey string) *SupabasePublicationRepository {
	return &SupabasePublicationRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabasePublicationRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabasePublicationRepository) publicationsURL(q url.Values) string {
	u := r.baseURL + "/user_publications"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabasePublicationRepository) CreatePublication(ctx context.Context, pub *models.UserPublication) error {
	data := map[string]interface{}{
		"id":            pub.ID.String(),
		"user_id":       pub.UserID.String(),
		"title":         pub.Title,
		"display_order": pub.DisplayOrder,
		"created_at":    pub.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
		"updated_at":    pub.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if pub.PublicationType != nil {
		data["publication_type"] = *pub.PublicationType
	}
	if pub.Publisher != nil {
		data["publisher"] = *pub.Publisher
	}
	if pub.PublicationDate != nil {
		data["publication_date"] = pub.PublicationDate.Format("2006-01-02")
	}
	if pub.PublicationURL != nil {
		data["publication_url"] = *pub.PublicationURL
	}
	if pub.Description != nil {
		data["description"] = *pub.Description
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.publicationsURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreatePublication failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabasePublicationRepository) GetPublicationByID(ctx context.Context, id uuid.UUID) (*models.UserPublication, error) {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))
	q.Set("select", "*")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.publicationsURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return nil, apperr.ErrDatabaseError
	}

	var pubs []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &pubs); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(pubs) == 0 {
		return nil, apperr.New(404, "Resource not found")
	}

	return r.parsePublication(pubs[0])
}

func (r *SupabasePublicationRepository) GetUserPublications(ctx context.Context, userID uuid.UUID) ([]*models.UserPublication, error) {
	q := url.Values{}
	q.Set("user_id", fmt.Sprintf("eq.%s", userID.String()))
	q.Set("select", "*")
	q.Set("order", "display_order.desc,created_at.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.publicationsURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		if resp.StatusCode == 404 {
			return []*models.UserPublication{}, nil
		}
		return nil, apperr.ErrDatabaseError
	}

	var raw []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &raw); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	pubs := make([]*models.UserPublication, 0, len(raw))
	for _, rawItem := range raw {
		pub, err := r.parsePublication(rawItem)
		if err != nil {
			continue
		}
		pubs = append(pubs, pub)
	}

	return pubs, nil
}

func (r *SupabasePublicationRepository) parsePublication(raw map[string]interface{}) (*models.UserPublication, error) {
	pub := &models.UserPublication{}
	if idStr, ok := raw["id"].(string); ok {
		pub.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		pub.UserID, _ = uuid.Parse(userIDStr)
	}
	if title, ok := raw["title"].(string); ok {
		pub.Title = title
	}
	if pubType, ok := raw["publication_type"].(string); ok && pubType != "" {
		pub.PublicationType = &pubType
	}
	if publisher, ok := raw["publisher"].(string); ok && publisher != "" {
		pub.Publisher = &publisher
	}
	if pubDate, ok := raw["publication_date"].(string); ok && pubDate != "" {
		parsed, _ := time.Parse("2006-01-02", pubDate)
		pub.PublicationDate = &parsed
	}
	if pubURL, ok := raw["publication_url"].(string); ok && pubURL != "" {
		pub.PublicationURL = &pubURL
	}
	if desc, ok := raw["description"].(string); ok && desc != "" {
		pub.Description = &desc
	}
	if order, ok := raw["display_order"].(float64); ok {
		pub.DisplayOrder = int(order)
	}
	if createdAt, ok := raw["created_at"].(string); ok {
		pub.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	if updatedAt, ok := raw["updated_at"].(string); ok {
		pub.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	}
	return pub, nil
}

func (r *SupabasePublicationRepository) UpdatePublication(ctx context.Context, pub *models.UserPublication) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", pub.ID.String()))

	data := map[string]interface{}{
		"title":         pub.Title,
		"display_order": pub.DisplayOrder,
		"updated_at":    pub.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if pub.PublicationType != nil {
		data["publication_type"] = *pub.PublicationType
	} else {
		data["publication_type"] = nil
	}
	if pub.Publisher != nil {
		data["publisher"] = *pub.Publisher
	} else {
		data["publisher"] = nil
	}
	if pub.PublicationDate != nil {
		data["publication_date"] = pub.PublicationDate.Format("2006-01-02")
	} else {
		data["publication_date"] = nil
	}
	if pub.PublicationURL != nil {
		data["publication_url"] = *pub.PublicationURL
	} else {
		data["publication_url"] = nil
	}
	if pub.Description != nil {
		data["description"] = *pub.Description
	} else {
		data["description"] = nil
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.publicationsURL(q), bytes.NewReader(body))
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

func (r *SupabasePublicationRepository) DeletePublication(ctx context.Context, id uuid.UUID) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.publicationsURL(q), nil)
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

// SupabaseInterestRepository implements InterestRepository
type SupabaseInterestRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabaseInterestRepository(baseURL, serviceRoleKey string) *SupabaseInterestRepository {
	return &SupabaseInterestRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseInterestRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseInterestRepository) interestsURL(q url.Values) string {
	u := r.baseURL + "/user_interests"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseInterestRepository) CreateInterest(ctx context.Context, interest *models.UserInterest) error {
	data := map[string]interface{}{
		"id":            interest.ID.String(),
		"user_id":       interest.UserID.String(),
		"interest_name": interest.InterestName,
		"display_order": interest.DisplayOrder,
		"created_at":    interest.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if interest.Category != nil {
		data["category"] = *interest.Category
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.interestsURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateInterest failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabaseInterestRepository) GetInterestByID(ctx context.Context, id uuid.UUID) (*models.UserInterest, error) {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))
	q.Set("select", "*")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.interestsURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return nil, apperr.ErrDatabaseError
	}

	var interests []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &interests); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(interests) == 0 {
		return nil, apperr.New(404, "Resource not found")
	}

	return r.parseInterest(interests[0])
}

func (r *SupabaseInterestRepository) GetUserInterests(ctx context.Context, userID uuid.UUID) ([]*models.UserInterest, error) {
	q := url.Values{}
	q.Set("user_id", fmt.Sprintf("eq.%s", userID.String()))
	q.Set("select", "*")
	q.Set("order", "display_order.desc,created_at.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.interestsURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		if resp.StatusCode == 404 {
			return []*models.UserInterest{}, nil
		}
		return nil, apperr.ErrDatabaseError
	}

	var raw []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &raw); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	interests := make([]*models.UserInterest, 0, len(raw))
	for _, rawItem := range raw {
		interest, err := r.parseInterest(rawItem)
		if err != nil {
			continue
		}
		interests = append(interests, interest)
	}

	return interests, nil
}

func (r *SupabaseInterestRepository) parseInterest(raw map[string]interface{}) (*models.UserInterest, error) {
	interest := &models.UserInterest{}
	if idStr, ok := raw["id"].(string); ok {
		interest.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		interest.UserID, _ = uuid.Parse(userIDStr)
	}
	if name, ok := raw["interest_name"].(string); ok {
		interest.InterestName = name
	}
	if cat, ok := raw["category"].(string); ok && cat != "" {
		interest.Category = &cat
	}
	if order, ok := raw["display_order"].(float64); ok {
		interest.DisplayOrder = int(order)
	}
	if createdAt, ok := raw["created_at"].(string); ok {
		interest.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	return interest, nil
}

func (r *SupabaseInterestRepository) UpdateInterest(ctx context.Context, interest *models.UserInterest) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", interest.ID.String()))

	data := map[string]interface{}{
		"interest_name": interest.InterestName,
		"display_order": interest.DisplayOrder,
	}

	if interest.Category != nil {
		data["category"] = *interest.Category
	} else {
		data["category"] = nil
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.interestsURL(q), bytes.NewReader(body))
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

func (r *SupabaseInterestRepository) DeleteInterest(ctx context.Context, id uuid.UUID) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.interestsURL(q), nil)
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

// SupabaseAchievementRepository implements AchievementRepository
type SupabaseAchievementRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabaseAchievementRepository(baseURL, serviceRoleKey string) *SupabaseAchievementRepository {
	return &SupabaseAchievementRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseAchievementRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseAchievementRepository) achievementsURL(q url.Values) string {
	u := r.baseURL + "/user_achievements"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseAchievementRepository) CreateAchievement(ctx context.Context, achievement *models.UserAchievement) error {
	data := map[string]interface{}{
		"id":            achievement.ID.String(),
		"user_id":       achievement.UserID.String(),
		"title":         achievement.Title,
		"display_order": achievement.DisplayOrder,
		"created_at":    achievement.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
		"updated_at":    achievement.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if achievement.AchievementType != nil {
		data["achievement_type"] = *achievement.AchievementType
	}
	if achievement.IssuingOrganization != nil {
		data["issuing_organization"] = *achievement.IssuingOrganization
	}
	if achievement.AchievementDate != nil {
		data["achievement_date"] = achievement.AchievementDate.Format("2006-01-02")
	}
	if achievement.Description != nil {
		data["description"] = *achievement.Description
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.achievementsURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateAchievement failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}
	return nil
}

func (r *SupabaseAchievementRepository) GetAchievementByID(ctx context.Context, id uuid.UUID) (*models.UserAchievement, error) {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))
	q.Set("select", "*")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.achievementsURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return nil, apperr.ErrDatabaseError
	}

	var achievements []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &achievements); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(achievements) == 0 {
		return nil, apperr.New(404, "Resource not found")
	}

	return r.parseAchievement(achievements[0])
}

func (r *SupabaseAchievementRepository) GetUserAchievements(ctx context.Context, userID uuid.UUID) ([]*models.UserAchievement, error) {
	q := url.Values{}
	q.Set("user_id", fmt.Sprintf("eq.%s", userID.String()))
	q.Set("select", "*")
	q.Set("order", "display_order.desc,created_at.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.achievementsURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		if resp.StatusCode == 404 {
			return []*models.UserAchievement{}, nil
		}
		return nil, apperr.ErrDatabaseError
	}

	var raw []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &raw); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	achievements := make([]*models.UserAchievement, 0, len(raw))
	for _, rawItem := range raw {
		achievement, err := r.parseAchievement(rawItem)
		if err != nil {
			continue
		}
		achievements = append(achievements, achievement)
	}

	return achievements, nil
}

func (r *SupabaseAchievementRepository) parseAchievement(raw map[string]interface{}) (*models.UserAchievement, error) {
	achievement := &models.UserAchievement{}
	if idStr, ok := raw["id"].(string); ok {
		achievement.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		achievement.UserID, _ = uuid.Parse(userIDStr)
	}
	if title, ok := raw["title"].(string); ok {
		achievement.Title = title
	}
	if aType, ok := raw["achievement_type"].(string); ok && aType != "" {
		achievement.AchievementType = &aType
	}
	if org, ok := raw["issuing_organization"].(string); ok && org != "" {
		achievement.IssuingOrganization = &org
	}
	if aDate, ok := raw["achievement_date"].(string); ok && aDate != "" {
		parsed, _ := time.Parse("2006-01-02", aDate)
		achievement.AchievementDate = &parsed
	}
	if desc, ok := raw["description"].(string); ok && desc != "" {
		achievement.Description = &desc
	}
	if order, ok := raw["display_order"].(float64); ok {
		achievement.DisplayOrder = int(order)
	}
	if createdAt, ok := raw["created_at"].(string); ok {
		achievement.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	if updatedAt, ok := raw["updated_at"].(string); ok {
		achievement.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	}
	return achievement, nil
}

func (r *SupabaseAchievementRepository) UpdateAchievement(ctx context.Context, achievement *models.UserAchievement) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", achievement.ID.String()))

	data := map[string]interface{}{
		"title":         achievement.Title,
		"display_order": achievement.DisplayOrder,
		"updated_at":    achievement.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if achievement.AchievementType != nil {
		data["achievement_type"] = *achievement.AchievementType
	} else {
		data["achievement_type"] = nil
	}
	if achievement.IssuingOrganization != nil {
		data["issuing_organization"] = *achievement.IssuingOrganization
	} else {
		data["issuing_organization"] = nil
	}
	if achievement.AchievementDate != nil {
		data["achievement_date"] = achievement.AchievementDate.Format("2006-01-02")
	} else {
		data["achievement_date"] = nil
	}
	if achievement.Description != nil {
		data["description"] = *achievement.Description
	} else {
		data["description"] = nil
	}

	body, _ := json.Marshal(data)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.achievementsURL(q), bytes.NewReader(body))
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

func (r *SupabaseAchievementRepository) DeleteAchievement(ctx context.Context, id uuid.UUID) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.achievementsURL(q), nil)
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

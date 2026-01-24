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

// SupabaseCompanyRepository implements CompanyRepository using Supabase PostgREST
type SupabaseCompanyRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabaseCompanyRepository(baseURL, serviceRoleKey string) *SupabaseCompanyRepository {
	return &SupabaseCompanyRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseCompanyRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseCompanyRepository) companiesURL(q url.Values) string {
	u := r.baseURL + "/companies"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseCompanyRepository) CreateCompany(ctx context.Context, company *models.Company) error {
	data := map[string]interface{}{
		"id":         company.ID.String(),
		"name":       company.Name,
		"created_at": company.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
		"updated_at": company.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if company.LogoURL != nil {
		data["logo_url"] = *company.LogoURL
	}
	if company.Website != nil {
		data["website"] = *company.Website
	}
	if company.Industry != nil {
		data["industry"] = *company.Industry
	}

	body, err := json.Marshal(data)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.companiesURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateCompany failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

func (r *SupabaseCompanyRepository) GetCompanyByID(ctx context.Context, id uuid.UUID) (*models.Company, error) {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))
	q.Set("select", "*")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.companiesURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		log.Printf("[Supabase] GetCompanyByID failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return nil, apperr.ErrDatabaseError
	}

	var companies []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &companies); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(companies) == 0 {
		return nil, apperr.New(404, "Resource not found")
	}

	raw := companies[0]
	company := &models.Company{}
	if idStr, ok := raw["id"].(string); ok {
		company.ID, _ = uuid.Parse(idStr)
	}
	if name, ok := raw["name"].(string); ok {
		company.Name = name
	}
	if logoURL, ok := raw["logo_url"].(string); ok && logoURL != "" {
		company.LogoURL = &logoURL
	}
	if website, ok := raw["website"].(string); ok && website != "" {
		company.Website = &website
	}
	if industry, ok := raw["industry"].(string); ok && industry != "" {
		company.Industry = &industry
	}
	if createdAt, ok := raw["created_at"].(string); ok {
		company.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	if updatedAt, ok := raw["updated_at"].(string); ok {
		company.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	}

	return company, nil
}

func (r *SupabaseCompanyRepository) GetCompanyByName(ctx context.Context, name string) (*models.Company, error) {
	q := url.Values{}
	q.Set("name", fmt.Sprintf("eq.%s", name))
	q.Set("select", "*")
	q.Set("limit", "1")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.companiesURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		log.Printf("[Supabase] GetCompanyByName failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return nil, apperr.ErrDatabaseError
	}

	var companies []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &companies); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(companies) == 0 {
		return nil, apperr.New(404, "Resource not found")
	}

	raw := companies[0]
	company := &models.Company{}
	if idStr, ok := raw["id"].(string); ok {
		company.ID, _ = uuid.Parse(idStr)
	}
	if name, ok := raw["name"].(string); ok {
		company.Name = name
	}
	if logoURL, ok := raw["logo_url"].(string); ok && logoURL != "" {
		company.LogoURL = &logoURL
	}
	if website, ok := raw["website"].(string); ok && website != "" {
		company.Website = &website
	}
	if industry, ok := raw["industry"].(string); ok && industry != "" {
		company.Industry = &industry
	}
	if createdAt, ok := raw["created_at"].(string); ok {
		company.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	if updatedAt, ok := raw["updated_at"].(string); ok {
		company.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	}

	return company, nil
}

func (r *SupabaseCompanyRepository) SearchCompanies(ctx context.Context, query string, limit int) ([]*models.Company, error) {
	q := url.Values{}
	q.Set("name", fmt.Sprintf("ilike.%s%%", query))
	q.Set("select", "*")
	q.Set("order", "name.asc")
	q.Set("limit", fmt.Sprintf("%d", limit))

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.companiesURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		log.Printf("[Supabase] SearchCompanies failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return nil, apperr.ErrDatabaseError
	}

	var rawCompanies []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &rawCompanies); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	companies := make([]*models.Company, 0, len(rawCompanies))
	for _, raw := range rawCompanies {
		company := &models.Company{}
		if idStr, ok := raw["id"].(string); ok {
			company.ID, _ = uuid.Parse(idStr)
		}
		if name, ok := raw["name"].(string); ok {
			company.Name = name
		}
		if logoURL, ok := raw["logo_url"].(string); ok && logoURL != "" {
			company.LogoURL = &logoURL
		}
		if website, ok := raw["website"].(string); ok && website != "" {
			company.Website = &website
		}
		if industry, ok := raw["industry"].(string); ok && industry != "" {
			company.Industry = &industry
		}
		if createdAt, ok := raw["created_at"].(string); ok {
			company.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
		}
		if updatedAt, ok := raw["updated_at"].(string); ok {
			company.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
		}
		companies = append(companies, company)
	}

	return companies, nil
}

func (r *SupabaseCompanyRepository) UpdateCompany(ctx context.Context, company *models.Company) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", company.ID.String()))

	data := map[string]interface{}{
		"name":       company.Name,
		"updated_at": company.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if company.LogoURL != nil {
		data["logo_url"] = *company.LogoURL
	} else {
		data["logo_url"] = nil
	}
	if company.Website != nil {
		data["website"] = *company.Website
	} else {
		data["website"] = nil
	}
	if company.Industry != nil {
		data["industry"] = *company.Industry
	} else {
		data["industry"] = nil
	}

	body, err := json.Marshal(data)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.companiesURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateCompany failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// SupabaseCertificationRepository implements CertificationRepository
type SupabaseCertificationRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabaseCertificationRepository(baseURL, serviceRoleKey string) *SupabaseCertificationRepository {
	return &SupabaseCertificationRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseCertificationRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseCertificationRepository) certificationsURL(q url.Values) string {
	u := r.baseURL + "/user_certifications"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseCertificationRepository) CreateCertification(ctx context.Context, cert *models.UserCertification) error {
	data := map[string]interface{}{
		"id":            cert.ID.String(),
		"user_id":       cert.UserID.String(),
		"name":          cert.Name,
		"issue_date":    cert.IssueDate.Format("2006-01-02"),
		"display_order": cert.DisplayOrder,
		"created_at":    cert.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
		"updated_at":    cert.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if cert.IssuingOrganization != nil {
		data["issuing_organization"] = *cert.IssuingOrganization
	}
	if cert.ExpirationDate != nil {
		data["expiration_date"] = cert.ExpirationDate.Format("2006-01-02")
	}
	if cert.CredentialID != nil {
		data["credential_id"] = *cert.CredentialID
	}
	if cert.CredentialURL != nil {
		data["credential_url"] = *cert.CredentialURL
	}
	if cert.Description != nil {
		data["description"] = *cert.Description
	}

	body, err := json.Marshal(data)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.certificationsURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateCertification failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

func (r *SupabaseCertificationRepository) GetCertificationByID(ctx context.Context, id uuid.UUID) (*models.UserCertification, error) {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))
	q.Set("select", "*")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.certificationsURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		log.Printf("[Supabase] GetCertificationByID failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return nil, apperr.ErrDatabaseError
	}

	var certs []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &certs); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(certs) == 0 {
		return nil, apperr.New(404, "Certification not found")
	}

	return r.parseCertification(certs[0])
}

func (r *SupabaseCertificationRepository) GetUserCertifications(ctx context.Context, userID uuid.UUID) ([]*models.UserCertification, error) {
	q := url.Values{}
	q.Set("user_id", fmt.Sprintf("eq.%s", userID.String()))
	q.Set("select", "*")
	q.Set("order", "display_order.desc,created_at.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.certificationsURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		log.Printf("[Supabase] GetUserCertifications failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		if resp.StatusCode == 404 {
			return []*models.UserCertification{}, nil
		}
		return nil, apperr.ErrDatabaseError
	}

	var rawCerts []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &rawCerts); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	certs := make([]*models.UserCertification, 0, len(rawCerts))
	for _, raw := range rawCerts {
		cert, err := r.parseCertification(raw)
		if err != nil {
			continue
		}
		certs = append(certs, cert)
	}

	return certs, nil
}

func (r *SupabaseCertificationRepository) parseCertification(raw map[string]interface{}) (*models.UserCertification, error) {
	cert := &models.UserCertification{}
	if idStr, ok := raw["id"].(string); ok {
		cert.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		cert.UserID, _ = uuid.Parse(userIDStr)
	}
	if name, ok := raw["name"].(string); ok {
		cert.Name = name
	}
	if org, ok := raw["issuing_organization"].(string); ok && org != "" {
		cert.IssuingOrganization = &org
	}
	if issueDate, ok := raw["issue_date"].(string); ok {
		cert.IssueDate, _ = time.Parse("2006-01-02", issueDate)
	}
	if expDate, ok := raw["expiration_date"].(string); ok && expDate != "" {
		parsed, _ := time.Parse("2006-01-02", expDate)
		cert.ExpirationDate = &parsed
	}
	if credID, ok := raw["credential_id"].(string); ok && credID != "" {
		cert.CredentialID = &credID
	}
	if credURL, ok := raw["credential_url"].(string); ok && credURL != "" {
		cert.CredentialURL = &credURL
	}
	if desc, ok := raw["description"].(string); ok && desc != "" {
		cert.Description = &desc
	}
	if order, ok := raw["display_order"].(float64); ok {
		cert.DisplayOrder = int(order)
	}
	if createdAt, ok := raw["created_at"].(string); ok {
		cert.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	if updatedAt, ok := raw["updated_at"].(string); ok {
		cert.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	}
	return cert, nil
}

func (r *SupabaseCertificationRepository) UpdateCertification(ctx context.Context, cert *models.UserCertification) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", cert.ID.String()))

	data := map[string]interface{}{
		"name":          cert.Name,
		"issue_date":    cert.IssueDate.Format("2006-01-02"),
		"display_order": cert.DisplayOrder,
		"updated_at":    cert.UpdatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if cert.IssuingOrganization != nil {
		data["issuing_organization"] = *cert.IssuingOrganization
	} else {
		data["issuing_organization"] = nil
	}
	if cert.ExpirationDate != nil {
		data["expiration_date"] = cert.ExpirationDate.Format("2006-01-02")
	} else {
		data["expiration_date"] = nil
	}
	if cert.CredentialID != nil {
		data["credential_id"] = *cert.CredentialID
	} else {
		data["credential_id"] = nil
	}
	if cert.CredentialURL != nil {
		data["credential_url"] = *cert.CredentialURL
	} else {
		data["credential_url"] = nil
	}
	if cert.Description != nil {
		data["description"] = *cert.Description
	} else {
		data["description"] = nil
	}

	body, err := json.Marshal(data)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.certificationsURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateCertification failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

func (r *SupabaseCertificationRepository) DeleteCertification(ctx context.Context, id uuid.UUID) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.certificationsURL(q), nil)
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] DeleteCertification failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// Similar implementations for Skills, Languages, Volunteering, Publications, Interests, Achievements
// Following the same pattern as Certifications above

// SupabaseSkillRepository implements SkillRepository
type SupabaseSkillRepository struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

func NewSupabaseSkillRepository(baseURL, serviceRoleKey string) *SupabaseSkillRepository {
	return &SupabaseSkillRepository{
		baseURL: strings.TrimRight(baseURL, "/") + "/rest/v1",
		apiKey:  serviceRoleKey,
		http:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *SupabaseSkillRepository) setHeaders(req *http.Request, prefer string) {
	req.Header.Set("apikey", r.apiKey)
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
}

func (r *SupabaseSkillRepository) skillsURL(q url.Values) string {
	u := r.baseURL + "/user_skills"
	if q != nil {
		return u + "?" + q.Encode()
	}
	return u
}

func (r *SupabaseSkillRepository) CreateSkill(ctx context.Context, skill *models.UserSkill) error {
	data := map[string]interface{}{
		"id":            skill.ID.String(),
		"user_id":       skill.UserID.String(),
		"skill_name":    skill.SkillName,
		"display_order": skill.DisplayOrder,
		"created_at":    skill.CreatedAt.Format("2006-01-02T15:04:05.999999999Z07:00"),
	}

	if skill.ProficiencyLevel != nil {
		data["proficiency_level"] = *skill.ProficiencyLevel
	}
	if skill.Category != nil {
		data["category"] = *skill.Category
	}

	body, err := json.Marshal(data)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, r.skillsURL(nil), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] CreateSkill failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

func (r *SupabaseSkillRepository) GetSkillByID(ctx context.Context, id uuid.UUID) (*models.UserSkill, error) {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))
	q.Set("select", "*")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.skillsURL(q), nil)
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

	var skills []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &skills); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	if len(skills) == 0 {
		return nil, apperr.New(404, "Resource not found")
	}

	return r.parseSkill(skills[0])
}

func (r *SupabaseSkillRepository) GetUserSkills(ctx context.Context, userID uuid.UUID) ([]*models.UserSkill, error) {
	q := url.Values{}
	q.Set("user_id", fmt.Sprintf("eq.%s", userID.String()))
	q.Set("select", "*")
	q.Set("order", "display_order.desc,created_at.desc")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.skillsURL(q), nil)
	r.setHeaders(req, "")

	resp, err := r.http.Do(req)
	if err != nil {
		return nil, apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		if resp.StatusCode == 404 {
			return []*models.UserSkill{}, nil
		}
		return nil, apperr.ErrDatabaseError
	}

	var rawSkills []map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &rawSkills); err != nil {
		return nil, apperr.ErrDatabaseError
	}

	skills := make([]*models.UserSkill, 0, len(rawSkills))
	for _, raw := range rawSkills {
		skill, err := r.parseSkill(raw)
		if err != nil {
			continue
		}
		skills = append(skills, skill)
	}

	return skills, nil
}

func (r *SupabaseSkillRepository) parseSkill(raw map[string]interface{}) (*models.UserSkill, error) {
	skill := &models.UserSkill{}
	if idStr, ok := raw["id"].(string); ok {
		skill.ID, _ = uuid.Parse(idStr)
	}
	if userIDStr, ok := raw["user_id"].(string); ok {
		skill.UserID, _ = uuid.Parse(userIDStr)
	}
	if name, ok := raw["skill_name"].(string); ok {
		skill.SkillName = name
	}
	if level, ok := raw["proficiency_level"].(string); ok && level != "" {
		skill.ProficiencyLevel = &level
	}
	if cat, ok := raw["category"].(string); ok && cat != "" {
		skill.Category = &cat
	}
	if order, ok := raw["display_order"].(float64); ok {
		skill.DisplayOrder = int(order)
	}
	if createdAt, ok := raw["created_at"].(string); ok {
		skill.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	}
	return skill, nil
}

func (r *SupabaseSkillRepository) UpdateSkill(ctx context.Context, skill *models.UserSkill) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", skill.ID.String()))

	data := map[string]interface{}{
		"skill_name":    skill.SkillName,
		"display_order": skill.DisplayOrder,
	}

	if skill.ProficiencyLevel != nil {
		data["proficiency_level"] = *skill.ProficiencyLevel
	} else {
		data["proficiency_level"] = nil
	}
	if skill.Category != nil {
		data["category"] = *skill.Category
	} else {
		data["category"] = nil
	}

	body, err := json.Marshal(data)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, _ := http.NewRequestWithContext(ctx, http.MethodPatch, r.skillsURL(q), bytes.NewReader(body))
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] UpdateSkill failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

func (r *SupabaseSkillRepository) DeleteSkill(ctx context.Context, id uuid.UUID) error {
	q := url.Values{}
	q.Set("id", fmt.Sprintf("eq.%s", id.String()))

	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, r.skillsURL(q), nil)
	r.setHeaders(req, "return=minimal")

	resp, err := r.http.Do(req)
	if err != nil {
		return apperr.ErrDatabaseError
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Supabase] DeleteSkill failed: HTTP %d - %s", resp.StatusCode, string(bodyBytes))
		return apperr.ErrDatabaseError
	}

	return nil
}

// Continue with similar implementations for Languages, Volunteering, Publications, Interests, Achievements
// Due to length, I'll create a helper file for the remaining repositories

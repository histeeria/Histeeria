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

// SupabaseCourseRepository implements CourseRepository using Supabase REST API
type SupabaseCourseRepository struct {
	supabaseURL string
	serviceKey  string
	client      *http.Client
}

// NewSupabaseCourseRepository creates a new Supabase course repository
func NewSupabaseCourseRepository(supabaseURL, serviceKey string) *SupabaseCourseRepository {
	return &SupabaseCourseRepository{
		supabaseURL: supabaseURL,
		serviceKey:  serviceKey,
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// Helper to make Supabase requests
func (r *SupabaseCourseRepository) makeRequest(method, table, query string, body interface{}) ([]byte, error) {
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
		log.Printf("[SupabaseCourseRepo] Error response (status %d): %s", resp.StatusCode, string(data))
		return nil, fmt.Errorf("supabase error (status %d): %s", resp.StatusCode, string(data))
	}

	return data, nil
}

// supabaseCourse represents the course structure from Supabase
type supabaseCourse struct {
	ID                uuid.UUID     `json:"id"`
	CreatorID         uuid.UUID     `json:"creator_id"`
	Title             string        `json:"title"`
	Slug              string        `json:"slug"`
	Description       *string       `json:"description"`
	ShortDescription  *string       `json:"short_description"`
	CoverImageURL     *string       `json:"cover_image_url"`
	ThumbnailURL      *string       `json:"thumbnail_url"`
	Category          *string       `json:"category"`
	Subcategory       *string       `json:"subcategory"`
	Tags              []string      `json:"tags"`
	DifficultyLevel   string        `json:"difficulty_level"`
	Language          string        `json:"language"`
	IsFree            bool          `json:"is_free"`
	Price             *float64      `json:"price"`
	Currency          string        `json:"currency"`
	IsPublic          bool          `json:"is_public"`
	RequiresApproval  bool          `json:"requires_approval"`
	EstimatedDuration *int          `json:"estimated_duration"`
	TotalLessons      int           `json:"total_lessons"`
	TotalModules      int           `json:"total_modules"`
	Status            string        `json:"status"`
	PublishedAt       *string       `json:"published_at"`
	LastUpdatedAt     string        `json:"last_updated_at"`
	CreatedAt         string        `json:"created_at"`
	EnrollmentCount   int           `json:"enrollment_count"`
	CompletionCount   int           `json:"completion_count"`
	AverageRating     float64       `json:"average_rating"`
	ReviewCount       int           `json:"review_count"`
	ViewCount         int           `json:"view_count"`
	MetaTitle         *string       `json:"meta_title"`
	MetaDescription   *string       `json:"meta_description"`
	Creator           *supabaseUser `json:"creator,omitempty"`
}

func (sc *supabaseCourse) toCourse() (*models.Course, error) {
	course := &models.Course{
		ID:                sc.ID,
		CreatorID:         sc.CreatorID,
		Title:             sc.Title,
		Slug:              sc.Slug,
		Description:       sc.Description,
		ShortDescription:  sc.ShortDescription,
		CoverImageURL:     sc.CoverImageURL,
		ThumbnailURL:      sc.ThumbnailURL,
		Category:          sc.Category,
		Subcategory:       sc.Subcategory,
		Tags:              pq.StringArray(sc.Tags),
		DifficultyLevel:   sc.DifficultyLevel,
		Language:          sc.Language,
		IsFree:            sc.IsFree,
		Price:             sc.Price,
		Currency:          sc.Currency,
		IsPublic:          sc.IsPublic,
		RequiresApproval:  sc.RequiresApproval,
		EstimatedDuration: sc.EstimatedDuration,
		TotalLessons:      sc.TotalLessons,
		TotalModules:      sc.TotalModules,
		Status:            sc.Status,
		LastUpdatedAt:     parseCourseTime(sc.LastUpdatedAt),
		CreatedAt:         parseCourseTime(sc.CreatedAt),
		EnrollmentCount:   sc.EnrollmentCount,
		CompletionCount:   sc.CompletionCount,
		AverageRating:     sc.AverageRating,
		ReviewCount:       sc.ReviewCount,
		ViewCount:         sc.ViewCount,
		MetaTitle:         sc.MetaTitle,
		MetaDescription:   sc.MetaDescription,
	}

	if sc.PublishedAt != nil {
		publishedAt := parseCourseTime(*sc.PublishedAt)
		course.PublishedAt = &publishedAt
	}

	if sc.Creator != nil {
		creator, err := sc.Creator.toUser()
		if err == nil {
			course.Creator = creator
		}
	}

	return course, nil
}

func parseCourseTime(s string) time.Time {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return time.Now()
	}
	return t
}

// CreateCourse creates a new course
func (r *SupabaseCourseRepository) CreateCourse(ctx context.Context, course *models.Course) error {
	// Generate slug from title if not provided
	if course.Slug == "" {
		course.Slug = generateSlug(course.Title)
	}

	payload := map[string]interface{}{
		"creator_id":         course.CreatorID,
		"title":              course.Title,
		"slug":               course.Slug,
		"description":        course.Description,
		"short_description":  course.ShortDescription,
		"cover_image_url":    course.CoverImageURL,
		"thumbnail_url":      course.ThumbnailURL,
		"category":           course.Category,
		"subcategory":        course.Subcategory,
		"tags":               []string(course.Tags),
		"difficulty_level":   course.DifficultyLevel,
		"language":           course.Language,
		"is_free":            course.IsFree,
		"price":              course.Price,
		"currency":           course.Currency,
		"is_public":          course.IsPublic,
		"requires_approval":  course.RequiresApproval,
		"estimated_duration": course.EstimatedDuration,
		"meta_title":         course.MetaTitle,
		"meta_description":   course.MetaDescription,
		"status":             course.Status,
	}

	data, err := r.makeRequest("POST", "courses", "", payload)
	if err != nil {
		return err
	}

	var created supabaseCourse
	if err := json.Unmarshal(data, &created); err != nil {
		return fmt.Errorf("failed to unmarshal course: %w", err)
	}

	// Update course ID
	course.ID = created.ID
	course.CreatedAt = parseCourseTime(created.CreatedAt)
	course.LastUpdatedAt = parseCourseTime(created.LastUpdatedAt)

	return nil
}

// GetCourseByID retrieves a course by ID
func (r *SupabaseCourseRepository) GetCourseByID(ctx context.Context, id uuid.UUID) (*models.Course, error) {
	query := fmt.Sprintf("?id=eq.%s&select=*,creator:users!courses_creator_id_fkey(id,username,display_name,profile_picture,is_verified)", id.String())

	data, err := r.makeRequest("GET", "courses", query, nil)
	if err != nil {
		return nil, err
	}

	var courses []supabaseCourse
	if err := json.Unmarshal(data, &courses); err != nil {
		return nil, fmt.Errorf("failed to unmarshal courses: %w", err)
	}

	if len(courses) == 0 {
		return nil, fmt.Errorf("course not found")
	}

	return courses[0].toCourse()
}

// GetCourseBySlug retrieves a course by slug
func (r *SupabaseCourseRepository) GetCourseBySlug(ctx context.Context, slug string) (*models.Course, error) {
	query := fmt.Sprintf("?slug=eq.%s&select=*,creator:users!courses_creator_id_fkey(id,username,display_name,profile_picture,is_verified)", url.QueryEscape(slug))

	data, err := r.makeRequest("GET", "courses", query, nil)
	if err != nil {
		return nil, err
	}

	var courses []supabaseCourse
	if err := json.Unmarshal(data, &courses); err != nil {
		return nil, fmt.Errorf("failed to unmarshal courses: %w", err)
	}

	if len(courses) == 0 {
		return nil, fmt.Errorf("course not found")
	}

	return courses[0].toCourse()
}

// UpdateCourse updates an existing course
func (r *SupabaseCourseRepository) UpdateCourse(ctx context.Context, course *models.Course) error {
	payload := map[string]interface{}{}

	if course.Title != "" {
		payload["title"] = course.Title
		if course.Slug == "" {
			payload["slug"] = generateSlug(course.Title)
		}
	}
	if course.Slug != "" {
		payload["slug"] = course.Slug
	}
	if course.Description != nil {
		payload["description"] = course.Description
	}
	if course.ShortDescription != nil {
		payload["short_description"] = course.ShortDescription
	}
	if course.CoverImageURL != nil {
		payload["cover_image_url"] = course.CoverImageURL
	}
	if course.Category != nil {
		payload["category"] = course.Category
	}
	if course.Tags != nil {
		payload["tags"] = []string(course.Tags)
	}
	if course.Status != "" {
		payload["status"] = course.Status
		if course.Status == "published" && course.PublishedAt == nil {
			now := time.Now().Format(time.RFC3339)
			payload["published_at"] = now
		}
	}
	payload["last_updated_at"] = time.Now().Format(time.RFC3339)

	query := fmt.Sprintf("?id=eq.%s", course.ID.String())
	_, err := r.makeRequest("PATCH", "courses", query, payload)
	return err
}

// DeleteCourse deletes a course
func (r *SupabaseCourseRepository) DeleteCourse(ctx context.Context, id uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s", id.String())
	_, err := r.makeRequest("DELETE", "courses", query, nil)
	return err
}

// ListCourses lists courses with filters
func (r *SupabaseCourseRepository) ListCourses(ctx context.Context, filter *models.CourseFilter, userID *uuid.UUID) ([]*models.Course, error) {
	var queryParams []string

	// Base condition: only show published courses
	queryParams = append(queryParams, "status=eq.published")

	// If user is not logged in, also filter by is_public=true
	if userID == nil {
		queryParams = append(queryParams, "is_public=eq.true")
	}

	// Apply filters
	if filter.Category != nil {
		queryParams = append(queryParams, fmt.Sprintf("category=eq.%s", url.QueryEscape(*filter.Category)))
	}

	if filter.DifficultyLevel != nil {
		queryParams = append(queryParams, fmt.Sprintf("difficulty_level=eq.%s", url.QueryEscape(*filter.DifficultyLevel)))
	}

	if filter.IsFree != nil {
		queryParams = append(queryParams, fmt.Sprintf("is_free=eq.%t", *filter.IsFree))
	}

	if filter.Language != nil {
		queryParams = append(queryParams, fmt.Sprintf("language=eq.%s", url.QueryEscape(*filter.Language)))
	}

	if filter.Search != nil {
		queryParams = append(queryParams, fmt.Sprintf("or=(title.ilike.*%s*,description.ilike.*%s*)", url.QueryEscape(*filter.Search), url.QueryEscape(*filter.Search)))
	}

	// Build query string
	query := strings.Join(queryParams, "&")

	// Add sorting
	sortBy := "created_at.desc"
	if filter.SortBy == "popular" {
		sortBy = "enrollment_count.desc"
	} else if filter.SortBy == "rating" {
		sortBy = "average_rating.desc"
	} else if filter.SortBy == "price_asc" {
		sortBy = "price.asc"
	} else if filter.SortBy == "price_desc" {
		sortBy = "price.desc"
	}

	query = fmt.Sprintf("?%s&select=*,creator:users!courses_creator_id_fkey(id,username,display_name,profile_picture,is_verified)&order=%s&limit=%d&offset=%d",
		query, sortBy, filter.Limit, filter.Offset)

	log.Printf("[SupabaseCourseRepo] ListCourses query: %s", query)

	data, err := r.makeRequest("GET", "courses", query, nil)
	if err != nil {
		return nil, err
	}

	var supabaseCourses []supabaseCourse
	if err := json.Unmarshal(data, &supabaseCourses); err != nil {
		return nil, fmt.Errorf("failed to unmarshal courses: %w", err)
	}

	courses := make([]*models.Course, len(supabaseCourses))
	for i, sc := range supabaseCourses {
		course, err := sc.toCourse()
		if err != nil {
			return nil, err
		}

		// Check if user has enrolled
		if userID != nil {
			enrollment, _ := r.GetEnrollment(ctx, course.ID, *userID)
			if enrollment != nil {
				course.IsEnrolled = true
				course.Enrollment = enrollment
			}
		}

		courses[i] = course
	}

	return courses, nil
}

// Helper function to generate slug from title
func generateSlug(title string) string {
	slug := strings.ToLower(title)
	slug = strings.ReplaceAll(slug, " ", "-")
	slug = strings.ReplaceAll(slug, "_", "-")
	// Remove special characters, keep only alphanumeric and hyphens
	var result strings.Builder
	for _, char := range slug {
		if (char >= 'a' && char <= 'z') || (char >= '0' && char <= '9') || char == '-' {
			result.WriteRune(char)
		}
	}
	return result.String()
}

// Stub implementations for other methods (to be implemented as needed)
func (r *SupabaseCourseRepository) GetCoursesByCreator(ctx context.Context, creatorID uuid.UUID, limit, offset int) ([]*models.Course, error) {
	query := fmt.Sprintf("?creator_id=eq.%s&order=created_at.desc&limit=%d&offset=%d&select=*,creator:users!courses_creator_id_fkey(id,username,display_name,profile_picture,is_verified)", creatorID.String(), limit, offset)
	data, err := r.makeRequest("GET", "courses", query, nil)
	if err != nil {
		return nil, err
	}
	var supabaseCourses []supabaseCourse
	if err := json.Unmarshal(data, &supabaseCourses); err != nil {
		return nil, fmt.Errorf("failed to unmarshal courses: %w", err)
	}
	courses := make([]*models.Course, len(supabaseCourses))
	for i, sc := range supabaseCourses {
		course, err := sc.toCourse()
		if err != nil {
			return nil, err
		}
		courses[i] = course
	}
	return courses, nil
}

func (r *SupabaseCourseRepository) GetEnrolledCourses(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.Course, error) {
	// Get enrollments first
	query := fmt.Sprintf("?user_id=eq.%s&select=course_id&limit=%d&offset=%d", userID.String(), limit, offset)
	data, err := r.makeRequest("GET", "course_enrollments", query, nil)
	if err != nil {
		return nil, err
	}
	var enrollments []struct {
		CourseID uuid.UUID `json:"course_id"`
	}
	if err := json.Unmarshal(data, &enrollments); err != nil {
		return nil, err
	}
	if len(enrollments) == 0 {
		return []*models.Course{}, nil
	}
	// Get courses
	courseIDs := make([]string, len(enrollments))
	for i, e := range enrollments {
		courseIDs[i] = e.CourseID.String()
	}
	query = fmt.Sprintf("?id=in.(%s)&select=*,creator:users!courses_creator_id_fkey(id,username,display_name,profile_picture,is_verified)", strings.Join(courseIDs, ","))
	data, err = r.makeRequest("GET", "courses", query, nil)
	if err != nil {
		return nil, err
	}
	var supabaseCourses []supabaseCourse
	if err := json.Unmarshal(data, &supabaseCourses); err != nil {
		return nil, err
	}
	courses := make([]*models.Course, len(supabaseCourses))
	for i, sc := range supabaseCourses {
		course, err := sc.toCourse()
		if err != nil {
			return nil, err
		}
		course.IsEnrolled = true
		courses[i] = course
	}
	return courses, nil
}

func (r *SupabaseCourseRepository) IncrementViewCount(ctx context.Context, courseID uuid.UUID) error {
	// Get current view count
	course, err := r.GetCourseByID(ctx, courseID)
	if err != nil {
		return err
	}
	payload := map[string]interface{}{
		"view_count": course.ViewCount + 1,
	}
	query := fmt.Sprintf("?id=eq.%s", courseID.String())
	_, err = r.makeRequest("PATCH", "courses", query, payload)
	return err
}

// Module methods (stubs - to be fully implemented)
func (r *SupabaseCourseRepository) CreateModule(ctx context.Context, module *models.CourseModule) error {
	payload := map[string]interface{}{
		"course_id":   module.CourseID,
		"title":       module.Title,
		"description": module.Description,
		"order_index": module.OrderIndex,
		"is_preview":  module.IsPreview,
	}
	data, err := r.makeRequest("POST", "course_modules", "", payload)
	if err != nil {
		return err
	}
	var created struct {
		ID        uuid.UUID `json:"id"`
		CreatedAt string    `json:"created_at"`
		UpdatedAt string    `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &created); err != nil {
		return err
	}
	module.ID = created.ID
	module.CreatedAt = parseCourseTime(created.CreatedAt)
	module.UpdatedAt = parseCourseTime(created.UpdatedAt)
	return nil
}

func (r *SupabaseCourseRepository) GetModuleByID(ctx context.Context, id uuid.UUID) (*models.CourseModule, error) {
	query := fmt.Sprintf("?id=eq.%s", id.String())
	data, err := r.makeRequest("GET", "course_modules", query, nil)
	if err != nil {
		return nil, err
	}
	var modules []struct {
		ID          uuid.UUID `json:"id"`
		CourseID    uuid.UUID `json:"course_id"`
		Title       string    `json:"title"`
		Description *string   `json:"description"`
		OrderIndex  int       `json:"order_index"`
		IsPreview   bool      `json:"is_preview"`
		CreatedAt   string    `json:"created_at"`
		UpdatedAt   string    `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &modules); err != nil {
		return nil, err
	}
	if len(modules) == 0 {
		return nil, fmt.Errorf("module not found")
	}
	m := modules[0]
	return &models.CourseModule{
		ID:          m.ID,
		CourseID:    m.CourseID,
		Title:       m.Title,
		Description: m.Description,
		OrderIndex:  m.OrderIndex,
		IsPreview:   m.IsPreview,
		CreatedAt:   parseCourseTime(m.CreatedAt),
		UpdatedAt:   parseCourseTime(m.UpdatedAt),
	}, nil
}

func (r *SupabaseCourseRepository) GetModulesByCourse(ctx context.Context, courseID uuid.UUID) ([]*models.CourseModule, error) {
	query := fmt.Sprintf("?course_id=eq.%s&order=order_index.asc&select=*", courseID.String())
	data, err := r.makeRequest("GET", "course_modules", query, nil)
	if err != nil {
		return nil, err
	}
	var modules []struct {
		ID          uuid.UUID `json:"id"`
		CourseID    uuid.UUID `json:"course_id"`
		Title       string    `json:"title"`
		Description *string   `json:"description"`
		OrderIndex  int       `json:"order_index"`
		IsPreview   bool      `json:"is_preview"`
		CreatedAt   string    `json:"created_at"`
		UpdatedAt   string    `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &modules); err != nil {
		return nil, err
	}
	result := make([]*models.CourseModule, len(modules))
	for i, m := range modules {
		result[i] = &models.CourseModule{
			ID:          m.ID,
			CourseID:    m.CourseID,
			Title:       m.Title,
			Description: m.Description,
			OrderIndex:  m.OrderIndex,
			IsPreview:   m.IsPreview,
			CreatedAt:   parseCourseTime(m.CreatedAt),
			UpdatedAt:   parseCourseTime(m.UpdatedAt),
		}
	}
	return result, nil
}

func (r *SupabaseCourseRepository) UpdateModule(ctx context.Context, module *models.CourseModule) error {
	payload := map[string]interface{}{
		"title":       module.Title,
		"description": module.Description,
		"order_index": module.OrderIndex,
		"is_preview":  module.IsPreview,
		"updated_at":  time.Now().Format(time.RFC3339),
	}
	query := fmt.Sprintf("?id=eq.%s", module.ID.String())
	_, err := r.makeRequest("PATCH", "course_modules", query, payload)
	return err
}

func (r *SupabaseCourseRepository) DeleteModule(ctx context.Context, id uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s", id.String())
	_, err := r.makeRequest("DELETE", "course_modules", query, nil)
	return err
}

func (r *SupabaseCourseRepository) ReorderModules(ctx context.Context, courseID uuid.UUID, moduleOrders map[uuid.UUID]int) error {
	// Batch update order indices
	for moduleID, orderIndex := range moduleOrders {
		payload := map[string]interface{}{
			"order_index": orderIndex,
		}
		query := fmt.Sprintf("?id=eq.%s", moduleID.String())
		if _, err := r.makeRequest("PATCH", "course_modules", query, payload); err != nil {
			return err
		}
	}
	return nil
}

// Lesson methods (stubs)
func (r *SupabaseCourseRepository) CreateLesson(ctx context.Context, lesson *models.CourseLesson) error {
	payload := map[string]interface{}{
		"module_id":      lesson.ModuleID,
		"course_id":      lesson.CourseID,
		"title":          lesson.Title,
		"description":    lesson.Description,
		"content":        lesson.Content,
		"video_url":      lesson.VideoURL,
		"video_duration": lesson.VideoDuration,
		"order_index":    lesson.OrderIndex,
		"lesson_type":    lesson.LessonType,
		"is_preview":     lesson.IsPreview,
		"resources":      lesson.Resources,
		"attachments":    []string(lesson.Attachments),
	}
	data, err := r.makeRequest("POST", "course_lessons", "", payload)
	if err != nil {
		return err
	}
	var created struct {
		ID        uuid.UUID `json:"id"`
		CreatedAt string    `json:"created_at"`
		UpdatedAt string    `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &created); err != nil {
		return err
	}
	lesson.ID = created.ID
	lesson.CreatedAt = parseCourseTime(created.CreatedAt)
	lesson.UpdatedAt = parseCourseTime(created.UpdatedAt)
	return nil
}

func (r *SupabaseCourseRepository) GetLessonByID(ctx context.Context, id uuid.UUID) (*models.CourseLesson, error) {
	query := fmt.Sprintf("?id=eq.%s", id.String())
	data, err := r.makeRequest("GET", "course_lessons", query, nil)
	if err != nil {
		return nil, err
	}
	var lessons []struct {
		ID            uuid.UUID              `json:"id"`
		ModuleID      uuid.UUID              `json:"module_id"`
		CourseID      uuid.UUID              `json:"course_id"`
		Title         string                 `json:"title"`
		Description   *string                `json:"description"`
		Content       *string                `json:"content"`
		VideoURL      *string                `json:"video_url"`
		VideoDuration *int                   `json:"video_duration"`
		OrderIndex    int                    `json:"order_index"`
		LessonType    string                 `json:"lesson_type"`
		IsPreview     bool                   `json:"is_preview"`
		Resources     map[string]interface{} `json:"resources"`
		Attachments   []string               `json:"attachments"`
		CreatedAt     string                 `json:"created_at"`
		UpdatedAt     string                 `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &lessons); err != nil {
		return nil, err
	}
	if len(lessons) == 0 {
		return nil, fmt.Errorf("lesson not found")
	}
	l := lessons[0]
	return &models.CourseLesson{
		ID:            l.ID,
		ModuleID:      l.ModuleID,
		CourseID:      l.CourseID,
		Title:         l.Title,
		Description:   l.Description,
		Content:       l.Content,
		VideoURL:      l.VideoURL,
		VideoDuration: l.VideoDuration,
		OrderIndex:    l.OrderIndex,
		LessonType:    l.LessonType,
		IsPreview:     l.IsPreview,
		Resources:     l.Resources,
		Attachments:   pq.StringArray(l.Attachments),
		CreatedAt:     parseCourseTime(l.CreatedAt),
		UpdatedAt:     parseCourseTime(l.UpdatedAt),
	}, nil
}

func (r *SupabaseCourseRepository) GetLessonsByModule(ctx context.Context, moduleID uuid.UUID) ([]*models.CourseLesson, error) {
	query := fmt.Sprintf("?module_id=eq.%s&order=order_index.asc&select=*", moduleID.String())
	data, err := r.makeRequest("GET", "course_lessons", query, nil)
	if err != nil {
		return nil, err
	}
	var lessons []struct {
		ID            uuid.UUID              `json:"id"`
		ModuleID      uuid.UUID              `json:"module_id"`
		CourseID      uuid.UUID              `json:"course_id"`
		Title         string                 `json:"title"`
		Description   *string                `json:"description"`
		Content       *string                `json:"content"`
		VideoURL      *string                `json:"video_url"`
		VideoDuration *int                   `json:"video_duration"`
		OrderIndex    int                    `json:"order_index"`
		LessonType    string                 `json:"lesson_type"`
		IsPreview     bool                   `json:"is_preview"`
		Resources     map[string]interface{} `json:"resources"`
		Attachments   []string               `json:"attachments"`
		CreatedAt     string                 `json:"created_at"`
		UpdatedAt     string                 `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &lessons); err != nil {
		return nil, err
	}
	result := make([]*models.CourseLesson, len(lessons))
	for i, l := range lessons {
		result[i] = &models.CourseLesson{
			ID:            l.ID,
			ModuleID:      l.ModuleID,
			CourseID:      l.CourseID,
			Title:         l.Title,
			Description:   l.Description,
			Content:       l.Content,
			VideoURL:      l.VideoURL,
			VideoDuration: l.VideoDuration,
			OrderIndex:    l.OrderIndex,
			LessonType:    l.LessonType,
			IsPreview:     l.IsPreview,
			Resources:     l.Resources,
			Attachments:   pq.StringArray(l.Attachments),
			CreatedAt:     parseCourseTime(l.CreatedAt),
			UpdatedAt:     parseCourseTime(l.UpdatedAt),
		}
	}
	return result, nil
}

func (r *SupabaseCourseRepository) GetLessonsByCourse(ctx context.Context, courseID uuid.UUID) ([]*models.CourseLesson, error) {
	query := fmt.Sprintf("?course_id=eq.%s&order=order_index.asc&select=*", courseID.String())
	data, err := r.makeRequest("GET", "course_lessons", query, nil)
	if err != nil {
		return nil, err
	}
	var lessons []struct {
		ID            uuid.UUID              `json:"id"`
		ModuleID      uuid.UUID              `json:"module_id"`
		CourseID      uuid.UUID              `json:"course_id"`
		Title         string                 `json:"title"`
		Description   *string                `json:"description"`
		Content       *string                `json:"content"`
		VideoURL      *string                `json:"video_url"`
		VideoDuration *int                   `json:"video_duration"`
		OrderIndex    int                    `json:"order_index"`
		LessonType    string                 `json:"lesson_type"`
		IsPreview     bool                   `json:"is_preview"`
		Resources     map[string]interface{} `json:"resources"`
		Attachments   []string               `json:"attachments"`
		CreatedAt     string                 `json:"created_at"`
		UpdatedAt     string                 `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &lessons); err != nil {
		return nil, err
	}
	result := make([]*models.CourseLesson, len(lessons))
	for i, l := range lessons {
		result[i] = &models.CourseLesson{
			ID:            l.ID,
			ModuleID:      l.ModuleID,
			CourseID:      l.CourseID,
			Title:         l.Title,
			Description:   l.Description,
			Content:       l.Content,
			VideoURL:      l.VideoURL,
			VideoDuration: l.VideoDuration,
			OrderIndex:    l.OrderIndex,
			LessonType:    l.LessonType,
			IsPreview:     l.IsPreview,
			Resources:     l.Resources,
			Attachments:   pq.StringArray(l.Attachments),
			CreatedAt:     parseCourseTime(l.CreatedAt),
			UpdatedAt:     parseCourseTime(l.UpdatedAt),
		}
	}
	return result, nil
}

func (r *SupabaseCourseRepository) UpdateLesson(ctx context.Context, lesson *models.CourseLesson) error {
	payload := map[string]interface{}{
		"title":          lesson.Title,
		"description":    lesson.Description,
		"content":        lesson.Content,
		"video_url":      lesson.VideoURL,
		"video_duration": lesson.VideoDuration,
		"order_index":    lesson.OrderIndex,
		"lesson_type":    lesson.LessonType,
		"is_preview":     lesson.IsPreview,
		"resources":      lesson.Resources,
		"attachments":    []string(lesson.Attachments),
		"updated_at":     time.Now().Format(time.RFC3339),
	}
	query := fmt.Sprintf("?id=eq.%s", lesson.ID.String())
	_, err := r.makeRequest("PATCH", "course_lessons", query, payload)
	return err
}

func (r *SupabaseCourseRepository) DeleteLesson(ctx context.Context, id uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s", id.String())
	_, err := r.makeRequest("DELETE", "course_lessons", query, nil)
	return err
}

func (r *SupabaseCourseRepository) ReorderLessons(ctx context.Context, moduleID uuid.UUID, lessonOrders map[uuid.UUID]int) error {
	for lessonID, orderIndex := range lessonOrders {
		payload := map[string]interface{}{
			"order_index": orderIndex,
		}
		query := fmt.Sprintf("?id=eq.%s", lessonID.String())
		if _, err := r.makeRequest("PATCH", "course_lessons", query, payload); err != nil {
			return err
		}
	}
	return nil
}

// Enrollment methods
func (r *SupabaseCourseRepository) CreateEnrollment(ctx context.Context, enrollment *models.CourseEnrollment) error {
	payload := map[string]interface{}{
		"course_id":              enrollment.CourseID,
		"user_id":                enrollment.UserID,
		"payment_status":         enrollment.PaymentStatus,
		"payment_amount":         enrollment.PaymentAmount,
		"payment_currency":       enrollment.PaymentCurrency,
		"payment_transaction_id": enrollment.PaymentTransactionID,
	}
	data, err := r.makeRequest("POST", "course_enrollments", "", payload)
	if err != nil {
		return err
	}
	var created struct {
		ID                 uuid.UUID `json:"id"`
		EnrolledAt         string    `json:"enrolled_at"`
		ProgressPercentage float64   `json:"progress_percentage"`
	}
	if err := json.Unmarshal(data, &created); err != nil {
		return err
	}
	enrollment.ID = created.ID
	enrollment.EnrolledAt = parseCourseTime(created.EnrolledAt)
	enrollment.ProgressPercentage = created.ProgressPercentage
	return nil
}

func (r *SupabaseCourseRepository) GetEnrollment(ctx context.Context, courseID, userID uuid.UUID) (*models.CourseEnrollment, error) {
	query := fmt.Sprintf("?course_id=eq.%s&user_id=eq.%s&select=*", courseID.String(), userID.String())
	data, err := r.makeRequest("GET", "course_enrollments", query, nil)
	if err != nil {
		return nil, err
	}
	var enrollments []struct {
		ID                   uuid.UUID  `json:"id"`
		CourseID             uuid.UUID  `json:"course_id"`
		UserID               uuid.UUID  `json:"user_id"`
		EnrolledAt           string     `json:"enrolled_at"`
		CompletedAt          *string    `json:"completed_at"`
		ProgressPercentage   float64    `json:"progress_percentage"`
		PaymentStatus        string     `json:"payment_status"`
		PaymentAmount        *float64   `json:"payment_amount"`
		PaymentCurrency      *string    `json:"payment_currency"`
		PaymentTransactionID *string    `json:"payment_transaction_id"`
		LastAccessedAt       *string    `json:"last_accessed_at"`
		LastAccessedLessonID *uuid.UUID `json:"last_accessed_lesson_id"`
	}
	if err := json.Unmarshal(data, &enrollments); err != nil {
		return nil, err
	}
	if len(enrollments) == 0 {
		return nil, nil
	}
	e := enrollments[0]
	enrollment := &models.CourseEnrollment{
		ID:                   e.ID,
		CourseID:             e.CourseID,
		UserID:               e.UserID,
		EnrolledAt:           parseCourseTime(e.EnrolledAt),
		ProgressPercentage:   e.ProgressPercentage,
		PaymentStatus:        e.PaymentStatus,
		PaymentAmount:        e.PaymentAmount,
		PaymentCurrency:      e.PaymentCurrency,
		PaymentTransactionID: e.PaymentTransactionID,
	}
	if e.CompletedAt != nil {
		completedAt := parseCourseTime(*e.CompletedAt)
		enrollment.CompletedAt = &completedAt
	}
	if e.LastAccessedAt != nil {
		lastAccessedAt := parseCourseTime(*e.LastAccessedAt)
		enrollment.LastAccessedAt = &lastAccessedAt
	}
	enrollment.LastAccessedLessonID = e.LastAccessedLessonID
	return enrollment, nil
}

func (r *SupabaseCourseRepository) GetEnrollmentByID(ctx context.Context, id uuid.UUID) (*models.CourseEnrollment, error) {
	query := fmt.Sprintf("?id=eq.%s&select=*", id.String())
	data, err := r.makeRequest("GET", "course_enrollments", query, nil)
	if err != nil {
		return nil, err
	}
	var enrollments []struct {
		ID                   uuid.UUID  `json:"id"`
		CourseID             uuid.UUID  `json:"course_id"`
		UserID               uuid.UUID  `json:"user_id"`
		EnrolledAt           string     `json:"enrolled_at"`
		CompletedAt          *string    `json:"completed_at"`
		ProgressPercentage   float64    `json:"progress_percentage"`
		PaymentStatus        string     `json:"payment_status"`
		PaymentAmount        *float64   `json:"payment_amount"`
		PaymentCurrency      *string    `json:"payment_currency"`
		PaymentTransactionID *string    `json:"payment_transaction_id"`
		LastAccessedAt       *string    `json:"last_accessed_at"`
		LastAccessedLessonID *uuid.UUID `json:"last_accessed_lesson_id"`
	}
	if err := json.Unmarshal(data, &enrollments); err != nil {
		return nil, err
	}
	if len(enrollments) == 0 {
		return nil, fmt.Errorf("enrollment not found")
	}
	e := enrollments[0]
	enrollment := &models.CourseEnrollment{
		ID:                   e.ID,
		CourseID:             e.CourseID,
		UserID:               e.UserID,
		EnrolledAt:           parseCourseTime(e.EnrolledAt),
		ProgressPercentage:   e.ProgressPercentage,
		PaymentStatus:        e.PaymentStatus,
		PaymentAmount:        e.PaymentAmount,
		PaymentCurrency:      e.PaymentCurrency,
		PaymentTransactionID: e.PaymentTransactionID,
	}
	if e.CompletedAt != nil {
		completedAt := parseCourseTime(*e.CompletedAt)
		enrollment.CompletedAt = &completedAt
	}
	if e.LastAccessedAt != nil {
		lastAccessedAt := parseCourseTime(*e.LastAccessedAt)
		enrollment.LastAccessedAt = &lastAccessedAt
	}
	enrollment.LastAccessedLessonID = e.LastAccessedLessonID
	return enrollment, nil
}

func (r *SupabaseCourseRepository) UpdateEnrollment(ctx context.Context, enrollment *models.CourseEnrollment) error {
	payload := map[string]interface{}{
		"progress_percentage": enrollment.ProgressPercentage,
		"last_accessed_at":    time.Now().Format(time.RFC3339),
	}
	if enrollment.CompletedAt != nil {
		payload["completed_at"] = enrollment.CompletedAt.Format(time.RFC3339)
	}
	if enrollment.LastAccessedLessonID != nil {
		payload["last_accessed_lesson_id"] = enrollment.LastAccessedLessonID.String()
	}
	query := fmt.Sprintf("?id=eq.%s", enrollment.ID.String())
	_, err := r.makeRequest("PATCH", "course_enrollments", query, payload)
	return err
}

func (r *SupabaseCourseRepository) GetEnrollmentsByCourse(ctx context.Context, courseID uuid.UUID, limit, offset int) ([]*models.CourseEnrollment, error) {
	query := fmt.Sprintf("?course_id=eq.%s&order=enrolled_at.desc&limit=%d&offset=%d&select=*,user:users!course_enrollments_user_id_fkey(id,username,display_name,profile_picture,is_verified)", courseID.String(), limit, offset)
	data, err := r.makeRequest("GET", "course_enrollments", query, nil)
	if err != nil {
		return nil, err
	}
	var enrollments []struct {
		ID                 uuid.UUID     `json:"id"`
		CourseID           uuid.UUID     `json:"course_id"`
		UserID             uuid.UUID     `json:"user_id"`
		EnrolledAt         string        `json:"enrolled_at"`
		CompletedAt        *string       `json:"completed_at"`
		ProgressPercentage float64       `json:"progress_percentage"`
		PaymentStatus      string        `json:"payment_status"`
		User               *supabaseUser `json:"user,omitempty"`
	}
	if err := json.Unmarshal(data, &enrollments); err != nil {
		return nil, err
	}
	result := make([]*models.CourseEnrollment, len(enrollments))
	for i, e := range enrollments {
		enrollment := &models.CourseEnrollment{
			ID:                 e.ID,
			CourseID:           e.CourseID,
			UserID:             e.UserID,
			EnrolledAt:         parseCourseTime(e.EnrolledAt),
			ProgressPercentage: e.ProgressPercentage,
			PaymentStatus:      e.PaymentStatus,
		}
		if e.CompletedAt != nil {
			completedAt := parseCourseTime(*e.CompletedAt)
			enrollment.CompletedAt = &completedAt
		}
		if e.User != nil {
			user, err := e.User.toUser()
			if err == nil {
				enrollment.User = user
			}
		}
		result[i] = enrollment
	}
	return result, nil
}

func (r *SupabaseCourseRepository) GetEnrollmentsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.CourseEnrollment, error) {
	query := fmt.Sprintf("?user_id=eq.%s&order=enrolled_at.desc&limit=%d&offset=%d&select=*", userID.String(), limit, offset)
	data, err := r.makeRequest("GET", "course_enrollments", query, nil)
	if err != nil {
		return nil, err
	}
	var enrollments []struct {
		ID                 uuid.UUID `json:"id"`
		CourseID           uuid.UUID `json:"course_id"`
		UserID             uuid.UUID `json:"user_id"`
		EnrolledAt         string    `json:"enrolled_at"`
		CompletedAt        *string   `json:"completed_at"`
		ProgressPercentage float64   `json:"progress_percentage"`
		PaymentStatus      string    `json:"payment_status"`
	}
	if err := json.Unmarshal(data, &enrollments); err != nil {
		return nil, err
	}
	result := make([]*models.CourseEnrollment, len(enrollments))
	for i, e := range enrollments {
		enrollment := &models.CourseEnrollment{
			ID:                 e.ID,
			CourseID:           e.CourseID,
			UserID:             e.UserID,
			EnrolledAt:         parseCourseTime(e.EnrolledAt),
			ProgressPercentage: e.ProgressPercentage,
			PaymentStatus:      e.PaymentStatus,
		}
		if e.CompletedAt != nil {
			completedAt := parseCourseTime(*e.CompletedAt)
			enrollment.CompletedAt = &completedAt
		}
		result[i] = enrollment
	}
	return result, nil
}

func (r *SupabaseCourseRepository) CheckEnrollment(ctx context.Context, courseID, userID uuid.UUID) (bool, error) {
	enrollment, err := r.GetEnrollment(ctx, courseID, userID)
	if err != nil {
		return false, err
	}
	return enrollment != nil, nil
}

// Collaborator methods (stubs)
func (r *SupabaseCourseRepository) CreateCollaborator(ctx context.Context, collaborator *models.CourseCollaborator) error {
	payload := map[string]interface{}{
		"course_id":   collaborator.CourseID,
		"user_id":     collaborator.UserID,
		"role":        collaborator.Role,
		"permissions": []string(collaborator.Permissions),
		"invited_by":  collaborator.InvitedBy,
		"status":      collaborator.Status,
		"invited_at":  time.Now().Format(time.RFC3339),
	}
	data, err := r.makeRequest("POST", "course_collaborators", "", payload)
	if err != nil {
		return err
	}
	var created struct {
		ID        uuid.UUID `json:"id"`
		CreatedAt string    `json:"created_at"`
	}
	if err := json.Unmarshal(data, &created); err != nil {
		return err
	}
	collaborator.ID = created.ID
	collaborator.CreatedAt = parseCourseTime(created.CreatedAt)
	return nil
}

func (r *SupabaseCourseRepository) GetCollaborator(ctx context.Context, courseID, userID uuid.UUID) (*models.CourseCollaborator, error) {
	query := fmt.Sprintf("?course_id=eq.%s&user_id=eq.%s&select=*", courseID.String(), userID.String())
	data, err := r.makeRequest("GET", "course_collaborators", query, nil)
	if err != nil {
		return nil, err
	}
	var collaborators []struct {
		ID          uuid.UUID  `json:"id"`
		CourseID    uuid.UUID  `json:"course_id"`
		UserID      uuid.UUID  `json:"user_id"`
		Role        string     `json:"role"`
		Permissions []string   `json:"permissions"`
		InvitedBy   *uuid.UUID `json:"invited_by"`
		InvitedAt   *string    `json:"invited_at"`
		AcceptedAt  *string    `json:"accepted_at"`
		Status      string     `json:"status"`
		CreatedAt   string     `json:"created_at"`
	}
	if err := json.Unmarshal(data, &collaborators); err != nil {
		return nil, err
	}
	if len(collaborators) == 0 {
		return nil, nil
	}
	c := collaborators[0]
	collab := &models.CourseCollaborator{
		ID:          c.ID,
		CourseID:    c.CourseID,
		UserID:      c.UserID,
		Role:        c.Role,
		Permissions: pq.StringArray(c.Permissions),
		InvitedBy:   c.InvitedBy,
		Status:      c.Status,
		CreatedAt:   parseCourseTime(c.CreatedAt),
	}
	if c.InvitedAt != nil {
		invitedAt := parseCourseTime(*c.InvitedAt)
		collab.InvitedAt = &invitedAt
	}
	if c.AcceptedAt != nil {
		acceptedAt := parseCourseTime(*c.AcceptedAt)
		collab.AcceptedAt = &acceptedAt
	}
	return collab, nil
}

func (r *SupabaseCourseRepository) GetCollaboratorsByCourse(ctx context.Context, courseID uuid.UUID) ([]*models.CourseCollaborator, error) {
	query := fmt.Sprintf("?course_id=eq.%s&status=eq.accepted&select=*,user:users!course_collaborators_user_id_fkey(id,username,display_name,profile_picture,is_verified)", courseID.String())
	data, err := r.makeRequest("GET", "course_collaborators", query, nil)
	if err != nil {
		return nil, err
	}
	var collaborators []struct {
		ID          uuid.UUID     `json:"id"`
		CourseID    uuid.UUID     `json:"course_id"`
		UserID      uuid.UUID     `json:"user_id"`
		Role        string        `json:"role"`
		Permissions []string      `json:"permissions"`
		Status      string        `json:"status"`
		CreatedAt   string        `json:"created_at"`
		User        *supabaseUser `json:"user,omitempty"`
	}
	if err := json.Unmarshal(data, &collaborators); err != nil {
		return nil, err
	}
	result := make([]*models.CourseCollaborator, len(collaborators))
	for i, c := range collaborators {
		collab := &models.CourseCollaborator{
			ID:          c.ID,
			CourseID:    c.CourseID,
			UserID:      c.UserID,
			Role:        c.Role,
			Permissions: pq.StringArray(c.Permissions),
			Status:      c.Status,
			CreatedAt:   parseCourseTime(c.CreatedAt),
		}
		if c.User != nil {
			user, err := c.User.toUser()
			if err == nil {
				collab.User = user
			}
		}
		result[i] = collab
	}
	return result, nil
}

func (r *SupabaseCourseRepository) UpdateCollaborator(ctx context.Context, collaborator *models.CourseCollaborator) error {
	payload := map[string]interface{}{
		"role":        collaborator.Role,
		"permissions": []string(collaborator.Permissions),
		"status":      collaborator.Status,
	}
	if collaborator.AcceptedAt != nil {
		payload["accepted_at"] = collaborator.AcceptedAt.Format(time.RFC3339)
	}
	query := fmt.Sprintf("?id=eq.%s", collaborator.ID.String())
	_, err := r.makeRequest("PATCH", "course_collaborators", query, payload)
	return err
}

func (r *SupabaseCourseRepository) DeleteCollaborator(ctx context.Context, courseID, userID uuid.UUID) error {
	query := fmt.Sprintf("?course_id=eq.%s&user_id=eq.%s", courseID.String(), userID.String())
	_, err := r.makeRequest("DELETE", "course_collaborators", query, nil)
	return err
}

func (r *SupabaseCourseRepository) CheckCollaborator(ctx context.Context, courseID, userID uuid.UUID) (bool, error) {
	collab, err := r.GetCollaborator(ctx, courseID, userID)
	if err != nil {
		return false, err
	}
	return collab != nil && collab.Status == "accepted", nil
}

// Review methods (stubs)
func (r *SupabaseCourseRepository) CreateReview(ctx context.Context, review *models.CourseReview) error {
	payload := map[string]interface{}{
		"course_id":              review.CourseID,
		"user_id":                review.UserID,
		"rating":                 review.Rating,
		"title":                  review.Title,
		"review_text":            review.ReviewText,
		"is_verified_enrollment": review.IsVerifiedEnrollment,
	}
	data, err := r.makeRequest("POST", "course_reviews", "", payload)
	if err != nil {
		return err
	}
	var created struct {
		ID        uuid.UUID `json:"id"`
		CreatedAt string    `json:"created_at"`
		UpdatedAt string    `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &created); err != nil {
		return err
	}
	review.ID = created.ID
	review.CreatedAt = parseCourseTime(created.CreatedAt)
	review.UpdatedAt = parseCourseTime(created.UpdatedAt)
	return nil
}

func (r *SupabaseCourseRepository) GetReview(ctx context.Context, courseID, userID uuid.UUID) (*models.CourseReview, error) {
	query := fmt.Sprintf("?course_id=eq.%s&user_id=eq.%s&select=*", courseID.String(), userID.String())
	data, err := r.makeRequest("GET", "course_reviews", query, nil)
	if err != nil {
		return nil, err
	}
	var reviews []struct {
		ID                   uuid.UUID `json:"id"`
		CourseID             uuid.UUID `json:"course_id"`
		UserID               uuid.UUID `json:"user_id"`
		Rating               int       `json:"rating"`
		Title                *string   `json:"title"`
		ReviewText           *string   `json:"review_text"`
		IsVerifiedEnrollment bool      `json:"is_verified_enrollment"`
		IsHelpfulCount       int       `json:"is_helpful_count"`
		CreatedAt            string    `json:"created_at"`
		UpdatedAt            string    `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &reviews); err != nil {
		return nil, err
	}
	if len(reviews) == 0 {
		return nil, nil
	}
	rev := reviews[0]
	return &models.CourseReview{
		ID:                   rev.ID,
		CourseID:             rev.CourseID,
		UserID:               rev.UserID,
		Rating:               rev.Rating,
		Title:                rev.Title,
		ReviewText:           rev.ReviewText,
		IsVerifiedEnrollment: rev.IsVerifiedEnrollment,
		IsHelpfulCount:       rev.IsHelpfulCount,
		CreatedAt:            parseCourseTime(rev.CreatedAt),
		UpdatedAt:            parseCourseTime(rev.UpdatedAt),
	}, nil
}

func (r *SupabaseCourseRepository) GetReviewsByCourse(ctx context.Context, courseID uuid.UUID, limit, offset int) ([]*models.CourseReview, error) {
	query := fmt.Sprintf("?course_id=eq.%s&order=created_at.desc&limit=%d&offset=%d&select=*,user:users!course_reviews_user_id_fkey(id,username,display_name,profile_picture,is_verified)", courseID.String(), limit, offset)
	data, err := r.makeRequest("GET", "course_reviews", query, nil)
	if err != nil {
		return nil, err
	}
	var reviews []struct {
		ID                   uuid.UUID     `json:"id"`
		CourseID             uuid.UUID     `json:"course_id"`
		UserID               uuid.UUID     `json:"user_id"`
		Rating               int           `json:"rating"`
		Title                *string       `json:"title"`
		ReviewText           *string       `json:"review_text"`
		IsVerifiedEnrollment bool          `json:"is_verified_enrollment"`
		IsHelpfulCount       int           `json:"is_helpful_count"`
		CreatedAt            string        `json:"created_at"`
		UpdatedAt            string        `json:"updated_at"`
		User                 *supabaseUser `json:"user,omitempty"`
	}
	if err := json.Unmarshal(data, &reviews); err != nil {
		return nil, err
	}
	result := make([]*models.CourseReview, len(reviews))
	for i, rev := range reviews {
		review := &models.CourseReview{
			ID:                   rev.ID,
			CourseID:             rev.CourseID,
			UserID:               rev.UserID,
			Rating:               rev.Rating,
			Title:                rev.Title,
			ReviewText:           rev.ReviewText,
			IsVerifiedEnrollment: rev.IsVerifiedEnrollment,
			IsHelpfulCount:       rev.IsHelpfulCount,
			CreatedAt:            parseCourseTime(rev.CreatedAt),
			UpdatedAt:            parseCourseTime(rev.UpdatedAt),
		}
		if rev.User != nil {
			user, err := rev.User.toUser()
			if err == nil {
				review.User = user
			}
		}
		result[i] = review
	}
	return result, nil
}

func (r *SupabaseCourseRepository) UpdateReview(ctx context.Context, review *models.CourseReview) error {
	payload := map[string]interface{}{
		"rating":      review.Rating,
		"title":       review.Title,
		"review_text": review.ReviewText,
		"updated_at":  time.Now().Format(time.RFC3339),
	}
	query := fmt.Sprintf("?id=eq.%s", review.ID.String())
	_, err := r.makeRequest("PATCH", "course_reviews", query, payload)
	return err
}

func (r *SupabaseCourseRepository) DeleteReview(ctx context.Context, courseID, userID uuid.UUID) error {
	query := fmt.Sprintf("?course_id=eq.%s&user_id=eq.%s", courseID.String(), userID.String())
	_, err := r.makeRequest("DELETE", "course_reviews", query, nil)
	return err
}

// Learning Materials methods
func (r *SupabaseCourseRepository) CreateMaterial(ctx context.Context, material *models.LearningMaterial) error {
	if material.Slug == "" {
		material.Slug = generateSlug(material.Title)
	}
	payload := map[string]interface{}{
		"creator_id":      material.CreatorID,
		"title":           material.Title,
		"slug":            material.Slug,
		"description":     material.Description,
		"cover_image_url": material.CoverImageURL,
		"material_type":   material.MaterialType,
		"category":        material.Category,
		"tags":            []string(material.Tags),
		"content":         material.Content,
		"file_url":        material.FileURL,
		"external_url":    material.ExternalURL,
		"is_free":         material.IsFree,
		"price":           material.Price,
		"currency":        material.Currency,
		"is_public":       material.IsPublic,
		"status":          material.Status,
	}
	if material.Status == "published" {
		now := time.Now().Format(time.RFC3339)
		payload["published_at"] = now
	}
	data, err := r.makeRequest("POST", "learning_materials", "", payload)
	if err != nil {
		return err
	}
	var created struct {
		ID        uuid.UUID `json:"id"`
		CreatedAt string    `json:"created_at"`
		UpdatedAt string    `json:"updated_at"`
	}
	if err := json.Unmarshal(data, &created); err != nil {
		return err
	}
	material.ID = created.ID
	material.CreatedAt = parseCourseTime(created.CreatedAt)
	material.UpdatedAt = parseCourseTime(created.UpdatedAt)
	return nil
}

func (r *SupabaseCourseRepository) GetMaterialByID(ctx context.Context, id uuid.UUID) (*models.LearningMaterial, error) {
	query := fmt.Sprintf("?id=eq.%s&select=*,creator:users!learning_materials_creator_id_fkey(id,username,display_name,profile_picture,is_verified)", id.String())
	data, err := r.makeRequest("GET", "learning_materials", query, nil)
	if err != nil {
		return nil, err
	}
	var materials []struct {
		ID            uuid.UUID     `json:"id"`
		CreatorID     uuid.UUID     `json:"creator_id"`
		Title         string        `json:"title"`
		Slug          string        `json:"slug"`
		Description   *string       `json:"description"`
		CoverImageURL *string       `json:"cover_image_url"`
		MaterialType  string        `json:"material_type"`
		Category      *string       `json:"category"`
		Tags          []string      `json:"tags"`
		Content       *string       `json:"content"`
		FileURL       *string       `json:"file_url"`
		ExternalURL   *string       `json:"external_url"`
		IsFree        bool          `json:"is_free"`
		Price         *float64      `json:"price"`
		Currency      string        `json:"currency"`
		IsPublic      bool          `json:"is_public"`
		ViewCount     int           `json:"view_count"`
		DownloadCount int           `json:"download_count"`
		LikeCount     int           `json:"like_count"`
		Status        string        `json:"status"`
		PublishedAt   *string       `json:"published_at"`
		CreatedAt     string        `json:"created_at"`
		UpdatedAt     string        `json:"updated_at"`
		Creator       *supabaseUser `json:"creator,omitempty"`
	}
	if err := json.Unmarshal(data, &materials); err != nil {
		return nil, err
	}
	if len(materials) == 0 {
		return nil, fmt.Errorf("material not found")
	}
	m := materials[0]
	material := &models.LearningMaterial{
		ID:            m.ID,
		CreatorID:     m.CreatorID,
		Title:         m.Title,
		Slug:          m.Slug,
		Description:   m.Description,
		CoverImageURL: m.CoverImageURL,
		MaterialType:  m.MaterialType,
		Category:      m.Category,
		Tags:          pq.StringArray(m.Tags),
		Content:       m.Content,
		FileURL:       m.FileURL,
		ExternalURL:   m.ExternalURL,
		IsFree:        m.IsFree,
		Price:         m.Price,
		Currency:      m.Currency,
		IsPublic:      m.IsPublic,
		ViewCount:     m.ViewCount,
		DownloadCount: m.DownloadCount,
		LikeCount:     m.LikeCount,
		Status:        m.Status,
		CreatedAt:     parseCourseTime(m.CreatedAt),
		UpdatedAt:     parseCourseTime(m.UpdatedAt),
	}
	if m.PublishedAt != nil {
		publishedAt := parseCourseTime(*m.PublishedAt)
		material.PublishedAt = &publishedAt
	}
	if m.Creator != nil {
		creator, err := m.Creator.toUser()
		if err == nil {
			material.Creator = creator
		}
	}
	return material, nil
}

func (r *SupabaseCourseRepository) GetMaterialBySlug(ctx context.Context, slug string) (*models.LearningMaterial, error) {
	query := fmt.Sprintf("?slug=eq.%s&select=*,creator:users!learning_materials_creator_id_fkey(id,username,display_name,profile_picture,is_verified)", url.QueryEscape(slug))
	data, err := r.makeRequest("GET", "learning_materials", query, nil)
	if err != nil {
		return nil, err
	}
	var materials []struct {
		ID            uuid.UUID     `json:"id"`
		CreatorID     uuid.UUID     `json:"creator_id"`
		Title         string        `json:"title"`
		Slug          string        `json:"slug"`
		Description   *string       `json:"description"`
		CoverImageURL *string       `json:"cover_image_url"`
		MaterialType  string        `json:"material_type"`
		Category      *string       `json:"category"`
		Tags          []string      `json:"tags"`
		Content       *string       `json:"content"`
		FileURL       *string       `json:"file_url"`
		ExternalURL   *string       `json:"external_url"`
		IsFree        bool          `json:"is_free"`
		Price         *float64      `json:"price"`
		Currency      string        `json:"currency"`
		IsPublic      bool          `json:"is_public"`
		ViewCount     int           `json:"view_count"`
		DownloadCount int           `json:"download_count"`
		LikeCount     int           `json:"like_count"`
		Status        string        `json:"status"`
		PublishedAt   *string       `json:"published_at"`
		CreatedAt     string        `json:"created_at"`
		UpdatedAt     string        `json:"updated_at"`
		Creator       *supabaseUser `json:"creator,omitempty"`
	}
	if err := json.Unmarshal(data, &materials); err != nil {
		return nil, err
	}
	if len(materials) == 0 {
		return nil, fmt.Errorf("material not found")
	}
	m := materials[0]
	material := &models.LearningMaterial{
		ID:            m.ID,
		CreatorID:     m.CreatorID,
		Title:         m.Title,
		Slug:          m.Slug,
		Description:   m.Description,
		CoverImageURL: m.CoverImageURL,
		MaterialType:  m.MaterialType,
		Category:      m.Category,
		Tags:          pq.StringArray(m.Tags),
		Content:       m.Content,
		FileURL:       m.FileURL,
		ExternalURL:   m.ExternalURL,
		IsFree:        m.IsFree,
		Price:         m.Price,
		Currency:      m.Currency,
		IsPublic:      m.IsPublic,
		ViewCount:     m.ViewCount,
		DownloadCount: m.DownloadCount,
		LikeCount:     m.LikeCount,
		Status:        m.Status,
		CreatedAt:     parseCourseTime(m.CreatedAt),
		UpdatedAt:     parseCourseTime(m.UpdatedAt),
	}
	if m.PublishedAt != nil {
		publishedAt := parseCourseTime(*m.PublishedAt)
		material.PublishedAt = &publishedAt
	}
	if m.Creator != nil {
		creator, err := m.Creator.toUser()
		if err == nil {
			material.Creator = creator
		}
	}
	return material, nil
}

func (r *SupabaseCourseRepository) UpdateMaterial(ctx context.Context, material *models.LearningMaterial) error {
	payload := map[string]interface{}{
		"title":           material.Title,
		"description":     material.Description,
		"cover_image_url": material.CoverImageURL,
		"category":        material.Category,
		"tags":            []string(material.Tags),
		"content":         material.Content,
		"file_url":        material.FileURL,
		"external_url":    material.ExternalURL,
		"is_free":         material.IsFree,
		"price":           material.Price,
		"is_public":       material.IsPublic,
		"status":          material.Status,
		"updated_at":      time.Now().Format(time.RFC3339),
	}
	if material.Status == "published" && material.PublishedAt == nil {
		now := time.Now().Format(time.RFC3339)
		payload["published_at"] = now
	}
	query := fmt.Sprintf("?id=eq.%s", material.ID.String())
	_, err := r.makeRequest("PATCH", "learning_materials", query, payload)
	return err
}

func (r *SupabaseCourseRepository) DeleteMaterial(ctx context.Context, id uuid.UUID) error {
	query := fmt.Sprintf("?id=eq.%s", id.String())
	_, err := r.makeRequest("DELETE", "learning_materials", query, nil)
	return err
}

func (r *SupabaseCourseRepository) ListMaterials(ctx context.Context, filter *models.CourseFilter, userID *uuid.UUID) ([]*models.LearningMaterial, error) {
	var queryParams []string
	queryParams = append(queryParams, "status=eq.published")
	if userID == nil {
		queryParams = append(queryParams, "is_public=eq.true")
	}
	if filter.Category != nil {
		queryParams = append(queryParams, fmt.Sprintf("category=eq.%s", url.QueryEscape(*filter.Category)))
	}
	if filter.Search != nil {
		queryParams = append(queryParams, fmt.Sprintf("or=(title.ilike.*%s*,description.ilike.*%s*)", url.QueryEscape(*filter.Search), url.QueryEscape(*filter.Search)))
	}
	query := strings.Join(queryParams, "&")
	sortBy := "created_at.desc"
	if filter.SortBy == "popular" {
		sortBy = "view_count.desc"
	}
	query = fmt.Sprintf("?%s&select=*,creator:users!learning_materials_creator_id_fkey(id,username,display_name,profile_picture,is_verified)&order=%s&limit=%d&offset=%d",
		query, sortBy, filter.Limit, filter.Offset)
	data, err := r.makeRequest("GET", "learning_materials", query, nil)
	if err != nil {
		return nil, err
	}
	var materials []struct {
		ID            uuid.UUID     `json:"id"`
		CreatorID     uuid.UUID     `json:"creator_id"`
		Title         string        `json:"title"`
		Slug          string        `json:"slug"`
		Description   *string       `json:"description"`
		CoverImageURL *string       `json:"cover_image_url"`
		MaterialType  string        `json:"material_type"`
		Category      *string       `json:"category"`
		Tags          []string      `json:"tags"`
		IsFree        bool          `json:"is_free"`
		Price         *float64      `json:"price"`
		Currency      string        `json:"currency"`
		ViewCount     int           `json:"view_count"`
		DownloadCount int           `json:"download_count"`
		LikeCount     int           `json:"like_count"`
		Status        string        `json:"status"`
		CreatedAt     string        `json:"created_at"`
		UpdatedAt     string        `json:"updated_at"`
		Creator       *supabaseUser `json:"creator,omitempty"`
	}
	if err := json.Unmarshal(data, &materials); err != nil {
		return nil, err
	}
	result := make([]*models.LearningMaterial, len(materials))
	for i, m := range materials {
		material := &models.LearningMaterial{
			ID:            m.ID,
			CreatorID:     m.CreatorID,
			Title:         m.Title,
			Slug:          m.Slug,
			Description:   m.Description,
			CoverImageURL: m.CoverImageURL,
			MaterialType:  m.MaterialType,
			Category:      m.Category,
			Tags:          pq.StringArray(m.Tags),
			IsFree:        m.IsFree,
			Price:         m.Price,
			Currency:      m.Currency,
			ViewCount:     m.ViewCount,
			DownloadCount: m.DownloadCount,
			LikeCount:     m.LikeCount,
			Status:        m.Status,
			CreatedAt:     parseCourseTime(m.CreatedAt),
			UpdatedAt:     parseCourseTime(m.UpdatedAt),
		}
		if m.Creator != nil {
			creator, err := m.Creator.toUser()
			if err == nil {
				material.Creator = creator
			}
		}
		result[i] = material
	}
	return result, nil
}

func (r *SupabaseCourseRepository) IncrementMaterialViewCount(ctx context.Context, materialID uuid.UUID) error {
	material, err := r.GetMaterialByID(ctx, materialID)
	if err != nil {
		return err
	}
	payload := map[string]interface{}{
		"view_count": material.ViewCount + 1,
	}
	query := fmt.Sprintf("?id=eq.%s", materialID.String())
	_, err = r.makeRequest("PATCH", "learning_materials", query, payload)
	return err
}

func (r *SupabaseCourseRepository) IncrementMaterialDownloadCount(ctx context.Context, materialID uuid.UUID) error {
	material, err := r.GetMaterialByID(ctx, materialID)
	if err != nil {
		return err
	}
	payload := map[string]interface{}{
		"download_count": material.DownloadCount + 1,
	}
	query := fmt.Sprintf("?id=eq.%s", materialID.String())
	_, err = r.makeRequest("PATCH", "learning_materials", query, payload)
	return err
}

// Progress methods (stubs)
func (r *SupabaseCourseRepository) CreateOrUpdateProgress(ctx context.Context, progress *models.LessonProgress) error {
	// Check if progress exists
	existing, _ := r.GetProgress(ctx, progress.EnrollmentID, progress.LessonID)
	if existing != nil {
		return r.UpdateProgress(ctx, progress)
	}
	payload := map[string]interface{}{
		"enrollment_id":         progress.EnrollmentID,
		"lesson_id":             progress.LessonID,
		"user_id":               progress.UserID,
		"course_id":             progress.CourseID,
		"is_completed":          progress.IsCompleted,
		"completion_percentage": progress.CompletionPercentage,
		"time_spent":            progress.TimeSpent,
		"last_position":         progress.LastPosition,
		"last_accessed_at":      time.Now().Format(time.RFC3339),
	}
	if progress.StartedAt != nil {
		payload["started_at"] = progress.StartedAt.Format(time.RFC3339)
	}
	if progress.IsCompleted && progress.CompletedAt != nil {
		payload["completed_at"] = progress.CompletedAt.Format(time.RFC3339)
	}
	data, err := r.makeRequest("POST", "lesson_progress", "", payload)
	if err != nil {
		return err
	}
	var created struct {
		ID             uuid.UUID `json:"id"`
		LastAccessedAt string    `json:"last_accessed_at"`
	}
	if err := json.Unmarshal(data, &created); err != nil {
		return err
	}
	progress.ID = created.ID
	progress.LastAccessedAt = parseCourseTime(created.LastAccessedAt)
	return nil
}

func (r *SupabaseCourseRepository) GetProgress(ctx context.Context, enrollmentID, lessonID uuid.UUID) (*models.LessonProgress, error) {
	query := fmt.Sprintf("?enrollment_id=eq.%s&lesson_id=eq.%s&select=*", enrollmentID.String(), lessonID.String())
	data, err := r.makeRequest("GET", "lesson_progress", query, nil)
	if err != nil {
		return nil, err
	}
	var progresses []struct {
		ID                   uuid.UUID `json:"id"`
		EnrollmentID         uuid.UUID `json:"enrollment_id"`
		LessonID             uuid.UUID `json:"lesson_id"`
		UserID               uuid.UUID `json:"user_id"`
		CourseID             uuid.UUID `json:"course_id"`
		IsCompleted          bool      `json:"is_completed"`
		CompletionPercentage float64   `json:"completion_percentage"`
		TimeSpent            int       `json:"time_spent"`
		LastPosition         int       `json:"last_position"`
		StartedAt            *string   `json:"started_at"`
		CompletedAt          *string   `json:"completed_at"`
		LastAccessedAt       string    `json:"last_accessed_at"`
	}
	if err := json.Unmarshal(data, &progresses); err != nil {
		return nil, err
	}
	if len(progresses) == 0 {
		return nil, nil
	}
	p := progresses[0]
	progress := &models.LessonProgress{
		ID:                   p.ID,
		EnrollmentID:         p.EnrollmentID,
		LessonID:             p.LessonID,
		UserID:               p.UserID,
		CourseID:             p.CourseID,
		IsCompleted:          p.IsCompleted,
		CompletionPercentage: p.CompletionPercentage,
		TimeSpent:            p.TimeSpent,
		LastPosition:         p.LastPosition,
		LastAccessedAt:       parseCourseTime(p.LastAccessedAt),
	}
	if p.StartedAt != nil {
		startedAt := parseCourseTime(*p.StartedAt)
		progress.StartedAt = &startedAt
	}
	if p.CompletedAt != nil {
		completedAt := parseCourseTime(*p.CompletedAt)
		progress.CompletedAt = &completedAt
	}
	return progress, nil
}

func (r *SupabaseCourseRepository) GetProgressByEnrollment(ctx context.Context, enrollmentID uuid.UUID) ([]*models.LessonProgress, error) {
	query := fmt.Sprintf("?enrollment_id=eq.%s&select=*", enrollmentID.String())
	data, err := r.makeRequest("GET", "lesson_progress", query, nil)
	if err != nil {
		return nil, err
	}
	var progresses []struct {
		ID                   uuid.UUID `json:"id"`
		EnrollmentID         uuid.UUID `json:"enrollment_id"`
		LessonID             uuid.UUID `json:"lesson_id"`
		UserID               uuid.UUID `json:"user_id"`
		CourseID             uuid.UUID `json:"course_id"`
		IsCompleted          bool      `json:"is_completed"`
		CompletionPercentage float64   `json:"completion_percentage"`
		TimeSpent            int       `json:"time_spent"`
		LastPosition         int       `json:"last_position"`
		StartedAt            *string   `json:"started_at"`
		CompletedAt          *string   `json:"completed_at"`
		LastAccessedAt       string    `json:"last_accessed_at"`
	}
	if err := json.Unmarshal(data, &progresses); err != nil {
		return nil, err
	}
	result := make([]*models.LessonProgress, len(progresses))
	for i, p := range progresses {
		progress := &models.LessonProgress{
			ID:                   p.ID,
			EnrollmentID:         p.EnrollmentID,
			LessonID:             p.LessonID,
			UserID:               p.UserID,
			CourseID:             p.CourseID,
			IsCompleted:          p.IsCompleted,
			CompletionPercentage: p.CompletionPercentage,
			TimeSpent:            p.TimeSpent,
			LastPosition:         p.LastPosition,
			LastAccessedAt:       parseCourseTime(p.LastAccessedAt),
		}
		if p.StartedAt != nil {
			startedAt := parseCourseTime(*p.StartedAt)
			progress.StartedAt = &startedAt
		}
		if p.CompletedAt != nil {
			completedAt := parseCourseTime(*p.CompletedAt)
			progress.CompletedAt = &completedAt
		}
		result[i] = progress
	}
	return result, nil
}

func (r *SupabaseCourseRepository) UpdateProgress(ctx context.Context, progress *models.LessonProgress) error {
	payload := map[string]interface{}{
		"is_completed":          progress.IsCompleted,
		"completion_percentage": progress.CompletionPercentage,
		"time_spent":            progress.TimeSpent,
		"last_position":         progress.LastPosition,
		"last_accessed_at":      time.Now().Format(time.RFC3339),
	}
	if progress.CompletedAt != nil {
		payload["completed_at"] = progress.CompletedAt.Format(time.RFC3339)
	}
	query := fmt.Sprintf("?id=eq.%s", progress.ID.String())
	_, err := r.makeRequest("PATCH", "lesson_progress", query, payload)
	return err
}

// Certificate methods (stubs)
func (r *SupabaseCourseRepository) CreateCertificate(ctx context.Context, certificate *models.CourseCertificate) error {
	certNumber := fmt.Sprintf("AST-%s-%d", certificate.CourseID.String()[:8], time.Now().Unix())
	payload := map[string]interface{}{
		"enrollment_id":      certificate.EnrollmentID,
		"course_id":          certificate.CourseID,
		"user_id":            certificate.UserID,
		"certificate_number": certNumber,
		"certificate_url":    certificate.CertificateURL,
	}
	data, err := r.makeRequest("POST", "course_certificates", "", payload)
	if err != nil {
		return err
	}
	var created struct {
		ID       uuid.UUID `json:"id"`
		IssuedAt string    `json:"issued_at"`
	}
	if err := json.Unmarshal(data, &created); err != nil {
		return err
	}
	certificate.ID = created.ID
	certificate.CertificateNumber = certNumber
	certificate.IssuedAt = parseCourseTime(created.IssuedAt)
	return nil
}

func (r *SupabaseCourseRepository) GetCertificate(ctx context.Context, enrollmentID uuid.UUID) (*models.CourseCertificate, error) {
	query := fmt.Sprintf("?enrollment_id=eq.%s&select=*", enrollmentID.String())
	data, err := r.makeRequest("GET", "course_certificates", query, nil)
	if err != nil {
		return nil, err
	}
	var certificates []struct {
		ID                uuid.UUID `json:"id"`
		EnrollmentID      uuid.UUID `json:"enrollment_id"`
		CourseID          uuid.UUID `json:"course_id"`
		UserID            uuid.UUID `json:"user_id"`
		CertificateNumber string    `json:"certificate_number"`
		CertificateURL    *string   `json:"certificate_url"`
		IssuedAt          string    `json:"issued_at"`
	}
	if err := json.Unmarshal(data, &certificates); err != nil {
		return nil, err
	}
	if len(certificates) == 0 {
		return nil, nil
	}
	c := certificates[0]
	return &models.CourseCertificate{
		ID:                c.ID,
		EnrollmentID:      c.EnrollmentID,
		CourseID:          c.CourseID,
		UserID:            c.UserID,
		CertificateNumber: c.CertificateNumber,
		CertificateURL:    c.CertificateURL,
		IssuedAt:          parseCourseTime(c.IssuedAt),
	}, nil
}

func (r *SupabaseCourseRepository) GetCertificatesByUser(ctx context.Context, userID uuid.UUID) ([]*models.CourseCertificate, error) {
	query := fmt.Sprintf("?user_id=eq.%s&order=issued_at.desc&select=*", userID.String())
	data, err := r.makeRequest("GET", "course_certificates", query, nil)
	if err != nil {
		return nil, err
	}
	var certificates []struct {
		ID                uuid.UUID `json:"id"`
		EnrollmentID      uuid.UUID `json:"enrollment_id"`
		CourseID          uuid.UUID `json:"course_id"`
		UserID            uuid.UUID `json:"user_id"`
		CertificateNumber string    `json:"certificate_number"`
		CertificateURL    *string   `json:"certificate_url"`
		IssuedAt          string    `json:"issued_at"`
	}
	if err := json.Unmarshal(data, &certificates); err != nil {
		return nil, err
	}
	result := make([]*models.CourseCertificate, len(certificates))
	for i, c := range certificates {
		result[i] = &models.CourseCertificate{
			ID:                c.ID,
			EnrollmentID:      c.EnrollmentID,
			CourseID:          c.CourseID,
			UserID:            c.UserID,
			CertificateNumber: c.CertificateNumber,
			CertificateURL:    c.CertificateURL,
			IssuedAt:          parseCourseTime(c.IssuedAt),
		}
	}
	return result, nil
}

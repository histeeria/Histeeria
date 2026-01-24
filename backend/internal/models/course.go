package models

import (
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// Course represents a course in the learning platform
type Course struct {
	ID        uuid.UUID `json:"id"`
	CreatorID uuid.UUID `json:"creator_id"`
	Creator   *User     `json:"creator,omitempty"` // Populated via join

	// Basic Information
	Title            string  `json:"title"`
	Slug             string  `json:"slug"`
	Description      *string `json:"description,omitempty"`
	ShortDescription *string `json:"short_description,omitempty"`
	CoverImageURL    *string `json:"cover_image_url,omitempty"`
	ThumbnailURL     *string `json:"thumbnail_url,omitempty"`

	// Course Details
	Category        *string        `json:"category,omitempty"`
	Subcategory     *string        `json:"subcategory,omitempty"`
	Tags            pq.StringArray `json:"tags,omitempty"`
	DifficultyLevel string         `json:"difficulty_level"` // beginner, intermediate, advanced, expert
	Language        string         `json:"language"`         // en, es, fr, etc.

	// Pricing & Access
	IsFree           bool     `json:"is_free"`
	Price            *float64 `json:"price,omitempty"`
	Currency         string   `json:"currency"`
	IsPublic         bool     `json:"is_public"`
	RequiresApproval bool     `json:"requires_approval"`

	// Course Structure
	EstimatedDuration *int `json:"estimated_duration,omitempty"` // Total minutes
	TotalLessons      int  `json:"total_lessons"`
	TotalModules      int  `json:"total_modules"`

	// Metadata
	Status        string     `json:"status"` // draft, published, archived, pending_review
	PublishedAt   *time.Time `json:"published_at,omitempty"`
	LastUpdatedAt time.Time  `json:"last_updated_at"`
	CreatedAt     time.Time  `json:"created_at"`

	// Statistics
	EnrollmentCount int     `json:"enrollment_count"`
	CompletionCount int     `json:"completion_count"`
	AverageRating   float64 `json:"average_rating"` // 0.00 to 5.00
	ReviewCount     int     `json:"review_count"`
	ViewCount       int     `json:"view_count"`

	// SEO
	MetaTitle       *string `json:"meta_title,omitempty"`
	MetaDescription *string `json:"meta_description,omitempty"`

	// Computed fields
	IsEnrolled       bool              `json:"is_enrolled,omitempty"`     // For authenticated users
	Enrollment       *CourseEnrollment `json:"enrollment,omitempty"`      // If enrolled
	IsCollaborator   bool              `json:"is_collaborator,omitempty"` // If user is collaborator
	CollaboratorRole *string           `json:"collaborator_role,omitempty"`
}

// CourseModule represents a module within a course
type CourseModule struct {
	ID          uuid.UUID `json:"id"`
	CourseID    uuid.UUID `json:"course_id"`
	Title       string    `json:"title"`
	Description *string   `json:"description,omitempty"`
	OrderIndex  int       `json:"order_index"`
	IsPreview   bool      `json:"is_preview"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`

	// Populated fields
	Lessons []*CourseLesson `json:"lessons,omitempty"`
}

// CourseLesson represents a lesson within a course module
type CourseLesson struct {
	ID            uuid.UUID              `json:"id"`
	ModuleID      uuid.UUID              `json:"module_id"`
	CourseID      uuid.UUID              `json:"course_id"`
	Title         string                 `json:"title"`
	Description   *string                `json:"description,omitempty"`
	Content       *string                `json:"content,omitempty"` // Markdown/HTML
	VideoURL      *string                `json:"video_url,omitempty"`
	VideoDuration *int                   `json:"video_duration,omitempty"` // seconds
	OrderIndex    int                    `json:"order_index"`
	LessonType    string                 `json:"lesson_type"` // video, text, quiz, assignment, live, download
	IsPreview     bool                   `json:"is_preview"`
	Resources     map[string]interface{} `json:"resources,omitempty"` // JSONB
	Attachments   pq.StringArray         `json:"attachments,omitempty"`
	CreatedAt     time.Time              `json:"created_at"`
	UpdatedAt     time.Time              `json:"updated_at"`

	// Computed fields
	Progress *LessonProgress `json:"progress,omitempty"` // For enrolled users
}

// CourseEnrollment represents a user's enrollment in a course
type CourseEnrollment struct {
	ID                 uuid.UUID  `json:"id"`
	CourseID           uuid.UUID  `json:"course_id"`
	UserID             uuid.UUID  `json:"user_id"`
	User               *User      `json:"user,omitempty"`
	EnrolledAt         time.Time  `json:"enrolled_at"`
	CompletedAt        *time.Time `json:"completed_at,omitempty"`
	ProgressPercentage float64    `json:"progress_percentage"` // 0.00 to 100.00

	// Payment info
	PaymentStatus        string   `json:"payment_status"` // free, pending, paid, refunded
	PaymentAmount        *float64 `json:"payment_amount,omitempty"`
	PaymentCurrency      *string  `json:"payment_currency,omitempty"`
	PaymentTransactionID *string  `json:"payment_transaction_id,omitempty"`

	LastAccessedAt       *time.Time `json:"last_accessed_at,omitempty"`
	LastAccessedLessonID *uuid.UUID `json:"last_accessed_lesson_id,omitempty"`
}

// CourseCollaborator represents a collaborator on a course
type CourseCollaborator struct {
	ID          uuid.UUID      `json:"id"`
	CourseID    uuid.UUID      `json:"course_id"`
	UserID      uuid.UUID      `json:"user_id"`
	User        *User          `json:"user,omitempty"`
	Role        string         `json:"role"` // instructor, co-instructor, contributor, reviewer, moderator
	Permissions pq.StringArray `json:"permissions,omitempty"`
	InvitedBy   *uuid.UUID     `json:"invited_by,omitempty"`
	InvitedAt   *time.Time     `json:"invited_at,omitempty"`
	AcceptedAt  *time.Time     `json:"accepted_at,omitempty"`
	Status      string         `json:"status"` // pending, accepted, rejected, removed
	CreatedAt   time.Time      `json:"created_at"`
}

// CourseReview represents a review/rating for a course
type CourseReview struct {
	ID                   uuid.UUID `json:"id"`
	CourseID             uuid.UUID `json:"course_id"`
	UserID               uuid.UUID `json:"user_id"`
	User                 *User     `json:"user,omitempty"`
	Rating               int       `json:"rating"` // 1 to 5
	Title                *string   `json:"title,omitempty"`
	ReviewText           *string   `json:"review_text,omitempty"`
	IsVerifiedEnrollment bool      `json:"is_verified_enrollment"`
	IsHelpfulCount       int       `json:"is_helpful_count"`
	CreatedAt            time.Time `json:"created_at"`
	UpdatedAt            time.Time `json:"updated_at"`
}

// LearningMaterial represents a standalone learning resource
type LearningMaterial struct {
	ID            uuid.UUID      `json:"id"`
	CreatorID     uuid.UUID      `json:"creator_id"`
	Creator       *User          `json:"creator,omitempty"`
	Title         string         `json:"title"`
	Slug          string         `json:"slug"`
	Description   *string        `json:"description,omitempty"`
	CoverImageURL *string        `json:"cover_image_url,omitempty"`
	MaterialType  string         `json:"material_type"` // article, video, ebook, template, tool, worksheet, cheatsheet, infographic
	Category      *string        `json:"category,omitempty"`
	Tags          pq.StringArray `json:"tags,omitempty"`
	Content       *string        `json:"content,omitempty"`
	FileURL       *string        `json:"file_url,omitempty"`
	ExternalURL   *string        `json:"external_url,omitempty"`
	IsFree        bool           `json:"is_free"`
	Price         *float64       `json:"price,omitempty"`
	Currency      string         `json:"currency"`
	IsPublic      bool           `json:"is_public"`
	ViewCount     int            `json:"view_count"`
	DownloadCount int            `json:"download_count"`
	LikeCount     int            `json:"like_count"`
	Status        string         `json:"status"` // draft, published, archived
	PublishedAt   *time.Time     `json:"published_at,omitempty"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
}

// LessonProgress represents a user's progress on a specific lesson
type LessonProgress struct {
	ID                   uuid.UUID  `json:"id"`
	EnrollmentID         uuid.UUID  `json:"enrollment_id"`
	LessonID             uuid.UUID  `json:"lesson_id"`
	UserID               uuid.UUID  `json:"user_id"`
	CourseID             uuid.UUID  `json:"course_id"`
	IsCompleted          bool       `json:"is_completed"`
	CompletionPercentage float64    `json:"completion_percentage"` // 0.00 to 100.00
	TimeSpent            int        `json:"time_spent"`            // seconds
	LastPosition         int        `json:"last_position"`         // For video lessons
	StartedAt            *time.Time `json:"started_at,omitempty"`
	CompletedAt          *time.Time `json:"completed_at,omitempty"`
	LastAccessedAt       time.Time  `json:"last_accessed_at"`
}

// CourseCertificate represents a certificate issued for course completion
type CourseCertificate struct {
	ID                uuid.UUID `json:"id"`
	EnrollmentID      uuid.UUID `json:"enrollment_id"`
	CourseID          uuid.UUID `json:"course_id"`
	UserID            uuid.UUID `json:"user_id"`
	CertificateNumber string    `json:"certificate_number"`
	CertificateURL    *string   `json:"certificate_url,omitempty"`
	IssuedAt          time.Time `json:"issued_at"`
}

// Request/Response Models

// CreateCourseRequest represents the request to create a course
type CreateCourseRequest struct {
	Title             string   `json:"title" binding:"required,min=3,max=255"`
	Description       *string  `json:"description,omitempty"`
	ShortDescription  *string  `json:"short_description,omitempty"`
	Category          *string  `json:"category,omitempty"`
	Subcategory       *string  `json:"subcategory,omitempty"`
	Tags              []string `json:"tags,omitempty"`
	DifficultyLevel   string   `json:"difficulty_level"` // beginner, intermediate, advanced, expert
	Language          string   `json:"language"`
	IsFree            bool     `json:"is_free"`
	Price             *float64 `json:"price,omitempty"`
	Currency          string   `json:"currency"`
	IsPublic          bool     `json:"is_public"`
	RequiresApproval  bool     `json:"requires_approval"`
	EstimatedDuration *int     `json:"estimated_duration,omitempty"`
	MetaTitle         *string  `json:"meta_title,omitempty"`
	MetaDescription   *string  `json:"meta_description,omitempty"`
}

// UpdateCourseRequest represents the request to update a course
type UpdateCourseRequest struct {
	Title             *string  `json:"title,omitempty"`
	Description       *string  `json:"description,omitempty"`
	ShortDescription  *string  `json:"short_description,omitempty"`
	Category          *string  `json:"category,omitempty"`
	Subcategory       *string  `json:"subcategory,omitempty"`
	Tags              []string `json:"tags,omitempty"`
	DifficultyLevel   *string  `json:"difficulty_level,omitempty"`
	Language          *string  `json:"language,omitempty"`
	IsFree            *bool    `json:"is_free,omitempty"`
	Price             *float64 `json:"price,omitempty"`
	Currency          *string  `json:"currency,omitempty"`
	IsPublic          *bool    `json:"is_public,omitempty"`
	Status            *string  `json:"status,omitempty"`
	EstimatedDuration *int     `json:"estimated_duration,omitempty"`
	MetaTitle         *string  `json:"meta_title,omitempty"`
	MetaDescription   *string  `json:"meta_description,omitempty"`
}

// CourseFilter represents filters for listing courses
type CourseFilter struct {
	Category        *string  `json:"category,omitempty"`
	DifficultyLevel *string  `json:"difficulty_level,omitempty"`
	IsFree          *bool    `json:"is_free,omitempty"`
	Language        *string  `json:"language,omitempty"`
	Search          *string  `json:"search,omitempty"`
	Tags            []string `json:"tags,omitempty"`
	SortBy          string   `json:"sort_by"` // newest, popular, rating, price_asc, price_desc
	Limit           int      `json:"limit"`
	Offset          int      `json:"offset"`
}

// CreateModuleRequest represents the request to create a course module
type CreateModuleRequest struct {
	Title       string  `json:"title" binding:"required,min=3,max=255"`
	Description *string `json:"description,omitempty"`
	OrderIndex  int     `json:"order_index"`
	IsPreview   bool    `json:"is_preview"`
}

// CreateLessonRequest represents the request to create a course lesson
type CreateLessonRequest struct {
	Title         string                 `json:"title" binding:"required,min=3,max=255"`
	Description   *string                `json:"description,omitempty"`
	Content       *string                `json:"content,omitempty"`
	VideoURL      *string                `json:"video_url,omitempty"`
	VideoDuration *int                   `json:"video_duration,omitempty"`
	OrderIndex    int                    `json:"order_index"`
	LessonType    string                 `json:"lesson_type"` // video, text, quiz, assignment, live, download
	IsPreview     bool                   `json:"is_preview"`
	Resources     map[string]interface{} `json:"resources,omitempty"`
	Attachments   []string               `json:"attachments,omitempty"`
}

// CreateReviewRequest represents the request to create a course review
type CreateReviewRequest struct {
	Rating     int     `json:"rating" binding:"required,min=1,max=5"`
	Title      *string `json:"title,omitempty"`
	ReviewText *string `json:"review_text,omitempty"`
}

// CreateMaterialRequest represents the request to create a learning material
type CreateMaterialRequest struct {
	Title        string   `json:"title" binding:"required,min=3,max=255"`
	Description  *string  `json:"description,omitempty"`
	MaterialType string   `json:"material_type"` // article, video, ebook, template, tool, worksheet, cheatsheet, infographic
	Category     *string  `json:"category,omitempty"`
	Tags         []string `json:"tags,omitempty"`
	Content      *string  `json:"content,omitempty"`
	FileURL      *string  `json:"file_url,omitempty"`
	ExternalURL  *string  `json:"external_url,omitempty"`
	IsFree       bool     `json:"is_free"`
	Price        *float64 `json:"price,omitempty"`
	Currency     string   `json:"currency"`
	IsPublic     bool     `json:"is_public"`
}

// UpdateProgressRequest represents the request to update lesson progress
type UpdateProgressRequest struct {
	IsCompleted          *bool    `json:"is_completed,omitempty"`
	CompletionPercentage *float64 `json:"completion_percentage,omitempty"`
	TimeSpent            *int     `json:"time_spent,omitempty"`
	LastPosition         *int     `json:"last_position,omitempty"`
}

package repository

import (
	"context"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// CourseRepository defines the interface for course data operations
type CourseRepository interface {
	// Courses
	CreateCourse(ctx context.Context, course *models.Course) error
	GetCourseByID(ctx context.Context, id uuid.UUID) (*models.Course, error)
	GetCourseBySlug(ctx context.Context, slug string) (*models.Course, error)
	UpdateCourse(ctx context.Context, course *models.Course) error
	DeleteCourse(ctx context.Context, id uuid.UUID) error
	ListCourses(ctx context.Context, filter *models.CourseFilter, userID *uuid.UUID) ([]*models.Course, error)
	GetCoursesByCreator(ctx context.Context, creatorID uuid.UUID, limit, offset int) ([]*models.Course, error)
	GetEnrolledCourses(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.Course, error)
	IncrementViewCount(ctx context.Context, courseID uuid.UUID) error

	// Modules
	CreateModule(ctx context.Context, module *models.CourseModule) error
	GetModuleByID(ctx context.Context, id uuid.UUID) (*models.CourseModule, error)
	GetModulesByCourse(ctx context.Context, courseID uuid.UUID) ([]*models.CourseModule, error)
	UpdateModule(ctx context.Context, module *models.CourseModule) error
	DeleteModule(ctx context.Context, id uuid.UUID) error
	ReorderModules(ctx context.Context, courseID uuid.UUID, moduleOrders map[uuid.UUID]int) error

	// Lessons
	CreateLesson(ctx context.Context, lesson *models.CourseLesson) error
	GetLessonByID(ctx context.Context, id uuid.UUID) (*models.CourseLesson, error)
	GetLessonsByModule(ctx context.Context, moduleID uuid.UUID) ([]*models.CourseLesson, error)
	GetLessonsByCourse(ctx context.Context, courseID uuid.UUID) ([]*models.CourseLesson, error)
	UpdateLesson(ctx context.Context, lesson *models.CourseLesson) error
	DeleteLesson(ctx context.Context, id uuid.UUID) error
	ReorderLessons(ctx context.Context, moduleID uuid.UUID, lessonOrders map[uuid.UUID]int) error

	// Enrollments
	CreateEnrollment(ctx context.Context, enrollment *models.CourseEnrollment) error
	GetEnrollment(ctx context.Context, courseID, userID uuid.UUID) (*models.CourseEnrollment, error)
	GetEnrollmentByID(ctx context.Context, id uuid.UUID) (*models.CourseEnrollment, error)
	UpdateEnrollment(ctx context.Context, enrollment *models.CourseEnrollment) error
	GetEnrollmentsByCourse(ctx context.Context, courseID uuid.UUID, limit, offset int) ([]*models.CourseEnrollment, error)
	GetEnrollmentsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*models.CourseEnrollment, error)
	CheckEnrollment(ctx context.Context, courseID, userID uuid.UUID) (bool, error)

	// Collaborators
	CreateCollaborator(ctx context.Context, collaborator *models.CourseCollaborator) error
	GetCollaborator(ctx context.Context, courseID, userID uuid.UUID) (*models.CourseCollaborator, error)
	GetCollaboratorsByCourse(ctx context.Context, courseID uuid.UUID) ([]*models.CourseCollaborator, error)
	UpdateCollaborator(ctx context.Context, collaborator *models.CourseCollaborator) error
	DeleteCollaborator(ctx context.Context, courseID, userID uuid.UUID) error
	CheckCollaborator(ctx context.Context, courseID, userID uuid.UUID) (bool, error)

	// Reviews
	CreateReview(ctx context.Context, review *models.CourseReview) error
	GetReview(ctx context.Context, courseID, userID uuid.UUID) (*models.CourseReview, error)
	GetReviewsByCourse(ctx context.Context, courseID uuid.UUID, limit, offset int) ([]*models.CourseReview, error)
	UpdateReview(ctx context.Context, review *models.CourseReview) error
	DeleteReview(ctx context.Context, courseID, userID uuid.UUID) error

	// Learning Materials
	CreateMaterial(ctx context.Context, material *models.LearningMaterial) error
	GetMaterialByID(ctx context.Context, id uuid.UUID) (*models.LearningMaterial, error)
	GetMaterialBySlug(ctx context.Context, slug string) (*models.LearningMaterial, error)
	UpdateMaterial(ctx context.Context, material *models.LearningMaterial) error
	DeleteMaterial(ctx context.Context, id uuid.UUID) error
	ListMaterials(ctx context.Context, filter *models.CourseFilter, userID *uuid.UUID) ([]*models.LearningMaterial, error)
	IncrementMaterialViewCount(ctx context.Context, materialID uuid.UUID) error
	IncrementMaterialDownloadCount(ctx context.Context, materialID uuid.UUID) error

	// Progress
	CreateOrUpdateProgress(ctx context.Context, progress *models.LessonProgress) error
	GetProgress(ctx context.Context, enrollmentID, lessonID uuid.UUID) (*models.LessonProgress, error)
	GetProgressByEnrollment(ctx context.Context, enrollmentID uuid.UUID) ([]*models.LessonProgress, error)
	UpdateProgress(ctx context.Context, progress *models.LessonProgress) error

	// Certificates
	CreateCertificate(ctx context.Context, certificate *models.CourseCertificate) error
	GetCertificate(ctx context.Context, enrollmentID uuid.UUID) (*models.CourseCertificate, error)
	GetCertificatesByUser(ctx context.Context, userID uuid.UUID) ([]*models.CourseCertificate, error)
}

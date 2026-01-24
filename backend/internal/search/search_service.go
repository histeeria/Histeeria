package search

import (
	"context"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	
	"github.com/google/uuid"
)

// SearchService handles search business logic
type SearchService struct {
	userRepo repository.UserRepository
	postRepo repository.PostRepository
}

// NewSearchService creates a new search service
func NewSearchService(userRepo repository.UserRepository, postRepo repository.PostRepository) *SearchService {
	return &SearchService{
		userRepo: userRepo,
		postRepo: postRepo,
	}
}

// SearchUsers searches for users matching the query
func (s *SearchService) SearchUsers(ctx context.Context, query string, page int, limit int) ([]*models.User, int, error) {
	if limit <= 0 || limit > 100 {
		limit = 20 // Default limit
	}
	if page < 1 {
		page = 1
	}

	offset := (page - 1) * limit

	return s.userRepo.SearchUsers(ctx, query, limit, offset)
}

// SearchPosts searches for posts matching the query
func (s *SearchService) SearchPosts(ctx context.Context, query string, userID uuid.UUID, page int, limit int) ([]models.Post, int, error) {
	if limit <= 0 || limit > 100 {
		limit = 20 // Default limit
	}
	if page < 1 {
		page = 1
	}

	offset := (page - 1) * limit

	// Call the repository's SearchPosts (which matches the interface signature)
	return s.postRepo.SearchPosts(ctx, query, userID, limit, offset)
}

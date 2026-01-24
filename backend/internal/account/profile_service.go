package account

import (
	"context"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	apperr "histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// ProfileService handles profile-related business logic
type ProfileService struct {
	userRepo repository.UserRepository
}

// NewProfileService creates a new profile service
func NewProfileService(userRepo repository.UserRepository) *ProfileService {
	return &ProfileService{
		userRepo: userRepo,
	}
}

// GetPublicProfile retrieves a user's public profile with privacy filtering applied
func (s *ProfileService) GetPublicProfile(ctx context.Context, username string, viewerID *uuid.UUID) (*models.PublicProfileResponse, error) {
	// Fetch user by username
	user, err := s.userRepo.GetUserByUsername(ctx, username)
	if err != nil {
		return nil, err
	}

	// Check if viewer is the profile owner
	isOwner := false
	if viewerID != nil && *viewerID == user.ID {
		isOwner = true
	}

	// Apply privacy checks
	if !isOwner {
		// Check profile privacy level
		switch user.ProfilePrivacy {
		case "private":
			return nil, apperr.ErrForbidden // Private profiles can only be viewed by the owner
		case "connections":
			// TODO: In future, check if viewer is connected to this user
			// For now, treat connections-only profiles as public for logged-in users
			if viewerID == nil {
				return nil, apperr.ErrForbidden // Must be logged in to view connections-only profiles
			}
			// "public" and default: allow viewing
		}
	}

	// Filter fields based on visibility settings and privacy
	profile := filterProfileFields(user, isOwner)
	profile.IsOwnProfile = isOwner

	return profile, nil
}

// filterProfileFields applies field visibility rules and returns a filtered public profile
func filterProfileFields(user *models.User, isOwner bool) *models.PublicProfileResponse {
	profile := &models.PublicProfileResponse{
		ID:             user.ID,
		Username:       user.Username,
		DisplayName:    user.DisplayName,
		ProfilePicture: user.ProfilePicture,
		CoverPhoto:     user.CoverPhoto,
		IsVerified:     user.IsVerified,
		Bio:            user.Bio,
		JoinedAt:       user.CreatedAt,
		PostsCount:     user.PostsCount,
		ProjectsCount:  user.ProjectsCount,
		FollowersCount: user.FollowersCount,
		FollowingCount: user.FollowingCount,
	}

	// If owner, show all fields regardless of visibility settings
	if isOwner {
		profile.Location = user.Location
		profile.Gender = user.Gender
		profile.GenderCustom = user.GenderCustom
		if user.Age > 0 {
			profile.Age = &user.Age
		}
		profile.Website = user.Website
		profile.Story = user.Story
		profile.Ambition = user.Ambition
		profile.SocialLinks = user.SocialLinks
		profile.ProfilePrivacy = &user.ProfilePrivacy // Only send to owner
		profile.StatVisibility = user.StatVisibility  // Only send to owner
		return profile
	}

	// For non-owners, respect field visibility settings
	if user.FieldVisibility != nil {
		if user.FieldVisibility["location"] {
			profile.Location = user.Location
		}
		if user.FieldVisibility["gender"] {
			profile.Gender = user.Gender
			profile.GenderCustom = user.GenderCustom
		}
		if user.FieldVisibility["age"] && user.Age > 0 {
			profile.Age = &user.Age
		}
		if user.FieldVisibility["website"] {
			profile.Website = user.Website
		}
		// joined_date visibility is checked but we always show it in this implementation
		// email is never shown in public profile
	} else {
		// Default visibility: show all fields if no visibility settings exist
		profile.Location = user.Location
		profile.Gender = user.Gender
		profile.GenderCustom = user.GenderCustom
		if user.Age > 0 {
			profile.Age = &user.Age
		}
		profile.Website = user.Website
	}

	// Story and Ambition are always visible if they exist (part of public "About" section)
	profile.Story = user.Story
	profile.Ambition = user.Ambition

	// Social links are always public (they're meant to be shared)
	profile.SocialLinks = user.SocialLinks

	return profile
}

// UpdateBasicProfile updates basic profile information
func (s *ProfileService) UpdateBasicProfile(ctx context.Context, userID uuid.UUID, req *models.UpdateBasicProfileRequest) error {
	// Validate gender custom field
	if req.Gender != nil && *req.Gender == "custom" {
		if req.GenderCustom == nil || *req.GenderCustom == "" {
			return apperr.New(apperr.ErrBadRequest.Code, "Custom gender text is required when gender is 'custom'")
		}
	}

	return s.userRepo.UpdateBasicProfile(ctx, userID, req)
}

// UpdatePrivacySettings updates user privacy settings
func (s *ProfileService) UpdatePrivacySettings(ctx context.Context, userID uuid.UUID, req *models.UpdatePrivacySettingsRequest) error {
	return s.userRepo.UpdatePrivacySettings(ctx, userID, req)
}

// UpdateStory updates the user's story section
func (s *ProfileService) UpdateStory(ctx context.Context, userID uuid.UUID, story *string) error {
	return s.userRepo.UpdateStory(ctx, userID, story)
}

// UpdateAmbition updates the user's ambition section
func (s *ProfileService) UpdateAmbition(ctx context.Context, userID uuid.UUID, ambition *string) error {
	return s.userRepo.UpdateAmbition(ctx, userID, ambition)
}

// UpdateSocialLinks updates the user's social media links
func (s *ProfileService) UpdateSocialLinks(ctx context.Context, userID uuid.UUID, req *models.UpdateSocialLinksRequest) error {
	// Build social links map
	socialLinks := make(map[string]*string)
	socialLinks["twitter"] = req.Twitter
	socialLinks["instagram"] = req.Instagram
	socialLinks["facebook"] = req.Facebook
	socialLinks["linkedin"] = req.LinkedIn
	socialLinks["github"] = req.GitHub
	socialLinks["youtube"] = req.YouTube

	return s.userRepo.UpdateSocialLinks(ctx, userID, socialLinks)
}

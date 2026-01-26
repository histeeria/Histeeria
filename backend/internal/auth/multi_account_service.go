package auth

import (
	"context"
	"fmt"
	"log"
	"time"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	"histeeria-backend/internal/utils"
	"histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// MultiAccountService handles multi-account (Instagram-style) business logic
type MultiAccountService struct {
	accountGroupRepo repository.AccountGroupRepository
	userRepo         repository.UserRepository
	jwtSvc           *utils.JWTService
	authSvc          *AuthService
}

// NewMultiAccountService creates a new multi-account service
func NewMultiAccountService(
	accountGroupRepo repository.AccountGroupRepository,
	userRepo repository.UserRepository,
	jwtSvc *utils.JWTService,
	authSvc *AuthService,
) *MultiAccountService {
	return &MultiAccountService{
		accountGroupRepo: accountGroupRepo,
		userRepo:         userRepo,
		jwtSvc:           jwtSvc,
		authSvc:          authSvc,
	}
}

// LinkAccountRequest represents a request to link an account
type LinkAccountRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
}

// SwitchAccountResponse represents the response when switching accounts
type SwitchAccountResponse struct {
	Success   bool         `json:"success"`
	Message   string       `json:"message"`
	Token     string       `json:"token"`
	ExpiresAt string       `json:"expires_at"`
	User      *models.User `json:"user"`
}

// GetLinkedAccounts returns all accounts linked to the current user's account group
func (s *MultiAccountService) GetLinkedAccounts(ctx context.Context, currentUserID uuid.UUID) ([]repository.LinkedAccount, error) {
	accounts, err := s.accountGroupRepo.GetLinkedAccounts(ctx, currentUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to get linked accounts: %w", err)
	}

	return accounts, nil
}

// LinkAccount links another account to the current user's account group
// Requires password verification for the account being linked
func (s *MultiAccountService) LinkAccount(ctx context.Context, currentUserID uuid.UUID, req *LinkAccountRequest) (*SwitchAccountResponse, error) {
	// Get the account to link
	userToLink, err := s.userRepo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		return nil, errors.ErrInvalidCredentials
	}

	// Verify password
	if !utils.CheckPasswordHash(req.Password, userToLink.PasswordHash) {
		return nil, errors.ErrInvalidCredentials
	}

	// Check if user is already linked
	currentGroupID, err := s.accountGroupRepo.GetAccountGroupForUser(ctx, currentUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to get current account group: %w", err)
	}

	userToLinkGroupID, err := s.accountGroupRepo.GetAccountGroupForUser(ctx, userToLink.ID)
	if err != nil {
		return nil, fmt.Errorf("failed to get target account group: %w", err)
	}

	// If both users already have groups and they're the same, they're already linked
	if currentGroupID != nil && userToLinkGroupID != nil && *currentGroupID == *userToLinkGroupID {
		// Even if already linked, return the token for the linked account
		return s.SwitchAccount(ctx, currentUserID, userToLink.ID)
	}

	// If current user has no group, create one
	if currentGroupID == nil {
		groupID, err := s.accountGroupRepo.CreateAccountGroupWithUser(ctx, currentUserID, true)
		if err != nil {
			return nil, fmt.Errorf("failed to create account group: %w", err)
		}
		currentGroupID = groupID
	}

	// If user to link has a group, merge them (add all users from that group)
	if userToLinkGroupID != nil {
		// Get all accounts in the target group
		targetAccounts, err := s.accountGroupRepo.GetLinkedAccounts(ctx, userToLink.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to get target group accounts: %w", err)
		}

		// Add all accounts from target group to current group
		for _, account := range targetAccounts {
			err = s.accountGroupRepo.AddUserToAccountGroup(ctx, *currentGroupID, account.UserID, account.IsPrimary)
			if err != nil {
				log.Printf("[MultiAccountService] Warning: Failed to add account %s to group: %v", account.UserID, err)
			}
		}

		// Delete the old group (will be cleaned up by database function)
	} else {
		// User to link has no group, just add them
		err = s.accountGroupRepo.AddUserToAccountGroup(ctx, *currentGroupID, userToLink.ID, false)
		if err != nil {
			return nil, fmt.Errorf("failed to add user to account group: %w", err)
		}
	}

	// Return token for the linked account
	return s.SwitchAccount(ctx, currentUserID, userToLink.ID)
}

// SwitchAccount switches to another account in the same account group
// Returns a new token for the target account
func (s *MultiAccountService) SwitchAccount(ctx context.Context, currentUserID, targetUserID uuid.UUID) (*SwitchAccountResponse, error) {
	// Verify both users are in the same account group
	sameGroup, err := s.accountGroupRepo.VerifyUserInGroup(ctx, currentUserID, targetUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to verify account group: %w", err)
	}

	if !sameGroup {
		return nil, errors.ErrForbidden
	}

	// Get target user
	targetUser, err := s.userRepo.GetUserByID(ctx, targetUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to get target user: %w", err)
	}

	// Generate new token for target account
	token, err := s.jwtSvc.GenerateToken(targetUser)
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	// Update last login
	s.userRepo.UpdateLastLogin(ctx, targetUserID)

	return &SwitchAccountResponse{
		Success:   true,
		Message:   "Account switched successfully",
		Token:     token,
		ExpiresAt: time.Now().Add(30 * 24 * time.Hour).Format(time.RFC3339),
		User:      targetUser.ToSafeUser(),
	}, nil
}

// UnlinkAccount removes an account from the account group
func (s *MultiAccountService) UnlinkAccount(ctx context.Context, currentUserID, targetUserID uuid.UUID) error {
	// Verify both users are in the same account group
	sameGroup, err := s.accountGroupRepo.VerifyUserInGroup(ctx, currentUserID, targetUserID)
	if err != nil {
		return fmt.Errorf("failed to verify account group: %w", err)
	}

	if !sameGroup {
		return errors.ErrForbidden
	}

	// Get account group ID
	groupID, err := s.accountGroupRepo.GetAccountGroupForUser(ctx, currentUserID)
	if err != nil {
		return fmt.Errorf("failed to get account group: %w", err)
	}

	if groupID == nil {
		return fmt.Errorf("no account group found")
	}

	// Get all linked accounts
	accounts, err := s.accountGroupRepo.GetLinkedAccounts(ctx, currentUserID)
	if err != nil {
		return fmt.Errorf("failed to get linked accounts: %w", err)
	}

	// Prevent unlinking if it's the last account
	if len(accounts) <= 1 {
		return fmt.Errorf("cannot unlink the last account")
	}

	// Remove user from group
	err = s.accountGroupRepo.RemoveUserFromAccountGroup(ctx, *groupID, targetUserID)
	if err != nil {
		return fmt.Errorf("failed to remove user from account group: %w", err)
	}

	return nil
}

// SetPrimaryAccount sets which account is primary in the group
func (s *MultiAccountService) SetPrimaryAccount(ctx context.Context, currentUserID, targetUserID uuid.UUID) error {
	// Verify both users are in the same account group
	sameGroup, err := s.accountGroupRepo.VerifyUserInGroup(ctx, currentUserID, targetUserID)
	if err != nil {
		return fmt.Errorf("failed to verify account group: %w", err)
	}

	if !sameGroup {
		return errors.ErrForbidden
	}

	// Get account group ID
	groupID, err := s.accountGroupRepo.GetAccountGroupForUser(ctx, currentUserID)
	if err != nil {
		return fmt.Errorf("failed to get account group: %w", err)
	}

	if groupID == nil {
		return fmt.Errorf("no account group found")
	}

	// Set primary account
	err = s.accountGroupRepo.SetPrimaryAccount(ctx, *groupID, targetUserID)
	if err != nil {
		return fmt.Errorf("failed to set primary account: %w", err)
	}

	return nil
}

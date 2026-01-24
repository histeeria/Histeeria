package repository

import (
	"context"

	"github.com/google/uuid"
)

// LinkedAccount represents a linked account in an account group
type LinkedAccount struct {
	UserID       uuid.UUID `json:"user_id"`
	Username     string    `json:"username"`
	Email        string    `json:"email"`
	DisplayName  string    `json:"display_name"`
	ProfilePicture *string `json:"profile_picture,omitempty"`
	IsPrimary    bool      `json:"is_primary"`
	AddedAt      string    `json:"added_at"`
}

// AccountGroupRepository defines the data-access contract for account groups
type AccountGroupRepository interface {
	// GetAccountGroupForUser returns the account group ID for a user
	GetAccountGroupForUser(ctx context.Context, userID uuid.UUID) (*uuid.UUID, error)

	// GetLinkedAccounts returns all accounts linked to the user's account group
	GetLinkedAccounts(ctx context.Context, userID uuid.UUID) ([]LinkedAccount, error)

	// CreateAccountGroup creates a new account group and adds the first user
	CreateAccountGroupWithUser(ctx context.Context, userID uuid.UUID, isPrimary bool) (*uuid.UUID, error)

	// AddUserToAccountGroup adds a user to an existing account group
	AddUserToAccountGroup(ctx context.Context, groupID, userID uuid.UUID, isPrimary bool) error

	// RemoveUserFromAccountGroup removes a user from an account group
	RemoveUserFromAccountGroup(ctx context.Context, groupID, userID uuid.UUID) error

	// SetPrimaryAccount sets which account is primary in a group
	SetPrimaryAccount(ctx context.Context, groupID, userID uuid.UUID) error

	// VerifyUserInGroup checks if a user belongs to the same account group as another user
	VerifyUserInGroup(ctx context.Context, userID1, userID2 uuid.UUID) (bool, error)
}

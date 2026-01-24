package database

import (
	"context"
	"fmt"
	"strings"
	"time"

	"histeeria-backend/internal/config"
	"histeeria-backend/internal/models"
	"histeeria-backend/internal/repository"
	"histeeria-backend/pkg/errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Database represents the database connection and operations
type Database struct {
	pool *pgxpool.Pool
}

// NewDatabase creates a new database connection
func NewDatabase(config *config.DatabaseConfig) (*Database, error) {
	// For Supabase, we need to construct the connection string properly
	// Extract hostname from SUPABASE_URL (remove https:// if present)
	hostname := config.SupabaseURL
	if strings.HasPrefix(hostname, "https://") {
		hostname = strings.TrimPrefix(hostname, "https://")
	}

	// Supabase connection string format
	// You need to get the actual database password from Supabase settings
	connStr := fmt.Sprintf("postgresql://postgres:%s@%s:5432/postgres?sslmode=require",
		config.SupabaseServiceKey, // This should be the actual database password
		hostname)

	// Create connection pool
	pool, err := pgxpool.New(context.Background(), connStr)
	if err != nil {
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	// Test the connection
	if err := pool.Ping(context.Background()); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return &Database{pool: pool}, nil
}

// Close closes the database connection
func (db *Database) Close() {
	db.pool.Close()
}

// DEPRECATED: Inline repository replaced by internal/repository package
// This type alias is kept for backward compatibility but should not be used in new code.
// TODO: Remove this deprecated code after confirming no dependencies remain.
// Use repository.UserRepository directly instead.
type UserRepository = repository.UserRepository

// CreateUser creates a new user in the database
func (db *Database) CreateUser(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (
			id, email, username, password_hash, display_name, age,
			is_email_verified, email_verification_code, email_verification_expires_at,
			is_active, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
		)
	`

	_, err := db.pool.Exec(ctx, query,
		user.ID, user.Email, user.Username, user.PasswordHash, user.DisplayName, user.Age,
		user.IsEmailVerified, user.EmailVerificationCode, user.EmailVerificationExpiresAt,
		user.IsActive, user.CreatedAt, user.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}

	return nil
}

// GetUserByID retrieves a user by ID
func (db *Database) GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	query := `
		SELECT id, email, username, password_hash, display_name, age,
		       is_email_verified, email_verification_code, email_verification_expires_at,
		       password_reset_token, password_reset_expires_at, is_active,
		       last_login_at, created_at, updated_at
		FROM users WHERE id = $1
	`

	var user models.User
	err := db.pool.QueryRow(ctx, query, id).Scan(
		&user.ID, &user.Email, &user.Username, &user.PasswordHash, &user.DisplayName, &user.Age,
		&user.IsEmailVerified, &user.EmailVerificationCode, &user.EmailVerificationExpiresAt,
		&user.PasswordResetToken, &user.PasswordResetExpiresAt, &user.IsActive,
		&user.LastLoginAt, &user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, errors.ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to get user by ID: %w", err)
	}

	return &user, nil
}

// GetUserByEmail retrieves a user by email
func (db *Database) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	query := `
		SELECT id, email, username, password_hash, display_name, age,
		       is_email_verified, email_verification_code, email_verification_expires_at,
		       password_reset_token, password_reset_expires_at, is_active,
		       last_login_at, created_at, updated_at
		FROM users WHERE email = $1
	`

	var user models.User
	err := db.pool.QueryRow(ctx, query, email).Scan(
		&user.ID, &user.Email, &user.Username, &user.PasswordHash, &user.DisplayName, &user.Age,
		&user.IsEmailVerified, &user.EmailVerificationCode, &user.EmailVerificationExpiresAt,
		&user.PasswordResetToken, &user.PasswordResetExpiresAt, &user.IsActive,
		&user.LastLoginAt, &user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, errors.ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to get user by email: %w", err)
	}

	return &user, nil
}

// GetUserByUsername retrieves a user by username
func (db *Database) GetUserByUsername(ctx context.Context, username string) (*models.User, error) {
	query := `
		SELECT id, email, username, password_hash, display_name, age,
		       is_email_verified, email_verification_code, email_verification_expires_at,
		       password_reset_token, password_reset_expires_at, is_active,
		       last_login_at, created_at, updated_at
		FROM users WHERE username = $1
	`

	var user models.User
	err := db.pool.QueryRow(ctx, query, username).Scan(
		&user.ID, &user.Email, &user.Username, &user.PasswordHash, &user.DisplayName, &user.Age,
		&user.IsEmailVerified, &user.EmailVerificationCode, &user.EmailVerificationExpiresAt,
		&user.PasswordResetToken, &user.PasswordResetExpiresAt, &user.IsActive,
		&user.LastLoginAt, &user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, errors.ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to get user by username: %w", err)
	}

	return &user, nil
}

// GetUserByEmailOrUsername retrieves a user by email or username
func (db *Database) GetUserByEmailOrUsername(ctx context.Context, emailOrUsername string) (*models.User, error) {
	query := `
		SELECT id, email, username, password_hash, display_name, age,
		       is_email_verified, email_verification_code, email_verification_expires_at,
		       password_reset_token, password_reset_expires_at, is_active,
		       last_login_at, created_at, updated_at
		FROM users WHERE email = $1 OR username = $1
	`

	var user models.User
	err := db.pool.QueryRow(ctx, query, emailOrUsername).Scan(
		&user.ID, &user.Email, &user.Username, &user.PasswordHash, &user.DisplayName, &user.Age,
		&user.IsEmailVerified, &user.EmailVerificationCode, &user.EmailVerificationExpiresAt,
		&user.PasswordResetToken, &user.PasswordResetExpiresAt, &user.IsActive,
		&user.LastLoginAt, &user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, errors.ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to get user by email or username: %w", err)
	}

	return &user, nil
}

// UpdateUser updates a user in the database
func (db *Database) UpdateUser(ctx context.Context, user *models.User) error {
	query := `
		UPDATE users SET 
			email = $2, username = $3, password_hash = $4, display_name = $5, age = $6,
			is_email_verified = $7, email_verification_code = $8, email_verification_expires_at = $9,
			password_reset_token = $10, password_reset_expires_at = $11, is_active = $12,
			last_login_at = $13, updated_at = $14
		WHERE id = $1
	`

	_, err := db.pool.Exec(ctx, query,
		user.ID, user.Email, user.Username, user.PasswordHash, user.DisplayName, user.Age,
		user.IsEmailVerified, user.EmailVerificationCode, user.EmailVerificationExpiresAt,
		user.PasswordResetToken, user.PasswordResetExpiresAt, user.IsActive,
		user.LastLoginAt, user.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	return nil
}

// UpdateEmailVerification updates email verification code
func (db *Database) UpdateEmailVerification(ctx context.Context, email, code string, expiresAt time.Time) error {
	query := `
		UPDATE users SET 
			email_verification_code = $2, email_verification_expires_at = $3, updated_at = NOW()
		WHERE email = $1
	`

	result, err := db.pool.Exec(ctx, query, email, code, expiresAt)
	if err != nil {
		return fmt.Errorf("failed to update email verification: %w", err)
	}

	if result.RowsAffected() == 0 {
		return errors.ErrUserNotFound
	}

	return nil
}

// VerifyEmail verifies user email with code
func (db *Database) VerifyEmail(ctx context.Context, email, code string) error {
	query := `
		UPDATE users SET 
			is_email_verified = true, email_verification_code = NULL, 
			email_verification_expires_at = NULL, updated_at = NOW()
		WHERE email = $1 AND email_verification_code = $2 
		AND email_verification_expires_at > NOW()
	`

	result, err := db.pool.Exec(ctx, query, email, code)
	if err != nil {
		return fmt.Errorf("failed to verify email: %w", err)
	}

	if result.RowsAffected() == 0 {
		return errors.ErrInvalidVerificationCode
	}

	return nil
}

// UpdatePasswordReset updates password reset token
func (db *Database) UpdatePasswordReset(ctx context.Context, email, token string, expiresAt time.Time) error {
	query := `
		UPDATE users SET 
			password_reset_token = $2, password_reset_expires_at = $3, updated_at = NOW()
		WHERE email = $1
	`

	result, err := db.pool.Exec(ctx, query, email, token, expiresAt)
	if err != nil {
		return fmt.Errorf("failed to update password reset: %w", err)
	}

	if result.RowsAffected() == 0 {
		return errors.ErrUserNotFound
	}

	return nil
}

// ResetPassword resets user password
func (db *Database) ResetPassword(ctx context.Context, token, newPasswordHash string) error {
	query := `
		UPDATE users SET 
			password_hash = $2, password_reset_token = NULL, 
			password_reset_expires_at = NULL, updated_at = NOW()
		WHERE password_reset_token = $1 AND password_reset_expires_at > NOW()
	`

	result, err := db.pool.Exec(ctx, query, token, newPasswordHash)
	if err != nil {
		return fmt.Errorf("failed to reset password: %w", err)
	}

	if result.RowsAffected() == 0 {
		return errors.ErrInvalidResetToken
	}

	return nil
}

// UpdateLastLogin updates user's last login time
func (db *Database) UpdateLastLogin(ctx context.Context, userID uuid.UUID) error {
	query := `
		UPDATE users SET last_login_at = NOW(), updated_at = NOW()
		WHERE id = $1
	`

	_, err := db.pool.Exec(ctx, query, userID)
	if err != nil {
		return fmt.Errorf("failed to update last login: %w", err)
	}

	return nil
}

// CheckEmailExists checks if email already exists
func (db *Database) CheckEmailExists(ctx context.Context, email string) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)`

	var exists bool
	err := db.pool.QueryRow(ctx, query, email).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check email exists: %w", err)
	}

	return exists, nil
}

// CheckUsernameExists checks if username already exists
func (db *Database) CheckUsernameExists(ctx context.Context, username string) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)`

	var exists bool
	err := db.pool.QueryRow(ctx, query, username).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check username exists: %w", err)
	}

	return exists, nil
}

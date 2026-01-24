package utils

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"time"

	"histeeria-backend/internal/models"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// JWTService handles JWT token operations
type JWTService struct {
	secretKey []byte
	expiry    time.Duration
	blacklist *TokenBlacklist // Optional token blacklist
}

// NewJWTService creates a new JWT service
func NewJWTService(secretKey string, expiry time.Duration) *JWTService {
	return &JWTService{
		secretKey: []byte(secretKey),
		expiry:    expiry,
	}
}

// SetBlacklist sets the token blacklist for the JWT service
func (j *JWTService) SetBlacklist(blacklist *TokenBlacklist) {
	j.blacklist = blacklist
}

// GenerateToken generates a JWT token for a user
func (j *JWTService) GenerateToken(user *models.User) (string, error) {
	now := time.Now()
	claims := &models.JWTClaims{
		UserID:   user.ID.String(),
		Email:    user.Email,
		Username: user.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(j.expiry)),
			IssuedAt:  jwt.NewNumericDate(now),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(j.secretKey)
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

// ValidateToken validates a JWT token and returns the claims
func (j *JWTService) ValidateToken(tokenString string) (*models.JWTClaims, error) {
	// Check if token is blacklisted (before parsing to save resources)
	if j.blacklist != nil && j.blacklist.IsBlacklisted(tokenString) {
		return nil, errors.New("token has been revoked")
	}

	token, err := jwt.ParseWithClaims(tokenString, &models.JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		// Verify the signing method
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return j.secretKey, nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*models.JWTClaims); ok && token.Valid {
		// Check if token is expired
		if time.Now().After(claims.ExpiresAt.Time) {
			return nil, errors.New("token has expired")
		}
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

// ExtractUserIDFromToken extracts user ID from a JWT token
func (j *JWTService) ExtractUserIDFromToken(tokenString string) (uuid.UUID, error) {
	claims, err := j.ValidateToken(tokenString)
	if err != nil {
		return uuid.Nil, err
	}

	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return uuid.Nil, err
	}

	return userID, nil
}

// GenerateRefreshToken generates a refresh token (optional implementation)
func (j *JWTService) GenerateRefreshToken(user *models.User) (string, error) {
	// For now, we'll use the same token generation but with longer expiry
	// In production, you might want to use a different approach for refresh tokens
	now := time.Now()
	claims := &models.JWTClaims{
		UserID:   user.ID.String(),
		Email:    user.Email,
		Username: user.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(7 * 24 * time.Hour)), // 7 days
			IssuedAt:  jwt.NewNumericDate(now),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(j.secretKey)
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

// IsTokenExpired checks if a token is expired
func (j *JWTService) IsTokenExpired(tokenString string) bool {
	claims, err := j.ValidateToken(tokenString)
	if err != nil {
		return true
	}
	return time.Now().After(claims.ExpiresAt.Time)
}

// HashToken creates a SHA256 hash of a JWT token for storage
func HashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}

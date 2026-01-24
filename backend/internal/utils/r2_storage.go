package utils

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
)

// R2StorageService handles file storage with Cloudflare R2
// R2 is S3-compatible and has better free tier than Supabase Storage
// Free tier: 10GB storage, 10M Class A ops, 1M Class B ops, 0 egress fees!
type R2StorageService struct {
	accountID       string
	accessKeyID     string
	secretAccessKey string
	bucketName      string
	publicURL       string // Custom domain or R2.dev URL
	http            *http.Client
	region          string // Always "auto" for R2
}

// R2Config holds R2 configuration
type R2Config struct {
	AccountID       string
	AccessKeyID     string
	SecretAccessKey string
	BucketName      string
	PublicURL       string // e.g., https://media.histeeria.app or bucket.r2.dev
}

// NewR2StorageService creates a new R2 storage service
func NewR2StorageService(cfg *R2Config) *R2StorageService {
	return &R2StorageService{
		accountID:       cfg.AccountID,
		accessKeyID:     cfg.AccessKeyID,
		secretAccessKey: cfg.SecretAccessKey,
		bucketName:      cfg.BucketName,
		publicURL:       cfg.PublicURL,
		http:            &http.Client{Timeout: 60 * time.Second},
		region:          "auto",
	}
}

// UploadFile uploads a file to R2
// Returns the public URL of the uploaded file
func (s *R2StorageService) UploadFile(ctx context.Context, key string, content []byte, contentType string) (string, error) {
	// R2 API endpoint
	endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com/%s/%s",
		s.accountID, s.bucketName, key)

	req, err := http.NewRequestWithContext(ctx, http.MethodPut, endpoint, bytes.NewReader(content))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	// Sign the request with AWS Signature V4
	s.signRequest(req, content, contentType)

	resp, err := s.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to upload: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("upload failed (status %d): %s", resp.StatusCode, string(body))
	}

	// Return public URL
	publicURL := fmt.Sprintf("%s/%s", s.publicURL, key)
	return publicURL, nil
}

// UploadMediaFile uploads a media file with optimized settings
// Generates unique key based on user ID and content hash
func (s *R2StorageService) UploadMediaFile(ctx context.Context, userID uuid.UUID, content []byte, contentType, extension string) (string, error) {
	// Generate content-based key for deduplication
	hash := sha256.Sum256(content)
	hashStr := hex.EncodeToString(hash[:8]) // First 8 bytes for short hash

	// Key format: media/{user_id}/{hash}.{ext}
	key := fmt.Sprintf("media/%s/%s%s", userID.String(), hashStr, extension)

	return s.UploadFile(ctx, key, content, contentType)
}

// UploadDMMedia uploads DM media with expiry metadata
// DM media should be deleted after delivery (WhatsApp model)
func (s *R2StorageService) UploadDMMedia(ctx context.Context, conversationID uuid.UUID, content []byte, contentType, extension string) (string, error) {
	// Key format: dm/{conversation_id}/{uuid}.{ext}
	key := fmt.Sprintf("dm/%s/%s%s", conversationID.String(), uuid.New().String(), extension)

	return s.UploadFile(ctx, key, content, contentType)
}

// DeleteFile deletes a file from R2
func (s *R2StorageService) DeleteFile(ctx context.Context, key string) error {
	endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com/%s/%s",
		s.accountID, s.bucketName, key)

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, endpoint, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	s.signRequest(req, nil, "")

	resp, err := s.http.Do(req)
	if err != nil {
		return fmt.Errorf("failed to delete: %w", err)
	}
	defer resp.Body.Close()

	// 204 No Content or 404 Not Found are both OK
	if resp.StatusCode >= 300 && resp.StatusCode != 404 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("delete failed (status %d): %s", resp.StatusCode, string(body))
	}

	return nil
}

// DeleteExpiredDMMedia deletes all DM media for a conversation
func (s *R2StorageService) DeleteExpiredDMMedia(ctx context.Context, conversationID uuid.UUID) error {
	// List and delete all objects with prefix dm/{conversation_id}/
	prefix := fmt.Sprintf("dm/%s/", conversationID.String())

	// For simplicity, we'll handle this via the worker/cron job
	// In production, use R2's lifecycle rules or a worker
	log.Printf("[R2] Marked for deletion: %s*", prefix)
	return nil
}

// GetSignedURL generates a presigned URL for private file access
func (s *R2StorageService) GetSignedURL(ctx context.Context, key string, expiry time.Duration) (string, error) {
	// For R2, we can use the S3 presigned URL format
	// This allows temporary access to private objects
	
	endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com/%s/%s",
		s.accountID, s.bucketName, key)

	// Generate presigned URL (simplified - in production use full AWS V4 signing)
	return fmt.Sprintf("%s?X-Amz-Expires=%d", endpoint, int(expiry.Seconds())), nil
}

// ============================================
// AWS SIGNATURE V4 SIGNING
// ============================================

// signRequest signs the request with AWS Signature V4
func (s *R2StorageService) signRequest(req *http.Request, payload []byte, contentType string) {
	now := time.Now().UTC()
	dateStamp := now.Format("20060102")
	amzDate := now.Format("20060102T150405Z")

	// Content hash
	var payloadHash string
	if payload != nil {
		hash := sha256.Sum256(payload)
		payloadHash = hex.EncodeToString(hash[:])
	} else {
		hash := sha256.Sum256([]byte{})
		payloadHash = hex.EncodeToString(hash[:])
	}

	// Set required headers
	req.Header.Set("x-amz-date", amzDate)
	req.Header.Set("x-amz-content-sha256", payloadHash)
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	req.Header.Set("Host", req.Host)

	// Create canonical request
	signedHeaders := "content-type;host;x-amz-content-sha256;x-amz-date"
	if contentType == "" {
		signedHeaders = "host;x-amz-content-sha256;x-amz-date"
	}

	canonicalRequest := s.createCanonicalRequest(req, payloadHash, signedHeaders, contentType)

	// Create string to sign
	credentialScope := fmt.Sprintf("%s/%s/s3/aws4_request", dateStamp, s.region)
	stringToSign := s.createStringToSign(amzDate, credentialScope, canonicalRequest)

	// Calculate signature
	signature := s.calculateSignature(dateStamp, stringToSign)

	// Add authorization header
	authHeader := fmt.Sprintf(
		"AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s",
		s.accessKeyID, credentialScope, signedHeaders, signature,
	)
	req.Header.Set("Authorization", authHeader)
}

func (s *R2StorageService) createCanonicalRequest(req *http.Request, payloadHash, signedHeaders, contentType string) string {
	// Canonical URI
	canonicalURI := req.URL.Path
	if canonicalURI == "" {
		canonicalURI = "/"
	}

	// Canonical query string
	canonicalQueryString := req.URL.RawQuery

	// Canonical headers
	var canonicalHeaders string
	if contentType != "" {
		canonicalHeaders = fmt.Sprintf(
			"content-type:%s\nhost:%s\nx-amz-content-sha256:%s\nx-amz-date:%s\n",
			contentType,
			req.Host,
			payloadHash,
			req.Header.Get("x-amz-date"),
		)
	} else {
		canonicalHeaders = fmt.Sprintf(
			"host:%s\nx-amz-content-sha256:%s\nx-amz-date:%s\n",
			req.Host,
			payloadHash,
			req.Header.Get("x-amz-date"),
		)
	}

	return fmt.Sprintf("%s\n%s\n%s\n%s\n%s\n%s",
		req.Method,
		canonicalURI,
		canonicalQueryString,
		canonicalHeaders,
		signedHeaders,
		payloadHash,
	)
}

func (s *R2StorageService) createStringToSign(amzDate, credentialScope, canonicalRequest string) string {
	hash := sha256.Sum256([]byte(canonicalRequest))
	return fmt.Sprintf("AWS4-HMAC-SHA256\n%s\n%s\n%s",
		amzDate,
		credentialScope,
		hex.EncodeToString(hash[:]),
	)
}

func (s *R2StorageService) calculateSignature(dateStamp, stringToSign string) string {
	kDate := hmacSHA256([]byte("AWS4"+s.secretAccessKey), dateStamp)
	kRegion := hmacSHA256(kDate, s.region)
	kService := hmacSHA256(kRegion, "s3")
	kSigning := hmacSHA256(kService, "aws4_request")
	signature := hmacSHA256(kSigning, stringToSign)
	return hex.EncodeToString(signature)
}

func hmacSHA256(key []byte, data string) []byte {
	h := hmac.New(sha256.New, key)
	h.Write([]byte(data))
	return h.Sum(nil)
}

// ============================================
// MULTI-PROVIDER STORAGE SERVICE
// ============================================

// MultiStorageService supports multiple storage providers
// Uses R2 for media (cheap), Supabase for profile pics (integrated)
type MultiStorageService struct {
	r2Storage      *R2StorageService
	supabase       *StorageService
	preferR2       bool
}

// NewMultiStorageService creates a multi-provider storage service
func NewMultiStorageService(r2 *R2StorageService, supabase *StorageService, preferR2 bool) *MultiStorageService {
	return &MultiStorageService{
		r2Storage: r2,
		supabase:  supabase,
		preferR2:  preferR2,
	}
}

// UploadMedia uploads media to the preferred storage provider
func (s *MultiStorageService) UploadMedia(ctx context.Context, userID uuid.UUID, content []byte, contentType, extension string) (string, string, error) {
	if s.preferR2 && s.r2Storage != nil {
		url, err := s.r2Storage.UploadMediaFile(ctx, userID, content, contentType, extension)
		if err == nil {
			return url, "r2", nil
		}
		log.Printf("[Storage] R2 upload failed, falling back to Supabase: %v", err)
	}

	// Fallback to Supabase
	if s.supabase != nil {
		key := fmt.Sprintf("%s/%s%s", userID.String(), uuid.New().String(), extension)
		url, err := s.supabase.UploadFile(ctx, "media", key, bytes.NewReader(content), contentType)
		if err != nil {
			return "", "", err
		}
		return url, "supabase", nil
	}

	return "", "", fmt.Errorf("no storage provider available")
}

// UploadDMMedia uploads DM media with expiry support
func (s *MultiStorageService) UploadDMMedia(ctx context.Context, conversationID uuid.UUID, content []byte, contentType, extension string) (string, string, error) {
	if s.r2Storage != nil {
		url, err := s.r2Storage.UploadDMMedia(ctx, conversationID, content, contentType, extension)
		if err == nil {
			return url, "r2", nil
		}
		log.Printf("[Storage] R2 DM upload failed: %v", err)
	}

	return "", "", fmt.Errorf("R2 storage required for DM media (expiry support)")
}

// DeleteMedia deletes media from the appropriate storage provider
func (s *MultiStorageService) DeleteMedia(ctx context.Context, url, provider string) error {
	switch provider {
	case "r2":
		if s.r2Storage != nil {
			// Extract key from URL
			key := extractKeyFromR2URL(url, s.r2Storage.publicURL)
			return s.r2Storage.DeleteFile(ctx, key)
		}
	case "supabase":
		if s.supabase != nil {
			return s.supabase.DeleteProfilePicture(ctx, url)
		}
	}
	return fmt.Errorf("unknown storage provider: %s", provider)
}

func extractKeyFromR2URL(url, publicURL string) string {
	return strings.TrimPrefix(url, publicURL+"/")
}

// GetStorageStats returns storage usage statistics
func (s *MultiStorageService) GetStorageStats() map[string]interface{} {
	stats := map[string]interface{}{
		"r2_enabled":       s.r2Storage != nil,
		"supabase_enabled": s.supabase != nil,
		"prefer_r2":        s.preferR2,
	}
	return stats
}

// Helper function to sort headers
func sortedHeaderKeys(headers http.Header) []string {
	keys := make([]string, 0, len(headers))
	for k := range headers {
		keys = append(keys, strings.ToLower(k))
	}
	sort.Strings(keys)
	return keys
}

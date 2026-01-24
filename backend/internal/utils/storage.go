package utils

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"histeeria-backend/internal/config"
	apperr "histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// StorageService handles file storage operations with Supabase Storage
type StorageService struct {
	config      *config.StorageConfig
	supabaseURL string
	apiKey      string
	http        *http.Client
}

// NewStorageService creates a new storage service
func NewStorageService(storageConfig *config.StorageConfig, supabaseURL, apiKey string) *StorageService {
	// Validate and normalize supabaseURL
	normalizedURL := supabaseURL
	if normalizedURL != "" && !strings.HasPrefix(normalizedURL, "http://") && !strings.HasPrefix(normalizedURL, "https://") {
		log.Printf("[Storage] WARNING: SupabaseURL doesn't start with http/https, got: %s", normalizedURL)
		// Try to prepend https:// if it looks like a domain
		if strings.Contains(normalizedURL, ".supabase.co") {
			normalizedURL = "https://" + normalizedURL
			log.Printf("[Storage] Auto-corrected URL to: %s", normalizedURL)
		}
	}
	
	log.Printf("[Storage] Initializing StorageService with URL: %s", normalizedURL)
	
	return &StorageService{
		config:      storageConfig,
		supabaseURL: normalizedURL,
		apiKey:      apiKey,
		http:        &http.Client{Timeout: 30 * time.Second},
	}
}

// UploadProfilePicture uploads a profile picture to Supabase Storage
func (s *StorageService) UploadProfilePicture(ctx context.Context, userID uuid.UUID, file multipart.File, header *multipart.FileHeader) (string, error) {
	// Validate file size
	if header.Size > s.config.MaxFileSize {
		return "", apperr.NewAppError(400, fmt.Sprintf("File size exceeds maximum allowed size of %d bytes", s.config.MaxFileSize))
	}

	// Validate file type
	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		// Try to detect content type from file extension
		ext := strings.ToLower(filepath.Ext(header.Filename))
		switch ext {
		case ".jpg", ".jpeg":
			contentType = "image/jpeg"
		case ".png":
			contentType = "image/png"
		case ".gif":
			contentType = "image/gif"
		case ".webp":
			contentType = "image/webp"
		default:
			contentType = "image/jpeg" // Default fallback
		}
		log.Printf("[Storage] Content-Type not provided, detected as: %s", contentType)
	}

	if !s.isAllowedFileType(contentType) {
		return "", apperr.NewAppError(400, fmt.Sprintf("File type %s is not allowed. Allowed types: %s", contentType, s.config.AllowedFileTypes))
	}

	// Generate unique filename
	ext := filepath.Ext(header.Filename)
	filename := fmt.Sprintf("%s/%s%s", userID.String(), uuid.New().String(), ext)

	// Read file content
	fileBytes, err := io.ReadAll(file)
	if err != nil {
		log.Printf("[Storage] Error reading file: %v", err)
		return "", apperr.NewAppError(http.StatusInternalServerError, fmt.Sprintf("Failed to read file: %v", err))
	}

	// Upload to Supabase Storage
	// Supabase Storage API format: POST /storage/v1/object/{bucket}/{path}
	uploadURL := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.supabaseURL, s.config.BucketName, filename)
	log.Printf("[Storage] Uploading to: %s (bucket: %s, filename: %s, size: %d bytes, content-type: %s)",
		uploadURL, s.config.BucketName, filename, len(fileBytes), contentType)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, uploadURL, bytes.NewReader(fileBytes))
	if err != nil {
		log.Printf("[Storage] Error creating request: %v", err)
		return "", apperr.NewAppError(http.StatusInternalServerError, fmt.Sprintf("Failed to create upload request: %v", err))
	}

	// Set required Supabase Storage headers
	req.Header.Set("apikey", s.apiKey)
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("x-upsert", "true") // Allow overwriting existing files

	resp, err := s.http.Do(req)
	if err != nil {
		log.Printf("[Storage] Error uploading file to Supabase: %v", err)
		return "", apperr.NewAppError(http.StatusInternalServerError, fmt.Sprintf("Failed to upload to storage: %v", err))
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		errorMsg := fmt.Sprintf("Supabase storage error (status %d): %s", resp.StatusCode, string(bodyBytes))
		log.Printf("[Storage] %s", errorMsg)
		return "", apperr.NewAppError(resp.StatusCode, errorMsg)
	}

	// Get public URL
	publicURL := fmt.Sprintf("%s/storage/v1/object/public/%s/%s", s.supabaseURL, s.config.BucketName, filename)

	return publicURL, nil
}

// UploadCoverPhoto uploads a cover photo to Supabase Storage
func (s *StorageService) UploadCoverPhoto(ctx context.Context, userID uuid.UUID, file multipart.File, header *multipart.FileHeader) (string, error) {
	// Validate file size
	if header.Size > s.config.MaxFileSize {
		return "", apperr.NewAppError(400, fmt.Sprintf("File size exceeds maximum allowed size of %d bytes", s.config.MaxFileSize))
	}

	// Validate file type
	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		// Try to detect content type from file extension
		ext := strings.ToLower(filepath.Ext(header.Filename))
		switch ext {
		case ".jpg", ".jpeg":
			contentType = "image/jpeg"
		case ".png":
			contentType = "image/png"
		case ".gif":
			contentType = "image/gif"
		case ".webp":
			contentType = "image/webp"
		default:
			contentType = "image/jpeg" // Default fallback
		}
		log.Printf("[Storage] Content-Type not provided, detected as: %s", contentType)
	}

	if !s.isAllowedFileType(contentType) {
		return "", apperr.NewAppError(400, fmt.Sprintf("File type %s is not allowed. Allowed types: %s", contentType, s.config.AllowedFileTypes))
	}

	// Generate unique filename for cover photo
	ext := filepath.Ext(header.Filename)
	filename := fmt.Sprintf("%s/cover_%s%s", userID.String(), uuid.New().String(), ext)

	// Read file content
	fileBytes, err := io.ReadAll(file)
	if err != nil {
		log.Printf("[Storage] Error reading file: %v", err)
		return "", apperr.NewAppError(http.StatusInternalServerError, fmt.Sprintf("Failed to read file: %v", err))
	}

	// Upload to Supabase Storage
	uploadURL := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.supabaseURL, s.config.BucketName, filename)
	log.Printf("[Storage] Uploading cover photo to: %s (bucket: %s, filename: %s, size: %d bytes, content-type: %s)",
		uploadURL, s.config.BucketName, filename, len(fileBytes), contentType)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, uploadURL, bytes.NewReader(fileBytes))
	if err != nil {
		log.Printf("[Storage] Error creating request: %v", err)
		return "", apperr.NewAppError(http.StatusInternalServerError, fmt.Sprintf("Failed to create upload request: %v", err))
	}

	// Set required Supabase Storage headers
	req.Header.Set("apikey", s.apiKey)
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("x-upsert", "true") // Allow overwriting existing files

	resp, err := s.http.Do(req)
	if err != nil {
		log.Printf("[Storage] Error uploading file to Supabase: %v", err)
		return "", apperr.NewAppError(http.StatusInternalServerError, fmt.Sprintf("Failed to upload to storage: %v", err))
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		errorMsg := fmt.Sprintf("Supabase storage error (status %d): %s", resp.StatusCode, string(bodyBytes))
		log.Printf("[Storage] %s", errorMsg)
		return "", apperr.NewAppError(resp.StatusCode, errorMsg)
	}

	// Get public URL
	publicURL := fmt.Sprintf("%s/storage/v1/object/public/%s/%s", s.supabaseURL, s.config.BucketName, filename)

	return publicURL, nil
}

// DeleteCoverPhoto deletes a cover photo from Supabase Storage
func (s *StorageService) DeleteCoverPhoto(ctx context.Context, coverPhotoURL string) error {
	// Extract file path from URL
	// URL format: https://{project}.supabase.co/storage/v1/object/public/{bucket}/{path}
	if coverPhotoURL == "" {
		return nil // Nothing to delete
	}

	// Parse URL to extract bucket and path
	parts := strings.Split(coverPhotoURL, "/storage/v1/object/public/")
	if len(parts) != 2 {
		log.Printf("[Storage] Invalid cover photo URL format: %s", coverPhotoURL)
		return nil // Don't fail if URL format is unexpected
	}

	bucketAndPath := parts[1]
	bucketPathParts := strings.SplitN(bucketAndPath, "/", 2)
	if len(bucketPathParts) != 2 {
		log.Printf("[Storage] Invalid bucket/path format: %s", bucketAndPath)
		return nil
	}

	bucketName := bucketPathParts[0]
	filePath := bucketPathParts[1]

	// Delete from Supabase Storage
	deleteURL := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.supabaseURL, bucketName, filePath)
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, deleteURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create delete request: %w", err)
	}

	req.Header.Set("apikey", s.apiKey)
	req.Header.Set("Authorization", "Bearer "+s.apiKey)

	resp, err := s.http.Do(req)
	if err != nil {
		log.Printf("[Storage] Error deleting cover photo: %v", err)
		return nil // Don't fail if deletion fails
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 && resp.StatusCode != 404 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[Storage] Failed to delete cover photo (status %d): %s", resp.StatusCode, string(bodyBytes))
		return nil // Don't fail if deletion fails
	}

	return nil
}

// UploadFile uploads a file to Supabase Storage with custom bucket and path
// Returns the file path (not a public URL) for private buckets
func (s *StorageService) UploadFile(ctx context.Context, bucketName, filePath string, file io.Reader, contentType string) (string, error) {
	// Read file content
	fileBytes, err := io.ReadAll(file)
	if err != nil {
		return "", fmt.Errorf("failed to read file: %w", err)
	}

	// Upload to Supabase Storage
	uploadURL := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.supabaseURL, bucketName, filePath)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, uploadURL, bytes.NewReader(fileBytes))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", s.apiKey)
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("x-upsert", "true") // Allow overwriting existing files

	resp, err := s.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to upload file: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("upload failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	// For public buckets (public, media, etc.), return the public URL directly
	// For private buckets, return the path (bucket/path) for signed URL generation
	publicBuckets := map[string]bool{
		"public": true,
		"media":  true,
	}
	
	if publicBuckets[bucketName] {
		// Return full public URL for public buckets
		// Ensure supabaseURL is not empty and starts with http/https
		if s.supabaseURL == "" {
			log.Printf("[Storage] ERROR: supabaseURL is empty, cannot generate public URL")
			return "", fmt.Errorf("supabaseURL is empty, cannot generate public URL")
		}
		if !strings.HasPrefix(s.supabaseURL, "http://") && !strings.HasPrefix(s.supabaseURL, "https://") {
			log.Printf("[Storage] ERROR: supabaseURL must start with http:// or https://, got: %s", s.supabaseURL)
			return "", fmt.Errorf("supabaseURL must start with http:// or https://, got: %s", s.supabaseURL)
		}
		
		publicURL := fmt.Sprintf("%s/storage/v1/object/public/%s/%s", s.supabaseURL, bucketName, filePath)
		log.Printf("[Storage] ✅ Generated public URL for bucket '%s'", bucketName)
		log.Printf("[Storage]   supabaseURL: %s", s.supabaseURL)
		log.Printf("[Storage]   bucketName: %s", bucketName)
		log.Printf("[Storage]   filePath: %s", filePath)
		log.Printf("[Storage]   publicURL: %s", publicURL)
		log.Printf("[Storage]   URL validation - starts with http: %v, length: %d", strings.HasPrefix(publicURL, "http"), len(publicURL))
		return publicURL, nil
	}
	
	// If not a public bucket, log what we're returning
	log.Printf("[Storage] ⚠️ Bucket '%s' is not in publicBuckets map, returning relative path", bucketName)

	// Return file path (bucket/path) for private buckets
	// Format: "bucket/path/to/file" - this will be used to generate signed URLs
	return fmt.Sprintf("%s/%s", bucketName, filePath), nil
}

// GenerateSignedURL generates a signed URL for a file in a private bucket
// The filePath should be in format "bucket/path/to/file"
// expirationSeconds defaults to 3600 (1 hour) if not specified
func (s *StorageService) GenerateSignedURL(ctx context.Context, filePath string, expirationSeconds int) (string, error) {
	if expirationSeconds <= 0 {
		expirationSeconds = 3600 // Default 1 hour
	}

	// Parse bucket and path from filePath
	parts := strings.SplitN(filePath, "/", 2)
	if len(parts) != 2 {
		return "", fmt.Errorf("invalid file path format: expected 'bucket/path', got: %s", filePath)
	}
	bucketName := parts[0]
	objectPath := parts[1]

	// Generate signed URL using Supabase Storage API
	// POST /storage/v1/object/sign/{bucket}/{path}
	// Body: { "expiresIn": 3600 }
	signURL := fmt.Sprintf("%s/storage/v1/object/sign/%s/%s", s.supabaseURL, bucketName, objectPath)
	
	// Create JSON body with expiresIn (Supabase expects this in the body, not query param)
	payload := map[string]interface{}{
		"expiresIn": expirationSeconds,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal signed URL payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, signURL, bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("failed to create signed URL request: %w", err)
	}

	req.Header.Set("apikey", s.apiKey)
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to generate signed URL: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("failed to generate signed URL (status %d): %s", resp.StatusCode, string(bodyBytes))
	}

	var result struct {
		SignedURL string `json:"signedURL"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("failed to decode signed URL response: %w", err)
	}

	// Supabase returns a relative path, we need to prepend the base URL
	if strings.HasPrefix(result.SignedURL, "/") {
		return fmt.Sprintf("%s%s", s.supabaseURL, result.SignedURL), nil
	}

	return result.SignedURL, nil
}

// DeleteProfilePicture deletes a profile picture from Supabase Storage
func (s *StorageService) DeleteProfilePicture(ctx context.Context, pictureURL string) error {
	// Extract filename from URL
	// URL format: https://xxx.supabase.co/storage/v1/object/public/bucket/filename
	parts := strings.Split(pictureURL, "/"+s.config.BucketName+"/")
	if len(parts) < 2 {
		return apperr.NewAppError(400, "Invalid picture URL")
	}
	filename := parts[1]

	deleteURL := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.supabaseURL, s.config.BucketName, filename)

	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, deleteURL, nil)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req.Header.Set("apikey", s.apiKey)
	req.Header.Set("Authorization", "Bearer "+s.apiKey)

	resp, err := s.http.Do(req)
	if err != nil {
		return apperr.ErrInternalServer
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		// Ignore 404 errors (file might already be deleted)
		if resp.StatusCode != 404 {
			bodyBytes, _ := io.ReadAll(resp.Body)
			return apperr.NewAppError(resp.StatusCode, fmt.Sprintf("Failed to delete file: %s", string(bodyBytes)))
		}
	}

	return nil
}

// isAllowedFileType checks if the file type is allowed
func (s *StorageService) isAllowedFileType(contentType string) bool {
	allowedTypes := strings.Split(s.config.AllowedFileTypes, ",")
	for _, allowedType := range allowedTypes {
		if strings.TrimSpace(allowedType) == contentType {
			return true
		}
	}
	return false
}

// CreateBucket creates a storage bucket in Supabase (one-time setup)
func (s *StorageService) CreateBucket(ctx context.Context) error {
	createURL := fmt.Sprintf("%s/storage/v1/bucket", s.supabaseURL)

	bucketData := map[string]interface{}{
		"id":                 s.config.BucketName,
		"name":               s.config.BucketName,
		"public":             true,
		"file_size_limit":    s.config.MaxFileSize,
		"allowed_mime_types": strings.Split(s.config.AllowedFileTypes, ","),
	}

	body, err := json.Marshal(bucketData)
	if err != nil {
		return apperr.ErrInternalServer
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, createURL, bytes.NewReader(body))
	if err != nil {
		return apperr.ErrInternalServer
	}

	req.Header.Set("apikey", s.apiKey)
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.http.Do(req)
	if err != nil {
		return apperr.ErrInternalServer
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		// Bucket might already exist, which is fine
		if resp.StatusCode != 409 {
			bodyBytes, _ := io.ReadAll(resp.Body)
			return apperr.NewAppError(resp.StatusCode, fmt.Sprintf("Failed to create bucket: %s", string(bodyBytes)))
		}
	}

	return nil
}

package storage

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// SupabaseConfig holds configuration for Supabase Storage
type SupabaseConfig struct {
	ProjectURL string
	ServiceKey string // Service role key for backend operations
	BucketName string
}

// SupabaseProvider implements StorageProvider for Supabase Storage
type SupabaseProvider struct {
	config     SupabaseConfig
	httpClient *http.Client
	storageURL string
}

// NewSupabaseProvider creates a new Supabase storage provider
func NewSupabaseProvider(config SupabaseConfig) *SupabaseProvider {
	return &SupabaseProvider{
		config:     config,
		httpClient: &http.Client{Timeout: 60 * time.Second},
		storageURL: fmt.Sprintf("%s/storage/v1", strings.TrimSuffix(config.ProjectURL, "/")),
	}
}

// GetProviderName returns the provider name
func (s *SupabaseProvider) GetProviderName() string {
	return "supabase-storage"
}

// Upload uploads data to Supabase Storage
func (s *SupabaseProvider) Upload(ctx context.Context, key string, data io.Reader, opts *UploadOptions) (*StorageObject, error) {
	// Read all data
	body, err := io.ReadAll(data)
	if err != nil {
		return nil, fmt.Errorf("failed to read data: %w", err)
	}

	// Determine content type
	contentType := "application/octet-stream"
	if opts != nil && opts.ContentType != "" {
		contentType = opts.ContentType
	}

	// Build upload URL
	uploadURL := fmt.Sprintf("%s/object/%s/%s", s.storageURL, s.config.BucketName, key)

	req, err := http.NewRequestWithContext(ctx, "POST", uploadURL, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.config.ServiceKey)
	req.Header.Set("Content-Type", contentType)

	if opts != nil && opts.CacheControl != "" {
		req.Header.Set("Cache-Control", opts.CacheControl)
	}

	// Upsert mode to allow overwriting
	req.Header.Set("x-upsert", "true")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to upload: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("upload failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	// Parse response
	var result struct {
		Key string `json:"Key"`
	}
	json.NewDecoder(resp.Body).Decode(&result)

	return &StorageObject{
		Key:          key,
		ContentType:  contentType,
		Size:         int64(len(body)),
		LastModified: time.Now(),
	}, nil
}

// Download downloads data from Supabase Storage
func (s *SupabaseProvider) Download(ctx context.Context, key string, opts *DownloadOptions) (io.ReadCloser, *StorageObject, error) {
	downloadURL := fmt.Sprintf("%s/object/%s/%s", s.storageURL, s.config.BucketName, key)

	req, err := http.NewRequestWithContext(ctx, "GET", downloadURL, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.config.ServiceKey)

	if opts != nil && opts.Range != "" {
		req.Header.Set("Range", opts.Range)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to download: %w", err)
	}

	if resp.StatusCode == http.StatusNotFound {
		resp.Body.Close()
		return nil, nil, fmt.Errorf("object not found: %s", key)
	}

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
		resp.Body.Close()
		return nil, nil, fmt.Errorf("download failed with status %d", resp.StatusCode)
	}

	obj := &StorageObject{
		Key:         key,
		ContentType: resp.Header.Get("Content-Type"),
		Size:        resp.ContentLength,
		ETag:        resp.Header.Get("ETag"),
	}

	if lastMod := resp.Header.Get("Last-Modified"); lastMod != "" {
		if t, err := time.Parse(http.TimeFormat, lastMod); err == nil {
			obj.LastModified = t
		}
	}

	return resp.Body, obj, nil
}

// Delete removes an object from Supabase Storage
func (s *SupabaseProvider) Delete(ctx context.Context, key string) error {
	deleteURL := fmt.Sprintf("%s/object/%s/%s", s.storageURL, s.config.BucketName, key)

	req, err := http.NewRequestWithContext(ctx, "DELETE", deleteURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.config.ServiceKey)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to delete: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusNotFound {
		return fmt.Errorf("delete failed with status %d", resp.StatusCode)
	}

	return nil
}

// DeleteMany removes multiple objects from Supabase Storage
func (s *SupabaseProvider) DeleteMany(ctx context.Context, keys []string) error {
	// Supabase supports batch delete
	deleteURL := fmt.Sprintf("%s/object/%s", s.storageURL, s.config.BucketName)

	// Build prefixes array
	prefixes := make([]string, len(keys))
	for i, key := range keys {
		prefixes[i] = key
	}

	body, err := json.Marshal(map[string][]string{"prefixes": prefixes})
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "DELETE", deleteURL, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.config.ServiceKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to delete: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("batch delete failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// Exists checks if an object exists in Supabase Storage
func (s *SupabaseProvider) Exists(ctx context.Context, key string) (bool, error) {
	_, err := s.GetMetadata(ctx, key)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

// GetMetadata retrieves object metadata
func (s *SupabaseProvider) GetMetadata(ctx context.Context, key string) (*StorageObject, error) {
	// Use HEAD request or list with specific key
	infoURL := fmt.Sprintf("%s/object/info/%s/%s", s.storageURL, s.config.BucketName, key)

	req, err := http.NewRequestWithContext(ctx, "GET", infoURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.config.ServiceKey)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to get metadata: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, fmt.Errorf("object not found: %s", key)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("get metadata failed with status %d", resp.StatusCode)
	}

	var info struct {
		Name         string            `json:"name"`
		Size         int64             `json:"size"`
		ContentType  string            `json:"contentType"`
		ETag         string            `json:"etag"`
		LastModified string            `json:"lastModified"`
		Metadata     map[string]string `json:"metadata"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		return nil, fmt.Errorf("failed to parse metadata: %w", err)
	}

	obj := &StorageObject{
		Key:         key,
		ContentType: info.ContentType,
		Size:        info.Size,
		ETag:        info.ETag,
		Metadata:    info.Metadata,
	}

	if info.LastModified != "" {
		if t, err := time.Parse(time.RFC3339, info.LastModified); err == nil {
			obj.LastModified = t
		}
	}

	return obj, nil
}

// List lists objects with optional prefix
func (s *SupabaseProvider) List(ctx context.Context, opts *ListOptions) (*ListResult, error) {
	listURL := fmt.Sprintf("%s/object/list/%s", s.storageURL, s.config.BucketName)

	// Build query parameters
	params := url.Values{}
	if opts != nil {
		if opts.Prefix != "" {
			params.Set("prefix", opts.Prefix)
		}
		if opts.MaxKeys > 0 {
			params.Set("limit", fmt.Sprintf("%d", opts.MaxKeys))
		}
		if opts.StartKey != "" {
			params.Set("offset", opts.StartKey)
		}
	}

	if len(params) > 0 {
		listURL += "?" + params.Encode()
	}

	req, err := http.NewRequestWithContext(ctx, "POST", listURL, bytes.NewReader([]byte("{}")))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.config.ServiceKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to list: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("list failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var items []struct {
		Name         string            `json:"name"`
		Size         int64             `json:"size,omitempty"`
		ContentType  string            `json:"content_type,omitempty"`
		LastModified string            `json:"updated_at,omitempty"`
		Metadata     map[string]string `json:"metadata,omitempty"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&items); err != nil {
		return nil, fmt.Errorf("failed to parse list response: %w", err)
	}

	objects := make([]StorageObject, 0, len(items))
	for _, item := range items {
		obj := StorageObject{
			Key:         item.Name,
			ContentType: item.ContentType,
			Size:        item.Size,
			Metadata:    item.Metadata,
		}
		if item.LastModified != "" {
			if t, err := time.Parse(time.RFC3339, item.LastModified); err == nil {
				obj.LastModified = t
			}
		}
		objects = append(objects, obj)
	}

	return &ListResult{
		Objects:     objects,
		IsTruncated: opts != nil && opts.MaxKeys > 0 && len(objects) >= opts.MaxKeys,
	}, nil
}

// GetSignedUploadURL generates a pre-signed URL for uploads
func (s *SupabaseProvider) GetSignedUploadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error) {
	expiration := int64(3600) // 1 hour default
	if opts != nil && opts.Expiration > 0 {
		expiration = int64(opts.Expiration.Seconds())
	}

	signURL := fmt.Sprintf("%s/object/sign/%s/%s", s.storageURL, s.config.BucketName, key)

	body, err := json.Marshal(map[string]interface{}{
		"expiresIn": expiration,
	})
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", signURL, bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.config.ServiceKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to create signed URL: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("create signed URL failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var result struct {
		SignedURL string `json:"signedUrl"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("failed to parse signed URL response: %w", err)
	}

	return result.SignedURL, nil
}

// GetSignedDownloadURL generates a pre-signed URL for downloads
func (s *SupabaseProvider) GetSignedDownloadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error) {
	return s.GetSignedUploadURL(ctx, key, opts) // Same endpoint in Supabase
}

// GetPublicURL returns the public URL for an object
func (s *SupabaseProvider) GetPublicURL(key string) string {
	return fmt.Sprintf("%s/object/public/%s/%s", s.storageURL, s.config.BucketName, key)
}

// Copy copies an object within Supabase Storage
func (s *SupabaseProvider) Copy(ctx context.Context, sourceKey, destKey string) error {
	copyURL := fmt.Sprintf("%s/object/copy", s.storageURL)

	body, err := json.Marshal(map[string]string{
		"bucketId":       s.config.BucketName,
		"sourceKey":      sourceKey,
		"destinationKey": destKey,
	})
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", copyURL, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.config.ServiceKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to copy: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("copy failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// HealthCheck verifies the Supabase Storage connection is healthy
func (s *SupabaseProvider) HealthCheck(ctx context.Context) error {
	// Try to list bucket info
	bucketsURL := fmt.Sprintf("%s/bucket/%s", s.storageURL, s.config.BucketName)

	req, err := http.NewRequestWithContext(ctx, "GET", bucketsURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.config.ServiceKey)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("health check failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("health check failed with status %d", resp.StatusCode)
	}

	return nil
}

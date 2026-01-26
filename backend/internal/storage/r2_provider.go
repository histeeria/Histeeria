package storage

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"
)

// R2Config holds configuration for Cloudflare R2
type R2Config struct {
	AccountID       string
	AccessKeyID     string
	SecretAccessKey string
	BucketName      string
	PublicURL       string // Optional: custom domain for public access
}

// R2Provider implements StorageProvider for Cloudflare R2
type R2Provider struct {
	config     R2Config
	httpClient *http.Client
	endpoint   string
}

// NewR2Provider creates a new Cloudflare R2 storage provider
func NewR2Provider(config R2Config) *R2Provider {
	return &R2Provider{
		config:     config,
		httpClient: &http.Client{Timeout: 60 * time.Second},
		endpoint:   fmt.Sprintf("https://%s.r2.cloudflarestorage.com", config.AccountID),
	}
}

// GetProviderName returns the provider name
func (r *R2Provider) GetProviderName() string {
	return "cloudflare-r2"
}

// Upload uploads data to R2
func (r *R2Provider) Upload(ctx context.Context, key string, data io.Reader, opts *UploadOptions) (*StorageObject, error) {
	// Read all data into memory for signing
	// For large files, use multipart upload instead
	body, err := io.ReadAll(data)
	if err != nil {
		return nil, fmt.Errorf("failed to read data: %w", err)
	}

	contentType := "application/octet-stream"
	if opts != nil && opts.ContentType != "" {
		contentType = opts.ContentType
	}

	reqURL := fmt.Sprintf("%s/%s/%s", r.endpoint, r.config.BucketName, key)
	req, err := http.NewRequestWithContext(ctx, "PUT", reqURL, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", contentType)
	if opts != nil && opts.CacheControl != "" {
		req.Header.Set("Cache-Control", opts.CacheControl)
	}

	// Add metadata headers
	if opts != nil && opts.Metadata != nil {
		for k, v := range opts.Metadata {
			req.Header.Set("x-amz-meta-"+k, v)
		}
	}

	// Sign the request with AWS Signature V4
	r.signRequest(req, body)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to upload: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("upload failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return &StorageObject{
		Key:          key,
		ContentType:  contentType,
		Size:         int64(len(body)),
		ETag:         resp.Header.Get("ETag"),
		LastModified: time.Now(),
	}, nil
}

// Download downloads data from R2
func (r *R2Provider) Download(ctx context.Context, key string, opts *DownloadOptions) (io.ReadCloser, *StorageObject, error) {
	reqURL := fmt.Sprintf("%s/%s/%s", r.endpoint, r.config.BucketName, key)
	req, err := http.NewRequestWithContext(ctx, "GET", reqURL, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create request: %w", err)
	}

	if opts != nil && opts.Range != "" {
		req.Header.Set("Range", opts.Range)
	}

	r.signRequest(req, nil)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to download: %w", err)
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

// Delete removes an object from R2
func (r *R2Provider) Delete(ctx context.Context, key string) error {
	reqURL := fmt.Sprintf("%s/%s/%s", r.endpoint, r.config.BucketName, key)
	req, err := http.NewRequestWithContext(ctx, "DELETE", reqURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	r.signRequest(req, nil)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to delete: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusNotFound {
		return fmt.Errorf("delete failed with status %d", resp.StatusCode)
	}

	return nil
}

// DeleteMany removes multiple objects from R2
func (r *R2Provider) DeleteMany(ctx context.Context, keys []string) error {
	// R2 supports batch delete, but for simplicity we delete one by one
	// For production, implement the batch delete API
	for _, key := range keys {
		if err := r.Delete(ctx, key); err != nil {
			return err
		}
	}
	return nil
}

// Exists checks if an object exists in R2
func (r *R2Provider) Exists(ctx context.Context, key string) (bool, error) {
	_, err := r.GetMetadata(ctx, key)
	if err != nil {
		if strings.Contains(err.Error(), "404") {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

// GetMetadata retrieves object metadata
func (r *R2Provider) GetMetadata(ctx context.Context, key string) (*StorageObject, error) {
	reqURL := fmt.Sprintf("%s/%s/%s", r.endpoint, r.config.BucketName, key)
	req, err := http.NewRequestWithContext(ctx, "HEAD", reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	r.signRequest(req, nil)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to get metadata: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, fmt.Errorf("object not found: 404")
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("get metadata failed with status %d", resp.StatusCode)
	}

	obj := &StorageObject{
		Key:         key,
		ContentType: resp.Header.Get("Content-Type"),
		Size:        resp.ContentLength,
		ETag:        resp.Header.Get("ETag"),
		Metadata:    make(map[string]string),
	}

	if lastMod := resp.Header.Get("Last-Modified"); lastMod != "" {
		if t, err := time.Parse(http.TimeFormat, lastMod); err == nil {
			obj.LastModified = t
		}
	}

	// Extract custom metadata
	for k, v := range resp.Header {
		if strings.HasPrefix(strings.ToLower(k), "x-amz-meta-") {
			metaKey := strings.TrimPrefix(strings.ToLower(k), "x-amz-meta-")
			if len(v) > 0 {
				obj.Metadata[metaKey] = v[0]
			}
		}
	}

	return obj, nil
}

// List lists objects with optional prefix
func (r *R2Provider) List(ctx context.Context, opts *ListOptions) (*ListResult, error) {
	reqURL := fmt.Sprintf("%s/%s?list-type=2", r.endpoint, r.config.BucketName)

	if opts != nil {
		if opts.Prefix != "" {
			reqURL += "&prefix=" + url.QueryEscape(opts.Prefix)
		}
		if opts.MaxKeys > 0 {
			reqURL += fmt.Sprintf("&max-keys=%d", opts.MaxKeys)
		}
		if opts.Delimiter != "" {
			reqURL += "&delimiter=" + url.QueryEscape(opts.Delimiter)
		}
		if opts.StartKey != "" {
			reqURL += "&start-after=" + url.QueryEscape(opts.StartKey)
		}
	}

	req, err := http.NewRequestWithContext(ctx, "GET", reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	r.signRequest(req, nil)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to list: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("list failed with status %d", resp.StatusCode)
	}

	// Parse XML response (simplified - in production, use proper XML parsing)
	// For now, return empty result as placeholder
	return &ListResult{
		Objects:     []StorageObject{},
		IsTruncated: false,
	}, nil
}

// GetSignedUploadURL generates a pre-signed URL for uploads
func (r *R2Provider) GetSignedUploadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error) {
	expiration := 15 * time.Minute
	if opts != nil && opts.Expiration > 0 {
		expiration = opts.Expiration
	}

	return r.generatePresignedURL("PUT", key, expiration, opts)
}

// GetSignedDownloadURL generates a pre-signed URL for downloads
func (r *R2Provider) GetSignedDownloadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error) {
	expiration := 1 * time.Hour
	if opts != nil && opts.Expiration > 0 {
		expiration = opts.Expiration
	}

	return r.generatePresignedURL("GET", key, expiration, opts)
}

// GetPublicURL returns the public URL for an object
func (r *R2Provider) GetPublicURL(key string) string {
	if r.config.PublicURL != "" {
		return fmt.Sprintf("%s/%s", strings.TrimSuffix(r.config.PublicURL, "/"), key)
	}
	// R2 doesn't have public URLs by default, use signed URL
	url, _ := r.GetSignedDownloadURL(context.Background(), key, &SignedURLOptions{
		Expiration: 24 * time.Hour,
	})
	return url
}

// Copy copies an object within R2
func (r *R2Provider) Copy(ctx context.Context, sourceKey, destKey string) error {
	reqURL := fmt.Sprintf("%s/%s/%s", r.endpoint, r.config.BucketName, destKey)
	req, err := http.NewRequestWithContext(ctx, "PUT", reqURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("x-amz-copy-source", fmt.Sprintf("/%s/%s", r.config.BucketName, sourceKey))

	r.signRequest(req, nil)

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to copy: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("copy failed with status %d", resp.StatusCode)
	}

	return nil
}

// HealthCheck verifies the R2 connection is healthy
func (r *R2Provider) HealthCheck(ctx context.Context) error {
	// Try to list with max 1 key to verify connection
	_, err := r.List(ctx, &ListOptions{MaxKeys: 1})
	return err
}

// ============================================
// AWS Signature V4 Implementation
// ============================================

func (r *R2Provider) signRequest(req *http.Request, payload []byte) {
	// Get current time
	t := time.Now().UTC()
	amzDate := t.Format("20060102T150405Z")
	dateStamp := t.Format("20060102")

	// Set required headers
	req.Header.Set("x-amz-date", amzDate)
	req.Header.Set("Host", req.Host)

	// Calculate payload hash
	payloadHash := sha256Hash(payload)
	req.Header.Set("x-amz-content-sha256", payloadHash)

	// Create canonical request
	canonicalHeaders, signedHeaders := r.buildCanonicalHeaders(req)
	canonicalRequest := strings.Join([]string{
		req.Method,
		req.URL.Path,
		req.URL.RawQuery,
		canonicalHeaders,
		signedHeaders,
		payloadHash,
	}, "\n")

	// Create string to sign
	region := "auto" // R2 uses "auto" region
	service := "s3"
	scope := fmt.Sprintf("%s/%s/%s/aws4_request", dateStamp, region, service)
	stringToSign := strings.Join([]string{
		"AWS4-HMAC-SHA256",
		amzDate,
		scope,
		sha256Hash([]byte(canonicalRequest)),
	}, "\n")

	// Calculate signature
	signingKey := r.deriveSigningKey(dateStamp, region, service)
	signature := hex.EncodeToString(hmacSHA256(signingKey, []byte(stringToSign)))

	// Add authorization header
	authHeader := fmt.Sprintf("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s",
		r.config.AccessKeyID, scope, signedHeaders, signature)
	req.Header.Set("Authorization", authHeader)
}

func (r *R2Provider) buildCanonicalHeaders(req *http.Request) (string, string) {
	// Headers to sign (must be lowercase and sorted)
	headersToSign := []string{"host", "x-amz-content-sha256", "x-amz-date"}

	// Add other x-amz headers
	for key := range req.Header {
		lowerKey := strings.ToLower(key)
		if strings.HasPrefix(lowerKey, "x-amz-") && lowerKey != "x-amz-content-sha256" && lowerKey != "x-amz-date" {
			headersToSign = append(headersToSign, lowerKey)
		}
	}

	sort.Strings(headersToSign)

	var canonicalHeaders strings.Builder
	for _, key := range headersToSign {
		var value string
		if key == "host" {
			value = req.Host
		} else {
			value = req.Header.Get(key)
		}
		canonicalHeaders.WriteString(fmt.Sprintf("%s:%s\n", key, strings.TrimSpace(value)))
	}

	return canonicalHeaders.String(), strings.Join(headersToSign, ";")
}

func (r *R2Provider) deriveSigningKey(dateStamp, region, service string) []byte {
	kDate := hmacSHA256([]byte("AWS4"+r.config.SecretAccessKey), []byte(dateStamp))
	kRegion := hmacSHA256(kDate, []byte(region))
	kService := hmacSHA256(kRegion, []byte(service))
	kSigning := hmacSHA256(kService, []byte("aws4_request"))
	return kSigning
}

func (r *R2Provider) generatePresignedURL(method, key string, expiration time.Duration, opts *SignedURLOptions) (string, error) {
	t := time.Now().UTC()
	amzDate := t.Format("20060102T150405Z")
	dateStamp := t.Format("20060102")

	region := "auto"
	service := "s3"

	// Build query string
	params := url.Values{}
	params.Set("X-Amz-Algorithm", "AWS4-HMAC-SHA256")
	params.Set("X-Amz-Credential", fmt.Sprintf("%s/%s/%s/%s/aws4_request",
		r.config.AccessKeyID, dateStamp, region, service))
	params.Set("X-Amz-Date", amzDate)
	params.Set("X-Amz-Expires", fmt.Sprintf("%d", int(expiration.Seconds())))
	params.Set("X-Amz-SignedHeaders", "host")

	if opts != nil && opts.ResponseDisposition != "" {
		params.Set("response-content-disposition", opts.ResponseDisposition)
	}

	// Build canonical request
	objectPath := fmt.Sprintf("/%s/%s", r.config.BucketName, key)
	host := fmt.Sprintf("%s.r2.cloudflarestorage.com", r.config.AccountID)

	canonicalRequest := strings.Join([]string{
		method,
		objectPath,
		params.Encode(),
		fmt.Sprintf("host:%s\n", host),
		"host",
		"UNSIGNED-PAYLOAD",
	}, "\n")

	// String to sign
	scope := fmt.Sprintf("%s/%s/%s/aws4_request", dateStamp, region, service)
	stringToSign := strings.Join([]string{
		"AWS4-HMAC-SHA256",
		amzDate,
		scope,
		sha256Hash([]byte(canonicalRequest)),
	}, "\n")

	// Calculate signature
	signingKey := r.deriveSigningKey(dateStamp, region, service)
	signature := hex.EncodeToString(hmacSHA256(signingKey, []byte(stringToSign)))

	params.Set("X-Amz-Signature", signature)

	return fmt.Sprintf("https://%s%s?%s", host, objectPath, params.Encode()), nil
}

// Helper functions
func sha256Hash(data []byte) string {
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

func hmacSHA256(key, data []byte) []byte {
	h := hmac.New(sha256.New, key)
	h.Write(data)
	return h.Sum(nil)
}

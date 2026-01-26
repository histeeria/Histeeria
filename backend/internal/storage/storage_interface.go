package storage

import (
	"context"
	"io"
	"time"
)

// StorageObject represents an object in storage
type StorageObject struct {
	Key          string            `json:"key"`
	ContentType  string            `json:"content_type"`
	Size         int64             `json:"size"`
	ETag         string            `json:"etag,omitempty"`
	LastModified time.Time         `json:"last_modified,omitempty"`
	Metadata     map[string]string `json:"metadata,omitempty"`
}

// UploadOptions configures upload behavior
type UploadOptions struct {
	ContentType  string
	CacheControl string
	Metadata     map[string]string
	ACL          string // "private", "public-read"
}

// DownloadOptions configures download behavior
type DownloadOptions struct {
	Range string // For partial downloads: "bytes=0-1024"
}

// ListOptions configures list behavior
type ListOptions struct {
	Prefix    string
	MaxKeys   int
	Delimiter string
	StartKey  string // For pagination
}

// ListResult contains the results of a list operation
type ListResult struct {
	Objects      []StorageObject
	NextStartKey string
	IsTruncated  bool
}

// SignedURLOptions configures signed URL generation
type SignedURLOptions struct {
	Expiration          time.Duration
	ContentType         string // For uploads
	ResponseDisposition string // Content-Disposition header
}

// StorageProvider defines the interface for storage operations
// This interface is platform-independent and can be implemented
// for any storage provider (R2, S3, Supabase Storage, GCS, etc.)
type StorageProvider interface {
	// Upload uploads data to storage
	Upload(ctx context.Context, key string, data io.Reader, opts *UploadOptions) (*StorageObject, error)

	// Download downloads data from storage
	Download(ctx context.Context, key string, opts *DownloadOptions) (io.ReadCloser, *StorageObject, error)

	// Delete removes an object from storage
	Delete(ctx context.Context, key string) error

	// DeleteMany removes multiple objects from storage
	DeleteMany(ctx context.Context, keys []string) error

	// Exists checks if an object exists
	Exists(ctx context.Context, key string) (bool, error)

	// GetMetadata retrieves object metadata without downloading
	GetMetadata(ctx context.Context, key string) (*StorageObject, error)

	// List lists objects with optional prefix
	List(ctx context.Context, opts *ListOptions) (*ListResult, error)

	// GetSignedUploadURL generates a pre-signed URL for uploads
	GetSignedUploadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error)

	// GetSignedDownloadURL generates a pre-signed URL for downloads
	GetSignedDownloadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error)

	// GetPublicURL returns the public URL for an object (if public access is enabled)
	GetPublicURL(key string) string

	// Copy copies an object within storage
	Copy(ctx context.Context, sourceKey, destKey string) error

	// HealthCheck verifies the storage connection is healthy
	HealthCheck(ctx context.Context) error

	// GetProviderName returns the name of the storage provider
	GetProviderName() string
}

// StorageService provides a high-level interface for storage operations
// with support for multiple providers and fallback
type StorageService struct {
	primary   StorageProvider
	fallback  StorageProvider
	providers map[string]StorageProvider
}

// NewStorageService creates a new storage service with the given primary provider
func NewStorageService(primary StorageProvider) *StorageService {
	return &StorageService{
		primary: primary,
		providers: map[string]StorageProvider{
			primary.GetProviderName(): primary,
		},
	}
}

// SetFallback sets a fallback provider for when primary fails
func (s *StorageService) SetFallback(provider StorageProvider) {
	s.fallback = provider
	s.providers[provider.GetProviderName()] = provider
}

// AddProvider adds an additional provider
func (s *StorageService) AddProvider(provider StorageProvider) {
	s.providers[provider.GetProviderName()] = provider
}

// GetProvider returns a provider by name
func (s *StorageService) GetProvider(name string) (StorageProvider, bool) {
	provider, ok := s.providers[name]
	return provider, ok
}

// Upload uploads data using the primary provider with fallback
func (s *StorageService) Upload(ctx context.Context, key string, data io.Reader, opts *UploadOptions) (*StorageObject, error) {
	obj, err := s.primary.Upload(ctx, key, data, opts)
	if err != nil && s.fallback != nil {
		// If data is seekable, reset it for retry
		if seeker, ok := data.(io.Seeker); ok {
			seeker.Seek(0, io.SeekStart)
		}
		return s.fallback.Upload(ctx, key, data, opts)
	}
	return obj, err
}

// Download downloads data using the primary provider with fallback
func (s *StorageService) Download(ctx context.Context, key string, opts *DownloadOptions) (io.ReadCloser, *StorageObject, error) {
	reader, obj, err := s.primary.Download(ctx, key, opts)
	if err != nil && s.fallback != nil {
		return s.fallback.Download(ctx, key, opts)
	}
	return reader, obj, err
}

// Delete removes an object using the primary provider
func (s *StorageService) Delete(ctx context.Context, key string) error {
	err := s.primary.Delete(ctx, key)
	if err != nil && s.fallback != nil {
		// Also try to delete from fallback
		s.fallback.Delete(ctx, key)
	}
	return err
}

// DeleteMany removes multiple objects
func (s *StorageService) DeleteMany(ctx context.Context, keys []string) error {
	err := s.primary.DeleteMany(ctx, keys)
	if s.fallback != nil {
		// Also delete from fallback regardless of primary result
		s.fallback.DeleteMany(ctx, keys)
	}
	return err
}

// Exists checks if an object exists
func (s *StorageService) Exists(ctx context.Context, key string) (bool, error) {
	exists, err := s.primary.Exists(ctx, key)
	if err != nil && s.fallback != nil {
		return s.fallback.Exists(ctx, key)
	}
	return exists, err
}

// GetMetadata retrieves object metadata
func (s *StorageService) GetMetadata(ctx context.Context, key string) (*StorageObject, error) {
	obj, err := s.primary.GetMetadata(ctx, key)
	if err != nil && s.fallback != nil {
		return s.fallback.GetMetadata(ctx, key)
	}
	return obj, err
}

// List lists objects
func (s *StorageService) List(ctx context.Context, opts *ListOptions) (*ListResult, error) {
	result, err := s.primary.List(ctx, opts)
	if err != nil && s.fallback != nil {
		return s.fallback.List(ctx, opts)
	}
	return result, err
}

// GetSignedUploadURL generates a pre-signed upload URL
func (s *StorageService) GetSignedUploadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error) {
	return s.primary.GetSignedUploadURL(ctx, key, opts)
}

// GetSignedDownloadURL generates a pre-signed download URL
func (s *StorageService) GetSignedDownloadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error) {
	url, err := s.primary.GetSignedDownloadURL(ctx, key, opts)
	if err != nil && s.fallback != nil {
		return s.fallback.GetSignedDownloadURL(ctx, key, opts)
	}
	return url, err
}

// GetPublicURL returns the public URL for an object
func (s *StorageService) GetPublicURL(key string) string {
	return s.primary.GetPublicURL(key)
}

// Copy copies an object within storage
func (s *StorageService) Copy(ctx context.Context, sourceKey, destKey string) error {
	return s.primary.Copy(ctx, sourceKey, destKey)
}

// HealthCheck verifies all storage connections are healthy
func (s *StorageService) HealthCheck(ctx context.Context) map[string]error {
	results := make(map[string]error)
	for name, provider := range s.providers {
		results[name] = provider.HealthCheck(ctx)
	}
	return results
}

// Primary returns the primary storage provider
func (s *StorageService) Primary() StorageProvider {
	return s.primary
}

// Fallback returns the fallback storage provider
func (s *StorageService) Fallback() StorageProvider {
	return s.fallback
}

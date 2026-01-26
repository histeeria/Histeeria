package storage

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// LocalConfig holds configuration for local filesystem storage
type LocalConfig struct {
	BasePath string // Base directory for storage
	BaseURL  string // Base URL for serving files (e.g., http://localhost:8080/uploads)
}

// LocalProvider implements StorageProvider for local filesystem storage
// This is useful for development and testing environments
type LocalProvider struct {
	config LocalConfig
}

// NewLocalProvider creates a new local filesystem storage provider
func NewLocalProvider(config LocalConfig) (*LocalProvider, error) {
	// Ensure base path exists
	if err := os.MkdirAll(config.BasePath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create storage directory: %w", err)
	}

	return &LocalProvider{
		config: config,
	}, nil
}

// GetProviderName returns the provider name
func (l *LocalProvider) GetProviderName() string {
	return "local-filesystem"
}

// Upload uploads data to local filesystem
func (l *LocalProvider) Upload(ctx context.Context, key string, data io.Reader, opts *UploadOptions) (*StorageObject, error) {
	// Create full path
	fullPath := filepath.Join(l.config.BasePath, key)

	// Ensure directory exists
	dir := filepath.Dir(fullPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create directory: %w", err)
	}

	// Create file
	file, err := os.Create(fullPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create file: %w", err)
	}
	defer file.Close()

	// Copy data and calculate hash
	hasher := sha256.New()
	writer := io.MultiWriter(file, hasher)

	size, err := io.Copy(writer, data)
	if err != nil {
		os.Remove(fullPath) // Clean up on error
		return nil, fmt.Errorf("failed to write file: %w", err)
	}

	etag := hex.EncodeToString(hasher.Sum(nil))

	// Store metadata in a sidecar file if provided
	if opts != nil && len(opts.Metadata) > 0 {
		l.writeMetadata(fullPath, opts.ContentType, opts.Metadata)
	}

	return &StorageObject{
		Key:          key,
		ContentType:  l.getContentType(key, opts),
		Size:         size,
		ETag:         etag,
		LastModified: time.Now(),
	}, nil
}

// Download downloads data from local filesystem
func (l *LocalProvider) Download(ctx context.Context, key string, opts *DownloadOptions) (io.ReadCloser, *StorageObject, error) {
	fullPath := filepath.Join(l.config.BasePath, key)

	file, err := os.Open(fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil, fmt.Errorf("object not found: %s", key)
		}
		return nil, nil, fmt.Errorf("failed to open file: %w", err)
	}

	info, err := file.Stat()
	if err != nil {
		file.Close()
		return nil, nil, fmt.Errorf("failed to stat file: %w", err)
	}

	obj := &StorageObject{
		Key:          key,
		ContentType:  l.detectContentType(key),
		Size:         info.Size(),
		LastModified: info.ModTime(),
	}

	return file, obj, nil
}

// Delete removes a file from local filesystem
func (l *LocalProvider) Delete(ctx context.Context, key string) error {
	fullPath := filepath.Join(l.config.BasePath, key)

	err := os.Remove(fullPath)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to delete file: %w", err)
	}

	// Also remove metadata file if exists
	os.Remove(fullPath + ".meta")

	// Try to remove empty parent directories
	l.cleanEmptyDirs(filepath.Dir(fullPath))

	return nil
}

// DeleteMany removes multiple files from local filesystem
func (l *LocalProvider) DeleteMany(ctx context.Context, keys []string) error {
	for _, key := range keys {
		if err := l.Delete(ctx, key); err != nil {
			return err
		}
	}
	return nil
}

// Exists checks if a file exists
func (l *LocalProvider) Exists(ctx context.Context, key string) (bool, error) {
	fullPath := filepath.Join(l.config.BasePath, key)
	_, err := os.Stat(fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, fmt.Errorf("failed to check file existence: %w", err)
	}
	return true, nil
}

// GetMetadata retrieves file metadata
func (l *LocalProvider) GetMetadata(ctx context.Context, key string) (*StorageObject, error) {
	fullPath := filepath.Join(l.config.BasePath, key)

	info, err := os.Stat(fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("object not found: %s", key)
		}
		return nil, fmt.Errorf("failed to stat file: %w", err)
	}

	// Calculate ETag from file content
	file, err := os.Open(fullPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return nil, fmt.Errorf("failed to calculate hash: %w", err)
	}

	return &StorageObject{
		Key:          key,
		ContentType:  l.detectContentType(key),
		Size:         info.Size(),
		ETag:         hex.EncodeToString(hasher.Sum(nil)),
		LastModified: info.ModTime(),
		Metadata:     l.readMetadata(fullPath),
	}, nil
}

// List lists files with optional prefix
func (l *LocalProvider) List(ctx context.Context, opts *ListOptions) (*ListResult, error) {
	var objects []StorageObject
	prefix := ""
	if opts != nil {
		prefix = opts.Prefix
	}

	searchPath := filepath.Join(l.config.BasePath, prefix)
	basePath := l.config.BasePath

	err := filepath.Walk(searchPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Skip files we can't access
		}

		// Skip directories and metadata files
		if info.IsDir() || strings.HasSuffix(path, ".meta") {
			return nil
		}

		// Get relative key
		key, err := filepath.Rel(basePath, path)
		if err != nil {
			return nil
		}

		// Convert to forward slashes for consistency
		key = filepath.ToSlash(key)

		// Apply delimiter filter if set
		if opts != nil && opts.Delimiter != "" {
			// Only return files at this level, not in subdirectories
			relToPrefix := strings.TrimPrefix(key, prefix)
			if strings.Contains(relToPrefix, opts.Delimiter) {
				return nil
			}
		}

		objects = append(objects, StorageObject{
			Key:          key,
			ContentType:  l.detectContentType(key),
			Size:         info.Size(),
			LastModified: info.ModTime(),
		})

		// Apply max keys limit
		if opts != nil && opts.MaxKeys > 0 && len(objects) >= opts.MaxKeys {
			return filepath.SkipAll
		}

		return nil
	})

	if err != nil && !os.IsNotExist(err) {
		return nil, fmt.Errorf("failed to list files: %w", err)
	}

	return &ListResult{
		Objects:     objects,
		IsTruncated: opts != nil && opts.MaxKeys > 0 && len(objects) >= opts.MaxKeys,
	}, nil
}

// GetSignedUploadURL returns the direct upload path for local storage
// In local mode, there's no signing needed
func (l *LocalProvider) GetSignedUploadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error) {
	// For local development, just return the public URL
	// In production, you'd implement proper authentication
	return fmt.Sprintf("%s/upload/%s", strings.TrimSuffix(l.config.BaseURL, "/"), key), nil
}

// GetSignedDownloadURL returns the direct download path for local storage
func (l *LocalProvider) GetSignedDownloadURL(ctx context.Context, key string, opts *SignedURLOptions) (string, error) {
	return l.GetPublicURL(key), nil
}

// GetPublicURL returns the public URL for a file
func (l *LocalProvider) GetPublicURL(key string) string {
	return fmt.Sprintf("%s/%s", strings.TrimSuffix(l.config.BaseURL, "/"), key)
}

// Copy copies a file within local filesystem
func (l *LocalProvider) Copy(ctx context.Context, sourceKey, destKey string) error {
	sourcePath := filepath.Join(l.config.BasePath, sourceKey)
	destPath := filepath.Join(l.config.BasePath, destKey)

	// Open source file
	source, err := os.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("failed to open source file: %w", err)
	}
	defer source.Close()

	// Create destination directory
	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	// Create destination file
	dest, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("failed to create destination file: %w", err)
	}
	defer dest.Close()

	// Copy content
	if _, err := io.Copy(dest, source); err != nil {
		os.Remove(destPath) // Clean up on error
		return fmt.Errorf("failed to copy file: %w", err)
	}

	// Also copy metadata if exists
	if meta := l.readMetadata(sourcePath); len(meta) > 0 {
		l.writeMetadata(destPath, "", meta)
	}

	return nil
}

// HealthCheck verifies the local storage is accessible
func (l *LocalProvider) HealthCheck(ctx context.Context) error {
	// Check if base path exists and is writable
	testFile := filepath.Join(l.config.BasePath, ".healthcheck")
	file, err := os.Create(testFile)
	if err != nil {
		return fmt.Errorf("storage not writable: %w", err)
	}
	file.Close()
	os.Remove(testFile)
	return nil
}

// Helper methods

func (l *LocalProvider) getContentType(key string, opts *UploadOptions) string {
	if opts != nil && opts.ContentType != "" {
		return opts.ContentType
	}
	return l.detectContentType(key)
}

func (l *LocalProvider) detectContentType(key string) string {
	ext := strings.ToLower(filepath.Ext(key))
	contentTypes := map[string]string{
		".jpg":  "image/jpeg",
		".jpeg": "image/jpeg",
		".png":  "image/png",
		".gif":  "image/gif",
		".webp": "image/webp",
		".svg":  "image/svg+xml",
		".mp4":  "video/mp4",
		".webm": "video/webm",
		".mp3":  "audio/mpeg",
		".pdf":  "application/pdf",
		".json": "application/json",
		".txt":  "text/plain",
		".html": "text/html",
		".css":  "text/css",
		".js":   "application/javascript",
	}

	if ct, ok := contentTypes[ext]; ok {
		return ct
	}
	return "application/octet-stream"
}

func (l *LocalProvider) writeMetadata(path, contentType string, metadata map[string]string) {
	// Simple metadata storage in sidecar file
	metaPath := path + ".meta"
	file, err := os.Create(metaPath)
	if err != nil {
		return
	}
	defer file.Close()

	if contentType != "" {
		fmt.Fprintf(file, "Content-Type: %s\n", contentType)
	}
	for k, v := range metadata {
		fmt.Fprintf(file, "%s: %s\n", k, v)
	}
}

func (l *LocalProvider) readMetadata(path string) map[string]string {
	metaPath := path + ".meta"
	data, err := os.ReadFile(metaPath)
	if err != nil {
		return nil
	}

	metadata := make(map[string]string)
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		parts := strings.SplitN(line, ": ", 2)
		if len(parts) == 2 {
			metadata[parts[0]] = parts[1]
		}
	}
	return metadata
}

func (l *LocalProvider) cleanEmptyDirs(dir string) {
	// Don't delete above base path
	if !strings.HasPrefix(dir, l.config.BasePath) || dir == l.config.BasePath {
		return
	}

	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) > 0 {
		return
	}

	os.Remove(dir)
	l.cleanEmptyDirs(filepath.Dir(dir))
}

// ServeFiles creates an HTTP handler to serve files from local storage
func (l *LocalProvider) ServeFiles() http.Handler {
	return http.StripPrefix("/uploads/", http.FileServer(http.Dir(l.config.BasePath)))
}

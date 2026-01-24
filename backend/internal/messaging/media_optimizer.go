package messaging

import (
	"bytes"
	"fmt"
	"image"
	"image/jpeg"
	"io"

	"github.com/disintegration/imaging"
)

// MediaOptimizer handles media file optimization
type MediaOptimizer struct {
	// Configuration for optimization
	maxStandardWidth  int
	maxStandardHeight int
	maxHDWidth        int
	maxHDHeight       int
	standardQuality   int
	hdQuality         int
	thumbnailSize     int
}

// NewMediaOptimizer creates a new media optimizer with default settings
func NewMediaOptimizer() *MediaOptimizer {
	return &MediaOptimizer{
		maxStandardWidth:  1920,
		maxStandardHeight: 1920,
		maxHDWidth:        4096,
		maxHDHeight:       4096,
		standardQuality:   85,  // JPEG quality
		hdQuality:         95,  // JPEG quality
		thumbnailSize:     150, // 150x150 thumbnail
	}
}

// OptimizeImageQuality represents the quality level for image optimization
type OptimizeImageQuality string

const (
	QualityStandard OptimizeImageQuality = "standard"
	QualityHD       OptimizeImageQuality = "hd"
)

// OptimizeImage resizes and compresses an image
func (m *MediaOptimizer) OptimizeImage(reader io.Reader, quality OptimizeImageQuality) ([]byte, string, error) {
	// Decode image
	img, format, err := image.Decode(reader)
	if err != nil {
		return nil, "", fmt.Errorf("failed to decode image: %w", err)
	}

	// Determine target dimensions and quality
	var maxWidth, maxHeight, jpegQuality int
	if quality == QualityHD {
		maxWidth = m.maxHDWidth
		maxHeight = m.maxHDHeight
		jpegQuality = m.hdQuality
	} else {
		maxWidth = m.maxStandardWidth
		maxHeight = m.maxStandardHeight
		jpegQuality = m.standardQuality
	}

	// Resize if necessary
	bounds := img.Bounds()
	width := bounds.Dx()
	height := bounds.Dy()

	if width > maxWidth || height > maxHeight {
		// Calculate new dimensions maintaining aspect ratio
		img = imaging.Fit(img, maxWidth, maxHeight, imaging.Lanczos)
	}

	// Apply sharpening for HD quality
	if quality == QualityHD {
		img = imaging.Sharpen(img, 0.5)
	}

	// Encode to JPEG (more efficient than PNG for photos)
	var buf bytes.Buffer
	if format == "png" && quality == QualityStandard {
		// For PNG, convert to JPEG to reduce size
		err = jpeg.Encode(&buf, img, &jpeg.Options{Quality: jpegQuality})
		format = "jpeg"
	} else if format == "jpeg" || format == "jpg" {
		err = jpeg.Encode(&buf, img, &jpeg.Options{Quality: jpegQuality})
	} else {
		// For other formats, encode as JPEG
		err = jpeg.Encode(&buf, img, &jpeg.Options{Quality: jpegQuality})
		format = "jpeg"
	}

	if err != nil {
		return nil, "", fmt.Errorf("failed to encode image: %w", err)
	}

	return buf.Bytes(), format, nil
}

// GenerateThumbnail creates a small thumbnail for an image
func (m *MediaOptimizer) GenerateThumbnail(reader io.Reader) ([]byte, error) {
	// Decode image
	img, _, err := image.Decode(reader)
	if err != nil {
		return nil, fmt.Errorf("failed to decode image: %w", err)
	}

	// Create thumbnail (crop to square and resize)
	thumb := imaging.Fill(img, m.thumbnailSize, m.thumbnailSize, imaging.Center, imaging.Lanczos)

	// Encode as JPEG
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, thumb, &jpeg.Options{Quality: 80}); err != nil {
		return nil, fmt.Errorf("failed to encode thumbnail: %w", err)
	}

	return buf.Bytes(), nil
}

// OptimizeImageFromBytes optimizes image from byte array
func (m *MediaOptimizer) OptimizeImageFromBytes(data []byte, quality OptimizeImageQuality) ([]byte, string, error) {
	reader := bytes.NewReader(data)
	return m.OptimizeImage(reader, quality)
}

// ValidateImage checks if the data is a valid image
func (m *MediaOptimizer) ValidateImage(data []byte) (bool, string, error) {
	reader := bytes.NewReader(data)
	_, format, err := image.DecodeConfig(reader)
	if err != nil {
		return false, "", err
	}

	return true, format, nil
}

// GetImageDimensions returns the width and height of an image
func (m *MediaOptimizer) GetImageDimensions(data []byte) (int, int, error) {
	reader := bytes.NewReader(data)
	config, _, err := image.DecodeConfig(reader)
	if err != nil {
		return 0, 0, err
	}

	return config.Width, config.Height, nil
}

// ConvertToWebP converts an image to WebP format (placeholder for future implementation)
// Note: WebP encoding requires cgo and external libraries
// For now, we use JPEG which has excellent compression
func (m *MediaOptimizer) ConvertToWebP(reader io.Reader) ([]byte, error) {
	// TODO: Implement WebP conversion when cgo is available
	// For now, fall back to JPEG optimization
	data, _, err := m.OptimizeImage(reader, QualityStandard)
	return data, err
}

// ============================================
// AUDIO PROCESSING (PLACEHOLDER)
// ============================================

// ConvertAudio converts WebM/Opus audio to MP3
// Note: This requires ffmpeg to be installed on the system
// This is a placeholder that returns an error for now
func (m *MediaOptimizer) ConvertAudio(reader io.Reader) ([]byte, error) {
	// TODO: Implement audio conversion using ffmpeg
	// This requires executing external command:
	// ffmpeg -i input.webm -codec:a libmp3lame -b:a 64k output.mp3

	// For Phase 1, we'll accept WebM format directly
	// Audio conversion can be added in Phase 2
	return nil, fmt.Errorf("audio conversion not yet implemented - WebM format accepted as-is")
}

// ValidateAudio checks if the data is valid audio
func (m *MediaOptimizer) ValidateAudio(data []byte, mimeType string) (bool, error) {
	// Basic validation - check mime type and file header
	// Accept WebM, OGG, MP3, M4A/AAC formats
	supportedTypes := []string{
		"audio/webm", "audio/ogg", "audio/mp3", "audio/mpeg",
		"audio/m4a", "audio/aac", "audio/x-m4a", "audio/mp4",
	}
	
	isSupported := false
	for _, supported := range supportedTypes {
		if mimeType == supported {
			isSupported = true
			break
		}
	}
	
	if !isSupported {
		return false, fmt.Errorf("unsupported audio format: %s (supported: webm, ogg, mp3, m4a, aac)", mimeType)
	}

	// Check minimum file size (should be at least 1KB)
	if len(data) < 1024 {
		return false, fmt.Errorf("audio file too small: %d bytes", len(data))
	}

	return true, nil
}

// GetAudioDuration returns the duration of an audio file in seconds (placeholder)
func (m *MediaOptimizer) GetAudioDuration(data []byte) (float64, error) {
	// TODO: Implement audio duration detection
	// For now, return 0
	return 0, fmt.Errorf("audio duration detection not yet implemented")
}

// ============================================
// FILE SIZE LIMITS
// ============================================

const (
	MaxImageSizeStandard = 5 * 1024 * 1024   // 5MB
	MaxImageSizeHD       = 20 * 1024 * 1024  // 20MB
	MaxAudioSize         = 16 * 1024 * 1024  // 16MB (WhatsApp limit)
	MaxFileSize          = 100 * 1024 * 1024 // 100MB
)

// ValidateFileSize checks if file size is within limits
func ValidateFileSize(size int64, fileType string) error {
	switch fileType {
	case "image_standard":
		if size > MaxImageSizeStandard {
			return fmt.Errorf("image size %d bytes exceeds limit of %d bytes", size, MaxImageSizeStandard)
		}
	case "image_hd":
		if size > MaxImageSizeHD {
			return fmt.Errorf("HD image size %d bytes exceeds limit of %d bytes", size, MaxImageSizeHD)
		}
	case "audio":
		if size > MaxAudioSize {
			return fmt.Errorf("audio size %d bytes exceeds limit of %d bytes", size, MaxAudioSize)
		}
	case "file":
		if size > MaxFileSize {
			return fmt.Errorf("file size %d bytes exceeds limit of %d bytes", size, MaxFileSize)
		}
	}

	return nil
}

// ============================================
// SUPPORTED FORMATS
// ============================================

var (
	SupportedImageFormats = []string{"image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp"}
	SupportedAudioFormats = []string{"audio/webm", "audio/ogg", "audio/mpeg", "audio/mp3"}
	SupportedFileFormats  = []string{"application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"}
)

// IsSupportedFormat checks if a MIME type is supported
func IsSupportedFormat(mimeType, category string) bool {
	var formats []string
	switch category {
	case "image":
		formats = SupportedImageFormats
	case "audio":
		formats = SupportedAudioFormats
	case "file":
		formats = SupportedFileFormats
	default:
		return false
	}

	for _, format := range formats {
		if format == mimeType {
			return true
		}
	}

	return false
}

/**
 * Image Compression Utilities
 * Client-side image compression before upload to reduce bandwidth and storage
 */

import imageCompression from 'browser-image-compression';

export type ImageQuality = 'standard' | 'hd';

// ============================================
// COMPRESSION OPTIONS
// ============================================

const STANDARD_OPTIONS = {
  maxSizeMB: 0.3, // Target 300KB for standard quality (better than WhatsApp's ~100KB)
  maxWidthOrHeight: 2048, // Full HD+ resolution
  useWebWorker: true,
  fileType: 'image/jpeg' as const,
  initialQuality: 0.88, // Higher quality than WhatsApp
};

const HD_OPTIONS = {
  maxSizeMB: 5, // Target 5MB for Ultra HD (WhatsApp uses ~1-2MB)
  maxWidthOrHeight: 7680, // 8K resolution (WhatsApp max is ~4K)
  useWebWorker: true,
  fileType: 'image/jpeg' as const,
  initialQuality: 0.98, // Near-lossless (WhatsApp uses ~0.9)
  preserveExif: true, // Keep photo metadata
  alwaysKeepResolution: true, // Don't downscale unnecessarily
};

// ============================================
// COMPRESSION FUNCTIONS
// ============================================

/**
 * Compress an image file
 * @param file - Image file to compress
 * @param quality - 'standard' (200KB, 1920px) or 'hd' (2MB, 4096px)
 * @returns Compressed image file
 */
export async function compressImage(
  file: File,
  quality: ImageQuality = 'standard'
): Promise<File> {
  const options = quality === 'hd' ? HD_OPTIONS : STANDARD_OPTIONS;

  try {
    console.log(`[ImageCompression] Compressing image (${quality} quality)...`);
    console.log(`[ImageCompression] Original size: ${(file.size / 1024).toFixed(2)}KB`);

    const compressed = await imageCompression(file, options);

    console.log(`[ImageCompression] Compressed size: ${(compressed.size / 1024).toFixed(2)}KB`);
    console.log(`[ImageCompression] Reduction: ${(((file.size - compressed.size) / file.size) * 100).toFixed(1)}%`);

    return compressed;
  } catch (error) {
    console.error('[ImageCompression] Compression failed:', error);
    // Return original file if compression fails
    return file;
  }
}

/**
 * Compress multiple images
 */
export async function compressImages(
  files: File[],
  quality: ImageQuality = 'standard'
): Promise<File[]> {
  return Promise.all(files.map((file) => compressImage(file, quality)));
}

/**
 * Get image dimensions without loading the full image
 */
export function getImageDimensions(file: File): Promise<{ width: number; height: number }> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);

    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve({ width: img.width, height: img.height });
    };

    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('Failed to load image'));
    };

    img.src = url;
  });
}

/**
 * Validate image file
 */
export function validateImage(file: File): { valid: boolean; error?: string } {
  // Check if file is an image
  if (!file.type.startsWith('image/')) {
    return { valid: false, error: 'File must be an image' };
  }

  // Check file size (max 20MB before compression)
  const maxSize = 20 * 1024 * 1024; // 20MB
  if (file.size > maxSize) {
    return { valid: false, error: 'Image must be smaller than 20MB' };
  }

  // Check image type
  const supportedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
  if (!supportedTypes.includes(file.type)) {
    return { valid: false, error: 'Unsupported image format. Use JPEG, PNG, GIF, or WebP' };
  }

  return { valid: true };
}

/**
 * Generate thumbnail from image file
 */
export async function generateThumbnail(file: File, size = 150): Promise<File> {
  try {
    const thumbnail = await imageCompression(file, {
      maxSizeMB: 0.05, // 50KB max
      maxWidthOrHeight: size,
      useWebWorker: true,
    });

    return thumbnail;
  } catch (error) {
    console.error('[ImageCompression] Thumbnail generation failed:', error);
    return file;
  }
}

/**
 * Convert image to data URL (for preview)
 */
export function fileToDataURL(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = () => {
      resolve(reader.result as string);
    };

    reader.onerror = () => {
      reject(new Error('Failed to read file'));
    };

    reader.readAsDataURL(file);
  });
}

/**
 * Format file size for display
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 Bytes';

  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

/**
 * Compress profile image (alias for standard quality compression)
 */
export function compressProfileImage(file: File): Promise<File> {
  return compressImage(file, 'standard');
}

/**
 * Validate image file (alias for validateImage)
 */
export function validateImageFile(file: File): { valid: boolean; error?: string } {
  return validateImage(file);
}

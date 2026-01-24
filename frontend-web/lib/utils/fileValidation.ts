'use client';

export interface FileValidationResult {
  valid: boolean;
  error?: string;
  warning?: string;
  sizeInfo?: {
    bytes: number;
    kb: string;
    mb: string;
    withinLimit: boolean;
  };
}

// File size limits (in bytes)
const FILE_LIMITS = {
  image_standard: 10 * 1024 * 1024,    // 10MB
  image_hd: 25 * 1024 * 1024,          // 25MB
  audio: 50 * 1024 * 1024,             // 50MB
  video: 100 * 1024 * 1024,            // 100MB
  document: 100 * 1024 * 1024,         // 100MB
  voice: 10 * 1024 * 1024,             // 10MB for voice messages
};

/**
 * Validate file size and type
 */
export function validateFile(file: File, type: 'image' | 'audio' | 'video' | 'document'): FileValidationResult {
  const sizeInfo = {
    bytes: file.size,
    kb: (file.size / 1024).toFixed(2),
    mb: (file.size / (1024 * 1024)).toFixed(2),
    withinLimit: false,
  };

  // Determine limit based on type
  let limit = FILE_LIMITS.document;
  let limitMB = 100;

  switch (type) {
    case 'image':
      limit = FILE_LIMITS.image_hd;
      limitMB = 25;
      break;
    case 'audio':
      limit = FILE_LIMITS.audio;
      limitMB = 50;
      break;
    case 'video':
      limit = FILE_LIMITS.video;
      limitMB = 100;
      break;
    case 'document':
      limit = FILE_LIMITS.document;
      limitMB = 100;
      break;
  }

  sizeInfo.withinLimit = file.size <= limit;

  // Check size
  if (file.size > limit) {
    return {
      valid: false,
      error: `File too large! Maximum size: ${limitMB}MB. Your file: ${sizeInfo.mb}MB`,
      sizeInfo,
    };
  }

  // Warning for large files (>50% of limit)
  if (file.size > limit * 0.5) {
    return {
      valid: true,
      warning: `Large file (${sizeInfo.mb}MB). Upload may take longer.`,
      sizeInfo,
    };
  }

  return {
    valid: true,
    sizeInfo,
  };
}

/**
 * Validate image file
 */
export function validateImageFile(file: File, quality: 'standard' | 'hd' = 'standard'): FileValidationResult {
  const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'image/heic'];

  if (!file.type.startsWith('image/')) {
    return {
      valid: false,
      error: 'File is not an image',
    };
  }

  if (!allowedTypes.includes(file.type)) {
    return {
      valid: false,
      error: `Image type ${file.type} not supported. Use JPG, PNG, WebP, or GIF.`,
    };
  }

  // Check size based on quality
  const limit = quality === 'hd' ? FILE_LIMITS.image_hd : FILE_LIMITS.image_standard;
  const limitMB = quality === 'hd' ? 25 : 10;

  return validateFile(file, 'image');
}

/**
 * Validate video file
 */
export function validateVideoFile(file: File): FileValidationResult {
  const allowedTypes = ['video/mp4', 'video/webm', 'video/ogg', 'video/quicktime'];

  if (!file.type.startsWith('video/')) {
    return {
      valid: false,
      error: 'File is not a video',
    };
  }

  if (!allowedTypes.includes(file.type)) {
    return {
      valid: false,
      error: `Video type ${file.type} not supported. Use MP4, WebM, or MOV.`,
    };
  }

  return validateFile(file, 'video');
}

/**
 * Validate audio file
 */
export function validateAudioFile(file: File): FileValidationResult {
  const allowedTypes = [
    'audio/webm',
    'audio/mp3',
    'audio/mpeg',
    'audio/wav',
    'audio/ogg',
    'audio/m4a',
    'audio/aac',
    'audio/flac',
  ];

  if (!file.type.startsWith('audio/')) {
    return {
      valid: false,
      error: 'File is not an audio file',
    };
  }

  return validateFile(file, 'audio');
}

/**
 * Validate document file
 */
export function validateDocumentFile(file: File): FileValidationResult {
  // Most document types are allowed
  const restrictedTypes = ['application/x-msdownload', 'application/x-executable'];

  if (restrictedTypes.includes(file.type)) {
    return {
      valid: false,
      error: 'Executable files are not allowed for security reasons',
    };
  }

  return validateFile(file, 'document');
}

/**
 * Format file size for display
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 Bytes';

  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
}

/**
 * Get file type category
 */
export function getFileCategory(file: File): 'image' | 'audio' | 'video' | 'document' {
  if (file.type.startsWith('image/')) return 'image';
  if (file.type.startsWith('audio/')) return 'audio';
  if (file.type.startsWith('video/')) return 'video';
  return 'document';
}

/**
 * Check if compression is recommended
 */
export function shouldCompress(file: File): boolean {
  const category = getFileCategory(file);
  const sizeMB = file.size / (1024 * 1024);

  switch (category) {
    case 'image':
      return sizeMB > 1; // Compress images > 1MB
    case 'audio':
      return sizeMB > 5; // Compress audio > 5MB
    case 'video':
      return sizeMB > 10; // Compress video > 10MB
    default:
      return false; // Don't compress documents
  }
}


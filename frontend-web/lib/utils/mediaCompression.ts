/**
 * Media Compression Utilities for Posts
 * Re-exports and extends compression utilities for post media uploads
 */

export {
  compressImage,
  compressImages,
  validateImage,
  generateThumbnail,
  formatFileSize,
  type ImageQuality,
} from './imageCompression';

export {
  compressVideo,
  validateVideo,
  generateVideoThumbnail,
  getVideoMetadata,
  type VideoCompressionOptions,
  type VideoCompressionResult,
} from './videoCompression';

export {
  compressAudio,
  validateAudio,
  getAudioMetadata,
  type AudioCompressionOptions,
  type AudioCompressionResult,
} from './audioCompression';

/**
 * Optimized compression settings for posts
 */
export const POST_MEDIA_SETTINGS = {
  images: {
    standard: {
      maxSizeMB: 0.5, // 500KB for posts (slightly larger than messages)
      maxWidthOrHeight: 1920,
      quality: 0.85,
    },
    hd: {
      maxSizeMB: 2, // 2MB for HD posts
      maxWidthOrHeight: 3840, // 4K
      quality: 0.95,
    },
  },
  videos: {
    standard: {
      maxWidth: 1920,
      maxHeight: 1080,
      bitrate: '2M',
    },
    hd: {
      maxWidth: 3840,
      maxHeight: 2160,
      bitrate: '5M',
    },
  },
  audio: {
    voice: {
      bitrate: 128, // kbps
      mono: true,
    },
    music: {
      bitrate: 192, // kbps
      mono: false,
    },
  },
};


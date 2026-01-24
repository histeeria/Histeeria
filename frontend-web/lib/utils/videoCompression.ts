'use client';

import { ffmpegService, checkFFmpegSupport } from './ffmpegService';

export interface VideoCompressionOptions {
  maxWidth?: number;
  maxHeight?: number;
  quality?: 'standard' | 'hd';
  onProgress?: (progress: number) => void;
}

export interface VideoCompressionResult {
  compressedBlob: Blob;
  thumbnail: string; // Base64 thumbnail
  duration: number;
  originalSize: number;
  compressedSize: number;
  compressionRatio: number;
}

/**
 * Generate thumbnail from video file
 */
export async function generateVideoThumbnail(
  file: File,
  timeInSeconds = 1
): Promise<string> {
  return new Promise((resolve, reject) => {
    const video = document.createElement('video');
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');

    if (!ctx) {
      reject(new Error('Could not get canvas context'));
      return;
    }

    video.preload = 'metadata';
    video.muted = true;

    video.onloadedmetadata = () => {
      // Set canvas size to video dimensions (max 400px)
      const maxSize = 400;
      const scale = Math.min(maxSize / video.videoWidth, maxSize / video.videoHeight, 1);
      
      canvas.width = video.videoWidth * scale;
      canvas.height = video.videoHeight * scale;

      // Seek to specific time
      video.currentTime = Math.min(timeInSeconds, video.duration / 2);
    };

    video.onseeked = () => {
      try {
        // Draw video frame to canvas
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        
        // Convert to base64 JPEG
        const thumbnail = canvas.toDataURL('image/jpeg', 0.8);
        
        // Cleanup
        URL.revokeObjectURL(video.src);
        
        resolve(thumbnail);
      } catch (error) {
        reject(error);
      }
    };

    video.onerror = () => {
      reject(new Error('Failed to load video'));
    };

    // Load video
    video.src = URL.createObjectURL(file);
  });
}

/**
 * Compress video file using FFmpeg.wasm
 */
export async function compressVideo(
  file: File,
  options: VideoCompressionOptions = {}
): Promise<VideoCompressionResult> {
  const {
    quality = 'standard',
    onProgress,
  } = options;

  try {
    onProgress?.(5);

    // Check browser support
    const support = checkFFmpegSupport();
    if (!support.supported) {
      console.warn('[VideoCompression] FFmpeg not supported:', support.reason);
      // Fallback: return original video with basic metadata
      const metadata = await getVideoMetadata(file);
      const thumbnail = await generateVideoThumbnail(file);
      
      return {
        compressedBlob: file,
        thumbnail,
        duration: metadata.duration,
        originalSize: file.size,
        compressedSize: file.size,
        compressionRatio: 1,
      };
    }

    onProgress?.(10);

    // Use FFmpeg service for compression
    const result = await ffmpegService.compressVideo(file, {
      quality,
      onProgress: (p) => onProgress?.(10 + p * 0.9), // Map 0-100 to 10-100
    });

    return {
      compressedBlob: result.blob,
      thumbnail: result.thumbnail,
      duration: result.metadata.duration,
      originalSize: file.size,
      compressedSize: result.blob.size,
      compressionRatio: file.size / result.blob.size,
    };
  } catch (error) {
    console.error('[VideoCompression] Compression failed:', error);
    
    // Fallback: return original video
    const metadata = await getVideoMetadata(file);
    const thumbnail = await generateVideoThumbnail(file);
    
    return {
      compressedBlob: file,
      thumbnail,
      duration: metadata.duration,
      originalSize: file.size,
      compressedSize: file.size,
      compressionRatio: 1,
    };
  }
}

/**
 * Validate video file
 */
export function validateVideo(file: File): { valid: boolean; error?: string } {
  const maxSize = 100 * 1024 * 1024; // 100MB
  const allowedTypes = ['video/mp4', 'video/webm', 'video/ogg', 'video/quicktime'];

  if (!file.type.startsWith('video/')) {
    return { valid: false, error: 'File is not a video' };
  }

  if (!allowedTypes.includes(file.type)) {
    return { valid: false, error: `Video type ${file.type} not supported. Use MP4, WebM, or MOV.` };
  }

  if (file.size > maxSize) {
    return { valid: false, error: `Video too large (max 100MB). Your file: ${(file.size / 1024 / 1024).toFixed(1)}MB` };
  }

  return { valid: true };
}

/**
 * Get video metadata without loading entire file
 */
export async function getVideoMetadata(file: File): Promise<{
  duration: number;
  width: number;
  height: number;
  size: number;
}> {
  return new Promise((resolve, reject) => {
    const video = document.createElement('video');
    video.preload = 'metadata';

    video.onloadedmetadata = () => {
      resolve({
        duration: video.duration,
        width: video.videoWidth,
        height: video.videoHeight,
        size: file.size,
      });
      
      URL.revokeObjectURL(video.src);
    };

    video.onerror = () => {
      reject(new Error('Failed to load video metadata'));
    };

    video.src = URL.createObjectURL(file);
  });
}


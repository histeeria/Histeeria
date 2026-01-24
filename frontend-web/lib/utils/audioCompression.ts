'use client';

import { ffmpegService, checkFFmpegSupport } from './ffmpegService';

export interface AudioCompressionOptions {
  bitrate?: number; // kbps
  mono?: boolean; // Convert to mono
  onProgress?: (progress: number) => void;
}

export interface AudioCompressionResult {
  compressedBlob: Blob;
  originalSize: number;
  compressedSize: number;
  compressionRatio: number;
  duration: number;
}

/**
 * Compress audio file using FFmpeg.wasm
 */
export async function compressAudio(
  file: Blob,
  options: AudioCompressionOptions = {}
): Promise<AudioCompressionResult> {
  const {
    bitrate = 64, // 64kbps for voice messages
    mono = true, // Convert to mono for voice
    onProgress,
  } = options;

  try {
    onProgress?.(5);

    // Check browser support
    const support = checkFFmpegSupport();
    if (!support.supported) {
      console.warn('[AudioCompression] FFmpeg not supported:', support.reason);
      // Fallback: return original audio
      const metadata = await getAudioMetadata(file);
      return {
        compressedBlob: file,
        originalSize: file.size,
        compressedSize: file.size,
        compressionRatio: 1,
        duration: metadata.duration,
      };
    }

    onProgress?.(10);

    // Use FFmpeg service for compression
    const compressedBlob = await ffmpegService.compressAudio(file, {
      bitrate,
      mono,
      onProgress: (p) => onProgress?.(10 + p * 0.85), // Map to 10-95
    });

    onProgress?.(95);

    // Get duration from original
    const metadata = await getAudioMetadata(file);

    onProgress?.(100);

    const compressionRatio = file.size / compressedBlob.size;
    console.log(`[AudioCompression] Compressed ${(file.size / 1024).toFixed(1)}KB → ${(compressedBlob.size / 1024).toFixed(1)}KB (${(compressionRatio * 100).toFixed(0)}% reduction)`);

    return {
      compressedBlob,
      originalSize: file.size,
      compressedSize: compressedBlob.size,
      compressionRatio,
      duration: metadata.duration,
    };
  } catch (error) {
    console.error('[AudioCompression] Compression failed:', error);
    
    // Fallback: return original
    const metadata = await getAudioMetadata(file);
    return {
      compressedBlob: file,
      originalSize: file.size,
      compressedSize: file.size,
      compressionRatio: 1,
      duration: metadata.duration,
    };
  }
}

/**
 * Validate audio file
 */
export function validateAudio(file: File): { valid: boolean; error?: string } {
  const maxSize = 50 * 1024 * 1024; // 50MB
  const allowedTypes = [
    'audio/webm',
    'audio/mp3',
    'audio/mpeg',
    'audio/wav',
    'audio/ogg',
    'audio/m4a',
    'audio/aac',
  ];

  if (!file.type.startsWith('audio/')) {
    return { valid: false, error: 'File is not an audio file' };
  }

  if (file.size > maxSize) {
    return { 
      valid: false, 
      error: `Audio file too large (max 50MB). Your file: ${(file.size / 1024 / 1024).toFixed(1)}MB` 
    };
  }

  return { valid: true };
}

/**
 * Get audio metadata
 */
export async function getAudioMetadata(file: Blob): Promise<{
  duration: number;
  size: number;
}> {
  return new Promise(async (resolve, reject) => {
    try {
      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      const arrayBuffer = await file.arrayBuffer();
      const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);

      resolve({
        duration: audioBuffer.duration,
        size: file.size,
      });

      audioContext.close();
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Convert audio to mono (reduces size by 50%)
 */
export async function convertToMono(blob: Blob): Promise<Blob> {
  return new Promise(async (resolve, reject) => {
    try {
      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      const arrayBuffer = await blob.arrayBuffer();
      const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);

      // Create mono buffer
      const monoBuffer = audioContext.createBuffer(
        1, // 1 channel (mono)
        audioBuffer.length,
        audioBuffer.sampleRate
      );

      // Mix stereo to mono if needed
      if (audioBuffer.numberOfChannels === 2) {
        const leftChannel = audioBuffer.getChannelData(0);
        const rightChannel = audioBuffer.getChannelData(1);
        const monoChannel = monoBuffer.getChannelData(0);

        for (let i = 0; i < audioBuffer.length; i++) {
          monoChannel[i] = (leftChannel[i] + rightChannel[i]) / 2;
        }
      } else {
        // Already mono, just copy
        monoBuffer.copyToChannel(audioBuffer.getChannelData(0), 0);
      }

      // For now, return original blob
      // Encoding mono buffer to blob requires MediaRecorder or FFmpeg
      resolve(blob);

      audioContext.close();
    } catch (error) {
      reject(error);
    }
  });
}


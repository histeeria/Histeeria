'use client';

import { FFmpeg } from '@ffmpeg/ffmpeg';
import { fetchFile, toBlobURL } from '@ffmpeg/util';

/**
 * FFmpegService - Singleton wrapper for FFmpeg.wasm
 * Lazy loads FFmpeg only when needed to avoid bundle bloat
 */
class FFmpegService {
  private ffmpeg: FFmpeg | null = null;
  private isLoading: boolean = false;
  private isLoaded: boolean = false;
  private loadPromise: Promise<void> | null = null;

  /**
   * Initialize FFmpeg (lazy load on first use)
   */
  async initialize(onProgress?: (message: string) => void): Promise<void> {
    // Already loaded
    if (this.isLoaded && this.ffmpeg) {
      return;
    }

    // Currently loading - return existing promise
    if (this.isLoading && this.loadPromise) {
      return this.loadPromise;
    }

    // Start loading
    this.isLoading = true;
    this.loadPromise = this._loadFFmpeg(onProgress);
    
    try {
      await this.loadPromise;
      this.isLoaded = true;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Internal method to load FFmpeg
   */
  private async _loadFFmpeg(onProgress?: (message: string) => void): Promise<void> {
    try {
      console.log('[FFmpeg] Starting to load FFmpeg.wasm...');
      onProgress?.('Loading FFmpeg core...');

      this.ffmpeg = new FFmpeg();

      // Set up logging
      this.ffmpeg.on('log', ({ message }) => {
        console.log('[FFmpeg]', message);
      });

      // Set up progress tracking
      this.ffmpeg.on('progress', ({ progress, time }) => {
        const percent = Math.round(progress * 100);
        console.log(`[FFmpeg] Progress: ${percent}% (${time}ms)`);
        onProgress?.(`Processing: ${percent}%`);
      });

      onProgress?.('Downloading FFmpeg core (~30MB)...');

      // Load FFmpeg core from CDN
      const baseURL = 'https://unpkg.com/@ffmpeg/core@0.12.6/dist/esm';
      await this.ffmpeg.load({
        coreURL: await toBlobURL(`${baseURL}/ffmpeg-core.js`, 'text/javascript'),
        wasmURL: await toBlobURL(`${baseURL}/ffmpeg-core.wasm`, 'application/wasm'),
      });

      console.log('[FFmpeg] FFmpeg.wasm loaded successfully!');
      onProgress?.('FFmpeg ready!');
    } catch (error) {
      console.error('[FFmpeg] Failed to load FFmpeg:', error);
      this.ffmpeg = null;
      this.isLoaded = false;
      throw new Error('Failed to load FFmpeg. Your browser may not support it.');
    }
  }

  /**
   * Check if FFmpeg is ready
   */
  isReady(): boolean {
    return this.isLoaded && this.ffmpeg !== null;
  }

  /**
   * Get FFmpeg instance (throws if not loaded)
   */
  getFFmpeg(): FFmpeg {
    if (!this.ffmpeg) {
      throw new Error('FFmpeg not initialized. Call initialize() first.');
    }
    return this.ffmpeg;
  }

  /**
   * Compress video file
   */
  async compressVideo(
    file: File,
    options: {
      quality: 'standard' | 'hd';
      onProgress?: (progress: number) => void;
    }
  ): Promise<{ blob: Blob; thumbnail: string; metadata: any }> {
    await this.initialize((msg) => options.onProgress?.(5));
    const ffmpeg = this.getFFmpeg();

    const { quality, onProgress } = options;
    const isHD = quality === 'hd';

    try {
      onProgress?.(10);
      
      // Write input file
      await ffmpeg.writeFile('input.mp4', await fetchFile(file));
      onProgress?.(20);

      // Compression settings
      const width = isHD ? 1280 : 640;
      const height = isHD ? 720 : 360;
      const videoBitrate = isHD ? '2000k' : '1000k';
      const audioBitrate = '128k';

      console.log(`[FFmpeg] Compressing video to ${width}x${height}, bitrate: ${videoBitrate}`);

      // Compress video with FFmpeg
      // -i input.mp4: input file
      // -vf scale: resize video
      // -c:v libx264: H.264 codec
      // -preset fast: encoding speed
      // -b:v: video bitrate
      // -c:a aac: audio codec
      // -b:a: audio bitrate
      // -movflags +faststart: optimize for streaming
      await ffmpeg.exec([
        '-i', 'input.mp4',
        '-vf', `scale=${width}:${height}:force_original_aspect_ratio=decrease`,
        '-c:v', 'libx264',
        '-preset', 'fast',
        '-b:v', videoBitrate,
        '-c:a', 'aac',
        '-b:a', audioBitrate,
        '-movflags', '+faststart',
        'output.mp4'
      ]);

      onProgress?.(80);

      // Read compressed video
      const data = await ffmpeg.readFile('output.mp4');
      const blob = new Blob([new Uint8Array(data as Uint8Array)], { type: 'video/mp4' });

      onProgress?.(85);

      // Generate thumbnail
      await ffmpeg.exec([
        '-i', 'input.mp4',
        '-ss', '00:00:01',
        '-vframes', '1',
        '-vf', 'scale=400:-1',
        'thumbnail.jpg'
      ]);

      const thumbnailData = await ffmpeg.readFile('thumbnail.jpg');
      const thumbnailBlob = new Blob([new Uint8Array(thumbnailData as Uint8Array)], { type: 'image/jpeg' });
      const thumbnail = await blobToBase64(thumbnailBlob);

      onProgress?.(95);

      // Get metadata
      const metadata = await this.getVideoMetadata(file);

      // Cleanup
      await ffmpeg.deleteFile('input.mp4');
      await ffmpeg.deleteFile('output.mp4');
      await ffmpeg.deleteFile('thumbnail.jpg');

      onProgress?.(100);

      console.log(`[FFmpeg] Video compressed: ${(file.size / 1024 / 1024).toFixed(1)}MB → ${(blob.size / 1024 / 1024).toFixed(1)}MB`);

      return { blob, thumbnail, metadata };
    } catch (error) {
      console.error('[FFmpeg] Video compression failed:', error);
      throw error;
    }
  }

  /**
   * Compress audio file
   */
  async compressAudio(
    file: Blob,
    options: {
      bitrate?: number;
      mono?: boolean;
      onProgress?: (progress: number) => void;
    }
  ): Promise<Blob> {
    await this.initialize((msg) => options.onProgress?.(5));
    const ffmpeg = this.getFFmpeg();

    const { bitrate = 64, mono = true, onProgress } = options;

    try {
      onProgress?.(10);

      // Write input file
      await ffmpeg.writeFile('input.webm', await fetchFile(file));
      onProgress?.(20);

      console.log(`[FFmpeg] Compressing audio to ${bitrate}kbps, mono: ${mono}`);

      // Compress audio
      // -i input.webm: input file
      // -c:a libopus: Opus codec (best for voice)
      // -b:a: audio bitrate
      // -ac 1: mono channel
      // -ar 16000: sample rate (16kHz for voice)
      const args = [
        '-i', 'input.webm',
        '-c:a', 'libopus',
        '-b:a', `${bitrate}k`,
      ];

      if (mono) {
        args.push('-ac', '1'); // Mono
        args.push('-ar', '16000'); // 16kHz sample rate for voice
      }

      args.push('output.webm');

      await ffmpeg.exec(args);

      onProgress?.(80);

      // Read compressed audio
      const data = await ffmpeg.readFile('output.webm');
      const blob = new Blob([new Uint8Array(data as Uint8Array)], { type: 'audio/webm' });

      // Cleanup
      await ffmpeg.deleteFile('input.webm');
      await ffmpeg.deleteFile('output.webm');

      onProgress?.(100);

      console.log(`[FFmpeg] Audio compressed: ${(file.size / 1024).toFixed(1)}KB → ${(blob.size / 1024).toFixed(1)}KB`);

      return blob;
    } catch (error) {
      console.error('[FFmpeg] Audio compression failed:', error);
      throw error;
    }
  }

  /**
   * Get video metadata
   */
  async getVideoMetadata(file: File): Promise<{
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
          duration: Math.round(video.duration),
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

  /**
   * Check browser support for FFmpeg
   */
  static checkSupport(): { supported: boolean; reason?: string } {
    // Check for SharedArrayBuffer support (required for FFmpeg.wasm)
    if (typeof SharedArrayBuffer === 'undefined') {
      return {
        supported: false,
        reason: 'SharedArrayBuffer not available. Enable cross-origin isolation headers or use a modern browser.'
      };
    }

    // Check for WebAssembly support
    if (typeof WebAssembly === 'undefined') {
      return {
        supported: false,
        reason: 'WebAssembly not supported in this browser.'
      };
    }

    return { supported: true };
  }
}

// Helper function to convert blob to base64
function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

// Export singleton instance
export const ffmpegService = new FFmpegService();

// Export static check function
export function checkFFmpegSupport(): { supported: boolean; reason?: string } {
  return FFmpegService.checkSupport();
}


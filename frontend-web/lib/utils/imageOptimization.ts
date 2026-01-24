'use client';

/**
 * Image Optimization Utilities
 * Provides blur placeholder generation and progressive loading
 */

/**
 * Generate a tiny blur placeholder from an image
 * Returns a base64-encoded 20x20 blurred image
 */
export async function generateBlurPlaceholder(file: File | string): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';

    img.onload = () => {
      try {
        // Create canvas with tiny dimensions
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        
        if (!ctx) {
          reject(new Error('Could not get canvas context'));
          return;
        }

        // Tiny size for blur placeholder (20x20)
        const targetSize = 20;
        const aspectRatio = img.width / img.height;
        
        canvas.width = targetSize;
        canvas.height = Math.round(targetSize / aspectRatio);

        // Draw scaled-down image
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

        // Apply blur effect
        ctx.filter = 'blur(10px)';
        ctx.drawImage(canvas, 0, 0);

        // Convert to base64 (very small, ~1-2KB)
        const blurDataUrl = canvas.toDataURL('image/jpeg', 0.3);
        
        resolve(blurDataUrl);
      } catch (error) {
        reject(error);
      }
    };

    img.onerror = () => {
      reject(new Error('Failed to load image'));
    };

    // Load image
    if (typeof file === 'string') {
      img.src = file;
    } else {
      img.src = URL.createObjectURL(file);
    }
  });
}

/**
 * Preload an image (add to browser cache)
 */
export function preloadImage(url: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve();
    img.onerror = () => reject(new Error('Failed to preload image'));
    img.src = url;
  });
}

/**
 * Check if image is in viewport (for lazy loading)
 */
export function isInViewport(element: HTMLElement, offset = 200): boolean {
  const rect = element.getBoundingClientRect();
  return (
    rect.top < window.innerHeight + offset &&
    rect.bottom > -offset
  );
}

/**
 * Generate a low-resolution thumbnail (400x400 max)
 */
export async function generateThumbnail(file: File, maxSize = 400): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const img = new Image();

    img.onload = () => {
      try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        
        if (!ctx) {
          reject(new Error('Could not get canvas context'));
          return;
        }

        // Calculate dimensions
        const scale = Math.min(maxSize / img.width, maxSize / img.height, 1);
        canvas.width = img.width * scale;
        canvas.height = img.height * scale;

        // Draw thumbnail
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

        // Convert to blob
        canvas.toBlob((blob) => {
          if (blob) {
            resolve(blob);
          } else {
            reject(new Error('Failed to create thumbnail'));
          }
        }, 'image/jpeg', 0.8);

        URL.revokeObjectURL(img.src);
      } catch (error) {
        reject(error);
      }
    };

    img.onerror = () => {
      reject(new Error('Failed to load image'));
    };

    img.src = URL.createObjectURL(file);
  });
}

/**
 * Image metadata extraction
 */
export async function getImageMetadata(file: File): Promise<{
  width: number;
  height: number;
  size: number;
  type: string;
}> {
  return new Promise((resolve, reject) => {
    const img = new Image();

    img.onload = () => {
      resolve({
        width: img.width,
        height: img.height,
        size: file.size,
        type: file.type,
      });
      URL.revokeObjectURL(img.src);
    };

    img.onerror = () => {
      reject(new Error('Failed to load image metadata'));
    };

    img.src = URL.createObjectURL(file);
  });
}


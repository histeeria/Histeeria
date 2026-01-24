'use client';

/**
 * ImageCache - LRU cache for loaded images
 * Prevents re-downloading images that are already loaded
 */

interface CachedImage {
  url: string;
  blob: Blob;
  timestamp: number;
  accessCount: number;
}

class ImageCache {
  private cache: Map<string, CachedImage> = new Map();
  private maxSize: number = 100; // Maximum number of images to cache
  private maxMemoryMB: number = 50; // Maximum memory usage in MB

  /**
   * Add image to cache
   */
  async add(url: string, blob: Blob): Promise<void> {
    // Check if already cached
    if (this.cache.has(url)) {
      const cached = this.cache.get(url)!;
      cached.accessCount++;
      cached.timestamp = Date.now();
      return;
    }

    // Check memory limit
    await this.ensureSpace(blob.size);

    // Add to cache
    this.cache.set(url, {
      url,
      blob,
      timestamp: Date.now(),
      accessCount: 1,
    });

    console.log(`[ImageCache] Cached image: ${url.substring(url.lastIndexOf('/') + 1)} (${(blob.size / 1024).toFixed(1)}KB). Total: ${this.cache.size}`);
  }

  /**
   * Get image from cache
   */
  get(url: string): Blob | null {
    const cached = this.cache.get(url);
    
    if (cached) {
      // Update access stats
      cached.accessCount++;
      cached.timestamp = Date.now();
      
      console.log(`[ImageCache] Cache hit for ${url.substring(url.lastIndexOf('/') + 1)}`);
      return cached.blob;
    }

    return null;
  }

  /**
   * Check if image is cached
   */
  has(url: string): boolean {
    return this.cache.has(url);
  }

  /**
   * Get cached object URL (creates one if needed)
   */
  getObjectURL(url: string): string | null {
    const blob = this.get(url);
    if (blob) {
      return URL.createObjectURL(blob);
    }
    return null;
  }

  /**
   * Preload images near viewport
   */
  async preload(urls: string[]): Promise<void> {
    const uncached = urls.filter(url => !this.has(url));
    
    if (uncached.length === 0) return;

    console.log(`[ImageCache] Preloading ${uncached.length} images`);

    const promises = uncached.map(async (url) => {
      try {
        const response = await fetch(url);
        const blob = await response.blob();
        await this.add(url, blob);
      } catch (error) {
        console.error(`[ImageCache] Failed to preload ${url}:`, error);
      }
    });

    await Promise.allSettled(promises);
  }

  /**
   * Ensure there's space for a new image
   * Evict least recently used images if necessary
   */
  private async ensureSpace(newImageSize: number): Promise<void> {
    // Calculate current memory usage
    let totalSize = newImageSize;
    for (const cached of this.cache.values()) {
      totalSize += cached.blob.size;
    }

    const totalSizeMB = totalSize / (1024 * 1024);

    // Check if we need to evict
    if (this.cache.size >= this.maxSize || totalSizeMB > this.maxMemoryMB) {
      // Sort by access count (ascending) and timestamp (oldest first)
      const entries = Array.from(this.cache.entries()).sort((a, b) => {
        // Prioritize least accessed, then oldest
        if (a[1].accessCount !== b[1].accessCount) {
          return a[1].accessCount - b[1].accessCount;
        }
        return a[1].timestamp - b[1].timestamp;
      });

      // Evict oldest/least accessed images until we're under limits
      let evicted = 0;
      for (const [url, cached] of entries) {
        if (this.cache.size < this.maxSize && totalSizeMB < this.maxMemoryMB) {
          break;
        }

        this.cache.delete(url);
        totalSize -= cached.blob.size;
        evicted++;
      }

      if (evicted > 0) {
        console.log(`[ImageCache] Evicted ${evicted} images to free space`);
      }
    }
  }

  /**
   * Clear entire cache
   */
  clear(): void {
    this.cache.clear();
    console.log('[ImageCache] Cache cleared');
  }

  /**
   * Get cache statistics
   */
  getStats(): {
    size: number;
    memoryMB: number;
    maxSize: number;
    maxMemoryMB: number;
  } {
    let totalSize = 0;
    for (const cached of this.cache.values()) {
      totalSize += cached.blob.size;
    }

    return {
      size: this.cache.size,
      memoryMB: totalSize / (1024 * 1024),
      maxSize: this.maxSize,
      maxMemoryMB: this.maxMemoryMB,
    };
  }
}

// Export singleton instance
export const imageCache = new ImageCache();


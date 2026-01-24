'use client';

import { messageCache } from './messageCache';

/**
 * Cache invalidation strategies and utilities
 */

export class CacheInvalidationManager {
  private invalidationScheduled = new Set<string>();
  private lastInvalidation = new Map<string, number>();

  /**
   * Schedule cache invalidation after a delay
   * Useful for batch invalidation
   */
  scheduleInvalidation(conversationId: string, delayMs = 1000) {
    if (this.invalidationScheduled.has(conversationId)) {
      return; // Already scheduled
    }

    this.invalidationScheduled.add(conversationId);

    setTimeout(async () => {
      try {
        await messageCache.invalidateConversation(conversationId);
        console.log('[CacheInvalidation] ✅ Invalidated cache for:', conversationId);
        this.lastInvalidation.set(conversationId, Date.now());
      } catch (error) {
        console.error('[CacheInvalidation] ❌ Failed to invalidate:', error);
      } finally {
        this.invalidationScheduled.delete(conversationId);
      }
    }, delayMs);
  }

  /**
   * Invalidate cache immediately
   */
  async invalidateNow(conversationId: string) {
    try {
      await messageCache.invalidateConversation(conversationId);
      this.lastInvalidation.set(conversationId, Date.now());
      console.log('[CacheInvalidation] ✅ Immediately invalidated cache for:', conversationId);
    } catch (error) {
      console.error('[CacheInvalidation] ❌ Failed to invalidate:', error);
    }
  }

  /**
   * Clear all caches (useful for logout or major updates)
   */
  async clearAllCaches() {
    try {
      await messageCache.clearAll();
      this.lastInvalidation.clear();
      this.invalidationScheduled.clear();
      console.log('[CacheInvalidation] 🗑️ Cleared all caches');
    } catch (error) {
      console.error('[CacheInvalidation] ❌ Failed to clear caches:', error);
    }
  }

  /**
   * Get time since last invalidation
   */
  getTimeSinceLastInvalidation(conversationId: string): number | null {
    const lastTime = this.lastInvalidation.get(conversationId);
    if (!lastTime) return null;
    
    return Date.now() - lastTime;
  }

  /**
   * Check if cache should be invalidated based on age
   */
  shouldInvalidate(conversationId: string, maxAgeMs = 30 * 60 * 1000): boolean {
    const timeSince = this.getTimeSinceLastInvalidation(conversationId);
    if (timeSince === null) return true; // Never invalidated
    
    return timeSince > maxAgeMs;
  }

  /**
   * Auto-invalidate stale caches (run periodically)
   */
  async cleanupStaleCaches(maxAgeMs = 60 * 60 * 1000) {
    try {
      const stats = await messageCache.getStats();
      console.log('[CacheInvalidation] 📊 Cache stats:', stats);

      // In a real implementation, we'd iterate through conversations
      // and invalidate old ones. For now, we log the stats.
      
      if (stats.oldestCache) {
        const oldestAge = Date.now() - stats.oldestCache;
        if (oldestAge > maxAgeMs) {
          console.log('[CacheInvalidation] ⚠️ Found stale cache (age:', Math.round(oldestAge / 1000 / 60), 'min)');
          // Could trigger cleanup here
        }
      }
    } catch (error) {
      console.error('[CacheInvalidation] ❌ Failed to cleanup:', error);
    }
  }
}

// Singleton instance
export const cacheInvalidation = new CacheInvalidationManager();

/**
 * Auto-cleanup stale caches every hour
 */
if (typeof window !== 'undefined') {
  setInterval(() => {
    cacheInvalidation.cleanupStaleCaches();
  }, 60 * 60 * 1000); // Every hour
}


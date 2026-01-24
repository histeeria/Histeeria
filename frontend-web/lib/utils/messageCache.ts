'use client';

import { Message } from '../api/messages';

export interface CachedConversation {
  conversationId: string;
  messages: Message[];
  lastFetchedAt: number;
  version: number;
}

const DB_NAME = 'upvista-message-cache';
const DB_VERSION = 2; // Incremented for new schema
const MESSAGES_STORE = 'messages';
const METADATA_STORE = 'metadata';
const CACHE_TTL = 30 * 60 * 1000; // 30 minutes

class MessageCache {
  private db: IDBDatabase | null = null;

  async init(): Promise<IDBDatabase> {
    if (this.db) return this.db;

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => {
        console.error('[MessageCache] Failed to open DB:', request.error);
        reject(request.error);
      };

      request.onsuccess = () => {
        this.db = request.result;
        console.log('[MessageCache] ✅ Database initialized');
        resolve(this.db);
      };

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;
        
        // Messages store - one entry per conversation
        if (!db.objectStoreNames.contains(MESSAGES_STORE)) {
          const messagesStore = db.createObjectStore(MESSAGES_STORE, { keyPath: 'conversationId' });
          messagesStore.createIndex('lastFetchedAt', 'lastFetchedAt', { unique: false });
          console.log('[MessageCache] Created messages store');
        }

        // Metadata store - for cache versioning and invalidation
        if (!db.objectStoreNames.contains(METADATA_STORE)) {
          db.createObjectStore(METADATA_STORE, { keyPath: 'key' });
          console.log('[MessageCache] Created metadata store');
        }
      };
    });
  }

  /**
   * Save messages for a conversation with timestamp
   */
  async saveMessages(conversationId: string, messages: Message[]): Promise<void> {
    const db = await this.init();
    
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([MESSAGES_STORE], 'readwrite');
      const store = transaction.objectStore(MESSAGES_STORE);

      const cached: CachedConversation = {
        conversationId,
        messages: messages.map(msg => ({
          ...msg,
          // Remove client-side only fields before caching
          send_state: undefined,
          temp_id: undefined,
          retry_count: undefined,
          send_error: undefined,
        })),
        lastFetchedAt: Date.now(),
        version: 1,
      };

      const request = store.put(cached);

      request.onsuccess = () => {
        console.log('[MessageCache] ✅ Saved', messages.length, 'messages for conversation:', conversationId);
        resolve();
      };

      request.onerror = () => {
        console.error('[MessageCache] ❌ Failed to save messages:', request.error);
        reject(request.error);
      };
    });
  }

  /**
   * Get cached messages for a conversation
   */
  async getMessages(conversationId: string): Promise<Message[] | null> {
    const db = await this.init();

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([MESSAGES_STORE], 'readonly');
      const store = transaction.objectStore(MESSAGES_STORE);
      const request = store.get(conversationId);

      request.onsuccess = () => {
        const cached = request.result as CachedConversation | undefined;

        if (!cached) {
          console.log('[MessageCache] ℹ️ No cache for conversation:', conversationId);
          resolve(null);
          return;
        }

        // Check if cache is stale
        const age = Date.now() - cached.lastFetchedAt;
        const isStale = age > CACHE_TTL;

        if (isStale) {
          console.log('[MessageCache] ⚠️ Cache is stale (age:', Math.round(age / 1000), 's)');
          // Return stale data but mark it for refresh
          resolve(cached.messages.map(msg => ({ ...msg, _isStale: true } as any)));
        } else {
          console.log('[MessageCache] ✅ Retrieved', cached.messages.length, 'cached messages (age:', Math.round(age / 1000), 's)');
          resolve(cached.messages);
        }
      };

      request.onerror = () => {
        console.error('[MessageCache] ❌ Failed to get messages:', request.error);
        reject(request.error);
      };
    });
  }

  /**
   * Update a single message in cache (for real-time updates)
   */
  async updateMessage(conversationId: string, updatedMessage: Message): Promise<void> {
    const db = await this.init();

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([MESSAGES_STORE], 'readwrite');
      const store = transaction.objectStore(MESSAGES_STORE);
      const getRequest = store.get(conversationId);

      getRequest.onsuccess = () => {
        const cached = getRequest.result as CachedConversation | undefined;

        if (!cached) {
          resolve(); // No cache to update
          return;
        }

        // Update or add message
        const messageIndex = cached.messages.findIndex(m => m.id === updatedMessage.id);
        if (messageIndex >= 0) {
          cached.messages[messageIndex] = updatedMessage;
        } else {
          cached.messages.push(updatedMessage);
        }

        // Sort by timestamp
        cached.messages.sort((a, b) => 
          new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
        );

        const putRequest = store.put(cached);
        putRequest.onsuccess = () => {
          console.log('[MessageCache] 🔄 Updated message in cache:', updatedMessage.id);
          resolve();
        };
        putRequest.onerror = () => reject(putRequest.error);
      };

      getRequest.onerror = () => reject(getRequest.error);
    });
  }

  /**
   * Add new message to cache
   */
  async addMessage(conversationId: string, message: Message): Promise<void> {
    return this.updateMessage(conversationId, message);
  }

  /**
   * Remove a message from cache
   */
  async removeMessage(conversationId: string, messageId: string): Promise<void> {
    const db = await this.init();

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([MESSAGES_STORE], 'readwrite');
      const store = transaction.objectStore(MESSAGES_STORE);
      const getRequest = store.get(conversationId);

      getRequest.onsuccess = () => {
        const cached = getRequest.result as CachedConversation | undefined;

        if (!cached) {
          resolve();
          return;
        }

        cached.messages = cached.messages.filter(m => m.id !== messageId);

        const putRequest = store.put(cached);
        putRequest.onsuccess = () => {
          console.log('[MessageCache] ➖ Removed message from cache:', messageId);
          resolve();
        };
        putRequest.onerror = () => reject(putRequest.error);
      };

      getRequest.onerror = () => reject(getRequest.error);
    });
  }

  /**
   * Invalidate cache for a conversation (force refresh)
   */
  async invalidateConversation(conversationId: string): Promise<void> {
    const db = await this.init();

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([MESSAGES_STORE], 'readwrite');
      const store = transaction.objectStore(MESSAGES_STORE);
      const request = store.delete(conversationId);

      request.onsuccess = () => {
        console.log('[MessageCache] 🗑️ Invalidated cache for conversation:', conversationId);
        resolve();
      };

      request.onerror = () => reject(request.error);
    });
  }

  /**
   * Clear all caches
   */
  async clearAll(): Promise<void> {
    const db = await this.init();

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([MESSAGES_STORE, METADATA_STORE], 'readwrite');
      
      const messagesRequest = transaction.objectStore(MESSAGES_STORE).clear();
      const metadataRequest = transaction.objectStore(METADATA_STORE).clear();

      transaction.oncomplete = () => {
        console.log('[MessageCache] 🗑️ Cleared all caches');
        resolve();
      };

      transaction.onerror = () => {
        console.error('[MessageCache] ❌ Failed to clear caches:', transaction.error);
        reject(transaction.error);
      };
    });
  }

  /**
   * Check if cache exists and is fresh
   */
  async isCacheFresh(conversationId: string): Promise<boolean> {
    const db = await this.init();

    return new Promise((resolve) => {
      const transaction = db.transaction([MESSAGES_STORE], 'readonly');
      const store = transaction.objectStore(MESSAGES_STORE);
      const request = store.get(conversationId);

      request.onsuccess = () => {
        const cached = request.result as CachedConversation | undefined;

        if (!cached) {
          resolve(false);
          return;
        }

        const age = Date.now() - cached.lastFetchedAt;
        resolve(age < CACHE_TTL);
      };

      request.onerror = () => resolve(false);
    });
  }

  /**
   * Get cache age in seconds
   */
  async getCacheAge(conversationId: string): Promise<number | null> {
    const db = await this.init();

    return new Promise((resolve) => {
      const transaction = db.transaction([MESSAGES_STORE], 'readonly');
      const store = transaction.objectStore(MESSAGES_STORE);
      const request = store.get(conversationId);

      request.onsuccess = () => {
        const cached = request.result as CachedConversation | undefined;
        if (!cached) {
          resolve(null);
          return;
        }

        const ageMs = Date.now() - cached.lastFetchedAt;
        resolve(Math.round(ageMs / 1000));
      };

      request.onerror = () => resolve(null);
    });
  }

  /**
   * Get statistics about cached data
   */
  async getStats(): Promise<{
    totalConversations: number;
    totalMessages: number;
    oldestCache: number | null;
    newestCache: number | null;
  }> {
    const db = await this.init();

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([MESSAGES_STORE], 'readonly');
      const store = transaction.objectStore(MESSAGES_STORE);
      const request = store.getAll();

      request.onsuccess = () => {
        const allCached = request.result as CachedConversation[];
        
        const totalMessages = allCached.reduce((sum, c) => sum + c.messages.length, 0);
        const timestamps = allCached.map(c => c.lastFetchedAt).filter(t => t > 0);

        resolve({
          totalConversations: allCached.length,
          totalMessages,
          oldestCache: timestamps.length > 0 ? Math.min(...timestamps) : null,
          newestCache: timestamps.length > 0 ? Math.max(...timestamps) : null,
        });
      };

      request.onerror = () => reject(request.error);
    });
  }
}

// Singleton instance
export const messageCache = new MessageCache();


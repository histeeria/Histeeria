'use client';

export interface QueuedMessage {
  id: string; // Temporary ID
  conversationId: string;
  content: string;
  messageType: 'text' | 'image' | 'audio' | 'file';
  attachmentUrl?: string;
  attachmentName?: string;
  attachmentSize?: number;
  attachmentType?: string;
  replyToId?: string;
  timestamp: number;
  retryCount: number;
  lastError?: string;
}

const DB_NAME = 'upvista-offline-queue';
const DB_VERSION = 1;
const STORE_NAME = 'queued-messages';

class OfflineMessageQueue {
  private db: IDBDatabase | null = null;

  async init(): Promise<IDBDatabase> {
    if (this.db) return this.db;

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        resolve(this.db);
      };

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          const store = db.createObjectStore(STORE_NAME, { keyPath: 'id' });
          store.createIndex('conversationId', 'conversationId', { unique: false });
          store.createIndex('timestamp', 'timestamp', { unique: false });
        }
      };
    });
  }

  async addToQueue(message: QueuedMessage): Promise<void> {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.add(message);

      request.onsuccess = () => {
        console.log('[OfflineQueue] ➕ Added message to queue:', message.id);
        resolve();
      };
      request.onerror = () => reject(request.error);
    });
  }

  async removeFromQueue(id: string): Promise<void> {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.delete(id);

      request.onsuccess = () => {
        console.log('[OfflineQueue] ➖ Removed message from queue:', id);
        resolve();
      };
      request.onerror = () => reject(request.error);
    });
  }

  async getQueuedMessages(conversationId?: string): Promise<QueuedMessage[]> {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORE_NAME], 'readonly');
      const store = transaction.objectStore(STORE_NAME);

      if (conversationId) {
        const index = store.index('conversationId');
        const request = index.getAll(conversationId);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      } else {
        const request = store.getAll();
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      }
    });
  }

  async getAllQueuedMessages(): Promise<QueuedMessage[]> {
    return this.getQueuedMessages();
  }

  async updateMessage(message: QueuedMessage): Promise<void> {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.put(message);

      request.onsuccess = () => {
        console.log('[OfflineQueue] 🔄 Updated message in queue:', message.id);
        resolve();
      };
      request.onerror = () => reject(request.error);
    });
  }

  async clearQueue(): Promise<void> {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.clear();

      request.onsuccess = () => {
        console.log('[OfflineQueue] 🗑️ Cleared all queued messages');
        resolve();
      };
      request.onerror = () => reject(request.error);
    });
  }

  async getQueueSize(): Promise<number> {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORE_NAME], 'readonly');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.count();

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }
}

// Singleton instance
export const offlineQueue = new OfflineMessageQueue();


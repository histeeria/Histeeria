/**
 * IndexedDB Cache Utilities
 * For storing feed data, messages, and other cached content
 */

import { openDB, DBSchema, IDBPDatabase } from 'idb';

interface CacheDBSchema extends DBSchema {
  feeds: {
    key: string; // 'feed:home:page:0'
    value: {
      data: any;
      timestamp: number;
      ttl: number; // Time to live in milliseconds
    };
  };
  messages: {
    key: string; // 'messages:conversation:uuid'
    value: {
      data: any;
      timestamp: number;
    };
  };
  profiles: {
    key: string; // 'profile:userId'
    value: {
      data: any;
      timestamp: number;
    };
  };
  keys: {
    key: string; // 'user:userId' or 'conversation:conversationId'
    value: {
      conversationId: string;
      userId?: string;
      publicKey?: string;
      privateKey?: string;
      publicKeyJWK?: JsonWebKey;
      privateKeyJWK?: JsonWebKey;
      sharedSecret?: string;
      createdAt?: number;
      updatedAt?: number;
      [key: string]: any;
    };
  };
}

let dbInstance: IDBPDatabase<CacheDBSchema> | null = null;

export async function getDB(): Promise<IDBPDatabase<CacheDBSchema>> {
  if (dbInstance) {
    return dbInstance;
  }

  dbInstance = await openDB<CacheDBSchema>('histeeria-cache', 1, {
    upgrade(db) {
      // Feeds store
      if (!db.objectStoreNames.contains('feeds')) {
        const feedsStore = db.createObjectStore('feeds');
        // @ts-expect-error - IDBObjectStore.createIndex types are strict
        feedsStore.createIndex('timestamp', 'timestamp');
      }

      // Messages store
      if (!db.objectStoreNames.contains('messages')) {
        const messagesStore = db.createObjectStore('messages');
        // @ts-expect-error - IDBObjectStore.createIndex types are strict
        messagesStore.createIndex('timestamp', 'timestamp');
      }

      // Profiles store
      if (!db.objectStoreNames.contains('profiles')) {
        const profilesStore = db.createObjectStore('profiles');
        // @ts-expect-error - IDBObjectStore.createIndex types are strict
        profilesStore.createIndex('timestamp', 'timestamp');
      }

      // Keys store (E2EE keys)
      if (!db.objectStoreNames.contains('keys')) {
        const keysStore = db.createObjectStore('keys');
        // @ts-expect-error - IDBObjectStore.createIndex types are strict
        keysStore.createIndex('userId', 'userId');
        // @ts-expect-error - IDBObjectStore.createIndex types are strict
        keysStore.createIndex('conversationId', 'conversationId');
      }
    },
  });

  return dbInstance;
}

// Feed cache utilities
export async function getFeedCache(key: string): Promise<any | null> {
  try {
    const db = await getDB();
    const cached = await db.get('feeds', key);
    
    if (!cached) return null;
    
    // Check if cache is expired
    const now = Date.now();
    if (cached.timestamp + cached.ttl < now) {
      await db.delete('feeds', key);
      return null;
    }
    
    return cached.data;
  } catch (error) {
    console.error('Error reading feed cache:', error);
    return null;
  }
}

export async function setFeedCache(key: string, data: any, ttl: number = 5 * 60 * 1000): Promise<void> {
  try {
    const db = await getDB();
    await db.put('feeds', {
      data,
      timestamp: Date.now(),
      ttl,
    }, key);
  } catch (error) {
    console.error('Error writing feed cache:', error);
  }
}

export async function clearFeedCache(pattern?: string): Promise<void> {
  try {
    const db = await getDB();
    const tx = db.transaction('feeds', 'readwrite');
    const store = tx.objectStore('feeds');
    
    if (pattern) {
      // Clear specific pattern (e.g., 'feed:home:*')
      const keys = await store.getAllKeys();
      const keysToDelete = keys.filter(key => key.startsWith(pattern));
      await Promise.all(keysToDelete.map(key => store.delete(key)));
    } else {
      // Clear all
      await store.clear();
    }
    
    await tx.done;
  } catch (error) {
    console.error('Error clearing feed cache:', error);
  }
}

// Message cache utilities
export async function getMessageCache(key: string): Promise<any | null> {
  try {
    const db = await getDB();
    const cached = await db.get('messages', key);
    return cached?.data || null;
  } catch (error) {
    console.error('Error reading message cache:', error);
    return null;
  }
}

export async function setMessageCache(key: string, data: any): Promise<void> {
  try {
    const db = await getDB();
    await db.put('messages', {
      data,
      timestamp: Date.now(),
    }, key);
  } catch (error) {
    console.error('Error writing message cache:', error);
  }
}

// Profile cache utilities
export async function getProfileCache(userId: string): Promise<any | null> {
  try {
    const db = await getDB();
    const cached = await db.get('profiles', `profile:${userId}`);
    
    if (!cached) return null;
    
    // Profile cache TTL: 30 minutes
    const now = Date.now();
    const ttl = 30 * 60 * 1000;
    if (cached.timestamp + ttl < now) {
      await db.delete('profiles', `profile:${userId}`);
      return null;
    }
    
    return cached.data;
  } catch (error) {
    console.error('Error reading profile cache:', error);
    return null;
  }
}

export async function setProfileCache(userId: string, data: any): Promise<void> {
  try {
    const db = await getDB();
    await db.put('profiles', {
      data,
      timestamp: Date.now(),
    }, `profile:${userId}`);
  } catch (error) {
    console.error('Error writing profile cache:', error);
  }
}

// Cleanup expired cache entries
export async function cleanupExpiredCache(): Promise<void> {
  try {
    const db = await getDB();
    const now = Date.now();
    
    // Clean feeds
    const feedsTx = db.transaction('feeds', 'readwrite');
    const feedsStore = feedsTx.objectStore('feeds');
    // @ts-expect-error - IDBObjectStore.index types are strict
    const feedsIndex = feedsStore.index('timestamp');
    const feedsKeys = await feedsIndex.getAllKeys();
    
    for (const key of feedsKeys) {
      const cached = await feedsStore.get(key);
      if (cached && cached.timestamp + cached.ttl < now) {
        await feedsStore.delete(key);
      }
    }
    await feedsTx.done;
    
    // Clean profiles (30 min TTL)
    const profilesTx = db.transaction('profiles', 'readwrite');
    const profilesStore = profilesTx.objectStore('profiles');
    // @ts-expect-error - IDBObjectStore.index types are strict
    const profilesIndex = profilesStore.index('timestamp');
    const profilesKeys = await profilesIndex.getAllKeys();
    const profileTtl = 30 * 60 * 1000;
    
    for (const key of profilesKeys) {
      const cached = await profilesStore.get(key);
      if (cached && cached.timestamp + profileTtl < now) {
        await profilesStore.delete(key);
      }
    }
    await profilesTx.done;
  } catch (error) {
    console.error('Error cleaning up expired cache:', error);
  }
}

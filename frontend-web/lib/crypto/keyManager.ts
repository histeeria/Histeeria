/**
 * E2EE Key Management System
 * Stores and manages encryption keys in IndexedDB
 */

import { getDB } from '@/lib/cache/indexedDB';
import { 
  generateRSAKeyPair, 
  importRSAPublicKey, 
  importRSAPrivateKey,
  type EncryptionResult,
  type DecryptionResult,
  encryptMessage as e2eeEncrypt,
  decryptMessage as e2eeDecrypt,
} from './e2ee';

export interface ConversationKey {
  conversationId: string;
  userId: string; // Other participant's user ID
  publicKey: string; // Their public key (PEM format)
  privateKey?: string; // Our private key (only if we generated it)
  sharedSecret?: string; // Optional: shared secret for session keys
  createdAt: number;
  updatedAt: number;
}

export interface UserKeyPair {
  userId: string;
  publicKey: string;
  privateKey: string;
  publicKeyJWK: JsonWebKey;
  privateKeyJWK: JsonWebKey;
  createdAt: number;
}

/**
 * Key Manager - Singleton
 */
class KeyManager {
  private userKeyPair: UserKeyPair | null = null;
  private conversationKeys: Map<string, ConversationKey> = new Map();
  private initialized = false;

  /**
   * Initialize key manager (load keys from IndexedDB)
   */
  async initialize(): Promise<void> {
    if (this.initialized) return;

    try {
      // Load user's own key pair
      const userKeys = await this.loadUserKeyPair();
      if (userKeys) {
        this.userKeyPair = userKeys;
        console.log('[KeyManager] ✅ Loaded user key pair');
      } else {
        // Generate new key pair
        console.log('[KeyManager] 🔑 Generating new user key pair...');
        const keyPair = await generateRSAKeyPair();
        
        // Get userId from JWT token or localStorage
        let userId = localStorage.getItem('userId');
        if (!userId) {
          // Try to extract from JWT token
          const token = localStorage.getItem('token');
          if (token) {
            try {
              const base64Url = token.split('.')[1];
              const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
              const jsonPayload = decodeURIComponent(
                atob(base64)
                  .split('')
                  .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
                  .join('')
              );
              const payload = JSON.parse(jsonPayload);
              // Backend uses UserID (capital), but JSON encoding may lowercase it
              userId = payload.UserID || payload.user_id || payload.sub || payload.id;
            } catch (e) {
              console.warn('[KeyManager] Could not extract userId from token:', e);
            }
          }
        }
        
        if (!userId || userId === 'unknown') {
          throw new Error('Cannot initialize key manager: userId not found. Please log in first.');
        }

        this.userKeyPair = {
          userId,
          publicKey: keyPair.publicKey,
          privateKey: keyPair.privateKey,
          publicKeyJWK: keyPair.publicKeyJWK,
          privateKeyJWK: keyPair.privateKeyJWK,
          createdAt: Date.now(),
        };

        await this.saveUserKeyPair(this.userKeyPair);
        console.log('[KeyManager] ✅ Generated and saved user key pair');
      }

      // Load conversation keys
      await this.loadConversationKeys();

      this.initialized = true;
    } catch (error) {
      console.error('[KeyManager] Failed to initialize:', error);
      throw error;
    }
  }

  /**
   * Get user's own public key
   */
  getMyPublicKey(): string | null {
    return this.userKeyPair?.publicKey || null;
  }

  /**
   * Get user's own private key
   */
  getMyPrivateKey(): string | null {
    return this.userKeyPair?.privateKey || null;
  }

  /**
   * Get or create conversation key
   */
  async getConversationKey(conversationId: string, otherUserId: string): Promise<ConversationKey | null> {
    const key = this.conversationKeys.get(conversationId);
    if (key) return key;

    // Try to load from IndexedDB
    try {
      const db = await getDB();
      const stored = await db.get('keys', `conversation:${conversationId}`);
      
      if (stored) {
        // Extract conversationId from stored value (may have prefix)
        let storedConvId = stored.conversationId || conversationId;
        if (storedConvId.startsWith('conversation:')) {
          storedConvId = storedConvId.replace('conversation:', '');
        }
        
        const convKey: ConversationKey = {
          conversationId: storedConvId,
          userId: stored.userId || otherUserId,
          publicKey: stored.publicKey || '',
          privateKey: stored.privateKey,
          sharedSecret: stored.sharedSecret,
          createdAt: stored.createdAt || Date.now(),
          updatedAt: stored.updatedAt || Date.now(),
        };
        this.conversationKeys.set(conversationId, convKey);
        return convKey;
      }
    } catch (error) {
      console.error('[KeyManager] Failed to load conversation key:', error);
    }

    return null;
  }

  /**
   * Set conversation key (when we receive other user's public key)
   */
  async setConversationKey(
    conversationId: string,
    otherUserId: string,
    otherUserPublicKey: string
  ): Promise<void> {
    try {
      const convKey: ConversationKey = {
        conversationId,
        userId: otherUserId,
        publicKey: otherUserPublicKey,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };

      this.conversationKeys.set(conversationId, convKey);

      // Save to IndexedDB with proper key
      const db = await getDB();
      const dbKey = `conversation:${conversationId}`;
      await db.put('keys', {
        conversationId: dbKey, // Store with prefix to match loading logic
        userId: otherUserId,
        publicKey: otherUserPublicKey,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      }, dbKey);

      console.log('[KeyManager] ✅ Saved conversation key for', conversationId);
    } catch (error) {
      console.error('[KeyManager] Failed to save conversation key:', error);
      throw error;
    }
  }

  /**
   * Encrypt message for conversation
   * Automatically triggers key exchange if key doesn't exist
   */
  async encryptMessageForConversation(
    conversationId: string,
    plaintext: string
  ): Promise<EncryptionResult> {
    const startTime = performance.now();
    console.log(`[KeyManager] 🔐 [${new Date().toISOString()}] STEP 2: Starting encryption for conversation: ${conversationId}`);
    console.log(`[KeyManager] 📝 Plaintext length: ${plaintext.length} bytes`);
    
    if (!this.userKeyPair) {
      throw new Error('User key pair not initialized');
    }

    // Get conversation key
    let convKey = await this.getConversationKey(conversationId, '');
    
    // If key doesn't exist, try to get it from the conversation (other user's ID)
    if (!convKey) {
      console.warn(`[KeyManager] ⚠️ Conversation key not found for ${conversationId}, attempting to fetch from conversation...`);
      
      // Try to get conversation details to find other user's ID
      try {
        const { messagesAPI } = await import('../api/messages');
        const conversationResponse = await messagesAPI.getConversation(conversationId);
        
        if (conversationResponse.success && conversationResponse.conversation) {
          const conversation = conversationResponse.conversation;
          // Get the other user's ID
          const token = localStorage.getItem('token');
          if (token) {
            try {
              const base64Url = token.split('.')[1];
              const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
              const jsonPayload = decodeURIComponent(
                atob(base64)
                  .split('')
                  .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
                  .join('')
              );
              const payload = JSON.parse(jsonPayload);
              const currentUserId = payload.user_id || payload.UserID;
              
              // Find other user ID
              const otherUserId = conversation.participant1_id === currentUserId 
                ? conversation.participant2_id 
                : conversation.participant1_id;
              
              // Try to initialize E2EE for this conversation
              const { initializeE2EEForConversation } = await import('../messaging/keyExchange');
              await initializeE2EEForConversation(conversationId, otherUserId);
              
              // Try to get key again
              convKey = await this.getConversationKey(conversationId, otherUserId);
            } catch (e) {
              console.error('[KeyManager] Failed to get current user ID:', e);
            }
          }
        }
      } catch (error) {
        console.error('[KeyManager] Failed to fetch conversation for key exchange:', error);
      }
      
      // If still no key, throw error (will fall back to plaintext)
      if (!convKey) {
        throw new Error(`Conversation key not found for ${conversationId}. Key exchange may be in progress.`);
      }
    }

    // Import recipient's public key
    console.log(`[KeyManager] 🔑 Loading recipient's public key for conversation: ${conversationId}`);
    const recipientPublicKey = await importRSAPublicKey(convKey.publicKey);
    console.log(`[KeyManager] ✅ Public key imported successfully`);

    // Encrypt message
    console.log(`[KeyManager] 🔒 Encrypting message...`);
    const encrypted = await e2eeEncrypt(plaintext, recipientPublicKey);
    const encryptionTime = performance.now() - startTime;
    console.log(`[KeyManager] ✅ [${new Date().toISOString()}] STEP 2: Encryption complete in ${encryptionTime.toFixed(2)}ms`);
    console.log(`[KeyManager] 📦 Encrypted content length: ${encrypted.encryptedContent.length} bytes`);
    console.log(`[KeyManager] 🔐 IV length: ${encrypted.iv.length} bytes`);
    return encrypted;
  }

  /**
   * Decrypt message from conversation
   * Uses our own private key (message was encrypted with our public key)
   */
  async decryptMessageFromConversation(
    conversationId: string,
    encryptedContent: string,
    iv: string
  ): Promise<DecryptionResult> {
    const startTime = performance.now();
    console.log(`[KeyManager] 🔓 [${new Date().toISOString()}] STEP 4: Starting decryption for conversation: ${conversationId}`);
    console.log(`[KeyManager] 📦 Encrypted content length: ${encryptedContent.length} bytes`);
    console.log(`[KeyManager] 🔐 IV length: ${iv.length} bytes`);
    
    if (!this.userKeyPair) {
      throw new Error('User key pair not initialized. Please log in again.');
    }

    // For decryption, we only need our own private key (message was encrypted with our public key)
    // The conversation key (other user's public key) is only needed for encryption
    console.log(`[KeyManager] 🔑 Loading our private key for decryption...`);
    const privateKey = await importRSAPrivateKey(this.userKeyPair.privateKey);
    console.log(`[KeyManager] ✅ Private key imported successfully`);

    // Decrypt message using our private key
    console.log(`[KeyManager] 🔓 Decrypting message with our private key...`);
    const decrypted = await e2eeDecrypt(encryptedContent, iv, privateKey);
    const decryptionTime = performance.now() - startTime;
    console.log(`[KeyManager] ✅ [${new Date().toISOString()}] STEP 4: Decryption complete in ${decryptionTime.toFixed(2)}ms`);
    console.log(`[KeyManager] 📝 Decrypted plaintext length: ${decrypted.plaintext.length} bytes`);
    console.log(`[KeyManager] ✅ Decrypted content: "${decrypted.plaintext.substring(0, 50)}${decrypted.plaintext.length > 50 ? '...' : ''}"`);
    return decrypted;
  }

  /**
   * Save user key pair to IndexedDB
   */
  private async saveUserKeyPair(keyPair: UserKeyPair): Promise<void> {
    try {
      if (!keyPair.userId || keyPair.userId === 'unknown') {
        throw new Error('Cannot save user key pair: userId is missing or invalid');
      }

      const db = await getDB();
      const key = `user:${keyPair.userId}`;
      
      // Ensure all required fields are present
      const value = {
        conversationId: key,
        userId: keyPair.userId,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
        publicKeyJWK: keyPair.publicKeyJWK,
        privateKeyJWK: keyPair.privateKeyJWK,
        createdAt: keyPair.createdAt || Date.now(),
      };

      // Explicitly pass the key as the third parameter
      await db.put('keys', value, key);
      
      console.log('[KeyManager] ✅ Saved user key pair for', keyPair.userId);
    } catch (error) {
      console.error('[KeyManager] Failed to save user key pair:', error);
      throw error;
    }
  }

  /**
   * Load user key pair from IndexedDB
   */
  private async loadUserKeyPair(): Promise<UserKeyPair | null> {
    try {
      // Get userId from JWT token or localStorage
      let userId = localStorage.getItem('userId');
      if (!userId) {
        // Try to extract from JWT token
        const token = localStorage.getItem('token');
        if (token) {
          try {
            const base64Url = token.split('.')[1];
            const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
            const jsonPayload = decodeURIComponent(
              atob(base64)
                .split('')
                .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
                .join('')
            );
            const payload = JSON.parse(jsonPayload);
            // Backend uses UserID (capital), but JSON encoding may lowercase it
            userId = payload.UserID || payload.user_id || payload.sub || payload.id;
          } catch (e) {
            console.warn('[KeyManager] Could not extract userId from token:', e);
            return null;
          }
        } else {
          return null;
        }
      }
      
      if (!userId || userId === 'unknown') {
        return null;
      }

      const db = await getDB();
      const stored = await db.get('keys', `user:${userId}`);
      
      if (stored && stored.publicKeyJWK && stored.privateKeyJWK) {
        return {
          userId: stored.userId || userId,
          publicKey: stored.publicKey || '',
          privateKey: stored.privateKey || '',
          publicKeyJWK: stored.publicKeyJWK,
          privateKeyJWK: stored.privateKeyJWK,
          createdAt: stored.createdAt || Date.now(),
        };
      }
    } catch (error) {
      console.error('[KeyManager] Failed to load user key pair:', error);
    }

    return null;
  }

  /**
   * Load all conversation keys from IndexedDB
   */
  private async loadConversationKeys(): Promise<void> {
    try {
      const db = await getDB();
      const keys = await db.getAll('keys');
      
      for (const key of keys) {
        if (key.conversationId?.startsWith('conversation:')) {
          const convKey: ConversationKey = {
            conversationId: key.conversationId.replace('conversation:', ''),
            userId: key.userId || '',
            publicKey: key.publicKey || '',
            privateKey: key.privateKey,
            sharedSecret: key.sharedSecret,
            createdAt: key.createdAt || Date.now(),
            updatedAt: key.updatedAt || Date.now(),
          };
          this.conversationKeys.set(convKey.conversationId, convKey);
        }
      }

      console.log('[KeyManager] ✅ Loaded', this.conversationKeys.size, 'conversation keys');
    } catch (error) {
      console.error('[KeyManager] Failed to load conversation keys:', error);
    }
  }
}

// Singleton instance
export const keyManager = new KeyManager();

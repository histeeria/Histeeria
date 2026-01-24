/**
 * Pending Message Sync
 * Syncs pending messages from server on app open/reconnect
 */

import { messagesAPI, Message } from '@/lib/api/messages';
import { keyManager } from '@/lib/crypto/keyManager';
import { messageCache } from '@/lib/utils/messageCache';

export interface PendingMessageSyncOptions {
  conversationId?: string; // Optional: sync specific conversation
  onProgress?: (progress: number) => void;
  onMessageSynced?: (message: Message) => void;
}

export interface SyncResult {
  syncedCount: number;
  failedCount: number;
  totalPending: number;
  errors: Error[];
}

/**
 * Sync pending messages from server
 * Decrypts messages and stores them locally, then marks as delivered
 */
export async function syncPendingMessages(
  options: PendingMessageSyncOptions = {}
): Promise<SyncResult> {
  const { conversationId, onProgress, onMessageSynced } = options;
  
  const result: SyncResult = {
    syncedCount: 0,
    failedCount: 0,
    totalPending: 0,
    errors: [],
  };

  try {
    // 1. Get pending messages from server
    onProgress?.(10);
    const response = conversationId
      ? await messagesAPI.getPendingMessages(conversationId)
      : await messagesAPI.getAllPendingMessages();

    if (!response.success || !response.messages) {
      throw new Error('Failed to fetch pending messages');
    }

    const pendingMessages = response.messages;
    result.totalPending = pendingMessages.length;

    if (pendingMessages.length === 0) {
      onProgress?.(100);
      return result;
    }

    console.log(`[PendingSync] 📬 Found ${pendingMessages.length} pending messages`);

    // 2. Decrypt and store each message
    const syncedMessageIds: string[] = [];
    
    for (let i = 0; i < pendingMessages.length; i++) {
      const message = pendingMessages[i];
      const progress = 10 + (i / pendingMessages.length) * 70; // 10-80%
      onProgress?.(progress);

      try {
        // Decrypt message content (if encrypted)
        let decryptedContent = message.content;
        
        if (message.encrypted_content && message.iv) {
          try {
            const decrypted = await keyManager.decryptMessageFromConversation(
              message.conversation_id,
              message.encrypted_content,
              message.iv
            );
            decryptedContent = decrypted.plaintext;
          } catch (decryptError) {
            console.error(`[PendingSync] Failed to decrypt message ${message.id}:`, decryptError);
            // Continue with encrypted content as fallback
            result.failedCount++;
            result.errors.push(new Error(`Decryption failed for message ${message.id}`));
            continue;
          }
        }

        // Create decrypted message
        const decryptedMessage: Message = {
          ...message,
          content: decryptedContent,
          encrypted_content: undefined, // Remove encrypted content after decryption
          status: 'delivered', // Mark as delivered locally
          synced_at: new Date().toISOString(),
        };

        // Store in local cache
        await messageCache.addMessage(message.conversation_id, decryptedMessage);
        
        // Callback
        onMessageSynced?.(decryptedMessage);
        
        syncedMessageIds.push(message.id);
        result.syncedCount++;

        console.log(`[PendingSync] ✅ Synced message ${message.id} for conversation ${message.conversation_id}`);
      } catch (error) {
        console.error(`[PendingSync] Failed to sync message ${message.id}:`, error);
        result.failedCount++;
        result.errors.push(error instanceof Error ? error : new Error(String(error)));
      }
    }

    // 3. Mark messages as delivered on server (triggers server deletion)
    if (syncedMessageIds.length > 0) {
      onProgress?.(85);
      
      try {
        await messagesAPI.markMessagesDelivered(syncedMessageIds);
        console.log(`[PendingSync] ✅ Marked ${syncedMessageIds.length} messages as delivered`);
      } catch (error) {
        console.error('[PendingSync] Failed to mark messages as delivered:', error);
        // Don't fail entire sync if marking fails
        result.errors.push(error instanceof Error ? error : new Error(String(error)));
      }
    }

    onProgress?.(100);
    console.log(`[PendingSync] ✅ Sync complete: ${result.syncedCount}/${result.totalPending} synced`);

    return result;
  } catch (error) {
    console.error('[PendingSync] Sync failed:', error);
    result.errors.push(error instanceof Error ? error : new Error(String(error)));
    throw error;
  }
}

/**
 * Check for pending messages and sync if needed
 */
export async function checkAndSyncPendingMessages(
  options: PendingMessageSyncOptions = {}
): Promise<SyncResult> {
  try {
    // Key manager is already initialized as singleton

    return await syncPendingMessages(options);
  } catch (error) {
    console.error('[PendingSync] Check and sync failed:', error);
    throw error;
  }
}

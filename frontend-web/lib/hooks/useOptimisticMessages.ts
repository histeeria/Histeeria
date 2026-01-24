/**
 * useOptimisticMessages - Hook for instant message sending with optimistic UI
 * Messages appear immediately, then sync with server in background
 */

import { useState, useCallback, useMemo, useEffect, useRef } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { messagesAPI, Message } from '../api/messages';
import { messageWS } from '../websocket/MessageWebSocket';
import { offlineQueue, QueuedMessage } from '../utils/offlineQueue';
import { messageCache } from '../utils/messageCache';
import { keyManager } from '../crypto/keyManager';

interface OptimisticMessage extends Message {
  tempId?: string;
  isSending?: boolean;
  sendError?: string;
}

interface UseOptimisticMessagesOptions {
  conversationId: string;
  initialMessages?: Message[];
}

export function useOptimisticMessages({
  conversationId,
  initialMessages = [],
}: UseOptimisticMessagesOptions) {
  // Real messages from server
  const [realMessages, setRealMessages] = useState<Message[]>(initialMessages);

  // Optimistic messages (not yet confirmed by server)
  const [optimisticMessages, setOptimisticMessages] = useState<Map<string, OptimisticMessage>>(
    new Map()
  );
  
  // Track pending HTTP fallback timeouts (to clear if WebSocket delivers)
  const pendingFallbacksRef = useRef<Map<string, NodeJS.Timeout>>(new Map());
  
  // Store plaintext content for messages until WebSocket delivers (keyed by temp_id or message id)
  const plaintextStoreRef = useRef<Map<string, string>>(new Map());
  
  // Track last sent message for fast lookup when WebSocket arrives before HTTP confirms
  // This allows us to find plaintext even if messageId isn't stored yet
  const lastSentMessageRef = useRef<{
    plaintext: string;
    timestamp: number;
    conversationId: string;
    tempId: string;
  } | null>(null);

  // ==================== SEND MESSAGE ====================

  /**
   * Send a text message with optimistic UI + offline queue
   */
  const sendMessage = useCallback(
    async (content: string, replyToId?: string) => {
      const tempId = uuidv4();
      const isOnline = navigator.onLine;

      // Create optimistic message
      const optimisticMsg: OptimisticMessage = {
        id: tempId,
        conversation_id: conversationId,
        sender_id: '', // Will be populated by server
        content,
        message_type: 'text',
        status: 'sent',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        is_mine: true,
        isSending: true,
        tempId,
        temp_id: tempId,
        send_state: isOnline ? 'sending' : 'queued',
        retry_count: 0,
        reply_to_id: replyToId,
      };

      // 1. Store plaintext immediately (BEFORE sending) so WebSocket can retrieve it
      // WebSocket may arrive before HTTP response, so we need to store it now
      plaintextStoreRef.current.set(tempId, content);
      
      // 2. Add to UI immediately (INSTANT FEEDBACK)
      setOptimisticMessages((prev) => new Map(prev).set(tempId, optimisticMsg));

      // 3. If offline, add to queue and return
      if (!isOnline) {
        console.log('[OptimisticUI] 📴 Offline - queuing message:', tempId);
        try {
          await offlineQueue.addToQueue({
            id: tempId,
            conversationId,
            content,
            messageType: 'text',
            replyToId,
            timestamp: Date.now(),
            retryCount: 0,
          });

          // Update to queued state
          setOptimisticMessages((prev) => {
            const next = new Map(prev);
            const msg = next.get(tempId);
            if (msg) {
              msg.send_state = 'queued';
              msg.isSending = false;
              next.set(tempId, msg);
            }
            return next;
          });
        } catch (error) {
          console.error('[OptimisticUI] Failed to queue message:', error);
        }
        return;
      }

      const sendStartTime = performance.now();
      console.log(`[OptimisticUI] 🚀 [${new Date().toISOString()}] STEP 2: Starting message send for conversation: ${conversationId}`);
      console.log(`[OptimisticUI] 📝 Plaintext content: "${content}"`);
      console.log(`[OptimisticUI] 📝 Content length: ${content.length} bytes`);
      
      try {
        // 3. ENCRYPT MESSAGE BEFORE SENDING (E2EE)
        let encryptedContent: string | undefined;
        let iv: string | undefined;
        
        try {
          // Initialize key manager if not already done
          await keyManager.initialize();
          
          // Encrypt message for this conversation
          // This will automatically trigger key exchange if key doesn't exist
          const encryptionResult = await keyManager.encryptMessageForConversation(
            conversationId,
            content
          );
          
          encryptedContent = encryptionResult.encryptedContent;
          iv = encryptionResult.iv;
          
          console.log(`[OptimisticUI] 🔐 [${new Date().toISOString()}] STEP 2: Message encrypted successfully`);
          console.log(`[OptimisticUI] 📦 Encrypted content length: ${encryptedContent.length} bytes`);
          console.log(`[OptimisticUI] 🔐 IV length: ${iv.length} bytes`);
        } catch (encryptError) {
          console.warn('[OptimisticUI] ⚠️ E2EE encryption failed, sending plaintext:', encryptError);
          // Continue with plaintext if encryption fails (fallback)
          // This allows messages to be sent even if key exchange hasn't completed yet
          encryptedContent = undefined;
          iv = undefined;
        }

        // CRITICAL: Store last sent message for fast lookup when WebSocket arrives before HTTP confirms
        // For MY OWN messages, we always have the plaintext (we typed it!), so store it here
        const now = Date.now();
        lastSentMessageRef.current = {
          plaintext: content,
          timestamp: now,
          conversationId,
          tempId,
        };
        console.log('[OptimisticUI] 📌 Stored last sent message for fast lookup (conversation:', conversationId, 'tempId:', tempId, ')');

        // 4. Send to server in background (with encrypted content if available)
        const apiStartTime = performance.now();
        console.log(`[OptimisticUI] 📡 [${new Date().toISOString()}] STEP 2: Sending message to backend API...`);
        const response = await messagesAPI.sendMessage(
          conversationId,
          encryptedContent || content, // Send encrypted if available, otherwise plaintext
          tempId,
          replyToId,
          iv // Include IV if encrypted
        );
        const apiTime = performance.now() - apiStartTime;
        console.log(`[OptimisticUI] ✅ [${new Date().toISOString()}] STEP 2: Message sent to backend in ${apiTime.toFixed(2)}ms`);
        console.log(`[OptimisticUI] 📬 Server response - Message ID: ${response.message.id}`);

        // Store plaintext content (already stored above by tempId, now also store by message ID)
        const plaintextContent = content;
        const wasEncrypted = !!encryptedContent;
        
        // Store by message ID (in addition to tempId which was stored earlier)
        const messageId = response.message.id;
        plaintextStoreRef.current.set(messageId, plaintextContent);
        
        // Also update optimistic message with real message ID for lookup
        setOptimisticMessages((prev) => {
          const next = new Map(prev);
          const optMsg = next.get(tempId);
          if (optMsg) {
            optMsg.id = messageId; // Update with real ID for WebSocket matching
            next.set(tempId, optMsg);
          }
          return next;
        });
        
        console.log('[OptimisticUI] ✅ Stored plaintext for tempId:', tempId, 'and messageId:', messageId);

        // 4. DON'T remove optimistic message yet - keep it until WebSocket confirms
        // This ensures we can retrieve plaintext when WebSocket arrives
        // The optimistic message will be removed when WebSocket delivers the real message

        // WebSocket will deliver the message with proper timestamp
        // If WebSocket doesn't deliver within 1 second, add from HTTP response as fallback
        const fallbackTimeout = setTimeout(() => {
          setRealMessages((prev) => {
            // Check if message already exists (WebSocket might have delivered it)
            if (prev.some(m => m.id === messageId)) {
              console.log('[OptimisticUI] Message already received via WebSocket, skipping HTTP fallback');
              return prev;
            }
            
            // Add from HTTP response as fallback
            // CRITICAL: For encrypted messages, server returns empty content, so use our stored plaintext
            const serverMessage: Message = {
              ...response.message,
              sync_state: 'synced' as const,
              synced_at: new Date().toISOString(),
              // If message was encrypted, server has empty content, so use our plaintext
              // If message was plaintext, server has the content
              content: wasEncrypted ? plaintextContent : (response.message.content || plaintextContent),
            };
            
            console.log('[OptimisticUI] ⚠️ Adding message from HTTP fallback (WebSocket may have failed)');
            console.log('[OptimisticUI] 📝 Fallback message content:', serverMessage.content ? `"${serverMessage.content.substring(0, 50)}${serverMessage.content.length > 50 ? '...' : ''}"` : 'EMPTY');
            return [...prev, serverMessage];
          });
          pendingFallbacksRef.current.delete(messageId);
        }, 1000); // 1 second delay to let WebSocket deliver first
        
        // Store timeout so we can clear it if WebSocket delivers
        pendingFallbacksRef.current.set(messageId, fallbackTimeout);

        console.log('[OptimisticUI] ✅ Message confirmed by server, waiting for WebSocket delivery');
      } catch (error) {
        // 5. Mark as failed - can be retried
        console.error('[OptimisticUI] ❌ Failed to send message:', error);

        setOptimisticMessages((prev) => {
          const next = new Map(prev);
          const msg = next.get(tempId);
          if (msg) {
            msg.isSending = false;
            msg.send_state = 'failed';
            msg.sendError = error instanceof Error ? error.message : 'Failed to send';
            msg.send_error = msg.sendError;
            msg.retry_count = (msg.retry_count || 0);
            next.set(tempId, msg);
          }
          return next;
        });

        // Add to offline queue for retry
        try {
          await offlineQueue.addToQueue({
            id: tempId,
            conversationId,
            content,
            messageType: 'text',
            replyToId,
            timestamp: Date.now(),
            retryCount: 0,
            lastError: error instanceof Error ? error.message : 'Failed to send',
          });
        } catch (queueError) {
          console.error('[OptimisticUI] Failed to queue failed message:', queueError);
        }
      }
    },
    [conversationId]
  );

  /**
   * Send a message with attachment
   */
  const sendMessageWithAttachment = useCallback(
    async (
      content: string,
      attachmentUrl: string,
      attachmentName: string,
      attachmentSize: number,
      attachmentType: string,
      messageType: 'image' | 'audio' | 'file' | 'video',
      replyToId?: string
    ) => {
      const tempId = uuidv4();

      const optimisticMsg: OptimisticMessage = {
        id: tempId,
        conversation_id: conversationId,
        sender_id: '',
        content,
        message_type: messageType,
        attachment_url: attachmentUrl,
        attachment_name: attachmentName,
        attachment_size: attachmentSize,
        attachment_type: attachmentType,
        status: 'sent',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        is_mine: true,
        isSending: true,
        tempId,
        reply_to_id: replyToId,
      };

      setOptimisticMessages((prev) => new Map(prev).set(tempId, optimisticMsg));

      try {
        // CRITICAL FIX: Actually send to server to persist in database!
        const response = await messagesAPI.sendMessageWithAttachment(
          conversationId,
          content,
          attachmentUrl,
          attachmentName,
          attachmentSize,
          attachmentType,
          messageType,
          replyToId
        );

        // Replace optimistic with real message from server
        setOptimisticMessages((prev) => {
          const next = new Map(prev);
          next.delete(tempId);
          return next;
        });

        setRealMessages((prev) => [...prev, response.message]);

        console.log('[OptimisticUI] ✅ Attachment message confirmed by server:', response.message.id);
      } catch (error) {
        console.error('[OptimisticUI] ❌ Failed to send attachment message:', error);
        
        // Mark as failed
        setOptimisticMessages((prev) => {
          const next = new Map(prev);
          const msg = next.get(tempId);
          if (msg) {
            msg.isSending = false;
            msg.sendError = 'Failed to send';
            next.set(tempId, msg);
          }
          return next;
        });
      }
    },
    [conversationId]
  );

  /**
   * Retry failed message
   */
  const retryMessage = useCallback(
    async (tempId: string) => {
      const msg = optimisticMessages.get(tempId);
      if (!msg) {
        console.warn('[OptimisticUI] Message not found for retry:', tempId);
        return;
      }

      console.log('[OptimisticUI] 🔄 Retrying message:', tempId);

      // Reset error state and mark as sending
      setOptimisticMessages((prev) => {
        const next = new Map(prev);
        const message = next.get(tempId);
        if (message) {
          message.isSending = true;
          message.send_state = 'sending';
          message.sendError = undefined;
          message.send_error = undefined;
          message.retry_count = (message.retry_count || 0) + 1;
          next.set(tempId, message);
        }
        return next;
      });

      // Retry sending
      try {
        const response = await messagesAPI.sendMessage(
          conversationId,
          msg.content,
          tempId,
          msg.reply_to_id
        );

        // Success - remove from optimistic and add to real
        setOptimisticMessages((prev) => {
          const next = new Map(prev);
          next.delete(tempId);
          return next;
        });

        setRealMessages((prev) => [...prev, response.message]);

        // Remove from offline queue on success
        try {
          await offlineQueue.removeFromQueue(tempId);
          console.log('[OptimisticUI] ✅ Removed message from offline queue:', tempId);
        } catch (error) {
          console.warn('[OptimisticUI] Failed to remove from queue:', error);
        }
      } catch (error) {
        console.error('[OptimisticUI] ❌ Retry failed:', error);
        
        setOptimisticMessages((prev) => {
          const next = new Map(prev);
          const message = next.get(tempId);
          if (message) {
            message.isSending = false;
            message.send_state = 'failed';
            message.sendError = error instanceof Error ? error.message : 'Failed to send';
            message.send_error = message.sendError;
            next.set(tempId, message);
          }
          return next;
        });
      }
    },
    [conversationId, optimisticMessages]
  );

  // ==================== WEBSOCKET LISTENERS ====================

  useEffect(() => {
    // CRITICAL FIX: Ensure WebSocket is connected before registering handlers
    const token = localStorage.getItem('token');
    if (token && !messageWS.isConnected()) {
      console.log('[OptimisticUI] WebSocket not connected, connecting now...');
      messageWS.connect(token);
    }
    
    // Listen for new messages from WebSocket (INSTANT delivery)
    // CRITICAL: Listen for ALL messages in this conversation (both sent and received)
    // This ensures real-time consistency - sender sees their message via WebSocket too
    console.log(`[OptimisticUI] Registering WebSocket handler for 'new_message' in conversation: ${conversationId}`);
    const unsubscribeNewMessage = messageWS.on('new_message', async (message: Message) => {
      const wsReceiveTime = performance.now();
      const messageTimestamp = new Date(message.created_at).getTime();
      const now = Date.now();
      const deliveryLatency = now - messageTimestamp;
      
      console.log(`[OptimisticUI] ⚡ [${new Date().toISOString()}] STEP 3: Received via WebSocket - Message ID: ${message.id}`);
      console.log(`[OptimisticUI] 📬 Delivery details - is_mine: ${message.is_mine}, conversation: ${message.conversation_id}`);
      console.log(`[OptimisticUI] ⏱️ WebSocket delivery latency: ${deliveryLatency}ms (message created: ${message.created_at}, received: ${new Date().toISOString()})`);
      
      // Only process messages for this conversation
      if (message.conversation_id !== conversationId) {
        return; // Ignore messages from other conversations
      }
      
      // Process ALL messages (both sent and received) for consistency
      // CRITICAL: Decrypt only messages from other users (we already have plaintext for our messages)
      let decryptedMessage = message;
      
      // Only decrypt if it's NOT our message AND it's encrypted
      if (!message.is_mine && message.encrypted_content && message.iv) {
        try {
          console.log(`[OptimisticUI] 🔓 [${new Date().toISOString()}] STEP 4: Starting decryption for message: ${message.id}`);
          console.log(`[OptimisticUI] Message details:`, {
            messageId: message.id,
            conversationId: message.conversation_id,
            hasEncryptedContent: !!message.encrypted_content,
            encryptedContentLength: message.encrypted_content?.length,
            hasIV: !!message.iv,
            ivLength: message.iv?.length,
          });
          
          const decryptStartTime = performance.now();
          
          // Ensure key manager is initialized
          await keyManager.initialize();
          
          // Try to decrypt message from other user
          const decrypted = await keyManager.decryptMessageFromConversation(
            message.conversation_id,
            message.encrypted_content,
            message.iv
          );

          const decryptTime = performance.now() - decryptStartTime;
          console.log(`[OptimisticUI] ✅ Decryption complete in ${decryptTime.toFixed(2)}ms`);

          // Create decrypted message
          decryptedMessage = {
            ...message,
            content: decrypted.plaintext || '[Decrypted message]', // Ensure content is never empty
            encrypted_content: undefined, // Remove encrypted content after decryption
            sync_state: 'synced' as const,
            synced_at: new Date().toISOString(),
          };

          console.log(`[OptimisticUI] 🔓 [${new Date().toISOString()}] STEP 4: Message decrypted successfully: "${decrypted.plaintext.substring(0, 50)}${decrypted.plaintext.length > 50 ? '...' : ''}"`);
        } catch (decryptError: any) {
          console.error('[OptimisticUI] ❌ Failed to decrypt message:', decryptError);
          console.error('[OptimisticUI] Decryption error details:', {
            messageId: message.id,
            conversationId: message.conversation_id,
            errorMessage: decryptError?.message,
            errorStack: decryptError?.stack,
            hasEncryptedContent: !!message.encrypted_content,
            hasIV: !!message.iv,
          });
          
          // Try to retry key exchange and decrypt again
          try {
            console.log('[OptimisticUI] 🔄 Attempting to retry key exchange and decrypt...');
            const conversationResponse = await messagesAPI.getConversation(message.conversation_id);
            if (conversationResponse.success && conversationResponse.conversation) {
              const conversation = conversationResponse.conversation;
              const token = localStorage.getItem('token');
              if (token) {
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
                const otherUserId = conversation.participant1_id === currentUserId 
                  ? conversation.participant2_id 
                  : conversation.participant1_id;
                
                const { initializeE2EEForConversation } = await import('../messaging/keyExchange');
                await initializeE2EEForConversation(message.conversation_id, otherUserId);
                
                // Retry decryption after key exchange
                const retryDecrypted = await keyManager.decryptMessageFromConversation(
                  message.conversation_id,
                  message.encrypted_content,
                  message.iv
                );
                
                console.log(`[OptimisticUI] ✅ Retry decryption successful for message ${message.id}`);
                decryptedMessage = {
                  ...message,
                  content: retryDecrypted.plaintext,
                  encrypted_content: undefined,
                  sync_state: 'synced' as const,
                  synced_at: new Date().toISOString(),
                };
              }
            }
          } catch (retryError) {
            console.error('[OptimisticUI] ❌ Retry decryption also failed:', retryError);
            // CRITICAL FIX: Show error placeholder instead of empty content
            decryptedMessage = {
              ...message,
              content: '[Unable to decrypt message. Please check your encryption keys.]', // Show error message instead of empty
              sync_state: 'error' as const,
              decryption_error: true,
            };
            console.warn('[OptimisticUI] ⚠️ Showing error placeholder for failed decryption');
          }
        }
      } else if (message.is_mine) {
        // CRITICAL FIX: For our own messages, preserve plaintext from store
        // The server message only has encrypted_content (we can't decrypt our own messages)
        // So we need to retrieve the plaintext we stored when sending
        
        // Log what we're looking for
        console.log('[OptimisticUI] 🔍 Looking for plaintext - temp_id:', message.temp_id, 'message.id:', message.id);
        console.log('[OptimisticUI] 🔍 Plaintext store keys:', Array.from(plaintextStoreRef.current.keys()));
        
        // CRITICAL FIX: For WebSocket messages, we have message.id but NOT temp_id
        // So we MUST look up by message.id FIRST, then temp_id as fallback
        let plaintextContent: string | undefined;
        
        // Try message.id FIRST (WebSocket has this, not temp_id)
        if (message.id) {
          plaintextContent = plaintextStoreRef.current.get(message.id);
          if (plaintextContent) {
            console.log('[OptimisticUI] ✅ Found plaintext by message.id:', message.id);
          }
        }
        
        // Fallback to temp_id (if HTTP response hasn't confirmed yet)
        if (!plaintextContent && message.temp_id) {
          plaintextContent = plaintextStoreRef.current.get(message.temp_id);
          if (plaintextContent) {
            console.log('[OptimisticUI] ✅ Found plaintext by temp_id:', message.temp_id);
          }
        }
        
        // CRITICAL FIX: Check lastSentMessage if store lookups failed
        // This handles the case where WebSocket arrives BEFORE HTTP confirms (WebSocket is faster)
        // For MY OWN messages, we ALWAYS have the plaintext (we typed it!)
        if (!plaintextContent && lastSentMessageRef.current) {
          const lastSent = lastSentMessageRef.current;
          const messageTime = new Date(message.created_at).getTime();
          const timeDiff = Math.abs(messageTime - lastSent.timestamp);
          
          // Match if same conversation AND sent within last 10 seconds
          if (lastSent.conversationId === message.conversation_id && timeDiff < 10000) {
            plaintextContent = lastSent.plaintext;
            console.log('[OptimisticUI] ✅ Found plaintext in lastSentMessage (conversation:', lastSent.conversationId, 'timeDiff:', timeDiff, 'ms)');
          }
        }
        
        // Also check optimistic messages as fallback (WebSocket may arrive before HTTP response)
        // The backend doesn't include temp_id in WebSocket messages, so we match by message.id or timestamp
        if (!plaintextContent) {
          console.log('[OptimisticUI] 🔍 Checking optimistic messages, count:', optimisticMessages.size);
          
          // CRITICAL FIX: Try matching by message.id FIRST (WebSocket has this, not temp_id)
          // The optimistic message gets updated with real message.id when HTTP confirms (line 172)
          if (message.id) {
            for (const optMsg of optimisticMessages.values()) {
              if (optMsg.id === message.id) {
                plaintextContent = optMsg.content;
                console.log('[OptimisticUI] ✅ Found plaintext in optimistic message by message.id:', message.id);
                break;
              }
            }
          }
          
          // Fallback: Try matching by temp_id (if HTTP response hasn't confirmed yet)
          if (!plaintextContent && message.temp_id) {
            for (const optMsg of optimisticMessages.values()) {
              if (optMsg.temp_id === message.temp_id) {
                plaintextContent = optMsg.content;
                console.log('[OptimisticUI] ✅ Found plaintext in optimistic message by temp_id:', message.temp_id);
                break;
              }
            }
          }
          
          // Match by timestamp and conversation (WebSocket message timestamp should be close to optimistic message)
          if (!plaintextContent) {
            const wsTime = new Date(message.created_at).getTime();
            let bestMatch: OptimisticMessage | null = null;
            let smallestDiff = Infinity;
            let mostRecentMatch: OptimisticMessage | null = null;
            let mostRecentTime = -1;
            
            for (const optMsg of optimisticMessages.values()) {
              // Must match conversation
              if (optMsg.conversation_id !== message.conversation_id) {
                console.log('[OptimisticUI] ⏭️ Skipping optimistic message - conversation mismatch:', optMsg.conversation_id, 'vs', message.conversation_id);
                continue;
              }
              
              // Must be our message
              if (!optMsg.is_mine) {
                console.log('[OptimisticUI] ⏭️ Skipping optimistic message - not ours');
                continue;
              }
              
              // Track most recent message as fallback
              const optTime = new Date(optMsg.created_at).getTime();
              if (optTime > mostRecentTime) {
                mostRecentTime = optTime;
                mostRecentMatch = optMsg;
              }
              
              // Check timestamp difference (should be within 5 seconds)
              const timeDiff = Math.abs(wsTime - optTime);
              
              if (timeDiff < 5000 && timeDiff < smallestDiff) {
                smallestDiff = timeDiff;
                bestMatch = optMsg;
              }
            }
            
            if (bestMatch) {
              plaintextContent = bestMatch.content;
              console.log('[OptimisticUI] ✅ Found plaintext in optimistic message by timestamp match (diff:', smallestDiff, 'ms)');
            } else if (mostRecentMatch) {
              // Fallback: use most recent optimistic message in conversation (WebSocket arrives very quickly)
              plaintextContent = mostRecentMatch.content;
              console.log('[OptimisticUI] ✅ Found plaintext in most recent optimistic message (fallback)');
            } else {
              console.log('[OptimisticUI] ⚠️ No matching optimistic message found');
            }
          }
        }
        
        // Remove optimistic message if it exists
        // Match by temp_id, message.id, or timestamp (since WebSocket may not have temp_id)
        setOptimisticMessages((prev) => {
          const next = new Map(prev);
          let removed = false;
          
          for (const [key, optMsg] of next.entries()) {
            // Match by temp_id or message.id (if available)
            if ((message.temp_id && optMsg.temp_id === message.temp_id) || 
                (message.id && optMsg.id === message.id)) {
              next.delete(key);
              console.log('[OptimisticUI] ✅ Removed optimistic message by ID match:', message.id || message.temp_id);
              removed = true;
              break;
            }
          }
          
          // If not found by ID, try matching by timestamp and conversation
          if (!removed) {
            const wsTime = new Date(message.created_at).getTime();
            let bestMatch: string | null = null;
            let smallestDiff = Infinity;
            
            for (const [key, optMsg] of next.entries()) {
              // Must match conversation and be our message
              if (optMsg.conversation_id !== message.conversation_id || !optMsg.is_mine) continue;
              
              const optTime = new Date(optMsg.created_at).getTime();
              const timeDiff = Math.abs(wsTime - optTime);
              
              if (timeDiff < 5000 && timeDiff < smallestDiff) {
                smallestDiff = timeDiff;
                bestMatch = key;
              }
            }
            
            if (bestMatch) {
              next.delete(bestMatch);
              console.log('[OptimisticUI] ✅ Removed optimistic message by timestamp match (diff:', smallestDiff, 'ms)');
            }
          }
          
          return next;
        });
        
        // Clean up plaintext store after use (keep for a bit in case of duplicates)
        if (message.temp_id) {
          const tempId = message.temp_id;
          setTimeout(() => plaintextStoreRef.current.delete(tempId), 5000);
        }
        if (message.id) {
          const msgId = message.id;
          setTimeout(() => plaintextStoreRef.current.delete(msgId), 5000);
        }
        
        // Use plaintext from store if available, otherwise show placeholder
        if (!message.content && message.encrypted_content) {
          decryptedMessage = {
            ...message,
            content: plaintextContent || '[Your encrypted message]', // Use preserved plaintext
            sync_state: 'synced' as const,
            synced_at: new Date().toISOString(),
          };
          if (plaintextContent) {
            console.log('[OptimisticUI] ✅ Preserved plaintext content from store:', plaintextContent.substring(0, Math.min(50, plaintextContent.length)));
          } else {
            console.warn('[OptimisticUI] ⚠️ Could not find plaintext in store, showing placeholder');
          }
        } else {
          // Our message - ensure it has proper sync state
          decryptedMessage = {
            ...message,
            sync_state: 'synced' as const,
            synced_at: new Date().toISOString(),
          };
        }
      } else {
        // Message without encryption - ensure sync state
        decryptedMessage = {
          ...message,
          sync_state: 'synced' as const,
          synced_at: new Date().toISOString(),
        };
      }
        
        // CRITICAL: Clear any pending HTTP fallback timeout since WebSocket delivered
        if (decryptedMessage.id && pendingFallbacksRef.current.has(decryptedMessage.id)) {
          clearTimeout(pendingFallbacksRef.current.get(decryptedMessage.id)!);
          pendingFallbacksRef.current.delete(decryptedMessage.id);
          console.log('[OptimisticUI] ✅ Cleared HTTP fallback - WebSocket delivered first');
        }
        
        // Add IMMEDIATELY to UI (REAL-TIME) - for both our messages and other user's
        setRealMessages((prev) => {
          // Check if message already exists (CRITICAL for deduplication)
          const existingIndex = prev.findIndex((m) => 
            m.id === decryptedMessage.id || 
            (m.temp_id && m.temp_id === decryptedMessage.temp_id) ||
            (decryptedMessage.temp_id && m.id === decryptedMessage.temp_id)
          );
          
          if (existingIndex !== -1) {
            // Update existing message (in case we got a newer version)
            const updated = [...prev];
            updated[existingIndex] = decryptedMessage;
            console.log('[OptimisticUI] 🔄 Updated existing message:', decryptedMessage.id);
            return updated;
          }
          
          console.log('[OptimisticUI] ⚡ REAL-TIME: Adding new message to chat, prev count:', prev.length);
          
          // Add message and SORT by timestamp (CRITICAL for consistency)
          const updated = [...prev, decryptedMessage].sort((a, b) => {
            const timeA = new Date(a.created_at || a.updated_at || 0).getTime();
            const timeB = new Date(b.created_at || b.updated_at || 0).getTime();
            // If timestamps are equal, use ID for stable sort
            if (timeA === timeB) {
              return a.id.localeCompare(b.id);
            }
            return timeA - timeB; // Ascending order (oldest first)
          });
          
          console.log('[OptimisticUI] ✅ New messages array length:', updated.length, 'sorted by timestamp');
          
          // Update cache in background (with decrypted message)
          messageCache.addMessage(conversationId, decryptedMessage).catch(err => 
            console.error('[OptimisticUI] Failed to cache new message:', err)
          );
          
          // Trigger scroll IMMEDIATELY after React updates DOM
          requestAnimationFrame(() => {
            const scrollContainer = document.querySelector('[data-message-scroll]');
            if (scrollContainer) {
              scrollContainer.scrollTop = scrollContainer.scrollHeight;
            }
          });
          
          return updated;
        });

        // Trigger badge update immediately after adding message to chat
        console.log('[OptimisticUI] 📬 New message added, will be marked as read');
    });

    // Listen for delivery status updates (INSTANT)
    const unsubscribeDelivered = messageWS.on('message_delivered', (data: any) => {
      console.log('[OptimisticUI] 📬 Received message_delivered event:', data);
      if (data.conversation_id === conversationId) {
        console.log('[OptimisticUI] ✅ Updating message', data.message_id, 'to delivered');
        setRealMessages((prev) =>
          prev.map((msg) =>
            msg.id === data.message_id
              ? { ...msg, status: 'delivered' as const, delivered_at: data.delivered_at }
              : msg
          )
        );
      } else {
        console.log('[OptimisticUI] ⏭️ Ignoring delivery (different conversation)');
      }
    });

    // Listen for read receipts (INSTANT)
    const unsubscribeRead = messageWS.on('message_read', (data: any) => {
      console.log('[OptimisticUI] 💙 Received message_read event:', data);
      if (data.conversation_id === conversationId) {
        console.log('[OptimisticUI] ✅ Marking all MY messages as read in conversation', conversationId);
        setRealMessages((prev) => {
          const updated = prev.map((msg) =>
            msg.is_mine && msg.status !== 'read'
              ? { 
                  ...msg, 
                  status: 'read' as const,
                  sync_state: 'read' as const,
                  read_at: data.read_at 
                }
              : msg
          );
          const changedCount = updated.filter((msg, i) => msg.status !== prev[i].status).length;
          console.log('[OptimisticUI] 💙 Marked', changedCount, 'messages as read');
          return updated;
        });
      } else {
        console.log('[OptimisticUI] ⏭️ Ignoring read receipt (different conversation)');
      }
    });

    // Listen for reactions
    const unsubscribeReaction = messageWS.on('reaction', (data: any) => {
      if (data.message_id) {
        setRealMessages((prev) =>
          prev.map((msg) => {
            if (msg.id === data.message_id) {
              const reactions = msg.reactions || [];
              // Check if user already reacted
              const existingIndex = reactions.findIndex((r) => r.user_id === data.reaction.user_id);

              if (existingIndex > -1) {
                // Update existing reaction
                reactions[existingIndex] = data.reaction;
              } else {
                // Add new reaction
                reactions.push(data.reaction);
              }

              return { ...msg, reactions: [...reactions] };
            }
            return msg;
          })
        );
      }
    });

    // Listen for reaction removals (toggle off)
    const unsubscribeReactionRemoved = messageWS.on('reaction_removed', (data: any) => {
      console.log('[OptimisticUI] 🔄 Received reaction_removed event:', data);
      if (data.message_id && data.emoji) {
        setRealMessages((prev) =>
          prev.map((msg) => {
            if (msg.id === data.message_id) {
              return {
                ...msg,
                reactions: (msg.reactions || []).filter((r) => r.emoji !== data.emoji),
              };
            }
            return msg;
          })
        );
        console.log('[OptimisticUI] ✅ Removed reaction:', data.emoji, 'from message:', data.message_id);
      }
    });

    // Listen for message deletions
    const unsubscribeDeleted = messageWS.on('message_deleted', (data: any) => {
      console.log('[OptimisticUI] 🗑️ Received message_deleted event:', data);
      if (data.conversation_id === conversationId) {
        // Remove message from UI
        setRealMessages((prev) => prev.filter((msg) => msg.id !== data.message_id));
        
        // Remove from cache
        messageCache.removeMessage(conversationId, data.message_id).catch(err =>
          console.error('[OptimisticUI] Failed to remove from cache:', err)
        );
        
        console.log('[OptimisticUI] ✅ Removed deleted message:', data.message_id);
      }
    });

    // Listen for message edits
    const unsubscribeEdited = messageWS.on('message_edited', (data: any) => {
      console.log('[OptimisticUI] ✏️ Received message_edited event:', data);
      if (data.message && data.message.conversation_id === conversationId) {
        const editedMessage = data.message;
        setRealMessages((prev) =>
          prev.map((msg) => {
            if (msg.id === editedMessage.id) {
              return {
                ...msg,
                content: editedMessage.content,
                edited_at: editedMessage.edited_at,
                edit_count: editedMessage.edit_count,
                original_content: editedMessage.original_content,
              };
            }
            return msg;
          })
        );
        console.log('[OptimisticUI] ✅ Updated edited message:', editedMessage.id);
      }
    });

    // Listen for message pins
    const unsubscribePinned = messageWS.on('message_pinned', (data: any) => {
      console.log('[OptimisticUI] 📌 Received message_pinned event:', data);
      if (data.message_id) {
        setRealMessages((prev) =>
          prev.map((msg) => {
            if (msg.id === data.message_id) {
              return {
                ...msg,
                is_pinned: true,
                pinned_at: new Date().toISOString(),
              };
            }
            return msg;
          })
        );
      }
    });

    // Listen for message unpins
    const unsubscribeUnpinned = messageWS.on('message_unpinned', (data: any) => {
      console.log('[OptimisticUI] 📌 Received message_unpinned event:', data);
      if (data.message_id) {
        setRealMessages((prev) =>
          prev.map((msg) => {
            if (msg.id === data.message_id) {
              return {
                ...msg,
                is_pinned: false,
                pinned_at: undefined,
              };
            }
            return msg;
          })
        );
      }
    });

    return () => {
      unsubscribeNewMessage();
      unsubscribeDelivered();
      unsubscribeRead();
      unsubscribeReaction();
      unsubscribeReactionRemoved();
      unsubscribeDeleted();
      unsubscribeEdited();
      unsubscribePinned();
      unsubscribeUnpinned();
    };
  }, [conversationId]);

  // ==================== COMBINED MESSAGES ====================

  /**
   * Merge real and optimistic messages, sorted by timestamp
   * ALWAYS sorted chronologically: oldest first, newest last
   * CRITICAL: Proper deduplication and stable sorting for consistency
   */
  const allMessages = useMemo(() => {
    // Combine real and optimistic messages
    const combined = [
      ...realMessages,
      ...Array.from(optimisticMessages.values()),
    ];

    // Remove duplicates - prioritize real messages over optimistic
    // Use both ID and temp_id for deduplication
    const uniqueMap = new Map<string, Message>();
    const tempIdMap = new Map<string, Message>();
    
    combined.forEach(msg => {
      // First, check by temp_id (for optimistic messages)
      if (msg.temp_id) {
        const existing = tempIdMap.get(msg.temp_id);
        if (!existing || (msg.id && !existing.id)) {
          // Keep this one (either new or has real ID)
          tempIdMap.set(msg.temp_id, msg);
        }
      }
      
      // Then, check by real ID (prioritize real messages)
      if (msg.id && msg.id !== msg.temp_id) {
        const existing = uniqueMap.get(msg.id);
        if (!existing || (existing.temp_id && !msg.temp_id)) {
          // Keep this one (either new or this is real message)
          uniqueMap.set(msg.id, msg);
        }
      }
    });
    
    // Merge both maps, prioritizing real IDs
    const allUnique = new Map<string, Message>();
    tempIdMap.forEach(msg => {
      if (msg.id && msg.id !== msg.temp_id) {
        allUnique.set(msg.id, msg); // Real message
      } else if (msg.temp_id) {
        allUnique.set(msg.temp_id, msg); // Optimistic message
      }
    });
    uniqueMap.forEach(msg => {
      allUnique.set(msg.id, msg); // Real messages override optimistic
    });

    // Convert to array and sort chronologically with stable sort
    const uniqueMessages = Array.from(allUnique.values());
    
    const sorted = uniqueMessages.sort((a, b) => {
      const timeA = new Date(a.created_at || a.updated_at || 0).getTime();
      const timeB = new Date(b.created_at || b.updated_at || 0).getTime();
      
      // If timestamps are equal (or very close), use ID for stable sort
      if (Math.abs(timeA - timeB) < 100) { // Within 100ms, consider equal
        return (a.id || a.temp_id || '').localeCompare(b.id || b.temp_id || '');
      }
      
      return timeA - timeB; // Ascending order (oldest first)
    });
    
    console.log('[OptimisticUI] 📊 Total messages:', sorted.length, 'Real:', realMessages.length, 'Optimistic:', optimisticMessages.size);
    return sorted;
  }, [realMessages, optimisticMessages]);

  // ==================== ACTIONS ====================

  /**
   * Add a message received from WebSocket
   */
  const addMessage = useCallback((message: Message) => {
    setRealMessages((prev) => {
      if (prev.some((m) => m.id === message.id)) {
        return prev;
      }
      return [...prev, message];
    });
  }, []);

  /**
   * Update message status
   */
  const updateMessageStatus = useCallback((messageId: string, status: 'sent' | 'delivered' | 'read') => {
    setRealMessages((prev) =>
      prev.map((msg) =>
        msg.id === messageId ? { ...msg, status } : msg
      )
    );
  }, []);

  /**
   * Set initial messages (from API)
   * WhatsApp-style: Decrypt encrypted messages when setting initial messages
   */
  const setMessages = useCallback(async (messages: Message[]) => {
    // Decrypt all encrypted messages before setting
    const decryptedMessages = await Promise.all(
      messages.map(async (message: Message) => {
        // Decrypt messages that have encrypted_content and IV but no content
        if (message.encrypted_content && message.iv && !message.content) {
          // Skip decryption for our own messages - WebSocket will deliver with plaintext
          if (message.is_mine) {
            return {
              ...message,
              content: '[Your encrypted message]', // Placeholder until WebSocket delivers
            };
          }
          
          // For other user's messages, decrypt immediately
          try {
            console.log(`[OptimisticUI] 🔓 Decrypting initial message ${message.id}`);
            await keyManager.initialize();
            const decrypted = await keyManager.decryptMessageFromConversation(
              message.conversation_id,
              message.encrypted_content,
              message.iv
            );
            
            return {
              ...message,
              content: decrypted.plaintext,
              encrypted_content: undefined,
            };
          } catch (error) {
            console.error(`[OptimisticUI] ❌ Failed to decrypt initial message ${message.id}:`, error);
            return {
              ...message,
              content: '[Unable to decrypt message]',
              decryption_error: true,
            };
          }
        }
        return message;
      })
    );
    
    setRealMessages(decryptedMessages);
    setOptimisticMessages(new Map()); // Clear optimistic messages
  }, []);

  /**
   * Remove a message (for delete)
   */
  const removeMessage = useCallback((messageId: string) => {
    setRealMessages((prev) => prev.filter((m) => m.id !== messageId));
    setOptimisticMessages((prev) => {
      const next = new Map(prev);
      next.delete(messageId);
      return next;
    });
  }, []);

  // ==================== OFFLINE QUEUE SYNC ====================

  /**
   * Process offline queue - send all queued messages
   */
  const processOfflineQueue = useCallback(async () => {
    try {
      const queuedMessages = await offlineQueue.getQueuedMessages(conversationId);
      
      if (queuedMessages.length === 0) {
        console.log('[OptimisticUI] No queued messages to process');
        return;
      }

      console.log('[OptimisticUI] 📤 Processing', queuedMessages.length, 'queued messages');

      for (const queued of queuedMessages) {
        // Update optimistic message to "sending"
        setOptimisticMessages((prev) => {
          const next = new Map(prev);
          const msg = next.get(queued.id);
          if (msg) {
            msg.send_state = 'sending';
            msg.isSending = true;
            next.set(queued.id, msg);
          }
          return next;
        });

        // Try to send
        try {
          const response = await messagesAPI.sendMessage(
            conversationId,
            queued.content,
            queued.id,
            queued.replyToId
          );

          // Success - remove from queue and optimistic, add to real
          await offlineQueue.removeFromQueue(queued.id);
          
          setOptimisticMessages((prev) => {
            const next = new Map(prev);
            next.delete(queued.id);
            return next;
          });

          setRealMessages((prev) => [...prev, response.message]);
          console.log('[OptimisticUI] ✅ Queued message sent:', queued.id);
        } catch (error) {
          console.error('[OptimisticUI] ❌ Failed to send queued message:', error);
          
          // Mark as failed
          setOptimisticMessages((prev) => {
            const next = new Map(prev);
            const msg = next.get(queued.id);
            if (msg) {
              msg.isSending = false;
              msg.send_state = 'failed';
              msg.sendError = error instanceof Error ? error.message : 'Failed to send';
              msg.send_error = msg.sendError;
              next.set(queued.id, msg);
            }
            return next;
          });

          // Update retry count in queue
          await offlineQueue.updateMessage({
            ...queued,
            retryCount: queued.retryCount + 1,
            lastError: error instanceof Error ? error.message : 'Failed to send',
          });
        }
      }
    } catch (error) {
      console.error('[OptimisticUI] Error processing offline queue:', error);
    }
  }, [conversationId]);

  // Listen for network coming back online
  useEffect(() => {
    const handleOnline = () => {
      console.log('[OptimisticUI] 🌐 Network restored - processing queue');
      processOfflineQueue();
    };

    window.addEventListener('network_online', handleOnline);
    
    // Also check on mount if there are queued messages
    if (navigator.onLine) {
      processOfflineQueue();
    }

    return () => {
      window.removeEventListener('network_online', handleOnline);
    };
  }, [processOfflineQueue]);

  return {
    messages: allMessages,
    realMessages,
    optimisticMessages: Array.from(optimisticMessages.values()),
    sendMessage,
    sendMessageWithAttachment,
    retryMessage,
    processOfflineQueue,
    addMessage,
    updateMessageStatus,
    setMessages,
    removeMessage,
  };
}


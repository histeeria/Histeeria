/**
 * useInfiniteMessages - Infinite scroll for message history with IndexedDB caching
 * Provides fast initial load and smooth pagination
 */

import { useState, useEffect, useCallback, useRef } from 'react';
import { messagesAPI, Message } from '../api/messages';
import { messageCache } from '../utils/messageCache';
import { keyManager } from '../crypto/keyManager';

// ============================================
// ENHANCED MESSAGE CACHING
// ============================================

/**
 * Get cached messages from new robust cache
 */
async function getCachedMessages(conversationId: string): Promise<Message[] | null> {
  try {
    return await messageCache.getMessages(conversationId);
  } catch (error) {
    console.error('[MessageCache] Error getting cached messages:', error);
    return null;
  }
}

/**
 * Save messages to new robust cache
 */
async function saveCachedMessages(conversationId: string, messages: Message[]): Promise<void> {
  try {
    await messageCache.saveMessages(conversationId, messages);
  } catch (error) {
    console.error('[MessageCache] Error saving cached messages:', error);
  }
}

// ============================================
// HOOK
// ============================================

interface UseInfiniteMessagesOptions {
  conversationId: string;
  pageSize?: number;
  enableCache?: boolean;
}

export function useInfiniteMessages({
  conversationId,
  pageSize = 50,
  enableCache = true,
}: UseInfiniteMessagesOptions) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [offset, setOffset] = useState(0);
  const [cacheLoaded, setCacheLoaded] = useState(false);

  // Refs for scroll management
  const scrollRef = useRef<HTMLDivElement>(null);
  const previousScrollHeight = useRef(0);
  const shouldScrollToBottom = useRef(true);

  // ==================== INITIAL LOAD ====================

  const loadInitialMessages = async () => {
    setIsLoading(true);

    try {
      // WhatsApp-style: Load minimal history from cache/database, rely on WebSocket for new messages
      // 1. Try cache first (instant load) - only decrypt encrypted messages
      if (enableCache && !cacheLoaded) {
        const cached = await getCachedMessages(conversationId);
        if (cached && cached.length > 0) {
          // Decrypt cached messages if needed (they might be encrypted if cache was saved before decryption)
          const decryptedCached = await Promise.all(
            cached.map(async (message: Message) => {
              // Decrypt messages that are encrypted (both ours and theirs)
              if (message.encrypted_content && message.iv) {
                // For our messages, we might not have plaintext in cache, skip decryption (we'll get it from WebSocket)
                if (message.is_mine) {
                  // Keep encrypted for our messages - WebSocket will deliver with plaintext
                  return message;
                }
                
                // For other user's messages, decrypt if content is empty
                if (!message.content) {
                  try {
                    console.log(`[InfiniteScroll] 🔓 Decrypting cached message ${message.id}`);
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
                    console.error(`[InfiniteScroll] ❌ Failed to decrypt cached message ${message.id}:`, error);
                    return {
                      ...message,
                      content: '[Unable to decrypt message]',
                      decryption_error: true,
                    };
                  }
                }
              }
              // Return message as-is if already decrypted or not encrypted
              return message;
            })
          );
          
          console.log(`[InfiniteScroll] 📦 Loaded ${decryptedCached.length} messages from cache`);
          setMessages(decryptedCached);
          setCacheLoaded(true);
          shouldScrollToBottom.current = true;
        }
      }

      // 2. WhatsApp-style: Fetch only recent messages from server (last 20-30 messages for context)
      // WebSocket will deliver new messages in real-time, so we don't need to fetch everything
      const recentMessageLimit = 30; // Only fetch last 30 messages for initial context
      const response = await messagesAPI.getMessages(conversationId, recentMessageLimit, 0);

      if (response.success) {
        const loadedMessages = response.messages || [];
        
        // Initialize key manager and attempt key exchange if needed
        try {
          await keyManager.initialize();
          
          // Try to initialize E2EE for this conversation if we have encrypted messages
          const hasEncryptedMessages = loadedMessages.some(
            (m: Message) => !m.is_mine && m.encrypted_content && m.iv
          );
          
          if (hasEncryptedMessages) {
            try {
              // Get conversation to find other user's ID
              const conversationResponse = await messagesAPI.getConversation(conversationId);
              if (conversationResponse.success && conversationResponse.conversation) {
                const conversation = conversationResponse.conversation;
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
                    const otherUserId = conversation.participant1_id === currentUserId 
                      ? conversation.participant2_id 
                      : conversation.participant1_id;
                    
                    // Initialize key exchange
                    const { initializeE2EEForConversation } = await import('../messaging/keyExchange');
                    await initializeE2EEForConversation(conversationId, otherUserId);
                    console.log('[InfiniteScroll] ✅ Key exchange initialized');
                  } catch (e) {
                    console.warn('[InfiniteScroll] Could not determine other user ID:', e);
                  }
                }
              }
            } catch (error) {
              console.warn('[InfiniteScroll] Failed to initialize key exchange:', error);
            }
          }
        } catch (error) {
          console.error('[InfiniteScroll] Failed to initialize key manager:', error);
        }
        
        // WhatsApp-style: Decrypt ALL encrypted messages from database
        // For our messages: We can't decrypt (encrypted with recipient's key), but WebSocket will deliver with plaintext
        // For their messages: Decrypt immediately
        const decryptedMessages = await Promise.all(
          loadedMessages.map(async (message: Message) => {
            // Decrypt messages that have encrypted_content and IV but no content
            if (message.encrypted_content && message.iv && !message.content) {
              // For our own messages: Can't decrypt (encrypted with recipient's public key)
              // WebSocket will deliver these with plaintext, so show placeholder
              if (message.is_mine) {
                return {
                  ...message,
                  content: '[Your encrypted message]', // Placeholder - WebSocket will replace with plaintext
                };
              }
              
              // For other user's messages: Decrypt immediately (encrypted with our public key)
              try {
                console.log(`[InfiniteScroll] 🔓 Decrypting message ${message.id} from database`);
                await keyManager.initialize();
                const decrypted = await keyManager.decryptMessageFromConversation(
                  message.conversation_id,
                  message.encrypted_content,
                  message.iv
                );
                
                return {
                  ...message,
                  content: decrypted.plaintext,
                  encrypted_content: undefined, // Remove encrypted content after decryption
                };
              } catch (error: any) {
                console.error(`[InfiniteScroll] ❌ Failed to decrypt message ${message.id}:`, error);
                console.error(`[InfiniteScroll] Error details:`, {
                  messageId: message.id,
                  hasEncryptedContent: !!message.encrypted_content,
                  hasIV: !!message.iv,
                  errorMessage: error?.message,
                  errorStack: error?.stack,
                });
                
                // Try to retry key exchange and decrypt again
                try {
                  const conversationResponse = await messagesAPI.getConversation(conversationId);
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
                      await initializeE2EEForConversation(conversationId, otherUserId);
                      
                      // Retry decryption after key exchange
                      const retryDecrypted = await keyManager.decryptMessageFromConversation(
                        message.conversation_id,
                        message.encrypted_content!,
                        message.iv!
                      );
                      
                      console.log(`[InfiniteScroll] ✅ Retry decryption successful for message ${message.id}`);
                      return {
                        ...message,
                        content: retryDecrypted.plaintext,
                        encrypted_content: undefined,
                      };
                    }
                  }
                } catch (retryError) {
                  console.error(`[InfiniteScroll] ❌ Retry decryption also failed:`, retryError);
                }
                
                return {
                  ...message,
                  content: '[Unable to decrypt message]',
                  decryption_error: true,
                };
              }
            }
            // Return message as-is if not encrypted or already has content
            return message;
          })
        );
        
        // Ensure messages are in chronological order (oldest first)
        const sorted = [...decryptedMessages].sort((a, b) => 
          new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
        );
        
        console.log(`[InfiniteScroll] 📥 Loaded ${sorted.length} messages from server`);
        console.log(`[InfiniteScroll] Oldest: ${sorted[0]?.created_at}, Newest: ${sorted[sorted.length - 1]?.created_at}`);
        console.log(`[InfiniteScroll] hasMore: ${response.has_more}`);
        
        setMessages(sorted);
        setHasMore(response.has_more || false);
        setOffset(sorted.length);

        // Update cache
        if (enableCache) {
          await saveCachedMessages(conversationId, sorted);
        }

        // Scroll to bottom only if cache wasn't loaded
        if (!cacheLoaded) {
          shouldScrollToBottom.current = true;
        }
      }
    } catch (error) {
      console.error('[InfiniteScroll] ❌ Error loading initial messages:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // ==================== LOAD MORE ====================

  const loadMore = useCallback(async () => {
    if (isLoadingMore || !hasMore || isLoading) {
      console.log('[InfiniteScroll] Skip loadMore - isLoadingMore:', isLoadingMore, 'hasMore:', hasMore, 'isLoading:', isLoading);
      return;
    }

    console.log('[InfiniteScroll] 🔄 Loading more messages from offset:', offset);
    setIsLoadingMore(true);

    // Save current scroll height to maintain position
    if (scrollRef.current) {
      previousScrollHeight.current = scrollRef.current.scrollHeight;
    }

    try {
      const response = await messagesAPI.getMessages(conversationId, pageSize, offset);
      console.log('[InfiniteScroll] API response:', response);

      if (response.success) {
        // WhatsApp-style: Decrypt ALL encrypted messages from database
        const decryptedMessages = await Promise.all(
          (response.messages || []).map(async (message: Message) => {
            // Decrypt messages that have encrypted_content and IV but no content
            if (message.encrypted_content && message.iv && !message.content) {
              // For our own messages: Can't decrypt (encrypted with recipient's public key)
              if (message.is_mine) {
                return {
                  ...message,
                  content: '[Your encrypted message]', // Placeholder - WebSocket will replace
                };
              }
              
              // For other user's messages: Decrypt immediately
              try {
                console.log(`[InfiniteScroll] 🔓 Decrypting message ${message.id}`);
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
                console.error(`[InfiniteScroll] ❌ Failed to decrypt message ${message.id}:`, error);
                return {
                  ...message,
                  content: '[Unable to decrypt message]',
                  decryption_error: true,
                };
              }
            }
            // Return message as-is if not encrypted or already has content
            return message;
          })
        );
        
        // Prepend older messages (they come in ascending order, so prepend to beginning)
        setMessages((prev) => {
          // Deduplicate: remove any messages that already exist
          const existingIds = new Set(prev.map((m: Message) => m.id));
          const uniqueNew = decryptedMessages.filter((m: Message) => !existingIds.has(m.id));
          
          console.log(`[InfiniteScroll] ✅ Loaded ${decryptedMessages.length} messages, ${uniqueNew.length} unique, total now: ${prev.length + uniqueNew.length}`);
          
          // Prepend to beginning (older messages go on top)
          return [...uniqueNew, ...prev];
        });
        
        const loadedCount = decryptedMessages.length;
        setHasMore(response.has_more || false);
        setOffset((prev) => prev + loadedCount);

        console.log('[InfiniteScroll] New offset:', offset + loadedCount, 'hasMore:', response.has_more);

        // Maintain scroll position
        shouldScrollToBottom.current = false;
      }
    } catch (error) {
      console.error('[InfiniteScroll] ❌ Error loading more messages:', error);
    } finally {
      setIsLoadingMore(false);
    }
  }, [conversationId, pageSize, offset, hasMore, isLoading, isLoadingMore]);

  // ==================== SCROLL HANDLING ====================

  /**
   * Handle scroll event - detect when to load more
   */
  const handleScroll = useCallback(() => {
    if (!scrollRef.current) return;

    const { scrollTop } = scrollRef.current;

    // If scrolled to top (within 100px), load more
    if (scrollTop < 100 && hasMore && !isLoadingMore && !isLoading) {
      console.log('[InfiniteScroll] Scroll near top, loading more messages...');
      loadMore();
    }
  }, [hasMore, isLoadingMore, isLoading, loadMore]);

  /**
   * Scroll to bottom of messages
   */
  const scrollToBottom = useCallback((smooth = false) => {
    if (scrollRef.current) {
      scrollRef.current.scrollTo({
        top: scrollRef.current.scrollHeight,
        behavior: smooth ? 'smooth' : 'auto',
      });
    }
  }, []);

  /**
   * Maintain scroll position after loading more messages
   */
  useEffect(() => {
    if (shouldScrollToBottom.current && scrollRef.current) {
      // Scroll to bottom for new messages
      scrollToBottom(false);
      shouldScrollToBottom.current = false;
    } else if (scrollRef.current && previousScrollHeight.current > 0) {
      // Maintain position after loading older messages
      const newScrollHeight = scrollRef.current.scrollHeight;
      const scrollDiff = newScrollHeight - previousScrollHeight.current;

      if (scrollDiff > 0) {
        scrollRef.current.scrollTop += scrollDiff;
      }

      previousScrollHeight.current = 0;
    }
  }, [messages, scrollToBottom]);

  // ==================== INITIALIZATION ====================

  useEffect(() => {
    if (conversationId) {
      // Reset state for new conversation
      setMessages([]);
      setOffset(0);
      setHasMore(true);
      setCacheLoaded(false);
      
      // Load messages
      loadInitialMessages();
    }
  }, [conversationId]);

  // ==================== BACKGROUND SYNC ====================

  /**
   * Refresh messages from server (for cache invalidation)
   */
  const refreshMessages = useCallback(async () => {
    if (!conversationId) return;

    console.log('[InfiniteScroll] 🔄 Background sync - refreshing messages');

    try {
      const response = await messagesAPI.getMessages(conversationId, pageSize, 0);

      if (response.success) {
        const loadedMessages = response.messages || [];
        
        // WhatsApp-style: Decrypt ALL encrypted messages during background sync
        const decryptedMessages = await Promise.all(
          loadedMessages.map(async (message: Message) => {
            // Decrypt messages that have encrypted_content and IV but no content
            if (message.encrypted_content && message.iv && !message.content) {
              // For our own messages: Can't decrypt (encrypted with recipient's public key)
              if (message.is_mine) {
                return {
                  ...message,
                  content: '[Your encrypted message]', // Placeholder - WebSocket will replace
                };
              }
              
              // For other user's messages: Decrypt immediately
              try {
                console.log(`[InfiniteScroll] 🔓 Decrypting message ${message.id} during background sync`);
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
                console.error(`[InfiniteScroll] ❌ Failed to decrypt message ${message.id}:`, error);
                return {
                  ...message,
                  content: '[Unable to decrypt message]',
                  decryption_error: true,
                };
              }
            }
            // Return message as-is if not encrypted or already has content
            return message;
          })
        );
        
        // Sort chronologically
        const sorted = [...decryptedMessages].sort((a, b) => 
          new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
        );
        
        // Update messages - merge with existing to avoid losing optimistic messages
        setMessages((prev) => {
          // Keep any optimistic messages (have temp_id)
          const optimistic = prev.filter(m => m.temp_id);
          
          // Deduplicate server messages
          const serverMessages = sorted.filter(
            sm => !prev.some(pm => pm.id === sm.id)
          );

          // Merge: existing + new server messages
          const merged = [...prev, ...serverMessages].sort((a, b) => 
            new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
          );

          console.log('[InfiniteScroll] ✅ Merged messages:', merged.length, '(added', serverMessages.length, 'new)');
          return merged;
        });

        // Update cache
        await messageCache.saveMessages(conversationId, sorted);
        console.log('[InfiniteScroll] ✅ Background sync complete');
      }
    } catch (error) {
      console.error('[InfiniteScroll] ❌ Background sync failed:', error);
    }
  }, [conversationId, pageSize]);

  /**
   * Auto-sync when app becomes visible (user returns to tab)
   */
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden && conversationId) {
        console.log('[InfiniteScroll] 👁️ App visible - triggering background sync');
        refreshMessages();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [conversationId, refreshMessages]);

  /**
   * Auto-sync when network is restored
   */
  useEffect(() => {
    const handleNetworkOnline = () => {
      console.log('[InfiniteScroll] 🌐 Network restored - triggering background sync');
      refreshMessages();
    };

    window.addEventListener('network_online', handleNetworkOnline);

    return () => {
      window.removeEventListener('network_online', handleNetworkOnline);
    };
  }, [refreshMessages]);

  // ==================== RETURN ====================

  return {
    messages,
    isLoading,
    isLoadingMore,
    hasMore,
    scrollRef,
    handleScroll,
    scrollToBottom,
    loadMore,
    setMessages,
    refreshMessages,
    invalidateCache: () => messageCache.invalidateConversation(conversationId),
  };
}


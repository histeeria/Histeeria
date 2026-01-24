/**
 * Key Exchange Flow
 * Handles E2EE key exchange when starting conversations
 */

import { messagesAPI } from '../api/messages';
import { keyManager } from '../crypto/keyManager';

export interface KeyExchangeResult {
  success: boolean;
  conversationId: string;
  publicKeyExchanged: boolean;
  error?: string;
}

/**
 * Exchange public keys when starting a conversation
 */
export async function exchangeKeysForConversation(
  conversationId: string,
  otherUserId: string
): Promise<KeyExchangeResult> {
  try {
    // Initialize key manager if needed
    await keyManager.initialize();

    // Get our public key
    const myPublicKey = keyManager.getMyPublicKey();
    if (!myPublicKey) {
      throw new Error('User key pair not initialized');
    }

    // 1. Send our public key to server
    try {
      await messagesAPI.exchangePublicKey(conversationId, myPublicKey);
      console.log('[KeyExchange] ✅ Sent our public key to server');
    } catch (error) {
      console.error('[KeyExchange] Failed to send public key:', error);
      // Continue - key might already be exchanged
    }

    // 2. Get other user's public key from server
    try {
      const keyResponse = await messagesAPI.getConversationPublicKey(conversationId);
      
      // Log the full response for debugging
      console.log('[KeyExchange] API response:', {
        success: keyResponse.success,
        hasPublicKey: !!keyResponse.public_key,
        publicKeyType: typeof keyResponse.public_key,
        error: keyResponse.error,
        keys: Object.keys(keyResponse),
      });
      
      // Check for various error conditions
      if (keyResponse.error) {
        const errorMsg = keyResponse.error.toLowerCase();
        if (errorMsg.includes('not found') || errorMsg.includes('404')) {
          console.log('[KeyExchange] ⚠️ Other user\'s public key not available yet (they may not have exchanged keys)');
          
          return {
            success: true,
            conversationId,
            publicKeyExchanged: false,
          };
        }
        // Other errors
        console.error('[KeyExchange] Error getting public key:', keyResponse.error);
        return {
          success: false,
          conversationId,
          publicKeyExchanged: false,
          error: keyResponse.error,
        };
      }
      
      if (keyResponse.success && keyResponse.public_key) {
        const publicKey = keyResponse.public_key;
        
        // Log what we received for debugging
        console.log('[KeyExchange] Received public key:', {
          length: publicKey.length,
          firstChars: publicKey.substring(0, 50),
          isJSON: publicKey.trim().startsWith('{'),
        });
        
        // Validate public key format
        if (!publicKey || typeof publicKey !== 'string' || publicKey.trim().length === 0) {
          console.error('[KeyExchange] Invalid public key: empty or not a string');
          return {
            success: false,
            conversationId,
            publicKeyExchanged: false,
            error: 'Invalid public key format: empty key',
          };
        }
        
        // Check if it's JWK format (JSON) - this is the actual format we use
        let keyToStore = publicKey;
        try {
          // Try to parse as JSON to validate JWK format
          const parsed = JSON.parse(publicKey);
          if (parsed.kty && parsed.n && parsed.e) {
            console.log('[KeyExchange] ✅ Public key is in JWK format (expected)');
            // Key is already in correct format, use as-is
          } else {
            console.warn('[KeyExchange] ⚠️ Public key appears to be JSON but missing JWK fields');
          }
        } catch {
          // Not JSON - might be PEM or other format
          console.warn('[KeyExchange] ⚠️ Public key is not JSON format, attempting to use anyway');
        }

        // Store conversation key (crypto library will handle format validation)
        try {
          await keyManager.setConversationKey(
            conversationId,
            otherUserId,
            keyToStore
          );

          console.log('[KeyExchange] ✅ Received and stored other user\'s public key');
          
          return {
            success: true,
            conversationId,
            publicKeyExchanged: true,
          };
        } catch (storeError) {
          console.error('[KeyExchange] Failed to store conversation key:', storeError);
          return {
            success: false,
            conversationId,
            publicKeyExchanged: false,
            error: `Failed to store key: ${storeError instanceof Error ? storeError.message : 'Unknown error'}`,
          };
        }
      } else {
        console.log('[KeyExchange] ⚠️ Other user\'s public key not available yet (response missing public_key)');
        
        return {
          success: true,
          conversationId,
          publicKeyExchanged: false,
        };
      }
    } catch (error) {
      console.error('[KeyExchange] Failed to get other user\'s public key:', error);
      
      // Network errors - return success but mark as not exchanged (will retry later)
      if (error instanceof TypeError || (error instanceof Error && error.message.includes('fetch'))) {
        console.warn('[KeyExchange] Network error, will retry later');
        return {
          success: true,
          conversationId,
          publicKeyExchanged: false,
        };
      }
      
      return {
        success: false,
        conversationId,
        publicKeyExchanged: false,
        error: error instanceof Error ? error.message : 'Failed to exchange keys',
      };
    }
  } catch (error) {
    console.error('[KeyExchange] Key exchange failed:', error);
    return {
      success: false,
      conversationId,
      publicKeyExchanged: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Initialize E2EE for a conversation (call when starting conversation)
 */
export async function initializeE2EEForConversation(
  conversationId: string,
  otherUserId: string
): Promise<boolean> {
  try {
    const result = await exchangeKeysForConversation(conversationId, otherUserId);
    
    if (result.success && result.publicKeyExchanged) {
      console.log('[KeyExchange] ✅ E2EE initialized for conversation:', conversationId);
      return true;
    } else {
      console.log('[KeyExchange] ⚠️ E2EE not fully initialized (will retry later):', result.error);
      return false;
    }
  } catch (error) {
    console.error('[KeyExchange] Failed to initialize E2EE:', error);
    return false;
  }
}

/**
 * Retry key exchange if needed
 */
export async function retryKeyExchange(
  conversationId: string,
  otherUserId: string
): Promise<boolean> {
  // Check if we already have the key
  const existingKey = await keyManager.getConversationKey(conversationId, otherUserId);
  if (existingKey) {
    console.log('[KeyExchange] ✅ Key already exists for conversation:', conversationId);
    return true;
  }

  // Retry exchange
  return await initializeE2EEForConversation(conversationId, otherUserId);
}

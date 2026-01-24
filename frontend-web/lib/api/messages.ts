// ============================================
// TYPES
// ============================================

export interface Message {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  encrypted_content?: string; // E2EE encrypted content
  iv?: string; // Initialization vector for encryption
  message_type: 'text' | 'image' | 'file' | 'audio' | 'video' | 'system';
  attachment_url?: string;
  attachment_name?: string;
  attachment_size?: number;
  attachment_type?: string;
  // Video-specific fields
  thumbnail_url?: string;
  video_duration?: number;
  video_width?: number;
  video_height?: number;
  status: 'sent' | 'delivered' | 'read';
  delivered_at?: string;
  read_at?: string;
  reply_to_id?: string;
  created_at: string;
  updated_at: string;
  // Pin feature
  pinned_at?: string;
  pinned_by?: string;
  is_pinned?: boolean;
  // Edit feature
  edited_at?: string;
  edit_count?: number;
  original_content?: string;
  // Forward feature
  forwarded_from_id?: string;
  is_forwarded?: boolean;
  // Relations
  sender?: User;
  reply_to?: Message;
  reactions?: MessageReaction[];
  is_mine?: boolean;
  is_starred?: boolean;
  // Client-side only fields for reliability
  send_state?: 'sending' | 'sent' | 'failed' | 'queued';
  temp_id?: string; // For optimistic UI and offline queue
  retry_count?: number;
  send_error?: string;
  // E2EE sync states
  sync_state?: 'pending' | 'synced' | 'delivered' | 'read' | 'error';
  synced_at?: string;
  decryption_error?: boolean; // Client-side flag for decryption failures
}

export interface Conversation {
  id: string;
  participant1_id: string;
  participant2_id: string;
  last_message_content?: string;
  last_message_sender_id?: string;
  last_message_at?: string;
  unread_count_p1: number;
  unread_count_p2: number;
  created_at: string;
  updated_at: string;
  participant1?: User;
  participant2?: User;
  other_user?: User;
  unread_count?: number;
  is_typing?: boolean;
  is_online?: boolean;
  last_seen?: string;
}

export interface MessageReaction {
  id: string;
  message_id: string;
  user_id: string;
  emoji: string;
  created_at: string;
  user?: User;
}

export interface User {
  id: string;
  username: string;
  display_name?: string;
  avatar_url?: string;
  profile_picture?: string; // Backend field name
  is_verified?: boolean;
}

export interface PresenceInfo {
  user_id: string;
  is_online: boolean;
  last_seen?: string;
}

// ============================================
// API CLIENT
// ============================================

const API_BASE = '/api/proxy/v1';

async function fetchAPI(endpoint: string, options: RequestInit = {}) {
  const token = localStorage.getItem('token');
  
  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
      ...options.headers,
    },
  });

  // Parse response body even for error statuses
  let data;
  try {
    data = await response.json();
  } catch {
    // If response is not JSON, use status text
    if (!response.ok) {
      throw new Error(`API Error: ${response.statusText}`);
    }
    return {};
  }

  // For 404, return the error data instead of throwing (allows handling "not found" cases)
  if (response.status === 404) {
    return data;
  }

  if (!response.ok) {
    throw new Error(data.error || data.message || `API Error: ${response.statusText}`);
  }

  return data;
}

export const messagesAPI = {
  // ==================== CONVERSATIONS ====================

  /**
   * Get list of user's conversations
   */
  async getConversations(limit = 20, offset = 0) {
    return fetchAPI(`/conversations?limit=${limit}&offset=${offset}`);
  },

  /**
   * Get single conversation by ID
   */
  async getConversation(conversationId: string) {
    return fetchAPI(`/conversations/${conversationId}`);
  },

  /**
   * Start or get existing conversation with a user
   */
  async startConversation(userId: string) {
    return fetchAPI(`/conversations/start/${userId}`, { method: 'POST' });
  },

  /**
   * Get total unread message count
   */
  async getUnreadCount() {
    return fetchAPI('/conversations/unread-count');
  },

  // ==================== MESSAGES ====================

  /**
   * Get messages in a conversation
   */
  async getMessages(conversationId: string, limit = 50, offset = 0) {
    return fetchAPI(`/conversations/${conversationId}/messages?limit=${limit}&offset=${offset}`);
  },

  /**
   * Send a text message
   */
  async sendMessage(
    conversationId: string,
    content: string,
    tempId?: string,
    replyToId?: string,
    iv?: string
  ) {
    const payload: any = {
      message_type: 'text',
      temp_id: tempId,
      reply_to_id: replyToId,
    };

    // If IV is provided, content is encrypted
    if (iv && content) {
      // E2EE encrypted message: send encrypted_content and IV, omit plaintext content
      payload.encrypted_content = content; // content is already encrypted at this point
      payload.iv = iv;
      // Explicitly omit content field for encrypted messages
      console.log('[messagesAPI] 🔐 Sending encrypted message - encrypted_content length:', content.length, 'IV length:', iv.length);
    } else {
      // Plaintext message: send content field
      payload.content = content;
      console.log('[messagesAPI] 📝 Sending plaintext message - content length:', content.length);
    }

    console.log('[messagesAPI] 📦 Payload being sent:', JSON.stringify(payload, null, 2));

    return fetchAPI(`/conversations/${conversationId}/messages`, {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  },

  /**
   * Send a message with attachment
   */
  async sendMessageWithAttachment(
    conversationId: string,
    content: string,
    attachmentUrl: string,
    attachmentName: string,
    attachmentSize: number,
    attachmentType: string,
    messageType: 'image' | 'audio' | 'file' | 'video',
    replyToId?: string
  ) {
    return fetchAPI(`/conversations/${conversationId}/messages`, {
      method: 'POST',
      body: JSON.stringify({
        content,
        message_type: messageType,
        attachment_url: attachmentUrl,
        attachment_name: attachmentName,
        attachment_size: attachmentSize,
        attachment_type: attachmentType,
        reply_to_id: replyToId,
      }),
    });
  },

  /**
   * Mark all messages in a conversation as read
   */
  async markAsRead(conversationId: string) {
    return fetchAPI(`/conversations/${conversationId}/read`, { method: 'PATCH' });
  },

  /**
   * Delete a message (soft delete)
   */
  async deleteMessage(messageId: string) {
    return fetchAPI(`/messages/${messageId}`, { method: 'DELETE' });
  },

  /**
   * Search messages by content
   */
  async searchMessages(query: string, limit = 20, offset = 0) {
    return fetchAPI(`/messages/search?q=${encodeURIComponent(query)}&limit=${limit}&offset=${offset}`);
  },

  // ==================== MEDIA UPLOADS ====================

  /**
   * Upload an image attachment with cancellation support
   */
  async uploadImage(
    file: File, 
    quality: 'standard' | 'hd' = 'standard',
    signal?: AbortSignal,
    onProgress?: (progress: number) => void
  ) {
    const formData = new FormData();
    formData.append('image', file);

    const token = localStorage.getItem('token');
    
    // Create XMLHttpRequest for progress tracking
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      // Handle abort
      if (signal) {
        signal.addEventListener('abort', () => {
          xhr.abort();
          reject(new Error('Upload cancelled'));
        });
      }

      // Progress tracking
      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable && onProgress) {
          const percentComplete = (e.loaded / e.total) * 100;
          onProgress(percentComplete);
        }
      });

      // Success
      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            const response = JSON.parse(xhr.responseText);
            resolve(response);
          } catch (error) {
            reject(new Error('Invalid response'));
          }
        } else {
          reject(new Error(`Upload failed: ${xhr.statusText}`));
        }
      });

      // Error
      xhr.addEventListener('error', () => {
        reject(new Error('Network error'));
      });

      xhr.addEventListener('abort', () => {
        reject(new Error('Upload cancelled'));
      });

      // Send request
      xhr.open('POST', `${API_BASE}/messages/upload-image?quality=${quality}`);
      if (token) {
        xhr.setRequestHeader('Authorization', `Bearer ${token}`);
      }
      xhr.send(formData);
    });
  },

  /**
   * Upload an audio attachment with cancellation and progress
   */
  async uploadAudio(
    blob: Blob, 
    filename = 'voice-message.webm',
    signal?: AbortSignal,
    onProgress?: (progress: number) => void
  ) {
    const formData = new FormData();
    formData.append('audio', blob, filename);

    const token = localStorage.getItem('token');
    
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      if (signal) {
        signal.addEventListener('abort', () => {
          xhr.abort();
          reject(new Error('Upload cancelled'));
        });
      }

      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable && onProgress) {
          const percentComplete = (e.loaded / e.total) * 100;
          onProgress(percentComplete);
        }
      });

      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            resolve(JSON.parse(xhr.responseText));
          } catch (error) {
            reject(new Error('Invalid response'));
          }
        } else {
          reject(new Error(`Upload failed: ${xhr.statusText}`));
        }
      });

      xhr.addEventListener('error', () => reject(new Error('Network error')));
      xhr.addEventListener('abort', () => reject(new Error('Upload cancelled')));

      xhr.open('POST', `${API_BASE}/messages/upload-audio`);
      if (token) {
        xhr.setRequestHeader('Authorization', `Bearer ${token}`);
      }
      xhr.send(formData);
    });
  },

  /**
   * Upload a generic file attachment with cancellation and progress
   */
  async uploadFile(
    file: File,
    signal?: AbortSignal,
    onProgress?: (progress: number) => void
  ) {
    const formData = new FormData();
    formData.append('file', file);

    const token = localStorage.getItem('token');
    
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      if (signal) {
        signal.addEventListener('abort', () => {
          xhr.abort();
          reject(new Error('Upload cancelled'));
        });
      }

      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable && onProgress) {
          const percentComplete = (e.loaded / e.total) * 100;
          onProgress(percentComplete);
        }
      });

      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            resolve(JSON.parse(xhr.responseText));
          } catch (error) {
            reject(new Error('Invalid response'));
          }
        } else {
          reject(new Error(`Upload failed: ${xhr.statusText}`));
        }
      });

      xhr.addEventListener('error', () => reject(new Error('Network error')));
      xhr.addEventListener('abort', () => reject(new Error('Upload cancelled')));

      xhr.open('POST', `${API_BASE}/messages/upload-file`);
      if (token) {
        xhr.setRequestHeader('Authorization', `Bearer ${token}`);
      }
      xhr.send(formData);
    });
  },

  /**
   * Upload a video attachment with optional thumbnail
   */
  async uploadVideo(
    file: File,
    thumbnail?: Blob,
    signal?: AbortSignal,
    onProgress?: (progress: number) => void
  ) {
    const formData = new FormData();
    formData.append('video', file);
    
    if (thumbnail) {
      formData.append('thumbnail', thumbnail, 'thumbnail.jpg');
    }

    const token = localStorage.getItem('token');
    
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      if (signal) {
        signal.addEventListener('abort', () => {
          xhr.abort();
          reject(new Error('Upload cancelled'));
        });
      }

      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable && onProgress) {
          const percentComplete = (e.loaded / e.total) * 100;
          onProgress(percentComplete);
        }
      });

      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            resolve(JSON.parse(xhr.responseText));
          } catch (error) {
            reject(new Error('Invalid response'));
          }
        } else {
          reject(new Error(`Upload failed: ${xhr.statusText}`));
        }
      });

      xhr.addEventListener('error', () => reject(new Error('Network error')));
      xhr.addEventListener('abort', () => reject(new Error('Upload cancelled')));

      xhr.open('POST', `${API_BASE}/messages/upload-video`);
      if (token) {
        xhr.setRequestHeader('Authorization', `Bearer ${token}`);
      }
      xhr.send(formData);
    });
  },

  // ==================== REACTIONS ====================

  /**
   * Add emoji reaction to a message
   */
  async addReaction(messageId: string, emoji: string) {
    return fetchAPI(`/messages/${messageId}/reactions`, {
      method: 'POST',
      body: JSON.stringify({ emoji }),
    });
  },

  /**
   * Remove reaction from a message
   */
  async removeReaction(messageId: string) {
    return fetchAPI(`/messages/${messageId}/reactions`, { method: 'DELETE' });
  },

  // ==================== STARRED MESSAGES ====================

  /**
   * Star/bookmark a message
   */
  async starMessage(messageId: string) {
    return fetchAPI(`/messages/${messageId}/star`, { method: 'POST' });
  },

  /**
   * Unstar a message
   */
  async unstarMessage(messageId: string) {
    return fetchAPI(`/messages/${messageId}/star`, { method: 'DELETE' });
  },

  /**
   * Get all starred messages
   */
  async getStarredMessages(limit = 20, offset = 0) {
    return fetchAPI(`/messages/starred?limit=${limit}&offset=${offset}`);
  },

  // ==================== PIN MESSAGES ====================

  /**
   * Pin a message in conversation
   */
  async pinMessage(messageId: string) {
    return fetchAPI(`/messages/${messageId}/pin`, { method: 'POST' });
  },

  /**
   * Unpin a message
   */
  async unpinMessage(messageId: string) {
    return fetchAPI(`/messages/${messageId}/pin`, { method: 'DELETE' });
  },

  /**
   * Get all pinned messages in a conversation
   */
  async getPinnedMessages(conversationId: string) {
    return fetchAPI(`/conversations/${conversationId}/pinned`);
  },

  // ==================== EDIT MESSAGES ====================

  /**
   * Edit a message content
   */
  async editMessage(messageId: string, content: string) {
    return fetchAPI(`/messages/${messageId}`, {
      method: 'PATCH',
      body: JSON.stringify({ content }),
    });
  },

  /**
   * Get edit history for a message
   */
  async getMessageEditHistory(messageId: string) {
    return fetchAPI(`/messages/${messageId}/edit-history`);
  },

  // ==================== FORWARD MESSAGES ====================

  /**
   * Forward a message to another conversation
   */
  async forwardMessage(messageId: string, toConversationId: string) {
    return fetchAPI(`/messages/${messageId}/forward`, {
      method: 'POST',
      body: JSON.stringify({ to_conversation_id: toConversationId }),
    });
  },

  // ==================== SEARCH MESSAGES ====================

  /**
   * Search messages in a conversation
   */
  async searchConversationMessages(conversationId: string, query: string, limit = 50, offset = 0) {
    return fetchAPI(`/conversations/${conversationId}/search?q=${encodeURIComponent(query)}&limit=${limit}&offset=${offset}`);
  },

  // ==================== TYPING INDICATORS ====================

  /**
   * Start typing indicator
   */
  async startTyping(conversationId: string, isRecording: boolean = false) {
    return fetchAPI(`/conversations/${conversationId}/typing/start`, { 
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ is_recording: isRecording })
    });
  },

  /**
   * Stop typing indicator
   */
  async stopTyping(conversationId: string) {
    return fetchAPI(`/conversations/${conversationId}/typing/stop`, { method: 'POST' });
  },

  // ==================== PRESENCE ====================

  /**
   * Get user's online/offline status
   */
  async getUserPresence(userId: string) {
    return fetchAPI(`/users/${userId}/presence`);
  },

  /**
   * Get presence for multiple users
   */
  async getBulkPresence(userIds: string[]) {
    return fetchAPI(`/users/presence/bulk?user_ids=${userIds.join(',')}`);
  },

  // ==================== PENDING MESSAGES (E2EE) ====================

  /**
   * Get pending messages for a conversation (encrypted, not yet delivered)
   */
  async getPendingMessages(conversationId: string) {
    return fetchAPI(`/messages/pending/${conversationId}`);
  },

  /**
   * Get all pending messages across all conversations
   */
  async getAllPendingMessages() {
    return fetchAPI('/messages/pending');
  },

  /**
   * Mark messages as delivered (triggers server deletion after grace period)
   */
  async markMessagesDelivered(messageIds: string[]) {
    return fetchAPI('/messages/mark-delivered', {
      method: 'POST',
      body: JSON.stringify({ message_ids: messageIds }),
    });
  },

  /**
   * Exchange public keys for E2EE
   */
  async exchangePublicKey(conversationId: string, publicKey: string) {
    return fetchAPI(`/conversations/${conversationId}/keys`, {
      method: 'POST',
      body: JSON.stringify({ public_key: publicKey }),
    });
  },

  /**
   * Get other user's public key for a conversation
   */
  async getConversationPublicKey(conversationId: string) {
    return fetchAPI(`/conversations/${conversationId}/keys`);
  },
};

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Format time as relative (e.g., "2 minutes ago", "Yesterday")
 */
export function formatMessageTime(timestamp: string): string {
  const now = new Date();
  const date = new Date(timestamp);
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;

  // Format as date
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

/**
 * Format full timestamp for message (e.g., "3:45 PM")
 */
export function formatMessageTimestamp(timestamp: string): string {
  const date = new Date(timestamp);
  return date.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });
}

/**
 * Format last seen timestamp (e.g., "last seen today at 3:45 PM", "last seen yesterday")
 */
export function formatLastSeen(timestamp: string): string {
  const now = new Date();
  const date = new Date(timestamp);
  const diffDays = Math.floor((now.getTime() - date.getTime()) / 86400000);

  const time = date.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });

  if (diffDays === 0) return `today at ${time}`;
  if (diffDays === 1) return `yesterday at ${time}`;
  if (diffDays < 7) return `${diffDays} days ago`;

  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}


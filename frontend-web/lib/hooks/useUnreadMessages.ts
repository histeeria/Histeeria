import { useState, useEffect } from 'react';
import { messagesAPI } from '../api/messages';
import { messageWS } from '../websocket/MessageWebSocket';

export function useUnreadMessages() {
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    // Load initial count
    loadUnreadCount();

    // Listen for new messages
    const unsubscribe = messageWS.on('new_message', (message: any) => {
      console.log('[UnreadBadge] New message received:', message.conversation_id, 'is_mine:', message.is_mine);
      
      // Only increment if message is NOT from me
      if (!message.is_mine) {
        // Check if user is currently viewing this conversation
        const currentPath = window.location.pathname;
        const isViewingMessages = currentPath.includes('/messages');
        
        // If viewing messages page, check the URL/state to see if this conversation is open
        // For now, we'll increment and rely on instant mark-as-read
        console.log('[UnreadBadge] Incrementing badge count');
        setUnreadCount(prev => prev + 1);
      }
    });

    // Listen for messages being read via WebSocket
    const unsubscribeRead = messageWS.on('message_read', (data: any) => {
      console.log('[UnreadBadge] message_read event received:', data);
      // Decrement count instantly for better UX
      loadUnreadCount();
    });

    // Listen for custom event from ChatWindow (optimistic update)
    const handleMarkedRead = (e: CustomEvent) => {
      console.log('[UnreadBadge] messages_marked_read event:', e.detail);
      // INSTANT update - fetch actual count immediately
      setTimeout(() => loadUnreadCount(), 100); // Small delay to ensure backend processed
    };
    window.addEventListener('messages_marked_read', handleMarkedRead as EventListener);

    return () => {
      unsubscribe();
      unsubscribeRead();
      window.removeEventListener('messages_marked_read', handleMarkedRead as EventListener);
    };
  }, []);

  const loadUnreadCount = async () => {
    try {
      const response = await messagesAPI.getUnreadCount();
      if (response.success) {
        setUnreadCount(response.total || 0);
      }
    } catch (error) {
      console.error('Failed to load unread count:', error);
    }
  };

  return { unreadCount, refreshCount: loadUnreadCount };
}


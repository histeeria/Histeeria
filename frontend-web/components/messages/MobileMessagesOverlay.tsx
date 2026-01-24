'use client';

import { useState, useEffect } from 'react';
import { useMessages } from '@/lib/contexts/MessagesContext';
import { messagesAPI, Conversation } from '@/lib/api/messages';
import { messageWS } from '@/lib/websocket/MessageWebSocket';
import { ArrowLeft, MoreVertical } from 'lucide-react';
import ConversationList from './ConversationList';
import ChatWindow from './ChatWindow';
import { initializeE2EEForConversation } from '@/lib/messaging/keyExchange';

export default function MobileMessagesOverlay() {
  const { isMessagesOpen, selectedUserId, closeMessages } = useMessages();
  const [selectedConversation, setSelectedConversation] = useState<string | null>(null);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [startingConversation, setStartingConversation] = useState(false);

  // Load conversations when overlay opens
  useEffect(() => {
    if (isMessagesOpen && conversations.length === 0) {
      loadConversations();
    }
    // Note: WebSocket already connected via NotificationContext
  }, [isMessagesOpen]);

  // Handle starting conversation with specific user
  useEffect(() => {
    if (isMessagesOpen && selectedUserId) {
      startConversationWithUser(selectedUserId);
    }
  }, [isMessagesOpen, selectedUserId]);

  const loadConversations = async () => {
    setIsLoading(true);
    try {
      const response = await messagesAPI.getConversations(20, 0);
      if (response.success) {
        setConversations(response.conversations || []);
      }
    } catch (error) {
      console.error('Failed to load conversations:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const startConversationWithUser = async (userId: string) => {
    setStartingConversation(true);
    try {
      const response = await messagesAPI.startConversation(userId);
      if (response.success && response.conversation) {
        const conversationId = response.conversation.id;
        
        // Initialize E2EE key exchange for this conversation
        try {
          await initializeE2EEForConversation(conversationId, userId);
        } catch (keyError) {
          console.error('Failed to initialize E2EE (messages will be plaintext):', keyError);
          // Continue anyway - messages will be plaintext
        }

        // Open the conversation directly
        setSelectedConversation(conversationId);
      }
    } catch (error) {
      console.error('Failed to start conversation:', error);
    } finally {
      setStartingConversation(false);
    }
  };

  // Listen for new messages and read receipts
  useEffect(() => {
    if (isMessagesOpen) {
      const unsubscribe = messageWS.on('new_message', (message: any) => {
        // Update conversation locally (instant)
        setConversations(prev => {
          const updated = prev.map(conv => {
            if (conv.id === message.conversation_id) {
              return {
                ...conv,
                last_message_content: message.content || '[Media]',
                last_message_at: message.created_at,
                unread_count: message.is_mine ? conv.unread_count : (conv.unread_count || 0) + 1,
              };
            }
            return conv;
          });
          // Sort by last message time
          return updated.sort((a, b) => 
            new Date(b.last_message_at || 0).getTime() - new Date(a.last_message_at || 0).getTime()
          );
        });
      });
      
      const unsubscribeRead = messageWS.on('message_read', (data: any) => {
        // Update unread count locally (instant)
        setConversations(prev => prev.map(conv => 
          conv.id === data.conversation_id 
            ? { ...conv, unread_count: 0 }
            : conv
        ));
      });

      // REAL-TIME TYPING UPDATES FOR CONVERSATION LIST
      const unsubscribeTyping = messageWS.on('typing', (data: any) => {
        console.log('[MobileMessages] Typing event for conversation:', data.conversation_id);
        setConversations(prev => prev.map(conv => 
          conv.id === data.conversation_id
            ? { ...conv, is_typing: true }
            : conv
        ));
      });

      const unsubscribeStopTyping = messageWS.on('stop_typing', (data: any) => {
        console.log('[MobileMessages] Stop typing event for conversation:', data.conversation_id);
        setConversations(prev => prev.map(conv => 
          conv.id === data.conversation_id
            ? { ...conv, is_typing: false }
            : conv
        ));
      });

      const handleMarkedRead = (e: any) => {
        // INSTANT update - clear unread count immediately
        const convId = e.detail?.conversationId || selectedConversation;
        if (convId) {
          setConversations(prev => prev.map(conv => 
            conv.id === convId 
              ? { ...conv, unread_count: 0 }
              : conv
          ));
        }
      };
      window.addEventListener('messages_marked_read', handleMarkedRead);
      
      return () => {
        unsubscribe();
        unsubscribeRead();
        unsubscribeTyping();
        unsubscribeStopTyping();
        window.removeEventListener('messages_marked_read', handleMarkedRead);
      };
    }
  }, [isMessagesOpen, selectedConversation]);

  const filteredConversations = conversations.filter((conv) => {
    if (!searchQuery) return true;
    const otherUser = conv.other_user;
    if (!otherUser) return false;

    const searchLower = searchQuery.toLowerCase();
    const displayName = (otherUser.display_name || otherUser.username || '').toLowerCase();
    const username = (otherUser.username || '').toLowerCase();
    const lastMessage = (conv.last_message_content || '').toLowerCase();

    return (
      displayName.includes(searchLower) ||
      username.includes(searchLower) ||
      lastMessage.includes(searchLower)
    );
  });

  const handleClose = () => {
    setSelectedConversation(null);
    closeMessages();
  };

  if (!isMessagesOpen) return null;

  // Show loading while starting conversation
  if (startingConversation) {
    return (
      <div className="md:hidden fixed inset-0 z-[100] bg-white dark:bg-neutral-900 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600 mx-auto mb-4"></div>
          <p className="text-gray-600 dark:text-gray-400">Starting conversation...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="md:hidden fixed inset-0 z-[100] bg-white dark:bg-neutral-900 animate-slide-in-right">
      {!selectedConversation ? (
        // Conversation List Screen
        <div className="flex flex-col h-full">
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200 dark:border-gray-800">
            <button
              onClick={handleClose}
              className="p-2 -ml-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
            >
              <ArrowLeft className="w-6 h-6 text-gray-900 dark:text-white" />
            </button>
            <h1 className="text-lg font-semibold text-gray-900 dark:text-white">
              Messages
            </h1>
            <button className="p-2 -mr-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full">
              <MoreVertical className="w-6 h-6 text-gray-900 dark:text-white" />
            </button>
          </div>

          {/* Search */}
          <div className="p-4 border-b border-gray-200 dark:border-gray-800">
            <input
              type="text"
              placeholder="Search conversations..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
            />
          </div>

          {/* Conversations */}
          <div className="flex-1 overflow-y-auto">
            <ConversationList
              conversations={filteredConversations}
              selectedId={null}
              onSelect={setSelectedConversation}
              isLoading={isLoading}
            />
          </div>
        </div>
      ) : (
        // Chat Window (slides in from right) - Full screen
        // Only render when conversation is actually selected (prevents background mark-as-read)
        <div className="h-full animate-slide-in-right">
          <ChatWindow
            key={selectedConversation} // Force remount on conversation change
            conversationId={selectedConversation}
            onClose={() => setSelectedConversation(null)}
          />
        </div>
      )}
    </div>
  );
}


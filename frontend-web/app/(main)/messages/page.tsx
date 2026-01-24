'use client';

import { useState, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { messagesAPI, Conversation } from '@/lib/api/messages';
import { messageWS } from '@/lib/websocket/MessageWebSocket';
import { ArrowLeft, MoreVertical, MessageCircle } from 'lucide-react';
import ConversationList from '@/components/messages/ConversationList';
import ChatWindow from '@/components/messages/ChatWindow';
import { initializeE2EEForConversation } from '@/lib/messaging/keyExchange';

export default function MessagesPage() {
  const searchParams = useSearchParams();
  const userIdParam = searchParams.get('userId'); // For starting conversation with specific user
  
  const [selectedConversation, setSelectedConversation] = useState<string | null>(null);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [startingConversation, setStartingConversation] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  // Detect screen size
  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // ==================== MOBILE BACK BUTTON HANDLING ====================

  useEffect(() => {
    if (!isMobile) return; // Only handle on mobile

    const handleBackButton = () => {
      if (selectedConversation) {
        // If chat is open, close it and show conversation list
        console.log('[MessagesPage] Back pressed - closing chat');
        setSelectedConversation(null);
        // Push state again to prevent app close
        window.history.pushState({ page: 'messages-list' }, '', window.location.pathname);
        return;
      }
      // If conversation list is shown, allow natural back navigation
      console.log('[MessagesPage] Back pressed - allowing natural navigation');
    };

    // Push initial state when chat opens to enable back button
    if (selectedConversation) {
      window.history.pushState({ page: 'messages-chat', conversationId: selectedConversation }, '', window.location.pathname);
      console.log('[MessagesPage] Pushed chat state to history');
    }

    window.addEventListener('popstate', handleBackButton);

    return () => {
      window.removeEventListener('popstate', handleBackButton);
    };
  }, [selectedConversation, isMobile]);

  // ==================== LOAD CONVERSATIONS ====================

  useEffect(() => {
    loadConversations();
  }, []);

  // Handle starting conversation with specific user (from URL param)
  useEffect(() => {
    if (userIdParam) {
      startConversationWithUser(userIdParam);
    }
  }, [userIdParam]);

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

        setSelectedConversation(conversationId);
      }
    } catch (error) {
      console.error('Failed to start conversation:', error);
    } finally {
      setStartingConversation(false);
    }
  };

  // ==================== WEBSOCKET INTEGRATION ====================

  useEffect(() => {
    // WebSocket already connected via NotificationContext
    // Listen for new messages to update conversation list INSTANTLY
    const unsubscribe = messageWS.on('new_message', (message: any) => {
      console.log('[MessagesPage] Received new message via WebSocket');
      // Update conversation locally (instant, no API call)
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
      console.log('[MessagesPage] Message read event');
      // Update unread count locally (instant)
      setConversations(prev => prev.map(conv => 
        conv.id === data.conversation_id 
          ? { ...conv, unread_count: 0 }
          : conv
      ));
    });

    // REAL-TIME TYPING UPDATES FOR CONVERSATION LIST
    const unsubscribeTyping = messageWS.on('typing', (data: any) => {
      console.log('[MessagesPage] Typing event for conversation:', data.conversation_id);
      // Update typing status INSTANTLY (real-time, not cached)
      setConversations(prev => prev.map(conv => 
        conv.id === data.conversation_id
          ? { ...conv, is_typing: true }
          : conv
      ));
    });

    const unsubscribeStopTyping = messageWS.on('stop_typing', (data: any) => {
      console.log('[MessagesPage] Stop typing event for conversation:', data.conversation_id);
      // Clear typing status INSTANTLY
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
  }, [selectedConversation]);

  // ==================== SEARCH ====================

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

  // ==================== RENDER ====================

  return (
    <>
      {/* Desktop: With MainLayout (shows sidebar) */}
      <div className="hidden md:block">
        <MainLayout showRightPanel={false}>
          <div className="flex h-[calc(100vh-64px)] -mx-4 md:-mx-6">
            {/* Left Panel - Conversation List */}
            <div className="w-96 border-r border-gray-200 dark:border-gray-800 flex flex-col bg-white dark:bg-neutral-900">
              {/* Search Bar */}
              <div className="p-4 border-b border-gray-200 dark:border-gray-800">
                <input
                  type="text"
                  placeholder="Search conversations..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                />
              </div>

              {/* Conversation List */}
              <div className="flex-1 overflow-y-auto">
                <ConversationList
                  conversations={filteredConversations}
                  selectedId={selectedConversation}
                  onSelect={setSelectedConversation}
                  isLoading={isLoading}
                />
              </div>
            </div>

            {/* Right Panel - Chat Window */}
            <div className="flex-1 flex flex-col bg-white dark:bg-neutral-900">
              {selectedConversation && !isMobile ? (
                // Only render ChatWindow on DESKTOP when conversation is selected
                // This prevents background rendering on mobile (which causes premature mark-as-read)
                <ChatWindow
                  key={selectedConversation} // Force remount on conversation change
                  conversationId={selectedConversation}
                  onClose={() => setSelectedConversation(null)}
                />
              ) : (
                <EmptyState />
              )}
            </div>
          </div>
        </MainLayout>
      </div>

      {/* Mobile: Fullscreen without MainLayout (Instagram-style) */}
      <div className="md:hidden">
        {!selectedConversation ? (
          <div className="animate-slide-in-right">
            <MobileConversationList
              conversations={filteredConversations}
              searchQuery={searchQuery}
              setSearchQuery={setSearchQuery}
              onSelect={setSelectedConversation}
              isLoading={isLoading}
            />
          </div>
        ) : (
          <div className="fixed inset-0 z-50 bg-white dark:bg-neutral-900 animate-slide-in-right">
            <ChatWindow
              conversationId={selectedConversation}
              onClose={() => setSelectedConversation(null)}
            />
          </div>
        )}
      </div>
    </>
  );
}

// ==================== MOBILE CONVERSATION LIST ====================

function MobileConversationList({
  conversations,
  searchQuery,
  setSearchQuery,
  onSelect,
  isLoading,
}: {
  conversations: Conversation[];
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  onSelect: (id: string) => void;
  isLoading: boolean;
}) {
  return (
    <div className="flex flex-col h-screen bg-white dark:bg-neutral-900">
      {/* Custom Header for Mobile (Instagram-style) */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200 dark:border-gray-800">
        {/* Back Arrow */}
        <button
          onClick={() => window.history.back()}
          className="p-2 -ml-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
        >
          <ArrowLeft className="w-6 h-6 text-gray-900 dark:text-white" />
        </button>

        {/* Title */}
        <h1 className="text-lg font-semibold text-gray-900 dark:text-white">
          Messages
        </h1>

        {/* More Options */}
        <button className="p-2 -mr-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full">
          <MoreVertical className="w-6 h-6 text-gray-900 dark:text-white" />
        </button>
      </div>

      {/* Search Bar */}
      <div className="p-4 border-b border-gray-200 dark:border-gray-800">
        <input
          type="text"
          placeholder="Search conversations..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
        />
      </div>

      {/* Conversation List */}
      <div className="flex-1 overflow-y-auto">
        <ConversationList
          conversations={conversations}
          selectedId={null}
          onSelect={onSelect}
          isLoading={isLoading}
        />
      </div>
    </div>
  );
}

// ==================== EMPTY STATE ====================

function EmptyState() {
  return (
    <div className="flex items-center justify-center h-full">
      <div className="text-center">
        <div className="w-24 h-24 mx-auto mb-4 rounded-full bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center">
          <MessageCircle className="w-12 h-12 text-purple-600 dark:text-purple-400" />
        </div>
        <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
          Your Messages
        </h3>
        <p className="text-gray-500 dark:text-gray-400">
          Select a conversation to start messaging
        </p>
      </div>
    </div>
  );
}

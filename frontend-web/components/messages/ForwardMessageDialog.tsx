'use client';

import { useState, useEffect } from 'react';
import { X, Send, Search, User } from 'lucide-react';
import { messagesAPI, Conversation } from '@/lib/api/messages';
import { Avatar } from '../ui/Avatar';
import { toast } from '../ui/Toast';

interface ForwardMessageDialogProps {
  isOpen: boolean;
  messageId: string;
  currentConversationId?: string;
  onClose: () => void;
  onForward?: (forwardedMessage: any, targetConversationId: string) => void;
}

export function ForwardMessageDialog({
  isOpen,
  messageId,
  currentConversationId,
  onClose,
  onForward,
}: ForwardMessageDialogProps) {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [forwarding, setForwarding] = useState(false);

  useEffect(() => {
    if (isOpen) {
      loadConversations();
    }
  }, [isOpen]);

  const loadConversations = async () => {
    try {
      setLoading(true);
      const response = await messagesAPI.getConversations(100, 0);
      if (response.success) {
        setConversations(response.conversations);
      }
    } catch (error) {
      console.error('Failed to load conversations:', error);
      toast.error('Failed to load conversations');
    } finally {
      setLoading(false);
    }
  };

  const handleForward = async (conversationId: string) => {
    try {
      setForwarding(true);
      const response = await messagesAPI.forwardMessage(messageId, conversationId);
      
      if (response.success) {
        toast.success('Message forwarded successfully');
        
        // Pass the forwarded message back to parent
        onForward?.(response.message, conversationId);
        onClose();
      }
    } catch (error) {
      console.error('Failed to forward message:', error);
      toast.error('Failed to forward message');
    } finally {
      setForwarding(false);
    }
  };

  const filteredConversations = conversations.filter((conv) => {
    if (!searchQuery) return true;
    const otherUser = conv.other_user;
    return (
      otherUser?.display_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      otherUser?.username?.toLowerCase().includes(searchQuery.toLowerCase())
    );
  });

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div
        className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl w-full max-w-md max-h-[80vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
          <h3 className="text-lg font-bold text-gray-900 dark:text-white">
            Forward Message
          </h3>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors"
            disabled={forwarding}
          >
            <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
          </button>
        </div>

        {/* Search */}
        <div className="p-4 border-b border-gray-200 dark:border-gray-700">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search conversations..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2 bg-gray-100 dark:bg-gray-700 border-none rounded-lg text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:ring-2 focus:ring-purple-500"
            />
          </div>
        </div>

        {/* Conversation List */}
        <div className="flex-1 overflow-y-auto">
          {loading ? (
            <div className="flex items-center justify-center h-40">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600"></div>
            </div>
          ) : filteredConversations.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-40 text-gray-500 dark:text-gray-400">
              <User className="w-12 h-12 mb-2 opacity-50" />
              <p className="text-sm">No conversations found</p>
            </div>
          ) : (
            <div className="divide-y divide-gray-200 dark:divide-gray-700">
              {filteredConversations.map((conv) => {
                const otherUser = conv.other_user;
                return (
                  <button
                    key={conv.id}
                    onClick={() => handleForward(conv.id)}
                    disabled={forwarding}
                    className="w-full flex items-center gap-3 p-4 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Avatar
                      src={otherUser?.profile_picture || otherUser?.avatar_url}
                      alt={otherUser?.display_name || 'User'}
                      size="md"
                    />
                    <div className="flex-1 text-left">
                      <p className="font-semibold text-gray-900 dark:text-white">
                        {otherUser?.display_name || 'Unknown User'}
                      </p>
                      <p className="text-sm text-gray-500 dark:text-gray-400">
                        @{otherUser?.username || 'unknown'}
                      </p>
                    </div>
                    <Send className="w-5 h-5 text-purple-600 dark:text-purple-400" />
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-gray-200 dark:border-gray-700">
          <button
            onClick={onClose}
            disabled={forwarding}
            className="w-full px-4 py-2 text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors font-medium disabled:opacity-50"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
}


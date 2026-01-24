'use client';

import { Conversation } from '@/lib/api/messages';
import { MessageCircle } from 'lucide-react';
import ConversationItem from './ConversationItem';

interface ConversationListProps {
  conversations: Conversation[];
  selectedId: string | null;
  onSelect: (id: string) => void;
  isLoading?: boolean;
}

export default function ConversationList({
  conversations,
  selectedId,
  onSelect,
  isLoading,
}: ConversationListProps) {
  if (isLoading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600"></div>
      </div>
    );
  }

  if (conversations.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center p-8 text-center">
        <div className="w-16 h-16 mx-auto mb-3 rounded-full bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center">
          <MessageCircle className="w-8 h-8 text-purple-600 dark:text-purple-400" />
        </div>
        <p className="text-gray-500 dark:text-gray-400">No conversations yet</p>
        <p className="text-sm text-gray-400 dark:text-gray-500 mt-1">
          Start a conversation from someone's profile
        </p>
      </div>
    );
  }

  return (
    <div className="divide-y divide-gray-200 dark:divide-gray-800">
      {conversations.map((conversation) => (
        <ConversationItem
          key={conversation.id}
          conversation={conversation}
          isSelected={conversation.id === selectedId}
          onClick={() => onSelect(conversation.id)}
        />
      ))}
    </div>
  );
}


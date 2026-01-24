'use client';

import { Conversation, formatMessageTime } from '@/lib/api/messages';
import { Avatar } from '../ui/Avatar';

interface ConversationItemProps {
  conversation: Conversation;
  isSelected: boolean;
  onClick: () => void;
}

export default function ConversationItem({
  conversation,
  isSelected,
  onClick,
}: ConversationItemProps) {
  const otherUser = conversation.other_user;
  if (!otherUser) return null;

  const hasUnread = (conversation.unread_count || 0) > 0;

  return (
    <div
      onClick={onClick}
      className={`flex items-center gap-3 p-4 cursor-pointer transition-colors ${
        isSelected
          ? 'bg-purple-50 dark:bg-purple-900/20'
          : 'hover:bg-gray-50 dark:hover:bg-gray-800'
      }`}
    >
      {/* Avatar with online indicator */}
      <div className="relative flex-shrink-0">
        <Avatar
          src={otherUser.profile_picture || otherUser.avatar_url}
          alt={otherUser.display_name || otherUser.username}
          fallback={otherUser.display_name || otherUser.username}
          size="md"
          showOnline={true}
          isOnline={conversation.is_online}
        />
      </div>

      {/* Conversation Info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between mb-1">
          <h4
            className={`text-sm font-medium truncate ${
              hasUnread
                ? 'text-gray-900 dark:text-white font-semibold'
                : 'text-gray-700 dark:text-gray-300'
            }`}
          >
            {otherUser.display_name || otherUser.username}
          </h4>
          {conversation.last_message_at && (
            <span className="text-xs text-gray-500 dark:text-gray-400 flex-shrink-0 ml-2">
              {formatMessageTime(conversation.last_message_at)}
            </span>
          )}
        </div>

        <div className="flex items-center justify-between">
          {/* Last Message */}
          <p
            className={`text-sm truncate ${
              hasUnread
                ? 'text-gray-900 dark:text-white font-medium'
                : 'text-gray-500 dark:text-gray-400'
            }`}
          >
            {conversation.is_typing ? (
              <span className="text-purple-600 dark:text-purple-400">Typing...</span>
            ) : (
              conversation.last_message_content || 'No messages yet'
            )}
          </p>

          {/* Unread Badge */}
          {hasUnread && (
            <div className="flex-shrink-0 ml-2 min-w-[20px] h-5 px-1.5 bg-purple-600 text-white text-xs font-bold rounded-full flex items-center justify-center">
              {conversation.unread_count}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}


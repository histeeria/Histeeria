'use client';

import { Mic } from 'lucide-react';

interface TypingUser {
  user_id: string;
  display_name: string;
  is_recording?: boolean;
}

interface TypingIndicatorProps {
  typingUsers?: TypingUser[];
}

export default function TypingIndicator({ typingUsers = [] }: TypingIndicatorProps) {
  if (typingUsers.length === 0) return null;

  const recordingUser = typingUsers.find((u) => u.is_recording);
  const typingOnly = typingUsers.filter((u) => !u.is_recording);

  const formatTypingText = () => {
    if (recordingUser) {
      return (
        <span className="flex items-center gap-2">
          <Mic className="w-3 h-3 text-red-500 animate-pulse" />
          <span>
            <strong>{recordingUser.display_name}</strong> is recording a voice message
          </span>
        </span>
      );
    }

    if (typingOnly.length === 1) {
      return (
        <span>
          <strong>{typingOnly[0].display_name}</strong> is typing
        </span>
      );
    }

    if (typingOnly.length === 2) {
      return (
        <span>
          <strong>{typingOnly[0].display_name}</strong> and <strong>{typingOnly[1].display_name}</strong> are typing
        </span>
      );
    }

    if (typingOnly.length > 2) {
      return (
        <span>
          <strong>{typingOnly[0].display_name}</strong>, <strong>{typingOnly[1].display_name}</strong>, and{' '}
          <strong>{typingOnly.length - 2} other{typingOnly.length - 2 > 1 ? 's' : ''}</strong> are typing
        </span>
      );
    }

    return null;
  };

  return (
    <div className="flex justify-start px-[1px] pb-[1px] animate-fade-in">
      <div className="bg-gray-200 dark:bg-gray-800 rounded-2xl px-4 py-3 max-w-[85%]">
        <div className="flex items-center gap-3">
          {/* Animated Dots */}
          {!recordingUser && (
            <div className="flex items-center gap-1">
              <div className="w-2 h-2 bg-purple-500 dark:bg-purple-400 rounded-full animate-bounce [animation-delay:-0.3s]"></div>
              <div className="w-2 h-2 bg-purple-500 dark:bg-purple-400 rounded-full animate-bounce [animation-delay:-0.15s]"></div>
              <div className="w-2 h-2 bg-purple-500 dark:bg-purple-400 rounded-full animate-bounce"></div>
            </div>
          )}

          {/* Text */}
          <div className="text-sm text-gray-700 dark:text-gray-300">
            {formatTypingText()}
            {!recordingUser && '...'}
          </div>
        </div>
      </div>
    </div>
  );
}


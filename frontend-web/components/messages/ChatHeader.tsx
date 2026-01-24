'use client';

import { useState } from 'react';
import { Conversation, formatLastSeen } from '@/lib/api/messages';
import { Avatar } from '../ui/Avatar';
import { ArrowLeft, Phone, Video, MoreVertical, Search, X, Pin, User } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { toast } from '@/components/ui/Toast';

interface ChatHeaderProps {
  conversation: Conversation;
  onClose?: () => void;
  onSearch?: (query: string) => void;
  onShowPinned?: () => void;
  pinnedCount?: number;
  onShowProfile?: () => void;
}

export default function ChatHeader({ conversation, onClose, onSearch, onShowPinned, pinnedCount = 0, onShowProfile }: ChatHeaderProps) {
  const router = useRouter();
  const otherUser = conversation.other_user;
  const [showSearch, setShowSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [showMobileMenu, setShowMobileMenu] = useState(false);

  if (!otherUser) return null;

  const handleViewProfile = () => {
    if (onShowProfile) {
      onShowProfile();
    } else {
      router.push(`/profile/${otherUser.username}`);
    }
  };

  const handleSearch = (query: string) => {
    setSearchQuery(query);
    if (onSearch) {
      onSearch(query);
    }
  };

  const closeSearch = () => {
    setShowSearch(false);
    setSearchQuery('');
    if (onSearch) {
      onSearch('');
    }
  };

  return (
    <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900">
      {/* Left: Back + User Info */}
      <div className="flex items-center gap-3 flex-1 min-w-0">
        {/* Back Arrow (mobile) */}
        {onClose && (
          <button
            onClick={onClose}
            className="md:hidden p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
        )}

        {/* Avatar */}
        <div className="cursor-pointer" onClick={handleViewProfile}>
          <Avatar
            src={otherUser.profile_picture || otherUser.avatar_url}
            alt={otherUser.display_name || otherUser.username}
            fallback={otherUser.display_name || otherUser.username}
            size="sm"
            showOnline={true}
            isOnline={conversation.is_online}
          />
        </div>

        {/* User Info */}
        <div className="flex-1 min-w-0 cursor-pointer" onClick={handleViewProfile}>
          <h3 className="text-sm font-semibold text-gray-900 dark:text-white truncate">
            {otherUser.display_name || otherUser.username}
          </h3>
          <p className="text-xs text-gray-500 dark:text-gray-400">
            {conversation.is_online ? (
              <span className="text-green-600 dark:text-green-400">Online</span>
            ) : conversation.last_seen ? (
              `Last seen ${formatLastSeen(conversation.last_seen)}`
            ) : (
              'Offline'
            )}
          </p>
        </div>
      </div>

      {/* Right: Action Buttons */}
      {!showSearch ? (
        <div className="flex items-center gap-1">
          {/* Pinned Messages - Always visible if there are pinned messages (Mobile + Desktop) */}
          {onShowPinned && pinnedCount > 0 && (
            <button
              onClick={onShowPinned}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors relative"
              title={`${pinnedCount} pinned message${pinnedCount > 1 ? 's' : ''}`}
            >
              <Pin className="w-5 h-5 text-purple-600 dark:text-purple-400" />
              {pinnedCount > 1 && (
                <span className="absolute -top-1 -right-1 bg-purple-600 text-white text-[10px] font-bold rounded-full w-4 h-4 flex items-center justify-center">
                  {pinnedCount}
                </span>
              )}
            </button>
          )}

          {/* Voice Call - Always visible (Mobile + Desktop) */}
          <button
            onClick={() => toast.info('Voice calls coming in Phase 2!')}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
            title="Voice call"
          >
            <Phone className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          </button>

          {/* Video Call - Always visible (Mobile + Desktop) */}
          <button
            onClick={() => toast.info('Video calls coming in Phase 2!')}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
            title="Video call"
          >
            <Video className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          </button>

          {/* Settings Dropdown */}
          <div className="relative">
            <button
              onClick={() => setShowMobileMenu(!showMobileMenu)}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
              title="Chat options"
            >
              <MoreVertical className="w-5 h-5 text-gray-600 dark:text-gray-400" />
            </button>

            {/* Dropdown Menu */}
            {showMobileMenu && (
              <>
                {/* Backdrop */}
                <div
                  className="fixed inset-0 z-40"
                  onClick={() => setShowMobileMenu(false)}
                />

                {/* Menu */}
                <div className="absolute right-0 mt-2 w-56 bg-white dark:bg-gray-800 rounded-xl shadow-2xl border border-gray-200 dark:border-gray-700 py-2 z-50">
                  {/* Search */}
                  <button
                    onClick={() => {
                      setShowSearch(true);
                      setShowMobileMenu(false);
                    }}
                    className="w-full flex items-center gap-3 px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors text-left"
                  >
                    <Search className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                    <span className="text-gray-900 dark:text-white font-medium">Search messages</span>
                  </button>

                  <div className="border-t border-gray-200 dark:border-gray-700 my-2" />

                  {/* View Profile */}
                  <button
                    onClick={() => {
                      handleViewProfile();
                      setShowMobileMenu(false);
                    }}
                    className="w-full flex items-center gap-3 px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors text-left"
                  >
                    <User className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                    <span className="text-gray-900 dark:text-white font-medium">View profile</span>
                  </button>

                  {/* Chat Settings */}
                  <button
                    onClick={() => {
                      toast.info('Chat settings coming soon!');
                      setShowMobileMenu(false);
                    }}
                    className="w-full flex items-center gap-3 px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors text-left"
                  >
                    <MoreVertical className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                    <span className="text-gray-900 dark:text-white font-medium">Chat settings</span>
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      ) : (
        // Search Bar
        <div className="flex-1 flex items-center gap-2">
          <div className="flex-1 relative">
            <input
              type="text"
              placeholder="Search messages..."
              value={searchQuery}
              onChange={(e) => handleSearch(e.target.value)}
              className="w-full px-4 py-2 bg-gray-100 dark:bg-gray-800 border-none rounded-full text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:ring-2 focus:ring-purple-500"
              autoFocus
            />
          </div>
          <button
            onClick={closeSearch}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          </button>
        </div>
      )}
    </div>
  );
}


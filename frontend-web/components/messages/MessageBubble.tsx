'use client';

import { useState } from 'react';
import { Message, formatMessageTimestamp } from '@/lib/api/messages';
import { Star, Reply, Forward, Trash2, Info, Smile, Copy, Pin, Share2, Edit, Image as ImageIcon, Mic, Paperclip, Plus, Loader2, AlertCircle, Clock, RotateCw } from 'lucide-react';
import ImageMessage from './ImageMessage';
import AudioPlayer from './AudioPlayer';
import VideoPlayer from './VideoPlayer';
import EmojiPicker from './EmojiPicker';
import { ReactionManageDialog } from './ReactionManageDialog';
import { LinkPreview } from './LinkPreview';
import { extractUrls, containsUrl } from '@/lib/utils/linkPreview';

interface MessageBubbleProps {
  message: Message;
  onReact: (messageId: string, emoji: string) => void;
  onReply: (message: Message) => void;
  onStar: (messageId: string, isStarred: boolean) => void;
  onDelete: (messageId: string) => void;
  onForward?: (message: Message) => void;
  onCopy?: (message: Message) => void;
  onPin?: (messageId: string, isPinned: boolean) => void;
  onShare?: (message: Message) => void;
  onInfo?: (message: Message) => void;
  onEdit?: (message: Message) => void;
  onViewMedia?: (message: Message) => void;
  onRetry?: (tempId: string) => void;
}

export default function MessageBubble({
  message,
  onReact,
  onReply,
  onStar,
  onDelete,
  onForward,
  onCopy,
  onPin,
  onShare,
  onInfo,
  onEdit,
  onViewMedia,
  onRetry,
}: MessageBubbleProps) {
  const [showActions, setShowActions] = useState(false);
  const [showReactions, setShowReactions] = useState(false);
  const [showDeleteMenu, setShowDeleteMenu] = useState(false);
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [manageReaction, setManageReaction] = useState<{ emoji: string; reactionId: string } | null>(null);
  const [isHighlighted, setIsHighlighted] = useState(false);
  const [longPressTimer, setLongPressTimer] = useState<NodeJS.Timeout | null>(null);
  const [touchStartPos, setTouchStartPos] = useState<{ x: number; y: number } | null>(null);

  const isMine = message.is_mine || false;
  const isForwarded = message.is_forwarded || false;
  const isPinned = message.is_pinned || false;

  // Get current user ID from localStorage
  const getCurrentUserId = () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) return null;
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.user_id;
    } catch {
      return null;
    }
  };

  // Handle delete with options
  const handleDeleteClick = () => {
    if (isMine) {
      // For my messages: show menu with "Delete for everyone" and "Delete for me"
      setShowDeleteMenu(true);
    } else {
      // For their messages: directly delete for me (parent will show confirmation)
      onDelete(message.id);
    }
  };

  const handleUnsend = () => {
    // Will be confirmed by parent component with proper dialog
    onDelete(message.id);
    setShowDeleteMenu(false);
  };

  const handleDeleteForMe = () => {
    // Will be confirmed by parent component with proper dialog  
    onDelete(message.id);
    setShowDeleteMenu(false);
  };

  // ==================== STATUS INDICATORS ====================

  const StatusIndicator = () => {
    if (!isMine) return null;

    // Priority: send_state > status
    // send_state is for client-side states (sending, failed, queued)
    // status is for server-confirmed states (sent, delivered, read)

    // 1. Sending state (loading spinner)
    if (message.send_state === 'sending') {
      return (
        <div title="Sending...">
          <Loader2 className="w-3 h-3 text-gray-400 animate-spin" />
        </div>
      );
    }

    // 2. Failed state (alert icon + retry button)
    if (message.send_state === 'failed' || message.send_error) {
      return (
        <div className="flex items-center gap-1" title={message.send_error || 'Failed to send'}>
          <AlertCircle className="w-3 h-3 text-red-500" />
          {onRetry && message.temp_id && (
            <button
              onClick={(e) => {
                e.stopPropagation();
                onRetry(message.temp_id!);
              }}
              className="p-0.5 hover:bg-white/20 rounded transition-colors"
              title="Retry sending"
            >
              <RotateCw className="w-3 h-3 text-red-500 hover:text-red-400" />
            </button>
          )}
        </div>
      );
    }

    // 3. Queued state (clock icon)
    if (message.send_state === 'queued') {
      return (
        <div title="Queued - will send when online">
          <Clock className="w-3 h-3 text-orange-400" />
        </div>
      );
    }

    // 4. Normal status dots (sent, delivered, read)
    switch (message.status) {
      case 'sent':
        return (
          <div className="w-2 h-2 rounded-full bg-gray-400" title="Sent" />
        );
      case 'delivered':
        return (
          <div className="w-2 h-2 rounded-full bg-yellow-400" title="Delivered" />
        );
      case 'read':
        return (
          <div className="w-2 h-2 rounded-full bg-green-500" title="Read" />
        );
      default:
        return null;
    }
  };

  // Alias for backward compatibility
  const StatusDot = StatusIndicator;

  // ==================== QUICK REACTIONS ====================

  const quickReactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

  const handleQuickReaction = (emoji: string) => {
    onReact(message.id, emoji);
    setShowReactions(false);
    setShowEmojiPicker(false);
  };

  // ==================== REACTION MANAGEMENT ====================

  const handleReactionClick = (reaction: any) => {
    const currentUserId = getCurrentUserId();
    
    // Only allow managing own reactions
    if (reaction.user_id === currentUserId) {
      setManageReaction({
        emoji: reaction.emoji,
        reactionId: reaction.id,
      });
    }
  };

  const handleRemoveReaction = () => {
    if (manageReaction) {
      // Call onReact with the same emoji to toggle it off
      onReact(message.id, manageReaction.emoji);
    }
  };

  const handleChangeReaction = (newEmoji: string) => {
    if (manageReaction) {
      // Remove old reaction, then add new one
      onReact(message.id, manageReaction.emoji); // Toggle off old
      setTimeout(() => {
        onReact(message.id, newEmoji); // Add new
      }, 100);
    }
  };

  // ==================== LONG PRESS HANDLING ====================

  const handleLongPressStart = (e: React.TouchEvent | React.MouseEvent) => {
    // Record touch/click position
    const pos = 'touches' in e ? 
      { x: e.touches[0].clientX, y: e.touches[0].clientY } :
      { x: (e as React.MouseEvent).clientX, y: (e as React.MouseEvent).clientY };
    
    setTouchStartPos(pos);

    // Start timer for long press (600ms - WhatsApp standard)
    const timer = setTimeout(() => {
      setShowActions(true);
      setIsHighlighted(true);
      
      // Haptic feedback on mobile
      if (navigator.vibrate) {
        navigator.vibrate(50);
      }
    }, 500);

    setLongPressTimer(timer);
  };

  const handleLongPressMove = (e: React.TouchEvent | React.MouseEvent) => {
    if (!touchStartPos || !longPressTimer) return;

    // Get current position
    const currentPos = 'touches' in e ?
      { x: e.touches[0].clientX, y: e.touches[0].clientY } :
      { x: (e as React.MouseEvent).clientX, y: (e as React.MouseEvent).clientY };

    // Cancel if moved more than 10px (prevents accidental long press during scroll)
    const distance = Math.sqrt(
      Math.pow(currentPos.x - touchStartPos.x, 2) +
      Math.pow(currentPos.y - touchStartPos.y, 2)
    );

    if (distance > 10) {
      if (longPressTimer) {
        clearTimeout(longPressTimer);
        setLongPressTimer(null);
      }
      setTouchStartPos(null);
    }
  };

  const handleLongPressEnd = () => {
    // Clear timer if released before timeout
    if (longPressTimer) {
      clearTimeout(longPressTimer);
      setLongPressTimer(null);
    }
    setTouchStartPos(null);
  };

  // Close actions when clicking outside
  const handleClickOutside = () => {
    if (showActions) {
      setShowActions(false);
      setIsHighlighted(false);
      setShowReactions(false);
      setShowDeleteMenu(false);
      setShowEmojiPicker(false);
    }
  };

  // ==================== RENDER ====================

  return (
    <>
      {/* Backdrop for closing actions */}
      {showActions && (
        <div
          className="fixed inset-0 z-40"
          onClick={handleClickOutside}
          onTouchEnd={handleClickOutside}
        />
      )}

      <div
        id={`message-${message.id}`}
        className={`flex ${isMine ? 'justify-end' : 'justify-start'} group scroll-mt-4 transition-all duration-200 ${
          isHighlighted ? 'relative z-50' : ''
        }`}
      >
        <div className={`relative max-w-[80%]`}>
        {/* Action Menu (on hover) - WhatsApp Style */}
        {showActions && !showReactions && (
          <div
            className={`absolute -top-11 ${
              isMine ? 'right-0' : 'left-0'
            } flex items-center gap-0.5 bg-white dark:bg-gray-800 rounded-lg shadow-xl border border-gray-200 dark:border-gray-700 p-1 z-50`}
          >
            <button
              onClick={() => setShowReactions(true)}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
              title="React"
            >
              <Smile className="w-4 h-4" />
            </button>
            <button
              onClick={() => onReply(message)}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
              title="Reply"
            >
              <Reply className="w-4 h-4" />
            </button>
            {onEdit && isMine && message.message_type === 'text' && (
              <button
                onClick={() => onEdit(message)}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
                title="Edit"
              >
                <Edit className="w-4 h-4" />
              </button>
            )}
            {onForward && (
              <button
                onClick={() => onForward(message)}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
                title="Forward"
              >
                <Forward className="w-4 h-4" />
              </button>
            )}
            {onCopy && (
              <button
                onClick={() => onCopy(message)}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
                title="Copy"
              >
                <Copy className="w-4 h-4" />
              </button>
            )}
            <button
              onClick={() => onStar(message.id, message.is_starred || false)}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
              title={message.is_starred ? 'Unstar' : 'Star'}
            >
              <Star
                className={`w-4 h-4 ${
                  message.is_starred ? 'fill-yellow-400 text-yellow-400' : ''
                }`}
              />
            </button>
            {onPin && (
              <button
                onClick={() => onPin(message.id, isPinned)}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
                title={isPinned ? 'Unpin' : 'Pin'}
              >
                <Pin
                  className={`w-4 h-4 ${
                    isPinned ? 'fill-purple-400 text-purple-400' : ''
                  }`}
                />
              </button>
            )}
            <button
              onClick={() => handleDeleteClick()}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors text-red-600"
              title={isMine ? "Delete" : "Delete for me"}
            >
              <Trash2 className="w-4 h-4" />
            </button>
            {onShare && (
              <button
                onClick={() => onShare(message)}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
                title="Share"
              >
                <Share2 className="w-4 h-4" />
              </button>
            )}
            {onInfo && (
              <button
                onClick={() => onInfo(message)}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
                title="Info"
              >
                <Info className="w-4 h-4" />
              </button>
            )}
          </div>
        )}

        {/* Reaction Picker - Instagram/WhatsApp Style */}
        {showReactions && !showEmojiPicker && (
          <div
            className={`absolute -top-16 ${
              isMine ? 'right-0' : 'left-0'
            } bg-white dark:bg-gray-800 rounded-full shadow-2xl border border-gray-200 dark:border-gray-700 px-3 py-2 flex items-center gap-1 backdrop-blur-lg`}
          >
            {/* Quick Reactions */}
            {quickReactions.map((emoji) => (
              <button
                key={emoji}
                onClick={() => handleQuickReaction(emoji)}
                className="text-2xl hover:scale-125 active:scale-110 transition-transform p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full"
                title={`React with ${emoji}`}
              >
                {emoji}
              </button>
            ))}
            
            {/* Divider */}
            <div className="w-px h-8 bg-gray-300 dark:bg-gray-600 mx-1"></div>
            
            {/* More Emojis Button */}
            <button
              onClick={() => setShowEmojiPicker(true)}
              className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors flex items-center justify-center w-10 h-10 border-2 border-dashed border-gray-400 dark:border-gray-500"
              title="More emojis"
            >
              <Plus className="w-5 h-5 text-gray-600 dark:text-gray-400" />
            </button>
          </div>
        )}

        {/* Full Emoji Picker Dropdown */}
        {showEmojiPicker && (
          <EmojiPicker
            onSelect={handleQuickReaction}
            onClose={() => setShowEmojiPicker(false)}
            position={isMine ? 'right' : 'left'}
          />
        )}

        {/* Delete Menu (For My Messages) */}
        {showDeleteMenu && isMine && (
          <div
            className={`absolute -top-24 ${
              isMine ? 'right-0' : 'left-0'
            } bg-white dark:bg-gray-800 rounded-lg shadow-xl border border-gray-200 dark:border-gray-700 py-1 min-w-[180px] z-10`}
          >
            <button
              onClick={handleUnsend}
              className="w-full px-4 py-2 text-left text-sm hover:bg-gray-100 dark:hover:bg-gray-700 text-red-600 dark:text-red-400 flex items-center gap-2"
            >
              <Trash2 className="w-4 h-4" />
              Delete for everyone
            </button>
            <button
              onClick={handleDeleteForMe}
              className="w-full px-4 py-2 text-left text-sm hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-300 flex items-center gap-2"
            >
              <Trash2 className="w-4 h-4" />
              Delete for me
            </button>
            <button
              onClick={() => setShowDeleteMenu(false)}
              className="w-full px-4 py-2 text-left text-sm hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-500 dark:text-gray-400"
            >
              Cancel
            </button>
          </div>
        )}

        {/* Message Bubble - WhatsApp Style with Tail */}
        <div
          onTouchStart={handleLongPressStart}
          onTouchMove={handleLongPressMove}
          onTouchEnd={handleLongPressEnd}
          onMouseDown={handleLongPressStart}
          onMouseMove={handleLongPressMove}
          onMouseUp={handleLongPressEnd}
          onMouseLeave={handleLongPressEnd}
          className={`break-words ${
            message.message_type === 'image' || message.message_type === 'file' || message.message_type === 'video'
              ? 'p-0.5 overflow-hidden' // Minimal 2px padding for images, videos and files
              : 'px-3 py-2' // Normal padding for text/audio
          } ${
            isMine
              ? 'bg-purple-600 text-white rounded-[18px] rounded-br-[4px]'
              : 'bg-gray-200 dark:bg-gray-800 text-gray-900 dark:text-white rounded-[18px] rounded-bl-[4px]'
          } ${
            isHighlighted ? 'ring-2 ring-purple-400 ring-opacity-50 scale-[1.02]' : ''
          } transition-all duration-150 select-none`}
          style={{ wordBreak: 'break-word', overflowWrap: 'anywhere', maxWidth: '100%' }}
        >
          {/* Forwarded Label */}
          {isForwarded && (
            <div className={`flex items-center gap-1.5 text-xs mb-1.5 ${
              (message.message_type === 'image' || message.message_type === 'file' || message.message_type === 'video') ? 'px-3 pt-2' : ''
            } ${
              isMine ? 'text-purple-200' : 'text-gray-500 dark:text-gray-400'
            }`}>
              <Forward className="w-3 h-3" />
              <span className="italic">Forwarded</span>
            </div>
          )}

          {/* Reply Preview - WhatsApp Style */}
          {message.reply_to && (
            <div
              className={`mb-2 pb-1.5 px-2 py-1.5 rounded-md cursor-pointer transition-colors ${
                (message.message_type === 'image' || message.message_type === 'file' || message.message_type === 'video') ? 'mx-2 mt-2' : ''
              } ${
                isMine 
                  ? 'bg-purple-700/30 border-l-4 border-purple-300' 
                  : 'bg-gray-300/50 dark:bg-gray-700/50 border-l-4 border-gray-500'
              } hover:bg-opacity-80`}
              onClick={() => {
                // Scroll to original message
                const element = document.getElementById(`message-${message.reply_to_id}`);
                if (element) {
                  element.scrollIntoView({ behavior: 'smooth', block: 'center' });
                  // Highlight briefly
                  element.classList.add('ring-2', 'ring-yellow-400');
                  setTimeout(() => {
                    element.classList.remove('ring-2', 'ring-yellow-400');
                  }, 2000);
                }
              }}
            >
              <div className={`text-[11px] font-semibold mb-0.5 ${
                isMine ? 'text-purple-200' : 'text-purple-600 dark:text-purple-400'
              }`}>
                {message.reply_to.sender?.display_name || 'User'}
              </div>
              <div className={`text-xs ${
                isMine ? 'text-purple-100' : 'text-gray-700 dark:text-gray-300'
              } line-clamp-2 flex items-center gap-1.5`}>
                {message.reply_to.message_type === 'image' && (
                  <>
                    <ImageIcon className="w-3.5 h-3.5 flex-shrink-0" />
                    <span>Photo</span>
                  </>
                )}
                {message.reply_to.message_type === 'audio' && (
                  <>
                    <Mic className="w-3.5 h-3.5 flex-shrink-0" />
                    <span>Voice message</span>
                  </>
                )}
                {message.reply_to.message_type === 'file' && (
                  <>
                    <Paperclip className="w-3.5 h-3.5 flex-shrink-0" />
                    <span>File</span>
                  </>
                )}
                {message.reply_to.message_type === 'text' && message.reply_to.content}
              </div>
            </div>
          )}

          {/* Content */}
          {message.message_type === 'text' && (
            <>
              {/* Text with clickable links */}
              <div className="text-sm whitespace-pre-wrap break-words">
                {(message.content && message.content.trim() ? message.content.split(/(https?:\/\/[^\s]+)/gi) : []).map((part, index) => {
                  // Check if this part is a URL
                  if (part.match(/^https?:\/\//i)) {
                    return (
                      <a
                        key={index}
                        href={part}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={`underline ${
                          isMine 
                            ? 'text-purple-100 hover:text-white' 
                            : 'text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300'
                        }`}
                        onClick={(e) => e.stopPropagation()}
                      >
                        {part}
                      </a>
                    );
                  }
                  return <span key={index}>{part}</span>;
                })}
              </div>

              {/* Link Preview Card */}
              {message.content && containsUrl(message.content) && extractUrls(message.content).map((url, index) => (
                <LinkPreview key={index} url={url} isMine={isMine} />
              ))}
            </>
          )}

          {message.message_type === 'image' && (
            <div 
              onClick={() => onViewMedia?.(message)}
              className="cursor-pointer hover:opacity-95 transition-opacity"
            >
              <ImageMessage url={message.attachment_url || ''} alt="Image" />
            </div>
          )}

          {message.message_type === 'video' && (
            <VideoPlayer 
              url={message.attachment_url || ''} 
              thumbnailUrl={message.thumbnail_url}
              duration={message.video_duration}
              width={message.video_width}
              height={message.video_height}
              onExpand={() => onViewMedia?.(message)}
            />
          )}

          {message.message_type === 'audio' && (
            <AudioPlayer url={message.attachment_url || ''} duration={0} />
          )}

          {message.message_type === 'file' && (
            <div 
              onClick={() => onViewMedia?.(message)}
              className="cursor-pointer hover:opacity-95 transition-opacity rounded-lg overflow-hidden max-w-xs"
            >
              {/* Document Preview Container - 2px bezels from bubble padding */}
              <div className="relative bg-white rounded-lg overflow-hidden">
                {/* PDF/Document Preview */}
                {message.attachment_type?.includes('pdf') ? (
                  <div className="w-full h-[220px] bg-white relative overflow-hidden">
                    {/* PDF Embed with proper permissions */}
                    <embed
                      src={`${message.attachment_url}#toolbar=0&navpanes=0&scrollbar=0&view=FitH`}
                      type="application/pdf"
                      className="w-full h-full border-0"
                      style={{ 
                        filter: 'contrast(1.05) brightness(0.98)',
                        pointerEvents: 'none'
                      }}
                    />
                    {/* Overlay to prevent interaction */}
                    <div className="absolute inset-0 bg-transparent cursor-pointer" />
                    
                    {/* Subtle shadow at bottom for depth */}
                    <div className="absolute bottom-0 left-0 right-0 h-6 bg-gradient-to-t from-black/5 to-transparent pointer-events-none" />
                  </div>
                ) : message.attachment_type?.includes('image') ? (
                  <img 
                    src={message.attachment_url} 
                    alt="Document preview"
                    className="w-full h-[220px] object-cover"
                  />
                ) : (
                  // Generic document preview for other file types
                  <div className="w-full h-[220px] bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
                    <div className="text-center">
                      <div className="w-20 h-20 bg-white rounded-2xl shadow-lg flex items-center justify-center mx-auto mb-4">
                        <Paperclip className="w-10 h-10 text-blue-600" />
                      </div>
                      <p className="text-base text-blue-700 font-semibold">
                        {message.attachment_type?.split('/')[1]?.toUpperCase() || 'DOCUMENT'}
                      </p>
                      <p className="text-sm text-blue-600 mt-1">
                        {message.attachment_size 
                          ? `${(message.attachment_size / 1024).toFixed(0)} KB` 
                          : 'File'}
                      </p>
                    </div>
                  </div>
                )}

                {/* Document Info Bar - WhatsApp Style */}
                <div className={`${
                  isMine 
                    ? 'bg-purple-700/30 dark:bg-purple-600/30' 
                    : 'bg-gray-100 dark:bg-gray-700'
                } px-3 py-2.5 border-t border-gray-200 dark:border-gray-600`}>
                  <div className="flex items-center gap-2.5">
                    {/* File Icon */}
                    <div className={`w-9 h-9 ${
                      isMine ? 'bg-purple-500/40' : 'bg-blue-500/30'
                    } rounded-lg flex items-center justify-center flex-shrink-0`}>
                      <Paperclip className={`w-4 h-4 ${
                        isMine ? 'text-purple-200' : 'text-blue-600'
                      }`} />
                    </div>
                    
                    {/* File Info */}
                    <div className="flex-1 min-w-0">
                      <p className={`text-[13px] font-semibold truncate ${
                        isMine ? 'text-white' : 'text-gray-900 dark:text-gray-100'
                      }`}>
                        {message.attachment_name || 'Document'}
                      </p>
                      <p className={`text-[11px] mt-0.5 font-medium ${
                        isMine ? 'text-purple-100' : 'text-gray-700 dark:text-gray-400'
                      }`}>
                        {message.attachment_size 
                          ? `${(message.attachment_size / 1024).toFixed(0)} KB` 
                          : 'File'}
                        {' • '}
                        {message.attachment_type?.split('/')[1]?.toUpperCase() || 'FILE'}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Timestamp + Status Dot + Star (Inside Bubble) */}
          <div className={`flex items-center justify-end gap-1.5 mt-1.5 ${
            (message.message_type === 'image' || message.message_type === 'file' || message.message_type === 'video') ? 'px-2 pb-1' : ''
          }`}>
            <span className={`text-[10px] ${
              (message.message_type === 'image' || message.message_type === 'file' || message.message_type === 'video')
                ? 'text-white drop-shadow-lg'
                : isMine ? 'text-purple-200' : 'text-gray-500 dark:text-gray-400'
            }`}>
              {formatMessageTimestamp(message.created_at)}
            </span>
            {message.edited_at && (
              <span className={`text-[9px] italic ${
                (message.message_type === 'image' || message.message_type === 'file' || message.message_type === 'video')
                  ? 'text-white/90 drop-shadow-lg'
                  : isMine ? 'text-purple-300' : 'text-gray-400 dark:text-gray-500'
              }`}>
                (edited)
              </span>
            )}
            <StatusDot />
            {message.is_starred && (
              <Star className="w-3 h-3 fill-yellow-400 text-yellow-400" />
            )}
            {isPinned && (
              <Pin className="w-3 h-3 fill-purple-400 text-purple-400" />
            )}
          </div>
        </div>

        {/* Reactions (Outside Bubble - WhatsApp Style) */}
        {message.reactions && message.reactions.length > 0 && (
          <div className={`flex flex-wrap gap-1 mt-1 ${isMine ? 'justify-end' : 'justify-start'}`}>
            {message.reactions.map((reaction) => {
              const currentUserId = getCurrentUserId();
              const isMyReaction = reaction.user_id === currentUserId;
              
              return (
                <button
                  key={reaction.id}
                  onClick={() => handleReactionClick(reaction)}
                  className={`text-xs bg-white dark:bg-gray-700 border px-2 py-0.5 rounded-full shadow-sm transition-all ${
                    isMyReaction
                      ? 'border-purple-400 dark:border-purple-600 hover:bg-purple-50 dark:hover:bg-purple-900/20 cursor-pointer hover:scale-110'
                      : 'border-gray-200 dark:border-gray-600 cursor-default'
                  }`}
                  title={isMyReaction ? 'Click to manage your reaction' : (reaction.user?.display_name || 'Someone')}
                  disabled={!isMyReaction}
                >
                  {reaction.emoji}
                </button>
              );
            })}
          </div>
        )}
        </div>

        {/* Reaction Management Dialog */}
        <ReactionManageDialog
          isOpen={!!manageReaction}
          currentEmoji={manageReaction?.emoji || ''}
          onClose={() => setManageReaction(null)}
          onRemove={handleRemoveReaction}
          onChange={handleChangeReaction}
        />
      </div>
    </>
  );
}


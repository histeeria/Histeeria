'use client';

import { useState } from 'react';
import { MoreVertical, Reply, Trash2, Edit2 } from 'lucide-react';
import { AnimatePresence, motion } from 'framer-motion';
import { Comment, formatPostTimestamp } from '@/lib/api/posts';
import { Avatar } from '../ui/Avatar';
import VerifiedBadge from '../ui/VerifiedBadge';

interface CommentItemProps {
  comment: Comment;
  currentUserId?: string;
  onLike: () => void;
  onReply: () => void;
  onEdit: () => void;
  onDelete: () => void;
  onLoadReplies: () => void;
  showMenu: string | null;
  onToggleMenu: (commentId: string) => void;
  depth?: number;
}

export default function CommentItem({
  comment,
  currentUserId,
  onLike,
  onReply,
  onEdit,
  onDelete,
  onLoadReplies,
  showMenu,
  onToggleMenu,
  depth = 0,
}: CommentItemProps) {
  const isOwnComment = comment.user_id === currentUserId;
  const hasReplies = comment.replies_count > 0;
  const showReplies = comment.replies && comment.replies.length > 0;
  const [isLiking, setIsLiking] = useState(false);

  const handleLike = async () => {
    if (isLiking) return;
    setIsLiking(true);
    await onLike();
    // Simulate haptic feedback
    if (navigator.vibrate) {
      navigator.vibrate(10);
    }
    setTimeout(() => setIsLiking(false), 300);
  };

  return (
    <div className="flex gap-3 group">
      <Avatar
        src={comment.author?.profile_picture}
        alt={comment.author?.display_name || comment.author?.username || 'User'}
        fallback={comment.author?.display_name || comment.author?.username || 'U'}
        size="sm"
        className="flex-shrink-0"
      />
      <div className="flex-1 min-w-0">
        {/* Comment Content */}
        <div className="mb-1">
          <div className="flex items-start justify-between gap-2">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1.5 mb-0.5">
                <span className="text-sm font-semibold text-neutral-900 dark:text-neutral-50">
                  {comment.author?.display_name || comment.author?.username}
                </span>
                {comment.author?.is_verified && (
                  <VerifiedBadge size="sm" variant="badge" showText={false} />
                )}
              </div>
              <p className="text-sm text-neutral-900 dark:text-neutral-50 whitespace-pre-wrap break-words leading-relaxed">
                {comment.content}
              </p>
              {comment.is_edited && (
                <span className="text-xs text-neutral-400 dark:text-neutral-500 ml-1">
                  (edited)
                </span>
              )}
            </div>
            {isOwnComment && (
              <div className="relative flex-shrink-0">
                <button
                  onClick={() => onToggleMenu(comment.id)}
                  className="p-1 transition-opacity opacity-0 group-hover:opacity-100"
                >
                  <MoreVertical className="w-4 h-4 text-neutral-500 dark:text-neutral-400" />
                </button>
                <AnimatePresence>
                  {showMenu === comment.id && (
                    <motion.div
                      initial={{ opacity: 0, scale: 0.95, y: -10 }}
                      animate={{ opacity: 1, scale: 1, y: 0 }}
                      exit={{ opacity: 0, scale: 0.95, y: -10 }}
                      transition={{ duration: 0.15 }}
                      className="absolute right-0 top-8 z-20
                        bg-white dark:bg-neutral-900
                        border border-neutral-200 dark:border-neutral-800
                        rounded-lg shadow-lg
                        py-1 min-w-[140px]
                      "
                    >
                      <button
                        onClick={onEdit}
                        className="w-full px-4 py-2 text-left text-sm text-neutral-700 dark:text-neutral-300 transition-colors"
                      >
                        <Edit2 className="w-4 h-4 inline mr-2" />
                        Edit
                      </button>
                      <button
                        onClick={onDelete}
                        className="w-full px-4 py-2 text-left text-sm text-red-600 dark:text-red-400 transition-colors"
                      >
                        <Trash2 className="w-4 h-4 inline mr-2" />
                        Delete
                      </button>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            )}
          </div>
        </div>

        {/* Comment Actions - Instagram Style */}
        <div className="flex items-center gap-4 mb-2">
          <span className="text-xs text-neutral-400 dark:text-neutral-500">
            {formatPostTimestamp(comment.created_at)}
          </span>
          <button
            onClick={handleLike}
            disabled={isLiking}
            className={`
              text-xs font-semibold transition-colors
              ${comment.is_liked
                ? 'text-red-600 dark:text-red-400'
                : 'text-neutral-400 dark:text-neutral-500'
              }
              ${isLiking ? 'opacity-50' : ''}
            `}
          >
            Like
          </button>
          {depth < 2 && (
            <button
              onClick={onReply}
              className="text-xs font-semibold text-neutral-400 dark:text-neutral-500 transition-colors"
            >
              Reply
            </button>
          )}
          {comment.likes_count > 0 && (
            <span className="text-xs font-semibold text-neutral-900 dark:text-neutral-50">
              {comment.likes_count} {comment.likes_count === 1 ? 'like' : 'likes'}
            </span>
          )}
        </div>

        {/* Replies */}
        {showReplies && (
          <div className="ml-4 mt-3 space-y-4 pl-4 border-l border-neutral-200 dark:border-neutral-800">
            {comment.replies?.map((reply) => (
              <CommentItem
                key={reply.id}
                comment={reply}
                currentUserId={currentUserId}
                onLike={onLike}
                onReply={onReply}
                onEdit={onEdit}
                onDelete={onDelete}
                onLoadReplies={onLoadReplies}
                showMenu={showMenu}
                onToggleMenu={onToggleMenu}
                depth={depth + 1}
              />
            ))}
            {comment.replies_count > (comment.replies?.length || 0) && (
              <button
                onClick={onLoadReplies}
                className="text-xs text-neutral-500 dark:text-neutral-400 font-medium mt-2 transition-colors"
              >
                View {comment.replies_count - (comment.replies?.length || 0)} more replies
              </button>
            )}
          </div>
        )}
        {hasReplies && !showReplies && (
          <button
            onClick={onLoadReplies}
            className="text-xs text-neutral-500 dark:text-neutral-400 font-medium mt-2 transition-colors"
          >
            View {comment.replies_count} {comment.replies_count === 1 ? 'reply' : 'replies'}
          </button>
        )}
      </div>
    </div>
  );
}


'use client';

/**
 * Status Comments Component
 * Sidebar for displaying and adding comments on statuses
 * Created by: Hamza Hafeez - Founder & CEO of Histeeria
 */

import { useState, useEffect } from 'react';
import { X, Send, Loader2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { Avatar } from '@/components/ui/Avatar';
import { cn } from '@/lib/utils';
import { type Status, type StatusComment, createStatusComment, getStatusComments } from '@/lib/api/statuses';
import { formatDistanceToNow } from 'date-fns';
import { useUser } from '@/lib/hooks/useUser';

interface StatusCommentsProps {
  status: Status;
  comments: StatusComment[];
  onClose: () => void;
  onCommentAdded: (comment: StatusComment) => void;
}

export function StatusComments({ status, comments: initialComments, onClose, onCommentAdded }: StatusCommentsProps) {
  const { user } = useUser();
  const [comments, setComments] = useState<StatusComment[]>(initialComments || []);
  const [commentInput, setCommentInput] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [offset, setOffset] = useState(initialComments?.length || 0);
  const [loadedStatusId, setLoadedStatusId] = useState<string | null>(null);

  const loadComments = async () => {
    if (isLoading || status.id === loadedStatusId) return;
    
    try {
      setIsLoading(true);
      const { comments: loadedComments, hasMore: moreAvailable } = await getStatusComments(status.id, 50, 0);
      setComments(loadedComments || []);
      setOffset(loadedComments?.length || 0);
      setHasMore(moreAvailable || false);
      setLoadedStatusId(status.id);
    } catch (error) {
      console.error('Failed to load comments:', error);
      setComments([]);
      setHasMore(false);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    // Load comments when component mounts or status changes
    loadComments();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status.id]);

  const handleSubmit = async () => {
    if (!commentInput.trim() || isSubmitting || !user) return;

    setIsSubmitting(true);
    try {
      const newComment = await createStatusComment(status.id, commentInput.trim());
      setComments((prev) => [newComment, ...prev]);
      setCommentInput('');
      onCommentAdded(newComment);
      // Reload to get full comment data with author
      await loadComments();
    } catch (error) {
      console.error('Failed to create comment:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const loadMoreComments = async () => {
    if (isLoading || !hasMore) return;

    setIsLoading(true);
    try {
      const { comments: newComments, hasMore: moreAvailable } = await getStatusComments(status.id, 50, offset);
      if (newComments.length > 0) {
        setComments((prev) => [...prev, ...newComments]);
        setOffset((prev) => prev + newComments.length);
        setHasMore(moreAvailable);
      } else {
        setHasMore(false);
      }
    } catch (error) {
      console.error('Failed to load comments:', error);
      setHasMore(false);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <motion.div
      initial={{ x: '100%' }}
      animate={{ x: 0 }}
      exit={{ x: '100%' }}
      transition={{ type: 'spring', damping: 32, stiffness: 300 }}
      className="absolute top-0 right-0 bottom-0 w-full md:w-96 bg-black/95 backdrop-blur-xl border-l border-white/10 z-30 flex flex-col"
    >
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-white/10">
        <h2 className="text-white font-semibold text-lg">Comments</h2>
        <button
          onClick={onClose}
          className="p-2 rounded-full hover:bg-white/10 transition-colors"
        >
          <X className="w-5 h-5 text-white" />
        </button>
      </div>

      {/* Comments List */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        <AnimatePresence>
          {comments.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full text-white/50">
              <p className="text-sm">No comments yet</p>
              <p className="text-xs mt-1">Be the first to comment!</p>
            </div>
          ) : (
            comments.map((comment) => (
              <motion.div
                key={comment.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -20 }}
                className="flex gap-3"
              >
                <Avatar
                  src={comment.author?.profile_picture}
                  alt={comment.author?.display_name || 'User'}
                  fallback={comment.author?.display_name || 'User'}
                  size="sm"
                />
                <div className="flex-1 min-w-0">
                  <div className="bg-white/10 rounded-2xl rounded-tl-sm p-3">
                    <p className="text-white font-semibold text-sm mb-1">
                      {comment.author?.display_name || 'Unknown'}
                    </p>
                    <p className="text-white/90 text-sm leading-relaxed whitespace-pre-wrap break-words">
                      {comment.content}
                    </p>
                  </div>
                  <p className="text-white/50 text-xs mt-1 ml-2">
                    {formatDistanceToNow(new Date(comment.created_at), { addSuffix: true })}
                  </p>
                </div>
              </motion.div>
            ))
          )}
        </AnimatePresence>

        {isLoading && (
          <div className="flex justify-center py-4">
            <Loader2 className="w-5 h-5 text-white/50 animate-spin" />
          </div>
        )}

        {hasMore && !isLoading && (
          <button
            onClick={loadMoreComments}
            className="w-full py-2 text-white/70 hover:text-white text-sm transition-colors"
          >
            Load more comments
          </button>
        )}
      </div>

      {/* Comment Input */}
      {user && (
        <div className="p-4 border-t border-white/10 bg-black/50">
          <div className="flex items-center gap-2">
            <Avatar
              src={user.profile_picture}
              alt={user.display_name || 'You'}
              fallback={user.display_name || 'You'}
              size="sm"
            />
            <div className="flex-1 relative">
              <input
                type="text"
                value={commentInput}
                onChange={(e) => setCommentInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSubmit()}
                placeholder="Add a comment..."
                className={cn(
                  "w-full px-4 py-2.5 pr-12 bg-white/10 backdrop-blur-md border border-white/20 rounded-full",
                  "text-white placeholder-white/50 focus:outline-none focus:ring-2 focus:ring-brand-purple-500",
                  "disabled:opacity-50 disabled:cursor-not-allowed"
                )}
                disabled={isSubmitting}
                maxLength={500}
              />
              <button
                onClick={handleSubmit}
                disabled={!commentInput.trim() || isSubmitting}
                className={cn(
                  "absolute right-2 top-1/2 -translate-y-1/2 p-1.5 rounded-full transition-all",
                  commentInput.trim() && !isSubmitting
                    ? "bg-brand-purple-600 hover:bg-brand-purple-700 text-white"
                    : "bg-white/10 opacity-50 cursor-not-allowed text-white/50"
                )}
              >
                {isSubmitting ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <Send className="w-4 h-4" />
                )}
              </button>
            </div>
          </div>
          {commentInput.length > 400 && (
            <p className="text-white/50 text-xs mt-1 ml-2">
              {commentInput.length}/500
            </p>
          )}
        </div>
      )}
    </motion.div>
  );
}

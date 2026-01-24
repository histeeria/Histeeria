'use client';

/**
 * Status Viewer Component
 * Full-screen Instagram-like status viewer with swipe gestures
 * Created by: Hamza Hafeez - Founder & CEO of Histeeria
 */

import { useState, useEffect, useRef } from 'react';
import { X, ChevronLeft, ChevronRight, Reply, Send, Heart, ThumbsUp, Sparkles, Handshake, Lightbulb } from 'lucide-react';
import { motion, AnimatePresence, PanInfo } from 'framer-motion';
import { Avatar } from '@/components/ui/Avatar';
import { cn } from '@/lib/utils';
import { type Status, viewStatus, reactToStatus, removeStatusReaction, createStatusComment, getStatusComments, createStatusMessageReply, type StatusComment } from '@/lib/api/statuses';
import { formatDistanceToNow } from 'date-fns';
import { StatusComments } from './StatusComments';
import { useMessages } from '@/lib/contexts/MessagesContext';
import { useUser } from '@/lib/hooks/useUser';
import { toast } from '@/components/ui/Toast';

interface StatusViewerProps {
  isOpen: boolean;
  initialStatus: Status;
  allStatuses: Status[];
  onClose: () => void;
  onNext?: () => void;
  onPrevious?: () => void;
}

const REACTION_EMOJIS = {
  like: { emoji: '👍', icon: ThumbsUp, label: 'Like' },
  fully: { emoji: '💯', icon: Sparkles, label: 'Fully' },
  appreciate: { emoji: '❤️', icon: Heart, label: 'Appreciate' },
  support: { emoji: '🤝', icon: Handshake, label: 'Support' },
  insightful: { emoji: '💡', icon: Lightbulb, label: 'Insightful' },
} as const;

export function StatusViewer({ isOpen, initialStatus, allStatuses, onClose, onNext, onPrevious }: StatusViewerProps) {
  const { user } = useUser();
  const { openMessages } = useMessages();
  const [statuses, setStatuses] = useState<Status[]>(allStatuses);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [currentStatus, setCurrentStatus] = useState<Status>(initialStatus);
  const [showComments, setShowComments] = useState(false);
  const [comments, setComments] = useState<StatusComment[]>([]);
  const [commentInput, setCommentInput] = useState('');
  const [isReacting, setIsReacting] = useState(false);
  const [showReactions, setShowReactions] = useState(false);
  const [progress, setProgress] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const [viewed, setViewed] = useState(initialStatus.is_viewed);
  const [isSendingMessage, setIsSendingMessage] = useState(false);
  const startTimeRef = useRef<number>(0);
  const elapsedTimeRef = useRef<number>(0);
  const DURATION = 5000;


  const progressIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const statusTimerRef = useRef<NodeJS.Timeout | null>(null);
  const dragXRef = useRef(0);

  useEffect(() => {
    if (isOpen) {
      setStatuses(allStatuses);
      setCurrentStatus(initialStatus);
      setCurrentIndex(0);
      setProgress(0);
      setIsPaused(false);
      elapsedTimeRef.current = 0;
      startTimeRef.current = Date.now();

      setShowComments(false);
      setViewed(initialStatus.is_viewed);

      // Record view if not viewed
      if (!initialStatus.is_viewed) {
        viewStatus(initialStatus.id).catch(console.error);
      }

      // Start progress timer
      startProgressTimer();



    } else {
      clearTimers();
    }

    return () => {
      clearTimers();
    };
  }, [isOpen, initialStatus.id]);

  const clearTimers = () => {
    if (progressIntervalRef.current) {
      clearInterval(progressIntervalRef.current);
    }
    if (statusTimerRef.current) {
      cancelAnimationFrame(statusTimerRef.current as any);
    }
  };

  const handleNext = () => {
    clearTimers();
    setProgress(0);
    elapsedTimeRef.current = 0;
    startTimeRef.current = Date.now();


    if (currentIndex < statuses.length - 1) {
      const nextIndex = currentIndex + 1;
      const nextStatus = statuses[nextIndex];
      setCurrentIndex(nextIndex);
      setCurrentStatus(nextStatus);
      setViewed(nextStatus.is_viewed);

      if (!nextStatus.is_viewed) {
        viewStatus(nextStatus.id).catch(console.error);
      }

      startProgressTimer();
    } else if (onNext) {
      onNext();
    } else {
      onClose();
    }
  };

  const handlePrevious = () => {
    clearTimers();
    setProgress(0);
    elapsedTimeRef.current = 0;
    startTimeRef.current = Date.now();


    if (currentIndex > 0) {
      const prevIndex = currentIndex - 1;
      const prevStatus = statuses[prevIndex];
      setCurrentIndex(prevIndex);
      setCurrentStatus(prevStatus);
      setViewed(prevStatus.is_viewed);

      startProgressTimer();
    } else if (onPrevious) {
      onPrevious();
    }
  };

  const startProgressTimer = () => {
    if (statusTimerRef.current) cancelAnimationFrame(statusTimerRef.current as any);

    const animate = () => {
      if (isPaused) return;

      const now = Date.now();
      const totalElapsed = elapsedTimeRef.current + (now - startTimeRef.current);
      const newProgress = (totalElapsed / DURATION) * 100;

      if (newProgress >= 100) {
        handleNext();
      } else {
        setProgress(newProgress);
        statusTimerRef.current = requestAnimationFrame(animate) as any;
      }
    };

    startTimeRef.current = Date.now();
    statusTimerRef.current = requestAnimationFrame(animate) as any;
  };

  // Pause when comments or reactions are shown
  useEffect(() => {
    if (showComments || showReactions) {
      setIsPaused(true);
    } else {
      setIsPaused(false);
    }
  }, [showComments, showReactions]);

  useEffect(() => {
    if (isPaused) {
      // Pause: Save elapsed time
      elapsedTimeRef.current += Date.now() - startTimeRef.current;
      if (statusTimerRef.current) cancelAnimationFrame(statusTimerRef.current as any);
    } else {
      // Resume
      startTimeRef.current = Date.now();
      startProgressTimer();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isPaused]);

  // Reset timer when index changes
  useEffect(() => {
    elapsedTimeRef.current = 0;
    startTimeRef.current = Date.now();
    setProgress(0);
    if (!isPaused) {
      startProgressTimer();
    }
  }, [currentIndex]);

  const handleReaction = async (emoji: string) => {
    if (isReacting) return;

    setIsReacting(true);
    setShowReactions(false);

    try {
      if (currentStatus.user_reaction === emoji) {
        // Remove reaction
        await removeStatusReaction(currentStatus.id);
        const updatedStatus = {
          ...currentStatus,
          user_reaction: undefined,
          reactions_count: Math.max(0, currentStatus.reactions_count - 1),
        };
        setCurrentStatus(updatedStatus);
        // Update in statuses array
        setStatuses(prev => prev.map((s, i) => i === currentIndex ? updatedStatus : s));
      } else {
        // Add/change reaction
        await reactToStatus(currentStatus.id, emoji as any);
        const updatedStatus = {
          ...currentStatus,
          user_reaction: emoji,
          reactions_count: currentStatus.user_reaction
            ? currentStatus.reactions_count
            : currentStatus.reactions_count + 1,
        };
        setCurrentStatus(updatedStatus);
        // Update in statuses array
        setStatuses(prev => prev.map((s, i) => i === currentIndex ? updatedStatus : s));
      }
    } catch (error) {
      console.error('Failed to react:', error);
    } finally {
      setIsReacting(false);
    }
  };

  const handleComment = async () => {
    if (!commentInput.trim() || isReacting) return;

    setIsReacting(true);

    try {
      const newComment = await createStatusComment(currentStatus.id, commentInput.trim());
      setComments((prev) => [newComment, ...prev]);
      setCommentInput('');
      setCurrentStatus({
        ...currentStatus,
        comments_count: currentStatus.comments_count + 1,
      });
      // Reload comments to get the full data
      await loadComments();
    } catch (error) {
      console.error('Failed to comment:', error);
      toast.error('Failed to add comment');
    } finally {
      setIsReacting(false);
    }
  };

  const loadComments = async () => {
    try {
      const { comments: loadedComments } = await getStatusComments(currentStatus.id, 50, 0);
      setComments(loadedComments);
    } catch (error) {
      console.error('Failed to load comments:', error);
    }
  };

  useEffect(() => {
    if (showComments && currentStatus.id) {
      loadComments();
    } else {
      setComments([]);
    }
  }, [showComments, currentStatus.id]);

  const handleDragEnd = (event: MouseEvent | TouchEvent | PointerEvent, info: PanInfo) => {
    dragXRef.current = 0;

    // Horizontal swipe threshold
    const threshold = 100;

    if (info.offset.x > threshold) {
      // Swipe right - previous
      handlePrevious();
    } else if (info.offset.x < -threshold) {
      // Swipe left - next
      handleNext();
    }
  };

  const handleDrag = (_: MouseEvent | TouchEvent | PointerEvent, info: PanInfo) => {
    dragXRef.current = info.offset.x;
  };

  if (!isOpen) return null;

  const isTextStatus = currentStatus.status_type === 'text';
  const bgColor = currentStatus.background_color || '#1a1f3a';

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[300] bg-black/95 backdrop-blur-xl">
        {/* Progress Bars */}
        <div className="absolute top-0 left-0 right-0 h-1 bg-black/30 z-10 flex gap-1 p-2">
          {statuses.map((_, index) => (
            <div
              key={index}
              className="flex-1 h-0.5 bg-white/30 rounded-full overflow-hidden"
            >
              <motion.div
                className={cn(
                  "h-full rounded-full",
                  index < currentIndex
                    ? "bg-white"
                    : index === currentIndex
                      ? "bg-white"
                      : "bg-transparent"
                )}
                style={{
                  width: index === currentIndex ? `${progress}%` : index < currentIndex ? '100%' : '0%',
                }}
                initial={false}
              />
            </div>
          ))}
        </div>

        {/* Status Content */}
        <motion.div
          drag="x"
          dragConstraints={{ left: 0, right: 0 }}
          dragElastic={0.2}
          onDrag={handleDrag}
          onDragEnd={handleDragEnd}
          className="absolute inset-0 flex items-center justify-center"
          onMouseDown={() => setIsPaused(true)}
          onMouseUp={() => setIsPaused(false)}
          onTouchStart={() => setIsPaused(true)}
          onTouchEnd={() => setIsPaused(false)}
        >
          {isTextStatus ? (
            <div
              className="w-full h-full flex items-center justify-center p-8"
              style={{ backgroundColor: bgColor }}
            >
              <motion.p
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                className="text-white text-2xl md:text-4xl font-semibold text-center"
                style={{ textShadow: '0 2px 8px rgba(0,0,0,0.3)' }}
              >
                {currentStatus.content}
              </motion.p>
            </div>
          ) : currentStatus.media_url ? (
            <motion.div
              initial={{ opacity: 0, scale: 1.1 }}
              animate={{ opacity: 1, scale: 1 }}
              className="relative w-full h-full"
            >
              {currentStatus.status_type === 'video' ? (
                <video
                  src={currentStatus.media_url}
                  className="w-full h-full object-contain"
                  autoPlay
                  loop
                  muted
                  playsInline
                />
              ) : (
                <img
                  src={currentStatus.media_url}
                  alt="Status"
                  className="w-full h-full object-contain"
                />
              )}
            </motion.div>
          ) : null}

          {/* Navigation Arrows */}
          {statuses.length > 1 && (
            <>
              <button
                onClick={handlePrevious}
                disabled={currentIndex === 0 && !onPrevious}
                className={cn(
                  "absolute left-4 top-1/2 -translate-y-1/2 p-2 rounded-full bg-black/50 hover:bg-black/70 transition-colors",
                  currentIndex === 0 && !onPrevious && "opacity-30 cursor-not-allowed"
                )}
              >
                <ChevronLeft className="w-6 h-6 text-white" />
              </button>
              <button
                onClick={handleNext}
                disabled={currentIndex === statuses.length - 1 && !onNext}
                className={cn(
                  "absolute right-4 top-1/2 -translate-y-1/2 p-2 rounded-full bg-black/50 hover:bg-black/70 transition-colors",
                  currentIndex === statuses.length - 1 && !onNext && "opacity-30 cursor-not-allowed"
                )}
              >
                <ChevronRight className="w-6 h-6 text-white" />
              </button>
            </>
          )}
        </motion.div>

        {/* Header */}
        <div className="absolute top-0 left-0 right-0 p-4 pt-12 z-20 bg-gradient-to-b from-black/60 to-transparent">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3 flex-1 min-w-0">
              <Avatar
                src={currentStatus.author?.profile_picture}
                alt={currentStatus.author?.display_name || ''}
                fallback={currentStatus.author?.display_name || ''}
                size="sm"
                className="border-2 border-white"
              />
              <div className="flex-1 min-w-0">
                <p className="text-white font-semibold text-sm truncate">
                  {currentStatus.author?.display_name || 'Unknown'}
                </p>
                <p className="text-white/70 text-xs">
                  {formatDistanceToNow(new Date(currentStatus.created_at), { addSuffix: true })}
                </p>
              </div>
            </div>
            <button
              onClick={onClose}
              className="p-2 rounded-full hover:bg-white/20 transition-colors ml-2"
            >
              <X className="w-5 h-5 text-white" />
            </button>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="absolute bottom-0 left-0 right-0 p-4 pb-8 z-20 bg-gradient-to-t from-black/60 to-transparent">
          {/* Quick Reactions Bar */}
          {showReactions && (
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 20 }}
              className="absolute bottom-20 left-1/2 -translate-x-1/2 flex gap-2 p-2 bg-black/80 rounded-full backdrop-blur-md border border-white/20"
            >
              {Object.entries(REACTION_EMOJIS).map(([key, reaction]) => {
                const Icon = reaction.icon;
                const isActive = currentStatus.user_reaction === reaction.emoji;

                return (
                  <button
                    key={key}
                    onClick={() => handleReaction(reaction.emoji)}
                    className={cn(
                      "p-2 rounded-full transition-all",
                      isActive
                        ? "bg-brand-purple-600 scale-110"
                        : "bg-white/10 hover:bg-white/20 hover:scale-110"
                    )}
                  >
                    <span className="text-xl">{reaction.emoji}</span>
                  </button>
                );
              })}
            </motion.div>
          )}

          {/* Bottom Actions */}
          <div className="flex items-center gap-4">
            {/* Reaction Button */}
            <button
              onClick={() => setShowReactions(!showReactions)}
              className={cn(
                "p-3 rounded-full transition-all",
                currentStatus.user_reaction
                  ? "bg-brand-purple-600 scale-110"
                  : "bg-white/10 hover:bg-white/20 hover:scale-110"
              )}
            >
              {currentStatus.user_reaction ? (
                <span className="text-2xl">{currentStatus.user_reaction}</span>
              ) : (
                <Heart className="w-6 h-6 text-white" />
              )}
            </button>

            {/* Comment Button */}
            <button
              onClick={() => setShowComments(!showComments)}
              className="p-3 rounded-full bg-white/10 hover:bg-white/20 transition-all hover:scale-110"
            >
              <Reply className="w-6 h-6 text-white" />
            </button>

            {/* Comment Count */}
            {currentStatus.comments_count > 0 && (
              <span className="text-white text-sm font-semibold">
                {currentStatus.comments_count}
              </span>
            )}

            <div className="flex-1" />

            {/* Send Message Button */}
            <button
              onClick={async () => {
                if (!currentStatus.author || !user || isSendingMessage) return;

                // Can't message yourself
                if (currentStatus.author.id === user.id) {
                  toast.error('You cannot message yourself');
                  return;
                }

                setIsSendingMessage(true);
                try {
                  // Create status message reply record
                  await createStatusMessageReply(currentStatus.id, currentStatus.author.id);

                  // Open messages with this user (messages system will handle creating conversation)
                  openMessages(currentStatus.author.id);

                  toast.success('Opening conversation...');
                  onClose(); // Close status viewer to show messages
                } catch (error: any) {
                  console.error('Failed to create message reply:', error);
                  toast.error(error.message || 'Failed to open conversation');
                } finally {
                  setIsSendingMessage(false);
                }
              }}
              disabled={!currentStatus.author || currentStatus.author.id === user?.id || isSendingMessage}
              className="p-3 rounded-full bg-white/10 hover:bg-white/20 transition-all hover:scale-110 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Send className="w-6 h-6 text-white" />
            </button>
          </div>

          {/* Comment Input (only show when comments sidebar is closed) */}
          {!showComments && (
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-4 flex items-center gap-2"
            >
              {user && (
                <>
                  <Avatar
                    src={user.profile_picture}
                    alt={user.display_name || 'You'}
                    fallback={user.display_name || 'You'}
                    size="sm"
                  />
                  <input
                    type="text"
                    value={commentInput}
                    onChange={(e) => setCommentInput(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && handleComment()}
                    placeholder="Add a comment..."
                    className="flex-1 px-4 py-2 bg-white/10 backdrop-blur-md border border-white/20 rounded-full text-white placeholder-white/50 focus:outline-none focus:ring-2 focus:ring-brand-purple-500"
                    disabled={isReacting}
                    onFocus={() => setIsPaused(true)}
                    onBlur={() => setIsPaused(false)}
                    maxLength={500}
                  />
                  <button
                    onClick={handleComment}
                    disabled={!commentInput.trim() || isReacting}
                    className={cn(
                      "p-2 rounded-full transition-all",
                      commentInput.trim() && !isReacting
                        ? "bg-brand-purple-600 hover:bg-brand-purple-700"
                        : "bg-white/10 opacity-50 cursor-not-allowed"
                    )}
                  >
                    <Send className="w-5 h-5 text-white" />
                  </button>
                </>
              )}
            </motion.div>
          )}
        </div>

        {/* Comments Sidebar */}
        {showComments && (
          <StatusComments
            status={currentStatus}
            comments={comments}
            onClose={() => setShowComments(false)}
            onCommentAdded={(comment) => {
              setComments((prev) => [comment, ...prev]);
              setCurrentStatus((prev) => ({
                ...prev,
                comments_count: prev.comments_count + 1,
              }));
            }}
          />
        )}
      </div>
    </AnimatePresence>
  );
}

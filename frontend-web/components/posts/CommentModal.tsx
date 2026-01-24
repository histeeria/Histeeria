'use client';

import { useState, useEffect, useRef } from 'react';
import { X, Heart, MoreVertical, Reply, Trash2, Edit2, Smile } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { Post, Comment, postsAPI, formatPostTimestamp } from '@/lib/api/posts';
import { Avatar } from '../ui/Avatar';
import VerifiedBadge from '../ui/VerifiedBadge';
import { toast } from '../ui/Toast';
import CommentInput from './CommentInput';
import CommentItem from './CommentItem';
import { useUser } from '@/lib/hooks/useUser';
import NotificationWebSocket from '@/lib/websocket/NotificationWebSocket';

interface CommentModalProps {
  post: Post;
  isOpen: boolean;
  onClose: () => void;
}

export default function CommentModal({ post, isOpen, onClose }: CommentModalProps) {
  const { user } = useUser();
  const [comments, setComments] = useState<Comment[]>([]);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [page, setPage] = useState(0);
  const [replyingTo, setReplyingTo] = useState<Comment | null>(null);
  const [editingComment, setEditingComment] = useState<Comment | null>(null);
  const [showMenu, setShowMenu] = useState<string | null>(null);
  const commentsEndRef = useRef<HTMLDivElement>(null);
  const scrollContainerRef = useRef<HTMLDivElement>(null);

  const limit = 20;

  // Load comments
  const loadComments = async (reset = false) => {
    if (loading) return;
    
    setLoading(true);
    try {
      const currentPage = reset ? 0 : page;
      const response = await postsAPI.getComments(post.id, currentPage, limit);
      
      if (response.success) {
        if (reset) {
          setComments(response.comments);
        } else {
          setComments(prev => [...prev, ...response.comments]);
        }
        setHasMore(response.has_more);
        setPage(currentPage + 1);
      }
    } catch (error: any) {
      console.error('Failed to load comments:', error);
      toast.error('Failed to load comments');
    } finally {
      setLoading(false);
    }
  };

  // Load comments when modal opens
  useEffect(() => {
    if (isOpen) {
      setPage(0);
      setHasMore(true);
      loadComments(true);
      // Prevent body scroll
      document.body.style.overflow = 'hidden';
    } else {
      // Restore body scroll
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [isOpen, post.id]);

  // Scroll to bottom when new comment is added
  useEffect(() => {
    if (commentsEndRef.current && comments.length > 0) {
      commentsEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [comments.length]);

  // WebSocket real-time comment updates
  useEffect(() => {
    if (!isOpen) return;

    const ws = NotificationWebSocket.getInstance();
    
    // Listen for new comments
    const handleNewComment = (data: any) => {
      if (data.type === 'new_comment' && data.comment && data.comment.post_id === post.id) {
        // Add new comment to the list
        setComments(prev => {
          // Check if comment already exists
          const exists = prev.some(c => c.id === data.comment.id);
          if (exists) return prev;
          
          // If it's a reply, add to parent's replies
          if (data.comment.parent_comment_id) {
            return prev.map(comment => {
              if (comment.id === data.comment.parent_comment_id) {
                return {
                  ...comment,
                  replies_count: comment.replies_count + 1,
                  replies: [...(comment.replies || []), data.comment],
                };
              }
              return comment;
            });
          }
          // Otherwise, add as top-level comment
          return [data.comment, ...prev];
        });
      }
    };

    // Listen for comment updates
    const handleCommentUpdate = (data: any) => {
      if (data.type === 'comment_updated' && data.comment && data.post_id === post.id) {
        setComments(prev => updateCommentInList(prev, data.comment));
      }
    };

    // Store unsubscribe functions
    const unsubscribeNewComment = ws.on('new_comment', handleNewComment);
    const unsubscribeCommentUpdate = ws.on('comment_updated', handleCommentUpdate);
    const unsubscribeCommentReply = ws.on('comment_reply', handleNewComment);

    // Cleanup: use the returned unsubscribe functions
    return () => {
      unsubscribeNewComment();
      unsubscribeCommentUpdate();
      unsubscribeCommentReply();
    };
  }, [isOpen, post.id]);

  // Handle scroll for infinite loading
  const handleScroll = () => {
    if (!scrollContainerRef.current || loading || !hasMore) return;
    
    const { scrollTop, scrollHeight, clientHeight } = scrollContainerRef.current;
    if (scrollHeight - scrollTop - clientHeight < 100) {
      loadComments(false);
    }
  };

  // Create comment with optimistic update
  const handleCreateComment = async (content: string) => {
    // Optimistic comment object
    const optimisticComment: Comment = {
      id: `temp-${Date.now()}`,
      post_id: post.id,
      user_id: user?.id || '',
      author: {
        id: user?.id || '',
        username: user?.username || 'you',
        display_name: user?.display_name || user?.username || 'You',
        profile_picture: user?.profile_picture || undefined,
        is_verified: user?.is_verified || false,
      },
      content,
      parent_comment_id: replyingTo?.id || undefined,
      likes_count: 0,
      replies_count: 0,
      is_liked: false,
      is_edited: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      replies: [],
    };

    // Optimistic UI update
    if (replyingTo) {
      setComments(prev => prev.map(comment => {
        if (comment.id === replyingTo.id) {
          return {
            ...comment,
            replies_count: comment.replies_count + 1,
            replies: [...(comment.replies || []), optimisticComment],
          };
        }
        return comment;
      }));
    } else {
      setComments(prev => [optimisticComment, ...prev]);
    }
    
    const previousComments = [...comments];
    setReplyingTo(null);

    try {
      const requestData: any = {
        post_id: post.id,
        content,
      };
      
      if (replyingTo?.id) {
        requestData.parent_comment_id = replyingTo.id;
      }
      
      const response = await postsAPI.createComment(post.id, requestData);

      if (response.success && response.comment) {
        // Replace optimistic comment with real one
        if (replyingTo) {
          setComments(prev => prev.map(comment => {
            if (comment.id === replyingTo.id) {
              return {
                ...comment,
                replies: comment.replies?.map(reply => 
                  reply.id === optimisticComment.id ? response.comment! : reply
                ) || [response.comment!],
              };
            }
            return comment;
          }));
        } else {
          setComments(prev => prev.map(comment => 
            comment.id === optimisticComment.id ? response.comment! : comment
          ));
        }
        toast.success('Comment posted');
      }
    } catch (error: any) {
      console.error('Failed to create comment:', error);
      // Revert optimistic update on error
      setComments(previousComments);
      toast.error('Failed to post comment. Please try again.');
    }
  };

  // Like comment with optimistic update
  const handleLikeComment = async (comment: Comment) => {
    const newLiked = !comment.is_liked;
    const newCount = newLiked ? comment.likes_count + 1 : comment.likes_count - 1;
    
    // Optimistic UI update
    setComments(prev => updateCommentLikes(prev, comment.id, newLiked));

    try {
      await postsAPI.likeComment(comment.id);
    } catch (error: any) {
      console.error('Failed to like comment:', error);
      // Revert on error
      setComments(prev => updateCommentLikes(prev, comment.id, comment.is_liked));
      toast.error('Failed to like comment');
    }
  };

  // Update comment likes in nested structure
  const updateCommentLikes = (commentsList: Comment[], commentId: string, isLiked: boolean): Comment[] => {
    return commentsList.map(comment => {
      if (comment.id === commentId) {
        return {
          ...comment,
          is_liked: isLiked,
          likes_count: isLiked ? comment.likes_count + 1 : comment.likes_count - 1,
        };
      }
      if (comment.replies) {
        return {
          ...comment,
          replies: updateCommentLikes(comment.replies, commentId, isLiked),
        };
      }
      return comment;
    });
  };

  // Delete comment
  const handleDeleteComment = async (comment: Comment) => {
    try {
      await postsAPI.deleteComment(comment.id);
      setComments(prev => removeComment(prev, comment.id));
      setShowMenu(null);
      toast.success('Comment deleted');
    } catch (error: any) {
      console.error('Failed to delete comment:', error);
      toast.error('Failed to delete comment');
    }
  };

  // Remove comment from nested structure
  const removeComment = (commentsList: Comment[], commentId: string): Comment[] => {
    return commentsList
      .filter(comment => comment.id !== commentId)
      .map(comment => {
        if (comment.replies) {
          return {
            ...comment,
            replies: removeComment(comment.replies, commentId),
            replies_count: comment.replies.filter(r => r.id !== commentId).length,
          };
        }
        return comment;
      });
  };

  // Update comment
  const handleUpdateComment = async (comment: Comment, newContent: string) => {
    try {
      const response = await postsAPI.updateComment(comment.id, newContent);
      if (response.success && response.comment) {
        // Use the updated comment from the server response
        setComments(prev => updateCommentInList(prev, response.comment!));
        setEditingComment(null);
        toast.success('Comment updated');
      } else {
        toast.error(response.message || 'Failed to update comment');
      }
    } catch (error: any) {
      console.error('Failed to update comment:', error);
      toast.error('Failed to update comment');
    }
  };

  // Update comment in nested structure using server response
  const updateCommentInList = (commentsList: Comment[], updatedComment: Comment): Comment[] => {
    return commentsList.map(comment => {
      if (comment.id === updatedComment.id) {
        return updatedComment;
      }
      if (comment.replies) {
        return {
          ...comment,
          replies: updateCommentInList(comment.replies, updatedComment),
        };
      }
      return comment;
    });
  };

  // Load replies for a comment
  const loadReplies = async (comment: Comment) => {
    if (comment.replies && comment.replies.length > 0) return; // Already loaded
    
    try {
      const response = await postsAPI.getComments(post.id, 0, 50);
      if (response.success) {
        const replies = response.comments.filter(c => c.parent_comment_id === comment.id);
        setComments(prev => prev.map(c => {
          if (c.id === comment.id) {
            return { ...c, replies };
          }
          return c;
        }));
      }
    } catch (error) {
      console.error('Failed to load replies:', error);
    }
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[300] flex items-end justify-center">
        {/* Backdrop */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
          className="absolute inset-0 bg-black/60"
          onClick={onClose}
        />

        {/* Modal Content - Instagram Style Bottom Sheet */}
        <motion.div
          initial={{ y: '100%' }}
          animate={{ y: 0 }}
          exit={{ y: '100%' }}
          transition={{ type: 'spring', damping: 30, stiffness: 300 }}
          className="relative
            w-full h-[85vh] md:h-[90vh] md:max-w-2xl
            bg-white dark:bg-neutral-950
            flex flex-col overflow-hidden
            rounded-t-3xl md:rounded-t-3xl
          "
          onClick={(e) => e.stopPropagation()}
        >
          {/* Drag Handle */}
          <div className="flex justify-center pt-2 pb-1 flex-shrink-0">
            <div className="w-12 h-1 bg-neutral-300 dark:bg-neutral-700 rounded-full" />
          </div>

          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3 border-b border-neutral-200 dark:border-neutral-800 flex-shrink-0">
            <h2 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
              Comments
            </h2>
            <button
              onClick={onClose}
              className="p-1 transition-opacity"
            >
              <X className="w-5 h-5 text-neutral-900 dark:text-neutral-50" />
            </button>
          </div>

          {/* Post Preview */}
          <div className="px-4 py-3 border-b border-neutral-200 dark:border-neutral-800 flex items-center gap-3 flex-shrink-0">
            <Avatar
              src={post.author?.profile_picture}
              alt={post.author?.display_name || post.author?.username || 'User'}
              fallback={post.author?.display_name || post.author?.username || 'U'}
              size="sm"
              className="flex-shrink-0"
            />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1.5 mb-0.5">
                <span className="text-sm font-semibold text-neutral-900 dark:text-neutral-50">
                  {post.author?.display_name || post.author?.username}
                </span>
                {post.author?.is_verified && (
                  <VerifiedBadge size="sm" variant="badge" showText={false} />
                )}
              </div>
              <p className="text-sm text-neutral-900 dark:text-neutral-50 line-clamp-2">
                {post.content}
              </p>
            </div>
          </div>

          {/* Comments List */}
          <div
            ref={scrollContainerRef}
            onScroll={handleScroll}
            className="flex-1 overflow-y-auto px-4 py-4 space-y-4"
          >
            {comments.length === 0 && !loading ? (
              <div className="flex flex-col items-center justify-center h-full text-center py-12">
                <p className="text-neutral-500 dark:text-neutral-400 mb-1 font-medium">No comments yet</p>
                <p className="text-sm text-neutral-400 dark:text-neutral-500">
                  Be the first to comment!
                </p>
              </div>
            ) : (
              <>
                {comments
                  .filter(c => !c.parent_comment_id) // Only show top-level comments
                  .map((comment) => (
                    <div key={comment.id}>
                      <CommentItem
                        comment={comment}
                        currentUserId={user?.id}
                        onLike={() => handleLikeComment(comment)}
                        onReply={() => setReplyingTo(comment)}
                        onEdit={() => setEditingComment(comment)}
                        onDelete={() => handleDeleteComment(comment)}
                        onLoadReplies={() => loadReplies(comment)}
                        showMenu={showMenu}
                        onToggleMenu={(commentId) => setShowMenu(showMenu === commentId ? null : commentId)}
                        depth={0}
                      />
                    </div>
                  ))}
                {loading && (
                  <div className="text-center py-6">
                    <div className="inline-block w-5 h-5 border-2 border-neutral-300 dark:border-neutral-600 border-t-transparent rounded-full animate-spin" />
                  </div>
                )}
                <div ref={commentsEndRef} />
              </>
            )}
          </div>

          {/* Comment Input Footer - Fixed at Bottom */}
          <div className="border-t border-neutral-200 dark:border-neutral-800 flex-shrink-0 bg-white dark:bg-neutral-950">
            {replyingTo && (
              <div className="px-4 py-2 flex items-center justify-between border-b border-neutral-200 dark:border-neutral-800">
                <div className="flex items-center gap-2 flex-1 min-w-0">
                  <Reply className="w-4 h-4 text-neutral-500 dark:text-neutral-400 flex-shrink-0" />
                  <span className="text-xs text-neutral-500 dark:text-neutral-400 truncate">
                    Replying to <span className="font-semibold text-neutral-900 dark:text-neutral-50">{replyingTo.author?.display_name || replyingTo.author?.username}</span>
                  </span>
                </div>
                <button
                  onClick={() => setReplyingTo(null)}
                  className="p-1 transition-opacity"
                >
                  <X className="w-4 h-4 text-neutral-500 dark:text-neutral-400" />
                </button>
              </div>
            )}
            <div className="relative">
              <CommentInput
                onSubmit={handleCreateComment}
                onCancel={() => {
                  setReplyingTo(null);
                  setEditingComment(null);
                }}
                editingComment={editingComment}
                onUpdate={(newContent) => editingComment && handleUpdateComment(editingComment, newContent)}
                placeholder={replyingTo ? `Reply to ${replyingTo.author?.display_name || replyingTo.author?.username}...` : 'Add a comment...'}
              />
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}



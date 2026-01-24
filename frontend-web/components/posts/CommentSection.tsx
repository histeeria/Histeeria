'use client';

import { useState, useEffect, useRef } from 'react';
import { motion } from 'framer-motion';
import { Post, Comment, postsAPI } from '@/lib/api/posts';
import { toast } from '../ui/Toast';
import CommentInput from './CommentInput';
import CommentItem from './CommentItem';
import { useUser } from '@/lib/hooks/useUser';
import NotificationWebSocket from '@/lib/websocket/NotificationWebSocket';
import { Loader2, X } from 'lucide-react';

interface CommentSectionProps {
  post: Post;
  showInput?: boolean;
  maxHeight?: string;
}

export default function CommentSection({ 
  post, 
  showInput = true,
  maxHeight = '600px'
}: CommentSectionProps) {
  const { user } = useUser();
  const [comments, setComments] = useState<Comment[]>([]);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [page, setPage] = useState(0);
  const [replyingTo, setReplyingTo] = useState<Comment | null>(null);
  const [editingComment, setEditingComment] = useState<Comment | null>(null);
  const [showMenu, setShowMenu] = useState<string | null>(null);
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

  // Load comments on mount
  useEffect(() => {
    loadComments(true);
  }, [post.id]);

  // WebSocket real-time comment updates
  useEffect(() => {
    const ws = NotificationWebSocket.getInstance();
    
    const handleNewComment = (data: any) => {
      if (data.type === 'new_comment' && data.comment && data.comment.post_id === post.id) {
        const exists = comments.some(c => c.id === data.comment.id);
        if (exists) return;
        
        if (data.comment.parent_comment_id) {
          setComments(prev => prev.map(comment => {
            if (comment.id === data.comment.parent_comment_id) {
              return {
                ...comment,
                replies_count: comment.replies_count + 1,
                replies: [...(comment.replies || []), data.comment],
              };
            }
            return comment;
          }));
        } else {
          setComments(prev => [data.comment, ...prev]);
        }
      }
    };

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
  }, [post.id, comments.length]);

  // Handle scroll for infinite loading
  const handleScroll = () => {
    if (!scrollContainerRef.current || loading || !hasMore) return;
    
    const { scrollTop, scrollHeight, clientHeight } = scrollContainerRef.current;
    if (scrollHeight - scrollTop - clientHeight < 100) {
      loadComments(false);
    }
  };

  // Create comment
  const handleCreateComment = async (content: string) => {
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
        if (replyingTo) {
          setComments(prev => prev.map(comment => {
            if (comment.id === replyingTo.id) {
              return {
                ...comment,
                replies_count: comment.replies_count + 1,
                replies: [...(comment.replies || []), response.comment!],
              };
            }
            return comment;
          }));
        } else {
          setComments(prev => [response.comment!, ...prev]);
        }
        setReplyingTo(null);
        toast.success('Comment posted');
      }
    } catch (error: any) {
      console.error('Failed to create comment:', error);
      toast.error('Failed to post comment');
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

  // Update comment likes
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

  // Remove comment
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

  // Update comment in list
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

  // Load replies
  const loadReplies = async (comment: Comment) => {
    if (comment.replies && comment.replies.length > 0) return;
    
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

  return (
    <div className="w-full">
      {/* Comments List */}
      <div
        ref={scrollContainerRef}
        onScroll={handleScroll}
        className="overflow-y-auto px-4 py-2 space-y-1"
        style={{ maxHeight }}
      >
        {comments.length === 0 && !loading ? (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex flex-col items-center justify-center py-12 text-center"
          >
            <p className="text-neutral-500 dark:text-neutral-400 mb-2 font-medium">No comments yet</p>
            <p className="text-sm text-neutral-400 dark:text-neutral-500">
              Be the first to comment!
            </p>
          </motion.div>
        ) : (
          <>
            {comments
              .filter(c => !c.parent_comment_id)
              .map((comment, index) => (
                <motion.div
                  key={comment.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: index * 0.05, duration: 0.3 }}
                >
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
                </motion.div>
              ))}
            {loading && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="flex justify-center py-6"
              >
                <Loader2 className="w-5 h-5 animate-spin text-purple-600" />
              </motion.div>
            )}
          </>
        )}
      </div>

      {/* Comment Input */}
      {showInput && (
        <div className="border-t border-neutral-200 dark:border-neutral-800 pt-2 mt-2">
          {replyingTo && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="px-4 py-2 mb-1
                bg-neutral-50 dark:bg-neutral-800/50
                flex items-center justify-between
              "
            >
              <div className="flex items-center gap-2 flex-1 min-w-0">
                <span className="text-xs text-neutral-600 dark:text-neutral-400 truncate">
                  Replying to <span className="font-semibold">{replyingTo.author?.display_name || replyingTo.author?.username}</span>
                </span>
              </div>
              <button
                onClick={() => setReplyingTo(null)}
                className="p-1 hover:opacity-70 transition-opacity"
              >
                <X className="w-3 h-3 text-neutral-400 dark:text-neutral-500" />
              </button>
            </motion.div>
          )}
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
      )}
    </div>
  );
}


'use client';

import { useState, useEffect, useCallback } from 'react';
import { Loader2, RefreshCw } from 'lucide-react';
import { Post, postsAPI } from '@/lib/api/posts';
import PostCard from './PostCard';
import CommentModal from './CommentModal';
import { toast } from '../ui/Toast';
import NotificationWebSocket from '@/lib/websocket/NotificationWebSocket';

interface FeedContainerProps {
  feedType?: 'home' | 'following' | 'explore' | 'saved';
  userId?: string;
  hashtag?: string;
}

export default function FeedContainer({ feedType = 'home', userId, hashtag }: FeedContainerProps) {
  const [posts, setPosts] = useState<Post[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedPostForComment, setSelectedPostForComment] = useState<Post | null>(null);

  // Load initial feed
  useEffect(() => {
    loadFeed(true);
  }, [feedType, hashtag]);

  // WebSocket real-time updates
  useEffect(() => {
    const ws = NotificationWebSocket.getInstance();
    
    // Listen for new posts
    const handleNewPost = (data: any) => {
      if (data.type === 'new_post' && data.post) {
        // Add new post to the top of the feed
        setPosts(prev => [data.post, ...prev]);
        toast.success('New post available');
      }
    };

    // Listen for post updates (likes, comments, etc.)
    const handlePostUpdate = (data: any) => {
      if (data.type === 'post_liked' && data.post_id) {
        setPosts(prev => prev.map(post => 
          post.id === data.post_id 
            ? { ...post, likes_count: data.likes_count || post.likes_count, is_liked: data.liker_id ? true : post.is_liked }
            : post
        ));
      }
    };

    // Store unsubscribe functions
    const unsubscribeNewPost = ws.on('new_post', handleNewPost);
    const unsubscribePostLiked = ws.on('post_liked', handlePostUpdate);
    const unsubscribePostUpdated = ws.on('post_updated', handlePostUpdate);

    // Cleanup: use the returned unsubscribe functions
    return () => {
      unsubscribeNewPost();
      unsubscribePostLiked();
      unsubscribePostUpdated();
    };
  }, []);

  const loadFeed = async (reset = false) => {
    if (reset) {
      setIsLoading(true);
      setPage(0);
      setPosts([]);
    } else {
      setIsLoadingMore(true);
    }

    setError(null);

    try {
      const currentPage = reset ? 0 : page;
      let response;

      switch (feedType) {
        case 'home':
          response = await postsAPI.getHomeFeed(currentPage, 20);
          break;
        case 'following':
          response = await postsAPI.getFollowingFeed(currentPage, 20);
          break;
        case 'explore':
          response = await postsAPI.getExploreFeed(currentPage, 20);
          break;
        case 'saved':
          response = await postsAPI.getSavedPosts('Saved', currentPage, 20);
          break;
        default:
          response = await postsAPI.getHomeFeed(currentPage, 20);
      }

      if (response.success) {
        if (reset) {
          setPosts(response.posts);
        } else {
          setPosts(prev => [...prev, ...response.posts]);
        }
        
        setHasMore(response.has_more);
        setPage(currentPage + 1);
      }
    } catch (error) {
      console.error('Failed to load feed:', error);
      setError('Failed to load posts');
      toast.error('Failed to load feed');
    } finally {
      setIsLoading(false);
      setIsLoadingMore(false);
    }
  };

  const handleScroll = useCallback(() => {
    if (isLoadingMore || !hasMore) return;

    const scrollPosition = window.innerHeight + window.scrollY;
    const threshold = document.documentElement.scrollHeight - 500;

    if (scrollPosition >= threshold) {
      loadFeed(false);
    }
  }, [isLoadingMore, hasMore, page]);

  useEffect(() => {
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, [handleScroll]);

  const handleRefresh = () => {
    loadFeed(true);
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="w-8 h-8 animate-spin text-purple-600" />
      </div>
    );
  }

  if (error && posts.length === 0) {
    return (
      <div className="text-center py-20">
        <p className="text-neutral-600 dark:text-neutral-400 mb-4">{error}</p>
        <button
          onClick={handleRefresh}
          className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors"
        >
          Try Again
        </button>
      </div>
    );
  }

  if (posts.length === 0) {
    return (
      <div className="text-center py-20">
        <div className="w-20 h-20 mx-auto mb-4 border border-neutral-200 dark:border-neutral-800 rounded-full flex items-center justify-center">
          <span className="text-4xl">📝</span>
        </div>
        <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
          No posts yet
        </h3>
        <p className="text-neutral-600 dark:text-neutral-400">
          Be the first to share something!
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-0">
      {/* Posts */}
      {posts.map((post) => (
        <PostCard 
          key={post.id} 
          post={post}
          onComment={(p) => setSelectedPostForComment(p)}
          onShare={(p) => {
            if (p.post_type === 'article' && p.article?.slug) {
              const url = `${window.location.origin}/articles/${p.article.slug}`;
              if (navigator.share) {
                navigator.share({
                  title: p.article.title,
                  text: p.article.subtitle || p.article.meta_description || '',
                  url: url,
                }).catch(() => {});
              } else {
                navigator.clipboard.writeText(url);
                toast.success('Link copied to clipboard');
              }
            } else {
              const url = `${window.location.origin}/posts/${p.id}`;
              if (navigator.share) {
                navigator.share({
                  title: 'Check out this post',
                  text: p.content.substring(0, 100),
                  url: url,
                }).catch(() => {});
              } else {
                navigator.clipboard.writeText(url);
                toast.success('Link copied to clipboard');
              }
            }
          }}
          onSave={async (p) => {
            try {
              if (p.is_saved) {
                await postsAPI.unsavePost(p.id);
                setPosts(prev => prev.map(post => 
                  post.id === p.id ? { ...post, is_saved: false } : post
                ));
                toast.success('Removed from saved');
              } else {
                await postsAPI.savePost(p.id);
                setPosts(prev => prev.map(post => 
                  post.id === p.id ? { ...post, is_saved: true } : post
                ));
                toast.success('Saved');
              }
            } catch (error: any) {
              toast.error(error.message || 'Failed to update save status');
            }
          }}
        />
      ))}

      {/* Comment Modal */}
      {selectedPostForComment && (
        <CommentModal
          post={selectedPostForComment}
          isOpen={!!selectedPostForComment}
          onClose={() => {
            setSelectedPostForComment(null);
            // Refresh feed to show updated comment counts
            loadFeed(true);
          }}
        />
      )}

      {/* Load More Indicator */}
      {isLoadingMore && (
        <div className="flex justify-center py-6">
          <Loader2 className="w-6 h-6 animate-spin text-purple-600" />
        </div>
      )}

      {/* End of Feed */}
      {!hasMore && posts.length > 0 && (
        <div className="text-center py-6 text-neutral-500 dark:text-neutral-400 text-sm">
          You've reached the end
        </div>
      )}
    </div>
  );
}


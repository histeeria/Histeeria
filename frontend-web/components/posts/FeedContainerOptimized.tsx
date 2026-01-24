'use client';

/**
 * Optimized Feed Container
 * Uses React Query + IndexedDB caching + Virtual Scrolling
 */

import { useState, useEffect, useRef, useCallback } from 'react';
import { useInfiniteQuery, useQueryClient, useMutation } from '@tanstack/react-query';
import { useVirtualizer } from '@tanstack/react-virtual';
import { Post, postsAPI } from '@/lib/api/posts';
import PostCard from './PostCard';
import CommentModal from './CommentModal';
import { FeedSkeleton } from '@/components/ui/Skeleton';
import { toast } from '../ui/Toast';
import NotificationWebSocket from '@/lib/websocket/NotificationWebSocket';
import { getFeedCache, setFeedCache, clearFeedCache } from '@/lib/cache/indexedDB';
import { usePullToRefresh } from '@/lib/hooks/usePullToRefresh';
import { RefreshCw, AlertCircle } from 'lucide-react';
import { Button } from '../ui/Button';

interface FeedContainerProps {
  feedType?: 'home' | 'following' | 'explore' | 'saved';
  userId?: string;
  hashtag?: string;
}

export default function FeedContainerOptimized({ 
  feedType = 'home', 
  userId, 
  hashtag 
}: FeedContainerProps) {
  const [selectedPostForComment, setSelectedPostForComment] = useState<Post | null>(null);
  const [allPosts, setAllPosts] = useState<Post[]>([]);
  const parentRef = useRef<HTMLDivElement>(null);
  const queryClient = useQueryClient();

  // Fetch feed with React Query + IndexedDB caching
  const {
    data: feedData,
    isLoading,
    isFetching,
    error,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    refetch,
  } = useInfiniteQuery({
    queryKey: ['feed', feedType, userId, hashtag] as const,
    queryFn: async ({ pageParam = 0 }: { pageParam: number }): Promise<{ success: boolean; posts: Post[]; has_more: boolean }> => {
      // Try IndexedDB cache first
      const cacheKey = `feed:${feedType}:${userId || ''}:${hashtag || ''}:page:${pageParam}`;
      const cached = await getFeedCache(cacheKey);
      
      if (cached && pageParam === 0) {
        // Return cached data immediately, but still fetch fresh data
        return cached;
      }

      // Fetch from API
      let response;
      switch (feedType) {
        case 'home':
          response = await postsAPI.getHomeFeed(pageParam, 20);
          break;
        case 'following':
          response = await postsAPI.getFollowingFeed(pageParam, 20);
          break;
        case 'explore':
          response = await postsAPI.getExploreFeed(pageParam, 20);
          break;
        case 'saved':
          response = await postsAPI.getSavedPosts('Saved', pageParam, 20);
          break;
        default:
          response = await postsAPI.getHomeFeed(pageParam, 20);
      }

      if (response.success) {
        // Cache the response
        await setFeedCache(cacheKey, response, 5 * 60 * 1000); // 5 min TTL
        return response;
      }

      throw new Error('Failed to load feed');
    },
    getNextPageParam: (lastPage: { success: boolean; posts: Post[]; has_more: boolean }, allPages: { success: boolean; posts: Post[]; has_more: boolean }[]) => {
      if (lastPage?.has_more) {
        // Return next page number (current pages length)
        return allPages.length;
      }
      return undefined;
    },
    initialPageParam: 0,
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes
  } as any); // Type assertion needed due to React Query v5 type definition issues

  // Flatten all pages into single array
  useEffect(() => {
    if (feedData?.pages) {
      const posts = (feedData.pages as Array<{ success: boolean; posts: Post[]; has_more: boolean }>).flatMap((page) => page.posts || []);
      setAllPosts(posts);
    }
  }, [feedData]);

  // Virtual scrolling
  const virtualizer = useVirtualizer({
    count: allPosts.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 500, // Estimated post height
    overscan: 5, // Render 5 extra items
  });

  // Load more when scrolling near bottom
  useEffect(() => {
    const [lastItem] = [...virtualizer.getVirtualItems()].reverse();
    if (!lastItem) return;

    if (
      lastItem.index >= allPosts.length - 1 &&
      hasNextPage &&
      !isFetchingNextPage
    ) {
      fetchNextPage();
    }
  }, [
    hasNextPage,
    fetchNextPage,
    isFetchingNextPage,
    virtualizer.getVirtualItems(),
    allPosts.length,
  ]);

  // WebSocket real-time updates
  useEffect(() => {
    const ws = NotificationWebSocket.getInstance();
    
    const handleNewPost = (data: any) => {
      if (data.type === 'new_post' && data.post) {
        setAllPosts(prev => [data.post, ...prev]);
        toast.success('New post available');
        
        // Invalidate cache to refresh
        queryClient.invalidateQueries({ queryKey: ['feed', feedType] });
      }
    };

    const handlePostUpdate = (data: any) => {
      if (data.type === 'post_liked' && data.post_id) {
        setAllPosts(prev => prev.map(post => 
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
  }, [feedType, queryClient]);

  const handleRefresh = useCallback(async () => {
    // Clear cache and refetch
    await clearFeedCache(`feed:${feedType}:${userId || ''}:${hashtag || ''}:*`);
    await refetch();
  }, [feedType, userId, hashtag, refetch]);

  // Pull-to-refresh
  const { isPulling, pullDistance, isRefreshing: isPTRRefreshing, pullProgress } = usePullToRefresh({
    onRefresh: handleRefresh,
    enabled: true,
    threshold: 80,
  });

  if (isLoading) {
    return <FeedSkeleton count={3} />;
  }

  // Error with retry
  if (error && allPosts.length === 0) {
    return (
      <div className="text-center py-20 px-4">
        <div className="flex justify-center mb-4">
          <AlertCircle className="w-12 h-12 text-red-500" />
        </div>
        <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
          Failed to load feed
        </h3>
        <p className="text-neutral-600 dark:text-neutral-400 mb-6">
          {error instanceof Error ? error.message : 'Something went wrong. Please try again.'}
        </p>
        <Button
          onClick={handleRefresh}
          variant="solid"
          className="flex items-center gap-2 mx-auto"
        >
          <RefreshCw className="w-4 h-4" />
          Retry
        </Button>
      </div>
    );
  }

  const virtualItems = virtualizer.getVirtualItems();
  const totalSize = virtualizer.getTotalSize();
  const paddingTop = virtualItems.length > 0 ? virtualItems[0]?.start ?? 0 : 0;
  const paddingBottom =
    virtualItems.length > 0
      ? totalSize - (virtualItems[virtualItems.length - 1]?.end ?? 0)
      : 0;

  return (
    <>
      {/* Pull-to-refresh indicator */}
      {isPulling && (
        <div 
          className="fixed top-0 left-1/2 transform -translate-x-1/2 z-50 transition-all duration-300"
          style={{ 
            transform: `translate(-50%, ${Math.max(0, pullDistance - 40)}px)`,
            opacity: pullProgress,
          }}
        >
          <div className="flex items-center gap-2 px-4 py-2 bg-white dark:bg-neutral-900 rounded-full shadow-lg border border-neutral-200 dark:border-neutral-800">
            <RefreshCw 
              className={`w-5 h-5 text-purple-600 ${pullProgress >= 1 ? 'animate-spin' : ''}`}
              style={{ transform: `rotate(${pullDistance * 2}deg)` }}
            />
            <span className="text-sm font-medium text-neutral-900 dark:text-neutral-50">
              {pullProgress >= 1 ? 'Release to refresh' : 'Pull to refresh'}
            </span>
          </div>
        </div>
      )}

      {(isFetching || isPTRRefreshing) && allPosts.length > 0 && !isLoading && (
        <div className="flex items-center justify-center py-2 text-sm text-neutral-600 dark:text-neutral-400">
          <RefreshCw className="w-4 h-4 animate-spin mr-2" />
          Refreshing...
        </div>
      )}

      <div
        ref={parentRef}
        className="h-[calc(100vh-200px)] overflow-auto"
        style={{ 
          contain: 'strict',
          transform: isPulling ? `translateY(${Math.min(pullDistance, 80)}px)` : 'translateY(0)',
          transition: isPulling ? 'none' : 'transform 0.3s ease-out',
        }}
      >
        <div style={{ paddingTop, paddingBottom }}>
          {virtualItems.map((virtualItem) => {
            const post = allPosts[virtualItem.index];
            if (!post) return null;

            return (
              <div
                key={virtualItem.key}
                data-index={virtualItem.index}
                ref={virtualizer.measureElement}
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  width: '100%',
                  transform: `translateY(${virtualItem.start}px)`,
                }}
              >
                <PostCard
                  post={post}
                  onComment={() => setSelectedPostForComment(post)}
                  onShare={() => {}}
                  onSave={() => {}}
                />
              </div>
            );
          })}
        </div>
        
        {isFetchingNextPage && (
          <div className="flex justify-center py-4">
            <div className="text-neutral-600 dark:text-neutral-400">Loading more...</div>
          </div>
        )}
      </div>

      {selectedPostForComment && (
        <CommentModal
          post={selectedPostForComment}
          isOpen={true}
          onClose={() => setSelectedPostForComment(null)}
        />
      )}
    </>
  );
}

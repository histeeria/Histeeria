'use client';

/**
 * Activity Archived Page - Enhanced
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Shows user's archived/deleted posts with error boundaries, caching, and skeletons
 */

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { ErrorBoundary } from '@/components/errors/ErrorBoundary';
import { MainLayout } from '@/components/layout/MainLayout';
import { FeedSkeleton } from '@/components/ui/Skeleton';
import { Loader2, Trash2, Archive, ArrowLeft, RotateCcw, Clock, AlertCircle, RefreshCw } from 'lucide-react';
import { Post, postsAPI, formatPostTimestamp } from '@/lib/api/posts';
import PostCard from '@/components/posts/PostCard';
import CommentModal from '@/components/posts/CommentModal';
import { toast } from '@/components/ui/Toast';
import { Button } from '@/components/ui/Button';
import { useInfiniteQuery } from '@tanstack/react-query';

function ArchivedPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const filter = (searchParams.get('filter') || 'deleted') as 'deleted' | 'archived';
  
  const [selectedPostForComment, setSelectedPostForComment] = useState<Post | null>(null);

  // Use React Query for data fetching with caching
  const {
    data: archivedData,
    isLoading,
    isFetchingNextPage,
    error,
    fetchNextPage,
    hasNextPage,
    refetch,
  } = useInfiniteQuery({
    queryKey: ['activity', 'archived', filter] as const,
    queryFn: async ({ pageParam = 0 }: { pageParam: number }) => {
      const response = await postsAPI.getUserArchived(filter, pageParam, 20);
      if (!response.success) {
        throw new Error('Failed to load archived posts');
      }
      return response;
    },
    getNextPageParam: (lastPage: any, allPages: any[]) => {
      if (lastPage?.has_more) {
        return allPages.length;
      }
      return undefined;
    },
    initialPageParam: 0,
    staleTime: 10 * 60 * 1000, // 10 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes
  } as any);

  // Flatten posts from all pages
  const posts = archivedData?.pages.flatMap((page: any) => page.posts || []) || [];

  // Load more on scroll
  useEffect(() => {
    const handleScroll = () => {
      if (isFetchingNextPage || !hasNextPage) return;
      const scrollPosition = window.innerHeight + window.scrollY;
      const threshold = document.documentElement.scrollHeight - 500;
      if (scrollPosition >= threshold) {
        fetchNextPage();
      }
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, [isFetchingNextPage, hasNextPage, fetchNextPage]);

  const handleSave = async (post: Post) => {
    try {
      if (post.is_saved) {
        await postsAPI.unsavePost(post.id);
        toast.success('Removed from saved');
      } else {
        await postsAPI.savePost(post.id);
        toast.success('Saved');
      }
      refetch();
    } catch (error: any) {
      toast.error(error.message || 'Failed to update save status');
    }
  };

  const handleShare = (post: Post) => {
    if (post.post_type === 'article' && post.article?.slug) {
      const url = `${window.location.origin}/articles/${post.article.slug}`;
      if (navigator.share) {
        navigator.share({
          title: post.article.title,
          text: post.article.subtitle || post.article.meta_description || '',
          url: url,
        }).catch(() => {});
      } else {
        navigator.clipboard.writeText(url);
        toast.success('Link copied to clipboard');
      }
    } else {
      const url = `${window.location.origin}/posts/${post.id}`;
      if (navigator.share) {
        navigator.share({
          title: 'Check out this post',
          text: post.content.substring(0, 100),
          url: url,
        }).catch(() => {});
      } else {
        navigator.clipboard.writeText(url);
        toast.success('Link copied to clipboard');
      }
    }
  };

  const handleRestore = async (post: Post) => {
    // TODO: Implement restore functionality when backend endpoint is available
    toast.info('Restore functionality coming soon');
  };

  if (isLoading) {
    return (
      <MainLayout>
        <FeedSkeleton count={5} />
      </MainLayout>
    );
  }

  if (error && posts.length === 0) {
    return (
      <MainLayout>
        <div className="text-center py-20">
          <div className="flex justify-center mb-4">
            <AlertCircle className="w-12 h-12 text-red-500" />
          </div>
          <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
            Failed to load {filter === 'deleted' ? 'deleted' : 'archived'} posts
          </h3>
          <p className="text-neutral-600 dark:text-neutral-400 mb-6">
            {error instanceof Error ? error.message : 'Something went wrong. Please try again.'}
          </p>
          <Button
            onClick={() => refetch()}
            variant="solid"
            className="flex items-center gap-2 mx-auto"
            aria-label="Retry loading archived posts"
          >
            <RefreshCw className="w-4 h-4" />
            Retry
          </Button>
        </div>
      </MainLayout>
    );
  }

  return (
    <MainLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center gap-4">
          <button
            onClick={() => router.back()}
            className="p-2 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-full transition-colors"
            aria-label="Go back"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <h1 className="text-2xl md:text-3xl font-bold text-neutral-900 dark:text-neutral-50">
              {filter === 'deleted' ? 'Recently deleted' : 'Archived'}
            </h1>
            <p className="text-sm text-neutral-600 dark:text-neutral-400 mt-1">
              {filter === 'deleted' 
                ? 'Posts deleted in the last 30 days'
                : 'Posts you\'ve archived'}
            </p>
          </div>
        </div>

        {/* Filter Tabs */}
        <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-1 -mx-4 px-4 md:mx-0 md:px-0">
          {[
            { id: 'deleted' as const, label: 'Recently deleted', icon: Trash2 },
            { id: 'archived' as const, label: 'Archived', icon: Archive },
          ].map((tab) => {
            const Icon = tab.icon;
            const isActive = filter === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => router.push(`/activity/archived?filter=${tab.id}`)}
                className={`px-4 py-2 rounded-full text-sm font-semibold whitespace-nowrap transition-all duration-200 flex-shrink-0 flex items-center gap-2 ${
                  isActive
                    ? 'bg-purple-600 text-white shadow-md'
                    : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
                }`}
                aria-label={`Filter by ${tab.label}`}
                aria-pressed={isActive}
              >
                <Icon className="w-4 h-4" />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>

        {/* Empty State */}
        {posts.length === 0 && (
          <div className="text-center py-20">
            <div className="w-20 h-20 mx-auto mb-4 bg-neutral-100 dark:bg-neutral-800 rounded-full flex items-center justify-center">
              {filter === 'deleted' ? (
                <Trash2 className="w-10 h-10 text-neutral-400" />
              ) : (
                <Archive className="w-10 h-10 text-neutral-400" />
              )}
            </div>
            <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
              No {filter === 'deleted' ? 'deleted' : 'archived'} posts
            </h3>
            <p className="text-neutral-600 dark:text-neutral-400 mb-6">
              {filter === 'deleted' 
                ? 'Posts you delete will appear here for 30 days'
                : 'Posts you archive will appear here'}
            </p>
            <button
              onClick={() => router.push('/home')}
              className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors"
              aria-label="Go to feed"
            >
              Go to Feed
            </button>
          </div>
        )}

        {/* Posts List */}
        {posts.length > 0 && (
          <div className="space-y-6">
            {posts.map((post) => (
              <div key={post.id} className="relative">
                {/* Deleted Badge */}
                {filter === 'deleted' && post.deleted_at && (
                  <div className="mb-2 flex items-center gap-2 text-xs text-neutral-500 dark:text-neutral-400">
                    <Clock className="w-3 h-3" />
                    <span>Deleted {formatPostTimestamp(post.deleted_at)}</span>
                    {(() => {
                      const deletedDate = new Date(post.deleted_at);
                      const daysSinceDeleted = Math.floor((Date.now() - deletedDate.getTime()) / (1000 * 60 * 60 * 24));
                      const daysRemaining = 30 - daysSinceDeleted;
                      return daysRemaining > 0 ? (
                        <span className="text-orange-500">• {daysRemaining} days until permanent deletion</span>
                      ) : null;
                    })()}
                  </div>
                )}
                
                <PostCard 
                  post={post}
                  onComment={(p) => setSelectedPostForComment(p)}
                  onShare={handleShare}
                  onSave={handleSave}
                />
                
                {/* Restore Button (for deleted posts) */}
                {filter === 'deleted' && (
                  <div className="mt-2 flex justify-end">
                    <button
                      onClick={() => handleRestore(post)}
                      className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-purple-600 dark:text-purple-400 hover:bg-purple-50 dark:hover:bg-purple-900/20 rounded-lg transition-colors"
                      aria-label={`Restore post ${post.id}`}
                    >
                      <RotateCcw className="w-4 h-4" />
                      Restore
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {/* Comment Modal */}
        {selectedPostForComment && (
          <CommentModal
            post={selectedPostForComment}
            isOpen={!!selectedPostForComment}
            onClose={() => {
              setSelectedPostForComment(null);
              refetch();
            }}
          />
        )}

        {/* Load More Indicator */}
        {isFetchingNextPage && (
          <div className="flex justify-center py-6">
            <Loader2 className="w-6 h-6 animate-spin text-purple-600" />
          </div>
        )}

        {/* End of Feed */}
        {!hasNextPage && posts.length > 0 && (
          <div className="text-center py-6 text-neutral-500 dark:text-neutral-400 text-sm">
            You've reached the end
          </div>
        )}
      </div>
    </MainLayout>
  );
}

export default function ArchivedPage() {
  return (
    <ErrorBoundary>
      <ArchivedPageContent />
    </ErrorBoundary>
  );
}
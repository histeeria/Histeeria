'use client';

/**
 * Activity Shared Page - Enhanced
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Shows user's shared posts and articles with error boundaries, caching, and skeletons
 */

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { ErrorBoundary } from '@/components/errors/ErrorBoundary';
import { MainLayout } from '@/components/layout/MainLayout';
import { FeedSkeleton } from '@/components/ui/Skeleton';
import { Loader2, Share2, ArrowLeft, Grid3x3, Newspaper, Video, Briefcase, AlertCircle, RefreshCw } from 'lucide-react';
import { Post, postsAPI } from '@/lib/api/posts';
import PostCard from '@/components/posts/PostCard';
import CommentModal from '@/components/posts/CommentModal';
import { toast } from '@/components/ui/Toast';
import { Button } from '@/components/ui/Button';
import { useInfiniteQuery } from '@tanstack/react-query';

function SharedPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const filter = (searchParams.get('filter') || 'posts') as 'posts' | 'articles' | 'reels' | 'projects';
  
  const [selectedPostForComment, setSelectedPostForComment] = useState<Post | null>(null);

  // Use React Query for data fetching with caching
  const {
    data: sharedData,
    isLoading,
    isFetchingNextPage,
    error,
    fetchNextPage,
    hasNextPage,
    refetch,
  } = useInfiniteQuery({
    queryKey: ['activity', 'shared', filter] as const,
    queryFn: async ({ pageParam = 0 }: { pageParam: number }) => {
      const response = await postsAPI.getUserShared(filter, pageParam, 20);
      if (!response.success) {
        throw new Error('Failed to load shared content');
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
  const posts = sharedData?.pages.flatMap((page: any) => page.posts || []) || [];

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

  const filterLabels: Record<string, { label: string; icon: typeof Grid3x3 }> = {
    posts: { label: 'Posts', icon: Grid3x3 },
    articles: { label: 'Articles', icon: Newspaper },
    reels: { label: 'Reels', icon: Video },
    projects: { label: 'Projects', icon: Briefcase },
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
            Failed to load shared content
          </h3>
          <p className="text-neutral-600 dark:text-neutral-400 mb-6">
            {error instanceof Error ? error.message : 'Something went wrong. Please try again.'}
          </p>
          <Button
            onClick={() => refetch()}
            variant="solid"
            className="flex items-center gap-2 mx-auto"
            aria-label="Retry loading shared content"
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
              Content you shared
            </h1>
            <p className="text-sm text-neutral-600 dark:text-neutral-400 mt-1">
              Posts and articles you've shared
            </p>
          </div>
        </div>

        {/* Filter Tabs */}
        <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-1 -mx-4 px-4 md:mx-0 md:px-0">
          {Object.entries(filterLabels).map(([key, { label, icon: Icon }]) => {
            const isActive = filter === key;
            return (
              <button
                key={key}
                onClick={() => router.push(`/activity/shared?filter=${key}`)}
                className={`px-4 py-2 rounded-full text-sm font-semibold whitespace-nowrap transition-all duration-200 flex-shrink-0 flex items-center gap-2 ${
                  isActive
                    ? 'bg-purple-600 text-white shadow-md'
                    : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
                }`}
                aria-label={`Filter by ${label}`}
                aria-pressed={isActive}
              >
                <Icon className="w-4 h-4" />
                <span>{label}</span>
              </button>
            );
          })}
        </div>

        {/* Empty State */}
        {posts.length === 0 && (
          <div className="text-center py-20">
            <div className="w-20 h-20 mx-auto mb-4 bg-neutral-100 dark:bg-neutral-800 rounded-full flex items-center justify-center">
              <Share2 className="w-10 h-10 text-neutral-400" />
            </div>
            <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
              No shared {filterLabels[filter]?.label.toLowerCase() || 'content'}
            </h3>
            <p className="text-neutral-600 dark:text-neutral-400 mb-6">
              {filter === 'posts' 
                ? 'Posts you share will appear here'
                : filter === 'articles'
                ? 'Articles you share will appear here'
                : 'Content you share will appear here'}
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
              <PostCard 
                key={post.id}
                post={post}
                onComment={(p) => setSelectedPostForComment(p)}
                onShare={handleShare}
                onSave={handleSave}
              />
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

export default function SharedPage() {
  return (
    <ErrorBoundary>
      <SharedPageContent />
    </ErrorBoundary>
  );
}
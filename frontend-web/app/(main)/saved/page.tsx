'use client';

/**
 * Saved Posts & Articles Page - Enhanced
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Displays all saved content with collections, search, virtual scrolling, and caching
 */

import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { ErrorBoundary } from '@/components/errors/ErrorBoundary';
import { MainLayout } from '@/components/layout/MainLayout';
import { FeedSkeleton } from '@/components/ui/Skeleton';
import { 
  Loader2, 
  Bookmark, 
  Grid3x3, 
  Newspaper, 
  RefreshCw, 
  Search,
  FolderPlus,
  X,
  AlertCircle,
  Check
} from 'lucide-react';
import { Post, postsAPI } from '@/lib/api/posts';
import PostCard from '@/components/posts/PostCard';
import CommentModal from '@/components/posts/CommentModal';
import { toast } from '@/components/ui/Toast';
import { Button } from '@/components/ui/Button';
import { useRouter } from 'next/navigation';
import { useInfiniteQuery } from '@tanstack/react-query';
import { useVirtualizer } from '@tanstack/react-virtual';
import CollectionItem from '@/components/saved/CollectionItem';

type FilterType = 'all' | 'posts' | 'articles';

interface Collection {
  id: string;
  name: string;
  count: number;
  isDefault?: boolean;
}

function SavedPageContent() {
  const router = useRouter();
  const [activeFilter, setActiveFilter] = useState<FilterType>('all');
  const [selectedCollection, setSelectedCollection] = useState<string>('Saved');
  const [collections, setCollections] = useState<Collection[]>([
    { id: 'Saved', name: 'Saved', count: 0, isDefault: true },
  ]);
  const [searchQuery, setSearchQuery] = useState('');
  const [showCreateCollection, setShowCreateCollection] = useState(false);
  const [newCollectionName, setNewCollectionName] = useState('');
  const [selectedPostForComment, setSelectedPostForComment] = useState<Post | null>(null);
  
  // Virtual scrolling refs
  const parentRef = useRef<HTMLDivElement>(null);

  // Use React Query for data fetching with caching
  const {
    data: savedData,
    isLoading,
    isFetchingNextPage,
    error,
    fetchNextPage,
    hasNextPage,
    refetch,
  } = useInfiniteQuery({
    queryKey: ['saved', selectedCollection, activeFilter] as const,
    queryFn: async ({ pageParam = 0 }: { pageParam: number }) => {
      const response = await postsAPI.getSavedPosts(selectedCollection, pageParam, 20);
      if (!response.success) {
        throw new Error('Failed to load saved posts');
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
  const allPosts = savedData?.pages.flatMap((page: any) => page.posts || []) || [];

  // Filter posts by type
  const filteredByType = useMemo(() => {
    if (activeFilter === 'all') return allPosts;
    if (activeFilter === 'posts') {
      return allPosts.filter(p => p.post_type === 'post' || p.post_type === 'poll');
    }
    return allPosts.filter(p => p.post_type === 'article');
  }, [allPosts, activeFilter]);

  // Search filter
  const filteredPosts = useMemo(() => {
    if (!searchQuery.trim()) return filteredByType;
    const query = searchQuery.toLowerCase();
    return filteredByType.filter(post => 
      post.content.toLowerCase().includes(query) ||
      post.author?.display_name?.toLowerCase().includes(query) ||
      post.author?.username?.toLowerCase().includes(query) ||
      post.article?.title?.toLowerCase().includes(query) ||
      post.article?.subtitle?.toLowerCase().includes(query)
    );
  }, [filteredByType, searchQuery]);

  // Virtual scrolling
  const virtualizer = useVirtualizer({
    count: filteredPosts.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 400, // Estimated height per post card
    overscan: 5,
  });

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

  // Load collections from localStorage
  useEffect(() => {
    const savedCollections = localStorage.getItem('savedCollections');
    if (savedCollections) {
      try {
        const parsed = JSON.parse(savedCollections);
        setCollections([...collections, ...parsed]);
      } catch (e) {
        // Ignore parse errors
      }
    }
  }, []);

  // Save collections to localStorage
  const saveCollections = useCallback((newCollections: Collection[]) => {
    const customCollections = newCollections.filter(c => !c.isDefault);
    localStorage.setItem('savedCollections', JSON.stringify(customCollections));
    setCollections(newCollections);
  }, []);

  const handleCreateCollection = () => {
    if (!newCollectionName.trim()) {
      toast.error('Collection name cannot be empty');
      return;
    }
    
    const newCollection: Collection = {
      id: `collection-${Date.now()}`,
      name: newCollectionName.trim(),
      count: 0,
    };
    
    saveCollections([...collections, newCollection]);
    setNewCollectionName('');
    setShowCreateCollection(false);
    toast.success('Collection created');
  };

  const handleDeleteCollection = (collectionId: string) => {
    if (collections.find(c => c.id === collectionId)?.isDefault) {
      toast.error('Cannot delete default collection');
      return;
    }
    
    saveCollections(collections.filter(c => c.id !== collectionId));
    if (selectedCollection === collectionId) {
      setSelectedCollection('Saved');
    }
    toast.success('Collection deleted');
  };

  const handleRenameCollection = (collectionId: string, newName: string) => {
    if (!newName.trim()) {
      toast.error('Collection name cannot be empty');
      return;
    }
    
    saveCollections(collections.map(c => 
      c.id === collectionId ? { ...c, name: newName.trim() } : c
    ));
    toast.success('Collection renamed');
  };

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

  const getFilterCount = (filter: FilterType) => {
    if (filter === 'all') return allPosts.length;
    if (filter === 'posts') {
      return allPosts.filter(p => p.post_type === 'post' || p.post_type === 'poll').length;
    }
    return allPosts.filter(p => p.post_type === 'article').length;
  };

  if (isLoading) {
    return (
      <MainLayout>
        <FeedSkeleton count={5} />
      </MainLayout>
    );
  }

  if (error && allPosts.length === 0) {
    return (
      <MainLayout>
        <div className="text-center py-20">
          <div className="flex justify-center mb-4">
            <AlertCircle className="w-12 h-12 text-red-500" />
          </div>
          <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
            Failed to load saved posts
          </h3>
          <p className="text-neutral-600 dark:text-neutral-400 mb-6">
            {error instanceof Error ? error.message : 'Something went wrong. Please try again.'}
          </p>
          <Button
            onClick={() => refetch()}
            variant="solid"
            className="flex items-center gap-2 mx-auto"
            aria-label="Retry loading saved posts"
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
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl md:text-3xl font-bold text-neutral-900 dark:text-neutral-50">
              Saved
            </h1>
            <p className="text-sm text-neutral-600 dark:text-neutral-400 mt-1">
              {allPosts.length} {allPosts.length === 1 ? 'item' : 'items'} saved
            </p>
          </div>
        </div>

        {/* Collections */}
        <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-1 -mx-4 px-4 md:mx-0 md:px-0">
          {collections.map((collection) => (
            <CollectionItem
              key={collection.id}
              collection={collection}
              isActive={selectedCollection === collection.id}
              onSelect={setSelectedCollection}
              onRename={handleRenameCollection}
              onDelete={handleDeleteCollection}
            />
          ))}
          
          {/* Create Collection Button */}
          {showCreateCollection ? (
            <div className="flex items-center gap-1 bg-neutral-100 dark:bg-neutral-800 rounded-lg px-2 py-1 flex-shrink-0">
              <input
                type="text"
                value={newCollectionName}
                onChange={(e) => setNewCollectionName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    handleCreateCollection();
                  } else if (e.key === 'Escape') {
                    setShowCreateCollection(false);
                    setNewCollectionName('');
                  }
                }}
                placeholder="Collection name"
                className="text-sm bg-transparent border-none outline-none text-neutral-900 dark:text-neutral-50 min-w-[120px]"
                autoFocus
              />
              <button
                onClick={handleCreateCollection}
                className="p-1 hover:bg-neutral-200 dark:hover:bg-neutral-700 rounded"
                aria-label="Create collection"
              >
                <Check className="w-3 h-3" />
              </button>
              <button
                onClick={() => {
                  setShowCreateCollection(false);
                  setNewCollectionName('');
                }}
                className="p-1 hover:bg-neutral-200 dark:hover:bg-neutral-700 rounded"
                aria-label="Cancel creating collection"
              >
                <X className="w-3 h-3" />
              </button>
            </div>
          ) : (
            <button
              onClick={() => setShowCreateCollection(true)}
              className="px-4 py-2 rounded-full text-sm font-semibold whitespace-nowrap bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700 transition-colors flex items-center gap-2 flex-shrink-0"
              aria-label="Create new collection"
            >
              <FolderPlus className="w-4 h-4" />
              <span>New</span>
            </button>
          )}
        </div>

        {/* Search Bar */}
        {allPosts.length > 0 && (
          <div className="relative">
            <div className="absolute left-3 top-1/2 -translate-y-1/2">
              <Search className="w-4 h-4 text-neutral-400" />
            </div>
            <input
              type="text"
              placeholder="Search saved items..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-10 py-2 bg-neutral-50 dark:bg-neutral-900 border border-neutral-200 dark:border-neutral-800 rounded-lg text-neutral-900 dark:text-neutral-50 placeholder:text-neutral-500 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all"
              aria-label="Search saved items"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded hover:bg-neutral-200 dark:hover:bg-neutral-800 transition-colors"
                aria-label="Clear search"
              >
                <X className="w-4 h-4 text-neutral-400" />
              </button>
            )}
          </div>
        )}

        {/* Filter Tabs */}
        <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-1 -mx-4 px-4 md:mx-0 md:px-0">
          {[
            { id: 'all' as FilterType, label: 'All', icon: Bookmark },
            { id: 'posts' as FilterType, label: 'Posts', icon: Grid3x3 },
            { id: 'articles' as FilterType, label: 'Articles', icon: Newspaper },
          ].map((filter) => {
            const Icon = filter.icon;
            const count = getFilterCount(filter.id);
            return (
              <button
                key={filter.id}
                onClick={() => setActiveFilter(filter.id)}
                className={`px-4 py-2 rounded-full text-sm font-semibold whitespace-nowrap transition-all duration-200 flex-shrink-0 flex items-center gap-2 ${
                  activeFilter === filter.id
                    ? 'bg-purple-600 text-white shadow-md'
                    : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
                }`}
                aria-label={`Filter by ${filter.label}`}
                aria-pressed={activeFilter === filter.id}
              >
                <Icon className="w-4 h-4" />
                <span>{filter.label}</span>
                {count > 0 && (
                  <span className={`px-2 py-0.5 rounded-full text-xs ${
                    activeFilter === filter.id
                      ? 'bg-white/20 text-white'
                      : 'bg-neutral-200 dark:bg-neutral-700 text-neutral-600 dark:text-neutral-400'
                  }`}>
                    {count}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {/* Empty State */}
        {filteredPosts.length === 0 && allPosts.length === 0 && (
          <div className="text-center py-20">
            <div className="w-20 h-20 mx-auto mb-4 bg-neutral-100 dark:bg-neutral-800 rounded-full flex items-center justify-center">
              <Bookmark className="w-10 h-10 text-neutral-400" />
            </div>
            <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
              No saved items yet
            </h3>
            <p className="text-neutral-600 dark:text-neutral-400 mb-6">
              Save posts and articles you want to read later
            </p>
            <button
              onClick={() => router.push('/home')}
              className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors"
              aria-label="Go to feed"
            >
              Explore Feed
            </button>
          </div>
        )}

        {/* Search Empty State */}
        {filteredPosts.length === 0 && allPosts.length > 0 && searchQuery && (
          <div className="text-center py-20">
            <div className="w-20 h-20 mx-auto mb-4 bg-neutral-100 dark:bg-neutral-800 rounded-full flex items-center justify-center">
              <Search className="w-10 h-10 text-neutral-400" />
            </div>
            <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
              No results found
            </h3>
            <p className="text-neutral-600 dark:text-neutral-400 mb-6">
              Try a different search term
            </p>
            <button
              onClick={() => setSearchQuery('')}
              className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors"
              aria-label="Clear search"
            >
              Clear Search
            </button>
          </div>
        )}

        {/* Filtered Empty State */}
        {filteredPosts.length === 0 && allPosts.length > 0 && !searchQuery && (
          <div className="text-center py-20">
            <div className="w-20 h-20 mx-auto mb-4 bg-neutral-100 dark:bg-neutral-800 rounded-full flex items-center justify-center">
              {activeFilter === 'posts' ? (
                <Grid3x3 className="w-10 h-10 text-neutral-400" />
              ) : (
                <Newspaper className="w-10 h-10 text-neutral-400" />
              )}
            </div>
            <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
              No {activeFilter === 'posts' ? 'posts' : 'articles'} saved yet
            </h3>
            <p className="text-neutral-600 dark:text-neutral-400">
              Save {activeFilter === 'posts' ? 'posts' : 'articles'} to see them here
            </p>
          </div>
        )}

        {/* Posts/Articles List with Virtual Scrolling (for large lists) */}
        {filteredPosts.length > 50 && (
          <div
            ref={parentRef}
            className="relative"
            style={{ height: '600px', overflow: 'auto' }}
          >
            <div
              style={{
                height: `${virtualizer.getTotalSize()}px`,
                width: '100%',
                position: 'relative',
              }}
            >
              {virtualizer.getVirtualItems().map((virtualItem) => {
                const post = filteredPosts[virtualItem.index];
                return (
                  <div
                    key={post.id}
                    style={{
                      position: 'absolute',
                      top: 0,
                      left: 0,
                      width: '100%',
                      height: `${virtualItem.size}px`,
                      transform: `translateY(${virtualItem.start}px)`,
                    }}
                  >
                    <PostCard 
                      post={post}
                      onComment={(p) => setSelectedPostForComment(p)}
                      onShare={handleShare}
                      onSave={handleSave}
                    />
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Regular List (for smaller lists) */}
        {filteredPosts.length > 0 && filteredPosts.length <= 50 && (
          <div className="space-y-6">
            {filteredPosts.map((post) => (
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
        {!hasNextPage && filteredPosts.length > 0 && (
          <div className="text-center py-6 text-neutral-500 dark:text-neutral-400 text-sm">
            You've reached the end
          </div>
        )}
      </div>
    </MainLayout>
  );
}

export default function SavedPage() {
  return (
    <ErrorBoundary>
      <SavedPageContent />
    </ErrorBoundary>
  );
}
'use client';

/**
 * Enhanced Search Page
 * Supports users, posts, and hashtags with error boundaries, skeletons, and caching
 */

import { useState, useEffect, useRef, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { ErrorBoundary } from '@/components/errors/ErrorBoundary';
import { MainLayout } from '@/components/layout/MainLayout';
import { Avatar } from '@/components/ui/Avatar';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { Skeleton, FeedSkeleton } from '@/components/ui/Skeleton';
import VerifiedBadge from '@/components/ui/VerifiedBadge';
import { searchAPI, SearchUser, SearchPost, SearchHashtag } from '@/lib/api/search';
import { useInfiniteQuery } from '@tanstack/react-query';
import { 
  Search, 
  Loader2, 
  X,
  MapPin,
  Users,
  Filter,
  SlidersHorizontal,
  Hash,
  FileText,
  AlertCircle,
  RefreshCw
} from 'lucide-react';
import { toast } from '@/components/ui/Toast';
import { useQueryClient } from '@tanstack/react-query';

type SearchType = 'users' | 'posts' | 'hashtags' | 'all';
type FilterType = 'all' | 'verified' | 'professionals' | 'creators';
type SortType = 'relevance' | 'followers' | 'recent';

function SearchPageContent() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [query, setQuery] = useState('');
  const [searchType, setSearchType] = useState<SearchType>('users');
  const [activeFilter, setActiveFilter] = useState<FilterType>('all');
  const [sortBy, setSortBy] = useState<SortType>('relevance');
  const [showFilters, setShowFilters] = useState(false);
  const [recentSearches, setRecentSearches] = useState<string[]>([]);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const debounceTimerRef = useRef<NodeJS.Timeout | null>(null);

  // Load recent searches from localStorage
  useEffect(() => {
    const saved = localStorage.getItem('recentSearches');
    if (saved) {
      try {
        setRecentSearches(JSON.parse(saved).slice(0, 5));
      } catch (e) {
        // Ignore parse errors
      }
    }
  }, []);

  // Save search to recent searches
  const saveToRecentSearches = useCallback((searchQuery: string) => {
    if (!searchQuery.trim() || searchQuery.length < 2) return;
    
    setRecentSearches((prev) => {
      const updated = [
        searchQuery,
        ...prev.filter(s => s.toLowerCase() !== searchQuery.toLowerCase())
      ].slice(0, 5);
      localStorage.setItem('recentSearches', JSON.stringify(updated));
      return updated;
    });
  }, []);

  // Infinite query for search results
  const {
    data: searchData,
    isLoading,
    isFetching,
    error,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    refetch,
  } = useInfiniteQuery({
    queryKey: ['search', query, searchType, activeFilter, sortBy] as const,
    queryFn: async ({ pageParam = 1 }: { pageParam: number }) => {
      if (!query.trim() || query.length < 2) {
        return { success: true, users: [], posts: [], hashtags: [], total: 0, has_more: false };
      }

      const params = {
        q: query.trim(),
        type: searchType,
        page: pageParam,
        limit: 20,
        verified: activeFilter === 'verified',
        sort_by: sortBy,
      };

      if (searchType === 'all') {
        return searchAPI.searchAll(params);
      } else if (searchType === 'users') {
        const result = await searchAPI.searchUsers(params);
        return { ...result, posts: [], hashtags: [] };
      } else if (searchType === 'posts') {
        const result = await searchAPI.searchPosts(params);
        return { ...result, users: [], hashtags: [] };
      } else {
        const result = await searchAPI.searchHashtags(params);
        return { ...result, users: [], posts: [] };
      }
    },
    getNextPageParam: (lastPage: any, allPages: any[]) => {
      if (lastPage?.has_more) {
        return allPages.length + 1;
      }
      return undefined;
    },
    enabled: query.trim().length >= 2,
    initialPageParam: 1,
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes
  } as any);

  // Flatten results
  const allUsers = searchData?.pages.flatMap((page: any) => page.users || []) || [];
  const allPosts = searchData?.pages.flatMap((page: any) => page.posts || []) || [];
  const allHashtags = searchData?.pages.flatMap((page: any) => page.hashtags || []) || [];
  const totalResults = ((searchData?.pages[0] as any)?.total || 0);
  const hasSearched = query.trim().length >= 2 && (searchData?.pages.length || 0) > 0;

  // Debounced search trigger
  useEffect(() => {
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }

    if (query.trim().length >= 2) {
      debounceTimerRef.current = setTimeout(() => {
        queryClient.invalidateQueries({ queryKey: ['search'] });
        saveToRecentSearches(query);
      }, 400);
    } else {
      setShowSuggestions(query.length > 0);
    }

    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
      }
    };
  }, [query, searchType, activeFilter, sortBy, queryClient, saveToRecentSearches]);

  const handleSearch = (searchQuery: string) => {
    setQuery(searchQuery);
    setShowSuggestions(false);
    searchInputRef.current?.blur();
  };

  const clearSearch = () => {
    setQuery('');
    setShowSuggestions(false);
    queryClient.removeQueries({ queryKey: ['search'] });
    searchInputRef.current?.focus();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setShowSuggestions(false);
      searchInputRef.current?.blur();
    } else if (e.key === 'Enter' && query.trim().length >= 2) {
      handleSearch(query);
    }
  };

  const formatNumber = (num?: number) => {
    if (!num) return '0';
    if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`;
    if (num >= 1000) return `${(num / 1000).toFixed(1)}K`;
    return num.toString();
  };

  const handleRetry = () => {
    refetch();
  };

  return (
    <MainLayout>
      <div className="min-h-screen bg-white dark:bg-neutral-950">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          {/* Search Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
              Search
            </h1>
            <p className="text-sm text-neutral-600 dark:text-neutral-400">
              Find people, posts, articles, and hashtags
            </p>
          </div>

          {/* Search Bar */}
          <div className="relative mb-6">
            <div className="relative">
              <div className="absolute left-4 top-1/2 -translate-y-1/2 z-10">
                <Search className="w-5 h-5 text-neutral-400" />
              </div>
              
              <input
                ref={searchInputRef}
                type="text"
                placeholder="Search users, posts, or hashtags..."
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value);
                  setShowSuggestions(true);
                }}
                onKeyDown={handleKeyDown}
                onFocus={() => {
                  if (query.length > 0 || recentSearches.length > 0) {
                    setShowSuggestions(true);
                  }
                }}
                className="w-full pl-12 pr-12 py-3 bg-neutral-50 dark:bg-neutral-900 border border-neutral-200 dark:border-neutral-800 rounded-lg text-neutral-900 dark:text-neutral-50 placeholder:text-neutral-500 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 focus:border-transparent transition-all"
                autoFocus
                aria-label="Search input"
              />

              {query && (
                <button
                  onClick={clearSearch}
                  className="absolute right-12 top-1/2 -translate-y-1/2 p-1 rounded hover:bg-neutral-200 dark:hover:bg-neutral-800 transition-colors"
                  aria-label="Clear search"
                >
                  <X className="w-4 h-4 text-neutral-400" />
                </button>
              )}

              {(isLoading || isFetching) && (
                <div className="absolute right-4 top-1/2 -translate-y-1/2">
                  <Loader2 className="w-5 h-5 animate-spin text-brand-purple-600" />
                </div>
              )}

              {/* Search Suggestions */}
              {showSuggestions && !hasSearched && (query.length > 0 || recentSearches.length > 0) && (
                <div className="absolute top-full left-0 right-0 mt-2 bg-white dark:bg-neutral-900 border border-neutral-200 dark:border-neutral-800 rounded-lg shadow-lg overflow-hidden z-30">
                  {recentSearches.length > 0 && query.length === 0 && (
                    <div className="p-3 border-b border-neutral-200 dark:border-neutral-800">
                      <p className="text-xs font-medium text-neutral-500 dark:text-neutral-400 mb-2 px-2">
                        Recent Searches
                      </p>
                      <div className="space-y-1">
                        {recentSearches.map((search, idx) => (
                          <button
                            key={idx}
                            onClick={() => handleSearch(search)}
                            className="w-full text-left px-3 py-2 rounded hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors text-sm text-neutral-700 dark:text-neutral-300"
                            aria-label={`Search for ${search}`}
                          >
                            {search}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}
                  
                  {query.length > 0 && (
                    <button
                      onClick={() => handleSearch(query)}
                      className="w-full text-left px-4 py-3 hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors text-sm font-medium text-neutral-900 dark:text-neutral-50 flex items-center gap-3"
                      aria-label={`Search for ${query}`}
                    >
                      <Search className="w-4 h-4 text-neutral-400" />
                      Search for "{query}"
                    </button>
                  )}
                </div>
              )}
            </div>

            {/* Search Type Tabs */}
            {hasSearched && (
              <div className="mt-4 flex items-center gap-2 overflow-x-auto scrollbar-hide pb-1">
                {[
                  { id: 'users' as SearchType, label: 'Users', icon: Users },
                  { id: 'posts' as SearchType, label: 'Posts', icon: FileText },
                  { id: 'hashtags' as SearchType, label: 'Hashtags', icon: Hash },
                  { id: 'all' as SearchType, label: 'All', icon: Search },
                ].map((tab) => {
                  const Icon = tab.icon;
                  const isActive = searchType === tab.id;
                  return (
                    <button
                      key={tab.id}
                      onClick={() => setSearchType(tab.id)}
                      className={`px-4 py-2 rounded-lg text-sm font-medium whitespace-nowrap transition-all duration-200 flex items-center gap-2 flex-shrink-0 ${
                        isActive
                          ? 'bg-brand-purple-600 text-white'
                          : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
                      }`}
                      aria-label={`Search ${tab.label}`}
                      aria-pressed={isActive}
                    >
                      <Icon className="w-4 h-4" />
                      {tab.label}
                    </button>
                  );
                })}
              </div>
            )}

            {/* Filters */}
            {hasSearched && searchType === 'users' && (
              <div className="mt-4 flex items-center gap-3 flex-wrap">
                <button
                  onClick={() => setShowFilters(!showFilters)}
                  className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-neutral-700 dark:text-neutral-300 hover:text-neutral-900 dark:hover:text-neutral-50 border border-neutral-200 dark:border-neutral-800 rounded-lg hover:bg-neutral-50 dark:hover:bg-neutral-900 transition-colors"
                  aria-label="Toggle filters"
                  aria-expanded={showFilters}
                >
                  <SlidersHorizontal className="w-4 h-4" />
                  Filters
                </button>

                {[
                  { id: 'all' as FilterType, label: 'All' },
                  { id: 'verified' as FilterType, label: 'Verified' },
                  { id: 'professionals' as FilterType, label: 'Professionals' },
                  { id: 'creators' as FilterType, label: 'Creators' },
                ].map((filter) => {
                  const isActive = activeFilter === filter.id;
                  return (
                    <button
                      key={filter.id}
                      onClick={() => {
                        setActiveFilter(filter.id);
                        queryClient.invalidateQueries({ queryKey: ['search'] });
                      }}
                      className={`px-3 py-1.5 text-sm font-medium rounded-lg transition-colors ${
                        isActive
                          ? 'bg-brand-purple-600 text-white'
                          : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
                      }`}
                      aria-label={`Filter by ${filter.label}`}
                      aria-pressed={isActive}
                    >
                      {filter.label}
                    </button>
                  );
                })}
              </div>
            )}

            {/* Advanced Filters Panel */}
            {showFilters && hasSearched && searchType === 'users' && (
              <div className="mt-4 p-4 bg-neutral-50 dark:bg-neutral-900 rounded-lg border border-neutral-200 dark:border-neutral-800">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-sm font-semibold text-neutral-900 dark:text-neutral-50 flex items-center gap-2">
                    <Filter className="w-4 h-4" />
                    Sort Options
                  </h3>
                  <button
                    onClick={() => setShowFilters(false)}
                    className="p-1 rounded hover:bg-neutral-200 dark:hover:bg-neutral-800"
                    aria-label="Close filters"
                  >
                    <X className="w-4 h-4 text-neutral-500" />
                  </button>
                </div>
                
                <div className="flex flex-wrap gap-2">
                  {[
                    { id: 'relevance' as SortType, label: 'Relevance' },
                    { id: 'followers' as SortType, label: 'Most Followers' },
                    { id: 'recent' as SortType, label: 'Recently Active' },
                  ].map((sort) => {
                    const isActive = sortBy === sort.id;
                    return (
                      <button
                        key={sort.id}
                        onClick={() => {
                          setSortBy(sort.id);
                          queryClient.invalidateQueries({ queryKey: ['search'] });
                        }}
                        className={`px-3 py-1.5 text-sm font-medium rounded-lg transition-colors ${
                          isActive
                            ? 'bg-brand-purple-600 text-white'
                            : 'bg-white dark:bg-neutral-800 border border-neutral-200 dark:border-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-50 dark:hover:bg-neutral-700'
                        }`}
                        aria-label={`Sort by ${sort.label}`}
                        aria-pressed={isActive}
                      >
                        {sort.label}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}

            {/* Results Count */}
            {hasSearched && totalResults > 0 && !isLoading && (
              <div className="mt-4 text-sm text-neutral-600 dark:text-neutral-400">
                <span className="font-medium text-neutral-900 dark:text-neutral-50">{totalResults}</span>{' '}
                {totalResults === 1 ? 'result' : 'results'}
              </div>
            )}
          </div>

          {/* Results Section */}
          {hasSearched && (
            <>
              {isLoading ? (
                <div className="space-y-3">
                  <FeedSkeleton count={5} />
                </div>
              ) : error ? (
                <div className="text-center py-20">
                  <div className="flex justify-center mb-4">
                    <AlertCircle className="w-12 h-12 text-red-500" />
                  </div>
                  <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
                    Failed to load search results
                  </h3>
                  <p className="text-neutral-600 dark:text-neutral-400 mb-6">
                    {error instanceof Error ? error.message : 'Something went wrong. Please try again.'}
                  </p>
                  <Button
                    onClick={handleRetry}
                    variant="solid"
                    className="flex items-center gap-2 mx-auto"
                  >
                    <RefreshCw className="w-4 h-4" />
                    Retry
                  </Button>
                </div>
              ) : (
                <>
                  {/* Users Results */}
                  {searchType === 'users' || searchType === 'all' ? (
                    allUsers.length > 0 ? (
                      <div className="space-y-3 mb-6">
                        {allUsers.map((user: SearchUser) => (
                          <Card
                            key={user.id}
                            hoverable
                            className="cursor-pointer"
                            onClick={() => router.push(`/profile?u=${user.username}`)}
                          >
                            <div className="flex items-center gap-4">
                              <div className="flex-shrink-0">
                                <Avatar
                                  src={user.profile_picture}
                                  alt={user.display_name}
                                  fallback={user.display_name}
                                  size="md"
                                />
                              </div>
                              <div className="flex-1 min-w-0">
                                <div className="flex items-center gap-2 mb-1">
                                  <h3 className="font-semibold text-neutral-900 dark:text-neutral-50 truncate">
                                    {user.display_name}
                                  </h3>
                                  {user.is_verified && <VerifiedBadge size="sm" />}
                                </div>
                                <p className="text-sm text-neutral-600 dark:text-neutral-400 mb-1">
                                  @{user.username}
                                </p>
                                {user.bio && (
                                  <p className="text-sm text-neutral-700 dark:text-neutral-300 line-clamp-2 mb-2">
                                    {user.bio}
                                  </p>
                                )}
                                <div className="flex items-center gap-4 text-xs text-neutral-500 dark:text-neutral-400">
                                  {user.location && (
                                    <div className="flex items-center gap-1">
                                      <MapPin className="w-3.5 h-3.5" />
                                      <span>{user.location}</span>
                                    </div>
                                  )}
                                  {user.followers_count !== undefined && (
                                    <div className="flex items-center gap-1">
                                      <Users className="w-3.5 h-3.5" />
                                      <span>{formatNumber(user.followers_count)} followers</span>
                                    </div>
                                  )}
                                </div>
                              </div>
                            </div>
                          </Card>
                        ))}
                      </div>
                    ) : searchType === 'users' && !isLoading ? (
                      <div className="text-center py-12 mb-6">
                        <Users className="w-12 h-12 mx-auto mb-4 text-neutral-400" />
                        <p className="text-neutral-600 dark:text-neutral-400">No users found</p>
                      </div>
                    ) : null
                  ) : null}

                  {/* Posts Results */}
                  {searchType === 'posts' || searchType === 'all' ? (
                    allPosts.length > 0 ? (
                      <div className="space-y-3 mb-6">
                        {allPosts.map((post: SearchPost) => (
                          <Card
                            key={post.id}
                            hoverable
                            className="cursor-pointer"
                            onClick={() => router.push(`/posts/${post.id}`)}
                          >
                            <div className="space-y-3">
                              {post.author && (
                                <div className="flex items-center gap-2">
                                  <Avatar
                                    src={post.author.profile_picture}
                                    alt={post.author.display_name || post.author.username}
                                    size="sm"
                                  />
                                  <span className="text-sm font-medium text-neutral-900 dark:text-neutral-50">
                                    {post.author.display_name || post.author.username}
                                  </span>
                                  {post.author.is_verified && <VerifiedBadge size="sm" />}
                                </div>
                              )}
                              <p className="text-neutral-700 dark:text-neutral-300 line-clamp-3">
                                {post.content}
                              </p>
                              <div className="flex items-center gap-4 text-xs text-neutral-500 dark:text-neutral-400">
                                <span>{post.likes_count} likes</span>
                                <span>{post.comments_count} comments</span>
                              </div>
                            </div>
                          </Card>
                        ))}
                      </div>
                    ) : searchType === 'posts' && !isLoading ? (
                      <div className="text-center py-12 mb-6">
                        <FileText className="w-12 h-12 mx-auto mb-4 text-neutral-400" />
                        <p className="text-neutral-600 dark:text-neutral-400">No posts found</p>
                      </div>
                    ) : null
                  ) : null}

                  {/* Hashtags Results */}
                  {searchType === 'hashtags' || searchType === 'all' ? (
                    allHashtags.length > 0 ? (
                      <div className="space-y-3 mb-6">
                        {allHashtags.map((hashtag: SearchHashtag, idx: number) => (
                          <Card
                            key={idx}
                            hoverable
                            className="cursor-pointer"
                            onClick={() => router.push(`/hashtag/${hashtag.tag}`)}
                          >
                            <div className="flex items-center justify-between">
                              <div className="flex items-center gap-3">
                                <Hash className="w-5 h-5 text-brand-purple-600" />
                                <div>
                                  <h3 className="font-semibold text-neutral-900 dark:text-neutral-50">
                                    #{hashtag.tag}
                                  </h3>
                                  <p className="text-sm text-neutral-600 dark:text-neutral-400">
                                    {hashtag.posts_count} {hashtag.posts_count === 1 ? 'post' : 'posts'}
                                  </p>
                                </div>
                              </div>
                              {hashtag.is_trending && (
                                <span className="px-2 py-1 text-xs font-medium bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-400 rounded">
                                  Trending
                                </span>
                              )}
                            </div>
                          </Card>
                        ))}
                      </div>
                    ) : searchType === 'hashtags' && !isLoading ? (
                      <div className="text-center py-12 mb-6">
                        <Hash className="w-12 h-12 mx-auto mb-4 text-neutral-400" />
                        <p className="text-neutral-600 dark:text-neutral-400">No hashtags found</p>
                      </div>
                    ) : null
                  ) : null}

                  {/* Load More */}
                  {hasNextPage && (
                    <div className="flex justify-center py-6">
                      <Button
                        onClick={() => fetchNextPage()}
                        disabled={isFetchingNextPage}
                        variant="outline"
                      >
                        {isFetchingNextPage ? (
                          <>
                            <Loader2 className="w-4 h-4 animate-spin mr-2" />
                            Loading...
                          </>
                        ) : (
                          'Load More'
                        )}
                      </Button>
                    </div>
                  )}

                  {/* Empty State */}
                  {!isLoading && allUsers.length === 0 && allPosts.length === 0 && allHashtags.length === 0 && (
                    <div className="text-center py-16">
                      <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-neutral-100 dark:bg-neutral-800 flex items-center justify-center">
                        <Search className="w-8 h-8 text-neutral-400" />
                      </div>
                      <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
                        No results found
                      </h3>
                      <p className="text-sm text-neutral-600 dark:text-neutral-400 mb-6">
                        Try adjusting your search terms or filters
                      </p>
                      <Button
                        variant="outline"
                        onClick={clearSearch}
                        size="sm"
                      >
                        Clear Search
                      </Button>
                    </div>
                  )}
                </>
              )}
            </>
          )}

          {/* Empty State */}
          {!hasSearched && !isLoading && (
            <div className="text-center py-16">
              <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-neutral-100 dark:bg-neutral-800 flex items-center justify-center">
                <Search className="w-8 h-8 text-neutral-400" />
              </div>
              <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
                Start searching
              </h3>
              <p className="text-sm text-neutral-600 dark:text-neutral-400 mb-6">
                Enter a name, username, hashtag, or keyword to find content
              </p>
              
              {/* Recent Searches */}
              {recentSearches.length > 0 && (
                <div className="max-w-md mx-auto">
                  <p className="text-xs font-medium text-neutral-500 dark:text-neutral-400 mb-3 uppercase tracking-wide">
                    Recent Searches
                  </p>
                  <div className="flex flex-wrap items-center justify-center gap-2">
                    {recentSearches.map((search, idx) => (
                      <button
                        key={idx}
                        onClick={() => handleSearch(search)}
                        className="px-3 py-1.5 bg-neutral-100 dark:bg-neutral-800 border border-neutral-200 dark:border-neutral-800 rounded-lg text-sm text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700 transition-colors"
                        aria-label={`Search for ${search}`}
                      >
                        {search}
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </MainLayout>
  );
}

export default function SearchPage() {
  return (
    <ErrorBoundary>
      <SearchPageContent />
    </ErrorBoundary>
  );
}

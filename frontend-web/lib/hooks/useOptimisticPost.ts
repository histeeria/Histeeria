/**
 * Optimistic Post Hook
 * Handles optimistic updates for post creation
 */

import { useCallback } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Post } from '@/lib/api/posts';
import { useUser } from './useUser';

export function useOptimisticPost() {
  const queryClient = useQueryClient();
  const { user } = useUser();

  const createOptimisticPost = useCallback((postData: any): Post => {
    return {
      id: `temp-${Date.now()}`,
      user_id: user?.id || '',
      author: {
        id: user?.id || '',
        username: user?.username || 'you',
        display_name: user?.display_name || user?.username || 'You',
        profile_picture: user?.profile_picture || undefined,
        is_verified: user?.is_verified || false,
      },
      post_type: postData.post_type || 'post',
      content: postData.content || '',
      media_urls: postData.media_urls || [],
      media_types: postData.media_types || [],
      visibility: postData.visibility || 'public',
      allows_comments: postData.allows_comments ?? true,
      allows_sharing: postData.allows_sharing ?? true,
      likes_count: 0,
      comments_count: 0,
      shares_count: 0,
      is_liked: false,
      is_saved: false,
      is_pinned: false,
      views_count: 0,
      saves_count: 0,
      is_featured: false,
      is_nsfw: false,
      is_published: true,
      is_draft: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      poll: postData.poll,
      article: postData.article,
    };
  }, [user]);

  const addOptimisticPostToFeed = useCallback((feedType: string, optimisticPost: Post) => {
    queryClient.setQueryData(['feed', feedType], (oldData: any) => {
      if (!oldData?.pages) return oldData;
      
      return {
        ...oldData,
        pages: oldData.pages.map((page: any, index: number) => {
          if (index === 0) {
            return {
              ...page,
              posts: [optimisticPost, ...(page.posts || [])],
            };
          }
          return page;
        }),
      };
    });
  }, [queryClient]);

  const replaceOptimisticPost = useCallback((feedType: string, tempId: string, realPost: Post) => {
    queryClient.setQueryData(['feed', feedType], (oldData: any) => {
      if (!oldData?.pages) return oldData;
      
      return {
        ...oldData,
        pages: oldData.pages.map((page: any) => ({
          ...page,
          posts: page.posts?.map((post: Post) => 
            post.id === tempId ? realPost : post
          ) || [],
        })),
      };
    });
  }, [queryClient]);

  const removeOptimisticPost = useCallback((feedType: string, tempId: string) => {
    queryClient.setQueryData(['feed', feedType], (oldData: any) => {
      if (!oldData?.pages) return oldData;
      
      return {
        ...oldData,
        pages: oldData.pages.map((page: any) => ({
          ...page,
          posts: page.posts?.filter((post: Post) => post.id !== tempId) || [],
        })),
      };
    });
  }, [queryClient]);

  return {
    createOptimisticPost,
    addOptimisticPostToFeed,
    replaceOptimisticPost,
    removeOptimisticPost,
  };
}

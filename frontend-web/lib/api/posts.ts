import React from 'react';

// ============================================
// TYPES
// ============================================

export interface Post {
  id: string;
  user_id: string;
  post_type: 'post' | 'poll' | 'article';
  content: string;
  media_urls?: string[];
  media_types?: string[];
  visibility: 'public' | 'connections' | 'private';
  allows_comments: boolean;
  allows_sharing: boolean;
  likes_count: number;
  comments_count: number;
  shares_count: number;
  views_count: number;
  saves_count: number;
  is_pinned: boolean;
  is_featured: boolean;
  is_nsfw: boolean;
  is_published: boolean;
  is_draft: boolean;
  published_at?: string;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
  
  // Relations
  author?: User;
  poll?: Poll;
  article?: Article;
  is_liked: boolean;
  is_saved: boolean;
  top_comments?: Comment[];
  hashtags?: string[];
}

export interface Poll {
  id: string;
  post_id: string;
  question: string;
  duration_hours: number;
  allow_multiple_votes: boolean;
  show_results_before_vote: boolean;
  allow_vote_changes: boolean;
  anonymous_votes: boolean;
  is_closed: boolean;
  closed_at?: string;
  ends_at: string;
  total_votes: number;
  created_at: string;
  options: PollOption[];
  user_vote?: string; // Option ID user voted for
}

export interface PollOption {
  id: string;
  poll_id: string;
  option_text: string;
  option_index: number;
  votes_count: number;
}

export interface PollResults {
  poll: Poll;
  options: PollOptionResult[];
  total_votes: number;
  user_voted: boolean;
  user_vote_id?: string;
  time_left?: number; // milliseconds
  is_ended: boolean;
}

export interface PollOptionResult {
  id: string;
  option_text: string;
  option_index: number;
  votes_count: number;
  percentage: number;
  is_user_vote: boolean;
}

export interface Article {
  id: string;
  post_id: string;
  title: string;
  subtitle?: string;
  content_html: string;
  cover_image_url?: string;
  meta_title?: string;
  meta_description?: string;
  slug: string;
  read_time_minutes: number;
  category?: string;
  views_count: number;
  reads_count: number;
  created_at: string;
  updated_at: string;
  tags?: string[];
}

export interface Comment {
  id: string;
  post_id: string;
  user_id: string;
  parent_comment_id?: string;
  content: string;
  media_url?: string;
  media_type?: string;
  likes_count: number;
  replies_count: number;
  is_edited: boolean;
  edited_at?: string;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
  
  // Relations
  author?: User;
  replies?: Comment[];
  is_liked: boolean;
  parent_comment?: Comment;
}

export interface User {
  id: string;
  username: string;
  display_name?: string;
  profile_picture?: string;
  is_verified?: boolean;
}

// Request types
export interface CreatePostRequest {
  post_type: 'post' | 'poll' | 'article';
  content: string;
  media_urls?: string[];
  media_types?: string[];
  visibility?: 'public' | 'connections' | 'private';
  allows_comments?: boolean;
  allows_sharing?: boolean;
  is_draft?: boolean;
  is_nsfw?: boolean;
  poll?: CreatePollRequest;
  article?: CreateArticleRequest;
}

export interface CreatePollRequest {
  question: string;
  options: string[];
  duration_hours: number;
  allow_multiple_votes?: boolean;
  show_results_before_vote?: boolean;
  allow_vote_changes?: boolean;
  anonymous_votes?: boolean;
}

export interface CreateArticleRequest {
  title: string;
  subtitle?: string;
  content_html: string;
  cover_image_url?: string;
  meta_title?: string;
  meta_description?: string;
  category?: string;
  tags?: string[];
}

export interface CreateCommentRequest {
  content: string;
  parent_comment_id?: string;
  media_url?: string;
  media_type?: string;
}

// Response types
export interface PostResponse {
  success: boolean;
  post?: Post;
  message?: string;
}

export interface PostsResponse {
  success: boolean;
  posts: Post[];
  total: number;
  page: number;
  limit: number;
  has_more: boolean;
}

export interface CommentResponse {
  success: boolean;
  comment?: Comment;
  message?: string;
}

export interface CommentsResponse {
  success: boolean;
  comments: Comment[];
  total: number;
  page: number;
  limit: number;
  has_more: boolean;
}

// ============================================
// API CLIENT
// ============================================

const API_BASE = '/api/proxy/v1';

async function fetchAPI(endpoint: string, options: RequestInit = {}) {
  const token = localStorage.getItem('token');
  
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  
  try {
    // Create abort controller for timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout

    const response = await fetch(`${API_BASE}${endpoint}`, {
      ...options,
      headers,
      signal: controller.signal,
    });

    clearTimeout(timeoutId);
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: 'Request failed' }));
      const message = error.message || error.error || `HTTP ${response.status}`;
      throw new Error(message);
    }
    
    return response.json();
  } catch (error: any) {
    // Handle network errors, CORS errors, timeouts, etc.
    if (error.name === 'AbortError') {
      console.error(`[fetchAPI] Timeout for ${endpoint}`);
      throw new Error('Request timeout: Server took too long to respond. Please try again.');
    }
    
    if (error instanceof TypeError && error.message === 'Failed to fetch') {
      console.error(`[fetchAPI] Network error for ${endpoint}:`, error);
      throw new Error('Network error: Unable to connect to server. Please check your connection.');
    }
    
    throw error;
  }
}

// ============================================
// POSTS API
// ============================================

export const postsAPI = {
  // Create post
  createPost: async (data: CreatePostRequest): Promise<PostResponse> => {
    return fetchAPI('/posts', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },
  
  // Get single post
  getPost: async (postId: string): Promise<PostResponse> => {
    return fetchAPI(`/posts/${postId}`);
  },
  
  // Get article by slug (public endpoint)
  getArticleBySlug: async (slug: string): Promise<PostResponse> => {
    return fetchAPI(`/articles/${slug}`, {
      method: 'GET',
    });
  },
  
  // Update post
  updatePost: async (postId: string, updates: Partial<CreatePostRequest>): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/posts/${postId}`, {
      method: 'PUT',
      body: JSON.stringify(updates),
    });
  },
  
  // Delete post
  deletePost: async (postId: string): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/posts/${postId}`, {
      method: 'DELETE',
    });
  },
  
  // Get user posts
  getUserPosts: async (username: string, page = 0, limit = 20): Promise<PostsResponse> => {
    return fetchAPI(`/posts/user/${username}?limit=${limit}&offset=${page * limit}`);
  },
  
  // ============================================
  // ENGAGEMENT
  // ============================================
  
  // Like post
  likePost: async (postId: string): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/posts/${postId}/like`, {
      method: 'POST',
    });
  },
  
  // Unlike post
  unlikePost: async (postId: string): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/posts/${postId}/like`, {
      method: 'DELETE',
    });
  },
  
  // Share post
  sharePost: async (postId: string, comment?: string): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/posts/${postId}/share`, {
      method: 'POST',
      body: JSON.stringify({ comment }),
    });
  },
  
  // Save post
  savePost: async (postId: string, collection = 'Saved'): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/posts/${postId}/save`, {
      method: 'POST',
      body: JSON.stringify({ collection }),
    });
  },
  
  // Unsave post
  unsavePost: async (postId: string): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/posts/${postId}/save`, {
      method: 'DELETE',
    });
  },
  
  // ============================================
  // COMMENTS
  // ============================================
  
  // Create comment
  createComment: async (postId: string, data: CreateCommentRequest): Promise<CommentResponse> => {
    return fetchAPI(`/posts/${postId}/comments`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },
  
  // Get comments
  getComments: async (postId: string, page = 0, limit = 20): Promise<CommentsResponse> => {
    return fetchAPI(`/posts/${postId}/comments?limit=${limit}&offset=${page * limit}`);
  },
  
  // Update comment
  updateComment: async (commentId: string, content: string): Promise<CommentResponse> => {
    return fetchAPI(`/comments/${commentId}`, {
      method: 'PUT',
      body: JSON.stringify({ content }),
    });
  },
  
  // Delete comment
  deleteComment: async (commentId: string): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/comments/${commentId}`, {
      method: 'DELETE',
    });
  },
  
  // Like comment
  likeComment: async (commentId: string): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/comments/${commentId}/like`, {
      method: 'POST',
    });
  },
  
  // ============================================
  // POLLS
  // ============================================
  
  // Vote on poll
  votePoll: async (postId: string, optionId: string): Promise<{success: boolean; message: string; results: PollResults}> => {
    return fetchAPI(`/posts/${postId}/vote`, {
      method: 'POST',
      body: JSON.stringify({ option_id: optionId }),
    });
  },
  
  // Get poll results
  getPollResults: async (postId: string): Promise<{success: boolean; results: PollResults}> => {
    return fetchAPI(`/posts/${postId}/results`);
  },
  
  // ============================================
  // FEED
  // ============================================
  
  // Get home feed
  getHomeFeed: async (page = 0, limit = 20): Promise<PostsResponse> => {
    return fetchAPI(`/feed/home?limit=${limit}&offset=${page * limit}`);
  },
  
  // Get following feed
  getFollowingFeed: async (page = 0, limit = 20): Promise<PostsResponse> => {
    return fetchAPI(`/feed/following?limit=${limit}&offset=${page * limit}`);
  },
  
  // Get explore feed
  getExploreFeed: async (page = 0, limit = 20): Promise<PostsResponse> => {
    return fetchAPI(`/feed/explore?limit=${limit}&offset=${page * limit}`);
  },
  
  // Get saved posts
  getSavedPosts: async (collection = 'Saved', page = 0, limit = 20): Promise<PostsResponse> => {
    return fetchAPI(`/feed/saved?collection=${collection}&limit=${limit}&offset=${page * limit}`);
  },
  
  // Get user interactions (likes, comments)
  getUserInteractions: async (filter: 'likes' | 'comments', page = 0, limit = 20): Promise<PostsResponse> => {
    return fetchAPI(`/activity/interactions?filter=${filter}&limit=${limit}&offset=${page * limit}`);
  },
  
  // Get user archived/deleted posts
  getUserArchived: async (filter: 'deleted' | 'archived', page = 0, limit = 20): Promise<PostsResponse> => {
    return fetchAPI(`/activity/archived?filter=${filter}&limit=${limit}&offset=${page * limit}`);
  },
  
  // Get user shared posts/articles
  getUserShared: async (filter: 'posts' | 'articles' | 'reels' | 'projects', page = 0, limit = 20): Promise<PostsResponse> => {
    return fetchAPI(`/activity/shared?filter=${filter}&limit=${limit}&offset=${page * limit}`);
  },
  
  // ============================================
  // HASHTAGS
  // ============================================
  
  // Get hashtag feed
  getHashtagFeed: async (tag: string, page = 0, limit = 20): Promise<PostsResponse> => {
    return fetchAPI(`/hashtags/${tag}/posts?limit=${limit}&offset=${page * limit}`);
  },
  
  // Get trending hashtags
  getTrendingHashtags: async (limit = 10): Promise<{success: boolean; hashtags: any[]}> => {
    return fetchAPI(`/hashtags/trending?limit=${limit}`);
  },
  
  // Follow hashtag
  followHashtag: async (tag: string): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/hashtags/${tag}/follow`, {
      method: 'POST',
    });
  },
  
  // Unfollow hashtag
  unfollowHashtag: async (tag: string): Promise<{success: boolean; message: string}> => {
    return fetchAPI(`/hashtags/${tag}/follow`, {
      method: 'DELETE',
    });
  },
};

// ============================================
// UTILITIES
// ============================================

export function formatPostTimestamp(timestamp: string): string {
  const date = new Date(timestamp);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);
  
  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;
  
  // Format as date
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function formatCount(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 1000000) return `${(count / 1000).toFixed(1)}K`;
  return `${(count / 1000000).toFixed(1)}M`;
}

export function extractHashtags(text: string): string[] {
  const regex = /#([a-zA-Z0-9_]+)/g;
  const matches = text.matchAll(regex);
  const hashtags: string[] = [];
  const seen = new Set<string>();
  
  for (const match of matches) {
    const tag = match[1].toLowerCase();
    if (!seen.has(tag)) {
      hashtags.push(tag);
      seen.add(tag);
    }
  }
  
  return hashtags;
}

export function extractMentions(text: string): string[] {
  const regex = /@([a-zA-Z0-9_]+)/g;
  const matches = text.matchAll(regex);
  const mentions: string[] = [];
  const seen = new Set<string>();
  
  for (const match of matches) {
    const username = match[1].toLowerCase();
    if (!seen.has(username)) {
      mentions.push(username);
      seen.add(username);
    }
  }
  
  return mentions;
}

export function highlightHashtagsAndMentions(text: string): (React.ReactElement | string)[] {
  // Split text by hashtags and mentions
  const parts = text.split(/(#[a-zA-Z0-9_]+|@[a-zA-Z0-9_]+)/g);
  
  return parts.map((part, index) => {
    if (part.startsWith('#')) {
      return React.createElement('a', {
        key: index,
        href: `/hashtag/${part.slice(1)}`,
        className: 'text-purple-600 dark:text-purple-400 hover:underline',
        onClick: (e: React.MouseEvent) => e.stopPropagation(),
      }, part);
    } else if (part.startsWith('@')) {
      return React.createElement('a', {
        key: index,
        href: `/profile/${part.slice(1)}`,
        className: 'text-purple-600 dark:text-purple-400 hover:underline',
        onClick: (e: React.MouseEvent) => e.stopPropagation(),
      }, part);
    }
    return part;
  });
}


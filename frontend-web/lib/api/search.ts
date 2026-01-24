/**
 * Search API Client
 * Handles user, post, and hashtag search
 */

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
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000);

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
    if (error.name === 'AbortError') {
      throw new Error('Request timeout: Server took too long to respond.');
    }
    if (error instanceof TypeError && error.message === 'Failed to fetch') {
      throw new Error('Network error: Unable to connect to server.');
    }
    throw error;
  }
}

export interface SearchUser {
  id: string;
  username: string;
  display_name: string;
  profile_picture?: string | null;
  bio?: string | null;
  location?: string | null;
  is_verified: boolean;
  followers_count?: number;
  following_count?: number;
}

export interface SearchPost {
  id: string;
  content: string;
  post_type: 'post' | 'poll' | 'article';
  author?: {
    id: string;
    username: string;
    display_name?: string;
    profile_picture?: string;
    is_verified?: boolean;
  };
  likes_count: number;
  comments_count: number;
  created_at: string;
  hashtags?: string[];
}

export interface SearchHashtag {
  tag: string;
  posts_count: number;
  is_trending?: boolean;
}

export interface SearchParams {
  q: string;
  type?: 'users' | 'posts' | 'hashtags' | 'all';
  page?: number;
  limit?: number;
  verified?: boolean;
  sort_by?: 'relevance' | 'followers' | 'recent';
}

export interface SearchResponse {
  success: boolean;
  users?: SearchUser[];
  posts?: SearchPost[];
  hashtags?: SearchHashtag[];
  total?: number;
  page?: number;
  limit?: number;
  has_more?: boolean;
}

export const searchAPI = {
  /**
   * Search users
   */
  async searchUsers(params: SearchParams): Promise<SearchResponse> {
    const queryParams = new URLSearchParams({
      q: params.q,
      page: (params.page || 1).toString(),
      limit: (params.limit || 20).toString(),
    });

    if (params.verified) {
      queryParams.append('verified', 'true');
    }

    return fetchAPI(`/search/users?${queryParams.toString()}`);
  },

  /**
   * Search posts (stub - backend may need implementation)
   */
  async searchPosts(params: SearchParams): Promise<SearchResponse> {
    const queryParams = new URLSearchParams({
      q: params.q,
      page: (params.page || 1).toString(),
      limit: (params.limit || 20).toString(),
    });

    if (params.sort_by) {
      queryParams.append('sort_by', params.sort_by);
    }

    // TODO: Implement when backend endpoint is available
    // For now, return empty results
    return {
      success: true,
      posts: [],
      total: 0,
      page: params.page || 1,
      limit: params.limit || 20,
      has_more: false,
    };
  },

  /**
   * Search hashtags (stub - backend may need implementation)
   */
  async searchHashtags(params: SearchParams): Promise<SearchResponse> {
    const queryParams = new URLSearchParams({
      q: params.q,
      limit: (params.limit || 20).toString(),
    });

    // TODO: Implement when backend endpoint is available
    // For now, return empty results
    return {
      success: true,
      hashtags: [],
      total: 0,
      has_more: false,
    };
  },

  /**
   * Universal search (all types)
   */
  async searchAll(params: SearchParams): Promise<SearchResponse> {
    const [usersResult, postsResult, hashtagsResult] = await Promise.all([
      this.searchUsers(params),
      this.searchPosts(params),
      this.searchHashtags(params),
    ]);

    return {
      success: true,
      users: usersResult.users || [],
      posts: postsResult.posts || [],
      hashtags: hashtagsResult.hashtags || [],
      total: (usersResult.total || 0) + (postsResult.total || 0) + (hashtagsResult.total || 0),
      has_more: (usersResult.has_more || false) || (postsResult.has_more || false) || (hashtagsResult.has_more || false),
    };
  },
};

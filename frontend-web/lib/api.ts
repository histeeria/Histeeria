/**
 * API Utility Functions
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Centralized API calling with automatic token refresh
 * Implements sliding window authentication
 */

interface FetchOptions extends RequestInit {
  skipTokenUpdate?: boolean;
}

import { getToken, storeToken, isTokenExpired, refreshToken } from './auth/tokenManager';

/**
 * Enhanced fetch that automatically updates tokens
 * Backend sends X-New-Token header when token needs refresh
 */
export async function apiFetch(url: string, options: FetchOptions = {}) {
  let token = getToken();
  
  // Check if token is expired and try to refresh
  if (token && isTokenExpired() && !options.skipTokenUpdate) {
    const newToken = await refreshToken();
    if (newToken) {
      token = newToken;
    } else {
      // Refresh failed, clear token
      const { clearToken } = await import('./auth/tokenManager');
      clearToken();
      // Redirect to auth if not already there
      if (typeof window !== 'undefined' && !window.location.pathname.startsWith('/auth')) {
        window.location.href = '/auth';
      }
      throw new Error('Session expired. Please log in again.');
    }
  }
  
  // Add Authorization header if token exists
  const headers = {
    ...options.headers,
    ...(token && { 'Authorization': `Bearer ${token}` }),
  };

  const response = await fetch(url, {
    ...options,
    headers,
  });

  // Check for token refresh (sliding window)
  if (!options.skipTokenUpdate) {
    const newToken = response.headers.get('X-New-Token') || response.headers.get('x-new-token');
    if (newToken) {
      storeToken(newToken);
      console.log('[Auth] Token auto-refreshed - staying logged in');
    }
  }

  return response;
}

/**
 * API call wrapper with automatic token refresh
 */
export const api = {
  get: (url: string, options?: FetchOptions) => 
    apiFetch(url, { ...options, method: 'GET' }),
  
  post: (url: string, data?: any, options?: FetchOptions) =>
    apiFetch(url, {
      ...options,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...options?.headers },
      body: data ? JSON.stringify(data) : undefined,
    }),
  
  patch: (url: string, data?: any, options?: FetchOptions) =>
    apiFetch(url, {
      ...options,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', ...options?.headers },
      body: data ? JSON.stringify(data) : undefined,
    }),
  
  delete: (url: string, data?: any, options?: FetchOptions) =>
    apiFetch(url, {
      ...options,
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json', ...options?.headers },
      body: data ? JSON.stringify(data) : undefined,
    }),
  
  upload: (url: string, formData: FormData, options?: FetchOptions) =>
    apiFetch(url, {
      ...options,
      method: 'POST',
      body: formData,
    }),
};

// Relationship API Functions
export const relationshipAPI = {
  // Follow a user
  followUser: async (userId: string) => {
    const response = await api.post(`/api/proxy/v1/relationships/follow/${userId}`);
    return response.json();
  },

  // Connect with a user
  connectWithUser: async (userId: string, message?: string) => {
    const response = await api.post(`/api/proxy/v1/relationships/connect/${userId}`, {
      message,
    });
    return response.json();
  },

  // Collaborate with a user
  collaborateWithUser: async (userId: string, message?: string) => {
    const response = await api.post(`/api/proxy/v1/relationships/collaborate/${userId}`, {
      message,
    });
    return response.json();
  },

  // Accept a relationship request
  acceptRequest: async (requestId: string) => {
    const response = await api.post(`/api/proxy/v1/relationships/requests/${requestId}/accept`);
    return response.json();
  },

  // Reject a relationship request
  rejectRequest: async (requestId: string) => {
    const response = await api.post(`/api/proxy/v1/relationships/requests/${requestId}/reject`);
    return response.json();
  },

  // Remove a relationship
  removeRelationship: async (userId: string, type: 'following' | 'connected' | 'collaborating') => {
    const response = await api.delete(`/api/proxy/v1/relationships/${userId}/${type}`);
    return response.json();
  },

  // Get relationship status with a user
  getRelationshipStatus: async (userId: string) => {
    const response = await api.get(`/api/proxy/v1/relationships/status/${userId}`);
    return response.json();
  },

  // Get relationship stats for current user
  getRelationshipStats: async () => {
    const response = await api.get('/api/proxy/v1/relationships/stats');
    return response.json();
  },

  // Get rate limit status
  getRateLimitStatus: async (action?: 'follow' | 'connect' | 'collaborate') => {
    const url = action
      ? `/api/proxy/v1/relationships/rate-limit-status?action=${action}`
      : '/api/proxy/v1/relationships/rate-limit-status';
    const response = await api.get(url);
    return response.json();
  },

  // Get followers list
  getFollowers: async (userId?: string, page: number = 1, limit: number = 20) => {
    const params = userId ? `?user_id=${userId}&page=${page}&limit=${limit}` : `?page=${page}&limit=${limit}`;
    const response = await api.get(`/api/proxy/v1/relationships/followers${params}`);
    return response.json();
  },

  // Get following list
  getFollowing: async (userId?: string, page: number = 1, limit: number = 20) => {
    const params = userId ? `?user_id=${userId}&page=${page}&limit=${limit}` : `?page=${page}&limit=${limit}`;
    const response = await api.get(`/api/proxy/v1/relationships/following${params}`);
    return response.json();
  },

  // Get connections list
  getConnections: async (userId?: string, page: number = 1, limit: number = 20) => {
    const params = userId ? `?user_id=${userId}&page=${page}&limit=${limit}` : `?page=${page}&limit=${limit}`;
    const response = await api.get(`/api/proxy/v1/relationships/connections${params}`);
    return response.json();
  },

  // Get collaborators list
  getCollaborators: async (userId?: string, page: number = 1, limit: number = 20) => {
    const params = userId ? `?user_id=${userId}&page=${page}&limit=${limit}` : `?page=${page}&limit=${limit}`;
    const response = await api.get(`/api/proxy/v1/relationships/collaborators${params}`);
    return response.json();
  },

  // Get pending requests
  getPendingRequests: async (page: number = 1, limit: number = 20) => {
    const response = await api.get(`/api/proxy/v1/relationships/pending?page=${page}&limit=${limit}`);
    return response.json();
  },
};


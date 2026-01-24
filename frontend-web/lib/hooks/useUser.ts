'use client';

/**
 * useUser Hook
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Centralized user profile data fetching and state management
 * Optimized with caching and request deduplication
 */

import { useState, useEffect } from 'react';

// Global cache to prevent duplicate requests
let cachedUser: UserProfile | null = null;
let cacheTimestamp: number = 0;
let inflightRequest: Promise<any> | null = null;
const CACHE_DURATION = 10000; // 10 seconds

export interface UserProfile {
  id: string;
  email: string;
  username: string;
  display_name: string;
  age: number;
  profile_picture: string | null;
  created_at: string;
  updated_at: string;
  
  // Profile System Phase 1 Fields
  bio?: string | null;
  location?: string | null;
  gender?: string | null;
  gender_custom?: string | null;
  website?: string | null;
  is_verified?: boolean;
  profile_privacy?: string;
  field_visibility?: {
    location: boolean;
    gender: boolean;
    age: boolean;
    website: boolean;
    joined_date: boolean;
    email: boolean;
    [key: string]: boolean; // Index signature for dynamic access
  };
  stat_visibility?: {
    posts: boolean;
    projects: boolean;
    followers: boolean;
    following: boolean;
    connections: boolean;
    collaborators: boolean;
    [key: string]: boolean; // Index signature for dynamic access
  };
  story?: string | null;
  ambition?: string | null;
  posts_count?: number;
  projects_count?: number;
  followers_count?: number;
  following_count?: number;
  social_links?: {
    twitter?: string | null;
    instagram?: string | null;
    facebook?: string | null;
    linkedin?: string | null;
    github?: string | null;
    youtube?: string | null;
  };
}

export function useUser() {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchProfile = async (skipCache = false) => {
    try {
      // Check cache first (unless explicitly skipped)
      if (!skipCache && cachedUser && Date.now() - cacheTimestamp < CACHE_DURATION) {
        console.log('[useUser] Using cached data');
        setUser(cachedUser);
        setLoading(false);
        return;
      }

      // If there's already a request in flight, wait for it
      if (inflightRequest) {
        console.log('[useUser] Waiting for inflight request');
        const data = await inflightRequest;
        setUser(data);
        setLoading(false);
        return;
      }

      setLoading(true);
      const token = localStorage.getItem('token');
      
      if (!token) {
        setError('Not authenticated');
        setLoading(false);
        return;
      }

      // Create the request promise and store it
      inflightRequest = (async () => {
        try {
          const response = await fetch('/api/proxy/v1/account/profile', {
            headers: { 
              'Authorization': `Bearer ${token}`,
            },
          });
          
          // Auto-refresh token (sliding window authentication)
          const newToken = response.headers.get('x-new-token');
          if (newToken) {
            localStorage.setItem('token', newToken);
          }

          if (response.ok) {
            const data = await response.json();
            return data.user;
          } else {
            const data = await response.json().catch(() => ({ message: 'Failed to fetch profile' }));
            throw new Error(data.message || 'Failed to fetch profile');
          }
        } catch (error) {
          // Handle network errors
          if (error instanceof TypeError && error.message === 'Failed to fetch') {
            console.error('[useUser] Network error:', error);
            throw new Error('Network error: Unable to connect to server');
          }
          throw error;
        }
      })();

      const userData = await inflightRequest;
      console.log('[useUser] Fetched user data');
      
      // Update cache
      cachedUser = userData;
      cacheTimestamp = Date.now();
      
      setUser(userData);
      setError(null);
    } catch (err: any) {
      setError(err.message || 'Network error occurred');
      console.error('Error fetching profile:', err);
    } finally {
      setLoading(false);
      inflightRequest = null; // Clear inflight request
    }
  };

  useEffect(() => {
    fetchProfile();
  }, []);

  return { user, loading, error, refetch: fetchProfile, setUser };
}


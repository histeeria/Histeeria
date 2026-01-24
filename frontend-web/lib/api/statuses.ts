// ============================================
// STATUSES API
// Instagram-like 24-hour stories/statuses
// ============================================

const API_BASE = '/api/proxy/v1';

async function fetchAPI<T = any>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const token = localStorage.getItem('token');
  
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  
  // Remove Content-Type for FormData
  if (options.body instanceof FormData) {
    delete headers['Content-Type'];
  }
  
  try {
    const response = await fetch(`${API_BASE}${endpoint}`, {
      ...options,
      headers: {
        ...headers,
        ...options.headers,
      },
    });
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: 'Request failed' }));
      const message = error.message || error.error || `HTTP ${response.status}`;
      throw new Error(message);
    }
    
    return response.json();
  } catch (error) {
    if (error instanceof TypeError && error.message === 'Failed to fetch') {
      console.error(`[fetchAPI] Network error for ${endpoint}:`, error);
      throw new Error('Network error: Unable to connect to server. Please check your connection.');
    }
    throw error;
  }
}

// ============================================
// TYPES
// ============================================

export interface Status {
  id: string;
  user_id: string;
  status_type: 'text' | 'image' | 'video';
  content?: string;
  media_url?: string;
  media_type?: string;
  background_color: string;
  views_count: number;
  reactions_count: number;
  comments_count: number;
  expires_at: string;
  created_at: string;
  updated_at: string;
  author?: {
    id: string;
    username: string;
    display_name: string;
    profile_picture?: string;
  };
  is_viewed: boolean;
  user_reaction?: string; // '👍', '💯', '❤️', '🤝', '💡'
  comments?: StatusComment[];
}

export interface StatusComment {
  id: string;
  status_id: string;
  user_id: string;
  content: string;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
  author?: {
    id: string;
    username: string;
    display_name: string;
    profile_picture?: string;
  };
}

export interface StatusReaction {
  id: string;
  status_id: string;
  user_id: string;
  emoji: string; // '👍', '💯', '❤️', '🤝', '💡'
  created_at: string;
  user?: {
    id: string;
    username: string;
    display_name: string;
    profile_picture?: string;
  };
}

export interface CreateStatusRequest {
  status_type: 'text' | 'image' | 'video';
  content?: string;
  media_url?: string;
  media_type?: string;
  background_color?: string;
}

export interface ReactToStatusRequest {
  emoji: '👍' | '💯' | '❤️' | '🤝' | '💡';
}

export interface CreateStatusCommentRequest {
  content: string;
}

export interface StatusesResponse {
  success: boolean;
  statuses: Status[];
  total: number;
  has_more: boolean;
}

export interface StatusResponse {
  success: boolean;
  status: Status;
  message?: string;
}

export interface StatusCommentsResponse {
  success: boolean;
  comments: StatusComment[];
  total: number;
  has_more: boolean;
}

// ============================================
// API FUNCTIONS
// ============================================

/**
 * Get statuses for feed (from followed users + own)
 */
export async function getStatusesForFeed(limit = 100): Promise<Status[]> {
  const response = await fetchAPI<StatusesResponse>(`/statuses/feed?limit=${limit}`);
  return response.statuses;
}

/**
 * Get user statuses
 */
export async function getUserStatuses(userId: string, limit = 50): Promise<Status[]> {
  const response = await fetchAPI<StatusesResponse>(`/statuses/user/${userId}?limit=${limit}`);
  return response.statuses;
}

/**
 * Get single status by ID
 */
export async function getStatus(statusId: string): Promise<Status> {
  const response = await fetchAPI<StatusResponse>(`/statuses/${statusId}`);
  return response.status;
}

/**
 * Create a new status
 */
export async function createStatus(data: CreateStatusRequest): Promise<Status> {
  const response = await fetchAPI<StatusResponse>('/statuses', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(data),
  });
  return response.status;
}

/**
 * Delete a status
 */
export async function deleteStatus(statusId: string): Promise<void> {
  await fetchAPI(`/statuses/${statusId}`, {
    method: 'DELETE',
  });
}

/**
 * Record a view on a status
 */
export async function viewStatus(statusId: string): Promise<void> {
  await fetchAPI(`/statuses/${statusId}/view`, {
    method: 'POST',
  });
}

/**
 * React to a status
 */
export async function reactToStatus(statusId: string, emoji: ReactToStatusRequest['emoji']): Promise<void> {
  await fetchAPI(`/statuses/${statusId}/react`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ emoji }),
  });
}

/**
 * Remove reaction from a status
 */
export async function removeStatusReaction(statusId: string): Promise<void> {
  await fetchAPI(`/statuses/${statusId}/react`, {
    method: 'DELETE',
  });
}

/**
 * Get reactions for a status
 */
export async function getStatusReactions(statusId: string, limit = 50): Promise<StatusReaction[]> {
  const response = await fetchAPI<{ success: boolean; reactions: StatusReaction[] }>(
    `/statuses/${statusId}/reactions?limit=${limit}`
  );
  return response.reactions;
}

/**
 * Create a comment on a status
 */
export async function createStatusComment(statusId: string, content: string): Promise<StatusComment> {
  const response = await fetchAPI<{ success: boolean; comment: StatusComment; message: string }>(
    `/statuses/${statusId}/comments`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ content }),
    }
  );
  return response.comment;
}

/**
 * Get comments for a status
 */
export async function getStatusComments(statusId: string, limit = 50, offset = 0): Promise<{
  comments: StatusComment[];
  total: number;
  hasMore: boolean;
}> {
  const response = await fetchAPI<StatusCommentsResponse>(
    `/statuses/${statusId}/comments?limit=${limit}&offset=${offset}`
  );
  return {
    comments: response.comments,
    total: response.total,
    hasMore: response.has_more,
  };
}

/**
 * Delete a status comment
 */
export async function deleteStatusComment(commentId: string): Promise<void> {
  await fetchAPI(`/statuses/comments/${commentId}`, {
    method: 'DELETE',
  });
}

/**
 * Create a message reply to a status
 */
export async function createStatusMessageReply(statusId: string, toUserId: string): Promise<{ reply_id: string }> {
  const response = await fetchAPI<{ success: boolean; reply_id: string; message: string }>(
    `/statuses/${statusId}/message-reply`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ to_user_id: toUserId }),
    }
  );
  return { reply_id: response.reply_id };
}

/**
 * Upload status image
 */
export async function uploadStatusImage(file: File, quality: 'standard' | 'hd' = 'standard'): Promise<{
  media_url: string;
  media_type: string;
}> {
  const formData = new FormData();
  formData.append('file', file);

  const response = await fetchAPI<{ success: boolean; media_url: string; media_type: string }>(
    `/statuses/upload-image?quality=${quality}`,
    {
      method: 'POST',
      body: formData,
    }
  );
  return {
    media_url: response.media_url,
    media_type: response.media_type,
  };
}

/**
 * Upload status video
 */
export async function uploadStatusVideo(file: File): Promise<{
  media_url: string;
  media_type: string;
}> {
  const formData = new FormData();
  formData.append('file', file);

  const response = await fetchAPI<{ success: boolean; media_url: string; media_type: string }>(
    '/statuses/upload-video',
    {
      method: 'POST',
      body: formData,
    }
  );
  return {
    media_url: response.media_url,
    media_type: response.media_type,
  };
}

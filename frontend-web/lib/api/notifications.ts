/**
 * Notifications API Client
 * Handles all notification-related API calls
 */

const API_BASE_URL = '/api/proxy/v1';

export interface NotificationActor {
  id: string;
  username: string;
  display_name: string;
  profile_picture?: string;
  is_verified: boolean;
}

export interface Notification {
  id: string;
  type: string;
  category: string;
  title: string;
  message?: string;
  actor?: NotificationActor;
  action_url?: string;
  is_read: boolean;
  is_actionable: boolean;
  action_type?: string;
  action_taken: boolean;
  metadata?: Record<string, any>;
  created_at: string;
}

export type { Notification as NotificationType };

export interface NotificationListResponse {
  success: boolean;
  notifications: Notification[];
  total: number;
  unread: number;
  limit: number;
  offset: number;
}

export interface NotificationCountResponse {
  success: boolean;
  total: number;
  category_counts: Record<string, number>;
}

export interface NotificationPreferences {
  user_id: string;
  email_enabled: boolean;
  email_types: Record<string, boolean>;
  email_frequency: 'instant' | 'daily' | 'weekly' | 'never';
  in_app_enabled: boolean;
  push_enabled: boolean;
  inline_actions_enabled: boolean;
  categories_enabled: Record<string, boolean>;
  updated_at: string;
}

export const notificationAPI = {
  /**
   * Get notifications list
   */
  async getNotifications(params?: {
    category?: string;
    unread?: boolean;
    limit?: number;
    offset?: number;
  }): Promise<NotificationListResponse> {
    const queryParams = new URLSearchParams();
    if (params?.category) queryParams.set('category', params.category);
    if (params?.unread !== undefined) queryParams.set('unread', params.unread.toString());
    if (params?.limit) queryParams.set('limit', params.limit.toString());
    if (params?.offset) queryParams.set('offset', params.offset.toString());

    try {
      const response = await fetch(
        `${API_BASE_URL}/notifications?${queryParams.toString()}`,
        {
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('token')}`,
            'Content-Type': 'application/json',
          },
        }
      );

      if (!response.ok) {
        throw new Error('Failed to fetch notifications');
      }

      return response.json();
    } catch (error) {
      if (error instanceof TypeError && error.message === 'Failed to fetch') {
        console.error('[notificationsAPI] Network error:', error);
        throw new Error('Network error: Unable to connect to server');
      }
      throw error;
    }
  },

  /**
   * Get unread count
   */
  async getUnreadCount(category?: string): Promise<NotificationCountResponse> {
    const queryParams = new URLSearchParams();
    if (category) queryParams.set('category', category);

    try {
      const response = await fetch(
        `${API_BASE_URL}/notifications/unread-count?${queryParams.toString()}`,
        {
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('token')}`,
            'Content-Type': 'application/json',
          },
        }
      );

      if (!response.ok) {
        throw new Error('Failed to fetch unread count');
      }

      return response.json();
    } catch (error) {
      if (error instanceof TypeError && error.message === 'Failed to fetch') {
        console.error('[notificationsAPI] Network error in getUnreadCount:', error);
        throw new Error('Network error: Unable to connect to server');
      }
      throw error;
    }
  },

  /**
   * Mark notification as read
   */
  async markAsRead(notificationId: string): Promise<{ success: boolean; message: string }> {
    const response = await fetch(
      `${API_BASE_URL}/notifications/${notificationId}/read`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!response.ok) {
      throw new Error('Failed to mark as read');
    }

    return response.json();
  },

  /**
   * Mark all notifications as read
   */
  async markAllAsRead(category?: string): Promise<{ success: boolean; message: string }> {
    const response = await fetch(
      `${API_BASE_URL}/notifications/read-all`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ category }),
      }
    );

    if (!response.ok) {
      throw new Error('Failed to mark all as read');
    }

    return response.json();
  },

  /**
   * Delete notification
   */
  async deleteNotification(notificationId: string): Promise<{ success: boolean; message: string }> {
    const response = await fetch(
      `${API_BASE_URL}/notifications/${notificationId}`,
      {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!response.ok) {
      throw new Error('Failed to delete notification');
    }

    return response.json();
  },

  /**
   * Take action on notification
   */
  async takeAction(
    notificationId: string,
    actionType: string
  ): Promise<{ success: boolean; message: string }> {
    const response = await fetch(
      `${API_BASE_URL}/notifications/${notificationId}/action`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ action_type: actionType }),
      }
    );

    if (!response.ok) {
      throw new Error('Failed to take action');
    }

    return response.json();
  },

  /**
   * Get notification preferences
   */
  async getPreferences(): Promise<{ success: boolean; preferences: NotificationPreferences }> {
    const response = await fetch(
      `${API_BASE_URL}/notifications/preferences`,
      {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!response.ok) {
      throw new Error('Failed to fetch preferences');
    }

    return response.json();
  },

  /**
   * Update notification preferences
   */
  async updatePreferences(
    preferences: Partial<Omit<NotificationPreferences, 'user_id' | 'updated_at'>>
  ): Promise<{ success: boolean; message: string }> {
    const response = await fetch(
      `${API_BASE_URL}/notifications/preferences`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(preferences),
      }
    );

    if (!response.ok) {
      throw new Error('Failed to update preferences');
    }

    return response.json();
  },
};


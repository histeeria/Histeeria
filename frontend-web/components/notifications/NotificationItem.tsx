'use client';

/**
 * Notification Item Component
 * Displays a single notification with inline actions
 */

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { formatDistanceToNow } from 'date-fns';
import { Check, X, UserPlus, Trash2 } from 'lucide-react';
import { Avatar } from '@/components/ui/Avatar';
import type { Notification } from '@/lib/api/notifications';
import { notificationAPI } from '@/lib/api/notifications';
import { useNotifications } from '@/lib/contexts/NotificationContext';
import { relationshipAPI } from '@/lib/api';

interface NotificationItemProps {
  notification: Notification;
  onClose: () => void;
}

export default function NotificationItem({ notification, onClose }: NotificationItemProps) {
  const [isActing, setIsActing] = useState(false);
  const [actionTaken, setActionTaken] = useState(notification.action_taken);
  const router = useRouter();
  const { markAsRead, deleteNotification, refreshCount } = useNotifications();

  const handleClick = async () => {
    if (!notification.is_read) {
      await markAsRead(notification.id);
    }

    if (notification.action_url) {
      router.push(notification.action_url);
      onClose();
    }
  };

  const handleAction = async (actionType: string) => {
    if (isActing || actionTaken) return;
    setIsActing(true);

    try {
      // First, mark action as taken in database (prevents duplicate actions)
      await notificationAPI.takeAction(notification.id, actionType);
      
      // Then execute the actual action
      if (actionType === 'follow_back' && notification.actor) {
        await relationshipAPI.followUser(notification.actor.id);
      } else if (actionType === 'accept_connection') {
        const requestId = notification.metadata?.request_id;
        if (requestId) {
          await relationshipAPI.acceptRequest(requestId);
        }
      } else if (actionType === 'reject_connection') {
        const requestId = notification.metadata?.request_id;
        if (requestId) {
          await relationshipAPI.rejectRequest(requestId);
        }
      } else if (actionType === 'accept_collaboration') {
        const requestId = notification.metadata?.request_id;
        if (requestId) {
          await relationshipAPI.acceptRequest(requestId);
        }
      } else if (actionType === 'reject_collaboration') {
        const requestId = notification.metadata?.request_id;
        if (requestId) {
          await relationshipAPI.rejectRequest(requestId);
        }
      }

      // Update UI state
      setActionTaken(true);
      await refreshCount();
    } catch (error) {
      console.error('Action failed:', error);
      // Revert action_taken state if the action failed
      setActionTaken(false);
    } finally {
      setIsActing(false);
    }
  };

  const handleDelete = async (e: React.MouseEvent) => {
    e.stopPropagation();
    await deleteNotification(notification.id);
  };

  const timeAgo = formatDistanceToNow(new Date(notification.created_at), { addSuffix: true });

  return (
    <div
      onClick={handleClick}
      className={`
        group relative px-5 py-4 transition-all cursor-pointer
        ${notification.is_read 
          ? 'hover:bg-neutral-50 dark:hover:bg-neutral-800/50' 
          : 'bg-blue-50/50 dark:bg-blue-900/10 hover:bg-blue-50 dark:hover:bg-blue-900/20'
        }
      `}
    >
      {/* Unread Indicator */}
      {!notification.is_read && (
        <div className="absolute left-0 top-0 bottom-0 w-1 bg-brand-purple-600" />
      )}

      <div className="flex gap-4">
        {/* Actor Avatar */}
        {notification.actor && (
          <div className="flex-shrink-0 pt-0.5">
            <Avatar
              src={notification.actor.profile_picture}
              alt={notification.actor.display_name}
              size="md"
              className="w-11 h-11"
            />
          </div>
        )}

        {/* Content */}
        <div className="flex-1 min-w-0">
          {/* Title */}
          <p className={`text-sm leading-snug ${
            notification.is_read 
              ? 'text-neutral-700 dark:text-neutral-300' 
              : 'text-neutral-900 dark:text-neutral-50 font-semibold'
          }`}>
            {notification.title}
          </p>

          {/* Message */}
          {notification.message && (
            <p className="text-sm text-neutral-600 dark:text-neutral-400 mt-1 leading-snug">
              {notification.message}
            </p>
          )}

          {/* Timestamp */}
          <p className="text-xs text-neutral-500 dark:text-neutral-500 mt-1.5">
            {timeAgo}
          </p>

          {/* Inline Actions */}
          {notification.is_actionable && !actionTaken && (
            <div className="flex flex-wrap gap-2 mt-3">
              {notification.action_type === 'follow_back' && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    handleAction('follow_back');
                  }}
                  disabled={isActing}
                  className="flex items-center gap-1.5 px-4 py-2 bg-brand-purple-600 hover:bg-brand-purple-700 text-white text-sm font-medium rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <UserPlus className="w-4 h-4" />
                  Follow Back
                </button>
              )}

              {notification.action_type === 'accept_connection' && (
                <>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleAction('accept_connection');
                    }}
                    disabled={isActing}
                    className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Check className="w-4 h-4" />
                    Accept
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleAction('reject_connection');
                    }}
                    disabled={isActing}
                    className="flex items-center gap-1.5 px-4 py-2 bg-white dark:bg-neutral-800 hover:bg-neutral-100 dark:hover:bg-neutral-700 text-neutral-700 dark:text-neutral-300 text-sm font-medium rounded-lg border border-neutral-300 dark:border-neutral-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <X className="w-4 h-4" />
                    Decline
                  </button>
                </>
              )}

              {notification.action_type === 'accept_collaboration' && (
                <>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleAction('accept_collaboration');
                    }}
                    disabled={isActing}
                    className="flex items-center gap-1.5 px-4 py-2 bg-yellow-600 hover:bg-yellow-700 text-white text-sm font-medium rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Check className="w-4 h-4" />
                    Accept
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleAction('reject_collaboration');
                    }}
                    disabled={isActing}
                    className="flex items-center gap-1.5 px-4 py-2 bg-white dark:bg-neutral-800 hover:bg-neutral-100 dark:hover:bg-neutral-700 text-neutral-700 dark:text-neutral-300 text-sm font-medium rounded-lg border border-neutral-300 dark:border-neutral-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <X className="w-4 h-4" />
                    Decline
                  </button>
                </>
              )}
            </div>
          )}

          {/* Action Taken Indicator */}
          {actionTaken && (
            <div className="mt-3 inline-flex items-center gap-1.5 px-3 py-1.5 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg">
              <Check className="w-3.5 h-3.5 text-green-600 dark:text-green-400" />
              <span className="text-xs text-green-700 dark:text-green-300 font-medium">Action completed</span>
            </div>
          )}
        </div>

        {/* Delete Button */}
        <button
          onClick={handleDelete}
          className="flex-shrink-0 opacity-0 group-hover:opacity-100 p-2 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-all"
          title="Delete notification"
        >
          <Trash2 className="w-4 h-4 text-neutral-400 dark:text-neutral-500 hover:text-red-600 dark:hover:text-red-400" />
        </button>
      </div>
    </div>
  );
}


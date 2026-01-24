'use client';

/**
 * Notification Bell Component
 * Displays bell icon with unread count badge
 * Navigates to /notifications page (Instagram-style)
 */

import { useRouter, usePathname } from 'next/navigation';
import { Bell } from 'lucide-react';
import { useNotifications } from '@/lib/contexts/NotificationContext';

export default function NotificationBell() {
  const router = useRouter();
  const pathname = usePathname();
  const { unreadCount, isConnected } = useNotifications();

  const handleClick = () => {
    router.push('/notifications');
  };

  const isActive = pathname === '/notifications';

  return (
    <button
      onClick={handleClick}
      className={`
        relative p-2 rounded-lg transition-all
        ${isActive 
          ? 'bg-brand-purple-100 dark:bg-brand-purple-900/30' 
          : 'hover:bg-neutral-100 dark:hover:bg-neutral-800'
        }
      `}
      aria-label="Notifications"
    >
      <Bell 
        className={`w-5 h-5 transition-colors ${
          isActive 
            ? 'text-brand-purple-600 dark:text-brand-purple-400' 
            : 'text-neutral-700 dark:text-neutral-300'
        }`}
        strokeWidth={isActive ? 2.5 : 2}
        fill={isActive ? 'currentColor' : 'none'}
      />
      
      {/* Unread Badge */}
      {unreadCount > 0 && (
        <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] flex items-center justify-center bg-red-500 text-white text-xs font-semibold rounded-full px-1">
          {unreadCount > 99 ? '99+' : unreadCount}
        </span>
      )}

      {/* Connection Indicator */}
      {!isConnected && !isActive && (
        <span className="absolute bottom-1 right-1 w-2 h-2 bg-yellow-500 rounded-full border border-white dark:border-neutral-900" />
      )}
    </button>
  );
}


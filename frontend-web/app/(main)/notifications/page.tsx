'use client';

/**
 * Notifications Page
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * Instagram-style full page notifications
 */

import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { Card } from '@/components/ui/Card';
import { CheckCheck, Settings, Bell as BellIcon } from 'lucide-react';
import { useNotifications } from '@/lib/contexts/NotificationContext';
import NotificationItem from '@/components/notifications/NotificationItem';
import CategoryTabs from '@/components/notifications/CategoryTabs';

export default function NotificationsPage() {
  const [activeCategory, setActiveCategory] = useState<string>('all');
  const router = useRouter();
  const scrollRef = useRef<HTMLDivElement>(null);
  
  const {
    notifications,
    unreadCount,
    categoryCounts,
    isLoading,
    fetchNotifications,
    loadMore,
    markAllAsRead,
  } = useNotifications();

  // Fetch notifications when category changes
  useEffect(() => {
    const category = activeCategory === 'all' ? undefined : activeCategory;
    fetchNotifications(category);
  }, [activeCategory, fetchNotifications]);

  // Mobile-first: mark all as read when opening the notifications page
  useEffect(() => {
    const category = activeCategory === 'all' ? undefined : activeCategory;
    // Fire and forget; UI will sync via context
    markAllAsRead(category);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Infinite scroll
  useEffect(() => {
    const scrollContainer = scrollRef.current;
    if (!scrollContainer) return;

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
      if (scrollHeight - scrollTop <= clientHeight * 1.5 && !isLoading) {
        loadMore();
      }
    };

    scrollContainer.addEventListener('scroll', handleScroll);
    return () => scrollContainer.removeEventListener('scroll', handleScroll);
  }, [isLoading, loadMore]);

  const handleMarkAllAsRead = async () => {
    const category = activeCategory === 'all' ? undefined : activeCategory;
    await markAllAsRead(category);
  };

  const handleSettingsClick = () => {
    router.push('/settings');
  };

  const currentCategoryCount = activeCategory === 'all' 
    ? unreadCount 
    : categoryCounts[activeCategory] || 0;

  return (
    <MainLayout>
      <div className="max-w-3xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-neutral-900 dark:text-neutral-50">
              Notifications
            </h1>
            {currentCategoryCount > 0 && (
              <p className="text-sm text-neutral-500 dark:text-neutral-400 mt-1">
                {currentCategoryCount} unread {currentCategoryCount === 1 ? 'notification' : 'notifications'}
              </p>
            )}
          </div>
          
          <div className="flex items-center gap-2">
            {/* Mark All as Read */}
            {currentCategoryCount > 0 && (
              <button
                onClick={handleMarkAllAsRead}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-lg transition-colors"
                title="Mark all as read"
              >
                <CheckCheck className="w-4 h-4" />
                <span className="hidden sm:inline">Mark all read</span>
              </button>
            )}

            {/* Settings */}
            <button
              onClick={handleSettingsClick}
              className="p-2 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-lg transition-colors"
              title="Notification settings"
            >
              <Settings className="w-5 h-5 text-neutral-600 dark:text-neutral-400" />
            </button>
          </div>
        </div>

        {/* Category Tabs Card */}
        <Card variant="solid" hoverable={false} className="mb-4">
          <CategoryTabs
            activeCategory={activeCategory}
            onCategoryChange={setActiveCategory}
            categoryCounts={categoryCounts}
            totalCount={unreadCount}
          />
        </Card>

        {/* Notifications List */}
        <Card variant="solid" hoverable={false}>
          {isLoading && notifications.length === 0 ? (
            <div className="py-16 text-center">
              <div className="inline-block w-10 h-10 border-3 border-brand-purple-600 border-t-transparent rounded-full animate-spin mb-4" />
              <p className="text-sm font-medium text-neutral-600 dark:text-neutral-400">Loading notifications...</p>
            </div>
          ) : notifications.length === 0 ? (
            <div className="py-16 text-center">
              <div className="inline-flex items-center justify-center w-20 h-20 bg-neutral-100 dark:bg-neutral-800 rounded-full mb-4">
                <BellIcon className="w-10 h-10 text-neutral-400 dark:text-neutral-600" />
              </div>
              <p className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-1">
                {activeCategory === 'all' ? 'All caught up!' : 'No notifications yet'}
              </p>
              <p className="text-sm text-neutral-500 dark:text-neutral-400">
                {activeCategory === 'all' 
                  ? 'You have no notifications at the moment' 
                  : `No ${activeCategory} notifications to show`
                }
              </p>
            </div>
          ) : (
            <div
              ref={scrollRef}
              className="divide-y divide-neutral-100 dark:divide-neutral-800"
            >
              {notifications.map((notification) => (
                <NotificationItem
                  key={notification.id}
                  notification={notification}
                  onClose={() => {}}
                />
              ))}
              
              {isLoading && (
                <div className="py-6 text-center">
                  <div className="inline-block w-6 h-6 border-2 border-brand-purple-600 border-t-transparent rounded-full animate-spin" />
                </div>
              )}
            </div>
          )}
        </Card>
      </div>
    </MainLayout>
  );
}


'use client';

/**
 * Notifications Settings Page
 * Instagram-style mobile-first design
 */

import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { ArrowLeft } from 'lucide-react';
import NotificationSettings from '@/components/settings/NotificationSettings';

export default function NotificationsSettingsPage() {
  const router = useRouter();

  return (
    <MainLayout>
      <div className="min-h-screen bg-white dark:bg-neutral-950">
        <div className="w-full">
          {/* Header */}
          <div className="flex items-center gap-4 px-4 py-4 border-b border-neutral-200 dark:border-neutral-800">
            <button
              onClick={() => router.push('/settings')}
              className="p-1 -ml-1 rounded-full transition-colors"
            >
              <ArrowLeft className="w-6 h-6 text-neutral-900 dark:text-neutral-50" />
            </button>
            <h1 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50">
              Notifications
            </h1>
          </div>

          <div className="w-full px-4 py-6">
            <NotificationSettings />
          </div>
        </div>
      </div>
    </MainLayout>
  );
}

'use client';

/**
 * Language Settings Page
 * Instagram-style: transparent, full-width, no borders
 */

import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { ArrowLeft } from 'lucide-react';

export default function LanguageSettingsPage() {
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
              Language
            </h1>
          </div>

          <div className="w-full px-4 py-6 space-y-4">
            <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
              Language & Region
            </h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-neutral-700 dark:text-neutral-300 mb-2">
                  Display Language
                </label>
                <select className="w-full px-4 py-3 rounded-lg border border-neutral-200 dark:border-neutral-800 bg-transparent text-neutral-900 dark:text-neutral-50 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 focus:border-brand-purple-500 cursor-pointer">
                  <option>English (US)</option>
                  <option>English (UK)</option>
                  <option>Spanish</option>
                  <option>French</option>
                  <option>German</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 dark:text-neutral-300 mb-2">
                  Time Zone
                </label>
                <select className="w-full px-4 py-3 rounded-lg border border-neutral-200 dark:border-neutral-800 bg-transparent text-neutral-900 dark:text-neutral-50 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 focus:border-brand-purple-500 cursor-pointer">
                  <option>Pacific Time (PT)</option>
                  <option>Eastern Time (ET)</option>
                  <option>Central Time (CT)</option>
                  <option>Mountain Time (MT)</option>
                </select>
              </div>
            </div>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}

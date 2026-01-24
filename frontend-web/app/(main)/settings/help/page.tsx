'use client';

/**
 * Help & Support Settings Page
 * Instagram-style: transparent, full-width, no borders
 */

import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { ArrowLeft } from 'lucide-react';

export default function HelpSettingsPage() {
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
              Help & Support
            </h1>
          </div>

          <div className="w-full">
            {/* Get Help */}
            <div className="px-4 py-6 space-y-1 border-b border-neutral-200 dark:border-neutral-800">
              <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50 mb-4">
                Get Help
              </h3>
              <button className="w-full text-left px-3 py-3 rounded-lg transition-colors">
                <p className="font-medium text-neutral-900 dark:text-neutral-50">Help Center</p>
                <p className="text-sm text-neutral-600 dark:text-neutral-400">Browse articles and guides</p>
              </button>
              <button className="w-full text-left px-3 py-3 rounded-lg transition-colors">
                <p className="font-medium text-neutral-900 dark:text-neutral-50">Contact Support</p>
                <p className="text-sm text-neutral-600 dark:text-neutral-400">Get help from our team</p>
              </button>
              <button className="w-full text-left px-3 py-3 rounded-lg transition-colors">
                <p className="font-medium text-neutral-900 dark:text-neutral-50">Report a Problem</p>
                <p className="text-sm text-neutral-600 dark:text-neutral-400">Let us know about issues</p>
              </button>
            </div>

            {/* About */}
            <div className="px-4 py-6 space-y-2">
              <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50 mb-1">
                About
              </h3>
              <p className="text-sm text-neutral-600 dark:text-neutral-400 mb-4">
                Version 1.0.0 • Built by Hamza Hafeez
              </p>
              <a href="#" className="block text-sm text-brand-purple-600 dark:text-brand-purple-400 hover:underline">
                Terms of Service
              </a>
              <a href="#" className="block text-sm text-brand-purple-600 dark:text-brand-purple-400 hover:underline">
                Privacy Policy
              </a>
              <a href="#" className="block text-sm text-brand-purple-600 dark:text-brand-purple-400 hover:underline">
                Community Guidelines
              </a>
            </div>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}

'use client';

/**
 * Offline Fallback Page
 * Shown when user is offline and page isn't cached
 */

import { WifiOff } from 'lucide-react';

export default function OfflinePage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-neutral-50 to-neutral-100 dark:from-neutral-950 dark:to-neutral-900 p-4">
      <div className="text-center max-w-md">
        {/* Icon */}
        <div className="w-24 h-24 mx-auto mb-6 bg-neutral-200 dark:bg-neutral-800 rounded-full flex items-center justify-center">
          <WifiOff className="w-12 h-12 text-neutral-500 dark:text-neutral-400" />
        </div>

        {/* Heading */}
        <h1 className="text-2xl font-bold text-neutral-900 dark:text-white mb-3">
          You're Offline
        </h1>

        {/* Description */}
        <p className="text-neutral-600 dark:text-neutral-400 mb-8 leading-relaxed">
          It looks like you've lost your internet connection. Some features may not work until you're back online.
        </p>

        {/* Reload Button */}
        <button
          onClick={() => window.location.reload()}
          className="px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white font-semibold rounded-xl transition-colors shadow-lg"
        >
          Try Again
        </button>

        {/* Footer */}
        <p className="mt-12 text-sm text-neutral-500 dark:text-neutral-500">
          App made by <span className="font-semibold text-neutral-700 dark:text-neutral-300">Hamza Hafeez</span>
        </p>
      </div>
    </div>
  );
}


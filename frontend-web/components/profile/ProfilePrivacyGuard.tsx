'use client';

import { Lock, User } from 'lucide-react';

interface ProfilePrivacyGuardProps {
  isLoading: boolean;
  error: string | null;
  children: React.ReactNode;
}

export default function ProfilePrivacyGuard({ isLoading, error, children }: ProfilePrivacyGuardProps) {
  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-neutral-50 dark:bg-neutral-950">
        <div className="text-center">
          <div className="w-16 h-16 mx-auto mb-4 border-4 border-brand-purple-200 border-t-brand-purple-600 rounded-full animate-spin"></div>
          <p className="text-neutral-600 dark:text-neutral-400">Loading profile...</p>
        </div>
      </div>
    );
  }

  if (error) {
    const is404 = error.toLowerCase().includes('not found');
    const is403 = error.toLowerCase().includes('forbidden') || error.toLowerCase().includes('private');

    return (
      <div className="min-h-screen flex items-center justify-center bg-neutral-50 dark:bg-neutral-950 p-4">
        <div className="text-center max-w-md">
          {is404 ? (
            <>
              <User className="w-20 h-20 mx-auto mb-4 text-neutral-300 dark:text-neutral-700" />
              <h1 className="text-2xl font-bold text-neutral-900 dark:text-white mb-2">
                User Not Found
              </h1>
              <p className="text-neutral-600 dark:text-neutral-400 mb-6">
                This user doesn't exist or may have changed their username.
              </p>
            </>
          ) : is403 ? (
            <>
              <Lock className="w-20 h-20 mx-auto mb-4 text-neutral-300 dark:text-neutral-700" />
              <h1 className="text-2xl font-bold text-neutral-900 dark:text-white mb-2">
                This Profile is Private
              </h1>
              <p className="text-neutral-600 dark:text-neutral-400 mb-6">
                This user has set their profile to private. Only they can view it.
              </p>
            </>
          ) : (
            <>
              <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-red-100 dark:bg-red-900/20 flex items-center justify-center">
                <span className="text-4xl">⚠️</span>
              </div>
              <h1 className="text-2xl font-bold text-neutral-900 dark:text-white mb-2">
                Something Went Wrong
              </h1>
              <p className="text-neutral-600 dark:text-neutral-400 mb-6">
                {error}
              </p>
            </>
          )}

          <button
            onClick={() => window.history.back()}
            className="px-6 py-3 bg-brand-purple-600 hover:bg-brand-purple-700 text-white rounded-xl font-semibold transition-colors"
          >
            Go Back
          </button>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}


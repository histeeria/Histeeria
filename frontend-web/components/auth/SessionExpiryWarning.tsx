'use client';

/**
 * Session Expiry Warning
 * Displays warning when session is about to expire
 */

import { useEffect, useState } from 'react';
import { AlertTriangle, RefreshCw, X } from 'lucide-react';
import { useAuth } from '@/lib/auth/authContext';
import { Button } from '@/components/ui/Button';

export function SessionExpiryWarning() {
  const { isSessionExpiring, timeUntilExpiry, refreshSession } = useAuth();
  const [isVisible, setIsVisible] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    if (isSessionExpiring) {
      setIsVisible(true);
    }
  }, [isSessionExpiring]);

  if (!isVisible || !isSessionExpiring) return null;

  const formatTime = (ms: number | null): string => {
    if (!ms || ms <= 0) return '0 minutes';
    const minutes = Math.floor(ms / 60000);
    const seconds = Math.floor((ms % 60000) / 1000);
    if (minutes > 0) {
      return `${minutes} minute${minutes !== 1 ? 's' : ''}`;
    }
    return `${seconds} second${seconds !== 1 ? 's' : ''}`;
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);
    const success = await refreshSession();
    if (success) {
      setIsVisible(false);
    }
    setIsRefreshing(false);
  };

  const handleDismiss = () => {
    setIsVisible(false);
  };

  return (
    <div className="fixed bottom-4 left-4 right-4 z-50 md:left-auto md:right-4 md:w-96">
      <div className="rounded-lg border border-yellow-300 bg-yellow-50 p-4 shadow-lg">
        <div className="flex items-start gap-3">
          <AlertTriangle className="h-5 w-5 flex-shrink-0 text-yellow-600" />
          <div className="flex-1">
            <h3 className="mb-1 text-sm font-semibold text-yellow-900">
              Session Expiring Soon
            </h3>
            <p className="mb-3 text-sm text-yellow-800">
              Your session will expire in {formatTime(timeUntilExpiry)}. Refresh to stay logged in.
            </p>
            <div className="flex gap-2">
              <Button
                onClick={handleRefresh}
                disabled={isRefreshing}
                variant="solid"
                size="sm"
                className="bg-yellow-600 hover:bg-yellow-700"
                aria-label="Refresh session"
              >
                <RefreshCw className={`mr-1 h-3 w-3 ${isRefreshing ? 'animate-spin' : ''}`} />
                Refresh Session
              </Button>
              <button
                onClick={handleDismiss}
                className="rounded px-2 py-1 text-sm text-yellow-800 hover:bg-yellow-100"
                aria-label="Dismiss warning"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * Loading State Hook
 * Manages loading states with better UX
 */

import { useState, useCallback } from 'react';

export interface UseLoadingStateOptions {
  initialLoading?: boolean;
  minLoadingTime?: number; // Minimum loading time in ms (prevents flash)
}

export function useLoadingState(options: UseLoadingStateOptions = {}) {
  const { initialLoading = false, minLoadingTime = 300 } = options;
  
  const [isLoading, setIsLoading] = useState(initialLoading);
  const [loadingStartTime, setLoadingStartTime] = useState<number | null>(null);

  const startLoading = useCallback(() => {
    setIsLoading(true);
    setLoadingStartTime(Date.now());
  }, []);

  const stopLoading = useCallback(() => {
    const elapsed = loadingStartTime ? Date.now() - loadingStartTime : 0;
    const remaining = Math.max(0, minLoadingTime - elapsed);
    
    if (remaining > 0) {
      setTimeout(() => {
        setIsLoading(false);
        setLoadingStartTime(null);
      }, remaining);
    } else {
      setIsLoading(false);
      setLoadingStartTime(null);
    }
  }, [loadingStartTime, minLoadingTime]);

  const setLoading = useCallback((loading: boolean) => {
    if (loading) {
      startLoading();
    } else {
      stopLoading();
    }
  }, [startLoading, stopLoading]);

  return {
    isLoading,
    startLoading,
    stopLoading,
    setLoading,
  };
}

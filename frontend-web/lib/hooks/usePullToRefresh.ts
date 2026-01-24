/**
 * Pull-to-Refresh Hook
 * Handles pull-to-refresh gesture for feeds
 */

import { useCallback, useRef, useEffect, useState } from 'react';

interface UsePullToRefreshOptions {
  onRefresh: () => Promise<void> | void;
  enabled?: boolean;
  threshold?: number; // Pull distance in pixels
  resistance?: number; // Resistance factor (0-1)
}

export function usePullToRefresh({
  onRefresh,
  enabled = true,
  threshold = 80,
  resistance = 0.3,
}: UsePullToRefreshOptions) {
  const [isPulling, setIsPulling] = useState(false);
  const [pullDistance, setPullDistance] = useState(0);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const startY = useRef<number>(0);
  const isDragging = useRef(false);

  const handleTouchStart = useCallback((e: TouchEvent) => {
    if (!enabled || isRefreshing) return;
    
    // Only trigger at top of scroll
    if (window.scrollY === 0) {
      startY.current = e.touches[0].clientY;
      isDragging.current = true;
    }
  }, [enabled, isRefreshing]);

  const handleTouchMove = useCallback((e: TouchEvent) => {
    if (!isDragging.current || !enabled || isRefreshing) return;

    const currentY = e.touches[0].clientY;
    const deltaY = currentY - startY.current;

    if (deltaY > 0 && window.scrollY === 0) {
      // Prevent default scrolling when pulling down
      e.preventDefault();
      
      setIsPulling(true);
      const distance = deltaY * resistance;
      setPullDistance(Math.min(distance, threshold * 1.5));
    } else if (deltaY < 0) {
      // Reset if scrolling up
      setIsPulling(false);
      setPullDistance(0);
      isDragging.current = false;
    }
  }, [enabled, isRefreshing, threshold, resistance]);

  const handleTouchEnd = useCallback(async () => {
    if (!isDragging.current || !enabled) return;

    isDragging.current = false;

    if (pullDistance >= threshold && !isRefreshing) {
      setIsRefreshing(true);
      setIsPulling(false);
      
      try {
        await onRefresh();
      } catch (error) {
        console.error('Refresh error:', error);
      } finally {
        setIsRefreshing(false);
        setPullDistance(0);
      }
    } else {
      // Spring back
      setIsPulling(false);
      setPullDistance(0);
    }
  }, [enabled, pullDistance, threshold, isRefreshing, onRefresh]);

  useEffect(() => {
    if (!enabled) return;

    window.addEventListener('touchstart', handleTouchStart, { passive: false });
    window.addEventListener('touchmove', handleTouchMove, { passive: false });
    window.addEventListener('touchend', handleTouchEnd);

    return () => {
      window.removeEventListener('touchstart', handleTouchStart);
      window.removeEventListener('touchmove', handleTouchMove);
      window.removeEventListener('touchend', handleTouchEnd);
    };
  }, [enabled, handleTouchStart, handleTouchMove, handleTouchEnd]);

  return {
    isPulling,
    pullDistance,
    isRefreshing,
    pullProgress: Math.min(pullDistance / threshold, 1),
  };
}

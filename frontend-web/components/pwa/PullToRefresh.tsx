'use client';

/**
 * Pull to Refresh Component
 * Native mobile feel for content refresh
 */

import { useState, useRef, TouchEvent } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { RefreshCw } from 'lucide-react';

interface PullToRefreshProps {
  onRefresh: () => Promise<void>;
  children: React.ReactNode;
}

export default function PullToRefresh({ onRefresh, children }: PullToRefreshProps) {
  const [pulling, setPulling] = useState(false);
  const [pullDistance, setPullDistance] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const startY = useRef(0);
  const threshold = 80; // Pull distance to trigger refresh

  const handleTouchStart = (e: TouchEvent) => {
    if (window.scrollY === 0) {
      startY.current = e.touches[0].clientY;
    }
  };

  const handleTouchMove = (e: TouchEvent) => {
    if (window.scrollY !== 0 || refreshing) return;

    const currentY = e.touches[0].clientY;
    const distance = currentY - startY.current;

    if (distance > 0 && distance <= threshold * 2) {
      setPulling(true);
      setPullDistance(distance);
    }
  };

  const handleTouchEnd = async () => {
    if (pullDistance >= threshold && !refreshing) {
      setRefreshing(true);
      setPullDistance(threshold);
      
      try {
        await onRefresh();
      } catch (error) {
        console.error('Refresh failed:', error);
      } finally {
        setRefreshing(false);
        setPulling(false);
        setPullDistance(0);
      }
    } else {
      setPulling(false);
      setPullDistance(0);
    }
  };

  const progress = Math.min(pullDistance / threshold, 1);

  return (
    <div
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      className="relative"
    >
      {/* Pull indicator */}
      <AnimatePresence>
        {(pulling || refreshing) && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="absolute top-0 left-0 right-0 flex items-center justify-center py-4 z-50"
            style={{ transform: `translateY(${Math.min(pullDistance, threshold)}px)` }}
          >
            <motion.div
              animate={{
                rotate: refreshing ? 360 : progress * 180,
              }}
              transition={{
                duration: refreshing ? 1 : 0,
                repeat: refreshing ? Infinity : 0,
                ease: 'linear',
              }}
              className="w-8 h-8 bg-purple-600 rounded-full flex items-center justify-center shadow-lg"
            >
              <RefreshCw className="w-5 h-5 text-white" />
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Content */}
      <div style={{ transform: `translateY(${pulling || refreshing ? threshold : 0}px)`, transition: 'transform 0.3s' }}>
        {children}
      </div>
    </div>
  );
}


'use client';

/**
 * Offline Banner
 * Shows when user loses connection
 */

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { WifiOff, Wifi } from 'lucide-react';

export default function OfflineBanner() {
  const [isOnline, setIsOnline] = useState(true);

  useEffect(() => {
    // Initial state
    setIsOnline(navigator.onLine);

    // Listen for online/offline events
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  return (
    <AnimatePresence>
      {!isOnline && (
        <motion.div
          initial={{ y: -100, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: -100, opacity: 0 }}
          transition={{ type: 'spring', damping: 25 }}
          className="fixed top-0 left-0 right-0 z-[9997] bg-red-500 text-white px-4 py-3 text-center font-medium shadow-lg"
        >
          <div className="flex items-center justify-center gap-2">
            <WifiOff className="w-5 h-5" />
            <span>You're offline. Some features may not work.</span>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}


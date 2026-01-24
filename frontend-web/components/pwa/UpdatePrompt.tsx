'use client';

/**
 * Update Prompt Component
 * Notifies user when new version is available
 */

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { RefreshCw } from 'lucide-react';
import { Button } from '@/components/ui/Button';

export default function UpdatePrompt() {
  const [showUpdate, setShowUpdate] = useState(false);

  useEffect(() => {
    const handleUpdate = () => {
      setShowUpdate(true);
    };

    window.addEventListener('pwa-update-available', handleUpdate);

    return () => {
      window.removeEventListener('pwa-update-available', handleUpdate);
    };
  }, []);

  const handleUpdate = () => {
    // Tell service worker to skip waiting and activate
    if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({ type: 'SKIP_WAITING' });
    }
    
    // Reload page to get new version
    window.location.reload();
  };

  return (
    <AnimatePresence>
      {showUpdate && (
        <motion.div
          initial={{ y: 100, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 100, opacity: 0 }}
          className="fixed bottom-4 left-4 right-4 md:left-auto md:right-4 md:w-96 z-[9998] bg-gradient-to-r from-purple-600 to-purple-700 text-white rounded-2xl shadow-2xl p-4"
        >
          <div className="flex items-center gap-4">
            <div className="flex-shrink-0 w-12 h-12 bg-white/20 rounded-full flex items-center justify-center">
              <RefreshCw className="w-6 h-6" />
            </div>
            <div className="flex-1">
              <h3 className="font-semibold mb-1">Update Available</h3>
              <p className="text-sm text-purple-100">
                A new version is ready. Update now for the latest features.
              </p>
            </div>
            <Button
              onClick={handleUpdate}
              className="bg-white text-purple-600 hover:bg-purple-50 font-semibold px-4 py-2 rounded-lg transition-colors"
            >
              Update
            </Button>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}


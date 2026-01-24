'use client';

/**
 * PWA Install Prompt
 * Beautiful prompt to install app on home screen
 */

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Download, X, Smartphone } from 'lucide-react';
import { Button } from '@/components/ui/Button';

export default function InstallPrompt() {
  const [deferredPrompt, setDeferredPrompt] = useState<any>(null);
  const [showPrompt, setShowPrompt] = useState(false);
  const [isIOS, setIsIOS] = useState(false);
  const [isStandalone, setIsStandalone] = useState(false);

  useEffect(() => {
    // Check if already installed
    const isInStandalone = window.matchMedia('(display-mode: standalone)').matches;
    setIsStandalone(isInStandalone);

    // Check if iOS
    const iOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    setIsIOS(iOS);

    // Check if user has dismissed before
    const dismissed = localStorage.getItem('pwa-install-dismissed');
    const visitCount = parseInt(localStorage.getItem('pwa-visit-count') || '0');

    // Increment visit count
    localStorage.setItem('pwa-visit-count', (visitCount + 1).toString());

    // Show prompt after 2 visits if not dismissed
    if (!dismissed && visitCount >= 1 && !isInStandalone) {
      setTimeout(() => setShowPrompt(true), 3000); // Show after 3 seconds
    }

    // Listen for install prompt event (Android/Chrome)
    const handler = (e: Event) => {
      e.preventDefault();
      setDeferredPrompt(e);
      if (!dismissed && visitCount >= 1) {
        setTimeout(() => setShowPrompt(true), 3000);
      }
    };

    window.addEventListener('beforeinstallprompt', handler);

    return () => {
      window.removeEventListener('beforeinstallprompt', handler);
    };
  }, []);

  const handleInstall = async () => {
    if (!deferredPrompt) return;

    deferredPrompt.prompt();
    const { outcome } = await deferredPrompt.userChoice;

    if (outcome === 'accepted') {
      console.log('[PWA] User accepted install');
    }

    setDeferredPrompt(null);
    setShowPrompt(false);
  };

  const handleDismiss = () => {
    setShowPrompt(false);
    localStorage.setItem('pwa-install-dismissed', 'true');
  };

  // Don't show if already installed
  if (isStandalone) return null;

  return (
    <AnimatePresence>
      {showPrompt && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[9998]"
            onClick={handleDismiss}
          />

          {/* Install Card */}
          <motion.div
            initial={{ opacity: 0, y: 100, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 100, scale: 0.9 }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className="fixed bottom-4 left-4 right-4 md:left-auto md:right-8 md:w-96 z-[9999] bg-white dark:bg-neutral-900 rounded-2xl shadow-2xl border border-neutral-200 dark:border-neutral-800 p-6"
          >
            {/* Close Button */}
            <button
              onClick={handleDismiss}
              className="absolute top-4 right-4 p-1.5 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-full transition-colors"
              aria-label="Dismiss"
            >
              <X className="w-5 h-5 text-neutral-500" />
            </button>

            {/* Content */}
            <div className="flex items-start gap-4 mb-4">
              {/* Icon */}
              <div className="flex-shrink-0 w-16 h-16 bg-gradient-to-br from-purple-600 to-purple-700 rounded-2xl p-3 shadow-lg">
                <Smartphone className="w-full h-full text-white" />
              </div>

              {/* Text */}
              <div className="flex-1">
                <h3 className="text-base font-bold text-neutral-900 dark:text-white mb-1">
                  Install Histeeria
                </h3>
                <p className="text-sm text-neutral-600 dark:text-neutral-400 leading-relaxed">
                  {isIOS
                    ? 'Tap Share → "Add to Home Screen" for the full experience'
                    : 'Your whole world in one app. Install for instant access.'}
                </p>
              </div>
            </div>

            {/* Benefits */}
            <ul className="space-y-2 mb-6 text-sm text-neutral-700 dark:text-neutral-300">
              <li className="flex items-center gap-2">
                <span className="text-green-500">✓</span>
                <span>Instant access from home screen</span>
              </li>
              <li className="flex items-center gap-2">
                <span className="text-green-500">✓</span>
                <span>Works offline</span>
              </li>
              <li className="flex items-center gap-2">
                <span className="text-green-500">✓</span>
                <span>Native app experience</span>
              </li>
            </ul>

            {/* Action Buttons */}
            <div className="flex gap-2">
              {!isIOS && deferredPrompt && (
                <button
                  onClick={handleInstall}
                  className="flex-1 flex items-center justify-center gap-1.5 px-4 py-2.5 bg-purple-600 hover:bg-purple-700 text-white text-sm font-semibold rounded-lg transition-colors shadow-sm"
                >
                  <Download className="w-4 h-4" />
                  Install
                </button>
              )}
              <button
                onClick={handleDismiss}
                className={`${isIOS || !deferredPrompt ? 'flex-1' : 'px-4'} py-2.5 bg-neutral-100 hover:bg-neutral-200 dark:bg-neutral-800 dark:hover:bg-neutral-700 text-neutral-700 dark:text-neutral-300 text-sm font-medium rounded-lg transition-colors`}
              >
                {isIOS || !deferredPrompt ? 'Got it' : 'Later'}
              </button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}


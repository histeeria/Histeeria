'use client';

/**
 * PWA Wrapper Component
 * Handles splash screen, install prompt, and offline banner
 */

import { useState, useEffect } from 'react';
import SplashScreen from './SplashScreen';
import InstallPrompt from './InstallPrompt';
import UpdatePrompt from './UpdatePrompt';
import OfflineBanner from './OfflineBanner';
import { registerServiceWorker } from '@/lib/utils/registerServiceWorker';

interface PWAWrapperProps {
  children: React.ReactNode;
}

export default function PWAWrapper({ children }: PWAWrapperProps) {
  const [showSplash, setShowSplash] = useState(false);
  const [appReady, setAppReady] = useState(false);

  useEffect(() => {
    // Register service worker
    registerServiceWorker();
    
    // Check if running in standalone mode (installed PWA)
    const isStandalone = 
      window.matchMedia('(display-mode: standalone)').matches ||
      (window.navigator as any).standalone === true;

    // Check if splash was already shown in this session
    const hasShownSplash = sessionStorage.getItem('upvista-splash-shown');

    // Show splash only on fresh app launch (not on page navigation)
    if (isStandalone && !hasShownSplash) {
      setShowSplash(true);
      sessionStorage.setItem('upvista-splash-shown', 'true');
    } else {
      setAppReady(true);
    }
  }, []);

  const handleSplashComplete = () => {
    setShowSplash(false);
    setAppReady(true);
  };

  return (
    <>
      {showSplash && <SplashScreen onComplete={handleSplashComplete} />}
      {appReady && (
        <>
          <OfflineBanner />
          <UpdatePrompt />
          {children}
          <InstallPrompt />
        </>
      )}
    </>
  );
}


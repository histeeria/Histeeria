'use client';

import { useState, useEffect } from 'react';

interface NetworkStatus {
  isOnline: boolean;
  isConnecting: boolean;
  lastOnlineAt: Date | null;
}

export function useNetworkStatus() {
  const [status, setStatus] = useState<NetworkStatus>({
    isOnline: typeof navigator !== 'undefined' ? navigator.onLine : true,
    isConnecting: false,
    lastOnlineAt: null,
  });

  useEffect(() => {
    // Initial check
    const initialOnline = navigator.onLine;
    setStatus(prev => ({
      ...prev,
      isOnline: initialOnline,
      lastOnlineAt: initialOnline ? new Date() : null,
    }));

    // Online event
    const handleOnline = () => {
      console.log('[NetworkStatus] 🟢 Connection restored');
      setStatus({
        isOnline: true,
        isConnecting: false,
        lastOnlineAt: new Date(),
      });

      // Dispatch custom event for other components
      window.dispatchEvent(new CustomEvent('network_online'));
    };

    // Offline event
    const handleOffline = () => {
      console.log('[NetworkStatus] 🔴 Connection lost');
      setStatus(prev => ({
        isOnline: false,
        isConnecting: false,
        lastOnlineAt: prev.lastOnlineAt,
      }));

      // Dispatch custom event
      window.dispatchEvent(new CustomEvent('network_offline'));
    };

    // Listen to browser events
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    // Periodic connection check (every 10 seconds)
    const checkConnection = setInterval(() => {
      const currentlyOnline = navigator.onLine;
      if (currentlyOnline !== status.isOnline) {
        if (currentlyOnline) {
          handleOnline();
        } else {
          handleOffline();
        }
      }
    }, 10000);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
      clearInterval(checkConnection);
    };
  }, []);

  return status;
}


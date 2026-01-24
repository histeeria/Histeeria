'use client';

import { useNetworkStatus } from '@/lib/hooks/useNetworkStatus';
import { Wifi, WifiOff, Loader2 } from 'lucide-react';

export function NetworkStatusBar() {
  const { isOnline, isConnecting } = useNetworkStatus();

  // Only show when offline or connecting
  if (isOnline && !isConnecting) return null;

  return (
    <div className={`
      absolute top-0 left-0 right-0 z-20
      ${isConnecting ? 'bg-yellow-500' : 'bg-red-500'}
      text-white text-center py-1.5 px-4
      text-xs font-medium
      shadow-lg
      animate-slide-down
    `}>
      <div className="flex items-center justify-center gap-2">
        {isConnecting ? (
          <>
            <Loader2 className="w-3.5 h-3.5 animate-spin" />
            <span>Connecting...</span>
          </>
        ) : (
          <>
            <WifiOff className="w-3.5 h-3.5" />
            <span>No internet connection • Messages will be sent when online</span>
          </>
        )}
      </div>
    </div>
  );
}


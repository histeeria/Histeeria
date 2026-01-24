/**
 * Main App Layout
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Layout wrapper for authenticated pages
 */

'use client';

import { ReactNode, Suspense } from 'react';
import { NotificationProvider } from '@/lib/contexts/NotificationContext';
import { MessagesProvider } from '@/lib/contexts/MessagesContext';
import MobileMessagesOverlay from '@/components/messages/MobileMessagesOverlay';
import { ToastContainer } from '@/components/ui/Toast';
import { FeedSkeleton } from '@/components/ui/Skeleton';

export default function MainAppLayout({ children }: { children: ReactNode }) {
  return (
    <NotificationProvider>
      <MessagesProvider>
        <Suspense fallback={<FeedSkeleton count={3} />}>
          {children}
        </Suspense>
        <MobileMessagesOverlay />
        <ToastContainer />
      </MessagesProvider>
    </NotificationProvider>
  );
}


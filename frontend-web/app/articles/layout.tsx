/**
 * Articles Layout
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Layout wrapper for article pages (public access)
 * Provides necessary contexts for Sidebar and other components
 */

'use client';

import { ReactNode } from 'react';
import { NotificationProvider } from '@/lib/contexts/NotificationContext';
import { MessagesProvider } from '@/lib/contexts/MessagesContext';
import MobileMessagesOverlay from '@/components/messages/MobileMessagesOverlay';
import { ToastContainer } from '@/components/ui/Toast';

export default function ArticlesLayout({ children }: { children: ReactNode }) {
  return (
    <NotificationProvider>
      <MessagesProvider>
        {children}
        <MobileMessagesOverlay />
        <ToastContainer />
      </MessagesProvider>
    </NotificationProvider>
  );
}


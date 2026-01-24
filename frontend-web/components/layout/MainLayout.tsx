'use client';

/**
 * Main Layout Component
 * Created by: Hamza Hafeez - Founder & CEO of Asteria
 * 
 * Main application layout with sidebar and navigation
 * Responsive: Desktop sidebar, mobile top/bottom nav
 */

import { ReactNode, useRef } from 'react';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';
import { BottomNav } from './BottomNav';
import { useMessages } from '@/lib/contexts/MessagesContext';
import { useTheme } from '@/lib/contexts/ThemeContext';
import { GradientBackground } from '@/components/ui/GradientBackground';

interface MainLayoutProps {
  children: ReactNode;
  showRightPanel?: boolean;
  rightPanel?: ReactNode;
}

export function MainLayout({ children, showRightPanel = false, rightPanel }: MainLayoutProps) {
  const { openMessages } = useMessages();
  const { theme } = useTheme();
  const touchStartXRef = useRef<number | null>(null);
  const touchStartYRef = useRef<number | null>(null);
  const touchActiveRef = useRef<boolean>(false);

  const handleTouchStart = (e: React.TouchEvent<HTMLDivElement>) => {
    if (typeof window === 'undefined') return;
    // Only enable on mobile widths
    if (window.innerWidth >= 1024) return;
    const touch = e.touches[0];
    touchStartXRef.current = touch.clientX;
    touchStartYRef.current = touch.clientY;
    touchActiveRef.current = true;
  };

  const handleTouchEnd = (e: React.TouchEvent<HTMLDivElement>) => {
    if (!touchActiveRef.current) return;
    touchActiveRef.current = false;
    if (typeof window === 'undefined') return;
    if (window.innerWidth >= 1024) return;

    const touch = e.changedTouches[0];
    const startX = touchStartXRef.current ?? touch.clientX;
    const startY = touchStartYRef.current ?? touch.clientY;
    const deltaX = touch.clientX - startX;
    const deltaY = touch.clientY - startY;

    const horizontal = Math.abs(deltaX) > 60 && Math.abs(deltaY) < 80;
    if (!horizontal) return;

    if (deltaX < -60) {
      // Swipe right-to-left: open conversations (messages overlay)
      openMessages();
    } else if (deltaX > 60) {
      // Swipe left-to-right: open "more" sidebar drawer
      window.dispatchEvent(new Event('open_more_menu'));
    }
  };

  const content = (
    <>
      {/* Desktop Sidebar */}
      <Sidebar />
      
      {/* Mobile Topbar */}
      <Topbar />
      
      {/* Main Content Area */}
      <div className="flex min-h-screen">
        {/* Sidebar spacer (desktop only) */}
        <div className="hidden lg:block w-60 flex-shrink-0" />
        
        {/* Main Content */}
        <main className="flex-1 pt-14 pb-14 md:pt-16 md:pb-14 lg:pt-0 lg:pb-0 overflow-x-hidden">
          <div className={cn(
            'mx-auto px-4 md:px-6 py-5 md:py-6 w-full',
            showRightPanel ? 'max-w-5xl' : 'max-w-4xl'
          )}>
            {children}
          </div>
        </main>
        
        {/* Right Panel (optional, desktop only) */}
        {showRightPanel && rightPanel && (
          <>
            <aside className="hidden xl:block w-80 flex-shrink-0 sticky top-0 h-screen overflow-y-auto scrollbar-hide py-6 px-4">
              {rightPanel}
            </aside>
          </>
        )}
      </div>
      
      {/* Mobile Bottom Nav */}
      <BottomNav />
    </>
  );

  // Use GradientBackground for Asteria theme
  if (theme === 'asteria') {
    return (
      <GradientBackground>
        <div
          className="min-h-screen"
          onTouchStart={handleTouchStart}
          onTouchEnd={handleTouchEnd}
        >
          {content}
        </div>
      </GradientBackground>
    );
  }

  return (
    <div
      className="min-h-screen bg-neutral-50 dark:bg-neutral-950"
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
    >
      {content}
    </div>
  );
}

function cn(...classes: (string | undefined | false)[]) {
  return classes.filter(Boolean).join(' ');
}


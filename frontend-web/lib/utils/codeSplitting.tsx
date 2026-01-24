/**
 * Code Splitting Utilities
 * Dynamic imports for route-based and component-based splitting
 */

import dynamic from 'next/dynamic';
import { ComponentType } from 'react';
import { FeedSkeleton } from '@/components/ui/Skeleton';

// Route-based code splitting
export const MessagesPage = dynamic(
  () => import('@/app/(main)/messages/page'),
  {
    loading: () => <FeedSkeleton count={5} />,
    ssr: false, // Client-only
  }
);

export const NotificationsPage = dynamic(
  () => import('@/app/(main)/notifications/page'),
  {
    loading: () => <FeedSkeleton count={5} />,
  }
);

export const CreatePage = dynamic(
  () => import('@/app/(main)/create/page'),
  {
    loading: () => <div className="min-h-screen flex items-center justify-center"><div>Loading...</div></div>,
    ssr: false,
  }
);

export const SettingsPage = dynamic(
  () => import('@/app/(main)/settings/page'),
  {
    loading: () => <FeedSkeleton count={3} />,
  }
);

// Component-based code splitting for heavy components
export const PostComposer = dynamic(
  () => import('@/components/posts/PostComposer'),
  {
    loading: () => <div className="p-4">Loading composer...</div>,
    ssr: false,
  }
);

export const MediaViewer = dynamic(
  () => import('@/components/messages/MediaViewer').then(mod => ({ default: mod.MediaViewer })),
  {
    loading: () => <div className="flex items-center justify-center p-8">Loading media...</div>,
    ssr: false,
  }
);

// Heavy libraries
// Note: FFmpegService is not a React component, so it should be imported normally where needed
// For lazy loading non-React code, use: const ffmpegService = (await import('@/lib/utils/ffmpegService')).ffmpegService;

// TipTap editor (heavy component)
// Note: TipTapEditor component doesn't exist yet - comment out until created
// export const TipTapEditor = dynamic(
//   () => import('@/components/posts/TipTapEditor').then(mod => ({ default: mod.default })),
//   {
//     loading: () => <div className="h-64 bg-neutral-100 dark:bg-neutral-800 rounded animate-pulse" />,
//     ssr: false,
//   }
// );

// Generic dynamic import helper
export function createLazyComponent<T extends ComponentType<any>>(
  importFn: () => Promise<{ default: T }>,
  options?: {
    loading?: ComponentType;
    ssr?: boolean;
  }
) {
  const LoadingComponent = options?.loading;
  return dynamic(importFn, {
    loading: LoadingComponent ? () => <LoadingComponent /> : undefined,
    ssr: options?.ssr ?? true,
  });
}

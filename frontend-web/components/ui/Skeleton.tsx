'use client';

/**
 * Skeleton Loader Components
 * Used for loading states across the application
 */

import { cn } from '@/lib/utils';

interface SkeletonProps {
  className?: string;
  variant?: 'default' | 'circular' | 'text' | 'rectangular';
  width?: string | number;
  height?: string | number;
}

export function Skeleton({ 
  className, 
  variant = 'default',
  width,
  height 
}: SkeletonProps) {
  const baseClasses = 'animate-pulse bg-neutral-200 dark:bg-neutral-800';
  
  const variantClasses = {
    default: 'rounded',
    circular: 'rounded-full',
    text: 'rounded h-4',
    rectangular: 'rounded-none',
  };

  const style: React.CSSProperties = {};
  if (width) style.width = typeof width === 'number' ? `${width}px` : width;
  if (height) style.height = typeof height === 'number' ? `${height}px` : height;

  return (
    <div
      className={cn(baseClasses, variantClasses[variant], className)}
      style={style}
    />
  );
}

// Pre-built skeleton components for common use cases

export function PostCardSkeleton() {
  return (
    <div className="bg-white dark:bg-neutral-900 rounded-lg border border-neutral-200 dark:border-neutral-800 p-4 space-y-4">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Skeleton variant="circular" width={40} height={40} />
        <div className="flex-1 space-y-2">
          <Skeleton width="40%" height={16} />
          <Skeleton width="30%" height={12} />
        </div>
      </div>
      
      {/* Content */}
      <div className="space-y-2">
        <Skeleton width="100%" height={16} />
        <Skeleton width="90%" height={16} />
        <Skeleton width="60%" height={16} />
      </div>
      
      {/* Media placeholder */}
      <Skeleton width="100%" height={300} />
      
      {/* Actions */}
      <div className="flex items-center gap-4 pt-2">
        <Skeleton width={60} height={24} />
        <Skeleton width={60} height={24} />
        <Skeleton width={60} height={24} />
      </div>
    </div>
  );
}

export function FeedSkeleton({ count = 3 }: { count?: number }) {
  return (
    <div className="space-y-4">
      {Array.from({ length: count }).map((_, i) => (
        <PostCardSkeleton key={i} />
      ))}
    </div>
  );
}

export function MessageSkeleton() {
  return (
    <div className="flex gap-3 p-3">
      <Skeleton variant="circular" width={36} height={36} />
      <div className="flex-1 space-y-2">
        <Skeleton width="30%" height={12} />
        <Skeleton width="70%" height={40} />
      </div>
    </div>
  );
}

export function ConversationListSkeleton({ count = 5 }: { count?: number }) {
  return (
    <div className="space-y-2">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="flex items-center gap-3 p-3 border-b border-neutral-200 dark:border-neutral-800">
          <Skeleton variant="circular" width={48} height={48} />
          <div className="flex-1 space-y-2">
            <Skeleton width="50%" height={16} />
            <Skeleton width="80%" height={12} />
          </div>
        </div>
      ))}
    </div>
  );
}

export function ProfileSkeleton() {
  return (
    <div className="space-y-6">
      {/* Profile header */}
      <div className="flex flex-col md:flex-row gap-6">
        <Skeleton variant="circular" width={120} height={120} className="mx-auto md:mx-0" />
        <div className="flex-1 space-y-3">
          <Skeleton width="60%" height={32} />
          <Skeleton width="40%" height={20} />
          <Skeleton width="100%" height={60} />
        </div>
      </div>
      
      {/* Stats */}
      <div className="flex gap-6">
        <Skeleton width={80} height={24} />
        <Skeleton width={80} height={24} />
        <Skeleton width={80} height={24} />
      </div>
    </div>
  );
}

export function NotificationSkeleton({ count = 5 }: { count?: number }) {
  return (
    <div className="space-y-2">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="flex gap-3 p-3 border-b border-neutral-200 dark:border-neutral-800">
          <Skeleton variant="circular" width={40} height={40} />
          <div className="flex-1 space-y-2">
            <Skeleton width="80%" height={16} />
            <Skeleton width="60%" height={12} />
          </div>
        </div>
      ))}
    </div>
  );
}

export function SettingsSkeleton() {
  return (
    <div className="space-y-6">
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="space-y-3">
          <Skeleton width="30%" height={24} />
          <Skeleton width="100%" height={48} />
          <Skeleton width="100%" height={48} />
        </div>
      ))}
    </div>
  );
}

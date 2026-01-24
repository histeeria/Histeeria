/**
 * Badge Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Tag/badge component for categories and labels
 * iOS-inspired minimal styling
 */

import { HTMLAttributes, ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: 'purple' | 'neutral' | 'success' | 'error' | 'warning' | 'info';
  size?: 'sm' | 'md';
  children: ReactNode;
}

export function Badge({
  variant = 'neutral',
  size = 'sm',
  className,
  children,
  ...props
}: BadgeProps) {
  const baseStyles = 'inline-flex items-center gap-1 rounded-full font-medium whitespace-nowrap';
  
  const variants = {
    purple: 'bg-brand-purple-100 dark:bg-brand-purple-900/30 text-brand-purple-700 dark:text-brand-purple-300 border border-brand-purple-200 dark:border-brand-purple-800/50',
    neutral: 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 border border-neutral-200 dark:border-neutral-700',
    success: 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 border border-green-200 dark:border-green-800/50',
    error: 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300 border border-red-200 dark:border-red-800/50',
    warning: 'bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300 border border-amber-200 dark:border-amber-800/50',
    info: 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 border border-blue-200 dark:border-blue-800/50',
  };
  
  const sizes = {
    sm: 'px-2.5 py-0.5 text-xs',
    md: 'px-3 py-1 text-sm',
  };

  return (
    <span
      className={cn(
        baseStyles,
        variants[variant],
        sizes[size],
        className
      )}
      {...props}
    >
      {children}
    </span>
  );
}


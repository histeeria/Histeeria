/**
 * Card Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Glassmorphic card component with smooth animations
 * iOS-inspired depth and hierarchy
 */

import { HTMLAttributes, ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: 'glass' | 'solid';
  hoverable?: boolean;
  children: ReactNode;
}

export function Card({
  variant = 'glass',
  hoverable = true,
  className,
  children,
  ...props
}: CardProps) {
  const baseStyles = 'transition-all duration-300 w-full';
  
  const variants = {
    glass: 'bg-transparent border border-neutral-200 dark:border-neutral-800',
    solid: 'bg-white dark:bg-neutral-900 border border-neutral-200 dark:border-neutral-800 shadow-lg',
  };
  
  const hoverStyles = hoverable
    ? 'hover:shadow-2xl hover:shadow-neutral-300/50 dark:hover:shadow-black/60'
    : '';

  return (
    <div
      className={cn(
        baseStyles,
        variants[variant],
        hoverStyles,
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}


/**
 * Avatar Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * User avatar with multiple sizes and online status indicator
 * Professional styling with fallback initials
 */

import { ImgHTMLAttributes } from 'react';
import { cn } from '@/lib/utils';
import { User } from 'lucide-react';

interface AvatarProps extends Omit<ImgHTMLAttributes<HTMLImageElement>, 'src'> {
  src?: string | null;
  alt: string;
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl' | '2xl' | '3xl';
  showOnline?: boolean;
  isOnline?: boolean;
  fallback?: string;
}

export function Avatar({
  src,
  alt,
  size = 'md',
  showOnline = false,
  isOnline = false,
  fallback,
  className,
  ...props
}: AvatarProps) {
  const sizes = {
    xs: 'w-6 h-6',
    sm: 'w-8 h-8',
    md: 'w-10 h-10',
    lg: 'w-12 h-12',
    xl: 'w-16 h-16',
    '2xl': 'w-24 h-24',
    '3xl': 'w-32 h-32',
  };
  
  const indicatorSizes = {
    xs: 'w-2 h-2',
    sm: 'w-2.5 h-2.5',
    md: 'w-3 h-3',
    lg: 'w-3.5 h-3.5',
    xl: 'w-4 h-4',
    '2xl': 'w-5 h-5',
    '3xl': 'w-6 h-6',
  };

  // Get initials from alt text or fallback
  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map(word => word[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  return (
    <div className="relative inline-block">
      {src ? (
        <img
          src={src}
          alt={alt}
          className={cn(
            sizes[size],
            'rounded-full object-cover border-2 border-white dark:border-neutral-800 shadow-md',
            className
          )}
          {...props}
        />
      ) : (
        <div
          className={cn(
            sizes[size],
            'rounded-full bg-brand-purple-100 dark:bg-brand-purple-900/30 border-2 border-white dark:border-neutral-800 shadow-md flex items-center justify-center',
            className
          )}
        >
          {fallback ? (
            <span className="text-brand-purple-700 dark:text-brand-purple-300 font-semibold text-sm">
              {getInitials(fallback)}
            </span>
          ) : (
            <User className="w-1/2 h-1/2 text-brand-purple-600 dark:text-brand-purple-400" />
          )}
        </div>
      )}
      
      {showOnline && (
        <div
          className={cn(
            indicatorSizes[size],
            'absolute -bottom-0.5 -right-0.5 rounded-full border-2 border-white dark:border-neutral-900',
            isOnline ? 'bg-success' : 'bg-neutral-400'
          )}
        />
      )}
    </div>
  );
}


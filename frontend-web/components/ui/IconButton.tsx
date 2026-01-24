/**
 * Icon Button Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Circular icon button for actions
 * iOS-inspired minimal styling
 */

import { ButtonHTMLAttributes, ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  badge?: number | string;
  children: ReactNode;
}

export function IconButton({
  badge,
  className,
  children,
  ...props
}: IconButtonProps) {
  return (
    <button
      className={cn(
        'relative w-10 h-10 flex items-center justify-center rounded-full text-neutral-600 dark:text-neutral-400 hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors duration-200 active:scale-90',
        className
      )}
      {...props}
    >
      {children}
      {badge !== undefined && badge !== 0 && (
        <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 flex items-center justify-center bg-error text-white text-[10px] font-bold rounded-full shadow-sm">
          {typeof badge === 'number' && badge > 99 ? '99+' : badge}
        </span>
      )}
    </button>
  );
}


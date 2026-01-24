/**
 * Button Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Professional button component with multiple variants
 * iOS-inspired styling with smooth transitions
 */

import { ButtonHTMLAttributes, ReactNode } from 'react';
import { cn } from '@/lib/utils';
import { Loader2 } from 'lucide-react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'outline' | 'solid';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
  children: ReactNode;
}

export function Button({
  variant = 'primary',
  size = 'md',
  isLoading = false,
  className,
  children,
  disabled,
  ...props
}: ButtonProps) {
  const baseStyles = 'inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition-all duration-200 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed';
  
  const variants = {
    primary: 'bg-brand-purple-600 hover:bg-brand-purple-700 active:bg-brand-purple-800 text-white shadow-md shadow-brand-purple-500/20 hover:shadow-lg hover:shadow-brand-purple-500/25',
    secondary: 'border-2 border-brand-purple-600 hover:border-brand-purple-700 text-brand-purple-600 dark:text-brand-purple-400 hover:bg-brand-purple-50 dark:hover:bg-brand-purple-950/30',
    outline: 'border border-neutral-200 dark:border-neutral-800 hover:border-neutral-300 dark:hover:border-neutral-700 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-50 dark:hover:bg-neutral-800',
    solid: 'bg-brand-purple-600 hover:bg-brand-purple-700 active:bg-brand-purple-800 text-white shadow-md shadow-brand-purple-500/20 hover:shadow-lg hover:shadow-brand-purple-500/25',
    ghost: 'text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800',
    danger: 'bg-error hover:bg-red-600 active:bg-red-700 text-white shadow-md shadow-error/20 hover:shadow-lg hover:shadow-error/25',
  };
  
  const sizes = {
    sm: 'px-4 py-2 text-sm',
    md: 'px-6 py-3 text-base',
    lg: 'px-8 py-4 text-lg',
  };

  return (
    <button
      className={cn(
        baseStyles,
        variants[variant],
        sizes[size],
        className
      )}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading && <Loader2 className="w-4 h-4 animate-spin" />}
      {children}
    </button>
  );
}


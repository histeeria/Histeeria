/**
 * Input Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Floating label input with Instagram-style transparent design
 * Labels move upward when focused or filled
 */

import { InputHTMLAttributes, forwardRef } from 'react';
import { cn } from '@/lib/utils';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  labelBg?: string; // Custom background for label (defaults to page background)
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, className, labelBg, ...props }, ref) => {
    // Default to white/dark-950 to match settings pages background
    const defaultLabelBg = 'bg-white dark:bg-neutral-950';
    const labelBackground = labelBg || defaultLabelBg;

    return (
      <div className="relative">
        <input
          ref={ref}
          placeholder=" "
          className={cn(
            'peer w-full rounded-lg border border-neutral-200 dark:border-neutral-800 bg-transparent px-4 py-3 text-sm text-neutral-900 dark:text-neutral-50 transition-all duration-200 placeholder-transparent focus:outline-none focus:ring-2 focus:ring-brand-purple-500 focus:border-brand-purple-500',
            error
              ? 'border-red-500 dark:border-red-500 focus:border-red-500 focus:ring-red-500'
              : '',
            className
          )}
          {...props}
        />
        <label
          className={cn(
            'pointer-events-none absolute -top-2.5 left-4 px-2 text-xs font-medium transition-all duration-200',
            'peer-placeholder-shown:top-3 peer-placeholder-shown:text-sm peer-placeholder-shown:text-neutral-400 dark:peer-placeholder-shown:text-neutral-500',
            'peer-focus:-top-2.5 peer-focus:text-xs',
            labelBackground,
            error
              ? 'text-red-600 dark:text-red-400 peer-focus:text-red-600 dark:peer-focus:text-red-400'
              : 'text-brand-purple-600 dark:text-brand-purple-400 peer-focus:text-brand-purple-600 dark:peer-focus:text-brand-purple-400'
          )}
        >
          {label}
        </label>
        {error && (
          <p className="mt-2 text-sm text-red-600 dark:text-red-400">{error}</p>
        )}
      </div>
    );
  }
);

Input.displayName = 'Input';

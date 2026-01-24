'use client';

/**
 * Verified Badge Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Minimal Instagram-style verification badge with purple gradient
 * Professional and clean design
 */

import { Check } from 'lucide-react';

interface VerifiedBadgeProps {
  size?: 'sm' | 'md' | 'lg';
  variant?: 'inline' | 'badge'; // inline = just icon, badge = full badge with text
  showText?: boolean;
  isVerified?: boolean; // Controls verified vs not verified state
}

export default function VerifiedBadge({ 
  size = 'md', 
  variant = 'badge',
  showText = true,
  isVerified = true 
}: VerifiedBadgeProps) {
  
  const sizeClasses = {
    sm: {
      container: 'w-3.5 h-3.5',
      icon: 'w-2.5 h-2.5',
      border: 'border-[0.5px]',
      text: 'text-[10px]',
      padding: 'px-2 py-0.5',
      gap: 'gap-1',
    },
    md: {
      container: 'w-4 h-4',
      icon: 'w-3 h-3',
      border: 'border-[0.5px]',
      text: 'text-xs',
      padding: 'px-2.5 py-1',
      gap: 'gap-1.5',
    },
    lg: {
      container: 'w-5 h-5',
      icon: 'w-3.5 h-3.5',
      border: 'border-[0.5px]',
      text: 'text-sm',
      padding: 'px-3 py-1.5',
      gap: 'gap-2',
    },
  };

  const classes = sizeClasses[size];

  // Instagram-style circular badge with checkmark
  if (variant === 'badge' || variant === 'inline') {
    if (!isVerified) {
      return null; // Don't show anything if not verified
    }

    return (
      <div className={`
        ${classes.container}
        rounded-full
        flex items-center justify-center
        relative
        ${isVerified 
          ? 'bg-gradient-to-br from-purple-600 via-purple-500 to-purple-600'
          : 'bg-neutral-200 dark:bg-neutral-700'
        }
        ${classes.border}
        ${isVerified 
          ? 'border-white/40'
          : 'border-neutral-400 dark:border-neutral-500'
        }
        flex-shrink-0
        shadow-sm
        ${isVerified ? 'shadow-purple-500/20' : ''}
      `}>
        {/* Conical border effect - inner ring */}
        <div className={`
          absolute inset-0 rounded-full
          ${isVerified 
            ? 'border border-white/20'
            : 'border border-neutral-300 dark:border-neutral-600'
          }
        `} />
        
        {/* Centered checkmark */}
        <Check 
          className={`
            ${classes.icon} 
            relative z-10
            ${isVerified 
              ? 'text-white'
              : 'text-neutral-500 dark:text-neutral-400'
            }
            stroke-[4]
          `}
        />
      </div>
    );
  }

  // Fallback for any other variant
  return (
    <div className={`
      inline-flex items-center ${classes.gap} ${classes.padding}
      ${isVerified 
        ? 'bg-gradient-to-r from-purple-600 to-purple-500 text-white shadow-sm shadow-purple-500/20'
        : 'bg-neutral-200 dark:bg-neutral-700 text-neutral-600 dark:text-neutral-400'
      }
      font-semibold rounded-full
      ${classes.text}
    `}>
      <Check className={`${classes.icon} ${isVerified ? 'text-white' : 'text-neutral-500 dark:text-neutral-400'}`} />
      {showText && <span>{isVerified ? 'Verified' : 'Not Verified'}</span>}
    </div>
  );
}


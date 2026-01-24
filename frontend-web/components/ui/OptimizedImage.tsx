'use client';

/**
 * Optimized Image Component
 * Wrapper around Next.js Image with sensible defaults
 */

import Image from 'next/image';
import { useState } from 'react';
import { Skeleton } from './Skeleton';

interface OptimizedImageProps {
  src: string;
  alt: string;
  width?: number;
  height?: number;
  fill?: boolean;
  className?: string;
  priority?: boolean;
  quality?: number;
  sizes?: string;
  objectFit?: 'contain' | 'cover' | 'fill' | 'none' | 'scale-down';
  onError?: () => void;
}

export function OptimizedImage({
  src,
  alt,
  width,
  height,
  fill = false,
  className = '',
  priority = false,
  quality = 85,
  sizes,
  objectFit = 'cover',
  onError,
}: OptimizedImageProps) {
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);

  // Generate blur placeholder
  const blurDataURL = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAIAAoDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAhEAACAQMDBQAAAAAAAAAAAAABAgMABAUGIWGRkqGx0f/EABUBAQEAAAAAAAAAAAAAAAAAAAMF/8QAGhEAAgIDAAAAAAAAAAAAAAAAAAECEgMRkf/aAAwDAQACEQMRAD8AltJagyeH0AthI5xdrLcNM91BF5pX2HaH9bcfaSXWGaRmknyJckliyjqTzSlT54b6bk+h0R//9k=';

  if (hasError) {
    return (
      <div 
        className={`bg-neutral-200 dark:bg-neutral-800 flex items-center justify-center ${className}`}
        style={{ width, height }}
      >
        <span className="text-neutral-400 text-sm">Failed to load image</span>
      </div>
    );
  }

  const imageProps: any = {
    src,
    alt,
    className: `${className} ${isLoading ? 'opacity-0' : 'opacity-100'} transition-opacity duration-300`,
    quality,
    priority,
    onLoad: () => setIsLoading(false),
    onError: () => {
      setHasError(true);
      setIsLoading(false);
      if (onError) onError();
    },
    style: { objectFit },
  };

  if (fill) {
    imageProps.fill = true;
    imageProps.sizes = sizes || '(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw';
  } else {
    if (width) imageProps.width = width;
    if (height) imageProps.height = height;
    imageProps.sizes = sizes;
  }

  return (
    <div className="relative" style={fill ? { width: '100%', height: '100%' } : { width, height }}>
      {isLoading && (
        <Skeleton 
          className="absolute inset-0" 
          width={fill ? undefined : width}
          height={fill ? undefined : height}
        />
      )}
      <Image
        {...imageProps}
        placeholder="blur"
        blurDataURL={blurDataURL}
        loading={priority ? undefined : 'lazy'}
      />
    </div>
  );
}

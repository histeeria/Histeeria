'use client';

import { useState, useEffect, useRef } from 'react';
import { generateBlurPlaceholder, isInViewport } from '@/lib/utils/imageOptimization';
import { imageCache } from '@/lib/utils/imageCache';

interface ImageMessageProps {
  url: string;
  alt: string;
  thumbnailUrl?: string; // Optional low-res thumbnail
}

export default function ImageMessage({ url, alt, thumbnailUrl }: ImageMessageProps) {
  const [isLoaded, setIsLoaded] = useState(false);
  const [blurDataUrl, setBlurDataUrl] = useState<string>('');
  const [currentSrc, setCurrentSrc] = useState<string>(thumbnailUrl || '');
  const imgRef = useRef<HTMLImageElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Generate blur placeholder
  useEffect(() => {
    const generatePlaceholder = async () => {
      try {
        const placeholder = await generateBlurPlaceholder(thumbnailUrl || url);
        setBlurDataUrl(placeholder);
      } catch (error) {
        console.error('[ImageMessage] Failed to generate blur placeholder:', error);
      }
    };

    generatePlaceholder();
  }, [url, thumbnailUrl]);

  // Progressive loading: blur → thumbnail → full image
  useEffect(() => {
    if (!containerRef.current) return;

    // Check if image is in viewport
    const checkViewport = () => {
      if (containerRef.current && isInViewport(containerRef.current, 300)) {
        loadFullImage();
      }
    };

    // Initial check
    checkViewport();

    // Check on scroll
    const handleScroll = () => checkViewport();
    window.addEventListener('scroll', handleScroll, { passive: true });

    return () => {
      window.removeEventListener('scroll', handleScroll);
    };
  }, [url]);

  const loadFullImage = async () => {
    // Check cache first
    if (imageCache.has(url)) {
      const cachedBlob = imageCache.get(url);
      if (cachedBlob) {
        const objectUrl = URL.createObjectURL(cachedBlob);
        setCurrentSrc(objectUrl);
        setIsLoaded(true);
        return;
      }
    }

    // Load full image
    try {
      const response = await fetch(url);
      const blob = await response.blob();
      
      // Cache it
      await imageCache.add(url, blob);
      
      // Set as current source
      const objectUrl = URL.createObjectURL(blob);
      setCurrentSrc(objectUrl);
      setIsLoaded(true);
    } catch (error) {
      console.error('[ImageMessage] Failed to load full image:', error);
      // Fallback to direct URL
      setCurrentSrc(url);
      setIsLoaded(true);
    }
  };

  return (
    <div
      ref={containerRef}
      className="relative rounded-lg overflow-hidden max-w-xs"
    >
      {/* Blur Placeholder (shown while loading) */}
      {!isLoaded && blurDataUrl && (
        <img
          src={blurDataUrl}
          alt="Loading..."
          className="absolute inset-0 w-full h-full object-cover blur-sm scale-110"
        />
      )}

      {/* Actual Image */}
      <img
        ref={imgRef}
        src={currentSrc || url}
        alt={alt}
        className={`w-full h-auto max-h-96 object-cover transition-opacity duration-500 ${
          isLoaded ? 'opacity-100' : 'opacity-0'
        }`}
        loading="lazy"
        onLoad={() => setIsLoaded(true)}
      />

      {/* Loading Spinner */}
      {!isLoaded && !blurDataUrl && (
        <div className="absolute inset-0 flex items-center justify-center bg-gray-200 dark:bg-gray-800">
          <div className="w-8 h-8 border-4 border-purple-600 border-t-transparent rounded-full animate-spin" />
        </div>
      )}
    </div>
  );
}



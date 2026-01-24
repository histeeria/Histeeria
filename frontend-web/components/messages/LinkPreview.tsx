'use client';

import { useState, useEffect } from 'react';
import { ExternalLink, Globe } from 'lucide-react';
import { LinkPreview as LinkPreviewType, generateBasicPreview, shortenUrl } from '@/lib/utils/linkPreview';

interface LinkPreviewProps {
  url: string;
  isMine: boolean;
}

export function LinkPreview({ url, isMine }: LinkPreviewProps) {
  const [preview, setPreview] = useState<LinkPreviewType | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Generate basic preview immediately (no API needed)
    const basicPreview = generateBasicPreview(url);
    setPreview(basicPreview);
    setIsLoading(false);

    // Could fetch rich preview from backend API here in Phase 2
    // fetchLinkPreview(url).then(richPreview => {
    //   if (richPreview) setPreview(richPreview);
    // });
  }, [url]);

  if (!preview) return null;

  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      className={`
        block mt-2 rounded-lg overflow-hidden border 
        ${isMine 
          ? 'border-purple-400 dark:border-purple-500 bg-purple-700/20 hover:bg-purple-700/30' 
          : 'border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600'
        }
        transition-colors cursor-pointer
        w-full max-w-full
      `}
    >
      {/* Preview Image */}
      {preview.image && (
        <div className="w-full h-40 bg-gray-200 dark:bg-gray-700 overflow-hidden">
          <img
            src={preview.image}
            alt={preview.title || 'Link preview'}
            className="w-full h-full object-cover"
            loading="lazy"
            onError={(e) => {
              // Hide image if it fails to load
              (e.target as HTMLImageElement).style.display = 'none';
            }}
          />
        </div>
      )}

      {/* Preview Content */}
      <div className="p-3">
        {/* Site Name / Favicon */}
        <div className="flex items-center gap-2 mb-2">
          {preview.favicon ? (
            <img
              src={preview.favicon}
              alt=""
              className="w-4 h-4 rounded"
              onError={(e) => {
                // Fallback to globe icon
                (e.target as HTMLImageElement).style.display = 'none';
              }}
            />
          ) : (
            <Globe className="w-4 h-4 text-gray-500" />
          )}
          <span className={`text-xs font-medium ${
            isMine ? 'text-purple-200' : 'text-gray-600 dark:text-gray-400'
          }`}>
            {preview.siteName || new URL(url).hostname}
          </span>
        </div>

        {/* Title */}
        {preview.title && (
          <h4 className={`font-semibold text-sm mb-1 line-clamp-2 ${
            isMine ? 'text-white' : 'text-gray-900 dark:text-white'
          }`}>
            {preview.title}
          </h4>
        )}

        {/* Description */}
        {preview.description && (
          <p className={`text-xs mb-2 line-clamp-2 ${
            isMine ? 'text-purple-100' : 'text-gray-600 dark:text-gray-300'
          }`}>
            {preview.description}
          </p>
        )}

        {/* URL */}
        <div className="flex items-center gap-1.5">
          <span className={`text-xs truncate flex-1 ${
            isMine ? 'text-purple-200' : 'text-blue-600 dark:text-blue-400'
          }`}>
            {shortenUrl(url, 40)}
          </span>
          <ExternalLink className={`w-3 h-3 flex-shrink-0 ${
            isMine ? 'text-purple-300' : 'text-gray-500 dark:text-gray-400'
          }`} />
        </div>
      </div>
    </a>
  );
}


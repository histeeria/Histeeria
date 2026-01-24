import { useState, useEffect } from 'react';
import { getAttachmentURL, isFilePath } from '@/lib/api/fileUrls';

/**
 * Hook to get signed URL for a message attachment
 * Automatically handles caching and URL resolution
 */
export function useSignedFileURL(
  attachmentUrl: string | undefined | null,
  messageId: string
): string | null {
  const [resolvedUrl, setResolvedUrl] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!attachmentUrl) {
      setResolvedUrl(null);
      return;
    }

    // If it's not a file path, use it directly
    if (!isFilePath(attachmentUrl)) {
      setResolvedUrl(attachmentUrl);
      return;
    }

    // It's a file path, fetch signed URL
    setIsLoading(true);
    setError(null);

    getAttachmentURL(attachmentUrl, messageId)
      .then((url) => {
        setResolvedUrl(url);
        setIsLoading(false);
      })
      .catch((err) => {
        console.error(`[useSignedFileURL] Failed to get signed URL for message ${messageId}:`, err);
        setError(err);
        setIsLoading(false);
        // Don't set resolvedUrl to null on error - keep previous URL if available
      });
  }, [attachmentUrl, messageId]);

  return resolvedUrl;
}

/**
 * Hook to get multiple signed URLs for a message (e.g., video + thumbnail)
 */
export function useSignedFileURLs(
  attachmentUrl: string | undefined | null,
  thumbnailUrl: string | undefined | null,
  messageId: string
): { video: string | null; thumbnail: string | null } {
  const videoUrl = useSignedFileURL(attachmentUrl, messageId);
  const thumbUrl = useSignedFileURL(thumbnailUrl, messageId);

  return {
    video: videoUrl,
    thumbnail: thumbUrl,
  };
}

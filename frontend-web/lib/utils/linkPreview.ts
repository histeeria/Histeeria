'use client';

export interface LinkPreview {
  url: string;
  title?: string;
  description?: string;
  image?: string;
  siteName?: string;
  favicon?: string;
  type?: string; // 'website' | 'video' | 'article'
}

/**
 * Extract URLs from text
 */
export function extractUrls(text: string): string[] {
  const urlRegex = /(https?:\/\/[^\s]+)/gi;
  return text.match(urlRegex) || [];
}

/**
 * Check if text contains URLs
 */
export function containsUrl(text: string): boolean {
  return extractUrls(text).length > 0;
}

/**
 * Make URLs clickable in text
 */
export function linkify(text: string): string {
  const urlRegex = /(https?:\/\/[^\s]+)/gi;
  return text.replace(urlRegex, (url) => {
    return `<a href="${url}" target="_blank" rel="noopener noreferrer" class="text-blue-500 hover:text-blue-600 underline">${url}</a>`;
  });
}

/**
 * Fetch link preview metadata using Open Graph protocol
 * This requires a backend proxy to avoid CORS issues
 */
export async function fetchLinkPreview(url: string): Promise<LinkPreview | null> {
  try {
    // Use backend proxy to fetch metadata
    const response = await fetch(`/api/proxy/v1/link-preview?url=${encodeURIComponent(url)}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('token')}`,
      },
    });

    if (!response.ok) {
      console.warn('[LinkPreview] Failed to fetch preview for:', url);
      return null;
    }

    const data = await response.json();
    return data.preview || null;
  } catch (error) {
    console.error('[LinkPreview] Error fetching preview:', error);
    return null;
  }
}

/**
 * Detect Instagram URLs
 */
export function isInstagramUrl(url: string): boolean {
  return url.includes('instagram.com');
}

/**
 * Detect YouTube URLs
 */
export function isYouTubeUrl(url: string): boolean {
  return url.includes('youtube.com') || url.includes('youtu.be');
}

/**
 * Extract Instagram reel/post ID
 */
export function extractInstagramId(url: string): string | null {
  const match = url.match(/instagram\.com\/(?:reel|p)\/([^/?]+)/);
  return match ? match[1] : null;
}

/**
 * Extract YouTube video ID
 */
export function extractYouTubeId(url: string): string | null {
  const match = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&?]+)/);
  return match ? match[1] : null;
}

/**
 * Generate preview for common platforms (client-side only, no API needed)
 */
export function generateBasicPreview(url: string): LinkPreview {
  const preview: LinkPreview = { url };

  // Instagram
  if (isInstagramUrl(url)) {
    const id = extractInstagramId(url);
    preview.siteName = 'Instagram';
    preview.title = id ? `Instagram Reel/Post` : 'Instagram';
    preview.description = 'View on Instagram';
    preview.type = 'video';
    preview.favicon = 'https://www.instagram.com/favicon.ico';
  }
  
  // YouTube
  else if (isYouTubeUrl(url)) {
    const id = extractYouTubeId(url);
    preview.siteName = 'YouTube';
    preview.title = id ? `YouTube Video` : 'YouTube';
    preview.description = 'Watch on YouTube';
    preview.type = 'video';
    preview.image = id ? `https://img.youtube.com/vi/${id}/maxresdefault.jpg` : undefined;
    preview.favicon = 'https://www.youtube.com/favicon.ico';
  }
  
  // Generic link
  else {
    try {
      const urlObj = new URL(url);
      preview.siteName = urlObj.hostname.replace('www.', '');
      preview.title = urlObj.hostname;
      preview.description = 'Click to open';
      preview.favicon = `https://www.google.com/s2/favicons?domain=${urlObj.hostname}`;
    } catch {
      preview.title = url;
    }
  }

  return preview;
}

/**
 * Shorten long URLs for display
 */
export function shortenUrl(url: string, maxLength = 50): string {
  if (url.length <= maxLength) return url;
  
  try {
    const urlObj = new URL(url);
    const domain = urlObj.hostname;
    const path = urlObj.pathname;
    
    if (domain.length + path.length > maxLength) {
      return `${domain}${path.substring(0, maxLength - domain.length - 3)}...`;
    }
    
    return `${domain}${path}`;
  } catch {
    return url.substring(0, maxLength - 3) + '...';
  }
}


/**
 * Secure File URL Service
 * Handles requesting signed URLs for private file attachments
 */

const API_BASE = '/api/proxy/v1';

interface SignedURLResponse {
  success: boolean;
  signed_url: string;
  expires_in: number;
}

// Cache for signed URLs (messageId -> { url, expiresAt })
const urlCache = new Map<string, { url: string; expiresAt: number }>();

// Cache expiration buffer (refresh 5 minutes before actual expiration)
const EXPIRATION_BUFFER = 5 * 60 * 1000; // 5 minutes in milliseconds

/**
 * Get a signed URL for a file attachment
 * @param messageId - The message ID containing the attachment
 * @param expiresIn - Optional expiration time in seconds (default: 3600 = 1 hour)
 * @returns Signed URL string
 */
export async function getFileSignedURL(
  messageId: string,
  expiresIn: number = 3600
): Promise<string> {
  // Check cache first
  const cached = urlCache.get(messageId);
  if (cached && cached.expiresAt > Date.now() + EXPIRATION_BUFFER) {
    console.log(`[FileURLs] ✅ Using cached signed URL for message ${messageId}`);
    return cached.url;
  }

  // Request new signed URL from backend
  const token = localStorage.getItem('token');
  const response = await fetch(
    `${API_BASE}/messages/files/${messageId}/download?expires_in=${expiresIn}`,
    {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    }
  );

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Failed to get file URL' }));
    throw new Error(error.error || `Failed to get signed URL: ${response.statusText}`);
  }

  const data: SignedURLResponse = await response.json();
  
  if (!data.success || !data.signed_url) {
    throw new Error('Invalid response from server');
  }

  // Cache the URL
  const expiresAt = Date.now() + (data.expires_in * 1000);
  urlCache.set(messageId, {
    url: data.signed_url,
    expiresAt,
  });

  console.log(`[FileURLs] ✅ Generated signed URL for message ${messageId}, expires in ${data.expires_in}s`);

  return data.signed_url;
}

/**
 * Clear cached URL for a message (e.g., when message is deleted)
 */
export function clearCachedURL(messageId: string): void {
  urlCache.delete(messageId);
}

/**
 * Clear all cached URLs
 */
export function clearAllCachedURLs(): void {
  urlCache.clear();
}

/**
 * Check if a URL is a file path (needs signed URL) vs a direct URL
 */
export function isFilePath(url: string | undefined | null): boolean {
  if (!url) return false;
  
  // If it's already a full URL (http/https), it's a direct URL (legacy or external)
  if (url.startsWith('http://') || url.startsWith('https://')) {
    // Check if it's a Supabase public URL (legacy) - these need conversion
    if (url.includes('/storage/v1/object/public/')) {
      return true; // Legacy public URL, needs signed URL
    }
    return false; // External URL, use as-is
  }
  
  // If it contains a slash but no protocol, it's likely a file path (bucket/path)
  return url.includes('/') && !url.includes('://');
}

/**
 * Get display URL for an attachment
 * If it's a file path, request signed URL; otherwise use as-is
 */
export async function getAttachmentURL(
  attachmentUrl: string | undefined | null,
  messageId: string
): Promise<string | null> {
  if (!attachmentUrl) return null;

  // If it's already a direct URL (not a file path), use it
  if (!isFilePath(attachmentUrl)) {
    return attachmentUrl;
  }

  // It's a file path, request signed URL
  try {
    return await getFileSignedURL(messageId);
  } catch (error) {
    console.error(`[FileURLs] Failed to get signed URL for message ${messageId}:`, error);
    return null;
  }
}

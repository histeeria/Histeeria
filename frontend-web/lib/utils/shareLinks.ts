/**
 * Share Link Generation Utilities
 * Generates share links for various platforms
 */

export interface ShareOptions {
  url: string;
  title: string;
  description?: string;
  image?: string;
  hashtags?: string[];
}

/**
 * Generate Twitter/X share link
 */
export function getTwitterShareLink(options: ShareOptions): string {
  const text = encodeURIComponent(`${options.title}${options.description ? ` - ${options.description}` : ''}`);
  const url = encodeURIComponent(options.url);
  const hashtags = options.hashtags?.map(tag => tag.replace('#', '')).join(',') || '';
  
  return `https://twitter.com/intent/tweet?text=${text}&url=${url}${hashtags ? `&hashtags=${hashtags}` : ''}`;
}

/**
 * Generate Facebook share link
 */
export function getFacebookShareLink(options: ShareOptions): string {
  const url = encodeURIComponent(options.url);
  return `https://www.facebook.com/sharer/sharer.php?u=${url}`;
}

/**
 * Generate LinkedIn share link
 */
export function getLinkedInShareLink(options: ShareOptions): string {
  const url = encodeURIComponent(options.url);
  const title = encodeURIComponent(options.title);
  const summary = encodeURIComponent(options.description || '');
  
  return `https://www.linkedin.com/sharing/share-offsite/?url=${url}&title=${title}&summary=${summary}`;
}

/**
 * Generate WhatsApp share link
 */
export function getWhatsAppShareLink(options: ShareOptions): string {
  const text = encodeURIComponent(`${options.title}${options.description ? ` - ${options.description}` : ''} ${options.url}`);
  return `https://wa.me/?text=${text}`;
}

/**
 * Generate Telegram share link
 */
export function getTelegramShareLink(options: ShareOptions): string {
  const url = encodeURIComponent(options.url);
  const text = encodeURIComponent(`${options.title}${options.description ? ` - ${options.description}` : ''}`);
  return `https://t.me/share/url?url=${url}&text=${text}`;
}

/**
 * Generate Email share link
 */
export function getEmailShareLink(options: ShareOptions): string {
  const subject = encodeURIComponent(options.title);
  const body = encodeURIComponent(`${options.description || ''}\n\n${options.url}`);
  return `mailto:?subject=${subject}&body=${body}`;
}

/**
 * Copy link to clipboard
 */
export async function copyToClipboard(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    } else {
      // Fallback for older browsers
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.style.position = 'fixed';
      textArea.style.opacity = '0';
      document.body.appendChild(textArea);
      textArea.select();
      const success = document.execCommand('copy');
      document.body.removeChild(textArea);
      return success;
    }
  } catch (error) {
    console.error('Failed to copy to clipboard:', error);
    return false;
  }
}

/**
 * Generate QR code data URL (using a QR code API)
 */
export function getQRCodeUrl(text: string, size = 200): string {
  return `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(text)}`;
}


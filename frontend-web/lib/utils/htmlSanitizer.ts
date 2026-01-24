/**
 * HTML Sanitizer
 * Prevents stored XSS attacks by sanitizing rich text editor content
 */

// Allowed HTML tags for rich text content
const ALLOWED_TAGS = new Set([
  'p', 'br', 'strong', 'em', 'u', 's', 'code', 'pre',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  'ul', 'ol', 'li',
  'blockquote',
  'a', 'img',
  'table', 'thead', 'tbody', 'tr', 'th', 'td',
  'span', 'div',
]);

// Allowed attributes per tag
const ALLOWED_ATTRIBUTES: Record<string, Set<string>> = {
  'a': new Set(['href', 'title', 'target', 'rel']),
  'img': new Set(['src', 'alt', 'title', 'width', 'height']),
  'code': new Set(['class']),
  'pre': new Set(['class']),
  'span': new Set(['class', 'style']),
  'div': new Set(['class']),
  'td': new Set(['colspan', 'rowspan']),
  'th': new Set(['colspan', 'rowspan']),
};

// Allowed URL protocols
const ALLOWED_PROTOCOLS = new Set(['http:', 'https:', 'mailto:']);

/**
 * Sanitize HTML content
 * Removes potentially dangerous tags, attributes, and scripts
 */
export function sanitizeHTML(html: string): string {
  if (typeof window === 'undefined') {
    // Server-side: use a simple regex-based approach
    return sanitizeHTMLServer(html);
  }
  
  // Client-side: use DOM API for better parsing
  return sanitizeHTMLClient(html);
}

/**
 * Server-side HTML sanitization (regex-based)
 */
function sanitizeHTMLServer(html: string): string {
  if (!html) return '';
  
  // Remove script tags and their content
  html = html.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
  
  // Remove event handlers (onclick, onerror, etc.)
  html = html.replace(/\s*on\w+\s*=\s*["'][^"']*["']/gi, '');
  html = html.replace(/\s*on\w+\s*=\s*[^\s>]*/gi, '');
  
  // Remove javascript: protocol
  html = html.replace(/javascript:/gi, '');
  
  // Remove data: protocol (except for images)
  html = html.replace(/(<(?!img)[^>]*)\s+src\s*=\s*["']data:[^"']*["']/gi, '$1');
  
  // Remove style tags
  html = html.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');
  
  // Remove iframe, object, embed tags
  html = html.replace(/<(iframe|object|embed|frame|frameset|applet|bgsound|link|meta|base)\b[^<]*(?:(?!<\/\1>)<[^<]*)*<\/\1>/gi, '');
  html = html.replace(/<(iframe|object|embed|frame|frameset|applet|bgsound|link|meta|base)\b[^>]*>/gi, '');
  
  return html;
}

/**
 * Client-side HTML sanitization (DOM-based)
 */
function sanitizeHTMLClient(html: string): string {
  if (!html) return '';
  
  const doc = new DOMParser().parseFromString(html, 'text/html');
  const body = doc.body;
  
  // Recursively sanitize nodes
  sanitizeNode(body);
  
  return body.innerHTML;
}

/**
 * Recursively sanitize DOM node
 */
function sanitizeNode(node: Node): void {
  if (node.nodeType === Node.TEXT_NODE) {
    return; // Text nodes are safe
  }
  
  if (node.nodeType !== Node.ELEMENT_NODE) {
    node.parentNode?.removeChild(node);
    return;
  }
  
  const element = node as Element;
  const tagName = element.tagName.toLowerCase();
  
  // Remove disallowed tags
  if (!ALLOWED_TAGS.has(tagName)) {
    // Keep children but remove the tag itself
    while (element.firstChild) {
      element.parentNode?.insertBefore(element.firstChild, element);
    }
    element.parentNode?.removeChild(element);
    return;
  }
  
  // Sanitize attributes
  const allowedAttrs = ALLOWED_ATTRIBUTES[tagName] || new Set();
  const attrs = Array.from(element.attributes);
  
  for (const attr of attrs) {
    const attrName = attr.name.toLowerCase();
    
    // Remove event handlers
    if (attrName.startsWith('on')) {
      element.removeAttribute(attr.name);
      continue;
    }
    
    // Remove disallowed attributes
    if (!allowedAttrs.has(attrName)) {
      element.removeAttribute(attr.name);
      continue;
    }
    
    // Sanitize attribute values
    if (attrName === 'href' || attrName === 'src') {
      const value = attr.value.trim().toLowerCase();
      
      // Check protocol
      const hasProtocol = value.includes(':');
      if (hasProtocol) {
        const protocol = value.split(':')[0] + ':';
        if (!ALLOWED_PROTOCOLS.has(protocol)) {
          element.removeAttribute(attr.name);
          continue;
        }
      }
      
      // Remove javascript: protocol
      if (value.startsWith('javascript:')) {
        element.removeAttribute(attr.name);
        continue;
      }
    }
    
    // Sanitize style attribute
    if (attrName === 'style') {
      const style = attr.value;
      // Remove potentially dangerous CSS
      const sanitizedStyle = style
        .replace(/expression\s*\(/gi, '')
        .replace(/javascript:/gi, '')
        .replace(/vbscript:/gi, '')
        .replace(/@import/gi, '');
      
      if (sanitizedStyle !== style) {
        element.setAttribute(attr.name, sanitizedStyle);
      }
    }
  }
  
  // Add rel="noopener noreferrer" to external links
  if (tagName === 'a' && element.hasAttribute('href')) {
    const href = element.getAttribute('href') || '';
    if (href.startsWith('http://') || href.startsWith('https://')) {
      element.setAttribute('rel', 'noopener noreferrer');
      element.setAttribute('target', '_blank');
    }
  }
  
  // Recursively sanitize children
  const children = Array.from(element.childNodes);
  for (const child of children) {
    sanitizeNode(child);
  }
}

/**
 * Sanitize text content (remove all HTML)
 */
export function sanitizeText(text: string): string {
  if (!text) return '';
  
  if (typeof window === 'undefined') {
    // Server-side: simple regex
    return text
      .replace(/<[^>]*>/g, '')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#x27;/g, "'");
  }
  
  // Client-side: use DOM
  const doc = new DOMParser().parseFromString(text, 'text/html');
  return doc.body.textContent || '';
}

/**
 * Escape HTML special characters
 */
export function escapeHTML(text: string): string {
  if (!text) return '';
  
  const div = typeof window !== 'undefined' 
    ? document.createElement('div')
    : null;
  
  if (div) {
    div.textContent = text;
    return div.innerHTML;
  }
  
  // Server-side fallback
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');
}

/**
 * Validate and sanitize URL
 */
export function sanitizeURL(url: string): string | null {
  if (!url) return null;
  
  try {
    const parsed = new URL(url);
    
    // Only allow http and https
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return null;
    }
    
    return parsed.toString();
  } catch {
    // Invalid URL
    return null;
  }
}

/**
 * Sanitize user input for display
 */
export function sanitizeUserInput(input: string, allowHTML: boolean = false): string {
  if (!input) return '';
  
  if (allowHTML) {
    return sanitizeHTML(input);
  }
  
  return escapeHTML(input);
}

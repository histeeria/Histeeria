/**
 * Secure Token Manager
 * Uses httpOnly cookies instead of localStorage to prevent XSS attacks
 */

const TOKEN_COOKIE_NAME = '__histeeria_token';
const REFRESH_TOKEN_COOKIE_NAME = '__histeeria_refresh';
const SESSION_WARNING_TIME = 5 * 60 * 1000; // 5 minutes before expiry

/**
 * Decode JWT token to get expiry (without verification)
 */
function decodeToken(token: string): { exp?: number; iat?: number; user_id?: string } | null {
  try {
    const base64Url = token.split('.')[1];
    if (!base64Url) return null;
    
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    return JSON.parse(jsonPayload);
  } catch {
    return null;
  }
}

/**
 * Get token expiry time from JWT
 */
function getTokenExpiry(token: string): number | null {
  const decoded = decodeToken(token);
  if (!decoded || !decoded.exp) return null;
  return decoded.exp * 1000; // Convert to milliseconds
}

/**
 * Get cookie value by name
 */
function getCookie(name: string): string | null {
  if (typeof document === 'undefined') return null;
  
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) {
    return parts.pop()?.split(';').shift() || null;
  }
  return null;
}

/**
 * Set secure cookie
 */
function setSecureCookie(name: string, value: string, maxAge?: number): void {
  if (typeof document === 'undefined') return;
  
  const isProduction = process.env.NODE_ENV === 'production';
  const secure = isProduction ? 'Secure;' : '';
  const sameSite = 'SameSite=Strict';
  const path = 'Path=/';
  const maxAgeStr = maxAge ? `Max-Age=${maxAge};` : '';
  
  document.cookie = `${name}=${value}; ${maxAgeStr} ${path}; ${sameSite}; ${secure} HttpOnly`;
}

/**
 * Delete cookie
 */
function deleteCookie(name: string): void {
  if (typeof document === 'undefined') return;
  
  document.cookie = `${name}=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT;`;
}

/**
 * Store token in httpOnly cookie (via API route)
 */
export async function storeToken(token: string, refreshToken?: string): Promise<void> {
  try {
    // Call API route to set httpOnly cookie
    const response = await fetch('/api/auth/set-token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token,
        refreshToken,
      }),
    });
    
    if (!response.ok) {
      console.error('[SecureTokenManager] Failed to set token cookie');
      // Fallback to localStorage (less secure but better than nothing)
      if (typeof window !== 'undefined' && window.localStorage) {
        localStorage.setItem('__fallback_token', token);
        if (refreshToken) {
          localStorage.setItem('__fallback_refresh', refreshToken);
        }
      }
    }
  } catch (error) {
    console.error('[SecureTokenManager] Error storing token:', error);
  }
}

/**
 * Get token from httpOnly cookie (via API route)
 */
export async function getToken(): Promise<string | null> {
  try {
    // Try to get token from API route
    const response = await fetch('/api/auth/get-token', {
      method: 'GET',
      credentials: 'include', // Include cookies
    });
    
    if (response.ok) {
      const data = await response.json();
      return data.token || null;
    }
    
    // Fallback to localStorage
    if (typeof window !== 'undefined' && window.localStorage) {
      return localStorage.getItem('__fallback_token');
    }
    
    return null;
  } catch (error) {
    console.error('[SecureTokenManager] Error getting token:', error);
    
    // Fallback to localStorage
    if (typeof window !== 'undefined' && window.localStorage) {
      return localStorage.getItem('__fallback_token');
    }
    
    return null;
  }
}

/**
 * Check if token is expired
 */
export async function isTokenExpired(): Promise<boolean> {
  try {
    const token = await getToken();
    if (!token) return true;
    
    const expiry = getTokenExpiry(token);
    if (!expiry) return false; // Can't determine, assume valid
    
    return Date.now() >= expiry;
  } catch {
    return true;
  }
}

/**
 * Get time until token expires (in milliseconds)
 */
export async function getTimeUntilExpiry(): Promise<number | null> {
  try {
    const token = await getToken();
    if (!token) return null;
    
    const expiry = getTokenExpiry(token);
    if (!expiry) return null;
    
    return expiry - Date.now();
  } catch {
    return null;
  }
}

/**
 * Check if token is about to expire (within warning time)
 */
export async function isTokenExpiringSoon(): Promise<boolean> {
  try {
    const timeUntilExpiry = await getTimeUntilExpiry();
    if (!timeUntilExpiry) return false;
    
    return timeUntilExpiry <= SESSION_WARNING_TIME && timeUntilExpiry > 0;
  } catch {
    return false;
  }
}

/**
 * Clear all token data
 */
export async function clearToken(): Promise<void> {
  try {
    // Call API route to clear httpOnly cookie
    await fetch('/api/auth/clear-token', {
      method: 'POST',
      credentials: 'include',
    });
    
    // Clear fallback localStorage
    if (typeof window !== 'undefined' && window.localStorage) {
      localStorage.removeItem('__fallback_token');
      localStorage.removeItem('__fallback_refresh');
    }
  } catch (error) {
    console.error('[SecureTokenManager] Error clearing token:', error);
  }
}

/**
 * Refresh token using refresh endpoint
 */
export async function refreshToken(): Promise<string | null> {
  try {
    const response = await fetch('/api/auth/refresh', {
      method: 'POST',
      credentials: 'include', // Include httpOnly cookies
    });
    
    if (!response.ok) {
      return null;
    }
    
    const data = await response.json();
    if (data.success && data.token) {
      return data.token;
    }
    
    return null;
  } catch (error) {
    console.error('[SecureTokenManager] Refresh failed:', error);
    return null;
  }
}

/**
 * Setup automatic token refresh interval
 */
export function setupTokenRefresh(callback?: (expired: boolean) => void): () => void {
  const checkInterval = setInterval(async () => {
    try {
      const expired = await isTokenExpired();
      
      if (expired) {
        // Token expired, try to refresh
        const newToken = await refreshToken();
        if (!newToken) {
          // Refresh failed
          await clearToken();
          callback?.(true);
        } else {
          callback?.(false);
        }
      } else {
        const expiringSoon = await isTokenExpiringSoon();
        if (expiringSoon) {
          // Token expiring soon, proactively refresh
          const newToken = await refreshToken();
          if (newToken) {
            console.log('[SecureTokenManager] Token refreshed proactively');
          }
        }
      }
    } catch (error) {
      console.error('[SecureTokenManager] Token check failed:', error);
    }
  }, 60000); // Check every minute
  
  return () => clearInterval(checkInterval);
}

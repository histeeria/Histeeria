/**
 * Token Manager
 * Handles token storage, refresh, and expiry management
 */

interface TokenData {
  token: string;
  expiresAt: number;
  refreshToken?: string;
}

const TOKEN_KEY = 'token';
const TOKEN_EXPIRY_KEY = 'token_expires_at';
const REFRESH_TOKEN_KEY = 'refresh_token';
const SESSION_WARNING_TIME = 5 * 60 * 1000; // 5 minutes before expiry

/**
 * Decode JWT token to get expiry (without verification)
 */
function decodeToken(token: string): { exp?: number; iat?: number } | null {
  try {
    const base64Url = token.split('.')[1];
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
 * Store token with expiry tracking
 */
export function storeToken(token: string, refreshToken?: string): void {
  localStorage.setItem(TOKEN_KEY, token);
  
  const expiry = getTokenExpiry(token);
  if (expiry) {
    localStorage.setItem(TOKEN_EXPIRY_KEY, expiry.toString());
  }
  
  if (refreshToken) {
    localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
  }
}

/**
 * Get stored token
 */
export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

/**
 * Get refresh token
 */
export function getRefreshToken(): string | null {
  return localStorage.getItem(REFRESH_TOKEN_KEY);
}

/**
 * Check if token is expired
 */
export function isTokenExpired(): boolean {
  const token = getToken();
  if (!token) return true;
  
  const expiryStr = localStorage.getItem(TOKEN_EXPIRY_KEY);
  if (!expiryStr) {
    // If no expiry stored, check token itself
    const expiry = getTokenExpiry(token);
    if (!expiry) return false; // Can't determine, assume valid
    return Date.now() >= expiry;
  }
  
  const expiry = parseInt(expiryStr, 10);
  return Date.now() >= expiry;
}

/**
 * Get time until token expires (in milliseconds)
 */
export function getTimeUntilExpiry(): number | null {
  const expiryStr = localStorage.getItem(TOKEN_EXPIRY_KEY);
  if (!expiryStr) {
    const token = getToken();
    if (!token) return null;
    const expiry = getTokenExpiry(token);
    if (!expiry) return null;
    return expiry - Date.now();
  }
  
  const expiry = parseInt(expiryStr, 10);
  return expiry - Date.now();
}

/**
 * Check if token is about to expire (within warning time)
 */
export function isTokenExpiringSoon(): boolean {
  const timeUntilExpiry = getTimeUntilExpiry();
  if (!timeUntilExpiry) return false;
  return timeUntilExpiry <= SESSION_WARNING_TIME && timeUntilExpiry > 0;
}

/**
 * Clear all token data
 */
export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(TOKEN_EXPIRY_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
}

/**
 * Refresh token using refresh endpoint
 */
export async function refreshToken(): Promise<string | null> {
  const refreshTokenValue = getRefreshToken();
  const currentToken = getToken();
  
  if (!refreshTokenValue && !currentToken) {
    return null;
  }
  
  try {
    const API_BASE_URL = '/api/proxy';
    const response = await fetch(`${API_BASE_URL}/v1/auth/refresh`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(currentToken && { 'Authorization': `Bearer ${currentToken}` }),
      },
      body: refreshTokenValue ? JSON.stringify({ refresh_token: refreshTokenValue }) : undefined,
    });
    
    if (!response.ok) {
      throw new Error('Token refresh failed');
    }
    
    const data = await response.json();
    if (data.success && data.token) {
      storeToken(data.token, data.refresh_token);
      return data.token;
    }
    
    return null;
  } catch (error) {
    console.error('[TokenManager] Refresh failed:', error);
    return null;
  }
}

/**
 * Setup automatic token refresh interval
 */
export function setupTokenRefresh(callback?: (expired: boolean) => void): () => void {
  const checkInterval = setInterval(() => {
    if (isTokenExpired()) {
      // Token expired, try to refresh
      refreshToken()
        .then((newToken) => {
          if (!newToken) {
            // Refresh failed, clear token and notify
            clearToken();
            callback?.(true);
          } else {
            callback?.(false);
          }
        })
        .catch(() => {
          clearToken();
          callback?.(true);
        });
    } else if (isTokenExpiringSoon()) {
      // Token expiring soon, proactively refresh
      refreshToken()
        .then((newToken) => {
          if (newToken) {
            console.log('[TokenManager] Token refreshed proactively');
          }
        })
        .catch((error) => {
          console.error('[TokenManager] Proactive refresh failed:', error);
        });
    }
  }, 60000); // Check every minute
  
  return () => clearInterval(checkInterval);
}

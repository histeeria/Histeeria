'use client';

/**
 * Auth Context
 * Provides authentication state and session management
 */

import { createContext, useContext, useEffect, useState, useCallback, ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { 
  getToken, 
  isTokenExpired, 
  isTokenExpiringSoon, 
  getTimeUntilExpiry,
  clearToken,
  refreshToken,
  setupTokenRefresh,
} from './tokenManager';

interface AuthContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  isSessionExpiring: boolean;
  timeUntilExpiry: number | null;
  refreshSession: () => Promise<boolean>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isSessionExpiring, setIsSessionExpiring] = useState(false);
  const [timeUntilExpiry, setTimeUntilExpiry] = useState<number | null>(null);
  const router = useRouter();

  const checkAuth = useCallback(() => {
    const token = getToken();
    if (!token || isTokenExpired()) {
      setIsAuthenticated(false);
      setIsLoading(false);
      return false;
    }
    
    setIsAuthenticated(true);
    setIsLoading(false);
    
    // Check if session is expiring soon
    const expiringSoon = isTokenExpiringSoon();
    setIsSessionExpiring(expiringSoon);
    
    // Update time until expiry
    const timeLeft = getTimeUntilExpiry();
    setTimeUntilExpiry(timeLeft);
    
    return true;
  }, []);

  const refreshSession = useCallback(async (): Promise<boolean> => {
    try {
      const newToken = await refreshToken();
      if (newToken) {
        checkAuth();
        return true;
      }
      return false;
    } catch (error) {
      console.error('[AuthContext] Refresh failed:', error);
      return false;
    }
  }, [checkAuth]);

  const logout = useCallback(() => {
    clearToken();
    setIsAuthenticated(false);
    setIsSessionExpiring(false);
    setTimeUntilExpiry(null);
    router.push('/auth');
  }, [router]);

  useEffect(() => {
    // Initial auth check
    checkAuth();

    // Setup token refresh interval
    const cleanup = setupTokenRefresh((expired) => {
      if (expired) {
        // Token expired and couldn't refresh
        logout();
      } else {
        // Token refreshed successfully
        checkAuth();
      }
    });

    // Update expiry time every 30 seconds
    const expiryInterval = setInterval(() => {
      if (isAuthenticated) {
        const expiringSoon = isTokenExpiringSoon();
        setIsSessionExpiring(expiringSoon);
        
        const timeLeft = getTimeUntilExpiry();
        setTimeUntilExpiry(timeLeft);
      }
    }, 30000);

    return () => {
      cleanup();
      clearInterval(expiryInterval);
    };
  }, [isAuthenticated, checkAuth, logout]);

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
        isLoading,
        isSessionExpiring,
        timeUntilExpiry,
        refreshSession,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

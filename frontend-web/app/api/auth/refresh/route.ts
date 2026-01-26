import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';

const TOKEN_COOKIE_NAME = '__histeeria_token';
const REFRESH_TOKEN_COOKIE_NAME = '__histeeria_refresh';
const MAX_AGE = 30 * 24 * 60 * 60; // 30 days

export async function POST() {
  try {
    const cookieStore = await cookies();
    const token = cookieStore.get(TOKEN_COOKIE_NAME)?.value;
    const refreshToken = cookieStore.get(REFRESH_TOKEN_COOKIE_NAME)?.value;
    
    if (!token && !refreshToken) {
      return NextResponse.json(
        { error: 'No token found' },
        { status: 401 }
      );
    }
    
    // Call backend to refresh token
    const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8080/api/v1';
    
    const response = await fetch(`${API_BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(token && { 'Authorization': `Bearer ${token}` }),
      },
      body: refreshToken ? JSON.stringify({ refresh_token: refreshToken }) : undefined,
    });
    
    if (!response.ok) {
      throw new Error('Token refresh failed');
    }
    
    const data = await response.json();
    
    if (data.success && data.token) {
      const isProduction = process.env.NODE_ENV === 'production';
      
      // Set new token cookie
      cookieStore.set({
        name: TOKEN_COOKIE_NAME,
        value: data.token,
        httpOnly: true,
        secure: isProduction,
        sameSite: 'strict',
        maxAge: MAX_AGE,
        path: '/',
      });
      
      // Update refresh token if provided
      if (data.refresh_token) {
        cookieStore.set({
          name: REFRESH_TOKEN_COOKIE_NAME,
          value: data.refresh_token,
          httpOnly: true,
          secure: isProduction,
          sameSite: 'strict',
          maxAge: MAX_AGE,
          path: '/',
        });
      }
      
      return NextResponse.json({
        success: true,
        token: data.token,
      });
    }
    
    return NextResponse.json(
      { error: 'Failed to refresh token' },
      { status: 401 }
    );
  } catch (error) {
    console.error('[RefreshToken] Error:', error);
    return NextResponse.json(
      { error: 'Failed to refresh token' },
      { status: 500 }
    );
  }
}

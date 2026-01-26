import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';

const TOKEN_COOKIE_NAME = '__histeeria_token';
const REFRESH_TOKEN_COOKIE_NAME = '__histeeria_refresh';
const MAX_AGE = 30 * 24 * 60 * 60; // 30 days

export async function POST(request: NextRequest) {
  try {
    const { token, refreshToken } = await request.json();
    
    if (!token) {
      return NextResponse.json(
        { error: 'Token is required' },
        { status: 400 }
      );
    }
    
    const cookieStore = await cookies();
    const isProduction = process.env.NODE_ENV === 'production';
    
    // Set token cookie with httpOnly flag
    cookieStore.set({
      name: TOKEN_COOKIE_NAME,
      value: token,
      httpOnly: true,
      secure: isProduction,
      sameSite: 'strict',
      maxAge: MAX_AGE,
      path: '/',
    });
    
    // Set refresh token cookie if provided
    if (refreshToken) {
      cookieStore.set({
        name: REFRESH_TOKEN_COOKIE_NAME,
        value: refreshToken,
        httpOnly: true,
        secure: isProduction,
        sameSite: 'strict',
        maxAge: MAX_AGE,
        path: '/',
      });
    }
    
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('[SetToken] Error:', error);
    return NextResponse.json(
      { error: 'Failed to set token' },
      { status: 500 }
    );
  }
}

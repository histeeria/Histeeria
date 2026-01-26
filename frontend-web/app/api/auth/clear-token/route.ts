import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';

const TOKEN_COOKIE_NAME = '__histeeria_token';
const REFRESH_TOKEN_COOKIE_NAME = '__histeeria_refresh';

export async function POST() {
  try {
    const cookieStore = await cookies();
    
    // Delete both cookies
    cookieStore.delete(TOKEN_COOKIE_NAME);
    cookieStore.delete(REFRESH_TOKEN_COOKIE_NAME);
    
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('[ClearToken] Error:', error);
    return NextResponse.json(
      { error: 'Failed to clear token' },
      { status: 500 }
    );
  }
}

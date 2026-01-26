import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';

const TOKEN_COOKIE_NAME = '__histeeria_token';

export async function GET() {
  try {
    const cookieStore = await cookies();
    const token = cookieStore.get(TOKEN_COOKIE_NAME)?.value;
    
    if (!token) {
      return NextResponse.json({ token: null });
    }
    
    return NextResponse.json({ token });
  } catch (error) {
    console.error('[GetToken] Error:', error);
    return NextResponse.json(
      { error: 'Failed to get token' },
      { status: 500 }
    );
  }
}

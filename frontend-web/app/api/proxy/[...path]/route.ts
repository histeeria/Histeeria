import { NextRequest, NextResponse } from 'next/server';

// Route segment config for Next.js
export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

// Auto-detect environment and use appropriate backend URL
const getBackendUrl = () => {
  // Always check NODE_ENV first - if development, use localhost
  if (process.env.NODE_ENV === 'development') {
    console.log('[Proxy] Development mode detected - using localhost:8081');
    return 'http://127.0.0.1:8081';
  }

  // Production: use environment variable if set
  const envUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
  if (envUrl) {
    // URL normalization: Remove trailing /api/v1, /api, or /v1
    // This prevents duplication since the proxy manually adds /api/ and the path includes v1
    let url = envUrl;

    // Remove trailing slashes first
    url = url.replace(/\/+$/, '');

    // Remove known suffixes to get the true root domain
    if (url.endsWith('/api/v1')) {
      url = url.substring(0, url.length - '/api/v1'.length);
    } else if (url.endsWith('/api')) {
      url = url.substring(0, url.length - '/api'.length);
    }

    console.log('[Proxy] Production mode - formatted root URL:', url);
    return url;
  }

  // Fallback to localhost (shouldn't happen in production)
  console.log('[Proxy] No API_BASE_URL set - using localhost:8081');
  return 'http://127.0.0.1:8081';
};

const BACKEND_URL = getBackendUrl();

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const resolvedParams = await params;
  const path = resolvedParams.path;
  console.log('[Proxy Route] GET called with path:', path);
  return proxyRequest(request, path, 'GET');
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  try {
    console.log('[Proxy Route] POST handler called');
    const resolvedParams = await params;
    console.log('[Proxy Route] Resolved params:', resolvedParams);
    const path = resolvedParams.path;
    console.log('[Proxy Route] POST called with path:', path);

    if (!path || path.length === 0) {
      console.error('[Proxy Route] No path in params');
      return NextResponse.json(
        { success: false, message: 'No path segments in route params', params: resolvedParams },
        { status: 400 }
      );
    }

    return proxyRequest(request, path, 'POST');
  } catch (error) {
    console.error('[Proxy Route] POST handler error:', error);
    return NextResponse.json(
      {
        success: false,
        message: 'Route handler error',
        error: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 500 }
    );
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const resolvedParams = await params;
  const path = resolvedParams.path;
  return proxyRequest(request, path, 'PUT');
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const resolvedParams = await params;
  const path = resolvedParams.path;
  return proxyRequest(request, path, 'PATCH');
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const resolvedParams = await params;
  const path = resolvedParams.path;
  return proxyRequest(request, path, 'DELETE');
}

async function proxyRequest(
  request: NextRequest,
  pathSegments: string[],
  method: string
) {
  // Always log in development for debugging
  console.log(`[Proxy] ${method} request received`);
  console.log(`[Proxy] Path segments:`, pathSegments);
  console.log(`[Proxy] Request URL:`, request.url);

  try {
    // Validate path segments
    if (!pathSegments || pathSegments.length === 0) {
      console.error('[Proxy] No path segments provided');
      return NextResponse.json(
        { success: false, message: 'Invalid path: no segments provided' },
        { status: 400 }
      );
    }

    const path = pathSegments.join('/');
    const url = new URL(request.url);
    const queryString = url.searchParams.toString();

    // Construct backend URL: /api/v1/... (path already includes 'v1')
    const backendUrl = `${BACKEND_URL}/api/${path}${queryString ? `?${queryString}` : ''}`;

    // Check content type to determine how to handle the body
    const contentType = request.headers.get('content-type');
    const isFormData = contentType?.includes('multipart/form-data');

    // Always log in development
    console.log(`[Proxy] ${method} ${backendUrl}`);
    console.log(`[Proxy] Path: ${path}`);
    console.log(`[Proxy] Content-Type:`, contentType);
    console.log(`[Proxy] Is FormData:`, isFormData);
    console.log(`[Proxy] Using BACKEND_URL: ${BACKEND_URL}`);

    // Get request body if present (for POST, PUT, PATCH)
    let body: any = null;

    if (method !== 'GET' && method !== 'DELETE') {
      try {
        if (isFormData) {
          // For file uploads, pass FormData as-is
          body = await request.formData();
        } else {
          // For JSON requests, get text
          const bodyText = await request.text();
          // Only set body if it's not empty
          if (bodyText && bodyText.trim().length > 0) {
            body = bodyText;
          }
        }
      } catch (e) {
        // No body or error reading body - that's okay
        console.log('[Proxy] No body or error reading body:', e instanceof Error ? e.message : 'Unknown');
      }
    }

    // Forward headers (excluding browser-specific headers)
    // Since this is a server-to-server request, we don't want to forward Origin, Referer, etc.
    const headers: HeadersInit = {};

    // Only set Content-Type for JSON requests (NOT for FormData - fetch will set it automatically with boundary)
    if (method !== 'GET' && method !== 'DELETE' && body && !isFormData) {
      headers['Content-Type'] = 'application/json';
    }

    // Log body info for debugging
    if (process.env.NODE_ENV === 'development' && body) {
      if (typeof body === 'string') {
        console.log('[Proxy] Body (first 500 chars):', body.substring(0, 500));
        try {
          const bodyObj = JSON.parse(body);
          console.log('[Proxy] Body parsed - encrypted_content:', bodyObj.encrypted_content ? `${bodyObj.encrypted_content.substring(0, 50)}...` : 'null', 'iv:', bodyObj.iv || 'null');
        } catch (e) {
          // Not JSON, that's okay
        }
      } else {
        console.log('[Proxy] Body type:', typeof body, 'isFormData:', isFormData);
      }
    }

    // Only forward specific headers we need (no browser headers like Origin, Referer)
    const forwardedHeaders = ['authorization'];
    request.headers.forEach((value, key) => {
      const lowerKey = key.toLowerCase();
      // Skip browser-specific headers that could trigger CORS
      if (
        lowerKey === 'origin' ||
        lowerKey === 'referer' ||
        lowerKey === 'sec-fetch-site' ||
        lowerKey === 'sec-fetch-mode' ||
        lowerKey === 'sec-fetch-dest' ||
        lowerKey === 'host'
      ) {
        return; // Skip these headers
      }

      if (
        forwardedHeaders.includes(lowerKey) ||
        (lowerKey.startsWith('x-') && lowerKey !== 'x-forwarded-host')
      ) {
        // Use standard case for Authorization header (some backends are picky)
        if (lowerKey === 'authorization') {
          headers['Authorization'] = value;
        } else {
          headers[key] = value;
        }
      }
    });

    // Always log in development for debugging
    console.log(`[Proxy] Headers being sent:`, Object.keys(headers));
    console.log(`[Proxy] Has Authorization header:`, !!headers['Authorization'] || !!headers['authorization']);
    if (headers['Authorization'] || headers['authorization']) {
      const authHeader = headers['Authorization'] || headers['authorization'];
      console.log(`[Proxy] Authorization header (first 50 chars):`, typeof authHeader === 'string' ? authHeader.substring(0, 50) + '...' : 'Not a string');
    }
    console.log(`[Proxy] Attempting ${method} request to: ${backendUrl}`);

    // Create abort controller for timeout (30 seconds)
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000);

    // Use fetch with explicit configuration for Next.js server-side
    const fetchOptions: RequestInit = {
      method,
      headers,
      // Only include body if it exists and is not empty
      ...(body ? { body } : {}),
      // Add cache and other options for Next.js compatibility
      cache: 'no-store',
      signal: controller.signal,
    };

    let response: Response;
    try {
      if (process.env.NODE_ENV === 'development') {
        console.log('[Proxy] Fetch options:', {
          method,
          url: backendUrl,
          hasBody: !!body,
          headers: Object.keys(headers),
        });
      }

      response = await fetch(backendUrl, fetchOptions);
      clearTimeout(timeoutId);
    } catch (fetchError) {
      clearTimeout(timeoutId);
      const errorMsg = fetchError instanceof Error ? fetchError.message : 'Unknown fetch error';
      console.error('[Proxy] Fetch error:', errorMsg);

      if (fetchError instanceof Error && fetchError.name === 'AbortError') {
        throw new Error('Request timeout - backend server did not respond within 30 seconds');
      }

      // Provide more context about the error
      if (errorMsg.includes('ECONNREFUSED') || errorMsg.includes('fetch failed')) {
        throw new Error(`Failed to connect to backend at ${backendUrl}. Is the backend running?`);
      }

      throw fetchError;
    }

    if (process.env.NODE_ENV === 'development') {
      console.log(`[Proxy] Response status: ${response.status} for ${backendUrl}`);
    }

    const data = await response.text();
    let jsonData;

    try {
      jsonData = JSON.parse(data);
    } catch {
      jsonData = { message: data, raw: true };
    }

    // Log ALL responses in development for debugging
    if (process.env.NODE_ENV === 'development') {
      if (response.status >= 400) {
        console.error(`[Proxy] ==========================================`);
        console.error(`[Proxy] Backend returned ${response.status} error`);
        console.error(`[Proxy] URL: ${backendUrl}`);
        console.error(`[Proxy] Method: ${method}`);
        console.error(`[Proxy] Response body:`, JSON.stringify(jsonData, null, 2));
        console.error(`[Proxy] Raw response:`, data.substring(0, 500));
        console.error(`[Proxy] ==========================================`);
      } else {
        console.log(`[Proxy] Success response (${response.status}):`, JSON.stringify(jsonData, null, 2).substring(0, 200));
      }
    }

    // Forward important headers from backend (including token refresh)
    const responseHeaders: HeadersInit = {
      'Content-Type': 'application/json',
      // Ensure no caching at any layer (browser, CDN, proxies)
      'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0, s-maxage=0',
      'Pragma': 'no-cache',
      'Expires': '0',
    };

    // Forward X-New-Token for sliding window authentication
    const newToken = response.headers.get('X-New-Token');
    if (newToken) {
      responseHeaders['X-New-Token'] = newToken;
    }

    return NextResponse.json(jsonData, {
      status: response.status,
      headers: responseHeaders,
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const errorStack = error instanceof Error ? error.stack : undefined;

    // Reconstruct backendUrl for error reporting (in case it failed before assignment)
    const path = pathSegments?.join('/') || 'unknown';
    const url = new URL(request.url);
    const queryString = url.searchParams.toString();
    const attemptedUrl = `${BACKEND_URL}/api/${path}${queryString ? `?${queryString}` : ''}`;

    // Always log errors for debugging
    console.error('[Proxy] Error details:');
    console.error('  Message:', errorMessage);
    console.error('  Backend URL:', BACKEND_URL);
    console.error('  Attempted URL:', attemptedUrl);
    console.error('  Method:', method);
    console.error('  Path segments:', pathSegments);
    if (process.env.NODE_ENV === 'development') {
      console.error('  Stack:', errorStack);
    }

    // Check if it's a timeout error
    if (errorMessage.includes('timeout') || errorMessage.includes('aborted')) {
      // SECURITY: Don't expose internal URLs in production
      const isDevelopment = process.env.NODE_ENV === 'development';
      return NextResponse.json(
        {
          success: false,
          message: 'Request timeout - the server may be slow or unresponsive',
          ...(isDevelopment && {
            error: errorMessage,
            backend_url: BACKEND_URL,
            attempted_url: attemptedUrl,
            hint: `Backend at ${BACKEND_URL} did not respond within 30 seconds.`,
          }),
        },
        { status: 504 }
      );
    }

    // Check if it's a connection error
    if (errorMessage.includes('ECONNREFUSED') || errorMessage.includes('fetch failed')) {
      // SECURITY: Don't expose internal URLs in production
      const isDevelopment = process.env.NODE_ENV === 'development';
      return NextResponse.json(
        {
          success: false,
          message: 'Failed to connect to backend server',
          ...(isDevelopment && {
            error: errorMessage,
            backend_url: BACKEND_URL,
            attempted_url: attemptedUrl,
            hint: `Backend should be running. Check: 1) Backend is running, 2) Port matches, 3) No firewall blocking`,
          }),
        },
        { status: 502 }
      );
    }

    // Generic error
    const isDevelopment = process.env.NODE_ENV === 'development';
    return NextResponse.json(
      {
        success: false,
        message: 'Proxy request failed',
        ...(isDevelopment && {
          error: errorMessage,
          backend_url: BACKEND_URL,
          attempted_url: attemptedUrl,
        }),
      },
      { status: 500 }
    );
  }
}

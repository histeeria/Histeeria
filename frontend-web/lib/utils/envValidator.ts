/**
 * Environment Variable Validator
 * Ensures all required environment variables are set at runtime
 */

interface EnvConfig {
  NEXT_PUBLIC_API_BASE_URL: string;
  NEXT_PUBLIC_APP_URL: string;
  NEXT_PUBLIC_WS_URL?: string;
}

class EnvironmentError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EnvironmentError';
  }
}

/**
 * Validate required environment variables
 */
export function validateEnv(): EnvConfig {
  const errors: string[] = [];
  
  // Required variables
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL;
  const APP_URL = process.env.NEXT_PUBLIC_APP_URL;
  
  if (!API_BASE_URL) {
    errors.push('NEXT_PUBLIC_API_BASE_URL is required');
  } else {
    // Validate URL format
    try {
      new URL(API_BASE_URL);
    } catch {
      errors.push('NEXT_PUBLIC_API_BASE_URL must be a valid URL');
    }
  }
  
  if (!APP_URL) {
    errors.push('NEXT_PUBLIC_APP_URL is required');
  } else {
    // Validate URL format
    try {
      new URL(APP_URL);
    } catch {
      errors.push('NEXT_PUBLIC_APP_URL must be a valid URL');
    }
  }
  
  // Optional but recommended
  const WS_URL = process.env.NEXT_PUBLIC_WS_URL;
  if (WS_URL) {
    if (!WS_URL.startsWith('ws://') && !WS_URL.startsWith('wss://')) {
      errors.push('NEXT_PUBLIC_WS_URL must start with ws:// or wss://');
    }
  }
  
  // Throw error if validation failed
  if (errors.length > 0) {
    const errorMessage = [
      '❌ Environment Variable Validation Failed:',
      '',
      ...errors.map(err => `  - ${err}`),
      '',
      '📝 Please check your .env.local file and ensure all required variables are set.',
      '📖 See ENV_TEMPLATE.md for reference.',
    ].join('\n');
    
    throw new EnvironmentError(errorMessage);
  }
  
  return {
    NEXT_PUBLIC_API_BASE_URL: API_BASE_URL!,
    NEXT_PUBLIC_APP_URL: APP_URL!,
    NEXT_PUBLIC_WS_URL: WS_URL,
  };
}

/**
 * Get validated environment configuration
 * Use this instead of directly accessing process.env
 */
let cachedEnv: EnvConfig | null = null;

export function getEnv(): EnvConfig {
  if (!cachedEnv) {
    cachedEnv = validateEnv();
  }
  return cachedEnv;
}

/**
 * Check API health
 */
export async function checkAPIHealth(): Promise<{ healthy: boolean; error?: string }> {
  try {
    const env = getEnv();
    
    // Remove /v1 suffix if present for health check
    const baseUrl = env.NEXT_PUBLIC_API_BASE_URL.replace(/\/v1$/, '');
    
    const response = await fetch(`${baseUrl}/health`, {
      method: 'GET',
      signal: AbortSignal.timeout(5000), // 5 second timeout
    });
    
    if (!response.ok) {
      return {
        healthy: false,
        error: `API returned ${response.status} ${response.statusText}`,
      };
    }
    
    const data = await response.json();
    
    if (data.status !== 'healthy' && data.status !== 'ok') {
      return {
        healthy: false,
        error: `API health check failed: ${data.status}`,
      };
    }
    
    return { healthy: true };
  } catch (error) {
    return {
      healthy: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Warn about environment issues in development
 */
export function warnEnvIssues(): void {
  if (process.env.NODE_ENV !== 'development') {
    return;
  }
  
  try {
    const env = getEnv();
    
    // Warn about HTTP in production-like URLs
    if (env.NEXT_PUBLIC_API_BASE_URL.startsWith('http://') && 
        !env.NEXT_PUBLIC_API_BASE_URL.includes('localhost')) {
      console.warn('⚠️  API_BASE_URL uses HTTP instead of HTTPS. This is insecure for production!');
    }
    
    if (env.NEXT_PUBLIC_WS_URL?.startsWith('ws://') && 
        !env.NEXT_PUBLIC_WS_URL.includes('localhost')) {
      console.warn('⚠️  WS_URL uses WS instead of WSS. This is insecure for production!');
    }
    
    // Check CORS configuration
    checkAPIHealth().then(({ healthy, error }) => {
      if (!healthy) {
        console.warn('⚠️  API health check failed:', error);
        console.warn('💡 Make sure your backend is running and CORS is configured correctly.');
      } else {
        console.log('✅ API connection healthy');
      }
    });
  } catch (error) {
    if (error instanceof EnvironmentError) {
      console.error(error.message);
    }
  }
}

// Auto-validate on import in development
if (typeof window !== 'undefined' && process.env.NODE_ENV === 'development') {
  setTimeout(() => warnEnvIssues(), 1000);
}

/**
 * Retry Utilities
 * Exponential backoff retry mechanism
 */

export interface RetryOptions {
  maxRetries?: number;
  initialDelay?: number;
  maxDelay?: number;
  backoffMultiplier?: number;
  onRetry?: (attempt: number, error: Error) => void;
}

export async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const {
    maxRetries = 3,
    initialDelay = 1000,
    maxDelay = 10000,
    backoffMultiplier = 2,
    onRetry,
  } = options;

  let lastError: Error;
  let delay = initialDelay;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));

      if (attempt === maxRetries) {
        throw lastError;
      }

      // Call onRetry callback
      if (onRetry) {
        onRetry(attempt + 1, lastError);
      }

      // Wait before retrying
      await new Promise(resolve => setTimeout(resolve, delay));

      // Exponential backoff
      delay = Math.min(delay * backoffMultiplier, maxDelay);
    }
  }

  throw lastError!;
}

/**
 * Retry with exponential backoff for API calls
 */
export async function retryAPI<T>(
  fn: () => Promise<T>,
  options?: RetryOptions
): Promise<T> {
  return retryWithBackoff(fn, {
    maxRetries: 3,
    initialDelay: 1000,
    maxDelay: 10000,
    backoffMultiplier: 2,
    ...options,
  });
}

/**
 * Check if error is retryable
 */
export function isRetryableError(error: unknown): boolean {
  if (error instanceof TypeError && error.message === 'Failed to fetch') {
    return true; // Network error
  }

  if (error instanceof Error) {
    // Retry on 5xx errors or network errors
    const message = error.message.toLowerCase();
    return message.includes('network') || 
           message.includes('timeout') ||
           message.includes('500') ||
           message.includes('502') ||
           message.includes('503') ||
           message.includes('504');
  }

  return false;
}

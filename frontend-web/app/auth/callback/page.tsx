'use client';

import { useEffect, useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Image from 'next/image';
import { AuthErrorBoundary } from '@/components/auth/AuthErrorBoundary';

const API_BASE_URL = '/api/proxy';

function OAuthCallbackContent() {
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const [message, setMessage] = useState('Completing authentication...');
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    const handleCallback = async () => {
      const code = searchParams.get('code');
      const state = searchParams.get('state');
      const error = searchParams.get('error');
      const provider = searchParams.get('provider') || 'google';

      if (error) {
        setStatus('error');
        setMessage('Authentication was cancelled or failed');
        setTimeout(() => router.push('/auth'), 3000);
        return;
      }

      if (!code || !state) {
        setStatus('error');
        setMessage('Invalid callback parameters');
        setTimeout(() => router.push('/auth'), 3000);
        return;
      }
      
      // Validate state token (CSRF protection)
      const savedState = sessionStorage.getItem('oauth_state');
      const savedProvider = sessionStorage.getItem('oauth_provider');
      
      if (!savedState || savedState !== state || savedProvider !== provider) {
        setStatus('error');
        setMessage('Invalid authentication request. Please try again.');
        sessionStorage.removeItem('oauth_state');
        sessionStorage.removeItem('oauth_provider');
        setTimeout(() => router.push('/auth'), 3000);
        return;
      }
      
      // Clear stored state
      sessionStorage.removeItem('oauth_state');
      sessionStorage.removeItem('oauth_provider');

      try {
        // Call the exchange endpoint to swap code for JWT token
        const response = await fetch(
          `${API_BASE_URL}/v1/auth/${provider}/exchange`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ code }),
          }
        );
        const data = await response.json();

        if (data.success && data.token) {
          // Store JWT token with expiry tracking
          const { storeToken } = await import('@/lib/auth/tokenManager');
          storeToken(data.token, data.refresh_token);
          setStatus('success');
          
          // Format provider name
          const providerName = provider.charAt(0).toUpperCase() + provider.slice(1);
          setMessage(`Successfully signed in with ${providerName}!`);
          
          // Redirect to home
          setTimeout(() => router.push('/'), 1500);
        } else {
          setStatus('error');
          setMessage(data.message || 'Authentication failed');
          setTimeout(() => router.push('/auth'), 3000);
        }
      } catch (err) {
        setStatus('error');
        setMessage('Failed to complete authentication');
        setTimeout(() => router.push('/auth'), 3000);
      }
    };

    handleCallback();
  }, [searchParams, router]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-white">
      <div className="w-full max-w-md px-8 py-12 text-center">
        {/* Logo and Brand */}
        <div className="mb-12 flex flex-col items-center gap-3">
          <Image
            src="/assets/u.png"
            alt="UpVista"
            width={70}
            height={70}
            className="object-contain"
          />
          <h2 className="text-2xl font-bold tracking-tight text-gray-900">
            <span className="bg-gradient-to-r from-purple-600 to-blue-600 bg-clip-text text-transparent">
              Histeeria
            </span>
          </h2>
        </div>

        {status === 'loading' && (
          <div className="space-y-6">
            <div className="mx-auto h-12 w-12 animate-spin rounded-full border-4 border-gray-200 border-t-blue-600"></div>
            <p className="text-base text-gray-600">{message}</p>
          </div>
        )}

        {status === 'success' && (
          <div className="rounded-2xl border-2 border-green-400 bg-green-50 p-6">
            <p className="text-base font-semibold text-green-700">{message}</p>
            <p className="mt-2 text-sm text-green-600">Redirecting to your account...</p>
          </div>
        )}

        {status === 'error' && (
          <div className="space-y-4">
            <div className="rounded-2xl border-2 border-red-400 bg-red-50 p-6">
              <p className="text-base font-semibold text-red-700">{message}</p>
            </div>
            <p className="text-sm text-gray-600">Redirecting to sign in...</p>
          </div>
        )}

        {/* Footer Links */}
        <div className="mt-10 flex justify-center gap-4 text-xs text-gray-500">
          <a href="#" className="cursor-pointer transition-colors hover:text-gray-700 hover:underline">
            Terms of Use
          </a>
          <span className="text-gray-300">|</span>
          <a href="#" className="cursor-pointer transition-colors hover:text-gray-700 hover:underline">
            Privacy Policy
          </a>
        </div>
      </div>
    </div>
  );
}

export default function OAuthCallbackPage() {
  return (
    <AuthErrorBoundary>
      <Suspense fallback={
        <div className="flex min-h-screen items-center justify-center bg-white">
          <div className="h-12 w-12 animate-spin rounded-full border-4 border-gray-200 border-t-blue-600"></div>
        </div>
      }>
        <OAuthCallbackContent />
      </Suspense>
    </AuthErrorBoundary>
  );
}


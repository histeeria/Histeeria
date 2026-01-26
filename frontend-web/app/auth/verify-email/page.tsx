'use client';

import { useState, Suspense, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Image from 'next/image';

// Use proxy route to avoid CORS issues in development
const API_BASE_URL = '/api/proxy';

interface VerifyEmailFormData {
  email: string;
  verification_code: string;
}

interface ApiResponse {
  success: boolean;
  message: string;
  token?: string;
  user?: any;
  error?: string;
}

// Storage keys for persisting state during verification
const VERIFY_EMAIL_STORAGE_KEY = 'verify_email_pending';
const VERIFY_CODE_STORAGE_KEY = 'verify_code_pending';

function VerifyEmailContent() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [isResending, setIsResending] = useState(false);
  const [isMounted, setIsMounted] = useState(false);
  const router = useRouter();
  const searchParams = useSearchParams();
  
  // Get email from URL params or localStorage (persistent)
  const emailFromUrl = searchParams.get('email') || '';
  const emailFromStorage = typeof window !== 'undefined' 
    ? localStorage.getItem(VERIFY_EMAIL_STORAGE_KEY) || '' 
    : '';
  const codeFromStorage = typeof window !== 'undefined'
    ? localStorage.getItem(VERIFY_CODE_STORAGE_KEY) || ''
    : '';

  // Initialize email - prefer URL param, fallback to storage
  const initialEmail = emailFromUrl || emailFromStorage;

  const [formData, setFormData] = useState<VerifyEmailFormData>({
    email: initialEmail,
    verification_code: codeFromStorage,
  });

  // Mark component as mounted
  useEffect(() => {
    setIsMounted(true);
  }, []);

  // Persist email and code to localStorage immediately
  useEffect(() => {
    if (typeof window === 'undefined') return;
    
    // Persist email
    if (emailFromUrl) {
      localStorage.setItem(VERIFY_EMAIL_STORAGE_KEY, emailFromUrl);
      setFormData(prev => ({ ...prev, email: emailFromUrl }));
    } else if (emailFromStorage && !formData.email) {
      // If no URL param but we have stored email, use it
      setFormData(prev => ({ ...prev, email: emailFromStorage }));
    }

    // Restore code from storage if available
    if (codeFromStorage && !formData.verification_code) {
      setFormData(prev => ({ ...prev, verification_code: codeFromStorage }));
    }
  }, [emailFromUrl, emailFromStorage, codeFromStorage]);

  // Persist verification code as user types
  useEffect(() => {
    if (typeof window === 'undefined' || !isMounted) return;
    if (formData.verification_code) {
      localStorage.setItem(VERIFY_CODE_STORAGE_KEY, formData.verification_code);
    }
  }, [formData.verification_code, isMounted]);

  // Clear stored data on successful verification
  useEffect(() => {
    if (success && typeof window !== 'undefined') {
      localStorage.removeItem(VERIFY_EMAIL_STORAGE_KEY);
      localStorage.removeItem(VERIFY_CODE_STORAGE_KEY);
    }
  }, [success]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    
    // Only allow 6 digits for verification code
    if (name === 'verification_code') {
      const digitsOnly = value.replace(/\D/g, '').slice(0, 6);
      const newFormData = {
        ...formData,
        [name]: digitsOnly,
      };
      setFormData(newFormData);
      // Persist immediately
      if (typeof window !== 'undefined') {
        localStorage.setItem(VERIFY_CODE_STORAGE_KEY, digitsOnly);
      }
    } else {
      const newFormData = {
        ...formData,
        [name]: value,
      };
      setFormData(newFormData);
      // Persist email immediately
      if (name === 'email' && typeof window !== 'undefined') {
        localStorage.setItem(VERIFY_EMAIL_STORAGE_KEY, value);
      }
    }
  };

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const response = await fetch(`${API_BASE_URL}/v1/auth/verify-email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(formData),
      });

      // Check if response is OK before parsing
      if (!response.ok) {
        try {
          const errorData = await response.json();
          setError(errorData.message || errorData.error || `Server error: ${response.status}`);
        } catch {
          setError(`Server error: ${response.status} ${response.statusText}`);
        }
        setLoading(false);
        return;
      }

      const data: ApiResponse = await response.json();

      if (data.success) {
        setSuccess(true);
        
        // Clear all stored verification data
        if (typeof window !== 'undefined') {
          localStorage.removeItem(VERIFY_EMAIL_STORAGE_KEY);
          localStorage.removeItem(VERIFY_CODE_STORAGE_KEY);
        }
        
        // Store token if provided
        if (data.token && typeof window !== 'undefined') {
          localStorage.setItem('token', data.token);
        }
        
        // Only redirect after user clicks "Continue" button - don't auto-redirect
        // User can manually proceed or stay on page
      } else {
        setError(data.message || 'Verification failed');
      }
    } catch (err) {
      const errorMessage = err instanceof Error 
        ? `Connection error: ${err.message}. Make sure backend is running.`
        : `Failed to connect to server. Please check if backend is running.`;
      setError(errorMessage);
      console.error('Verify email error:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleResendCode = async () => {
    if (!formData.email) {
      setError('Email address is required to resend verification code');
      return;
    }

    setIsResending(true);
    setError(null);

    try {
      // Call resend verification code endpoint (if available)
      // For now, we'll just show a message
      // TODO: Implement resend verification code API endpoint
      setError('Resend functionality coming soon. Please check your email for the code.');
    } catch (err) {
      setError('Failed to resend verification code. Please try again.');
      console.error('Resend code error:', err);
    } finally {
      setIsResending(false);
    }
  };

  const handleContinue = () => {
    // User explicitly wants to proceed after successful verification
    router.push('/');
  };

  // Don't render until mounted to prevent hydration issues
  if (!isMounted) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-white">
        <div className="h-12 w-12 animate-spin rounded-full border-4 border-gray-200 border-t-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-white">
      <div className="w-full max-w-md px-8 py-12">
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

        {/* Title */}
        <h1 className="mb-3 text-center text-[32px] font-bold text-black">
          Verify your email
        </h1>
        <p className="mb-10 text-center text-base text-gray-600">
          Enter the 6-digit code sent to your email address
        </p>

        {success ? (
          <div className="space-y-5">
            <div className="rounded-2xl border-2 border-green-400 bg-green-50 p-6 text-center">
              <div className="mb-4">
                <svg className="mx-auto h-12 w-12 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <p className="text-base font-semibold text-green-700 mb-2">
                Email verified successfully!
              </p>
              <p className="text-sm text-green-600">
                Your account has been verified. You can now proceed to your account.
              </p>
            </div>
            <button
              type="button"
              onClick={handleContinue}
              className="w-full cursor-pointer rounded-2xl bg-black px-4 py-4 text-base font-semibold text-white transition-all hover:bg-gray-800"
            >
              Continue to Account
            </button>
            <p className="text-center text-sm text-gray-600">
              Or{' '}
              <button
                type="button"
                onClick={() => router.push('/auth')}
                className="cursor-pointer font-semibold text-blue-600 hover:underline"
              >
                go back to sign in
              </button>
            </p>
          </div>
        ) : (
          <form onSubmit={handleVerify} className="space-y-5">
            {error && (
              <div className="mb-6 rounded-2xl border-2 border-red-400 bg-red-50 p-4 text-sm font-medium text-red-700">
                {error}
              </div>
            )}

            {/* Email Input with Floating Label */}
            <div className="relative">
              <input
                type="email"
                name="email"
                placeholder=" "
                required
                value={formData.email}
                onChange={handleChange}
                className="peer w-full rounded-2xl border-2 border-blue-500 px-5 py-4 text-base text-gray-900 transition-all focus:border-blue-600 focus:outline-none"
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Email address
              </label>
            </div>

            {/* Verification Code Input with Floating Label */}
            <div className="relative">
              <input
                type="text"
                name="verification_code"
                placeholder=" "
                required
                maxLength={6}
                minLength={6}
                value={formData.verification_code}
                onChange={handleChange}
                className="peer w-full rounded-2xl border-2 border-blue-500 px-5 py-4 text-center text-2xl tracking-[0.5em] text-gray-900 transition-all focus:border-blue-600 focus:outline-none"
                pattern="[0-9]{6}"
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Verification code
              </label>
              <p className="mt-2 text-center text-xs text-gray-500">
                Enter the 6-digit code from your email
              </p>
            </div>

            <button
              type="submit"
              disabled={loading || formData.verification_code.length !== 6 || !formData.email}
              className="mt-6 w-full cursor-pointer rounded-2xl bg-black px-4 py-4 text-base font-semibold text-white transition-all hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {loading ? 'Verifying...' : 'Verify Email'}
            </button>

            <div className="space-y-3 pt-2">
              <p className="text-center text-sm text-gray-700">
                Didn't receive the code?{' '}
                <button
                  type="button"
                  onClick={handleResendCode}
                  disabled={isResending || !formData.email}
                  className="cursor-pointer font-semibold text-blue-600 hover:underline disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {isResending ? 'Sending...' : 'Resend code'}
                </button>
              </p>
              <p className="text-center text-sm text-gray-700">
                <button
                  type="button"
                  onClick={() => {
                    if (typeof window !== 'undefined') {
                      localStorage.removeItem(VERIFY_EMAIL_STORAGE_KEY);
                      localStorage.removeItem(VERIFY_CODE_STORAGE_KEY);
                    }
                    router.push('/auth');
                  }}
                  className="cursor-pointer font-semibold text-blue-600 hover:underline"
                >
                  Back to sign in
                </button>
              </p>
            </div>
          </form>
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

export default function VerifyEmailPage() {
  return (
    <Suspense fallback={
      <div className="flex min-h-screen items-center justify-center bg-white">
        <div className="h-12 w-12 animate-spin rounded-full border-4 border-gray-200 border-t-blue-600"></div>
      </div>
    }>
      <VerifyEmailContent />
    </Suspense>
  );
}

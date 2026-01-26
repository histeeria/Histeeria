'use client';

import { useState, useEffect, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Image from 'next/image';

const API_BASE_URL = '/api/proxy';

function ResetPasswordContent() {
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [token, setToken] = useState<string | null>(null);
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    const tokenParam = searchParams.get('token');
    if (!tokenParam) {
      setError('Invalid or missing reset token. Please request a new password reset link.');
    } else {
      setToken(tokenParam);
    }
  }, [searchParams]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!token) {
      setError('Invalid reset token');
      return;
    }

    if (newPassword !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    if (newPassword.length < 8) {
      setError('Password must be at least 8 characters long');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(`${API_BASE_URL}/v1/auth/reset-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          token,
          new_password: newPassword 
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || 'Failed to reset password');
      }

      setSuccess(true);
      
      // Redirect to login after 3 seconds
      setTimeout(() => {
        router.push('/auth');
      }, 3000);
    } catch (err: any) {
      setError(err.message || 'An error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-white px-4">
      <div className="w-full max-w-md">
        {/* Logo and Brand */}
        <div className="mb-8 flex items-center justify-center gap-3">
          <Image
            src="/next.svg"
            alt="Upvista Logo"
            width={40}
            height={40}
            priority
          />
          <h2 className="text-2xl font-bold tracking-tight text-gray-900">
            <span className="bg-gradient-to-r from-purple-600 to-blue-600 bg-clip-text text-transparent">
              Histeeria
            </span>
          </h2>
        </div>

        {/* Title */}
        <h1 className="mb-4 text-center text-[32px] font-bold text-black">
          Create new password
        </h1>
        <p className="mb-10 text-center text-base text-gray-600">
          Enter your new password below. Make sure it's strong and secure.
        </p>

        {/* Success Message */}
        {success ? (
          <div className="space-y-6">
            <div className="rounded-2xl border-2 border-green-400 bg-green-50 p-6">
              <div className="mb-3 flex justify-center">
                <svg className="h-12 w-12 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <p className="text-center text-base font-semibold text-green-700">
                Password reset successful!
              </p>
              <p className="mt-2 text-center text-sm text-green-600">
                Redirecting you to login...
              </p>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Error Message */}
            {error && (
              <div className="rounded-lg border border-red-300 bg-red-50 p-4 text-sm text-red-700">
                {error}
              </div>
            )}

            {/* New Password Input with Floating Label and Toggle */}
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                placeholder=" "
                required
                minLength={8}
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                disabled={!token}
                className="peer w-full rounded-2xl border-2 border-blue-500 px-5 py-4 pr-12 text-base text-gray-900 transition-all focus:border-blue-600 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                New password
              </label>
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-4 top-1/2 -translate-y-1/2 cursor-pointer text-gray-500 transition-colors hover:text-gray-700"
              >
                {showPassword ? (
                  <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                  </svg>
                ) : (
                  <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                )}
              </button>
            </div>

            {/* Confirm Password Input with Floating Label */}
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                placeholder=" "
                required
                minLength={8}
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                disabled={!token}
                className="peer w-full rounded-2xl border-2 border-blue-500 px-5 py-4 text-base text-gray-900 transition-all focus:border-blue-600 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Confirm new password
              </label>
            </div>

            <button
              type="submit"
              disabled={loading || !token}
              className="w-full cursor-pointer rounded-2xl bg-black px-4 py-4 text-base font-semibold text-white transition-all hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {loading ? 'Resetting...' : 'Reset password'}
            </button>

            <div className="text-center">
              <a
                href="/auth"
                className="cursor-pointer text-sm font-medium text-blue-600 transition-colors hover:text-blue-700 hover:underline"
              >
                ← Back to login
              </a>
            </div>
          </form>
        )}

        {/* Footer */}
        <div className="mt-12 flex items-center justify-center gap-4 text-xs text-gray-500">
          <a href="#" className="cursor-pointer transition-colors hover:text-gray-700 hover:underline">
            Terms of Service
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

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={
      <div className="flex min-h-screen items-center justify-center bg-white">
        <div className="h-12 w-12 animate-spin rounded-full border-4 border-gray-200 border-t-blue-600"></div>
      </div>
    }>
      <ResetPasswordContent />
    </Suspense>
  );
}


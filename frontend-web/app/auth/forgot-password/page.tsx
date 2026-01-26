'use client';

import { useState } from 'react';
import Image from 'next/image';

const API_BASE_URL = '/api/proxy';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const response = await fetch(`${API_BASE_URL}/v1/auth/forgot-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || 'Failed to send reset email');
      }

      setSuccess(true);
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
            src="/assets/u.png"
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
          Reset your password
        </h1>
        <p className="mb-10 text-center text-base text-gray-600">
          Enter your email address and we'll send you a link to reset your password.
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
                Password reset email sent!
              </p>
              <p className="mt-2 text-center text-sm text-green-600">
                Check your inbox for a link to reset your password. If it doesn't appear within a few minutes, check your spam folder.
              </p>
            </div>

            <div className="text-center">
              <a
                href="/auth"
                className="cursor-pointer text-sm font-medium text-blue-600 transition-colors hover:text-blue-700 hover:underline"
              >
                ← Back to login
              </a>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Error Message */}
            {error && (
              <div className="rounded-lg border border-red-300 bg-red-50 p-4 text-sm text-red-700">
                {error}
              </div>
            )}

            {/* Email Input with Floating Label */}
            <div className="relative">
              <input
                type="email"
                placeholder=" "
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="peer w-full rounded-2xl border-2 border-blue-500 px-5 py-4 text-base text-gray-900 transition-all focus:border-blue-600 focus:outline-none"
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Email address
              </label>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full cursor-pointer rounded-2xl bg-black px-4 py-4 text-base font-semibold text-white transition-all hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {loading ? 'Sending...' : 'Send reset link'}
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


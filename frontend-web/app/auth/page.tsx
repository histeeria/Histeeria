'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Image from 'next/image';
import { AuthErrorBoundary } from '@/components/auth/AuthErrorBoundary';
import { AuthSkeleton } from '@/components/auth/AuthSkeleton';
import { SessionExpiryWarning } from '@/components/auth/SessionExpiryWarning';
import {
  validateSignInForm,
  validateSignUpForm,
  getFieldError,
  type ValidationError
} from '@/lib/auth/formValidation';
import { storeToken } from '@/lib/auth/tokenManager';

// Use proxy route to avoid CORS issues in development
const API_BASE_URL = '/api/proxy';

interface SignInFormData {
  email_or_username: string;
  password: string;
}

interface SignUpFormData {
  email: string;
  password: string;
  display_name: string;
  username: string;
  age: number;
}

interface ApiResponse {
  success: boolean;
  message: string;
  token?: string;
  refresh_token?: string;
  user?: any;
  error?: string;
}

function AuthPageContent() {
  const [isSignUp, setIsSignUp] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPassword, setShowPassword] = useState(false);
  const [validationErrors, setValidationErrors] = useState<ValidationError[]>([]);
  const [touchedFields, setTouchedFields] = useState<Set<string>>(new Set());
  const router = useRouter();

  const [signInForm, setSignInForm] = useState<SignInFormData>({
    email_or_username: '',
    password: '',
  });

  const [signUpForm, setSignUpForm] = useState<SignUpFormData>({
    email: '',
    password: '',
    display_name: '',
    username: '',
    age: 18,
  });

  const handleSignInChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const field = e.target.name;
    const value = e.target.value;

    setSignInForm({
      ...signInForm,
      [field]: value,
    });

    // Clear validation error for this field when user types
    if (validationErrors.length > 0) {
      setValidationErrors(prev => prev.filter(err => err.field !== field));
    }

    // Mark field as touched
    setTouchedFields(prev => new Set(prev).add(field));
  };

  const handleSignUpChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const field = e.target.name;
    let value: string | number;

    if (e.target.type === 'number') {
      const numValue = parseInt(e.target.value, 10);
      // Handle NaN - use empty string or keep current value
      value = isNaN(numValue) ? (e.target.value === '' ? 18 : signUpForm.age as number) : numValue;
    } else {
      value = e.target.value;
    }

    setSignUpForm({
      ...signUpForm,
      [field]: value,
    });

    // Clear validation error for this field when user types
    if (validationErrors.length > 0) {
      setValidationErrors(prev => prev.filter(err => err.field !== field));
    }

    // Mark field as touched
    setTouchedFields(prev => new Set(prev).add(field));
  };

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setValidationErrors([]);

    // Client-side validation
    const validation = validateSignInForm(signInForm);
    if (!validation.isValid) {
      setValidationErrors(validation.errors);
      setLoading(false);
      // Mark all fields as touched
      setTouchedFields(new Set(['email_or_username', 'password']));
      return;
    }

    try {
      const response = await fetch(`${API_BASE_URL}/v1/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(signInForm),
      });

      // Check if response is OK before parsing
      if (!response.ok) {
        // Try to parse error response
        try {
          const errorData = await response.json();
          setError(errorData.message || errorData.error || `Server error: ${response.status}`);
        } catch {
          setError(`Server error: ${response.status} ${response.statusText}. Backend may not be running on ${API_BASE_URL}`);
        }
        setLoading(false);
        return;
      }

      const data: ApiResponse = await response.json();

      if (data.success && data.token) {
        // Store token with expiry tracking
        storeToken(data.token, data.refresh_token);
        // Redirect to home page
        router.push('/');
      } else {
        setError(data.message || 'Login failed');
      }
    } catch (err) {
      const errorMessage = err instanceof Error
        ? `Connection error: ${err.message}. Make sure backend is running on ${API_BASE_URL}`
        : `Failed to connect to server. Please check if backend is running on ${API_BASE_URL}`;
      setError(errorMessage);
      console.error('Sign in error:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleOAuthLogin = async (provider: 'google' | 'github' | 'linkedin') => {
    try {
      setLoading(true);
      setError(null);

      const response = await fetch(`${API_BASE_URL}/v1/auth/${provider}/login`);
      const data = await response.json();

      if (data.success && data.auth_url) {
        // Store state in sessionStorage for validation after callback
        if (data.state) {
          sessionStorage.setItem('oauth_state', data.state);
          sessionStorage.setItem('oauth_provider', provider);
        }

        // Redirect to OAuth provider
        window.location.href = data.auth_url;
      } else {
        setError(`Failed to initialize ${provider} login`);
        setLoading(false);
      }
    } catch (err) {
      setError(`Failed to connect to ${provider} authentication service`);
      setLoading(false);
    }
  };

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setValidationErrors([]);

    // Client-side validation
    const validation = validateSignUpForm(signUpForm);
    if (!validation.isValid) {
      setValidationErrors(validation.errors);
      setLoading(false);
      // Mark all fields as touched
      setTouchedFields(new Set(['email', 'username', 'display_name', 'password', 'age']));
      return;
    }

    try {
      const response = await fetch(`${API_BASE_URL}/v1/auth/register`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(signUpForm),
      });

      // Check if response is OK before parsing
      if (!response.ok) {
        // Try to parse error response
        try {
          const errorData = await response.json();
          setError(errorData.message || errorData.error || `Server error: ${response.status}`);
        } catch {
          setError(`Server error: ${response.status} ${response.statusText}. Backend may not be running on ${API_BASE_URL}`);
        }
        setLoading(false);
        return;
      }

      const data: ApiResponse = await response.json();

      if (data.success) {
        // After successful registration, redirect to verify email page
        setError(null);
        router.push(`/auth/verify-email?email=${encodeURIComponent(signUpForm.email)}`);
      } else {
        setError(data.message || data.error || 'Registration failed');
      }
    } catch (err) {
      const errorMessage = err instanceof Error
        ? `Connection error: ${err.message}. Make sure backend is running on ${API_BASE_URL}`
        : `Failed to connect to server. Please check if backend is running on ${API_BASE_URL}`;
      setError(errorMessage);
      console.error('Sign up error:', err);
    } finally {
      setLoading(false);
    }
  };


  // Show loading skeleton during initial load
  if (loading && !error && validationErrors.length === 0) {
    return <AuthSkeleton />;
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-white">
      <SessionExpiryWarning />
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
        <h1 className="mb-10 text-center text-[32px] font-bold text-black">
          {isSignUp ? 'Create your account' : 'Welcome back'}
        </h1>

        {/* Error Message */}
        {error && (
          <div className="mb-6 rounded-lg border border-red-300 bg-red-50 p-4 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Main Form */}
        {isSignUp ? (
          <form onSubmit={handleSignUp} className="space-y-5">
            {/* Email Input with Floating Label */}
            <div className="relative">
              <input
                type="email"
                name="email"
                placeholder=" "
                required
                value={signUpForm.email}
                onChange={handleSignUpChange}
                className={`peer w-full rounded-2xl border-2 px-5 py-4 text-base text-gray-900 transition-all focus:outline-none ${getFieldError(validationErrors, 'email') && touchedFields.has('email')
                    ? 'border-red-500 focus:border-red-600'
                    : 'border-blue-500 focus:border-blue-600'
                  }`}
                aria-invalid={!!getFieldError(validationErrors, 'email')}
                aria-describedby={getFieldError(validationErrors, 'email') ? 'email-error' : undefined}
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Email address
              </label>
              {getFieldError(validationErrors, 'email') && touchedFields.has('email') && (
                <p id="email-error" className="mt-1 text-sm text-red-600" role="alert">
                  {getFieldError(validationErrors, 'email')}
                </p>
              )}
            </div>

            {/* Username Input with Floating Label */}
            <div className="relative">
              <input
                type="text"
                name="username"
                placeholder=" "
                required
                minLength={3}
                maxLength={20}
                pattern="[a-zA-Z0-9_]+"
                value={signUpForm.username}
                onChange={handleSignUpChange}
                className={`peer w-full rounded-2xl border-2 px-5 py-4 text-base text-gray-900 transition-all focus:outline-none ${getFieldError(validationErrors, 'username') && touchedFields.has('username')
                    ? 'border-red-500 focus:border-red-600'
                    : 'border-blue-500 focus:border-blue-600'
                  }`}
                aria-invalid={!!getFieldError(validationErrors, 'username')}
                aria-describedby={getFieldError(validationErrors, 'username') ? 'username-error' : undefined}
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Username
              </label>
              {getFieldError(validationErrors, 'username') && touchedFields.has('username') && (
                <p id="username-error" className="mt-1 text-sm text-red-600" role="alert">
                  {getFieldError(validationErrors, 'username')}
                </p>
              )}
            </div>

            {/* Display Name Input with Floating Label */}
            <div className="relative">
              <input
                type="text"
                name="display_name"
                placeholder=" "
                required
                minLength={2}
                maxLength={50}
                value={signUpForm.display_name}
                onChange={handleSignUpChange}
                className={`peer w-full rounded-2xl border-2 px-5 py-4 text-base text-gray-900 transition-all focus:outline-none ${getFieldError(validationErrors, 'display_name') && touchedFields.has('display_name')
                    ? 'border-red-500 focus:border-red-600'
                    : 'border-blue-500 focus:border-blue-600'
                  }`}
                aria-invalid={!!getFieldError(validationErrors, 'display_name')}
                aria-describedby={getFieldError(validationErrors, 'display_name') ? 'display_name-error' : undefined}
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Display name
              </label>
              {getFieldError(validationErrors, 'display_name') && touchedFields.has('display_name') && (
                <p id="display_name-error" className="mt-1 text-sm text-red-600" role="alert">
                  {getFieldError(validationErrors, 'display_name')}
                </p>
              )}
            </div>

            {/* Age Input with Floating Label */}
            <div className="relative">
              <input
                type="number"
                name="age"
                placeholder=" "
                required
                min={13}
                max={120}
                value={isNaN(signUpForm.age) ? 18 : signUpForm.age}
                onChange={handleSignUpChange}
                className={`peer w-full rounded-2xl border-2 px-5 py-4 text-base text-gray-900 transition-all focus:outline-none ${getFieldError(validationErrors, 'age') && touchedFields.has('age')
                    ? 'border-red-500 focus:border-red-600'
                    : 'border-blue-500 focus:border-blue-600'
                  }`}
                aria-invalid={!!getFieldError(validationErrors, 'age')}
                aria-describedby={getFieldError(validationErrors, 'age') ? 'age-error' : undefined}
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Age
              </label>
              {getFieldError(validationErrors, 'age') && touchedFields.has('age') && (
                <p id="age-error" className="mt-1 text-sm text-red-600" role="alert">
                  {getFieldError(validationErrors, 'age')}
                </p>
              )}
            </div>

            {/* Password Input with Floating Label and Toggle */}
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                name="password"
                placeholder=" "
                required
                minLength={8}
                value={signUpForm.password}
                onChange={handleSignUpChange}
                className={`peer w-full rounded-2xl border-2 px-5 py-4 pr-12 text-base text-gray-900 transition-all focus:outline-none ${getFieldError(validationErrors, 'password') && touchedFields.has('password')
                    ? 'border-red-500 focus:border-red-600'
                    : 'border-blue-500 focus:border-blue-600'
                  }`}
                aria-invalid={!!getFieldError(validationErrors, 'password')}
                aria-describedby={getFieldError(validationErrors, 'password') ? 'password-error' : undefined}
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Password
              </label>
              {getFieldError(validationErrors, 'password') && touchedFields.has('password') && (
                <p id="password-error" className="mt-1 text-sm text-red-600" role="alert">
                  {getFieldError(validationErrors, 'password')}
                </p>
              )}
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

            <button
              type="submit"
              disabled={loading}
              className="mt-6 w-full cursor-pointer rounded-2xl bg-black px-4 py-4 text-base font-semibold text-white transition-all hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {loading ? 'Creating account...' : 'Continue'}
            </button>

            <p className="pt-2 text-center text-sm text-gray-700">
              Already have an account?{' '}
              <button
                type="button"
                onClick={() => {
                  setIsSignUp(false);
                  setError(null);
                  setShowPassword(false);
                }}
                className="cursor-pointer font-semibold text-blue-600 hover:underline"
              >
                Log in
              </button>
            </p>
          </form>
        ) : (
          <form onSubmit={handleSignIn} className="space-y-5">
            {/* Email or Username Input with Floating Label */}
            <div className="relative">
              <input
                type="text"
                name="email_or_username"
                placeholder=" "
                required
                value={signInForm.email_or_username}
                onChange={handleSignInChange}
                className={`peer w-full rounded-2xl border-2 px-5 py-4 text-base text-gray-900 transition-all focus:outline-none ${getFieldError(validationErrors, 'email_or_username') && touchedFields.has('email_or_username')
                    ? 'border-red-500 focus:border-red-600'
                    : 'border-blue-500 focus:border-blue-600'
                  }`}
                aria-invalid={!!getFieldError(validationErrors, 'email_or_username')}
                aria-describedby={getFieldError(validationErrors, 'email_or_username') ? 'email_or_username-error' : undefined}
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Email or Username
              </label>
              {getFieldError(validationErrors, 'email_or_username') && touchedFields.has('email_or_username') && (
                <p id="email_or_username-error" className="mt-1 text-sm text-red-600" role="alert">
                  {getFieldError(validationErrors, 'email_or_username')}
                </p>
              )}
            </div>

            {/* Password Input with Floating Label and Toggle */}
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                name="password"
                placeholder=" "
                required
                value={signInForm.password}
                onChange={handleSignInChange}
                className={`peer w-full rounded-2xl border-2 px-5 py-4 pr-12 text-base text-gray-900 transition-all focus:outline-none ${getFieldError(validationErrors, 'password') && touchedFields.has('password')
                    ? 'border-red-500 focus:border-red-600'
                    : 'border-blue-500 focus:border-blue-600'
                  }`}
                aria-invalid={!!getFieldError(validationErrors, 'password')}
                aria-describedby={getFieldError(validationErrors, 'password') ? 'password-error' : undefined}
              />
              <label className="pointer-events-none absolute -top-3 left-4 bg-white px-2 text-sm font-medium text-blue-600 peer-placeholder-shown:top-4 peer-placeholder-shown:text-base peer-placeholder-shown:text-gray-400 peer-focus:-top-3 peer-focus:text-sm peer-focus:text-blue-600 transition-all">
                Password
              </label>
              {getFieldError(validationErrors, 'password') && touchedFields.has('password') && (
                <p id="password-error" className="mt-1 text-sm text-red-600" role="alert">
                  {getFieldError(validationErrors, 'password')}
                </p>
              )}
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

            {/* Forgot Password Link */}
            <div className="text-right">
              <a
                href="/auth/forgot-password"
                className="cursor-pointer text-sm font-medium text-blue-600 transition-colors hover:text-blue-700 hover:underline"
              >
                Forgot password?
              </a>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full cursor-pointer rounded-2xl bg-black px-4 py-4 text-base font-semibold text-white transition-all hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {loading ? 'Signing in...' : 'Continue'}
            </button>

            <p className="pt-2 text-center text-sm text-gray-700">
              Don't have an account?{' '}
              <button
                type="button"
                onClick={() => {
                  setIsSignUp(true);
                  setError(null);
                  setShowPassword(false);
                }}
                className="cursor-pointer font-semibold text-blue-600 hover:underline"
              >
                Sign up
              </button>
            </p>
          </form>
        )}

        {/* OR Separator */}
        <div className="relative my-8">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-gray-300"></div>
          </div>
          <div className="relative flex justify-center text-sm">
            <span className="bg-white px-4 font-medium text-gray-600">OR</span>
          </div>
        </div>

        {/* Social Login Buttons */}
        <div className="space-y-3">
          <button
            type="button"
            onClick={() => handleOAuthLogin('google')}
            disabled={loading}
            className="flex w-full cursor-pointer items-center justify-center gap-3 rounded-2xl border-2 border-gray-300 bg-white px-4 py-3.5 text-base font-medium text-gray-900 transition-all hover:border-gray-400 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <div className="flex h-5 w-5 items-center justify-center">
              <Image
                src="/assets/auth/google.png"
                alt="Google"
                width={24}
                height={24}
                className="object-contain"
              />
            </div>
            Continue with Google
          </button>

          <button
            type="button"
            onClick={() => handleOAuthLogin('github')}
            disabled={loading}
            className="flex w-full cursor-pointer items-center justify-center gap-3 rounded-2xl border-2 border-gray-300 bg-white px-4 py-3.5 text-base font-medium text-gray-900 transition-all hover:border-gray-400 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <div className="flex h-5 w-5 items-center justify-center">
              <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                <path fillRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clipRule="evenodd" />
              </svg>
            </div>
            Continue with GitHub
          </button>

          <button
            type="button"
            onClick={() => handleOAuthLogin('linkedin')}
            disabled={loading}
            className="flex w-full cursor-pointer items-center justify-center gap-3 rounded-2xl border-2 border-gray-300 bg-white px-4 py-3.5 text-base font-medium text-gray-900 transition-all hover:border-gray-400 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <div className="flex h-5 w-5 items-center justify-center">
              <svg className="h-5 w-5" fill="#0A66C2" viewBox="0 0 24 24">
                <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
              </svg>
            </div>
            Continue with LinkedIn
          </button>
        </div>

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

export default function AuthPage() {
  return (
    <AuthErrorBoundary>
      <AuthPageContent />
    </AuthErrorBoundary>
  );
}

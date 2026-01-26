'use client';

/**
 * Auth Error Boundary
 * Catches and handles authentication-related errors
 */

import { Component, ReactNode } from 'react';
import { AlertCircle, RefreshCw } from 'lucide-react';
import { Button } from '@/components/ui/Button';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class AuthErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('[AuthErrorBoundary] Caught error:', error, errorInfo);
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <div className="flex min-h-screen items-center justify-center bg-white p-4">
          <div className="w-full max-w-md text-center">
            <div className="mb-6 flex justify-center">
              <div className="rounded-full bg-red-100 p-4">
                <AlertCircle className="h-8 w-8 text-red-600" />
              </div>
            </div>
            <h2 className="mb-2 text-2xl font-bold text-gray-900">
              Authentication Error
            </h2>
            <p className="mb-6 text-gray-600">
              {this.state.error?.message || 'An error occurred during authentication. Please try again.'}
            </p>
            <div className="space-y-3">
              <Button
                onClick={this.handleReset}
                variant="solid"
                className="w-full"
                aria-label="Retry authentication"
              >
                <RefreshCw className="mr-2 h-4 w-4" />
                Try Again
              </Button>
              <Button
                onClick={() => window.location.href = '/auth'}
                variant="outline"
                className="w-full"
                aria-label="Go to login page"
              >
                Go to Login
              </Button>
            </div>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

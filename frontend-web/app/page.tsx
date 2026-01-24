'use client';

/**
 * Landing/Root Page
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Redirects to /home if authenticated, otherwise to /auth
 */

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function RootPage() {
  const router = useRouter();

  useEffect(() => {
    // Check if user is authenticated
    const token = localStorage.getItem('token');
    
    if (token) {
      // User is logged in, redirect to home
      router.push('/home');
    } else {
      // User is not logged in, redirect to auth
      router.push('/auth');
    }
  }, [router]);

  // Show loading state while redirecting
  return (
    <div className="min-h-screen flex items-center justify-center bg-neutral-50 dark:bg-neutral-950">
      <div className="text-center">
        <img src="/assets/u.png" alt="Upvista" className="w-20 h-20 mx-auto mb-4 animate-pulse" />
        <p className="text-neutral-600 dark:text-neutral-400">Loading...</p>
      </div>
    </div>
  );
}

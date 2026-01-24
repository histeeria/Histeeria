'use client';

/**
 * Public Profile View Page
 * View another user's profile by username
 */

import { useParams, useRouter } from 'next/navigation';
import { useEffect } from 'react';

export default function PublicProfilePage() {
  const params = useParams();
  const router = useRouter();
  const username = params.username as string;

  useEffect(() => {
    // Redirect to main profile page with query param
    router.replace(`/profile?u=${username}`);
  }, [username, router]);

  return null; // Redirecting...
}


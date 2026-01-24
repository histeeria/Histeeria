'use client';

import { useEffect, useState, ReactNode } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Post, postsAPI } from '@/lib/api/posts';
import PostDetailView from '@/components/posts/PostDetailView';
import { Loader2 } from 'lucide-react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Topbar } from '@/components/layout/Topbar';
import { BottomNav } from '@/components/layout/BottomNav';
import { NotificationProvider } from '@/lib/contexts/NotificationContext';
import { MessagesProvider } from '@/lib/contexts/MessagesContext';
import MobileMessagesOverlay from '@/components/messages/MobileMessagesOverlay';
import { ToastContainer } from '@/components/ui/Toast';

export default function PostDetailPage() {
  const params = useParams();
  const router = useRouter();
  const postId = params?.id as string;

  const [post, setPost] = useState<Post | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!postId) return;

    const fetchPost = async () => {
      try {
        setLoading(true);
        setError(null);

        const response = await postsAPI.getPost(postId);
        if (response.success && response.post) {
          setPost(response.post);
        } else {
          setError('Post not found');
        }
      } catch (err: any) {
        console.error('Error fetching post:', err);
        if (err.message?.includes('404') || err.message?.includes('not found')) {
          setError('Post not found');
        } else {
          setError('Failed to load post. Please try again.');
        }
      } finally {
        setLoading(false);
      }
    };

    fetchPost();
  }, [postId]);

  const LayoutWrapper = ({ children }: { children: ReactNode }) => (
    <NotificationProvider>
      <MessagesProvider>
        <div className="min-h-screen bg-neutral-50 dark:bg-neutral-950">
          <Sidebar />
          <Topbar />
          <div className="md:ml-64 pb-16 md:pb-0">
            {children}
          </div>
          <BottomNav />
        </div>
        <MobileMessagesOverlay />
        <ToastContainer />
      </MessagesProvider>
    </NotificationProvider>
  );

  if (loading) {
    return (
      <LayoutWrapper>
        <div className="min-h-screen flex items-center justify-center">
          <div className="text-center">
            <Loader2 className="w-8 h-8 animate-spin text-purple-600 mx-auto mb-4" />
            <p className="text-neutral-600 dark:text-neutral-400">Loading post...</p>
          </div>
        </div>
      </LayoutWrapper>
    );
  }

  if (error || !post) {
    return (
      <LayoutWrapper>
        <div className="min-h-screen flex items-center justify-center">
          <div className="text-center max-w-md">
            <h1 className="text-2xl font-bold text-neutral-900 dark:text-neutral-50 mb-2">
              Post Not Found
            </h1>
            <p className="text-neutral-600 dark:text-neutral-400 mb-6">
              {error || 'The post you\'re looking for doesn\'t exist or has been removed.'}
            </p>
            <button
              onClick={() => router.push('/home')}
              className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
            >
              Go to Home
            </button>
          </div>
        </div>
      </LayoutWrapper>
    );
  }

  return (
    <LayoutWrapper>
      <div className="min-h-screen bg-white dark:bg-gray-900 py-6">
        <PostDetailView post={post} />
      </div>
    </LayoutWrapper>
  );
}


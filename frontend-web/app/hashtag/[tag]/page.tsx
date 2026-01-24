'use client';

import { useEffect, useState, ReactNode } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Post, postsAPI } from '@/lib/api/posts';
import { Loader2, Hash, TrendingUp } from 'lucide-react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Topbar } from '@/components/layout/Topbar';
import { BottomNav } from '@/components/layout/BottomNav';
import { NotificationProvider } from '@/lib/contexts/NotificationContext';
import { MessagesProvider } from '@/lib/contexts/MessagesContext';
import MobileMessagesOverlay from '@/components/messages/MobileMessagesOverlay';
import { ToastContainer } from '@/components/ui/Toast';
import PostCard from '@/components/posts/PostCard';
import FeedContainer from '@/components/posts/FeedContainer';
import { motion } from 'framer-motion';

export default function HashtagPage() {
  const params = useParams();
  const router = useRouter();
  const tag = params?.tag as string;
  const cleanTag = tag?.startsWith('#') ? tag.substring(1) : tag;

  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isFollowing, setIsFollowing] = useState(false);
  const [postCount, setPostCount] = useState(0);

  useEffect(() => {
    if (!cleanTag) return;

    const fetchHashtagPosts = async () => {
      try {
        setLoading(true);
        setError(null);

        // For now, we'll fetch all posts and filter by hashtag
        // In production, you'd have a dedicated hashtag endpoint
        // TODO: Implement dedicated hashtag API endpoint
        // const response = await postsAPI.getHashtagPosts(cleanTag, 0, 50);
        // For now, using placeholder
        setPosts([]);
        setPostCount(0);
      } catch (err: any) {
        console.error('Error fetching hashtag posts:', err);
        setError('Failed to load posts');
      } finally {
        setLoading(false);
      }
    };

    fetchHashtagPosts();
  }, [cleanTag]);

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

  const handleFollow = () => {
    setIsFollowing(!isFollowing);
    // TODO: Implement follow hashtag API call
  };

  if (loading) {
    return (
      <LayoutWrapper>
        <div className="min-h-screen flex items-center justify-center">
          <div className="text-center">
            <Loader2 className="w-8 h-8 animate-spin text-purple-600 mx-auto mb-4" />
            <p className="text-neutral-600 dark:text-neutral-400">Loading hashtag...</p>
          </div>
        </div>
      </LayoutWrapper>
    );
  }

  return (
    <LayoutWrapper>
      <div className="min-h-screen bg-white dark:bg-gray-900">
        <div className="max-w-4xl mx-auto px-4 py-6">
          {/* Hashtag Header */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="mb-6
              rounded-2xl
              bg-white/70 dark:bg-neutral-900/70
              backdrop-blur-xl
              border border-white/30 dark:border-neutral-700/30
              shadow-lg
              p-6
            "
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-full bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center">
                  <Hash className="w-6 h-6 text-purple-600 dark:text-purple-400" />
                </div>
                <div>
                  <h1 className="text-2xl font-bold text-neutral-900 dark:text-neutral-50">
                    #{cleanTag}
                  </h1>
                  <p className="text-sm text-neutral-500 dark:text-neutral-400">
                    {postCount} {postCount === 1 ? 'post' : 'posts'}
                  </p>
                </div>
              </div>
              <motion.button
                whileTap={{ scale: 0.95 }}
                onClick={handleFollow}
                className={`
                  px-6 py-2.5 rounded-full font-semibold text-sm
                  transition-all duration-200
                  ${isFollowing
                    ? 'bg-purple-600 text-white hover:bg-purple-700'
                    : 'bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 hover:bg-purple-200 dark:hover:bg-purple-900/50'
                  }
                `}
              >
                {isFollowing ? 'Following' : 'Follow'}
              </motion.button>
            </div>
          </motion.div>

          {/* Posts Feed */}
          {error ? (
            <div className="text-center py-12">
              <p className="text-neutral-600 dark:text-neutral-400">{error}</p>
            </div>
          ) : posts.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-neutral-600 dark:text-neutral-400">No posts found for this hashtag</p>
            </div>
          ) : (
            <div className="space-y-4">
              {posts.map((post) => (
                <PostCard key={post.id} post={post} />
              ))}
            </div>
          )}
        </div>
      </div>
    </LayoutWrapper>
  );
}


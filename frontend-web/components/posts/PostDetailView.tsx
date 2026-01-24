'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { Post } from '@/lib/api/posts';
import PostCard from './PostCard';
import CommentSection from './CommentSection';
import { ShareDialog } from './ShareDialog';
import { ArrowLeft } from 'lucide-react';

interface PostDetailViewProps {
  post: Post;
}

export default function PostDetailView({ post }: PostDetailViewProps) {
  const router = useRouter();
  const [showShareDialog, setShowShareDialog] = useState(false);

  return (
    <div className="max-w-4xl mx-auto px-4">
      {/* Back Button */}
      <motion.button
        whileTap={{ scale: 0.95 }}
        onClick={() => router.back()}
        className="mb-4 flex items-center gap-2 text-neutral-600 dark:text-neutral-400 hover:text-purple-600 dark:hover:text-purple-400 transition-colors"
      >
        <ArrowLeft className="w-5 h-5" />
        <span className="text-sm font-medium">Back</span>
      </motion.button>

      {/* Post Card */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="mb-6"
      >
        <PostCard
          post={post}
          onComment={() => {
            // Scroll to comments
            document.getElementById('comments-section')?.scrollIntoView({ behavior: 'smooth' });
          }}
          onShare={() => setShowShareDialog(true)}
          onSave={() => {
            // Handle save
          }}
        />
      </motion.div>

      {/* Comments Section */}
      <motion.div
        id="comments-section"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, delay: 0.1 }}
        className="
          rounded-2xl
          bg-white/70 dark:bg-neutral-900/70
          backdrop-blur-xl
          border border-white/30 dark:border-neutral-700/30
          shadow-lg
          p-6
        "
      >
        <h2 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-4">
          Comments ({post.comments_count || 0})
        </h2>
        <CommentSection post={post} showInput={true} />
      </motion.div>

      {/* Share Dialog */}
      {showShareDialog && (
        <ShareDialog
          post={post}
          isOpen={showShareDialog}
          onClose={() => setShowShareDialog(false)}
        />
      )}
    </div>
  );
}


'use client';

import { MessageCircle, Share2, Bookmark } from 'lucide-react';
import { formatCount } from '@/lib/api/posts';
import LikeButton from './LikeButton';

interface PostActionsProps {
  postId: string;
  isLiked: boolean;
  isSaved: boolean;
  likesCount: number;
  commentsCount: number;
  sharesCount: number;
  onComment?: () => void;
  onShare?: () => void;
  onSave?: () => void;
}

export default function PostActions({
  postId,
  isLiked,
  isSaved,
  likesCount,
  commentsCount,
  sharesCount,
  onComment,
  onShare,
  onSave,
}: PostActionsProps) {
  return (
    <div className="flex items-center gap-5 md:gap-6 text-neutral-600 dark:text-neutral-400 pt-4 border-t border-neutral-200/50 dark:border-neutral-700/50">
      {/* Like */}
      <LikeButton 
        postId={postId}
        initialLiked={isLiked}
        initialCount={likesCount}
      />

      {/* Comment */}
      <button 
        onClick={onComment}
        className="flex items-center gap-2 hover:text-purple-600 dark:hover:text-purple-400 transition-colors active:scale-95"
      >
        <MessageCircle className="w-5 h-5" />
        <span className="text-sm font-medium">{formatCount(commentsCount)}</span>
      </button>

      {/* Share */}
      <button 
        onClick={onShare}
        className="flex items-center gap-2 hover:text-purple-600 dark:hover:text-purple-400 transition-colors active:scale-95"
      >
        <Share2 className="w-5 h-5" />
        <span className="text-sm font-medium">{formatCount(sharesCount)}</span>
      </button>

      {/* Save */}
      <button 
        onClick={onSave}
        className={`ml-auto flex items-center gap-2 transition-colors active:scale-95 ${
          isSaved ? 'text-purple-600' : 'hover:text-purple-600 dark:hover:text-purple-400'
        }`}
      >
        <Bookmark className={`w-5 h-5 ${isSaved ? 'fill-current' : ''}`} />
      </button>
    </div>
  );
}


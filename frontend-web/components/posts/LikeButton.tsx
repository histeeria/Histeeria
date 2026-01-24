'use client';

import { useState } from 'react';
import { Heart } from 'lucide-react';
import { motion } from 'framer-motion';
import { postsAPI, formatCount } from '@/lib/api/posts';
import { toast } from '../ui/Toast';

interface LikeButtonProps {
  postId: string;
  initialLiked: boolean;
  initialCount: number;
  onLikeChange?: (liked: boolean, newCount: number) => void;
}

export default function LikeButton({ 
  postId, 
  initialLiked, 
  initialCount,
  onLikeChange 
}: LikeButtonProps) {
  const [isLiked, setIsLiked] = useState(initialLiked);
  const [count, setCount] = useState(initialCount);
  const [isAnimating, setIsAnimating] = useState(false);

  const handleLike = async (e: React.MouseEvent) => {
    e.stopPropagation();
    
    // Optimistic UI
    const newLiked = !isLiked;
    const newCount = newLiked ? count + 1 : count - 1;
    
    setIsLiked(newLiked);
    setCount(newCount);
    
    if (newLiked) {
      setIsAnimating(true);
      setTimeout(() => setIsAnimating(false), 600);
    }

    try {
      if (newLiked) {
        await postsAPI.likePost(postId);
      } else {
        await postsAPI.unlikePost(postId);
      }
      
      onLikeChange?.(newLiked, newCount);
    } catch (error) {
      // Revert on error
      setIsLiked(!newLiked);
      setCount(count);
      toast.error('Failed to update like');
    }
  };

  return (
    <button
      onClick={handleLike}
      className={`flex items-center gap-2 transition-colors active:scale-95 ${
        isLiked ? 'text-red-500' : 'text-neutral-600 dark:text-neutral-400 hover:text-red-500'
      }`}
    >
      <motion.div
        animate={isAnimating ? { scale: [1, 1.3, 1] } : {}}
        transition={{ duration: 0.3 }}
      >
        <Heart 
          className={`w-5 h-5 md:w-5 md:h-5 transition-all ${isLiked ? 'fill-current' : ''}`} 
        />
      </motion.div>
      <span className="text-sm font-medium">
        {formatCount(count)}
      </span>
    </button>
  );
}


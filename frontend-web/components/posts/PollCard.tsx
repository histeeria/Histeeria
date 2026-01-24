'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { MoreVertical, BarChart3, Clock } from 'lucide-react';
import { motion } from 'framer-motion';
import { Post, Poll, PollResults, formatPostTimestamp, formatCount, postsAPI } from '@/lib/api/posts';
import { Avatar } from '../ui/Avatar';
import { Badge } from '../ui/Badge';
import { Card } from '../ui/Card';
import VerifiedBadge from '../ui/VerifiedBadge';
import PostActions from './PostActions';
import CommentModal from './CommentModal';
import { toast } from '../ui/Toast';

interface PollCardProps {
  post: Post;
  poll: Poll;
  onComment?: () => void;
  onShare?: () => void;
  onSave?: () => void;
}

export default function PollCard({ post, poll, onComment, onShare, onSave }: PollCardProps) {
  const router = useRouter();
  // Ensure options is always an array to prevent undefined errors
  const pollOptions = poll?.options || [];
  
  const [selectedOption, setSelectedOption] = useState<string | null>(poll?.user_vote || null);
  const [hasVoted, setHasVoted] = useState(!!poll?.user_vote);
  const [results, setResults] = useState<PollResults | null>(null);
  const [isVoting, setIsVoting] = useState(false);
  const [timeLeft, setTimeLeft] = useState('');
  const [showCommentModal, setShowCommentModal] = useState(false);

  const handleProfileClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (post.author?.username) {
      router.push(`/profile?u=${post.author.username}`);
    }
  };

  // Calculate time remaining
  useEffect(() => {
    const updateTimeLeft = () => {
      const now = new Date();
      const end = new Date(poll.ends_at);
      const diff = end.getTime() - now.getTime();

      if (diff <= 0) {
        setTimeLeft('Ended');
        return;
      }

      const days = Math.floor(diff / (1000 * 60 * 60 * 24));
      const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));

      if (days > 0) {
        setTimeLeft(`${days}d ${hours}h left`);
      } else if (hours > 0) {
        setTimeLeft(`${hours}h left`);
      } else {
        const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
        setTimeLeft(`${minutes}m left`);
      }
    };

    updateTimeLeft();
    const interval = setInterval(updateTimeLeft, 60000); // Update every minute

    return () => clearInterval(interval);
  }, [poll.ends_at]);

  // Load results if voted or poll allows viewing before vote
  useEffect(() => {
    if (hasVoted || poll.show_results_before_vote) {
      loadResults();
    }
  }, [hasVoted]);

  const loadResults = async () => {
    try {
      const response = await postsAPI.getPollResults(post.id);
      if (response.success && response.results) {
        setResults(response.results);
      }
    } catch (error) {
      console.error('Failed to load poll results:', error);
    }
  };

  const handleVote = async () => {
    if (!selectedOption) {
      toast.error('Please select an option');
      return;
    }

    setIsVoting(true);

    try {
      const response = await postsAPI.votePoll(post.id, selectedOption);
      if (response.success) {
        setHasVoted(true);
        setResults(response.results);
        toast.success('Vote recorded!');
      }
    } catch (error) {
      console.error('Failed to vote:', error);
      toast.error('Failed to record vote');
    } finally {
      setIsVoting(false);
    }
  };

  const showResults = hasVoted || poll.show_results_before_vote;

  return (
    <motion.div
      whileHover={{ y: -2 }}
      transition={{ duration: 0.2 }}
    >
      <Card variant="glass" hoverable={false} className="p-6">
        {/* Header */}
        <div className="flex items-start justify-between mb-4 pt-2">
          <div className="flex items-center gap-3 flex-1 min-w-0">
            <button
              onClick={handleProfileClick}
              className="flex-shrink-0 cursor-pointer hover:opacity-80 transition-opacity"
            >
              <Avatar 
                src={post.author?.profile_picture} 
                alt={post.author?.display_name || post.author?.username || 'User'} 
                fallback={post.author?.display_name || post.author?.username || 'U'}
                size="lg"
              />
            </button>
            <div className="flex-1 min-w-0">
              <button
                onClick={handleProfileClick}
                className="flex items-center gap-1.5 hover:opacity-80 transition-opacity w-full"
              >
                <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50 truncate">
                  {post.author?.display_name || post.author?.username}
                </h3>
                {post.author?.is_verified && (
                  <>
                    <span className="text-sm text-neutral-400 dark:text-neutral-600">·</span>
                    <VerifiedBadge size="sm" variant="badge" showText={false} />
                  </>
                )}
                <span className="text-sm text-neutral-400 dark:text-neutral-600">·</span>
                <span className="text-sm text-neutral-500 dark:text-neutral-400 whitespace-nowrap">
                  {formatPostTimestamp(post.created_at)}
                </span>
              </button>
              <button
                onClick={handleProfileClick}
                className="text-sm text-neutral-500 dark:text-neutral-400 hover:text-neutral-700 dark:hover:text-neutral-300 transition-colors"
              >
                @{post.author?.username}
              </button>
            </div>
          </div>
          <button 
            onClick={(e) => {
              e.stopPropagation();
            }}
            className="text-neutral-400 hover:text-neutral-600 dark:hover:text-neutral-300 p-1 rounded-full hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors"
          >
            <MoreVertical className="w-5 h-5" />
          </button>
        </div>

        {/* Poll Badge */}
        <div className="mb-3">
          <Badge variant="purple" size="sm" className="flex items-center gap-1.5 w-fit">
            <BarChart3 className="w-3 h-3" />
            POLL
          </Badge>
        </div>

        {/* Question */}
        <h2 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-4">
          {poll?.question || 'Poll Question'}
        </h2>

        {/* Options */}
        <div className="space-y-2.5 mb-4">
          {pollOptions.length === 0 ? (
            <p className="text-sm text-neutral-500 dark:text-neutral-400">No options available</p>
          ) : (
            pollOptions.map((option) => {
            const result = results?.options.find(r => r.id === option.id);
            const percentage = result?.percentage || 0;
            const isUserVote = result?.is_user_vote || false;
            const isSelected = selectedOption === option.id;

            return (
              <button
                key={option.id}
                onClick={() => !hasVoted && setSelectedOption(option.id)}
                disabled={hasVoted || poll.is_closed}
                className={`w-full text-left transition-all ${
                  hasVoted || poll.is_closed ? 'cursor-default' : 'cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800/50'
                }`}
              >
                <div className="relative overflow-hidden rounded-lg border-2 transition-colors" style={{
                  borderColor: isUserVote ? 'rgb(147, 51, 234)' : isSelected ? 'rgb(168, 85, 247)' : 'rgb(229, 231, 235)',
                }}>
                  {/* Progress Bar Background (if showing results) */}
                  {showResults && (
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${percentage}%` }}
                      transition={{ duration: 0.6, ease: 'easeOut' }}
                      className={`absolute inset-y-0 left-0 ${
                        isUserVote 
                          ? 'bg-purple-200 dark:bg-purple-900/40' 
                          : 'bg-neutral-100 dark:bg-neutral-800/40'
                      }`}
                    />
                  )}

                  {/* Option Content */}
                  <div className="relative px-4 py-3 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      {/* Radio/Check */}
                      <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center ${
                        isUserVote || isSelected 
                          ? 'border-purple-600 bg-purple-600' 
                          : 'border-neutral-400'
                      }`}>
                        {(isUserVote || isSelected) && (
                          <div className="w-2.5 h-2.5 bg-white rounded-full" />
                        )}
                      </div>
                      
                      {/* Option Text */}
                      <span className={`text-sm font-medium ${
                        isUserVote ? 'text-purple-700 dark:text-purple-300' : 'text-neutral-900 dark:text-neutral-50'
                      }`}>
                        {option.option_text}
                      </span>
                    </div>

                    {/* Percentage (if showing results) */}
                    {showResults && (
                      <span className={`text-sm font-bold ${
                        isUserVote ? 'text-purple-700 dark:text-purple-300' : 'text-neutral-700 dark:text-neutral-400'
                      }`}>
                        {percentage.toFixed(1)}%
                      </span>
                    )}
                  </div>
                  </div>
                </button>
              );
            })
          )}
        </div>

        {/* Vote Button (if not voted) */}
        {!hasVoted && !poll.is_closed && (
          <button
            onClick={handleVote}
            disabled={!selectedOption || isVoting}
            className="w-full mb-4 px-4 py-2.5 bg-purple-600 hover:bg-purple-700 text-white rounded-lg font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isVoting ? 'Voting...' : 'Vote'}
          </button>
        )}

        {/* Poll Info */}
        <div className="flex items-center gap-3 text-sm text-neutral-500 dark:text-neutral-400 mb-4">
          <span>{formatCount(poll.total_votes)} votes</span>
          <span>·</span>
          <div className="flex items-center gap-1">
            <Clock className="w-3.5 h-3.5" />
            <span>{timeLeft}</span>
          </div>
          {hasVoted && poll.allow_vote_changes && !poll.is_closed && (
            <>
              <span>·</span>
              <button 
                onClick={() => {
                  setHasVoted(false);
                  setSelectedOption(null);
                }}
                className="text-purple-600 dark:text-purple-400 hover:underline"
              >
                Change vote
              </button>
            </>
          )}
        </div>

        {/* Actions */}
        <PostActions
          postId={post.id}
          isLiked={post.is_liked}
          isSaved={post.is_saved}
          likesCount={post.likes_count}
          commentsCount={post.comments_count}
          sharesCount={post.shares_count}
          onComment={() => setShowCommentModal(true)}
          onShare={onShare}
          onSave={onSave}
        />
      </Card>

      {/* Comment Modal */}
      <CommentModal
        post={post}
        isOpen={showCommentModal}
        onClose={() => setShowCommentModal(false)}
      />
    </motion.div>
  );
}


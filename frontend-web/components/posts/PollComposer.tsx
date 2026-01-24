'use client';

import { useState } from 'react';
import { Plus, X, Loader2, Calendar, Check, Globe, Users, Lock } from 'lucide-react';
import { postsAPI, CreatePostRequest, CreatePollRequest } from '@/lib/api/posts';
import { toast } from '../ui/Toast';
import { Avatar } from '../ui/Avatar';

interface PollComposerProps {
  onClose: () => void;
  onPostCreated?: (post: any) => void;
}

export default function PollComposer({ onClose, onPostCreated }: PollComposerProps) {
  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState(['', '']);
  const [duration, setDuration] = useState(24); // hours
  const [visibility, setVisibility] = useState<'public' | 'connections' | 'private'>('public');
  const [allowVoteChanges, setAllowVoteChanges] = useState(true);
  const [showResultsBefore, setShowResultsBefore] = useState(true);
  const [anonymousVotes, setAnonymousVotes] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const addOption = () => {
    if (options.length < 4) {
      setOptions([...options, '']);
    }
  };

  const removeOption = (index: number) => {
    if (options.length > 2) {
      setOptions(options.filter((_, i) => i !== index));
    }
  };

  const updateOption = (index: number, value: string) => {
    const newOptions = [...options];
    newOptions[index] = value;
    setOptions(newOptions);
  };

  const handleSubmit = async () => {
    // Validation
    if (!question.trim()) {
      toast.error('Please enter a question');
      return;
    }

    if (question.length > 280) {
      toast.error('Question must be 280 characters or less');
      return;
    }

    const filledOptions = options.filter(opt => opt.trim());
    if (filledOptions.length < 2) {
      toast.error('Please provide at least 2 options');
      return;
    }

    if (filledOptions.some(opt => opt.length > 100)) {
      toast.error('Poll options must be 100 characters or less');
      return;
    }

    setIsSubmitting(true);

    try {
      const pollData: CreatePollRequest = {
        question: question.trim(),
        options: filledOptions,
        duration_hours: duration,
        allow_vote_changes: allowVoteChanges,
        show_results_before_vote: showResultsBefore,
        anonymous_votes: anonymousVotes,
      };

      const postData: CreatePostRequest = {
        post_type: 'poll',
        content: question.trim(),
        visibility,
        allows_comments: true,
        allows_sharing: true,
        poll: pollData,
      };

      const response = await postsAPI.createPost(postData);

      if (response.success) {
        toast.success('Poll published successfully!');
        onPostCreated?.(response.post);
        onClose();
      }
    } catch (error) {
      console.error('Failed to create poll:', error);
      toast.error('Failed to publish poll');
    } finally {
      setIsSubmitting(false);
    }
  };

  const questionCharCount = question.length;

  return (
    <div className="p-4 md:p-6 space-y-4 md:space-y-6">
      {/* User Info */}
      <div className="flex items-center gap-3">
        <Avatar src={null} alt="You" fallback="You" size="md" />
        <div>
          <p className="font-semibold text-neutral-900 dark:text-neutral-50">Create a Poll</p>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            Ask your network a question
          </p>
        </div>
      </div>

      {/* Question Input */}
      <div className="space-y-2">
        <label className="text-sm font-medium text-neutral-700 dark:text-neutral-300">
          Question
        </label>
        <textarea
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          placeholder="Ask a question..."
          className="w-full min-h-[80px] md:min-h-[100px] px-3 md:px-4 py-3 bg-white dark:bg-neutral-800 border-2 border-neutral-200 dark:border-neutral-700 rounded-xl text-black dark:text-white placeholder:text-neutral-400 dark:placeholder:text-neutral-500 resize-none focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 transition-all cursor-text"
          maxLength={280}
        />
        <div className="flex justify-end">
          <span className={`text-sm ${questionCharCount > 280 ? 'text-red-500' : 'text-neutral-500'}`}>
            {questionCharCount} / 280
          </span>
        </div>
      </div>

      {/* Poll Options */}
      <div className="space-y-3">
        <label className="text-sm font-medium text-neutral-700 dark:text-neutral-300">
          Options ({options.length}/4)
        </label>
        
        {options.map((option, index) => (
          <div key={index} className="flex items-center gap-2">
            <div className="flex-1 relative">
              <input
                type="text"
                value={option}
                onChange={(e) => updateOption(index, e.target.value)}
                placeholder={`Option ${index + 1}`}
                className="w-full px-4 py-2.5 pr-16 bg-white dark:bg-neutral-800 border-2 border-neutral-200 dark:border-neutral-700 rounded-lg text-black dark:text-white placeholder:text-neutral-400 dark:placeholder:text-neutral-500 focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 transition-all cursor-text"
                maxLength={100}
              />
              <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-neutral-400">
                {option.length}/100
              </span>
            </div>
            {options.length > 2 && (
              <button
                onClick={() => removeOption(index)}
                className="p-2 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>
        ))}

        {options.length < 4 && (
          <button
            onClick={addOption}
            className="flex items-center gap-2 px-4 py-2.5 w-full border-2 border-dashed border-neutral-300 dark:border-neutral-700 hover:border-purple-400 dark:hover:border-purple-600 rounded-lg transition-colors text-neutral-600 dark:text-neutral-400 hover:text-purple-600 dark:hover:text-purple-400"
          >
            <Plus className="w-4 h-4" />
            <span className="text-sm font-medium">Add Option</span>
          </button>
        )}
      </div>

      {/* Duration */}
      <div className="space-y-2">
        <label className="text-sm font-medium text-neutral-700 dark:text-neutral-300">
          Poll Duration
        </label>
        <div className="grid grid-cols-4 gap-2">
          {[
            { value: 24, label: '1 Day' },
            { value: 72, label: '3 Days' },
            { value: 168, label: '1 Week' },
            { value: 336, label: '2 Weeks' },
          ].map((option) => (
            <button
              key={option.value}
              onClick={() => setDuration(option.value)}
              className={`px-3 py-2 rounded-lg text-sm font-medium transition-all ${
                duration === option.value
                  ? 'bg-purple-600 text-white shadow-md'
                  : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
              }`}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>

      {/* Poll Settings */}
      <div className="space-y-3 p-3 md:p-4 bg-transparent border-2 border-neutral-200 dark:border-neutral-700 rounded-xl hover:border-neutral-300 dark:hover:border-neutral-600 transition-colors">
        <p className="text-sm font-medium text-black dark:text-white mb-3">
          Poll Settings
        </p>
        
        <label className="flex items-center justify-between cursor-pointer">
          <span className="text-sm text-neutral-700 dark:text-neutral-300">
            Allow vote changes
          </span>
          <div className="relative">
            <input
              type="checkbox"
              checked={allowVoteChanges}
              onChange={(e) => setAllowVoteChanges(e.target.checked)}
              className="sr-only peer"
            />
            <div className="w-11 h-6 bg-neutral-300 dark:bg-neutral-700 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-purple-500 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-purple-600"></div>
          </div>
        </label>

        <label className="flex items-center justify-between cursor-pointer">
          <span className="text-sm text-neutral-700 dark:text-neutral-300">
            Show results before voting
          </span>
          <div className="relative">
            <input
              type="checkbox"
              checked={showResultsBefore}
              onChange={(e) => setShowResultsBefore(e.target.checked)}
              className="sr-only peer"
            />
            <div className="w-11 h-6 bg-neutral-300 dark:bg-neutral-700 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-purple-500 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-purple-600"></div>
          </div>
        </label>

        <label className="flex items-center justify-between cursor-pointer">
          <span className="text-sm text-neutral-700 dark:text-neutral-300">
            Anonymous voting
          </span>
          <div className="relative">
            <input
              type="checkbox"
              checked={anonymousVotes}
              onChange={(e) => setAnonymousVotes(e.target.checked)}
              className="sr-only peer"
            />
            <div className="w-11 h-6 bg-neutral-300 dark:bg-neutral-700 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-purple-500 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-purple-600"></div>
          </div>
        </label>
      </div>

      {/* Visibility */}
      <div className="flex items-center justify-between p-4 bg-transparent border-2 border-neutral-200 dark:border-neutral-700 rounded-xl hover:border-neutral-300 dark:hover:border-neutral-600 transition-colors">
        <div className="flex items-center gap-3">
          {visibility === 'public' && <Globe className="w-5 h-5 text-purple-600 dark:text-purple-400" />}
          {visibility === 'connections' && <Users className="w-5 h-5 text-purple-600 dark:text-purple-400" />}
          {visibility === 'private' && <Lock className="w-5 h-5 text-purple-600 dark:text-purple-400" />}
          <div>
            <p className="text-sm font-medium text-black dark:text-white">
              {visibility === 'public' && 'Everyone'}
              {visibility === 'connections' && 'Connections only'}
              {visibility === 'private' && 'Only me'}
            </p>
            <p className="text-xs text-neutral-500 dark:text-neutral-400">
              {visibility === 'public' && 'Anyone can see this poll'}
              {visibility === 'connections' && 'Only your connections can see'}
              {visibility === 'private' && 'Only you can see this'}
            </p>
          </div>
        </div>
        <select
          value={visibility}
          onChange={(e) => setVisibility(e.target.value as any)}
          className="px-4 py-2 bg-neutral-50 dark:bg-neutral-800 border-2 border-neutral-200 dark:border-neutral-700 rounded-lg text-sm font-medium text-black dark:text-white focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 cursor-pointer transition-all hover:border-purple-400"
        >
          <option value="public">Everyone</option>
          <option value="connections">Connections</option>
          <option value="private">Private</option>
        </select>
      </div>

      {/* Actions */}
      <div className="flex items-center justify-end gap-3 pt-3 md:pt-4 border-t border-neutral-200 dark:border-neutral-800">
        <button
          onClick={onClose}
          className="px-5 py-2.5 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-lg transition-colors font-medium"
          disabled={isSubmitting}
        >
          Cancel
        </button>
        <button
          onClick={handleSubmit}
          disabled={!question.trim() || options.filter(o => o.trim()).length < 2 || isSubmitting}
          className="px-6 py-2.5 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          {isSubmitting ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              Creating...
            </>
          ) : (
            'Create Poll'
          )}
        </button>
      </div>
    </div>
  );
}


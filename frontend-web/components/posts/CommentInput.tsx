'use client';

import { useState, useRef, useEffect } from 'react';
import { X } from 'lucide-react';
import { Comment } from '@/lib/api/posts';
import { useUser } from '@/lib/hooks/useUser';
import { Avatar } from '../ui/Avatar';

interface CommentInputProps {
  onSubmit: (content: string) => void;
  onCancel?: () => void;
  editingComment?: Comment | null;
  onUpdate?: (content: string) => void;
  placeholder?: string;
}

export default function CommentInput({
  onSubmit,
  onCancel,
  editingComment,
  onUpdate,
  placeholder = 'Add a comment...',
}: CommentInputProps) {
  const { user } = useUser();
  const [content, setContent] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Set content when editing
  useEffect(() => {
    if (editingComment) {
      setContent(editingComment.content);
      textareaRef.current?.focus();
    } else {
      setContent('');
    }
  }, [editingComment]);

  // Auto-resize textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${Math.min(textareaRef.current.scrollHeight, 120)}px`;
    }
  }, [content]);


  const handleSubmit = () => {
    const trimmedContent = content.trim();
    if (!trimmedContent) return;

    if (editingComment && onUpdate) {
      onUpdate(trimmedContent);
    } else {
      onSubmit(trimmedContent);
    }
    setContent('');
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
    if (e.key === 'Escape' && onCancel) {
      onCancel();
    }
  };

  const isDisabled = !content.trim();

  return (
    <div className="relative">
      <div className="flex items-center gap-3 px-4 py-3">
        {/* User Avatar */}
        <Avatar
          src={user?.profile_picture}
          alt={user?.display_name || user?.username || 'User'}
          fallback={user?.display_name || user?.username || 'U'}
          size="sm"
          className="flex-shrink-0"
        />
        
        {/* Text Input */}
        <div className="flex-1 relative">
          <textarea
            ref={textareaRef}
            value={content}
            onChange={(e) => setContent(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={placeholder}
            rows={1}
            className="
              w-full px-0 py-1
              bg-transparent
              resize-none
              focus:outline-none
              text-sm text-neutral-900 dark:text-neutral-50
              placeholder:text-neutral-400 dark:placeholder:text-neutral-500
              max-h-[120px] overflow-y-auto
            "
            style={{ minHeight: '20px' }}
          />
        </div>

        {/* Submit Button - Instagram Style */}
        <div className="flex items-center gap-2 flex-shrink-0">
          {editingComment && onCancel && (
            <button
              onClick={onCancel}
              className="p-1 transition-opacity"
              type="button"
            >
              <X className="w-4 h-4 text-neutral-500 dark:text-neutral-400" />
            </button>
          )}
          <button
            onClick={handleSubmit}
            disabled={isDisabled}
            className={`
              text-sm font-semibold transition-opacity
              ${isDisabled
                ? 'text-blue-300 dark:text-blue-600 cursor-not-allowed opacity-50'
                : 'text-blue-500 dark:text-blue-400'
              }
            `}
            type="button"
          >
            Post
          </button>
        </div>
      </div>
    </div>
  );
}


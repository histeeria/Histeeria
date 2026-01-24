'use client';

import { useState } from 'react';
import { X, Trash2, RefreshCw } from 'lucide-react';
import EmojiPicker from './EmojiPicker';

interface ReactionManageDialogProps {
  isOpen: boolean;
  currentEmoji: string;
  onClose: () => void;
  onRemove: () => void;
  onChange: (newEmoji: string) => void;
}

export function ReactionManageDialog({
  isOpen,
  currentEmoji,
  onClose,
  onRemove,
  onChange,
}: ReactionManageDialogProps) {
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);

  if (!isOpen) return null;

  const handleChange = () => {
    setShowEmojiPicker(true);
  };

  const handleEmojiSelect = (emoji: string) => {
    onChange(emoji);
    setShowEmojiPicker(false);
    onClose();
  };

  const handleRemove = () => {
    onRemove();
    onClose();
  };

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center"
        onClick={onClose}
      >
        <div
          className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl w-[90%] max-w-md p-6 relative"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Close Button */}
          <button
            onClick={onClose}
            className="absolute top-4 right-4 p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
          </button>

          {/* Header */}
          <div className="mb-6">
            <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
              Manage Reaction
            </h3>
            <div className="flex items-center gap-2">
              <span className="text-4xl">{currentEmoji}</span>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Your current reaction
              </p>
            </div>
          </div>

          {/* Options */}
          {!showEmojiPicker ? (
            <div className="space-y-3">
              {/* Change Reaction */}
              <button
                onClick={handleChange}
                className="w-full flex items-center gap-3 px-4 py-3 text-left bg-purple-50 dark:bg-purple-900/20 hover:bg-purple-100 dark:hover:bg-purple-900/30 border border-purple-200 dark:border-purple-800 rounded-xl transition-colors group"
              >
                <RefreshCw className="w-5 h-5 text-purple-600 dark:text-purple-400 group-hover:rotate-180 transition-transform duration-300" />
                <div>
                  <div className="font-semibold text-purple-700 dark:text-purple-300">
                    Change Reaction
                  </div>
                  <div className="text-xs text-purple-600/70 dark:text-purple-400/70">
                    Pick a different emoji
                  </div>
                </div>
              </button>

              {/* Remove Reaction */}
              <button
                onClick={handleRemove}
                className="w-full flex items-center gap-3 px-4 py-3 text-left bg-red-50 dark:bg-red-900/20 hover:bg-red-100 dark:hover:bg-red-900/30 border border-red-200 dark:border-red-800 rounded-xl transition-colors group"
              >
                <Trash2 className="w-5 h-5 text-red-600 dark:text-red-400 group-hover:scale-110 transition-transform" />
                <div>
                  <div className="font-semibold text-red-700 dark:text-red-300">
                    Remove Reaction
                  </div>
                  <div className="text-xs text-red-600/70 dark:text-red-400/70">
                    Delete this reaction
                  </div>
                </div>
              </button>

              {/* Cancel */}
              <button
                onClick={onClose}
                className="w-full px-4 py-3 text-center text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-xl transition-colors font-medium"
              >
                Cancel
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              <p className="text-sm text-gray-600 dark:text-gray-400 mb-3">
                Select a new emoji:
              </p>
              <EmojiPicker
                onSelect={handleEmojiSelect}
                onClose={() => setShowEmojiPicker(false)}
              />
            </div>
          )}
        </div>
      </div>
    </>
  );
}


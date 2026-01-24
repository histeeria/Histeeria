'use client';

import { useState } from 'react';

interface EmojiPickerProps {
  onSelect: (emoji: string) => void;
}

// Common emojis for quick access (Instagram-style)
const EMOJI_CATEGORIES = {
  'Recently Used': ['❤️', '😂', '😍', '🔥', '👍', '😊', '🎉', '💯'],
  'Smileys & People': ['😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔'],
  'Gestures': ['👋', '🤚', '🖐', '✋', '🖖', '👌', '🤏', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏'],
  'Hearts': ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟'],
  'Objects': ['🔥', '💯', '⭐', '🌟', '✨', '💫', '🎉', '🎊', '🏆', '🥇', '🥈', '🥉', '🏅', '🎖', '🎗', '🎟', '🎫', '🎪', '🎭', '🎨', '🎬', '🎤', '🎧', '🎼', '🎹', '🥁', '🎷', '🎺', '🎸', '🎻'],
};

export default function EmojiPicker({ onSelect }: EmojiPickerProps) {
  const [activeCategory, setActiveCategory] = useState<keyof typeof EMOJI_CATEGORIES>('Recently Used');

  return (
    <div className="bg-white dark:bg-neutral-800 rounded-xl shadow-xl border border-neutral-200 dark:border-neutral-700 w-[320px] h-[400px] flex flex-col overflow-hidden">
      {/* Category Tabs */}
      <div className="flex border-b border-neutral-200 dark:border-neutral-700 overflow-x-auto scrollbar-hide">
        {Object.keys(EMOJI_CATEGORIES).map((category) => (
          <button
            key={category}
            onClick={() => setActiveCategory(category as keyof typeof EMOJI_CATEGORIES)}
            className={`px-3 py-2 text-xs font-medium whitespace-nowrap transition-colors ${
              activeCategory === category
                ? 'text-purple-600 dark:text-purple-400 border-b-2 border-purple-600 dark:border-purple-400'
                : 'text-neutral-500 dark:text-neutral-400 hover:text-neutral-700 dark:hover:text-neutral-300'
            }`}
          >
            {category}
          </button>
        ))}
      </div>

      {/* Emoji Grid */}
      <div className="flex-1 overflow-y-auto p-3">
        <div className="grid grid-cols-8 gap-1">
          {EMOJI_CATEGORIES[activeCategory].map((emoji, index) => (
            <button
              key={`${activeCategory}-${index}`}
              onClick={() => onSelect(emoji)}
              className="w-10 h-10 flex items-center justify-center text-2xl hover:bg-neutral-100 dark:hover:bg-neutral-700 rounded-lg transition-colors active:scale-90"
            >
              {emoji}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}


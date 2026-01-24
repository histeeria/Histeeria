'use client';

import { useState } from 'react';
import { Search, X } from 'lucide-react';

interface EmojiPickerProps {
  onSelect: (emoji: string) => void;
  onClose: () => void;
  position?: 'left' | 'right';
}

const emojiCategories = {
  'Smileys': ['😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙', '🥲', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥', '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥵', '🥶', '😶‍🌫️', '🥴', '😵', '🤯', '🤠', '🥳', '🥸', '😎', '🤓', '🧐'],
  'Gestures': ['👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏'],
  'Hearts': ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝'],
  'Symbols': ['✅', '❌', '✔️', '✖️', '➕', '➖', '➗', '✳️', '✴️', '❇️', '‼️', '⁉️', '❓', '❔', '❕', '❗', '💯', '🔥', '💫', '⭐', '🌟', '✨', '⚡', '💥', '💢', '💬', '💭', '💤'],
  'Objects': ['🎉', '🎊', '🎈', '🎁', '🏆', '🥇', '🥈', '🥉', '⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏉', '🥏', '🎱', '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🥅', '⛳', '🪁', '🏹', '🎣', '🤿'],
};

export default function EmojiPicker({ onSelect, onClose, position = 'left' }: EmojiPickerProps) {
  const [search, setSearch] = useState('');
  const [activeCategory, setActiveCategory] = useState<keyof typeof emojiCategories>('Smileys');

  const filteredEmojis = search
    ? Object.values(emojiCategories).flat().filter(emoji => emoji.includes(search))
    : emojiCategories[activeCategory];

  return (
    <div
      className={`absolute -top-[320px] ${
        position === 'right' ? 'right-0' : 'left-0'
      } w-[280px] bg-white dark:bg-gray-800 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 overflow-hidden z-50`}
      onClick={(e) => e.stopPropagation()}
    >
      {/* Header */}
      <div className="flex items-center justify-between p-3 border-b border-gray-200 dark:border-gray-700">
        <h4 className="text-sm font-semibold text-gray-900 dark:text-white">
          Choose Reaction
        </h4>
        <button
          onClick={onClose}
          className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors"
        >
          <X className="w-4 h-4 text-gray-500" />
        </button>
      </div>

      {/* Search */}
      <div className="p-2 border-b border-gray-200 dark:border-gray-700">
        <div className="relative">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search emoji..."
            className="w-full pl-8 pr-3 py-1.5 text-sm bg-gray-100 dark:bg-gray-700 rounded-lg border-0 outline-none focus:ring-2 focus:ring-purple-500"
          />
        </div>
      </div>

      {/* Categories */}
      {!search && (
        <div className="flex gap-1 px-2 py-2 border-b border-gray-200 dark:border-gray-700 overflow-x-auto scrollbar-hide">
          {Object.keys(emojiCategories).map((category) => (
            <button
              key={category}
              onClick={() => setActiveCategory(category as keyof typeof emojiCategories)}
              className={`px-3 py-1 text-xs rounded-full whitespace-nowrap transition-colors ${
                activeCategory === category
                  ? 'bg-purple-600 text-white'
                  : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
              }`}
            >
              {category}
            </button>
          ))}
        </div>
      )}

      {/* Emoji Grid */}
      <div className="p-2 h-[200px] overflow-y-auto">
        <div className="grid grid-cols-8 gap-1">
          {filteredEmojis.map((emoji, index) => (
            <button
              key={index}
              onClick={() => {
                onSelect(emoji);
                onClose();
              }}
              className="text-2xl p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors hover:scale-125 active:scale-110"
              title={emoji}
            >
              {emoji}
            </button>
          ))}
        </div>
        
        {filteredEmojis.length === 0 && (
          <div className="text-center py-8 text-sm text-gray-500">
            No emojis found
          </div>
        )}
      </div>
    </div>
  );
}


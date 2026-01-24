'use client';

/**
 * Collection Item Component
 * Handles individual collection display with edit/delete
 */

import { useState } from 'react';
import { Bookmark, Edit2, Trash2, Check, X } from 'lucide-react';
import { toast } from '@/components/ui/Toast';

interface Collection {
  id: string;
  name: string;
  count: number;
  isDefault?: boolean;
}

interface CollectionItemProps {
  collection: Collection;
  isActive: boolean;
  onSelect: (id: string) => void;
  onRename: (id: string, newName: string) => void;
  onDelete: (id: string) => void;
}

export default function CollectionItem({
  collection,
  isActive,
  onSelect,
  onRename,
  onDelete,
}: CollectionItemProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState(collection.name);

  const handleSave = () => {
    if (!editName.trim()) {
      toast.error('Collection name cannot be empty');
      return;
    }
    onRename(collection.id, editName);
    setIsEditing(false);
  };

  const handleCancel = () => {
    setEditName(collection.name);
    setIsEditing(false);
  };

  if (isEditing) {
    return (
      <div className="flex items-center gap-1 bg-neutral-100 dark:bg-neutral-800 rounded-lg px-2 py-1 flex-shrink-0">
        <input
          type="text"
          value={editName}
          onChange={(e) => setEditName(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              handleSave();
            } else if (e.key === 'Escape') {
              handleCancel();
            }
          }}
          className="text-sm bg-transparent border-none outline-none text-neutral-900 dark:text-neutral-50 min-w-[80px]"
          autoFocus
          aria-label="Edit collection name"
        />
        <button
          onClick={handleSave}
          className="p-1 hover:bg-neutral-200 dark:hover:bg-neutral-700 rounded"
          aria-label="Save collection name"
        >
          <Check className="w-3 h-3" />
        </button>
        <button
          onClick={handleCancel}
          className="p-1 hover:bg-neutral-200 dark:hover:bg-neutral-700 rounded"
          aria-label="Cancel editing"
        >
          <X className="w-3 h-3" />
        </button>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-1 flex-shrink-0">
      <button
        onClick={() => onSelect(collection.id)}
        className={`px-4 py-2 rounded-full text-sm font-semibold whitespace-nowrap transition-all duration-200 flex items-center gap-2 ${
          isActive
            ? 'bg-purple-600 text-white shadow-md'
            : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
        }`}
        aria-label={`Select collection ${collection.name}`}
        aria-pressed={isActive}
      >
        <Bookmark className="w-4 h-4" />
        <span>{collection.name}</span>
        {collection.count > 0 && (
          <span className={`px-2 py-0.5 rounded-full text-xs ${
            isActive
              ? 'bg-white/20 text-white'
              : 'bg-neutral-200 dark:bg-neutral-700 text-neutral-600 dark:text-neutral-400'
          }`}>
            {collection.count}
          </span>
        )}
      </button>
      {!collection.isDefault && (
        <>
          <button
            onClick={() => setIsEditing(true)}
            className="p-1.5 hover:bg-neutral-200 dark:hover:bg-neutral-700 rounded-full transition-colors"
            aria-label={`Edit collection ${collection.name}`}
          >
            <Edit2 className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={() => onDelete(collection.id)}
            className="p-1.5 hover:bg-red-100 dark:hover:bg-red-900/20 rounded-full transition-colors text-red-600 dark:text-red-400"
            aria-label={`Delete collection ${collection.name}`}
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </>
      )}
    </div>
  );
}

'use client';

import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Button } from '../ui/Button';

interface InlineEditorProps {
  title: string;
  value: string | null;
  maxLength: number;
  placeholder: string;
  isOpen: boolean;
  onClose: () => void;
  onSave: (value: string | null) => Promise<void>;
}

export default function InlineEditor({
  title,
  value,
  maxLength,
  placeholder,
  isOpen,
  onClose,
  onSave,
}: InlineEditorProps) {
  const [text, setText] = useState(value || '');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen) {
      setText(value || '');
      setError(null);
    }
  }, [isOpen, value]);

  const handleSave = async () => {
    setIsLoading(true);
    setError(null);

    try {
      await onSave(text.trim() || null);
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to save');
    } finally {
      setIsLoading(false);
    }
  };

  const handleCancel = () => {
    setText(value || '');
    setError(null);
    onClose();
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="w-full max-w-2xl bg-white dark:bg-neutral-900 rounded-2xl shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-neutral-200 dark:border-neutral-800">
          <h2 className="text-xl font-semibold text-neutral-900 dark:text-white">
            {title}
          </h2>
          <button
            onClick={handleCancel}
            disabled={isLoading}
            className="p-2 rounded-lg hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors disabled:opacity-50"
          >
            <X className="w-5 h-5 text-neutral-600 dark:text-neutral-400" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6">
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder={placeholder}
            maxLength={maxLength}
            rows={8}
            disabled={isLoading}
            className="w-full px-4 py-3 rounded-xl border border-neutral-200 dark:border-neutral-700 bg-white dark:bg-neutral-900 text-neutral-900 dark:text-neutral-100 placeholder-neutral-400 dark:placeholder-neutral-500 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 resize-none disabled:opacity-50"
          />

          <div className="mt-2 flex items-center justify-between">
            <div className={`text-sm ${text.length > maxLength * 0.9 ? 'text-red-500' : 'text-neutral-500'}`}>
              {text.length} / {maxLength}
            </div>
            {error && (
              <div className="text-sm text-red-500">{error}</div>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 p-6 border-t border-neutral-200 dark:border-neutral-800">
          <Button
            variant="ghost"
            size="md"
            onClick={handleCancel}
            disabled={isLoading}
          >
            Cancel
          </Button>
          <Button
            variant="primary"
            size="md"
            onClick={handleSave}
            isLoading={isLoading}
            disabled={isLoading || text.length > maxLength}
          >
            Save
          </Button>
        </div>
      </div>
    </div>
  );
}


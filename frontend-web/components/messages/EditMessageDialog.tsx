'use client';

import { useState } from 'react';
import { X, Save } from 'lucide-react';
import { messagesAPI } from '@/lib/api/messages';
import { toast } from '../ui/Toast';

interface EditMessageDialogProps {
  isOpen: boolean;
  messageId: string;
  currentContent: string;
  onClose: () => void;
  onEdit?: (newContent: string) => void;
}

export function EditMessageDialog({
  isOpen,
  messageId,
  currentContent,
  onClose,
  onEdit,
}: EditMessageDialogProps) {
  const [content, setContent] = useState(currentContent);
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    if (!content.trim()) {
      toast.error('Message cannot be empty');
      return;
    }

    if (content === currentContent) {
      toast.info('No changes made');
      onClose();
      return;
    }

    try {
      setSaving(true);
      const response = await messagesAPI.editMessage(messageId, content);
      
      if (response.success) {
        toast.success('Message edited successfully');
        onEdit?.(content);
        onClose();
      }
    } catch (error) {
      console.error('Failed to edit message:', error);
      toast.error('Failed to edit message');
    } finally {
      setSaving(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div
        className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl w-full max-w-md"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
          <h3 className="text-lg font-bold text-gray-900 dark:text-white">
            Edit Message
          </h3>
          <button
            onClick={onClose}
            disabled={saving}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors disabled:opacity-50"
          >
            <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
          </button>
        </div>

        {/* Content */}
        <div className="p-4">
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="Type your message..."
            disabled={saving}
            className="w-full h-32 p-3 bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:ring-2 focus:ring-purple-500 resize-none disabled:opacity-50"
            autoFocus
          />
        </div>

        {/* Footer */}
        <div className="flex gap-2 p-4 border-t border-gray-200 dark:border-gray-700">
          <button
            onClick={onClose}
            disabled={saving}
            className="flex-1 px-4 py-2 text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors font-medium disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={saving || !content.trim()}
            className="flex-1 px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          >
            {saving ? (
              <>
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                Saving...
              </>
            ) : (
              <>
                <Save className="w-4 h-4" />
                Save
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}


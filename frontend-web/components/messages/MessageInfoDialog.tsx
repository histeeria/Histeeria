'use client';

import { useState, useEffect } from 'react';
import { X, Clock, Eye, Check, CheckCheck, Edit, Pin, Forward } from 'lucide-react';
import { messagesAPI, Message } from '@/lib/api/messages';
import { toast } from '../ui/Toast';

interface MessageInfoDialogProps {
  isOpen: boolean;
  message: Message;
  onClose: () => void;
}

export function MessageInfoDialog({
  isOpen,
  message,
  onClose,
}: MessageInfoDialogProps) {
  const [editHistory, setEditHistory] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (isOpen && message.edited_at) {
      loadEditHistory();
    }
  }, [isOpen, message.id]);

  const loadEditHistory = async () => {
    try {
      setLoading(true);
      const response = await messagesAPI.getMessageEditHistory(message.id);
      if (response.success) {
        setEditHistory(response.history);
      }
    } catch (error) {
      console.error('Failed to load edit history:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString?: string) => {
    if (!dateString) return 'N/A';
    
    // Parse the date string correctly
    const date = new Date(dateString);
    
    // Check if date is valid
    if (isNaN(date.getTime())) {
      console.error('[MessageInfo] Invalid date:', dateString);
      return 'Invalid date';
    }
    
    console.log('[MessageInfo] Raw timestamp:', dateString, '→ Parsed:', date.toString());
    
    // Format with seconds for accuracy
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: true,
    }).format(date);
  };

  if (!isOpen) return null;

  // Debug: Log all timestamps
  console.log('[MessageInfo] Message timestamps:', {
    created_at: message.created_at,
    delivered_at: message.delivered_at,
    read_at: message.read_at,
  });

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div
        className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl w-full max-w-lg max-h-[80vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
          <h3 className="text-lg font-bold text-gray-900 dark:text-white">
            Message Info
          </h3>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {/* Message Content */}
          <div>
            <h4 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
              Message
            </h4>
            <div className="bg-gray-50 dark:bg-gray-700/50 p-3 rounded-lg">
              <p className="text-gray-900 dark:text-white break-words">
                {message.content}
              </p>
            </div>
          </div>

          {/* Status Information */}
          <div>
            <h4 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
              Status
            </h4>
            <div className="space-y-2">
              {/* Sent */}
              <div className="flex items-center gap-3 text-sm">
                <Clock className="w-5 h-5 text-gray-400" />
                <div className="flex-1">
                  <span className="text-gray-600 dark:text-gray-400">Sent</span>
                </div>
                <span className="text-gray-900 dark:text-white font-medium">
                  {formatDate(message.created_at)}
                </span>
              </div>

              {/* Delivered */}
              {message.delivered_at && (
                <div className="flex items-center gap-3 text-sm">
                  <Check className="w-5 h-5 text-yellow-500" />
                  <div className="flex-1">
                    <span className="text-gray-600 dark:text-gray-400">Delivered</span>
                  </div>
                  <span className="text-gray-900 dark:text-white font-medium">
                    {formatDate(message.delivered_at)}
                  </span>
                </div>
              )}

              {/* Read */}
              {message.read_at && (
                <div className="flex items-center gap-3 text-sm">
                  <Eye className="w-5 h-5 text-green-500" />
                  <div className="flex-1">
                    <span className="text-gray-600 dark:text-gray-400">Read</span>
                  </div>
                  <span className="text-gray-900 dark:text-white font-medium">
                    {formatDate(message.read_at)}
                  </span>
                </div>
              )}
            </div>
          </div>

          {/* Additional Info */}
          <div>
            <h4 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
              Additional Info
            </h4>
            <div className="space-y-2">
              {/* Edited */}
              {message.edited_at && (
                <div className="flex items-center gap-3 text-sm">
                  <Edit className="w-5 h-5 text-blue-500" />
                  <div className="flex-1">
                    <span className="text-gray-600 dark:text-gray-400">
                      Edited {message.edit_count} {message.edit_count === 1 ? 'time' : 'times'}
                    </span>
                  </div>
                  <span className="text-gray-900 dark:text-white font-medium">
                    {formatDate(message.edited_at)}
                  </span>
                </div>
              )}

              {/* Pinned */}
              {message.pinned_at && (
                <div className="flex items-center gap-3 text-sm">
                  <Pin className="w-5 h-5 text-purple-500" />
                  <div className="flex-1">
                    <span className="text-gray-600 dark:text-gray-400">Pinned</span>
                  </div>
                  <span className="text-gray-900 dark:text-white font-medium">
                    {formatDate(message.pinned_at)}
                  </span>
                </div>
              )}

              {/* Forwarded */}
              {message.is_forwarded && (
                <div className="flex items-center gap-3 text-sm">
                  <Forward className="w-5 h-5 text-orange-500" />
                  <div className="flex-1">
                    <span className="text-gray-600 dark:text-gray-400">Forwarded message</span>
                  </div>
                </div>
              )}

              {/* Message Type */}
              <div className="flex items-center gap-3 text-sm">
                <div className="flex-1">
                  <span className="text-gray-600 dark:text-gray-400">Type</span>
                </div>
                <span className="text-gray-900 dark:text-white font-medium capitalize">
                  {message.message_type}
                </span>
              </div>
            </div>
          </div>

          {/* Edit History */}
          {message.edited_at && (
            <div>
              <h4 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
                Edit History
              </h4>
              {loading ? (
                <div className="flex items-center justify-center py-4">
                  <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-purple-600"></div>
                </div>
              ) : editHistory.length > 0 ? (
                <div className="space-y-2">
                  {editHistory.map((edit, index) => (
                    <div
                      key={index}
                      className="bg-gray-50 dark:bg-gray-700/50 p-3 rounded-lg"
                    >
                      <p className="text-xs text-gray-500 dark:text-gray-400 mb-1">
                        {formatDate(edit.edited_at)}
                      </p>
                      <p className="text-sm text-gray-900 dark:text-white">
                        {edit.previous_content}
                      </p>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  No edit history available
                </p>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-gray-200 dark:border-gray-700">
          <button
            onClick={onClose}
            className="w-full px-4 py-2 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 rounded-lg transition-colors font-medium"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}


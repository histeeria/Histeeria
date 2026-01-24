'use client';

import { X, FileText, Image as ImageIcon, Music, File } from 'lucide-react';
import { UploadProgress } from '@/lib/hooks/useUploadProgress';

interface UploadProgressBarProps {
  upload: UploadProgress;
  onCancel: (uploadId: string) => void;
}

export function UploadProgressBar({ upload, onCancel }: UploadProgressBarProps) {
  const getFileIcon = () => {
    if (upload.filename.match(/\.(jpg|jpeg|png|gif|webp)$/i)) {
      return <ImageIcon className="w-5 h-5 text-blue-500" />;
    }
    if (upload.filename.match(/\.(mp3|wav|ogg|webm|m4a)$/i)) {
      return <Music className="w-5 h-5 text-purple-500" />;
    }
    if (upload.filename.match(/\.(pdf|doc|docx)$/i)) {
      return <FileText className="w-5 h-5 text-red-500" />;
    }
    return <File className="w-5 h-5 text-gray-500" />;
  };

  const getStatusColor = () => {
    switch (upload.status) {
      case 'uploading':
        return 'bg-blue-500';
      case 'completed':
        return 'bg-green-500';
      case 'failed':
        return 'bg-red-500';
      case 'cancelled':
        return 'bg-gray-500';
      default:
        return 'bg-blue-500';
    }
  };

  const getStatusText = () => {
    switch (upload.status) {
      case 'uploading':
        return `Uploading... ${upload.progress}%`;
      case 'completed':
        return 'Upload complete!';
      case 'failed':
        return upload.error || 'Upload failed';
      case 'cancelled':
        return 'Upload cancelled';
      default:
        return 'Uploading...';
    }
  };

  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg border border-gray-200 dark:border-gray-700 p-3 mb-2 animate-slide-in-up">
      <div className="flex items-center gap-3">
        {/* File Icon with Circular Progress (WhatsApp-style) */}
        <div className="flex-shrink-0 relative">
          {upload.status === 'uploading' ? (
            <div className="relative w-12 h-12">
              {/* Background Circle */}
              <svg className="w-12 h-12 transform -rotate-90">
                <circle
                  cx="24"
                  cy="24"
                  r="20"
                  stroke="currentColor"
                  strokeWidth="3"
                  fill="none"
                  className="text-gray-200 dark:text-gray-700"
                />
                {/* Progress Circle */}
                <circle
                  cx="24"
                  cy="24"
                  r="20"
                  stroke="currentColor"
                  strokeWidth="3"
                  fill="none"
                  strokeDasharray={`${2 * Math.PI * 20}`}
                  strokeDashoffset={`${2 * Math.PI * 20 * (1 - upload.progress / 100)}`}
                  className="text-purple-600 transition-all duration-300"
                  strokeLinecap="round"
                />
              </svg>
              {/* File Icon in Center */}
              <div className="absolute inset-0 flex items-center justify-center">
                {getFileIcon()}
              </div>
            </div>
          ) : (
            getFileIcon()
          )}
        </div>

        {/* Upload Info */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between gap-2 mb-1">
            <p className="text-sm font-medium text-gray-900 dark:text-gray-100 truncate">
              {upload.filename}
            </p>
            {upload.status === 'uploading' && (
              <button
                onClick={() => onCancel(upload.uploadId)}
                className="flex-shrink-0 p-1.5 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-full transition-colors group"
                title="Cancel upload"
              >
                <X className="w-4 h-4 text-gray-500 dark:text-gray-400 group-hover:text-red-600 dark:group-hover:text-red-400" />
              </button>
            )}
          </div>

          {/* Progress Bar (Linear fallback) */}
          <div className="relative w-full h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden mb-1">
            <div
              className={`absolute top-0 left-0 h-full ${getStatusColor()} transition-all duration-300 ease-out`}
              style={{ width: `${upload.progress}%` }}
            />
          </div>

          {/* Status Text */}
          <p className="text-xs text-gray-600 dark:text-gray-400">
            {getStatusText()}
          </p>
        </div>
      </div>
    </div>
  );
}


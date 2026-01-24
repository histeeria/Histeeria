'use client';

import { useState } from 'react';
import { X, Image as ImageIcon, Sparkles } from 'lucide-react';

interface ImageQualityDialogProps {
  isOpen: boolean;
  filename: string;
  fileSize: number;
  onSelect: (quality: 'standard' | 'hd') => void;
  onCancel: () => void;
}

export function ImageQualityDialog({
  isOpen,
  filename,
  fileSize,
  onSelect,
  onCancel,
}: ImageQualityDialogProps) {
  if (!isOpen) return null;

  const fileSizeMB = (fileSize / (1024 * 1024)).toFixed(2);
  const estimatedStandardSize = (fileSize * 0.3 / (1024 * 1024)).toFixed(2); // ~70% compression
  const estimatedHDSize = (fileSize * 0.6 / (1024 * 1024)).toFixed(2); // ~40% compression

  return (
    <div className="fixed inset-0 bg-black/50 z-[100] flex items-center justify-center p-4 animate-fade-in">
      <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl max-w-md w-full overflow-hidden animate-scale-in">
        {/* Header */}
        <div className="bg-gradient-to-r from-purple-600 to-purple-700 px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
              <ImageIcon className="w-5 h-5 text-white" />
            </div>
            <div>
              <h3 className="text-white font-semibold text-lg">Select Quality</h3>
              <p className="text-purple-100 text-sm">Choose compression level</p>
            </div>
          </div>
          <button
            onClick={onCancel}
            className="p-1 hover:bg-white/10 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-white" />
          </button>
        </div>

        {/* File Info */}
        <div className="px-6 py-4 bg-gray-50 dark:bg-gray-900/50 border-b border-gray-200 dark:border-gray-700">
          <p className="text-sm text-gray-700 dark:text-gray-300 font-medium truncate">
            {filename}
          </p>
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
            Original size: {fileSizeMB} MB
          </p>
        </div>

        {/* Quality Options */}
        <div className="p-6 space-y-3">
          {/* Standard Quality */}
          <button
            onClick={() => onSelect('standard')}
            className="w-full p-4 bg-gradient-to-r from-blue-50 to-blue-100 dark:from-blue-900/20 dark:to-blue-800/20 hover:from-blue-100 hover:to-blue-200 dark:hover:from-blue-900/30 dark:hover:to-blue-800/30 rounded-xl border-2 border-blue-200 dark:border-blue-700 hover:border-blue-400 dark:hover:border-blue-500 transition-all duration-200 text-left group"
          >
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-2">
                  <ImageIcon className="w-5 h-5 text-blue-600 dark:text-blue-400" />
                  <h4 className="font-semibold text-gray-900 dark:text-white">Standard Quality</h4>
                  <span className="px-2 py-0.5 bg-blue-600 text-white text-xs font-bold rounded-full">
                    Recommended
                  </span>
                </div>
                <p className="text-sm text-gray-700 dark:text-gray-300 mb-2">
                  Optimized for messaging. Great quality with faster upload.
                </p>
                <div className="flex items-center gap-4 text-xs">
                  <span className="text-blue-600 dark:text-blue-400 font-medium">
                    ~{estimatedStandardSize} MB
                  </span>
                  <span className="text-gray-500 dark:text-gray-400">
                    ~70% smaller
                  </span>
                  <span className="text-green-600 dark:text-green-400 font-medium">
                    Fast upload
                  </span>
                </div>
              </div>
            </div>
          </button>

          {/* HD Quality */}
          <button
            onClick={() => onSelect('hd')}
            className="w-full p-4 bg-gradient-to-r from-purple-50 to-purple-100 dark:from-purple-900/20 dark:to-purple-800/20 hover:from-purple-100 hover:to-purple-200 dark:hover:from-purple-900/30 dark:hover:to-purple-800/30 rounded-xl border-2 border-purple-200 dark:border-purple-700 hover:border-purple-400 dark:hover:border-purple-500 transition-all duration-200 text-left group"
          >
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-2">
                  <Sparkles className="w-5 h-5 text-purple-600 dark:text-purple-400" />
                  <h4 className="font-semibold text-gray-900 dark:text-white">HD Quality</h4>
                  <span className="px-2 py-0.5 bg-gradient-to-r from-purple-600 to-purple-700 text-white text-xs font-bold rounded-full">
                    Premium
                  </span>
                </div>
                <p className="text-sm text-gray-700 dark:text-gray-300 mb-2">
                  High-definition quality. Best for important photos.
                </p>
                <div className="flex items-center gap-4 text-xs">
                  <span className="text-purple-600 dark:text-purple-400 font-medium">
                    ~{estimatedHDSize} MB
                  </span>
                  <span className="text-gray-500 dark:text-gray-400">
                    ~40% smaller
                  </span>
                  <span className="text-orange-600 dark:text-orange-400 font-medium">
                    Slower upload
                  </span>
                </div>
              </div>
            </div>
          </button>
        </div>

        {/* Footer Tip */}
        <div className="px-6 pb-6">
          <div className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-700 rounded-lg p-3">
            <p className="text-xs text-yellow-800 dark:text-yellow-200">
              💡 <strong>Tip:</strong> Standard quality is perfect for most photos. HD is best for professional images or when detail matters.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}


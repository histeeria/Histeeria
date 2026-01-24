'use client';

import { useState } from 'react';
import { X, Video, Sparkles, Film } from 'lucide-react';

interface VideoQualityDialogProps {
  isOpen: boolean;
  videoFile: File;
  videoDuration?: number;
  onSelect: (quality: 'standard' | 'hd') => void;
  onCancel: () => void;
}

export function VideoQualityDialog({
  isOpen,
  videoFile,
  videoDuration,
  onSelect,
  onCancel,
}: VideoQualityDialogProps) {
  const [selectedQuality, setSelectedQuality] = useState<'standard' | 'hd'>('standard');

  if (!isOpen) return null;

  const originalSizeMB = (videoFile.size / (1024 * 1024)).toFixed(1);
  
  // Estimate compressed sizes based on typical compression ratios
  const estimateStandardSize = (videoFile.size * 0.3 / (1024 * 1024)).toFixed(1); // ~70% reduction
  const estimateHDSize = (videoFile.size * 0.5 / (1024 * 1024)).toFixed(1); // ~50% reduction

  const formatDuration = (seconds?: number): string => {
    if (!seconds) return 'Unknown';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[200] animate-fade-in"
        onClick={onCancel}
      />

      {/* Dialog */}
      <div className="fixed inset-0 z-[201] flex items-center justify-center p-4 pointer-events-none">
        <div
          className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-md pointer-events-auto animate-scale-in border border-gray-200 dark:border-gray-700"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-purple-100 dark:bg-purple-900/30 rounded-full flex items-center justify-center">
                <Film className="w-5 h-5 text-purple-600 dark:text-purple-400" />
              </div>
              <div>
                <h2 className="text-lg font-semibold text-gray-900 dark:text-white">
                  Video Quality
                </h2>
                <p className="text-xs text-gray-500 dark:text-gray-400">
                  {videoFile.name} • {originalSizeMB} MB • {formatDuration(videoDuration)}
                </p>
              </div>
            </div>
            <button
              onClick={onCancel}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
            >
              <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
            </button>
          </div>

          {/* Content */}
          <div className="p-6 space-y-3">
            {/* Standard Quality Option */}
            <button
              onClick={() => setSelectedQuality('standard')}
              className={`w-full p-4 rounded-xl border-2 transition-all ${
                selectedQuality === 'standard'
                  ? 'border-purple-600 bg-purple-50 dark:bg-purple-900/20'
                  : 'border-gray-200 dark:border-gray-700 hover:border-purple-300 dark:hover:border-purple-700'
              }`}
            >
              <div className="flex items-start gap-3">
                <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
                  selectedQuality === 'standard'
                    ? 'bg-purple-600 text-white'
                    : 'bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
                }`}>
                  <Video className="w-5 h-5" />
                </div>
                <div className="flex-1 text-left">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="font-semibold text-gray-900 dark:text-white">Standard</span>
                    <span className="text-xs px-2 py-0.5 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 rounded-full font-medium">
                      Recommended
                    </span>
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">
                    720p quality • Faster upload
                  </p>
                  <div className="flex items-center gap-2">
                    <div className="flex-1 h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
                      <div className="h-full bg-gradient-to-r from-green-500 to-green-600 rounded-full" style={{ width: '30%' }} />
                    </div>
                    <span className="text-xs font-bold text-green-600 dark:text-green-400">
                      ~{estimateStandardSize} MB
                    </span>
                  </div>
                </div>
              </div>
            </button>

            {/* HD Quality Option */}
            <button
              onClick={() => setSelectedQuality('hd')}
              className={`w-full p-4 rounded-xl border-2 transition-all ${
                selectedQuality === 'hd'
                  ? 'border-purple-600 bg-purple-50 dark:bg-purple-900/20'
                  : 'border-gray-200 dark:border-gray-700 hover:border-purple-300 dark:hover:border-purple-700'
              }`}
            >
              <div className="flex items-start gap-3">
                <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
                  selectedQuality === 'hd'
                    ? 'bg-purple-600 text-white'
                    : 'bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
                }`}>
                  <Sparkles className="w-5 h-5" />
                </div>
                <div className="flex-1 text-left">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="font-semibold text-gray-900 dark:text-white">HD Quality</span>
                    <span className="text-xs px-2 py-0.5 bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-400 rounded-full font-medium">
                      Best
                    </span>
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">
                    1080p quality • Larger file
                  </p>
                  <div className="flex items-center gap-2">
                    <div className="flex-1 h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
                      <div className="h-full bg-gradient-to-r from-purple-500 to-purple-600 rounded-full" style={{ width: '50%' }} />
                    </div>
                    <span className="text-xs font-bold text-purple-600 dark:text-purple-400">
                      ~{estimateHDSize} MB
                    </span>
                  </div>
                </div>
              </div>
            </button>

            {/* Info */}
            <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-3">
              <p className="text-xs text-blue-800 dark:text-blue-300 leading-relaxed">
                <strong>💡 Tip:</strong> Standard quality is perfect for most videos and uploads 70% faster. HD preserves full quality but takes longer to upload.
              </p>
            </div>
          </div>

          {/* Footer */}
          <div className="px-6 py-4 bg-gray-50 dark:bg-gray-800/50 border-t border-gray-200 dark:border-gray-700 flex gap-3">
            <button
              onClick={onCancel}
              className="flex-1 px-4 py-2.5 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 font-medium rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={() => onSelect(selectedQuality)}
              className="flex-1 px-4 py-2.5 bg-gradient-to-r from-purple-600 to-purple-700 hover:from-purple-700 hover:to-purple-800 text-white font-semibold rounded-lg transition-all shadow-md shadow-purple-500/30"
            >
              Send Video
            </button>
          </div>
        </div>
      </div>
    </>
  );
}


'use client';

import { useState } from 'react';
import { Play, X, Music, Waves } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { formatFileSize } from '@/lib/utils/mediaCompression';

export interface MediaItem {
  id: string;
  type: 'image' | 'video' | 'audio';
  url: string;
  thumbnail?: string;
  name?: string;
  size?: number;
  duration?: number;
}

interface MediaGridProps {
  media: MediaItem[];
  onRemove?: (id: string) => void;
  maxColumns?: number;
  className?: string;
}

export default function MediaGrid({ 
  media, 
  onRemove,
  maxColumns = 4,
  className = ''
}: MediaGridProps) {
  const [selectedMedia, setSelectedMedia] = useState<MediaItem | null>(null);

  if (media.length === 0) return null;

  const images = media.filter(m => m.type === 'image');
  const videos = media.filter(m => m.type === 'video');
  const audios = media.filter(m => m.type === 'audio');

  const getGridCols = (count: number) => {
    if (count === 1) return 'grid-cols-1';
    if (count === 2) return 'grid-cols-2';
    if (count === 3) return 'grid-cols-3';
    return `grid-cols-${Math.min(count, maxColumns)}`;
  };

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className={className}>
      {/* Images Grid */}
      {images.length > 0 && (
        <div className={`grid ${getGridCols(images.length)} gap-2 mb-3`}>
          {images.map((item, index) => (
            <motion.div
              key={item.id}
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className="relative group aspect-square rounded-lg overflow-hidden
                bg-neutral-100 dark:bg-neutral-800
                border border-neutral-200 dark:border-neutral-700
                cursor-pointer
              "
              onClick={() => setSelectedMedia(item)}
            >
              <img
                src={item.url}
                alt={item.name || `Image ${index + 1}`}
                className="w-full h-full object-cover"
              />
              
              {/* Overlay */}
              <div className="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-colors" />
              
              {/* Remove Button */}
              {onRemove && (
                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={(e) => {
                    e.stopPropagation();
                    onRemove(item.id);
                  }}
                  className="absolute top-2 right-2 p-1.5 rounded-full
                    bg-red-500/90 hover:bg-red-600
                    text-white opacity-0 group-hover:opacity-100
                    transition-opacity backdrop-blur-sm
                  "
                >
                  <X className="w-4 h-4" />
                </motion.button>
              )}
            </motion.div>
          ))}
        </div>
      )}

      {/* Videos */}
      {videos.length > 0 && (
        <div className="space-y-2 mb-3">
          {videos.map((item) => (
            <motion.div
              key={item.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="relative group rounded-lg overflow-hidden
                bg-neutral-100 dark:bg-neutral-800
                border border-neutral-200 dark:border-neutral-700
                cursor-pointer
              "
              onClick={() => setSelectedMedia(item)}
            >
              <div className="relative aspect-video">
                {item.thumbnail ? (
                  <img
                    src={item.thumbnail}
                    alt={item.name || 'Video'}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center bg-neutral-200 dark:bg-neutral-700">
                    <Play className="w-12 h-12 text-neutral-400" />
                  </div>
                )}
                
                {/* Play Overlay */}
                <div className="absolute inset-0 flex items-center justify-center bg-black/20 group-hover:bg-black/30 transition-colors">
                  <div className="p-3 rounded-full bg-white/90 backdrop-blur-sm">
                    <Play className="w-6 h-6 text-purple-600 fill-current" />
                  </div>
                </div>

                {/* Duration */}
                {item.duration && (
                  <div className="absolute bottom-2 right-2 px-2 py-1 rounded bg-black/70 backdrop-blur-sm">
                    <p className="text-xs text-white font-medium">
                      {formatDuration(item.duration)}
                    </p>
                  </div>
                )}

                {/* Remove Button */}
                {onRemove && (
                  <motion.button
                    whileTap={{ scale: 0.9 }}
                    onClick={(e) => {
                      e.stopPropagation();
                      onRemove(item.id);
                    }}
                    className="absolute top-2 right-2 p-1.5 rounded-full
                      bg-red-500/90 hover:bg-red-600
                      text-white opacity-0 group-hover:opacity-100
                      transition-opacity backdrop-blur-sm
                    "
                  >
                    <X className="w-4 h-4" />
                  </motion.button>
                )}
              </div>
            </motion.div>
          ))}
        </div>
      )}

      {/* Audio Files */}
      {audios.length > 0 && (
        <div className="space-y-2">
          {audios.map((item) => (
            <motion.div
              key={item.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="relative group rounded-lg p-3
                bg-white/70 dark:bg-neutral-800/70
                backdrop-blur-xl
                border border-white/30 dark:border-neutral-700/30
                hover:border-purple-400/50 dark:hover:border-purple-600/50
                transition-all duration-200
              "
            >
              <div className="flex items-center gap-3">
                <div className="flex-shrink-0 w-10 h-10 rounded-lg bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center">
                  <Waves className="w-5 h-5 text-purple-600 dark:text-purple-400" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-neutral-900 dark:text-neutral-50 truncate">
                    {item.name || 'Audio file'}
                  </p>
                  <div className="flex items-center gap-2 mt-0.5">
                    {item.size && (
                      <p className="text-xs text-neutral-500 dark:text-neutral-400">
                        {formatFileSize(item.size)}
                      </p>
                    )}
                    {item.duration && (
                      <>
                        {item.size && <span className="text-xs text-neutral-400">•</span>}
                        <p className="text-xs text-neutral-500 dark:text-neutral-400">
                          {formatDuration(item.duration)}
                        </p>
                      </>
                    )}
                  </div>
                </div>
                {onRemove && (
                  <motion.button
                    whileTap={{ scale: 0.9 }}
                    onClick={() => onRemove(item.id)}
                    className="flex-shrink-0 p-1.5 rounded-full
                      hover:bg-red-50 dark:hover:bg-red-900/20
                      text-red-600 dark:text-red-400
                      transition-colors
                    "
                  >
                    <X className="w-4 h-4" />
                  </motion.button>
                )}
              </div>
            </motion.div>
          ))}
        </div>
      )}

      {/* Media Viewer Modal */}
      <AnimatePresence>
        {selectedMedia && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 backdrop-blur-sm"
            onClick={() => setSelectedMedia(null)}
          >
            <motion.div
              initial={{ scale: 0.9 }}
              animate={{ scale: 1 }}
              exit={{ scale: 0.9 }}
              className="relative max-w-7xl max-h-[90vh] p-4"
              onClick={(e) => e.stopPropagation()}
            >
              {selectedMedia.type === 'image' && (
                <img
                  src={selectedMedia.url}
                  alt={selectedMedia.name || 'Media'}
                  className="max-w-full max-h-[90vh] object-contain rounded-lg"
                />
              )}
              {selectedMedia.type === 'video' && (
                <video
                  src={selectedMedia.url}
                  controls
                  className="max-w-full max-h-[90vh] rounded-lg"
                />
              )}
              {selectedMedia.type === 'audio' && (
                <div className="bg-white dark:bg-neutral-900 rounded-lg p-8 max-w-md">
                  <div className="flex items-center gap-4 mb-4">
                    <div className="w-16 h-16 rounded-lg bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center">
                      <Music className="w-8 h-8 text-purple-600 dark:text-purple-400" />
                    </div>
                    <div>
                      <p className="font-semibold text-neutral-900 dark:text-neutral-50">
                        {selectedMedia.name || 'Audio'}
                      </p>
                      {selectedMedia.size && (
                        <p className="text-sm text-neutral-500 dark:text-neutral-400">
                          {formatFileSize(selectedMedia.size)}
                        </p>
                      )}
                    </div>
                  </div>
                  <audio src={selectedMedia.url} controls className="w-full" />
                </div>
              )}
              <button
                onClick={() => setSelectedMedia(null)}
                className="absolute top-6 right-6 p-2 rounded-full bg-white/10 hover:bg-white/20 backdrop-blur-sm text-white transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}


'use client';

import { useState } from 'react';
import { Image as ImageIcon, Video, Music, X } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import ImageUploader, { type ImageUpload } from './ImageUploader';
import VideoUploader, { type VideoUpload } from './VideoUploader';
import AudioUploader, { type AudioUpload } from './AudioUploader';

export type MediaType = 'image' | 'video' | 'audio';

// Re-export types for convenience
export type { ImageUpload, VideoUpload, AudioUpload };

interface MediaUploaderProps {
  onMediaChange?: (media: {
    images: ImageUpload[];
    videos: VideoUpload[];
    audios: AudioUpload[];
  }) => void;
  maxImages?: number;
  maxVideos?: number;
  maxAudios?: number;
  imageQuality?: 'standard' | 'hd';
  videoQuality?: 'standard' | 'hd';
  audioType?: 'voice' | 'music';
}

export default function MediaUploader({
  onMediaChange,
  maxImages = 10,
  maxVideos = 1,
  maxAudios = 5,
  imageQuality = 'standard',
  videoQuality = 'standard',
  audioType = 'music',
}: MediaUploaderProps) {
  const [activeTab, setActiveTab] = useState<MediaType>('image');
  const [images, setImages] = useState<ImageUpload[]>([]);
  const [videos, setVideos] = useState<VideoUpload[]>([]);
  const [audios, setAudios] = useState<AudioUpload[]>([]);

  const handleImagesChange = (newImages: ImageUpload[]) => {
    setImages(newImages);
    onMediaChange?.({
      images: newImages,
      videos,
      audios,
    });
  };

  const handleVideosChange = (newVideos: VideoUpload[]) => {
    setVideos(newVideos);
    onMediaChange?.({
      images,
      videos: newVideos,
      audios,
    });
  };

  const handleAudiosChange = (newAudios: AudioUpload[]) => {
    setAudios(newAudios);
    onMediaChange?.({
      images,
      videos,
      audios: newAudios,
    });
  };

  const tabs: { id: MediaType; label: string; icon: typeof ImageIcon; count: number }[] = [
    { id: 'image', label: 'Images', icon: ImageIcon, count: images.length },
    { id: 'video', label: 'Videos', icon: Video, count: videos.length },
    { id: 'audio', label: 'Audio', icon: Music, count: audios.length },
  ];

  const hasMedia = images.length > 0 || videos.length > 0 || audios.length > 0;

  return (
    <div className="space-y-4">
      {/* Tabs */}
      <div className="flex gap-2 border-b border-neutral-200 dark:border-neutral-700">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          
          return (
            <motion.button
              key={tab.id}
              whileTap={{ scale: 0.95 }}
              onClick={() => setActiveTab(tab.id)}
              className={`
                relative px-4 py-2 text-sm font-medium
                transition-colors duration-200
                ${isActive
                  ? 'text-purple-600 dark:text-purple-400'
                  : 'text-neutral-500 dark:text-neutral-400 hover:text-neutral-700 dark:hover:text-neutral-300'
                }
              `}
            >
              <div className="flex items-center gap-2">
                <Icon className="w-4 h-4" />
                <span>{tab.label}</span>
                {tab.count > 0 && (
                  <span className={`
                    px-1.5 py-0.5 rounded-full text-xs font-semibold
                    ${isActive
                      ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300'
                      : 'bg-neutral-200 dark:bg-neutral-700 text-neutral-600 dark:text-neutral-400'
                    }
                  `}>
                    {tab.count}
                  </span>
                )}
              </div>
              {isActive && (
                <motion.div
                  layoutId="activeTab"
                  className="absolute bottom-0 left-0 right-0 h-0.5 bg-purple-600 dark:bg-purple-400"
                  initial={false}
                  transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                />
              )}
            </motion.button>
          );
        })}
      </div>

      {/* Content */}
      <AnimatePresence mode="wait">
        <motion.div
          key={activeTab}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -10 }}
          transition={{ duration: 0.2 }}
        >
          {activeTab === 'image' && (
            <ImageUploader
              maxImages={maxImages}
              quality={imageQuality}
              onImagesChange={handleImagesChange}
              existingImages={images}
            />
          )}
          {activeTab === 'video' && (
            <VideoUploader
              maxVideos={maxVideos}
              quality={videoQuality}
              onVideosChange={handleVideosChange}
              existingVideos={videos}
            />
          )}
          {activeTab === 'audio' && (
            <AudioUploader
              maxAudios={maxAudios}
              type={audioType}
              onAudiosChange={handleAudiosChange}
              existingAudios={audios}
            />
          )}
        </motion.div>
      </AnimatePresence>

      {/* Summary */}
      {hasMedia && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          className="p-3 rounded-lg bg-purple-50/50 dark:bg-purple-900/20 border border-purple-200/30 dark:border-purple-800/30"
        >
          <p className="text-xs font-medium text-purple-700 dark:text-purple-300">
            {images.length > 0 && `${images.length} image${images.length !== 1 ? 's' : ''}`}
            {images.length > 0 && (videos.length > 0 || audios.length > 0) && ' • '}
            {videos.length > 0 && `${videos.length} video${videos.length !== 1 ? 's' : ''}`}
            {videos.length > 0 && audios.length > 0 && ' • '}
            {audios.length > 0 && `${audios.length} audio file${audios.length !== 1 ? 's' : ''}`}
          </p>
        </motion.div>
      )}
    </div>
  );
}


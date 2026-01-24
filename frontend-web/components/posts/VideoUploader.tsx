'use client';

import { useState, useRef, useCallback } from 'react';
import { X, Upload, Loader2, Play, Video as VideoIcon } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { compressVideo, validateVideo, generateVideoThumbnail, formatFileSize, type VideoCompressionOptions } from '@/lib/utils/mediaCompression';
import { toast } from '../ui/Toast';

export interface VideoUpload {
  file: File;
  preview?: string;
  thumbnail?: string;
  compressed?: Blob;
  uploading: boolean;
  progress: number;
  error?: string;
  duration?: number;
}

interface VideoUploaderProps {
  maxVideos?: number;
  quality?: 'standard' | 'hd';
  onVideosChange: (videos: VideoUpload[]) => void;
  existingVideos?: VideoUpload[];
}

export default function VideoUploader({
  maxVideos = 1,
  quality = 'standard',
  onVideosChange,
  existingVideos = [],
}: VideoUploaderProps) {
  const [videos, setVideos] = useState<VideoUpload[]>(existingVideos);
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFiles = useCallback(async (files: FileList | File[]) => {
    const fileArray = Array.from(files);
    const remainingSlots = maxVideos - videos.length;
    
    if (fileArray.length > remainingSlots) {
      toast.error(`You can only upload ${remainingSlots} more video${remainingSlots === 1 ? '' : 's'}`);
      return;
    }

    for (const file of fileArray) {
      // Validate
      const validation = validateVideo(file);
      if (!validation.valid) {
        toast.error(validation.error || 'Invalid video file');
        continue;
      }

      // Generate thumbnail
      try {
        const thumbnail = await generateVideoThumbnail(file);
        const preview = URL.createObjectURL(file);
        
        const videoUpload: VideoUpload = {
          file,
          preview,
          thumbnail,
          uploading: false,
          progress: 0,
        };

        const updated = [...videos, videoUpload];
        setVideos(updated);
        onVideosChange(updated);

        // Compress in background
        compressVideo(file, {
          quality,
          onProgress: (p) => {
            setVideos(prev => prev.map(v => 
              v.file === file ? { ...v, progress: p } : v
            ));
          },
        }).then(result => {
          setVideos(prev => prev.map(v => 
            v.file === file 
              ? { ...v, compressed: result.compressedBlob, progress: 100 }
              : v
          ));
        }).catch(error => {
          console.error('Compression failed:', error);
          toast.error('Video compression failed, using original');
        });
      } catch (error) {
        console.error('Failed to process video:', error);
        toast.error('Failed to process video');
      }
    }
  }, [videos, maxVideos, quality, onVideosChange]);

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      handleFiles(e.target.files);
    }
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files) {
      handleFiles(e.dataTransfer.files);
    }
  };

  const removeVideo = (index: number) => {
    const updated = videos.filter((_, i) => i !== index);
    if (videos[index].preview) {
      URL.revokeObjectURL(videos[index].preview);
    }
    setVideos(updated);
    onVideosChange(updated);
  };

  const openFilePicker = () => {
    fileInputRef.current?.click();
  };

  return (
    <div className="space-y-3">
      {/* Upload Area */}
      {videos.length < maxVideos && (
        <div
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          onClick={openFilePicker}
          className={`
            relative border-2 border-dashed rounded-xl p-6
            transition-all duration-200 cursor-pointer
            ${isDragging
              ? 'border-purple-500 bg-purple-50/50 dark:bg-purple-900/20'
              : 'border-neutral-300 dark:border-neutral-700 hover:border-purple-400 dark:hover:border-purple-600 hover:bg-neutral-50 dark:hover:bg-neutral-900'
            }
          `}
        >
          <input
            ref={fileInputRef}
            type="file"
            accept="video/*"
            multiple={maxVideos > 1}
            onChange={handleFileSelect}
            className="hidden"
          />
          <div className="flex flex-col items-center justify-center gap-2">
            <VideoIcon className={`w-8 h-8 ${isDragging ? 'text-purple-600' : 'text-neutral-400'}`} />
            <p className="text-sm font-medium text-neutral-700 dark:text-neutral-300">
              {isDragging ? 'Drop video here' : 'Click or drag to upload video'}
            </p>
            <p className="text-xs text-neutral-500 dark:text-neutral-400">
              Max 100MB per video
            </p>
          </div>
        </div>
      )}

      {/* Video List */}
      {videos.length > 0 && (
        <div className="space-y-3">
          <AnimatePresence>
            {videos.map((video, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -20 }}
                className="relative group rounded-lg overflow-hidden
                  bg-neutral-100 dark:bg-neutral-800
                  border border-neutral-200 dark:border-neutral-700
                "
              >
                <div className="relative aspect-video">
                  {video.thumbnail ? (
                    <img
                      src={video.thumbnail}
                      alt="Video thumbnail"
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center bg-neutral-200 dark:bg-neutral-700">
                      <VideoIcon className="w-12 h-12 text-neutral-400" />
                    </div>
                  )}
                  
                  {/* Play Overlay */}
                  <div className="absolute inset-0 flex items-center justify-center bg-black/20 group-hover:bg-black/30 transition-colors">
                    <div className="p-3 rounded-full bg-white/90 backdrop-blur-sm">
                      <Play className="w-6 h-6 text-purple-600 fill-current" />
                    </div>
                  </div>

                  {/* Remove Button */}
                  <motion.button
                    whileTap={{ scale: 0.9 }}
                    onClick={() => removeVideo(index)}
                    className="absolute top-2 right-2 p-1.5 rounded-full
                      bg-red-500/90 hover:bg-red-600
                      text-white opacity-0 group-hover:opacity-100
                      transition-opacity backdrop-blur-sm
                    "
                  >
                    <X className="w-4 h-4" />
                  </motion.button>

                  {/* Upload Progress */}
                  {video.progress > 0 && video.progress < 100 && (
                    <div className="absolute bottom-0 left-0 right-0 h-1 bg-neutral-700/50">
                      <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${video.progress}%` }}
                        className="h-full bg-purple-600"
                      />
                    </div>
                  )}

                  {/* Compression Status */}
                  {video.compressed && (
                    <div className="absolute top-2 left-2 px-2 py-1 rounded bg-green-500/90 backdrop-blur-sm">
                      <p className="text-xs text-white font-medium">Compressed</p>
                    </div>
                  )}
                </div>

                {/* Video Info */}
                <div className="p-3">
                  <p className="text-sm font-medium text-neutral-900 dark:text-neutral-50 truncate">
                    {video.file.name}
                  </p>
                  <p className="text-xs text-neutral-500 dark:text-neutral-400">
                    {formatFileSize(video.compressed?.size || video.file.size)}
                    {video.duration && ` • ${Math.round(video.duration)}s`}
                  </p>
                </div>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      )}
    </div>
  );
}


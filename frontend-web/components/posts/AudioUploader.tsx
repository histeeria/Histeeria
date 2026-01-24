'use client';

import { useState, useRef, useCallback } from 'react';
import { X, Upload, Loader2, Music, Waves } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { compressAudio, validateAudio, getAudioMetadata, formatFileSize, type AudioCompressionOptions } from '@/lib/utils/mediaCompression';
import { toast } from '../ui/Toast';

export interface AudioUpload {
  file: File;
  preview?: string;
  compressed?: Blob;
  uploading: boolean;
  progress: number;
  error?: string;
  duration?: number;
}

interface AudioUploaderProps {
  maxAudios?: number;
  type?: 'voice' | 'music';
  onAudiosChange: (audios: AudioUpload[]) => void;
  existingAudios?: AudioUpload[];
}

export default function AudioUploader({
  maxAudios = 5,
  type = 'music',
  onAudiosChange,
  existingAudios = [],
}: AudioUploaderProps) {
  const [audios, setAudios] = useState<AudioUpload[]>(existingAudios);
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFiles = useCallback(async (files: FileList | File[]) => {
    const fileArray = Array.from(files);
    const remainingSlots = maxAudios - audios.length;
    
    if (fileArray.length > remainingSlots) {
      toast.error(`You can only upload ${remainingSlots} more audio file${remainingSlots === 1 ? '' : 's'}`);
      return;
    }

    for (const file of fileArray) {
      // Validate
      const validation = validateAudio(file);
      if (!validation.valid) {
        toast.error(validation.error || 'Invalid audio file');
        continue;
      }

      try {
        // Get metadata
        const metadata = await getAudioMetadata(file);
        const preview = URL.createObjectURL(file);
        
        const audioUpload: AudioUpload = {
          file,
          preview,
          uploading: false,
          progress: 0,
          duration: metadata.duration,
        };

        const updated = [...audios, audioUpload];
        setAudios(updated);
        onAudiosChange(updated);

        // Compress in background
        const options: AudioCompressionOptions = {
          bitrate: type === 'voice' ? 128 : 192,
          mono: type === 'voice',
          onProgress: (p) => {
            setAudios(prev => prev.map(a => 
              a.file === file ? { ...a, progress: p } : a
            ));
          },
        };

        compressAudio(file, options).then(result => {
          setAudios(prev => prev.map(a => 
            a.file === file 
              ? { ...a, compressed: result.compressedBlob, progress: 100 }
              : a
          ));
        }).catch(error => {
          console.error('Compression failed:', error);
          toast.error('Audio compression failed, using original');
        });
      } catch (error) {
        console.error('Failed to process audio:', error);
        toast.error('Failed to process audio');
      }
    }
  }, [audios, maxAudios, type, onAudiosChange]);

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

  const removeAudio = (index: number) => {
    const updated = audios.filter((_, i) => i !== index);
    if (audios[index].preview) {
      URL.revokeObjectURL(audios[index].preview);
    }
    setAudios(updated);
    onAudiosChange(updated);
  };

  const openFilePicker = () => {
    fileInputRef.current?.click();
  };

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="space-y-3">
      {/* Upload Area */}
      {audios.length < maxAudios && (
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
            accept="audio/*"
            multiple={maxAudios > 1}
            onChange={handleFileSelect}
            className="hidden"
          />
          <div className="flex flex-col items-center justify-center gap-2">
            <Music className={`w-8 h-8 ${isDragging ? 'text-purple-600' : 'text-neutral-400'}`} />
            <p className="text-sm font-medium text-neutral-700 dark:text-neutral-300">
              {isDragging ? 'Drop audio here' : 'Click or drag to upload audio'}
            </p>
            <p className="text-xs text-neutral-500 dark:text-neutral-400">
              {type === 'voice' ? 'Voice messages' : 'Music files'} • Max 50MB
            </p>
          </div>
        </div>
      )}

      {/* Audio List */}
      {audios.length > 0 && (
        <div className="space-y-2">
          <AnimatePresence>
            {audios.map((audio, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -20 }}
                className="relative group rounded-lg p-4
                  bg-white/70 dark:bg-neutral-800/70
                  backdrop-blur-xl
                  border border-white/30 dark:border-neutral-700/30
                  hover:border-purple-400/50 dark:hover:border-purple-600/50
                  transition-all duration-200
                "
              >
                <div className="flex items-center gap-3">
                  {/* Icon */}
                  <div className="flex-shrink-0 w-12 h-12 rounded-lg bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center">
                    <Waves className="w-6 h-6 text-purple-600 dark:text-purple-400" />
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-neutral-900 dark:text-neutral-50 truncate">
                      {audio.file.name}
                    </p>
                    <div className="flex items-center gap-2 mt-1">
                      <p className="text-xs text-neutral-500 dark:text-neutral-400">
                        {formatFileSize(audio.compressed?.size || audio.file.size)}
                      </p>
                      {audio.duration && (
                        <>
                          <span className="text-xs text-neutral-400">•</span>
                          <p className="text-xs text-neutral-500 dark:text-neutral-400">
                            {formatDuration(audio.duration)}
                          </p>
                        </>
                      )}
                    </div>
                    
                    {/* Progress Bar */}
                    {audio.progress > 0 && audio.progress < 100 && (
                      <div className="mt-2 h-1 bg-neutral-200 dark:bg-neutral-700 rounded-full overflow-hidden">
                        <motion.div
                          initial={{ width: 0 }}
                          animate={{ width: `${audio.progress}%` }}
                          className="h-full bg-purple-600"
                        />
                      </div>
                    )}
                  </div>

                  {/* Remove Button */}
                  <motion.button
                    whileTap={{ scale: 0.9 }}
                    onClick={() => removeAudio(index)}
                    className="flex-shrink-0 p-1.5 rounded-full
                      hover:bg-red-50 dark:hover:bg-red-900/20
                      text-red-600 dark:text-red-400
                      transition-colors
                    "
                  >
                    <X className="w-4 h-4" />
                  </motion.button>
                </div>

                {/* Compression Status */}
                {audio.compressed && (
                  <div className="absolute top-2 right-12 px-2 py-0.5 rounded bg-green-500/90 backdrop-blur-sm">
                    <p className="text-xs text-white font-medium">Compressed</p>
                  </div>
                )}
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      )}
    </div>
  );
}


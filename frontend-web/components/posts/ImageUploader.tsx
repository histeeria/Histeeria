'use client';

import { useState, useRef, useCallback } from 'react';
import { X, Upload, Loader2, Check } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { compressImage, validateImage, formatFileSize, type ImageQuality } from '@/lib/utils/mediaCompression';
import { toast } from '../ui/Toast';

export interface ImageUpload {
  file: File;
  preview: string;
  compressed?: File;
  uploading: boolean;
  progress: number;
  error?: string;
}

interface ImageUploaderProps {
  maxImages?: number;
  quality?: ImageQuality;
  onImagesChange: (images: ImageUpload[]) => void;
  existingImages?: ImageUpload[];
}

export default function ImageUploader({
  maxImages = 10,
  quality = 'standard',
  onImagesChange,
  existingImages = [],
}: ImageUploaderProps) {
  const [images, setImages] = useState<ImageUpload[]>(existingImages);
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFiles = useCallback(async (files: FileList | File[]) => {
    const fileArray = Array.from(files);
    const remainingSlots = maxImages - images.length;
    
    if (fileArray.length > remainingSlots) {
      toast.error(`You can only upload ${remainingSlots} more image${remainingSlots === 1 ? '' : 's'}`);
      return;
    }

    const newImages: ImageUpload[] = [];

    for (const file of fileArray) {
      // Validate
      const validation = validateImage(file);
      if (!validation.valid) {
        toast.error(validation.error || 'Invalid image file');
        continue;
      }

      // Create preview
      const preview = URL.createObjectURL(file);
      const imageUpload: ImageUpload = {
        file,
        preview,
        uploading: false,
        progress: 0,
      };

      newImages.push(imageUpload);
    }

    const updatedImages = [...images, ...newImages];
    setImages(updatedImages);
    onImagesChange(updatedImages);

    // Compress images in background
    newImages.forEach(async (imageUpload, index) => {
      try {
        const compressed = await compressImage(imageUpload.file, quality);
        setImages(prev => prev.map((img, i) => {
          const actualIndex = images.length + index;
          if (i === actualIndex) {
            return { ...img, compressed };
          }
          return img;
        }));
      } catch (error) {
        console.error('Compression failed:', error);
        // Keep original if compression fails
      }
    });
  }, [images, maxImages, quality, onImagesChange]);

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

  const removeImage = (index: number) => {
    const updated = images.filter((_, i) => i !== index);
    // Revoke preview URL
    URL.revokeObjectURL(images[index].preview);
    setImages(updated);
    onImagesChange(updated);
  };

  const openFilePicker = () => {
    fileInputRef.current?.click();
  };

  return (
    <div className="space-y-3">
      {/* Upload Area */}
      {images.length < maxImages && (
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
            accept="image/*"
            multiple
            onChange={handleFileSelect}
            className="hidden"
          />
          <div className="flex flex-col items-center justify-center gap-2">
            <Upload className={`w-8 h-8 ${isDragging ? 'text-purple-600' : 'text-neutral-400'}`} />
            <p className="text-sm font-medium text-neutral-700 dark:text-neutral-300">
              {isDragging ? 'Drop images here' : 'Click or drag to upload images'}
            </p>
            <p className="text-xs text-neutral-500 dark:text-neutral-400">
              Up to {maxImages - images.length} more image{maxImages - images.length !== 1 ? 's' : ''}
            </p>
          </div>
        </div>
      )}

      {/* Image Grid */}
      {images.length > 0 && (
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
          <AnimatePresence>
            {images.map((image, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.9 }}
                className="relative group aspect-square rounded-lg overflow-hidden
                  bg-neutral-100 dark:bg-neutral-800
                  border border-neutral-200 dark:border-neutral-700
                "
              >
                <img
                  src={image.preview}
                  alt={`Upload ${index + 1}`}
                  className="w-full h-full object-cover"
                />
                
                {/* Overlay */}
                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors" />
                
                {/* Remove Button */}
                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={(e) => {
                    e.stopPropagation();
                    removeImage(index);
                  }}
                  className="absolute top-2 right-2 p-1.5 rounded-full
                    bg-red-500/90 hover:bg-red-600
                    text-white opacity-0 group-hover:opacity-100
                    transition-opacity backdrop-blur-sm
                  "
                >
                  <X className="w-4 h-4" />
                </motion.button>

                {/* File Info */}
                <div className="absolute bottom-0 left-0 right-0 p-2 bg-gradient-to-t from-black/60 to-transparent
                  opacity-0 group-hover:opacity-100 transition-opacity
                ">
                  <p className="text-xs text-white truncate">
                    {formatFileSize(image.compressed?.size || image.file.size)}
                  </p>
                </div>

                {/* Upload Progress */}
                {image.uploading && (
                  <div className="absolute inset-0 flex items-center justify-center bg-black/50 backdrop-blur-sm">
                    <div className="text-center">
                      <Loader2 className="w-6 h-6 animate-spin text-white mx-auto mb-2" />
                      <p className="text-xs text-white">{image.progress}%</p>
                    </div>
                  </div>
                )}

                {/* Success Indicator */}
                {image.compressed && !image.uploading && (
                  <div className="absolute top-2 left-2 p-1 rounded-full bg-green-500/90 backdrop-blur-sm">
                    <Check className="w-3 h-3 text-white" />
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


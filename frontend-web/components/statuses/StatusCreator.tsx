'use client';

/**
 * Status Creator Component
 * Beautiful UI for creating text, image, and video statuses
 * Created by: Hamza Hafeez - Founder & CEO of Histeeria
 */

import { useState, useRef, useEffect } from 'react';
import { X, Image as ImageIcon, Video, Type, Loader2, Check, Camera, Upload } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { cn } from '@/lib/utils';
import { createStatus, uploadStatusImage, uploadStatusVideo, type CreateStatusRequest } from '@/lib/api/statuses';
import { useUser } from '@/lib/hooks/useUser';
import { toast } from '@/components/ui/Toast';

interface StatusCreatorProps {
  isOpen: boolean;
  onClose: () => void;
  onStatusCreated?: () => void;
}

type StatusType = 'text' | 'image' | 'video';

const BACKGROUND_COLORS = [
  '#1a1f3a', '#2d3561', '#4c63d2', '#6c5ce7', '#a29bfe',
  '#fd79a8', '#fdcb6e', '#e17055', '#d63031', '#00b894',
  '#00cec9', '#0984e3', '#74b9ff', '#55efc4', '#ffeaa7',
];

export function StatusCreator({ isOpen, onClose, onStatusCreated }: StatusCreatorProps) {
  const { user } = useUser();
  const [statusType, setStatusType] = useState<StatusType>('text');
  const [content, setContent] = useState('');
  const [backgroundColor, setBackgroundColor] = useState('#1a1f3a');
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [selectedVideo, setSelectedVideo] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [videoPreview, setVideoPreview] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);

  const imageInputRef = useRef<HTMLInputElement>(null);
  const videoInputRef = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (isOpen && statusType === 'text' && textareaRef.current) {
      textareaRef.current.focus();
    }
  }, [isOpen, statusType]);

  useEffect(() => {
    if (!isOpen) {
      // Reset form when closed
      setStatusType('text');
      setContent('');
      setBackgroundColor('#1a1f3a');
      setSelectedImage(null);
      setSelectedVideo(null);
      setImagePreview(null);
      setVideoPreview(null);
      setUploadProgress(0);
    }
  }, [isOpen]);

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      toast.error('Please select an image file');
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      toast.error('Image size must be less than 10MB');
      return;
    }

    setSelectedImage(file);
    setSelectedVideo(null);
    setVideoPreview(null);
    
    const reader = new FileReader();
    reader.onloadend = () => {
      setImagePreview(reader.result as string);
    };
    reader.readAsDataURL(file);
  };

  const handleVideoSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('video/')) {
      toast.error('Please select a video file');
      return;
    }

    if (file.size > 100 * 1024 * 1024) {
      toast.error('Video size must be less than 100MB');
      return;
    }

    setSelectedVideo(file);
    setSelectedImage(null);
    setImagePreview(null);
    
    const reader = new FileReader();
    reader.onloadend = () => {
      setVideoPreview(reader.result as string);
    };
    reader.readAsDataURL(file);
  };

  const handleSubmit = async () => {
    if (statusType === 'text' && !content.trim()) {
      toast.error('Please enter some text');
      return;
    }

    if (statusType === 'image' && !selectedImage) {
      toast.error('Please select an image');
      return;
    }

    if (statusType === 'video' && !selectedVideo) {
      toast.error('Please select a video');
      return;
    }

    setIsSubmitting(true);
    setUploadProgress(0);

    try {
      let mediaURL: string | undefined;
      let mediaType: string | undefined;

      // Upload media if needed
      if (statusType === 'image' && selectedImage) {
        setUploadProgress(30);
        const result = await uploadStatusImage(selectedImage, 'standard');
        mediaURL = result.media_url;
        mediaType = result.media_type;
        setUploadProgress(60);
      } else if (statusType === 'video' && selectedVideo) {
        setUploadProgress(20);
        const result = await uploadStatusVideo(selectedVideo);
        mediaURL = result.media_url;
        mediaType = result.media_type;
        setUploadProgress(60);
      }

      // Create status
      setUploadProgress(80);
      const request: CreateStatusRequest = {
        status_type: statusType,
        content: statusType === 'text' ? content : undefined,
        media_url: mediaURL,
        media_type: mediaType,
        background_color: statusType === 'text' ? backgroundColor : undefined,
      };

      await createStatus(request);
      setUploadProgress(100);

      toast.success('Status created successfully!');
      
      if (onStatusCreated) {
        onStatusCreated();
      }
      
      onClose();
    } catch (error: any) {
      console.error('Failed to create status:', error);
      toast.error(error.message || 'Failed to create status');
    } finally {
      setIsSubmitting(false);
      setUploadProgress(0);
    }
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[400] flex items-center justify-center p-4">
        {/* Backdrop */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="absolute inset-0 bg-black/80 backdrop-blur-sm"
          onClick={onClose}
        />

        {/* Modal */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 20 }}
          className="relative bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-hidden flex flex-col border border-gray-200 dark:border-gray-800"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-800">
            <h2 className="text-xl font-bold text-gray-900 dark:text-white">Create Status</h2>
            <button
              onClick={onClose}
              disabled={isSubmitting}
              className="p-2 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors disabled:opacity-50"
            >
              <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
            </button>
          </div>

          {/* Type Selector */}
          <div className="flex gap-2 p-4 border-b border-gray-200 dark:border-gray-800">
            <button
              onClick={() => {
                setStatusType('text');
                setSelectedImage(null);
                setSelectedVideo(null);
                setImagePreview(null);
                setVideoPreview(null);
              }}
              className={cn(
                "flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-xl transition-all",
                statusType === 'text'
                  ? "bg-brand-purple-600 text-white shadow-md"
                  : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
              )}
            >
              <Type className="w-5 h-5" />
              <span className="font-medium">Text</span>
            </button>
            <button
              onClick={() => {
                setStatusType('image');
                setContent('');
                setSelectedVideo(null);
                setVideoPreview(null);
                imageInputRef.current?.click();
              }}
              className={cn(
                "flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-xl transition-all",
                statusType === 'image'
                  ? "bg-brand-purple-600 text-white shadow-md"
                  : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
              )}
            >
              <ImageIcon className="w-5 h-5" />
              <span className="font-medium">Image</span>
            </button>
            <button
              onClick={() => {
                setStatusType('video');
                setContent('');
                setSelectedImage(null);
                setImagePreview(null);
                videoInputRef.current?.click();
              }}
              className={cn(
                "flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-xl transition-all",
                statusType === 'video'
                  ? "bg-brand-purple-600 text-white shadow-md"
                  : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
              )}
            >
              <Video className="w-5 h-5" />
              <span className="font-medium">Video</span>
            </button>
          </div>

          {/* Hidden Inputs */}
          <input
            ref={imageInputRef}
            type="file"
            accept="image/*"
            onChange={handleImageSelect}
            className="hidden"
          />
          <input
            ref={videoInputRef}
            type="file"
            accept="video/*"
            onChange={handleVideoSelect}
            className="hidden"
          />

          {/* Content Area */}
          <div className="flex-1 overflow-y-auto p-6">
            {statusType === 'text' ? (
              <div className="space-y-4">
                {/* Background Color Picker */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Background Color
                  </label>
                  <div className="flex flex-wrap gap-2">
                    {BACKGROUND_COLORS.map((color) => (
                      <button
                        key={color}
                        onClick={() => setBackgroundColor(color)}
                        className={cn(
                          "w-10 h-10 rounded-full border-2 transition-all hover:scale-110",
                          backgroundColor === color
                            ? "border-brand-purple-600 ring-2 ring-brand-purple-400 ring-offset-2"
                            : "border-gray-300 dark:border-gray-700"
                        )}
                        style={{ backgroundColor: color }}
                      >
                        {backgroundColor === color && (
                          <Check className="w-5 h-5 text-white mx-auto" />
                        )}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Preview */}
                <div
                  className="min-h-[300px] rounded-xl p-8 flex items-center justify-center border-2 border-gray-200 dark:border-gray-800"
                  style={{ backgroundColor }}
                >
                  <textarea
                    ref={textareaRef}
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    placeholder="What's on your mind?"
                    className="w-full bg-transparent text-white text-xl md:text-2xl font-semibold placeholder-white/70 focus:outline-none resize-none text-center"
                    maxLength={500}
                    rows={5}
                  />
                </div>

                {/* Character Count */}
                <p className="text-sm text-gray-500 dark:text-gray-400 text-right">
                  {content.length}/500
                </p>
              </div>
            ) : statusType === 'image' ? (
              <div className="space-y-4">
                {imagePreview ? (
                  <div className="relative">
                    <img
                      src={imagePreview}
                      alt="Preview"
                      className="w-full max-h-[400px] object-contain rounded-xl border-2 border-gray-200 dark:border-gray-800"
                    />
                    <button
                      onClick={() => {
                        setSelectedImage(null);
                        setImagePreview(null);
                        imageInputRef.current?.click();
                      }}
                      className="absolute top-2 right-2 p-2 bg-black/50 hover:bg-black/70 rounded-full transition-colors"
                    >
                      <Camera className="w-5 h-5 text-white" />
                    </button>
                  </div>
                ) : (
                  <div
                    onClick={() => imageInputRef.current?.click()}
                    className="min-h-[400px] border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-xl flex flex-col items-center justify-center gap-4 cursor-pointer hover:border-brand-purple-500 transition-colors"
                  >
                    <Upload className="w-12 h-12 text-gray-400 dark:text-gray-600" />
                    <p className="text-gray-500 dark:text-gray-400 font-medium">
                      Click to upload image
                    </p>
                    <p className="text-sm text-gray-400 dark:text-gray-500">
                      Max size: 10MB
                    </p>
                  </div>
                )}

                {/* Caption (optional for image) */}
                <textarea
                  value={content}
                  onChange={(e) => setContent(e.target.value)}
                  placeholder="Add a caption (optional)"
                  className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl focus:outline-none focus:ring-2 focus:ring-brand-purple-500 resize-none"
                  maxLength={500}
                  rows={3}
                />
              </div>
            ) : (
              <div className="space-y-4">
                {videoPreview ? (
                  <div className="relative">
                    <video
                      src={videoPreview}
                      controls
                      className="w-full max-h-[400px] rounded-xl border-2 border-gray-200 dark:border-gray-800"
                    />
                    <button
                      onClick={() => {
                        setSelectedVideo(null);
                        setVideoPreview(null);
                        videoInputRef.current?.click();
                      }}
                      className="absolute top-2 right-2 p-2 bg-black/50 hover:bg-black/70 rounded-full transition-colors"
                    >
                      <Camera className="w-5 h-5 text-white" />
                    </button>
                  </div>
                ) : (
                  <div
                    onClick={() => videoInputRef.current?.click()}
                    className="min-h-[400px] border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-xl flex flex-col items-center justify-center gap-4 cursor-pointer hover:border-brand-purple-500 transition-colors"
                  >
                    <Video className="w-12 h-12 text-gray-400 dark:text-gray-600" />
                    <p className="text-gray-500 dark:text-gray-400 font-medium">
                      Click to upload video
                    </p>
                    <p className="text-sm text-gray-400 dark:text-gray-500">
                      Max size: 100MB
                    </p>
                  </div>
                )}

                {/* Caption (optional for video) */}
                <textarea
                  value={content}
                  onChange={(e) => setContent(e.target.value)}
                  placeholder="Add a caption (optional)"
                  className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl focus:outline-none focus:ring-2 focus:ring-brand-purple-500 resize-none"
                  maxLength={500}
                  rows={3}
                />
              </div>
            )}

            {/* Upload Progress */}
            {isSubmitting && uploadProgress > 0 && (
              <div className="mt-4">
                <div className="h-2 bg-gray-200 dark:bg-gray-800 rounded-full overflow-hidden">
                  <motion.div
                    className="h-full bg-brand-purple-600"
                    initial={{ width: 0 }}
                    animate={{ width: `${uploadProgress}%` }}
                    transition={{ duration: 0.3 }}
                  />
                </div>
                <p className="text-sm text-gray-500 dark:text-gray-400 mt-2 text-center">
                  {uploadProgress < 60 ? 'Uploading...' : 'Creating status...'}
                </p>
              </div>
            )}
          </div>

          {/* Footer */}
          <div className="p-4 border-t border-gray-200 dark:border-gray-800 flex gap-3">
            <button
              onClick={onClose}
              disabled={isSubmitting}
              className="px-6 py-2.5 bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 rounded-xl font-medium hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              disabled={
                isSubmitting ||
                (statusType === 'text' && !content.trim()) ||
                (statusType === 'image' && !selectedImage) ||
                (statusType === 'video' && !selectedVideo)
              }
              className="flex-1 px-6 py-2.5 bg-brand-purple-600 text-white rounded-xl font-medium hover:bg-brand-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin" />
                  <span>Creating...</span>
                </>
              ) : (
                <>
                  <Check className="w-5 h-5" />
                  <span>Create Status</span>
                </>
              )}
            </button>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}

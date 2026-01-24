'use client';

/**
 * Profile Picture Editor Component - iOS Inspired
 * Clean, minimal image cropper with auto-compression
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 */

import { useState, useCallback } from 'react';
import Cropper from 'react-easy-crop';
import { X, Upload, ZoomIn, ZoomOut, Maximize2 } from 'lucide-react';
import { Button } from '../ui/Button';
import { compressProfileImage, validateImageFile } from '@/lib/utils/imageCompression';

interface ProfilePictureEditorProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (file: File) => Promise<void>;
  currentImageUrl?: string | null;
}

interface CroppedArea {
  x: number;
  y: number;
  width: number;
  height: number;
}

export default function ProfilePictureEditor({
  isOpen,
  onClose,
  currentImageUrl,
  onSave,
}: ProfilePictureEditorProps) {
  const [imageSrc, setImageSrc] = useState<string | null>(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<CroppedArea | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [originalFile, setOriginalFile] = useState<File | null>(null);
  const [cropShape, setCropShape] = useState<'round' | 'rect'>('round');

  const onCropComplete = useCallback((croppedArea: any, croppedAreaPixels: CroppedArea) => {
    setCroppedAreaPixels(croppedAreaPixels);
  }, []);

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const validation = validateImageFile(file);
    if (!validation.valid) {
      setError(validation.error || 'Invalid file');
      return;
    }

    setOriginalFile(file);
    setError(null);

    const reader = new FileReader();
    reader.onload = () => {
      setImageSrc(reader.result as string);
    };
    reader.readAsDataURL(file);
  };

  const createImage = (url: string): Promise<HTMLImageElement> =>
    new Promise((resolve, reject) => {
      const image = new Image();
      image.addEventListener('load', () => resolve(image));
      image.addEventListener('error', (error) => reject(error));
      image.src = url;
    });

  const getCroppedImg = async (
    imageSrc: string,
    pixelCrop: CroppedArea
  ): Promise<Blob> => {
    const image = await createImage(imageSrc);
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');

    if (!ctx) {
      throw new Error('No 2d context');
    }

    canvas.width = pixelCrop.width;
    canvas.height = pixelCrop.height;

    ctx.drawImage(
      image,
      pixelCrop.x,
      pixelCrop.y,
      pixelCrop.width,
      pixelCrop.height,
      0,
      0,
      pixelCrop.width,
      pixelCrop.height
    );

    return new Promise((resolve) => {
      canvas.toBlob((blob) => {
        if (blob) resolve(blob);
      }, 'image/jpeg');
    });
  };

  const handleSave = async () => {
    if (!imageSrc || !croppedAreaPixels) {
      setError('Please select an image');
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      // Get cropped image
      const croppedBlob = await getCroppedImg(imageSrc, croppedAreaPixels);
      const croppedFile = new File([croppedBlob], originalFile?.name || 'profile.jpg', {
        type: 'image/jpeg',
      });

      // Compress the cropped image
      const compressed = await compressProfileImage(croppedFile);

      // Upload
      await onSave(compressed);

      // Close modal
      handleClose();
    } catch (err: any) {
      console.error('Failed to save:', err);
      setError(err.message || 'Failed to save image');
    } finally {
      setIsSaving(false);
    }
  };

  const handleClose = () => {
    setImageSrc(null);
    setCrop({ x: 0, y: 0 });
    setZoom(1);
    setCroppedAreaPixels(null);
    setError(null);
    setOriginalFile(null);
    onClose();
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-neutral-900 rounded-2xl shadow-2xl w-full max-w-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-neutral-200 dark:border-neutral-800">
          <div>
            <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50">
              {imageSrc ? 'Adjust Your Photo' : 'Upload Profile Picture'}
            </h3>
            <p className="text-sm text-neutral-600 dark:text-neutral-400 mt-1">
              {imageSrc ? 'Drag to reposition, scroll to zoom' : 'Choose a photo to get started'}
            </p>
          </div>
          <button
            onClick={handleClose}
            className="text-neutral-500 hover:text-neutral-700 dark:hover:text-neutral-300 cursor-pointer transition-colors"
            disabled={isSaving}
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Error Message */}
        {error && (
          <div className="mx-6 mt-4 p-3 bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-200 rounded-lg text-sm">
            {error}
          </div>
        )}

        {/* Content */}
        <div className="flex-1 overflow-hidden">
          {!imageSrc ? (
            /* Upload Area */
            <div className="flex flex-col items-center justify-center h-full p-12">
              <div className="w-32 h-32 rounded-full bg-gradient-to-br from-brand-purple-100 to-brand-purple-200 dark:from-brand-purple-900/20 dark:to-brand-purple-800/20 flex items-center justify-center mb-6">
                <Upload className="w-16 h-16 text-brand-purple-600 dark:text-brand-purple-400" />
              </div>
              <h4 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
                Choose Your Best Photo
              </h4>
              <p className="text-neutral-600 dark:text-neutral-400 mb-6 text-center max-w-sm">
                Upload a high-quality photo (up to 5 MB). We'll help you crop it perfectly.
              </p>
              <input
                type="file"
                accept="image/*"
                onChange={handleFileSelect}
                className="hidden"
                id="file-upload"
              />
              <label htmlFor="file-upload">
                <Button variant="primary" onClick={() => document.getElementById('file-upload')?.click()}>
                  <Upload className="w-5 h-5 mr-2" />
                  Choose Photo
                </Button>
              </label>
              <p className="text-xs text-neutral-500 dark:text-neutral-400 mt-4">
                Supported: JPEG, PNG, WebP, GIF
              </p>
            </div>
          ) : (
            /* Cropper Area */
            <div className="relative h-full">
              {/* Crop Area */}
              <div className="relative h-[280px] md:h-[400px] bg-neutral-900">
                <Cropper
                  image={imageSrc}
                  crop={crop}
                  zoom={zoom}
                  aspect={1}
                  cropShape={cropShape}
                  showGrid={false}
                  onCropChange={setCrop}
                  onZoomChange={setZoom}
                  onCropComplete={onCropComplete}
                  style={{
                    containerStyle: {
                      backgroundColor: '#171717',
                    },
                    cropAreaStyle: {
                      border: '2px solid #fff',
                      boxShadow: '0 0 0 9999px rgba(0, 0, 0, 0.5)',
                    },
                  }}
                />
              </div>

              {/* Controls */}
              <div className="p-4 md:p-6 space-y-3 md:space-y-4 bg-white dark:bg-neutral-900 border-t border-neutral-200 dark:border-neutral-800">
                {/* Zoom Control */}
                <div className="flex items-center gap-3 md:gap-4">
                  <ZoomOut className="w-4 md:w-5 h-4 md:h-5 text-neutral-400" />
                  <input
                    type="range"
                    min={1}
                    max={3}
                    step={0.1}
                    value={zoom}
                    onChange={(e) => setZoom(Number(e.target.value))}
                    className="flex-1 h-2 bg-neutral-200 dark:bg-neutral-700 rounded-lg appearance-none cursor-pointer
                      [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4 
                      [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-brand-purple-600 
                      [&::-webkit-slider-thumb]:cursor-pointer [&::-webkit-slider-thumb]:shadow-md
                      [&::-moz-range-thumb]:w-4 [&::-moz-range-thumb]:h-4 [&::-moz-range-thumb]:rounded-full 
                      [&::-moz-range-thumb]:bg-brand-purple-600 [&::-moz-range-thumb]:cursor-pointer 
                      [&::-moz-range-thumb]:border-0 [&::-moz-range-thumb]:shadow-md"
                  />
                  <ZoomIn className="w-4 md:w-5 h-4 md:h-5 text-neutral-400" />
                </div>

                {/* Crop Shape Toggle - Mobile Only */}
                <div className="flex items-center justify-center gap-2 md:hidden">
                  <button
                    onClick={() => setCropShape('round')}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all cursor-pointer ${
                      cropShape === 'round'
                        ? 'bg-brand-purple-600 text-white shadow-md'
                        : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
                    }`}
                  >
                    Circle
                  </button>
                  <button
                    onClick={() => setCropShape('rect')}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all cursor-pointer ${
                      cropShape === 'rect'
                        ? 'bg-brand-purple-600 text-white shadow-md'
                        : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
                    }`}
                  >
                    <Maximize2 className="w-3 h-3 inline mr-1" />
                    Square
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex flex-col items-stretch gap-2 p-4 border-t border-neutral-200 dark:border-neutral-800 bg-neutral-50 dark:bg-neutral-900/50">
          <div className="flex gap-2">
            <Button 
              variant="secondary" 
              onClick={handleClose} 
              disabled={isSaving}
              className="flex-1 text-xs py-2 px-3"
            >
              Cancel
            </Button>
            {imageSrc && (
              <Button 
                variant="primary" 
                onClick={handleSave} 
                isLoading={isSaving}
                className="flex-1 text-xs py-2 px-3"
              >
                Save
              </Button>
            )}
          </div>
          {imageSrc && (
            <button
              onClick={() => {
                setImageSrc(null);
                setOriginalFile(null);
              }}
              className="text-xs font-medium text-neutral-600 dark:text-neutral-400 hover:text-brand-purple-600 dark:hover:text-brand-purple-400 transition-colors cursor-pointer text-center py-1"
              disabled={isSaving}
            >
              Choose Different Photo
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

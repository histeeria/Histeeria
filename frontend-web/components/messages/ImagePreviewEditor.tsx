'use client';

import { useState, useRef, useEffect } from 'react';
import { X, Send, RotateCw, Crop, Type, Pen, Sparkles, Image as ImageIcon } from 'lucide-react';
import { toast } from '../ui/Toast';

interface ImagePreviewEditorProps {
  isOpen: boolean;
  file: File;
  onSend: (editedFile: File, caption: string, isHD: boolean) => void;
  onCancel: () => void;
}

export function ImagePreviewEditor({
  isOpen,
  file,
  onSend,
  onCancel,
}: ImagePreviewEditorProps) {
  const [imageUrl, setImageUrl] = useState<string>('');
  const [caption, setCaption] = useState('');
  const [isHD, setIsHD] = useState(false);
  const [rotation, setRotation] = useState(0);
  const [editMode, setEditMode] = useState<'none' | 'text' | 'draw' | 'crop'>('none');
  const [isSending, setIsSending] = useState(false);
  
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const imageRef = useRef<HTMLImageElement>(null);
  const textInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen && file) {
      const url = URL.createObjectURL(file);
      setImageUrl(url);

      return () => {
        URL.revokeObjectURL(url);
      };
    }
  }, [isOpen, file]);

  const handleRotate = () => {
    setRotation((prev) => (prev + 90) % 360);
  };

  const handleToggleHD = () => {
    setIsHD((prev) => !prev);
    toast.success(isHD ? 'HD disabled' : 'HD enabled - Best quality!');
  };

  const handleSend = async () => {
    setIsSending(true);
    
    try {
      // If image was rotated, create new file with rotation applied
      if (rotation !== 0) {
        const rotatedFile = await applyRotation(file, rotation);
        onSend(rotatedFile, caption, isHD);
      } else {
        onSend(file, caption, isHD);
      }
    } catch (error) {
      console.error('Failed to process image:', error);
      toast.error('Failed to process image');
      setIsSending(false);
    }
  };

  const applyRotation = async (originalFile: File, degrees: number): Promise<File> => {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        if (!ctx) {
          reject(new Error('Could not get canvas context'));
          return;
        }

        // Set canvas size based on rotation
        if (degrees === 90 || degrees === 270) {
          canvas.width = img.height;
          canvas.height = img.width;
        } else {
          canvas.width = img.width;
          canvas.height = img.height;
        }

        // Apply rotation
        ctx.translate(canvas.width / 2, canvas.height / 2);
        ctx.rotate((degrees * Math.PI) / 180);
        ctx.drawImage(img, -img.width / 2, -img.height / 2);

        // Convert to blob
        canvas.toBlob((blob) => {
          if (blob) {
            const rotatedFile = new File([blob], originalFile.name, {
              type: originalFile.type,
              lastModified: Date.now(),
            });
            resolve(rotatedFile);
          } else {
            reject(new Error('Failed to create blob'));
          }
        }, originalFile.type, 1.0);

        URL.revokeObjectURL(img.src);
      };

      img.onerror = () => reject(new Error('Failed to load image'));
      img.src = URL.createObjectURL(originalFile);
    });
  };

  if (!isOpen) return null;

  return (
    <>
      {/* Backdrop Overlay */}
      <div 
        className="fixed inset-0 bg-black/80 backdrop-blur-sm z-[200] animate-fade-in"
        onClick={onCancel}
      />

      {/* Modal Dialog */}
      <div className="fixed inset-0 z-[201] flex items-center justify-center p-2 sm:p-4 pointer-events-none">
        <div 
          className="
            bg-gray-900 rounded-2xl shadow-2xl
            w-full max-w-[95vw] sm:max-w-[85vw] md:max-w-3xl lg:max-w-4xl
            max-h-[95vh] sm:max-h-[90vh]
            flex flex-col
            pointer-events-auto
            animate-scale-in
            border border-gray-800
          "
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="bg-gray-800/50 backdrop-blur-sm px-3 sm:px-4 py-2.5 sm:py-3 flex items-center justify-between border-b border-gray-700 rounded-t-2xl">
            <button
              onClick={onCancel}
              className="p-1.5 sm:p-2 hover:bg-white/10 rounded-full transition-colors"
              disabled={isSending}
            >
              <X className="w-5 h-5 sm:w-6 sm:h-6 text-white" />
            </button>

            <h2 className="text-white font-semibold text-sm sm:text-base md:text-lg">Edit Photo</h2>

            <div className="w-8 sm:w-10" /> {/* Spacer for center alignment */}
          </div>

          {/* Image Preview Area */}
          <div className="flex-1 flex items-center justify-center p-2 sm:p-4 overflow-hidden bg-gray-950/50">
            <div className="relative max-w-full max-h-full">
              <img
                ref={imageRef}
                src={imageUrl}
                alt="Preview"
                className="max-w-full max-h-[40vh] sm:max-h-[50vh] md:max-h-[55vh] object-contain rounded-lg shadow-2xl transition-transform duration-300"
                style={{
                  transform: `rotate(${rotation}deg)`,
                }}
              />
            </div>
          </div>

          {/* Caption Input */}
          <div className="px-3 sm:px-4 py-2 sm:py-3 bg-gray-900/50">
            <input
              ref={textInputRef}
              type="text"
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
              placeholder="Add a caption..."
              className="w-full px-3 sm:px-4 py-2 sm:py-3 bg-gray-800 border border-gray-700 rounded-full text-sm sm:text-base text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              disabled={isSending}
            />
          </div>

          {/* Toolbar */}
          <div className="bg-gray-800/50 backdrop-blur-sm px-2 sm:px-4 py-2.5 sm:py-3 border-t border-gray-700 rounded-b-2xl">
            {/* Mobile Layout (Stacked) */}
            <div className="flex flex-col gap-3 sm:hidden">
              {/* Row 1: Edit Tools + HD Toggle */}
              <div className="flex items-center justify-between">
                {/* Edit Tools */}
                <div className="flex items-center gap-1">
                  <button
                    onClick={handleRotate}
                    className="p-2 hover:bg-white/10 rounded-full transition-colors"
                    title="Rotate"
                    disabled={isSending}
                  >
                    <RotateCw className="w-4 h-4 text-white" />
                  </button>

                  <button
                    onClick={() => toast.info('Crop feature coming soon!')}
                    className="p-2 hover:bg-white/10 rounded-full transition-colors opacity-50"
                    title="Crop"
                    disabled={isSending}
                  >
                    <Crop className="w-4 h-4 text-white" />
                  </button>

                  <button
                    onClick={() => toast.info('Text feature coming soon!')}
                    className="p-2 hover:bg-white/10 rounded-full transition-colors opacity-50"
                    title="Add text"
                    disabled={isSending}
                  >
                    <Type className="w-4 h-4 text-white" />
                  </button>

                  <button
                    onClick={() => toast.info('Draw feature coming soon!')}
                    className="p-2 hover:bg-white/10 rounded-full transition-colors opacity-50"
                    title="Draw"
                    disabled={isSending}
                  >
                    <Pen className="w-4 h-4 text-white" />
                  </button>
                </div>

                {/* HD Toggle */}
                <button
                  onClick={handleToggleHD}
                  className={`
                    px-3 py-1.5 rounded-full font-semibold text-xs
                    transition-all duration-200 transform
                    flex items-center gap-1.5
                    ${isHD 
                      ? 'bg-gradient-to-r from-purple-600 to-purple-700 text-white shadow-lg scale-105' 
                      : 'bg-gray-700 text-gray-300'
                    }
                  `}
                  disabled={isSending}
                >
                  <Sparkles className={`w-3 h-3 ${isHD ? 'animate-pulse' : ''}`} />
                  <span>HD</span>
                </button>
              </div>

              {/* Row 2: Send Button */}
              <button
                onClick={handleSend}
                disabled={isSending}
                className={`
                  w-full px-6 py-2.5 bg-gradient-to-r from-purple-600 to-purple-700 
                  hover:from-purple-700 hover:to-purple-800
                  text-white font-semibold rounded-full text-sm
                  shadow-lg shadow-purple-500/50
                  transition-all duration-200
                  flex items-center justify-center gap-2
                  transform hover:scale-105 active:scale-95
                  disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none
                `}
              >
                {isSending ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    <span>Sending...</span>
                  </>
                ) : (
                  <>
                    <Send className="w-4 h-4" />
                    <span>Send</span>
                  </>
                )}
              </button>
            </div>

            {/* Desktop Layout (Single Row) */}
            <div className="hidden sm:flex items-center justify-between gap-3">
              {/* Left: Edit Tools */}
              <div className="flex items-center gap-1 md:gap-2">
                <button
                  onClick={handleRotate}
                  className="p-2 md:p-3 hover:bg-white/10 rounded-full transition-colors"
                  title="Rotate"
                  disabled={isSending}
                >
                  <RotateCw className="w-4 h-4 md:w-5 md:h-5 text-white" />
                </button>

                <button
                  onClick={() => toast.info('Crop feature coming soon!')}
                  className="p-2 md:p-3 hover:bg-white/10 rounded-full transition-colors opacity-50"
                  title="Crop (Coming soon)"
                  disabled={isSending}
                >
                  <Crop className="w-4 h-4 md:w-5 md:h-5 text-white" />
                </button>

                <button
                  onClick={() => toast.info('Text feature coming soon!')}
                  className="p-2 md:p-3 hover:bg-white/10 rounded-full transition-colors opacity-50"
                  title="Add text (Coming soon)"
                  disabled={isSending}
                >
                  <Type className="w-4 h-4 md:w-5 md:h-5 text-white" />
                </button>

                <button
                  onClick={() => toast.info('Draw feature coming soon!')}
                  className="p-2 md:p-3 hover:bg-white/10 rounded-full transition-colors opacity-50"
                  title="Draw (Coming soon)"
                  disabled={isSending}
                >
                  <Pen className="w-4 h-4 md:w-5 md:h-5 text-white" />
                </button>
              </div>

              {/* Center: HD Toggle */}
              <div className="flex items-center gap-2 md:gap-3">
                <button
                  onClick={handleToggleHD}
                  className={`
                    px-4 md:px-6 py-2 md:py-2.5 rounded-full font-semibold text-xs md:text-sm
                    transition-all duration-200 transform
                    flex items-center gap-2
                    ${isHD 
                      ? 'bg-gradient-to-r from-purple-600 to-purple-700 text-white shadow-lg shadow-purple-500/50 scale-105' 
                      : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                    }
                  `}
                  disabled={isSending}
                >
                  <Sparkles className={`w-3 h-3 md:w-4 md:h-4 ${isHD ? 'animate-pulse' : ''}`} />
                  <span className="hidden md:inline">HD Quality</span>
                  <span className="md:hidden">HD</span>
                  {isHD && (
                    <div className="w-1.5 h-1.5 md:w-2 md:h-2 bg-white rounded-full animate-pulse" />
                  )}
                </button>
                
                {isHD && (
                  <div className="hidden lg:block text-xs text-purple-400 font-medium animate-fade-in">
                    Best quality ✨
                  </div>
                )}
              </div>

              {/* Right: Send Button */}
              <button
                onClick={handleSend}
                disabled={isSending}
                className={`
                  px-6 md:px-8 py-2 md:py-3 bg-gradient-to-r from-purple-600 to-purple-700 
                  hover:from-purple-700 hover:to-purple-800
                  text-white font-semibold rounded-full text-sm md:text-base
                  shadow-lg shadow-purple-500/50
                  transition-all duration-200
                  flex items-center gap-2
                  transform hover:scale-105 active:scale-95
                  disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none
                `}
              >
                {isSending ? (
                  <>
                    <div className="w-4 h-4 md:w-5 md:h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    <span>Sending...</span>
                  </>
                ) : (
                  <>
                    <Send className="w-4 h-4 md:w-5 md:h-5" />
                    <span>Send</span>
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Info Banner - HD Enabled */}
          {isHD && (
            <div className="absolute top-14 sm:top-16 left-1/2 -translate-x-1/2 bg-gradient-to-r from-purple-600 to-purple-700 text-white px-3 sm:px-6 py-1.5 sm:py-2 rounded-full shadow-2xl border-2 border-purple-400 animate-slide-down max-w-[90%]">
              <div className="flex items-center justify-center gap-2">
                <Sparkles className="w-3 h-3 sm:w-4 sm:h-4 animate-pulse flex-shrink-0" />
                <span className="text-xs sm:text-sm font-semibold truncate">
                  <span className="hidden md:inline">Ultra HD Quality • Better than WhatsApp • 4K Resolution</span>
                  <span className="md:hidden">Ultra HD Quality Enabled</span>
                </span>
              </div>
            </div>
          )}
        </div>
      </div>
    </>
  );
}


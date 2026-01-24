'use client';

import { useState, useEffect } from 'react';
import { X, Download, ChevronLeft, ChevronRight, ZoomIn, ZoomOut, RotateCw, Play, Pause, FileText, Music, File, ExternalLink } from 'lucide-react';
import { Message } from '@/lib/api/messages';
import AudioPlayer from './AudioPlayer';
import { toast } from '../ui/Toast';
import { useSignedFileURL, useSignedFileURLs } from '@/lib/hooks/useSignedFileURL';

interface MediaViewerProps {
  isOpen: boolean;
  message: Message;
  allMedia?: Message[];
  onClose: () => void;
}

export function MediaViewer({
  isOpen,
  message,
  allMedia = [],
  onClose,
}: MediaViewerProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [zoom, setZoom] = useState(1);
  const [rotation, setRotation] = useState(0);
  const [isVideoPlaying, setIsVideoPlaying] = useState(false);

  // Get current message
  const currentMessage = allMedia[currentIndex] || message;

  // Get signed URLs for current message
  const attachmentUrl = useSignedFileURL(currentMessage.attachment_url, currentMessage.id);
  const videoUrls = useSignedFileURLs(
    currentMessage.attachment_url,
    currentMessage.thumbnail_url,
    currentMessage.id
  );

  useEffect(() => {
    if (isOpen && allMedia.length > 0) {
      const index = allMedia.findIndex(m => m.id === message.id);
      setCurrentIndex(index >= 0 ? index : 0);
    }
  }, [isOpen, message, allMedia]);

  useEffect(() => {
    // Reset zoom and rotation when changing media
    setZoom(1);
    setRotation(0);
    setIsVideoPlaying(false);
  }, [currentIndex]);

  // Keyboard navigation
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyPress = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'ArrowLeft') handlePrevious();
      if (e.key === 'ArrowRight') handleNext();
    };

    window.addEventListener('keydown', handleKeyPress);
    return () => window.removeEventListener('keydown', handleKeyPress);
  }, [isOpen, currentIndex]);

  if (!isOpen) return null;

  const hasMultiple = allMedia.length > 1;

  const handlePrevious = () => {
    if (currentIndex > 0) {
      setCurrentIndex(currentIndex - 1);
    }
  };

  const handleNext = () => {
    if (currentIndex < allMedia.length - 1) {
      setCurrentIndex(currentIndex + 1);
    }
  };

  const handleOpenFile = () => {
    if (!attachmentUrl) return;
    
    // Open file in new tab or supporting app
    window.open(attachmentUrl, '_blank', 'noopener,noreferrer');
    toast.success('Opening file...');
  };

  const handleDownload = async () => {
    if (!attachmentUrl) return;

    try {
      toast.info('Downloading...');
      
      // Fetch the file as binary data (Blob)
      const response = await fetch(attachmentUrl);
      if (!response.ok) throw new Error('Failed to fetch file');
      
      const blob = await response.blob();
      
      // Generate WhatsApp-style filename: "Upvista Image 2025-11-05 at 08.30.15_abc123"
      // Safe date parsing with fallback
      let date: Date;
      try {
        date = new Date(currentMessage.created_at);
        if (isNaN(date.getTime())) {
          console.warn('[MediaViewer] Invalid timestamp, using current time');
          date = new Date();
        }
      } catch {
        date = new Date();
      }
      
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const hours = String(date.getHours()).padStart(2, '0');
      const minutes = String(date.getMinutes()).padStart(2, '0');
      const seconds = String(date.getSeconds()).padStart(2, '0');
      
      // Random suffix (like WhatsApp)
      const randomSuffix = Math.random().toString(36).substring(2, 10);
      
      // Determine file type label and extension
      let fileTypeLabel = 'File';
      let extension = '';
      
      // Extension mapping for all common file types
      const extensionMap: Record<string, string> = {
        // Images
        'image/png': 'png',
        'image/jpeg': 'jpg',
        'image/jpg': 'jpg',
        'image/gif': 'gif',
        'image/webp': 'webp',
        'image/svg+xml': 'svg',
        'image/bmp': 'bmp',
        'image/tiff': 'tiff',
        'image/heic': 'heic',
        'image/heif': 'heif',
        // Audio
        'audio/webm': 'webm',
        'audio/mpeg': 'mp3',
        'audio/mp3': 'mp3',
        'audio/wav': 'wav',
        'audio/ogg': 'ogg',
        'audio/aac': 'aac',
        'audio/flac': 'flac',
        'audio/m4a': 'm4a',
        // Video
        'video/mp4': 'mp4',
        'video/webm': 'webm',
        'video/quicktime': 'mov',
        'video/x-msvideo': 'avi',
        'video/x-matroska': 'mkv',
        'video/mpeg': 'mpeg',
        // Documents
        'application/pdf': 'pdf',
        'application/msword': 'doc',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
        'application/vnd.ms-excel': 'xls',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
        'application/vnd.ms-powerpoint': 'ppt',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
        'text/plain': 'txt',
        'text/csv': 'csv',
        'application/zip': 'zip',
        'application/x-rar-compressed': 'rar',
        'application/x-7z-compressed': '7z',
        'application/json': 'json',
        'text/html': 'html',
        'text/css': 'css',
        'application/javascript': 'js',
        'application/xml': 'xml',
      };
      
      switch (currentMessage.message_type) {
        case 'image':
          fileTypeLabel = 'Image';
          // Try to get extension from MIME type
          extension = currentMessage.attachment_type 
            ? extensionMap[currentMessage.attachment_type] || 'jpg'
            : 'jpg';
          break;
          
        case 'audio':
          fileTypeLabel = 'Audio';
          extension = currentMessage.attachment_type 
            ? extensionMap[currentMessage.attachment_type] || 'webm'
            : 'webm';
          break;
          
        case 'file':
          fileTypeLabel = 'Document';
          
          // Try multiple methods to get extension
          if (currentMessage.attachment_type && extensionMap[currentMessage.attachment_type]) {
            extension = extensionMap[currentMessage.attachment_type];
          } else if (currentMessage.attachment_type) {
            // Fallback: extract from MIME type
            const parts = currentMessage.attachment_type.split('/');
            extension = parts[1]?.replace(/[^a-z0-9]/gi, '') || 'bin';
          } else if (currentMessage.attachment_name?.includes('.')) {
            // Fallback: extract from filename
            extension = currentMessage.attachment_name.split('.').pop() || 'bin';
          } else {
            extension = 'bin';
          }
          break;
          
        default:
          fileTypeLabel = 'File';
          extension = 'bin';
      }
      
      // Construct filename: "Upvista Image 2025-11-05 at 08.30.15_abc123def.jpg"
      const filename = `Upvista ${fileTypeLabel} ${year}-${month}-${day} at ${hours}.${minutes}.${seconds}_${randomSuffix}.${extension}`;
      
      // Create download link and trigger download
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = filename;
      link.style.display = 'none';
      document.body.appendChild(link);
      link.click();
      
      // Cleanup
      setTimeout(() => {
        document.body.removeChild(link);
        window.URL.revokeObjectURL(downloadUrl);
      }, 100);
      
      toast.success(`Downloaded successfully`);
      console.log('[MediaViewer] Downloaded:', filename);
    } catch (error) {
      console.error('[MediaViewer] Download failed:', error);
      toast.error('Download failed. Please try again.');
    }
  };

  const handleZoomIn = () => {
    setZoom(prev => Math.min(prev + 0.5, 3));
  };

  const handleZoomOut = () => {
    setZoom(prev => Math.max(prev - 0.5, 0.5));
  };

  const handleRotate = () => {
    setRotation(prev => (prev + 90) % 360);
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  };

  return (
    <div className="fixed inset-0 bg-black z-[100] flex flex-col">
      {/* Header - WhatsApp Style */}
      <div className="bg-gray-900/95 backdrop-blur-sm px-4 py-3 flex items-center justify-between">
        {/* Left: Close & Info */}
        <div className="flex items-center gap-4">
          <button
            onClick={onClose}
            className="p-2 hover:bg-white/10 rounded-full transition-colors"
          >
            <X className="w-6 h-6 text-white" />
          </button>
          <div className="text-white">
            <p className="font-semibold text-sm">
              {currentMessage.sender?.display_name || 'User'}
            </p>
            <p className="text-xs text-gray-400">
              {formatDate(currentMessage.created_at)}
            </p>
          </div>
        </div>

        {/* Right: Actions */}
        <div className="flex items-center gap-2">
          {/* Image Controls */}
          {currentMessage.message_type === 'image' && (
            <>
              <button
                onClick={handleZoomOut}
                className="p-2 hover:bg-white/10 rounded-full transition-colors"
                title="Zoom out"
              >
                <ZoomOut className="w-5 h-5 text-white" />
              </button>
              <button
                onClick={handleZoomIn}
                className="p-2 hover:bg-white/10 rounded-full transition-colors"
                title="Zoom in"
              >
                <ZoomIn className="w-5 h-5 text-white" />
              </button>
              <button
                onClick={handleRotate}
                className="p-2 hover:bg-white/10 rounded-full transition-colors"
                title="Rotate"
              >
                <RotateCw className="w-5 h-5 text-white" />
              </button>
            </>
          )}

          {/* Open File - for documents */}
          {(currentMessage.message_type === 'file' || currentMessage.message_type === 'audio') && (
            <button
              onClick={handleOpenFile}
              className="p-2 hover:bg-white/10 rounded-full transition-colors"
              title="Open file in new tab"
            >
              <ExternalLink className="w-5 h-5 text-white" strokeWidth={2} />
            </button>
          )}

          {/* Download */}
          <button
            onClick={handleDownload}
            className="p-2 hover:bg-white/10 rounded-full transition-colors"
            title="Download"
          >
            <Download className="w-5 h-5 text-white" />
          </button>
        </div>
      </div>

      {/* Media Content */}
      <div className="flex-1 flex items-center justify-center relative overflow-hidden">
        {/* Navigation - Previous */}
        {hasMultiple && currentIndex > 0 && (
          <button
            onClick={handlePrevious}
            className="absolute left-4 z-10 p-3 bg-black/50 hover:bg-black/70 rounded-full transition-colors"
          >
            <ChevronLeft className="w-6 h-6 text-white" />
          </button>
        )}

        {/* Media Display */}
        <div className="w-full h-full flex items-center justify-center p-4 md:p-8">
          {currentMessage.message_type === 'image' && attachmentUrl && (
            <div className="relative w-full h-full flex items-center justify-center">
              {/* High-Quality Image with Shadow */}
              <img
                src={attachmentUrl}
                alt="Media"
                className="max-w-full max-h-[85vh] object-contain transition-all duration-300 select-none rounded-lg shadow-2xl"
                style={{
                  transform: `scale(${zoom}) rotate(${rotation}deg)`,
                  imageRendering: zoom > 1 ? 'crisp-edges' : 'auto',
                  filter: 'contrast(1.02) brightness(1.02)',
                } as React.CSSProperties}
                loading="eager"
                draggable={false}
              />
              
              {/* Zoom Level Indicator */}
              {zoom !== 1 && (
                <div className="absolute bottom-4 left-1/2 -translate-x-1/2 bg-black/80 text-white px-4 py-2 rounded-full text-sm font-bold backdrop-blur-sm border border-white/20">
                  {Math.round(zoom * 100)}%
                </div>
              )}
            </div>
          )}

          {/* Video Player */}
          {currentMessage.message_type === 'video' && videoUrls.video && (
            <div className="w-full max-w-5xl">
              <video
                src={videoUrls.video}
                poster={videoUrls.thumbnail || undefined}
                controls
                autoPlay
                playsInline
                className="w-full h-auto max-h-[85vh] rounded-lg shadow-2xl bg-black"
                style={{
                  objectFit: 'contain',
                }}
              />
              
              {/* Video Info */}
              <div className="mt-4 text-center text-gray-300 text-sm">
                {currentMessage.video_width && currentMessage.video_height && (
                  <span className="mr-4">
                    {currentMessage.video_width}×{currentMessage.video_height}
                  </span>
                )}
                {currentMessage.video_duration && (
                  <span className="mr-4">
                    {Math.floor(currentMessage.video_duration / 60)}:{(currentMessage.video_duration % 60).toString().padStart(2, '0')}
                  </span>
                )}
                {currentMessage.attachment_size && (
                  <span>
                    {(currentMessage.attachment_size / (1024 * 1024)).toFixed(1)} MB
                  </span>
                )}
              </div>
            </div>
          )}

          {currentMessage.message_type === 'audio' && attachmentUrl && (
            <div className="w-full max-w-md">
              {/* Professional Audio Card */}
              <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-3xl shadow-2xl overflow-hidden border border-gray-700/50">
                {/* Header Section */}
                <div className="bg-gradient-to-r from-purple-600/20 to-purple-800/20 p-6 border-b border-gray-700/50">
                  <div className="flex items-center gap-4">
                    <div className="w-16 h-16 bg-gradient-to-br from-purple-500 to-purple-700 rounded-2xl flex items-center justify-center shadow-lg">
                      <Music className="w-8 h-8 text-white" />
                    </div>
                    <div className="flex-1 text-white">
                      <p className="font-semibold text-lg">Voice Message</p>
                      <p className="text-sm text-purple-200">
                        From {currentMessage.sender?.display_name || 'User'}
                      </p>
                    </div>
                  </div>
                </div>
                
                {/* Audio Player Section */}
                <div className="p-6">
                  <AudioPlayer url={attachmentUrl} duration={0} />
                </div>
              </div>
            </div>
          )}

          {currentMessage.message_type === 'file' && (
            <div className="w-full max-w-md">
              {/* Professional File Card */}
              <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-3xl shadow-2xl overflow-hidden border border-gray-700/50">
                {/* File Icon & Info Section */}
                <div className="p-8">
                  <div className="flex flex-col items-center gap-6">
                    {/* Large Professional Icon */}
                    <div className="relative">
                      <div className="w-28 h-28 bg-gradient-to-br from-blue-500 to-blue-700 rounded-3xl flex items-center justify-center shadow-2xl transform hover:scale-105 transition-transform">
                        {currentMessage.attachment_type?.includes('pdf') ? (
                          <FileText className="w-14 h-14 text-white" strokeWidth={1.5} />
                        ) : currentMessage.attachment_type?.includes('image') ? (
                          <File className="w-14 h-14 text-white" strokeWidth={1.5} />
                        ) : (
                          <File className="w-14 h-14 text-white" strokeWidth={1.5} />
                        )}
                      </div>
                      {/* File Type Badge */}
                      <div className="absolute -bottom-2 -right-2 px-3 py-1 bg-gradient-to-r from-blue-600 to-blue-700 rounded-full text-xs font-bold text-white shadow-lg border-2 border-gray-800">
                        {currentMessage.attachment_type?.split('/')[1]?.toUpperCase() || 'FILE'}
                      </div>
                    </div>
                    
                    {/* File Details */}
                    <div className="text-center text-white w-full">
                      <p className="font-semibold text-lg mb-2 truncate px-4">
                        {currentMessage.attachment_name || 'Document'}
                      </p>
                      <div className="flex items-center justify-center gap-3 text-sm text-gray-400">
                        <span className="px-3 py-1 bg-gray-700/50 rounded-full">
                          {currentMessage.attachment_size 
                            ? `${(currentMessage.attachment_size / 1024).toFixed(1)} KB`
                            : 'File'}
                        </span>
                        <span className="text-gray-600">•</span>
                        <span>
                          {new Date(currentMessage.created_at).toLocaleDateString()}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
                
                {/* Action Buttons Section */}
                <div className="px-6 pb-6">
                  <div className="flex gap-3">
                    <button
                      onClick={handleOpenFile}
                      className="flex-1 py-3.5 bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white rounded-xl transition-all duration-200 font-semibold flex items-center justify-center gap-2 shadow-lg hover:shadow-xl transform hover:scale-[1.02]"
                    >
                      <ExternalLink className="w-5 h-5" strokeWidth={2} />
                      Open File
                    </button>
                    <button
                      onClick={handleDownload}
                      className="flex-1 py-3.5 bg-gradient-to-r from-purple-600 to-purple-700 hover:from-purple-700 hover:to-purple-800 text-white rounded-xl transition-all duration-200 font-semibold flex items-center justify-center gap-2 shadow-lg hover:shadow-xl transform hover:scale-[1.02]"
                    >
                      <Download className="w-5 h-5" strokeWidth={2} />
                      Download
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Navigation - Next */}
        {hasMultiple && currentIndex < allMedia.length - 1 && (
          <button
            onClick={handleNext}
            className="absolute right-4 z-10 p-3 bg-black/50 hover:bg-black/70 rounded-full transition-colors"
          >
            <ChevronRight className="w-6 h-6 text-white" />
          </button>
        )}
      </div>

      {/* Footer - Counter */}
      {hasMultiple && (
        <div className="bg-gray-900/95 backdrop-blur-sm px-4 py-3 text-center">
          <p className="text-white text-sm font-medium">
            {currentIndex + 1} / {allMedia.length}
          </p>
        </div>
      )}
    </div>
  );
}


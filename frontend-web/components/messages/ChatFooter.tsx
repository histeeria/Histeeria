'use client';

import { useState, useRef, KeyboardEvent, useEffect } from 'react';
import { Smile, Paperclip, Mic, X, Send, Image as ImageIcon, Camera, FileText, Music, MapPin, User, Pause, Play, Trash2, Video } from 'lucide-react';
import { Message, messagesAPI } from '@/lib/api/messages';
import { toast } from '../ui/Toast';
import { validateImageFile, validateAudioFile, validateDocumentFile } from '@/lib/utils/fileValidation';

interface ChatFooterProps {
  conversationId: string;
  onSendMessage: (text: string) => void;
  onSendImage: (file: File, quality: 'standard' | 'hd') => void;
  onSendFile?: (file: File) => void;
  onSendVideo?: (file: File) => void;
  onStartVoiceRecording: () => void;
  onPauseVoiceRecording: () => void;
  onResumeVoiceRecording: () => void;
  onCancelVoiceRecording: () => void;
  isRecording: boolean;
  isPaused: boolean;
  recordingDuration: number;
  replyingTo: Message | null;
  onCancelReply: () => void;
}

export default function ChatFooter({
  conversationId,
  onSendMessage,
  onSendImage,
  onSendFile,
  onSendVideo,
  onStartVoiceRecording,
  onPauseVoiceRecording,
  onResumeVoiceRecording,
  onCancelVoiceRecording,
  isRecording,
  isPaused,
  recordingDuration,
  replyingTo,
  onCancelReply,
}: ChatFooterProps) {
  const [text, setText] = useState('');
  const [showAttachmentMenu, setShowAttachmentMenu] = useState(false);
  const [waveformData, setWaveformData] = useState<number[]>(new Array(30).fill(20));
  const [isTyping, setIsTyping] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);
  const documentInputRef = useRef<HTMLInputElement>(null);
  const audioInputRef = useRef<HTMLInputElement>(null);
  const videoInputRef = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const animationFrameRef = useRef<number | null>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // ==================== SEND ====================

  const handleSend = () => {
    if (text.trim() || isRecording) {
      onSendMessage(text);
      setText('');

      // Stop typing indicator when sending
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
      sendTypingStop();

      // Reset textarea height
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto';
      }
    }
  };

  const handleKeyPress = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  // ==================== TYPING INDICATOR ====================

  const sendTypingStart = async (isRecordingVoice: boolean = false) => {
    if (!isTyping) {
      setIsTyping(true);
      try {
        await messagesAPI.startTyping(conversationId, isRecordingVoice);
        console.log('[ChatFooter] Typing indicator started, recording:', isRecordingVoice);
      } catch (error) {
        console.error('[ChatFooter] Failed to start typing indicator:', error);
      }
    }
  };

  const sendTypingStop = async () => {
    if (isTyping) {
      setIsTyping(false);
      try {
        await messagesAPI.stopTyping(conversationId);
        console.log('[ChatFooter] Typing indicator stopped');
      } catch (error) {
        console.error('[ChatFooter] Failed to stop typing indicator:', error);
      }
    }
  };

  // Stop typing on unmount
  useEffect(() => {
    return () => {
      if (isTyping) {
        messagesAPI.stopTyping(conversationId).catch(console.error);
      }
    };
  }, [conversationId, isTyping]);

  // ==================== AUTO-RESIZE TEXTAREA ====================

  const handleTextChange = (value: string) => {
    setText(value);

    // Auto-resize textarea
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = textareaRef.current.scrollHeight + 'px';
    }

    // Handle typing indicator
    if (value.trim()) {
      // User is typing - send typing start
      sendTypingStart();

      // Clear previous timeout
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }

      // Set new timeout to stop typing after 3 seconds of inactivity
      typingTimeoutRef.current = setTimeout(() => {
        sendTypingStop();
      }, 3000);
    } else {
      // Text is empty - stop typing immediately
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
      sendTypingStop();
    }
  };

  // ==================== ATTACHMENT ====================

  const handleAttachment = () => {
    setShowAttachmentMenu(!showAttachmentMenu);
  };

  const handleGalleryClick = () => {
    imageInputRef.current?.click();
    setShowAttachmentMenu(false);
  };

  const handleCameraClick = () => {
    cameraInputRef.current?.click();
    setShowAttachmentMenu(false);
  };

  const handleDocumentClick = () => {
    documentInputRef.current?.click();
    setShowAttachmentMenu(false);
  };

  const handleAudioFileClick = () => {
    audioInputRef.current?.click();
    setShowAttachmentMenu(false);
  };

  const handleVideoClick = () => {
    videoInputRef.current?.click();
    setShowAttachmentMenu(false);
  };

  const handleImageSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate image
    const validation = validateImageFile(file);
    if (!validation.valid) {
      toast.error(validation.error || 'Invalid image file');
      e.target.value = '';
      return;
    }

    // Show warning for large files
    if (validation.warning) {
      toast.info(validation.warning);
    }

    if (file.type.startsWith('image/')) {
      onSendImage(file, 'standard'); // This will trigger quality dialog in ChatWindow
    }
    e.target.value = '';
  };

  const handleDocumentSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate document
    const validation = validateDocumentFile(file);
    if (!validation.valid) {
      toast.error(validation.error || 'Invalid file');
      e.target.value = '';
      return;
    }

    if (validation.warning) {
      toast.info(validation.warning);
    }

    if (onSendFile) {
      onSendFile(file);
    } else {
      toast.info('Document sending coming soon!');
    }
    e.target.value = '';
  };

  const handleAudioFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate audio
    const validation = validateAudioFile(file);
    if (!validation.valid) {
      toast.error(validation.error || 'Invalid audio file');
      e.target.value = '';
      return;
    }

    if (validation.warning) {
      toast.info(validation.warning);
    }

    if (onSendFile) {
      onSendFile(file);
    } else {
      toast.info('Audio file sending coming soon!');
    }
    e.target.value = '';
  };

  const handleVideoSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate video
    const maxSize = 100 * 1024 * 1024; // 100MB
    if (file.size > maxSize) {
      toast.error(`Video too large. Maximum size is 100MB. Your file: ${(file.size / (1024 * 1024)).toFixed(1)}MB`);
      e.target.value = '';
      return;
    }

    if (!file.type.startsWith('video/')) {
      toast.error('Please select a valid video file');
      e.target.value = '';
      return;
    }

    // Trigger video quality dialog
    if (onSendVideo) {
      onSendVideo(file);
    } else {
      toast.info('Video sending coming soon!');
    }
    
    e.target.value = '';
  };

  // ==================== WAVEFORM VISUALIZATION ====================

  useEffect(() => {
    if (isRecording && !isPaused) {
      startWaveformVisualization();
    } else {
      stopWaveformVisualization();
    }

    return () => {
      stopWaveformVisualization();
    };
  }, [isRecording, isPaused]);

  const startWaveformVisualization = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      
      audioContextRef.current = new (window.AudioContext || (window as any).webkitAudioContext)();
      const source = audioContextRef.current.createMediaStreamSource(stream);
      
      analyserRef.current = audioContextRef.current.createAnalyser();
      analyserRef.current.fftSize = 512;
      analyserRef.current.smoothingTimeConstant = 0.8;
      
      source.connect(analyserRef.current);
      
      visualizeWaveform();
    } catch (error) {
      console.error('[ChatFooter] Waveform visualization failed:', error);
    }
  };

  const visualizeWaveform = () => {
    if (!analyserRef.current || !isRecording || isPaused) return;

    const bufferLength = analyserRef.current.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);

    const updateWaveform = () => {
      if (!isRecording || isPaused) return;
      
      animationFrameRef.current = requestAnimationFrame(updateWaveform);
      analyserRef.current!.getByteFrequencyData(dataArray);

      // Sample data for waveform bars
      const bars = 30;
      const newWaveData = [];
      const step = Math.floor(bufferLength / bars);
      
      for (let i = 0; i < bars; i++) {
        const index = i * step;
        const value = dataArray[index] || 0;
        // Normalize to 10-100 range for better visuals
        newWaveData.push(Math.max(10, Math.min(100, (value / 255) * 100)));
      }
      
      setWaveformData(newWaveData);
    };

    updateWaveform();
  };

  const stopWaveformVisualization = () => {
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current);
      animationFrameRef.current = null;
    }
    if (audioContextRef.current) {
      audioContextRef.current.close();
      audioContextRef.current = null;
    }
    analyserRef.current = null;
  };

  // ==================== VOICE RECORDING ====================

  // Broadcast recording status when recording starts/stops
  useEffect(() => {
    if (isRecording) {
      // Send typing with "recording" status - IMPORTANT: Pass true!
      console.log('[ChatFooter] Broadcasting RECORDING status (is_recording: true)');
      sendTypingStart(true); // ← This tells backend user is RECORDING, not typing!
    } else {
      // Stop recording status
      if (isTyping) {
        sendTypingStop();
      }
    }
  }, [isRecording]);

  const handleVoiceClick = async () => {
    if (isRecording) {
      // Already recording - stop and send
      console.log('[ChatFooter] Stopping recording and sending...');
      handleSend();
    } else {
      // Not recording - start recording
      console.log('[ChatFooter] Starting voice recording...');
      await onStartVoiceRecording();
    }
  };

  const handlePauseResume = () => {
    if (isPaused) {
      onResumeVoiceRecording();
    } else {
      onPauseVoiceRecording();
    }
  };

  const formatDuration = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  // ==================== RENDER ====================

  return (
    <div className="border-t border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900">
      {/* Reply Preview - WhatsApp Style */}
      {replyingTo && (
        <div className="px-4 py-3 bg-gradient-to-r from-purple-50 to-transparent dark:from-purple-900/20 dark:to-transparent border-b border-gray-200 dark:border-gray-700">
          <div className="flex items-start gap-3">
            {/* Left Border Accent */}
            <div className="w-1 h-12 bg-purple-600 rounded-full flex-shrink-0"></div>
            
            {/* Reply Content */}
            <div className="flex-1 min-w-0">
              <div className="text-xs font-semibold text-purple-600 dark:text-purple-400 mb-1">
                Replying to {replyingTo.sender?.display_name || 'User'}
              </div>
              <div className="text-sm text-gray-700 dark:text-gray-300 line-clamp-2 flex items-center gap-2">
                {replyingTo.message_type === 'image' && (
                  <>
                    <span className="flex items-center gap-1.5">
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
                        <circle cx="8.5" cy="8.5" r="1.5"/>
                        <polyline points="21 15 16 10 5 21"/>
                      </svg>
                      Photo
                    </span>
                  </>
                )}
                {replyingTo.message_type === 'audio' && (
                  <>
                    <span className="flex items-center gap-1.5">
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/>
                        <path d="M19 10v2a7 7 0 0 1-14 0v-2"/>
                        <line x1="12" y1="19" x2="12" y2="23"/>
                        <line x1="8" y1="23" x2="16" y2="23"/>
                      </svg>
                      Voice message
                    </span>
                  </>
                )}
                {replyingTo.message_type === 'file' && (
                  <>
                    <span className="flex items-center gap-1.5">
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/>
                      </svg>
                      File
                    </span>
                  </>
                )}
                {replyingTo.message_type === 'text' && replyingTo.content}
              </div>
            </div>
            
            {/* Close Button */}
            <button
              onClick={onCancelReply}
              className="p-1.5 hover:bg-purple-100 dark:hover:bg-purple-900/30 rounded-full transition-colors flex-shrink-0"
              title="Cancel reply"
            >
              <X className="w-4 h-4 text-gray-500 dark:text-gray-400" />
            </button>
          </div>
        </div>
      )}

      {/* WhatsApp-Style Inline Recording UI */}
      {isRecording && (
        <div className="px-4 py-3 bg-gradient-to-r from-purple-50 to-purple-100 dark:from-purple-900/20 dark:to-purple-800/10 border-b border-purple-200 dark:border-purple-700/30">
          <div className="flex items-center gap-3">
            {/* Delete Button */}
            <button
              onClick={onCancelVoiceRecording}
              className="p-2 hover:bg-red-100 dark:hover:bg-red-900/30 rounded-full transition-colors flex-shrink-0"
              title="Delete recording"
            >
              <Trash2 className="w-5 h-5 text-red-600 dark:text-red-400" />
            </button>

            {/* Recording Indicator Dot */}
            {!isPaused && (
              <div className="w-3 h-3 bg-red-500 rounded-full animate-pulse flex-shrink-0"></div>
            )}

            {/* Waveform Visualization */}
            <div className="flex-1 flex items-center gap-0.5 h-10 px-2">
              {waveformData.map((height, index) => (
                <div
                  key={index}
                  className={`w-1 rounded-full transition-all duration-100 ${
                    isPaused
                      ? 'bg-gray-400 dark:bg-gray-500'
                      : 'bg-purple-600 dark:bg-purple-400'
                  }`}
                  style={{
                    height: `${height}%`,
                    maxHeight: '100%',
                  }}
                />
              ))}
            </div>

            {/* Duration */}
            <span className="text-sm font-semibold text-purple-900 dark:text-purple-100 min-w-[50px] flex-shrink-0">
              {formatDuration(recordingDuration)}
            </span>

            {/* Pause/Resume Button */}
            <button
              onClick={handlePauseResume}
              className="p-2.5 bg-white dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors shadow-md flex-shrink-0"
              title={isPaused ? 'Resume' : 'Pause'}
            >
              {isPaused ? (
                <Play className="w-5 h-5 text-purple-600 dark:text-purple-400" fill="currentColor" />
              ) : (
                <Pause className="w-5 h-5 text-purple-600 dark:text-purple-400" />
              )}
            </button>

            {/* Send Button */}
            <button
              onClick={handleSend}
              className="p-3 bg-gradient-to-r from-purple-600 to-purple-700 hover:from-purple-700 hover:to-purple-800 text-white rounded-full transition-all duration-200 transform hover:scale-105 active:scale-95 shadow-lg shadow-purple-500/50 flex-shrink-0"
              title="Send voice message"
            >
              <Send className="w-5 h-5" />
            </button>
          </div>

          {/* Paused Status */}
          {isPaused && (
            <div className="mt-2 text-xs text-center text-purple-700 dark:text-purple-300 font-medium">
              Recording paused
            </div>
          )}
        </div>
      )}

      {/* Input Area */}
      <div className="p-4 flex items-center gap-2.5">
        {/* Emoji Button */}
        <button
          onClick={async () => {
            const { toast } = await import('@/components/ui/Toast');
            toast.info('Emoji picker coming soon!');
          }}
          className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors flex-shrink-0"
        >
          <Smile className="w-5 h-5 text-gray-600 dark:text-gray-400" />
        </button>

        {/* Text Input */}
        <div className="flex-1 relative flex items-center">
          <textarea
            ref={textareaRef}
            value={text}
            onChange={(e) => handleTextChange(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder={isRecording ? 'Recording audio...' : 'Type a message...'}
            disabled={isRecording}
            className="w-full px-4 py-2.5 pr-10 rounded-full border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-900 dark:text-white resize-none focus:outline-none focus:ring-2 focus:ring-purple-500 max-h-32"
            rows={1}
            style={{ minHeight: '44px', lineHeight: '1.5' }}
          />

          {/* Attachment Button (inside input, vertically centered) */}
          <div className="absolute right-2 top-1/2 -translate-y-1/2">
            <button
              onClick={handleAttachment}
              className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors relative"
            >
              <Paperclip className="w-5 h-5 text-gray-600 dark:text-gray-400" />
            </button>

            {/* Attachment Grid Menu - Compact Dropdown */}
            {showAttachmentMenu && (
              <>
                {/* Backdrop */}
                <div
                  className="fixed inset-0 z-40"
                  onClick={() => setShowAttachmentMenu(false)}
                />

                {/* Grid Menu - Dropdown near paperclip */}
                <div className="absolute bottom-full right-0 mb-2 w-[280px] bg-white dark:bg-gray-800 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 p-5 z-50 animate-scale-in">
                  {/* Grid of Options - 3 per row */}
                  <div className="grid grid-cols-3 gap-x-4 gap-y-5">
                    {/* Gallery */}
                    <button
                      onClick={handleGalleryClick}
                      className="flex flex-col items-center justify-start gap-2 active:scale-95 transition-transform min-w-[70px]"
                    >
                      <div className="w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center shadow-md flex-shrink-0">
                        <ImageIcon className="w-6 h-6 text-white" />
                      </div>
                      <span className="text-[10px] text-gray-700 dark:text-gray-300 font-medium text-center whitespace-nowrap">Gallery</span>
                    </button>

                    {/* Camera */}
                    <button
                      onClick={handleCameraClick}
                      className="flex flex-col items-center justify-start gap-2 active:scale-95 transition-transform min-w-[70px]"
                    >
                      <div className="w-12 h-12 bg-pink-500 rounded-full flex items-center justify-center shadow-md flex-shrink-0">
                        <Camera className="w-6 h-6 text-white" />
                      </div>
                      <span className="text-[10px] text-gray-700 dark:text-gray-300 font-medium text-center whitespace-nowrap">Camera</span>
                    </button>

                    {/* Video */}
                    <button
                      onClick={handleVideoClick}
                      className="flex flex-col items-center justify-start gap-2 active:scale-95 transition-transform min-w-[70px]"
                    >
                      <div className="w-12 h-12 bg-red-500 rounded-full flex items-center justify-center shadow-md flex-shrink-0">
                        <Video className="w-6 h-6 text-white" />
                      </div>
                      <span className="text-[10px] text-gray-700 dark:text-gray-300 font-medium text-center whitespace-nowrap">Video</span>
                    </button>

                    {/* Location */}
                    <button
                      onClick={() => {
                        toast.info('Location sharing coming soon!');
                        setShowAttachmentMenu(false);
                      }}
                      className="flex flex-col items-center justify-start gap-2 active:scale-95 transition-transform min-w-[70px]"
                    >
                      <div className="w-12 h-12 bg-green-500 rounded-full flex items-center justify-center shadow-md flex-shrink-0">
                        <MapPin className="w-6 h-6 text-white" />
                      </div>
                      <span className="text-[10px] text-gray-700 dark:text-gray-300 font-medium text-center whitespace-nowrap">Location</span>
                    </button>

                    {/* Contact */}
                    <button
                      onClick={() => {
                        toast.info('Contact sharing coming soon!');
                        setShowAttachmentMenu(false);
                      }}
                      className="flex flex-col items-center justify-start gap-2 active:scale-95 transition-transform min-w-[70px]"
                    >
                      <div className="w-12 h-12 bg-indigo-500 rounded-full flex items-center justify-center shadow-md flex-shrink-0">
                        <User className="w-6 h-6 text-white" />
                      </div>
                      <span className="text-[10px] text-gray-700 dark:text-gray-300 font-medium text-center whitespace-nowrap">Contact</span>
                    </button>

                    {/* Document */}
                    <button
                      onClick={handleDocumentClick}
                      className="flex flex-col items-center justify-start gap-2 active:scale-95 transition-transform min-w-[70px]"
                    >
                      <div className="w-12 h-12 bg-purple-500 rounded-full flex items-center justify-center shadow-md flex-shrink-0">
                        <FileText className="w-6 h-6 text-white" />
                      </div>
                      <span className="text-[10px] text-gray-700 dark:text-gray-300 font-medium text-center whitespace-nowrap">Document</span>
                    </button>

                    {/* Audio */}
                    <button
                      onClick={handleAudioFileClick}
                      className="flex flex-col items-center justify-start gap-2 active:scale-95 transition-transform min-w-[70px]"
                    >
                      <div className="w-12 h-12 bg-orange-500 rounded-full flex items-center justify-center shadow-md flex-shrink-0">
                        <Music className="w-6 h-6 text-white" />
                      </div>
                      <span className="text-[10px] text-gray-700 dark:text-gray-300 font-medium text-center whitespace-nowrap">Audio</span>
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>

          {/* Hidden file inputs */}
          <input
            ref={imageInputRef}
            type="file"
            accept="image/*"
            onChange={handleImageSelect}
            className="hidden"
          />
          <input
            ref={cameraInputRef}
            type="file"
            accept="image/*"
            capture="environment"
            onChange={handleImageSelect}
            className="hidden"
          />
          <input
            ref={documentInputRef}
            type="file"
            accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.zip,.rar,.7z"
            onChange={handleDocumentSelect}
            className="hidden"
          />
          <input
            ref={audioInputRef}
            type="file"
            accept="audio/*"
            onChange={handleAudioFileSelect}
            className="hidden"
          />
          <input
            ref={videoInputRef}
            type="file"
            accept="video/*"
            onChange={handleVideoSelect}
            className="hidden"
          />
        </div>

        {/* Send / Voice Button - Equal height to input */}
        {text.trim() ? (
          <button
            onClick={handleSend}
            className="p-2.5 bg-purple-600 hover:bg-purple-700 text-white rounded-full transition-colors flex-shrink-0"
            style={{ height: '44px', width: '44px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
            title="Send message"
          >
            <Send className="w-5 h-5" />
          </button>
        ) : (
          <button
            onClick={handleVoiceClick}
            className={`rounded-full transition-colors flex-shrink-0 ${
              isRecording
                ? 'bg-red-600 hover:bg-red-700 text-white animate-pulse'
                : 'bg-purple-600 hover:bg-purple-700 text-white'
            }`}
            style={{ height: '44px', width: '44px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
            title={isRecording ? 'Click to send voice message' : 'Click to start recording'}
          >
            {isRecording ? <Send className="w-5 h-5" /> : <Mic className="w-5 h-5" />}
          </button>
        )}
      </div>
    </div>
  );
}


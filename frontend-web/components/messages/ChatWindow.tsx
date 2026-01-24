'use client';

import { useState, useEffect, useRef } from 'react';
import { messagesAPI, Conversation, Message } from '@/lib/api/messages';
import { useOptimisticMessages } from '@/lib/hooks/useOptimisticMessages';
import { useInfiniteMessages } from '@/lib/hooks/useInfiniteMessages';
import { useVoiceRecorder } from '@/lib/hooks/useVoiceRecorder';
import { compressImage } from '@/lib/utils/imageCompression';
import { compressAudio } from '@/lib/utils/audioCompression';
import { compressVideo } from '@/lib/utils/videoCompression';
import ChatHeader from './ChatHeader';
import ChatFooter from './ChatFooter';
import MessageBubble from './MessageBubble';
import VirtualMessageList from './VirtualMessageList';
import TypingIndicator from './TypingIndicator';
import { messageWS } from '@/lib/websocket/MessageWebSocket';
import { toast } from '@/components/ui/Toast';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { EditMessageDialog } from './EditMessageDialog';
import { ForwardMessageDialog } from './ForwardMessageDialog';
import { MessageInfoDialog } from './MessageInfoDialog';
import { ChatProfileDialog } from './ChatProfileDialog';
import { MediaViewer } from './MediaViewer';
import { VideoQualityDialog } from './VideoQualityDialog';
import { ChevronDown } from 'lucide-react';
import { NetworkStatusBar } from './NetworkStatusBar';
import { UploadProgressBar } from './UploadProgressBar';
import { ImagePreviewEditor } from './ImagePreviewEditor';
import { useNetworkStatus } from '@/lib/hooks/useNetworkStatus';
import { useUploadProgress } from '@/lib/hooks/useUploadProgress';

interface TypingUser {
  user_id: string;
  display_name: string;
  is_recording?: boolean;
}

interface ChatWindowProps {
  conversationId: string;
  onClose?: () => void;
}

export default function ChatWindow({ conversationId, onClose }: ChatWindowProps) {
  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [typingUsers, setTypingUsers] = useState<TypingUser[]>([]);
  const [replyingTo, setReplyingTo] = useState<Message | null>(null);
  const [isChatVisible, setIsChatVisible] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState<{ messageId: string; isMine: boolean; type: 'unsend' | 'delete_for_me' } | null>(null);
  const [editingMessage, setEditingMessage] = useState<{ id: string; content: string } | null>(null);
  const [forwardingMessage, setForwardingMessage] = useState<string | null>(null);
  const [infoMessage, setInfoMessage] = useState<Message | null>(null);
  const [searchResults, setSearchResults] = useState<Message[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [showPinnedOnly, setShowPinnedOnly] = useState(false);
  const [pinnedCount, setPinnedCount] = useState(0);
  const [showProfileDialog, setShowProfileDialog] = useState(false);
  const [viewingMedia, setViewingMedia] = useState<Message | null>(null);
  const [pendingImageFile, setPendingImageFile] = useState<File | null>(null);
  const [pendingVideoFile, setPendingVideoFile] = useState<File | null>(null);
  const [videoDuration, setVideoDuration] = useState<number | undefined>(undefined);
  const [useVirtualScroll] = useState(true); // Enable virtual scrolling for performance
  
  // Scroll to bottom button state
  const [showScrollButton, setShowScrollButton] = useState(false);
  const [unreadWhileScrolledUp, setUnreadWhileScrolledUp] = useState(0);
  const [isUserAtBottom, setIsUserAtBottom] = useState(true);

  // Hooks
  const {
    messages,
    sendMessage,
    sendMessageWithAttachment,
    setMessages,
    removeMessage,
    retryMessage,
    processOfflineQueue,
  } = useOptimisticMessages({ conversationId });

  const {
    messages: _loadedMessages,
    isLoading,
    isLoadingMore,
    hasMore,
    scrollRef,
    handleScroll,
    scrollToBottom,
    loadMore,
  } = useInfiniteMessages({ conversationId });

  const { 
    isRecording, 
    duration, 
    startRecording, 
    stopRecording, 
    cancelRecording,
    isPaused,
    pauseRecording,
    resumeRecording 
  } = useVoiceRecorder();

  const networkStatus = useNetworkStatus();
  
  const {
    startUpload,
    updateProgress,
    completeUpload,
    failUpload,
    cancelUpload,
    uploads,
  } = useUploadProgress();

  // ==================== COUNT PINNED MESSAGES ====================

  useEffect(() => {
    // Count pinned messages in real-time
    const count = messages.filter(msg => msg.is_pinned || msg.pinned_at).length;
    setPinnedCount(count);
    console.log('[ChatWindow] Pinned message count:', count);
  }, [messages]);

  // ==================== MARK AS READ STATE ====================
  // Track mark-as-read state to prevent duplicate requests (must be defined before loadConversation)
  const markAsReadInFlightRef = useRef(false);
  const markAsReadTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const lastMarkedReadAtRef = useRef<number>(0);

  // ==================== LOAD CONVERSATION ====================

  useEffect(() => {
    loadConversation();
    // Note: WebSocket connection is already handled by NotificationContext
    // Messages use the same WebSocket connection (shared endpoint)
    
    // Test WebSocket connection
    console.log('[ChatWindow] Is WebSocket connected?', messageWS.isConnected());
    console.log('[ChatWindow] Registering message listeners for conversation:', conversationId);
    
    // Check if this ChatWindow is actually visible on screen (not hidden in responsive layout)
    const checkVisibility = () => {
      const isVisible = window.innerWidth >= 768 || onClose !== undefined;
      setIsChatVisible(isVisible);
      console.log('[ChatWindow] Visibility check - is visible:', isVisible, 'width:', window.innerWidth);
    };
    
    checkVisibility();
    window.addEventListener('resize', checkVisibility);
    
    // Mark as visible immediately on mobile (when onClose exists)
    if (onClose) {
      setIsChatVisible(true);
    }
    
    return () => window.removeEventListener('resize', checkVisibility);
  }, [conversationId, onClose]);

  const loadConversation = async () => {
    try {
      const response = await messagesAPI.getConversation(conversationId);
      if (response.success) {
        setConversation(response.conversation);
        console.log('[ChatWindow] Conversation loaded, unread_count:', response.conversation.unread_count);
        
        // Initialize E2EE key exchange for this conversation (if not already done)
        try {
          const { initializeE2EEForConversation } = await import('@/lib/messaging/keyExchange');
          const token = localStorage.getItem('token');
          if (token && response.conversation) {
            // Get current user ID from token
            const base64Url = token.split('.')[1];
            const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
            const jsonPayload = decodeURIComponent(
              atob(base64)
                .split('')
                .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
                .join('')
            );
            const payload = JSON.parse(jsonPayload);
            const currentUserId = payload.user_id || payload.UserID;
            
            // Find other user ID
            const otherUserId = response.conversation.participant1_id === currentUserId 
              ? response.conversation.participant2_id 
              : response.conversation.participant1_id;
            
            // Initialize E2EE (non-blocking, won't fail if already initialized)
            initializeE2EEForConversation(conversationId, otherUserId).catch(err => 
              console.warn('[ChatWindow] E2EE initialization failed (will retry on send):', err)
            );
          }
        } catch (keyError) {
          console.warn('[ChatWindow] Failed to initialize E2EE (will retry on send):', keyError);
        }
        
        // If there are unread messages, mark as read immediately on open (mobile-first UX)
        if ((response.conversation.unread_count || 0) > 0 && !markAsReadInFlightRef.current) {
          markAsReadImmediately();
        }
      }
    } catch (error) {
      console.error('Failed to load conversation:', error);
    }
  };

  // Instant mark as read with debouncing to prevent rate limiting
  const markAsReadImmediately = async () => {
    // Prevent duplicate requests (rate limiting protection)
    if (markAsReadInFlightRef.current) {
      console.log('[ChatWindow] ⏭️ Mark as read already in flight, skipping');
      return;
    }
    
    // Debounce: don't mark as read if we just marked it recently (within 2 seconds)
    const now = Date.now();
    if (now - lastMarkedReadAtRef.current < 2000) {
      console.log('[ChatWindow] ⏭️ Recently marked as read, skipping (debounce)');
      return;
    }
    
    markAsReadInFlightRef.current = true;
    lastMarkedReadAtRef.current = now;
    
    try {
      // Update server FIRST
      await messagesAPI.markAsRead(conversationId);
      console.log('[ChatWindow] ✅ Marked as read on server');
      
      // Then trigger badge update (AFTER server confirms)
      window.dispatchEvent(new CustomEvent('messages_marked_read', { 
        detail: { conversationId } 
      }));
      console.log('[ChatWindow] 📤 Dispatched messages_marked_read event');
    } catch (err) {
      console.error('[ChatWindow] Failed to mark as read:', err);
      // Reset on error so we can retry
      lastMarkedReadAtRef.current = 0;
    } finally {
      // Reset in-flight flag after a delay to allow debouncing
      setTimeout(() => {
        markAsReadInFlightRef.current = false;
      }, 2000);
    }
  };

  // Sync loaded messages with optimistic messages (ONLY on initial load to prevent overwriting)
  const [hasInitialLoad, setHasInitialLoad] = useState(false);
  
  useEffect(() => {
    if (_loadedMessages.length > 0 && !hasInitialLoad) {
      console.log('[ChatWindow] 📥 Initial load:', _loadedMessages.length, 'messages');
      setMessages(_loadedMessages);
      setHasInitialLoad(true);
      
      // ALWAYS scroll to bottom on initial load (WhatsApp behavior)
      // Use multiple RAF to ensure DOM is fully rendered
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          const scrollElement = scrollRef.current;
          if (scrollElement) {
            scrollElement.scrollTop = scrollElement.scrollHeight;
            console.log('[ChatWindow] 📜 Auto-scrolled to bottom:', scrollElement.scrollHeight);
          }
        });
      });
    } else if (_loadedMessages.length > 0 && hasInitialLoad) {
      // For infinite scroll: merge new loaded messages without replacing existing
      console.log('[ChatWindow] 📥 Infinite scroll loaded more messages');
    }
  }, [_loadedMessages, setMessages, hasInitialLoad]);

  // Reset initial load flag when conversation changes
  useEffect(() => {
    setHasInitialLoad(false);
    console.log('[ChatWindow] 🔄 Conversation changed to:', conversationId);
  }, [conversationId]);

  // Mark as read ONLY when user scrolls (proves they're viewing)
  const [hasScrolled, setHasScrolled] = useState(false);

  useEffect(() => {
    setHasScrolled(false);
    // Reset mark-as-read state when conversation changes
    markAsReadInFlightRef.current = false;
    if (markAsReadTimeoutRef.current) {
      clearTimeout(markAsReadTimeoutRef.current);
      markAsReadTimeoutRef.current = null;
    }
    lastMarkedReadAtRef.current = 0;
  }, [conversationId]);

  // Only mark as read when user SCROLLS (proves they're reading)
  const handleChatInteraction = () => {
    if (!hasScrolled && isChatVisible && !document.hidden) {
      console.log('[ChatWindow] 👆 User scrolled - marking as read');
      setHasScrolled(true);
      
      // Clear any existing timeout
      if (markAsReadTimeoutRef.current) {
        clearTimeout(markAsReadTimeoutRef.current);
      }
      
      // Mark as read after scroll (only if not already in flight)
      if (!markAsReadInFlightRef.current) {
        markAsReadTimeoutRef.current = setTimeout(() => {
          markAsReadImmediately();
          markAsReadTimeoutRef.current = null;
        }, 200);
      }
    }
  };

  // Auto-mark as read when new messages arrive in active chat (with debouncing)
  useEffect(() => {
    // Clear any existing timeout
    if (markAsReadTimeoutRef.current) {
      clearTimeout(markAsReadTimeoutRef.current);
      markAsReadTimeoutRef.current = null;
    }
    
    if (messages.length > 0 && isChatVisible && !document.hidden && hasScrolled) {
      // User is actively viewing, mark new messages as read
      const hasUnreadMessages = messages.some(m => !m.is_mine && m.status !== 'read');
      if (hasUnreadMessages && !markAsReadInFlightRef.current) {
        console.log('[ChatWindow] 📖 New messages arrived in active chat, scheduling mark as read');
        markAsReadTimeoutRef.current = setTimeout(() => {
          markAsReadImmediately();
          markAsReadTimeoutRef.current = null;
        }, 500);
      }
    }
    
    // Cleanup timeout on unmount
    return () => {
      if (markAsReadTimeoutRef.current) {
        clearTimeout(markAsReadTimeoutRef.current);
        markAsReadTimeoutRef.current = null;
      }
    };
  }, [messages.length, isChatVisible, hasScrolled]);

  // ==================== WEBSOCKET LISTENERS ====================
  // Note: useOptimisticMessages already handles new_message, message_delivered, message_read
  // We only need to handle typing indicators here

  useEffect(() => {
    // Listen for typing indicators with user info (instant)
    const unsubscribeTyping = messageWS.on('typing', (data: any) => {
      console.log('[ChatWindow] Typing event received:', data);
      
      if (data.conversation_id === conversationId) {
        setTypingUsers((prev) => {
          // Check if user already in list
          const existing = prev.find((u) => u.user_id === data.user_id);
          if (existing) {
            // Update existing user
            return prev.map((u) =>
              u.user_id === data.user_id
                ? { ...u, is_recording: data.is_recording || false }
                : u
            );
          }
          // Add new typing user
          return [
            ...prev,
            {
              user_id: data.user_id,
              display_name: data.display_name || 'User',
              is_recording: data.is_recording || false,
            },
          ];
        });
      }
    });

    const unsubscribeStopTyping = messageWS.on('stop_typing', (data: any) => {
      console.log('[ChatWindow] Stop typing event received:', data);
      
      if (data.conversation_id === conversationId) {
        // Remove user from typing list
        setTypingUsers((prev) => prev.filter((u) => u.user_id !== data.user_id));
      }
    });

    // Listen for forwarded messages (custom event from other ChatWindow)
    const handleMessageForwarded = (event: any) => {
      const { conversationId: targetConvId, message } = event.detail;
      console.log('[ChatWindow] Received message_forwarded event for:', targetConvId);
      
      if (targetConvId === conversationId) {
        console.log('[ChatWindow] Adding forwarded message to this conversation');
        const updatedMessages = [...messages, message];
        setMessages(updatedMessages);
        
        requestAnimationFrame(() => {
          scrollToBottom(true);
        });
      }
    };

    window.addEventListener('message_forwarded', handleMessageForwarded as EventListener);

    return () => {
      unsubscribeTyping();
      unsubscribeStopTyping();
      window.removeEventListener('message_forwarded', handleMessageForwarded as EventListener);
    };
  }, [conversationId, messages, setMessages]);

  // ==================== SCROLL TO BOTTOM BUTTON ====================

  // Detect scroll position in real-time
  const checkScrollPosition = () => {
    const scrollElement = scrollRef.current;
    if (!scrollElement) return;

    const { scrollTop, scrollHeight, clientHeight } = scrollElement;
    const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
    
    // Show button if scrolled up more than 100px (even one message)
    const shouldShow = distanceFromBottom > 100;
    setShowScrollButton(shouldShow);
    setIsUserAtBottom(!shouldShow);

    // If user scrolls to bottom, reset unread count
    if (!shouldShow) {
      setUnreadWhileScrolledUp(0);
    }
  };

  // Enhanced handleScroll to include scroll button logic
  const handleScrollWithButton = () => {
    handleScroll(); // Original infinite scroll logic
    checkScrollPosition(); // Check if button should show
    handleChatInteraction(); // Mark as read when scrolling
  };

  // Detect new messages while scrolled up - track previous length
  const [prevMessageCount, setPrevMessageCount] = useState(0);
  
  useEffect(() => {
    if (!isUserAtBottom && messages.length > prevMessageCount) {
      // New message(s) arrived while user is scrolled up
      const newMessages = messages.slice(prevMessageCount);
      const newUnreadCount = newMessages.filter(msg => !msg.is_mine).length;
      
      if (newUnreadCount > 0) {
        // Increment unread count by number of new messages from others
        setUnreadWhileScrolledUp(prev => prev + newUnreadCount);
      }
    } else if (isUserAtBottom && messages.length > prevMessageCount) {
      // User is at bottom - auto-scroll to show new messages (WhatsApp behavior)
      const newMessages = messages.slice(prevMessageCount);
      const hasNewMessages = newMessages.length > 0;
      
      if (hasNewMessages) {
        console.log('[ChatWindow] 📜 New messages while at bottom, auto-scrolling');
        requestAnimationFrame(() => {
          scrollToBottom(true); // Smooth scroll
        });
      }
    }
    
    // Update previous count
    setPrevMessageCount(messages.length);
  }, [messages, isUserAtBottom, prevMessageCount, scrollToBottom]);

  // Reset unread count when conversation changes
  useEffect(() => {
    setUnreadWhileScrolledUp(0);
    setShowScrollButton(false);
    setIsUserAtBottom(true);
    setPrevMessageCount(0);
  }, [conversationId]);

  // Handle scroll to bottom button click
  const handleScrollToBottomClick = () => {
    scrollToBottom(true);
    setUnreadWhileScrolledUp(0);
    setShowScrollButton(false);
    setIsUserAtBottom(true);
  };

  // ==================== SEND MESSAGE ====================

  const handleSendMessage = async (text: string) => {
    console.log('[ChatWindow] handleSendMessage called - text:', text, 'isRecording:', isRecording);
    
    if (!text.trim() && !isRecording) {
      console.log('[ChatWindow] ⚠️ No text and not recording, skipping send');
      return;
    }

    if (isRecording) {
      // Stop recording and send voice message
      console.log('[ChatWindow] 🎤 Stopping recording and sending voice message...');
      const audioBlob = await stopRecording();
      if (audioBlob) {
        console.log('[ChatWindow] ✅ Audio blob received, size:', audioBlob.size);
        await handleSendVoice(audioBlob);
      } else {
        console.log('[ChatWindow] ❌ No audio blob received');
      }
    } else {
      // Send text message
      console.log('[ChatWindow] 📝 Sending text message');
      await sendMessage(text, replyingTo?.id);
      setReplyingTo(null);
      scrollToBottom(true);
    }
  };

  // ==================== VOICE RECORDING HANDLERS ====================

  const handleSendVoice = async (audioBlob: Blob) => {
    const uploadId = `upload_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    try {
      // Start progress tracking
      const abortSignal = startUpload(uploadId, 'voice-message.webm');
      updateProgress(uploadId, 5);

      // Compress audio with FFmpeg (64kbps mono for voice)
      console.log('[ChatWindow] Compressing voice message with FFmpeg...');
      const compressionResult = await compressAudio(audioBlob, {
        bitrate: 64,
        mono: true,
        onProgress: (p) => updateProgress(uploadId, 5 + (p * 0.30)), // 5% to 35%
      });

      const compressedBlob = compressionResult.compressedBlob;
      const savingsPercent = Math.round((1 - compressionResult.compressionRatio) * 100);
      
      if (savingsPercent > 10) {
        console.log(`[ChatWindow] Audio compressed: ${(audioBlob.size / 1024).toFixed(1)}KB → ${(compressedBlob.size / 1024).toFixed(1)}KB (${savingsPercent}% smaller)`);
        toast.success(`Compressed ${savingsPercent}% smaller`);
      }

      updateProgress(uploadId, 40);

      // Upload compressed audio with progress tracking
      const uploadResponse: any = await messagesAPI.uploadAudio(
        compressedBlob,
        'voice-message.webm',
        abortSignal,
        (progress) => updateProgress(uploadId, 40 + (progress * 0.55)) // 40% to 95%
      );
      
      updateProgress(uploadId, 98);

      if (uploadResponse.success) {
        // Complete upload
        completeUpload(uploadId);

        // Send as audio message
        await sendMessageWithAttachment(
          'Voice message',
          uploadResponse.url,
          uploadResponse.name,
          uploadResponse.size,
          uploadResponse.type,
          'audio'
        );

        scrollToBottom(true);
      }
    } catch (error) {
      console.error('Failed to send voice message:', error);
      
      if (error instanceof Error && error.message === 'Upload cancelled') {
        toast.info('Upload cancelled');
      } else {
        failUpload(uploadId, error instanceof Error ? error.message : 'Upload failed');
        toast.error('Failed to send voice message');
      }
    }
  };

  // ==================== IMAGE PREVIEW EDITOR ====================

  const handleImageSelected = (file: File) => {
    // Show preview editor (WhatsApp-style)
    setPendingImageFile(file);
  };

  const handleSendFromEditor = async (editedFile: File, caption: string, isHD: boolean) => {
    // Close editor
    setPendingImageFile(null);
    
    // Send with selected quality and caption
    const quality = isHD ? 'hd' : 'standard';
    
    // If there's a caption, we'll add it to the message
    // For now, send the image (caption feature can be enhanced in Phase 2)
    await handleSendImage(editedFile, quality);
    
    // TODO: If caption is provided, could send as separate text message
    if (caption.trim()) {
      await sendMessage(caption);
    }
  };

  // ==================== SEND IMAGE ====================

  const handleSendImage = async (file: File, quality: 'standard' | 'hd' = 'standard') => {
    const uploadId = `upload_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    try {
      // Start progress tracking with cancellation support
      const abortSignal = startUpload(uploadId, file.name);

      // Compress image on client side
      updateProgress(uploadId, 20);
      const compressed = await compressImage(file, quality);
      
      updateProgress(uploadId, 40);

      // Upload image with real progress tracking and cancellation
      const uploadResponse: any = await messagesAPI.uploadImage(
        compressed, 
        quality,
        abortSignal,
        (progress) => updateProgress(uploadId, 40 + (progress * 0.5)) // 40% to 90%
      );
      
      updateProgress(uploadId, 95);

      if (uploadResponse.success) {
        // Complete upload
        completeUpload(uploadId);

        // Send as image message
        await sendMessageWithAttachment(
          'Photo',
          uploadResponse.url,
          uploadResponse.name,
          uploadResponse.size,
          uploadResponse.type,
          'image'
        );

        scrollToBottom(true);
      }
    } catch (error) {
      console.error('Failed to send image:', error);
      
      if (error instanceof Error && error.message === 'Upload cancelled') {
        toast.info('Upload cancelled');
      } else {
        failUpload(uploadId, error instanceof Error ? error.message : 'Upload failed');
        toast.error('Failed to send image');
      }
    }
  };

  const handleSendFile = async (file: File) => {
    const uploadId = `upload_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    try {
      // Determine if it's audio or document
      const isAudio = file.type.startsWith('audio/');
      const messageType = isAudio ? 'audio' : 'file';
      
      // Start progress tracking with cancellation
      const abortSignal = startUpload(uploadId, file.name);
      updateProgress(uploadId, 10);
      
      // Upload file with real progress tracking
      let uploadResponse: any;
      
      if (isAudio) {
        uploadResponse = await messagesAPI.uploadAudio(
          file,
          file.name,
          abortSignal,
          (progress) => updateProgress(uploadId, 10 + (progress * 0.85)) // 10% to 95%
        );
      } else {
        uploadResponse = await messagesAPI.uploadFile(
          file,
          abortSignal,
          (progress) => updateProgress(uploadId, 10 + (progress * 0.85)) // 10% to 95%
        );
      }
      
      updateProgress(uploadId, 98);

      if (uploadResponse.success) {
        // Complete upload
        completeUpload(uploadId);

        // Send as file/audio message
        await sendMessageWithAttachment(
          isAudio ? 'Audio file' : file.name,
          uploadResponse.url,
          uploadResponse.name,
          uploadResponse.size,
          uploadResponse.type,
          messageType
        );

        scrollToBottom(true);
      }
    } catch (error) {
      console.error('Failed to send file:', error);
      
      if (error instanceof Error && error.message === 'Upload cancelled') {
        toast.info('Upload cancelled');
      } else {
        failUpload(uploadId, error instanceof Error ? error.message : 'Upload failed');
        toast.error('Failed to send file');
      }
    }
  };

  // ==================== VIDEO UPLOAD ====================

  const handleVideoSelected = async (file: File) => {
    try {
      // Get video metadata
      const video = document.createElement('video');
      video.preload = 'metadata';

      video.onloadedmetadata = () => {
        setVideoDuration(Math.round(video.duration));
        setPendingVideoFile(file);
        URL.revokeObjectURL(video.src);
      };

      video.onerror = () => {
        toast.error('Invalid video file');
      };

      video.src = URL.createObjectURL(file);
    } catch (error) {
      console.error('Failed to load video:', error);
      toast.error('Failed to load video');
    }
  };

  const handleSendVideo = async (file: File, quality: 'standard' | 'hd') => {
    const uploadId = `upload_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    try {
      setPendingVideoFile(null);

      // Start progress tracking
      const abortSignal = startUpload(uploadId, file.name);
      updateProgress(uploadId, 5);

      toast.info('Compressing video with FFmpeg... This may take a moment.');

      // Compress video with FFmpeg
      console.log(`[ChatWindow] Compressing video to ${quality} quality...`);
      const compressionResult = await compressVideo(file, {
        quality,
        onProgress: (p) => updateProgress(uploadId, 5 + (p * 0.60)), // 5% to 65%
      });

      const compressedVideo = compressionResult.compressedBlob;
      const thumbnail = compressionResult.thumbnail;
      const savingsPercent = Math.round((1 - compressionResult.compressionRatio) * 100);

      if (savingsPercent > 10) {
        console.log(`[ChatWindow] Video compressed: ${(file.size / (1024 * 1024)).toFixed(1)}MB → ${(compressedVideo.size / (1024 * 1024)).toFixed(1)}MB (${savingsPercent}% smaller)`);
        toast.success(`Video compressed ${savingsPercent}% smaller!`);
      }

      updateProgress(uploadId, 70);

      // Convert base64 thumbnail to blob
      const thumbnailBlob = await fetch(thumbnail).then(r => r.blob());

      // Upload compressed video with thumbnail
      const uploadResponse: any = await messagesAPI.uploadVideo(
        new File([compressedVideo], file.name, { type: 'video/mp4' }),
        thumbnailBlob,
        abortSignal,
        (progress) => updateProgress(uploadId, 70 + (progress * 0.25)) // 70% to 95%
      );

      updateProgress(uploadId, 98);

      if (uploadResponse.success) {
        // Complete upload
        completeUpload(uploadId);

        // Send as video message with metadata
        await sendMessageWithAttachment(
          'Video',
          uploadResponse.url,
          uploadResponse.name || file.name,
          uploadResponse.size || compressedVideo.size,
          uploadResponse.type || 'video/mp4',
          'video',
          replyingTo?.id
        );

        toast.success('Video sent successfully!');
        setReplyingTo(null);
        scrollToBottom(true);
      }
    } catch (error) {
      console.error('Failed to send video:', error);
      
      if (error instanceof Error && error.message === 'Upload cancelled') {
        toast.info('Upload cancelled');
      } else {
        failUpload(uploadId, error instanceof Error ? error.message : 'Upload failed');
        toast.error('Failed to send video');
      }
    }
  };

  // ==================== MESSAGE ACTIONS ====================

  const handleReact = async (messageId: string, emoji: string) => {
    try {
      console.log('[ChatWindow] Adding reaction:', emoji, 'to message:', messageId);
      const response = await messagesAPI.addReaction(messageId, emoji);
      
      if (response.removed) {
        console.log('[ChatWindow] ✅ Reaction removed (toggled off)');
        toast.info(`Removed ${emoji} reaction`);
        
        // Remove reaction from local state
        const updatedMessages = messages.map((msg: Message) =>
          msg.id === messageId
            ? {
                ...msg,
                reactions: msg.reactions?.filter((r: any) => r.emoji !== emoji) || [],
              }
            : msg
        );
        setMessages(updatedMessages);
      } else {
        console.log('[ChatWindow] ✅ Reaction added successfully');
        toast.success(`Reacted with ${emoji}`);
        
        // Add reaction to local state (optimistic UI)
        const newReaction = response.reaction;
        const updatedMessages = messages.map((msg: Message) =>
          msg.id === messageId
            ? {
                ...msg,
                reactions: [...(msg.reactions || []), newReaction],
              }
            : msg
        );
        setMessages(updatedMessages);
      }
    } catch (error) {
      console.error('[ChatWindow] ❌ Failed to add reaction:', error);
      toast.error('Failed to add reaction');
    }
  };

  const handleReply = (message: Message) => {
    setReplyingTo(message);
  };

  const handleStar = async (messageId: string, isStarred: boolean) => {
    try {
      if (isStarred) {
        await messagesAPI.unstarMessage(messageId);
      } else {
        await messagesAPI.starMessage(messageId);
      }
    } catch (error) {
      console.error('Failed to star message:', error);
    }
  };

  const handleDelete = async (messageId: string) => {
    const message = messages.find(m => m.id === messageId);
    if (!message) return;

    // Show confirmation dialog
    setDeleteConfirm({
      messageId,
      isMine: message.is_mine || false,
      type: message.is_mine ? 'unsend' : 'delete_for_me',
    });
  };

  const confirmDelete = async () => {
    if (!deleteConfirm) return;

    try {
      // Optimistic UI - remove message immediately
      removeMessage(deleteConfirm.messageId);
      console.log('[ChatWindow] 🗑️ Optimistically removed message:', deleteConfirm.messageId);

      // Delete on server
      await messagesAPI.deleteMessage(deleteConfirm.messageId);
      console.log('[ChatWindow] ✅ Message deleted on server:', deleteConfirm.messageId);

      // Show success toast
      if (deleteConfirm.type === 'unsend') {
        toast.success('Message deleted for everyone');
      } else {
        toast.success('Message deleted');
      }
    } catch (error) {
      console.error('[ChatWindow] ❌ Failed to delete message:', error);
      toast.error('Failed to delete message');
      // Reload messages to restore the message
      window.location.reload();
    } finally {
      setDeleteConfirm(null);
    }
  };

  const handleForward = (message: Message) => {
    setForwardingMessage(message.id);
  };

  const handleCopy = (message: Message) => {
    if (message.message_type === 'text') {
      navigator.clipboard.writeText(message.content);
      toast.success('Message copied to clipboard');
      console.log('Message copied to clipboard');
    } else {
      toast.info('Cannot copy this message type');
    }
  };

  const handlePin = async (messageId: string, isPinned: boolean) => {
    try {
      // Optimistic UI update first (instant feedback)
      const updatedMessages = messages.map((msg: Message) =>
        msg.id === messageId 
          ? { ...msg, is_pinned: !isPinned, pinned_at: isPinned ? undefined : new Date().toISOString() } 
          : msg
      );
      setMessages(updatedMessages);

      // Then call API
      if (isPinned) {
        await messagesAPI.unpinMessage(messageId);
        toast.success('Message unpinned');
      } else {
        await messagesAPI.pinMessage(messageId);
        toast.success('Message pinned');
      }
    } catch (error) {
      console.error('Failed to pin/unpin message:', error);
      toast.error('Failed to pin/unpin message');
      
      // Revert on error
      const revertedMessages = messages.map((msg: Message) =>
        msg.id === messageId 
          ? { ...msg, is_pinned: isPinned, pinned_at: isPinned ? new Date().toISOString() : undefined } 
          : msg
      );
      setMessages(revertedMessages);
    }
  };

  const handleShare = async (message: Message) => {
    if (navigator.share && message.message_type === 'text') {
      try {
        await navigator.share({
          title: 'Shared Message',
          text: message.content,
        });
        toast.success('Message shared');
      } catch (err: any) {
        if (err.name !== 'AbortError') {
          handleCopy(message); // Fallback to copy
        }
      }
    } else {
      handleCopy(message); // Fallback to copy
    }
  };

  const handleEdit = (message: Message) => {
    if (message.message_type === 'text' && message.is_mine) {
      setEditingMessage({ id: message.id, content: message.content });
    }
  };

  const handleEditComplete = (newContent: string) => {
    // Update message locally (optimistic UI)
    if (editingMessage) {
      const updatedMessages = messages.map((msg: Message) =>
        msg.id === editingMessage.id
          ? {
              ...msg,
              content: newContent,
              edited_at: new Date().toISOString(),
              edit_count: (msg.edit_count || 0) + 1,
            }
          : msg
      );
      setMessages(updatedMessages);
    }
    setEditingMessage(null);
  };

  const handleInfo = (message: Message) => {
    setInfoMessage(message);
  };

  const handleViewMedia = (message: Message) => {
    setViewingMedia(message);
  };

  const handleSearch = async (query: string) => {
    setSearchQuery(query);
    if (query.trim()) {
      try {
        const response = await messagesAPI.searchConversationMessages(conversationId, query);
        if (response.success) {
          setSearchResults(response.messages);
          toast.success(`Found ${response.messages.length} message(s)`);
        }
      } catch (error) {
        console.error('Search failed:', error);
        toast.error('Search failed');
        setSearchResults([]);
      }
    } else {
      setSearchResults([]);
      setShowPinnedOnly(false);
    }
  };

  const handleShowPinned = async () => {
    if (showPinnedOnly) {
      // Close pinned view
      setShowPinnedOnly(false);
      setSearchResults([]);
    } else {
      // Show pinned messages
      try {
        const response = await messagesAPI.getPinnedMessages(conversationId);
        if (response.success) {
          setSearchResults(response.messages);
          setShowPinnedOnly(true);
          toast.success(`${response.messages.length} pinned message(s)`);
        }
      } catch (error) {
        console.error('Failed to load pinned messages:', error);
        toast.error('Failed to load pinned messages');
      }
    }
  };

  // ==================== RENDER ====================

  if (!conversation) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600"></div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full min-h-screen md:min-h-0 relative">
      {/* Network Status Bar */}
      <NetworkStatusBar />

      {/* Header */}
      <ChatHeader 
        conversation={conversation} 
        onClose={onClose}
        onSearch={handleSearch}
        onShowPinned={handleShowPinned}
        pinnedCount={pinnedCount}
        onShowProfile={() => setShowProfileDialog(true)}
      />

      {/* Messages Body */}
      <div
        ref={scrollRef}
        data-message-scroll
        onScroll={handleScrollWithButton}
        className="flex-1 overflow-y-auto p-4 space-y-2 bg-gray-50 dark:bg-gray-900 relative"
      >
        {/* Load more indicator */}
        {hasMore && (
          <div className="text-center py-2">
            {isLoadingMore ? (
              <div className="inline-block animate-spin rounded-full h-5 w-5 border-b-2 border-purple-600"></div>
            ) : (
              <button
                onClick={loadMore}
                className="text-sm text-purple-600 hover:text-purple-700 font-medium px-4 py-2 rounded-lg hover:bg-purple-50 dark:hover:bg-purple-900/20 transition-colors"
              >
                Load older messages
              </button>
            )}
          </div>
        )}

        {/* Search/Pinned Banner */}
        {(searchQuery || showPinnedOnly) && (
          <div className="sticky top-0 bg-purple-50 dark:bg-purple-900/30 border-b border-purple-200 dark:border-purple-800 px-4 py-2 z-10">
            <p className="text-sm text-purple-700 dark:text-purple-300 font-medium">
              {showPinnedOnly ? `📌 Showing ${searchResults.length} pinned message(s)` : `🔍 Search results: ${searchResults.length} message(s)`}
            </p>
          </div>
        )}

        {/* Messages - Virtual Scrolling or Standard */}
        {useVirtualScroll && !searchQuery && !showPinnedOnly ? (
          <VirtualMessageList
            messages={messages}
            isLoadingMore={isLoadingMore}
            hasMore={hasMore}
            onLoadMore={loadMore}
            onScroll={handleScroll}
            onReact={handleReact}
            onReply={handleReply}
            onStar={handleStar}
            onDelete={handleDelete}
            onForward={handleForward}
            onCopy={handleCopy}
            onPin={handlePin}
            onShare={handleShare}
            onEdit={handleEdit}
            onInfo={handleInfo}
            onViewMedia={handleViewMedia}
            onRetry={retryMessage}
          />
        ) : (
          // Fallback: Standard rendering for search/pinned results
          (searchQuery || showPinnedOnly ? searchResults : messages).map((message) => (
            <MessageBubble
              key={message.id}
              message={message}
              onReact={handleReact}
              onReply={handleReply}
              onStar={handleStar}
              onDelete={handleDelete}
              onForward={handleForward}
              onCopy={handleCopy}
              onPin={handlePin}
              onShare={handleShare}
              onEdit={handleEdit}
              onInfo={handleInfo}
              onViewMedia={handleViewMedia}
              onRetry={retryMessage}
            />
          ))
        )}

        {/* Upload Progress Indicators */}
        {uploads.length > 0 && (
          <div className="space-y-2">
            {uploads.map((upload) => (
              <UploadProgressBar
                key={upload.uploadId}
                upload={upload}
                onCancel={cancelUpload}
              />
            ))}
          </div>
        )}

        {/* Typing Indicator */}
        <TypingIndicator typingUsers={typingUsers} />

        {/* Scroll to Bottom Button - WhatsApp Style */}
        {showScrollButton && (
          <div className="sticky bottom-4 left-0 right-0 flex justify-end pr-2 pointer-events-none z-10 animate-fade-in-up">
            <button
              onClick={handleScrollToBottomClick}
              className="pointer-events-auto bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-full p-2 shadow-lg border border-gray-300 dark:border-gray-600 transition-all duration-150 hover:scale-105 active:scale-95 relative group"
              aria-label="Scroll to bottom"
            >
              {/* Unread Badge */}
              {unreadWhileScrolledUp > 0 && (
                <div className="absolute -top-1 -right-1 bg-gradient-to-r from-purple-600 to-purple-700 text-white text-[10px] font-bold rounded-full min-w-[18px] h-[18px] flex items-center justify-center px-1.5 shadow-lg border-2 border-white dark:border-gray-800 animate-scale-bounce">
                  {unreadWhileScrolledUp > 99 ? '99+' : unreadWhileScrolledUp}
                </div>
              )}
              
              {/* Chevron Icon */}
              <ChevronDown className="w-4 h-4 text-gray-700 dark:text-gray-300 group-hover:text-purple-600 dark:group-hover:text-purple-400 transition-colors" strokeWidth={2.5} />
            </button>
          </div>
        )}
      </div>

      {/* Footer */}
      <ChatFooter
        conversationId={conversationId}
        onSendMessage={handleSendMessage}
        onSendImage={handleImageSelected}
        onSendFile={handleSendFile}
        onSendVideo={handleVideoSelected}
        onStartVoiceRecording={startRecording}
        onPauseVoiceRecording={pauseRecording}
        onResumeVoiceRecording={resumeRecording}
        onCancelVoiceRecording={cancelRecording}
        isRecording={isRecording}
        isPaused={isPaused}
        recordingDuration={duration}
        replyingTo={replyingTo}
        onCancelReply={() => setReplyingTo(null)}
      />

      {/* Delete Confirmation Dialog */}
      {deleteConfirm && (
        <ConfirmDialog
          isOpen={true}
          title={deleteConfirm.type === 'unsend' ? 'Delete for everyone?' : 'Delete for you?'}
          message={
            deleteConfirm.type === 'unsend'
              ? 'This message will be deleted for everyone in the chat. This cannot be undone.'
              : 'This message will be deleted for you. The sender will still see it.'
          }
          confirmText="Delete"
          cancelText="Cancel"
          variant="danger"
          onConfirm={confirmDelete}
          onCancel={() => setDeleteConfirm(null)}
        />
      )}

      {/* Edit Message Dialog */}
      {editingMessage && (
        <EditMessageDialog
          isOpen={true}
          messageId={editingMessage.id}
          currentContent={editingMessage.content}
          onClose={() => setEditingMessage(null)}
          onEdit={handleEditComplete}
        />
      )}

      {/* Forward Message Dialog */}
      {forwardingMessage && (
        <ForwardMessageDialog
          isOpen={true}
          messageId={forwardingMessage}
          currentConversationId={conversationId}
          onClose={() => setForwardingMessage(null)}
          onForward={(forwardedMessage, targetConversationId) => {
            console.log('[ChatWindow] Message forwarded to:', targetConversationId, 'Current:', conversationId);
            console.log('[ChatWindow] Forwarded message:', forwardedMessage);
            
            // If forwarded to the CURRENT conversation, add it to local state immediately
            if (targetConversationId === conversationId) {
              console.log('[ChatWindow] Adding forwarded message to current conversation');
              const updatedMessages = [...messages, forwardedMessage];
              setMessages(updatedMessages);
              
              // Scroll to show the new forwarded message
              requestAnimationFrame(() => {
                scrollToBottom(true);
              });
            } else {
              console.log('[ChatWindow] Message forwarded to different conversation');
              // Dispatch event to notify other ChatWindow instances
              window.dispatchEvent(new CustomEvent('message_forwarded', {
                detail: { conversationId: targetConversationId, message: forwardedMessage }
              }));
            }
            
            setForwardingMessage(null);
          }}
        />
      )}

      {/* Message Info Dialog */}
      {infoMessage && (
        <MessageInfoDialog
          isOpen={true}
          message={infoMessage}
          onClose={() => setInfoMessage(null)}
        />
      )}

      {/* Chat Profile Dialog */}
      <ChatProfileDialog
        isOpen={showProfileDialog}
        conversation={conversation}
        onClose={() => setShowProfileDialog(false)}
        onViewProfile={() => {
          setShowProfileDialog(false);
          if (conversation.other_user?.username) {
            window.location.href = `/profile/${conversation.other_user.username}`;
          }
        }}
      />

      {/* Media Viewer - WhatsApp Style */}
      {viewingMedia && (
        <MediaViewer
          isOpen={true}
          message={viewingMedia}
          allMedia={messages.filter(m => m.message_type === 'image' || m.message_type === 'audio' || m.message_type === 'file' || m.message_type === 'video')}
          onClose={() => setViewingMedia(null)}
        />
      )}

      {/* Image Preview Editor - WhatsApp Style */}
      {pendingImageFile && (
        <ImagePreviewEditor
          isOpen={true}
          file={pendingImageFile}
          onSend={handleSendFromEditor}
          onCancel={() => setPendingImageFile(null)}
        />
      )}

      {/* Video Quality Dialog */}
      {pendingVideoFile && (
        <VideoQualityDialog
          isOpen={true}
          videoFile={pendingVideoFile}
          videoDuration={videoDuration}
          onSelect={(quality) => handleSendVideo(pendingVideoFile, quality)}
          onCancel={() => setPendingVideoFile(null)}
        />
      )}
    </div>
  );
}


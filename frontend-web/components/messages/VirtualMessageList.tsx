'use client';

import { useRef, useEffect, memo, useCallback } from 'react';
import { Message } from '@/lib/api/messages';
import MessageBubble from './MessageBubble';

interface VirtualMessageListProps {
  messages: Message[];
  isLoadingMore: boolean;
  hasMore: boolean;
  onLoadMore: () => void;
  onScroll?: () => void;
  // Message handlers
  onReact: (messageId: string, emoji: string) => void;
  onReply: (message: Message) => void;
  onStar: (messageId: string, isStarred: boolean) => void;
  onDelete: (messageId: string) => void;
  onForward?: (message: Message) => void;
  onCopy?: (message: Message) => void;
  onPin?: (messageId: string, isPinned: boolean) => void;
  onShare?: (message: Message) => void;
  onInfo?: (message: Message) => void;
  onEdit?: (message: Message) => void;
  onViewMedia?: (message: Message) => void;
  onRetry?: (tempId: string) => void;
}

// Memoized MessageBubble to prevent unnecessary re-renders
const MemoizedMessageBubble = memo(MessageBubble, (prevProps, nextProps) => {
  // Only re-render if message data actually changed
  return (
    prevProps.message.id === nextProps.message.id &&
    prevProps.message.content === nextProps.message.content &&
    prevProps.message.status === nextProps.message.status &&
    prevProps.message.is_pinned === nextProps.message.is_pinned &&
    prevProps.message.is_starred === nextProps.message.is_starred &&
    prevProps.message.edited_at === nextProps.message.edited_at &&
    prevProps.message.reactions?.length === nextProps.message.reactions?.length &&
    prevProps.message.send_state === nextProps.message.send_state
  );
});

MemoizedMessageBubble.displayName = 'MemoizedMessageBubble';

export default function VirtualMessageList({
  messages,
  isLoadingMore,
  hasMore,
  onLoadMore,
  onScroll,
  onReact,
  onReply,
  onStar,
  onDelete,
  onForward,
  onCopy,
  onPin,
  onShare,
  onInfo,
  onEdit,
  onViewMedia,
  onRetry,
}: VirtualMessageListProps) {
  const listRef = useRef<any>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const itemSizeCache = useRef<Map<number, number>>(new Map());
  const measurementDivRef = useRef<HTMLDivElement>(null);

  // Calculate message height (with caching)
  const getItemSize = useCallback((index: number): number => {
    // Check cache first
    if (itemSizeCache.current.has(index)) {
      return itemSizeCache.current.get(index)!;
    }

    // Estimate based on message type
    const message = messages[index];
    if (!message) return 100;

    let estimatedHeight = 80; // Base height for text messages

    switch (message.message_type) {
      case 'image':
        estimatedHeight = 300; // Images are taller
        break;
      case 'video':
        estimatedHeight = 350; // Videos with controls
        break;
      case 'audio':
        estimatedHeight = 100; // Audio player height
        break;
      case 'file':
        estimatedHeight = 120; // Document preview
        break;
      case 'text':
        // Estimate based on content length
        const lines = Math.ceil(message.content.length / 40);
        estimatedHeight = 60 + (lines * 20);
        break;
    }

    // Add extra height for reactions, reply previews
    if (message.reactions && message.reactions.length > 0) {
      estimatedHeight += 30;
    }
    if (message.reply_to) {
      estimatedHeight += 60;
    }

    itemSizeCache.current.set(index, estimatedHeight);
    return estimatedHeight;
  }, [messages]);

  // Clear cache when messages change significantly
  useEffect(() => {
    itemSizeCache.current.clear();
    listRef.current?.resetAfterIndex(0);
  }, [messages.length]);

  // Handle scroll - load more when near top
  const handleScroll = ({ scrollOffset, scrollDirection }: { scrollOffset: number; scrollDirection: 'forward' | 'backward' }) => {
    onScroll?.();

    // Load more when scrolled near top (within 500px)
    if (scrollDirection === 'backward' && scrollOffset < 500 && hasMore && !isLoadingMore) {
      console.log('[VirtualMessageList] Near top, loading more messages');
      onLoadMore();
    }
  };

  // Scroll to bottom method (exposed via ref)
  const scrollToBottom = useCallback(() => {
    if (listRef.current && messages.length > 0) {
      listRef.current.scrollToItem(messages.length - 1, 'end');
    }
  }, [messages.length]);

  // Expose scrollToBottom method via window for external access
  useEffect(() => {
    (window as any).virtualScrollToBottom = scrollToBottom;
    return () => {
      delete (window as any).virtualScrollToBottom;
    };
  }, [scrollToBottom]);

  // Auto-scroll to bottom on new messages (only if user is at bottom)
  useEffect(() => {
    const timer = setTimeout(() => {
      // Only auto-scroll if near bottom already
      if (listRef.current) {
        const list = listRef.current as any;
        const scrollOffset = list.state?.scrollOffset || 0;
        const totalHeight = messages.length * 100; // Rough estimate
        
        if (scrollOffset + 600 > totalHeight - 200) {
          scrollToBottom();
        }
      }
    }, 100);
    return () => clearTimeout(timer);
  }, [messages.length]);

  // Row renderer
  const Row = ({ index, style }: { index: number; style: React.CSSProperties }) => {
    const message = messages[index];
    
    if (!message) {
      return <div style={style} />;
    }

    return (
      <div style={style} id={`message-${message.id}`}>
        <MemoizedMessageBubble
          message={message}
          onReact={onReact}
          onReply={onReply}
          onStar={onStar}
          onDelete={onDelete}
          onForward={onForward}
          onCopy={onCopy}
          onPin={onPin}
          onShare={onShare}
          onInfo={onInfo}
          onEdit={onEdit}
          onViewMedia={onViewMedia}
          onRetry={onRetry}
        />
      </div>
    );
  };

  return (
    <>
      {/* Loading More Indicator */}
      {isLoadingMore && (
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-10 bg-purple-600 text-white px-4 py-2 rounded-full text-sm font-medium shadow-lg">
          Loading more messages...
        </div>
      )}

      {/* Virtual List - Renders only visible messages */}
      {messages.map((message) => (
        <MemoizedMessageBubble
          key={message.id}
          message={message}
          onReact={onReact}
          onReply={onReply}
          onStar={onStar}
          onDelete={onDelete}
          onForward={onForward}
          onCopy={onCopy}
          onPin={onPin}
          onShare={onShare}
          onEdit={onEdit}
          onInfo={onInfo}
          onViewMedia={onViewMedia}
          onRetry={onRetry}
        />
      ))}
    </>
  );
}


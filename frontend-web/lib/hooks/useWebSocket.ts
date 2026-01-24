/**
 * useWebSocket - React hook for WebSocket connection state and message handling
 * 
 * Provides easy access to unified WebSocket service with React lifecycle management
 */

import { useEffect, useState, useCallback, useRef } from 'react';
import { unifiedWS, type WSMessageType, type WSMessageEnvelope } from '../websocket/UnifiedWebSocket';

interface UseWebSocketOptions {
  autoConnect?: boolean;
  onConnect?: () => void;
  onDisconnect?: () => void;
  onError?: (error: Event) => void;
}

/**
 * Hook for WebSocket connection state and message handling
 */
export function useWebSocket(options: UseWebSocketOptions = {}) {
  const { autoConnect = true, onConnect, onDisconnect, onError } = options;
  
  const [isConnected, setIsConnected] = useState(false);
  const [connectionState, setConnectionState] = useState<'disconnected' | 'connecting' | 'connected' | 'closing'>('disconnected');
  const handlersRef = useRef<Map<WSMessageType | string, Set<(data: any, envelope?: WSMessageEnvelope) => void>>>(new Map());

  // Auto-connect on mount
  useEffect(() => {
    if (autoConnect) {
      const token = localStorage.getItem('token');
      if (token) {
        unifiedWS.connect(token);
      }
    }

    // Listen to connection state changes
    const unsubscribe = unifiedWS.onConnectionStateChange((connected) => {
      setIsConnected(connected);
      setConnectionState(unifiedWS.getConnectionState());
      
      if (connected && onConnect) {
        onConnect();
      } else if (!connected && onDisconnect) {
        onDisconnect();
      }
    });

    return () => {
      unsubscribe();
      // Cleanup all handlers
      handlersRef.current.forEach((handlers, eventType) => {
        handlers.forEach(handler => {
          unifiedWS.off(eventType, handler);
        });
      });
      handlersRef.current.clear();
    };
  }, [autoConnect, onConnect, onDisconnect]);

  /**
   * Register event handler
   */
  const on = useCallback((eventType: WSMessageType | string, handler: (data: any, envelope?: WSMessageEnvelope) => void) => {
    if (!handlersRef.current.has(eventType)) {
      handlersRef.current.set(eventType, new Set());
    }
    
    handlersRef.current.get(eventType)!.add(handler);
    
    const unsubscribe = unifiedWS.on(eventType, handler);
    
    return () => {
      handlersRef.current.get(eventType)?.delete(handler);
      unsubscribe();
    };
  }, []);

  /**
   * Send message
   */
  const send = useCallback((message: { type: string; data?: any; channel?: string }) => {
    unifiedWS.send(message);
  }, []);

  /**
   * Connect manually
   */
  const connect = useCallback((token: string) => {
    unifiedWS.connect(token);
  }, []);

  /**
   * Disconnect manually
   */
  const disconnect = useCallback(() => {
    unifiedWS.disconnect();
  }, []);

  return {
    isConnected,
    connectionState,
    on,
    send,
    connect,
    disconnect,
  };
}

/**
 * Hook specifically for messaging WebSocket events
 */
export function useMessagingWebSocket(conversationId?: string) {
  const { on, isConnected, connectionState } = useWebSocket({ autoConnect: true });

  /**
   * Listen for new messages
   */
  const onNewMessage = useCallback((handler: (message: any) => void) => {
    return on('new_message', (data, envelope) => {
      if (!conversationId || envelope?.conversation_id === conversationId) {
        handler(data);
      }
    });
  }, [on, conversationId]);

  /**
   * Listen for typing indicators
   */
  const onTyping = useCallback((handler: (data: any) => void) => {
    return on('typing', (data, envelope) => {
      if (!conversationId || envelope?.conversation_id === conversationId || data.conversation_id === conversationId) {
        handler(data);
      }
    });
  }, [on, conversationId]);

  /**
   * Listen for stop typing
   */
  const onStopTyping = useCallback((handler: (data: any) => void) => {
    return on('stop_typing', (data, envelope) => {
      if (!conversationId || envelope?.conversation_id === conversationId || data.conversation_id === conversationId) {
        handler(data);
      }
    });
  }, [on, conversationId]);

  /**
   * Listen for message read receipts
   */
  const onMessageRead = useCallback((handler: (data: any) => void) => {
    return on('message_read', (data, envelope) => {
      if (!conversationId || envelope?.conversation_id === conversationId) {
        handler(data);
      }
    });
  }, [on, conversationId]);

  /**
   * Listen for message delivered
   */
  const onMessageDelivered = useCallback((handler: (data: any) => void) => {
    return on('message_delivered', (data, envelope) => {
      if (!conversationId || envelope?.conversation_id === conversationId) {
        handler(data);
      }
    });
  }, [on, conversationId]);

  return {
    isConnected,
    connectionState,
    onNewMessage,
    onTyping,
    onStopTyping,
    onMessageRead,
    onMessageDelivered,
    on, // Generic handler
  };
}

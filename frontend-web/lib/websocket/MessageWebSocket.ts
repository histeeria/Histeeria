/**
 * MessageWebSocket - WebSocket client for real-time messaging
 * Features: Multiplexing, ACK tracking, auto-reconnect, message queue
 */

import { v4 as uuidv4 } from 'uuid';

// ============================================
// TYPES
// ============================================

export type WSMessageType =
  | 'new_message'
  | 'message_delivered'
  | 'message_read'
  | 'typing'
  | 'stop_typing'
  | 'reaction'
  | 'reaction_removed'
  | 'message_deleted'
  | 'message_edited'
  | 'message_pinned'
  | 'message_unpinned'
  | 'online'
  | 'offline'
  | 'ack'
  | 'ping'
  | 'pong';

export interface WSMessageEnvelope {
  id: string;
  type: WSMessageType;
  channel: string;
  conversation_id?: string;
  data: any;
  timestamp: number;
}

export type MessageEventHandler = (data: any) => void;

// ============================================
// MESSAGE WEBSOCKET CLIENT
// ============================================

class MessageWebSocket {
  private ws: WebSocket | null = null;
  private token: string | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000; // Start with 1 second
  private isConnecting = false;
  private isIntentionallyClosed = false;

  // Message queue for offline messages
  private messageQueue: WSMessageEnvelope[] = [];

  // Pending acknowledgments
  private pendingAcks = new Map<string, {
    resolve: () => void;
    reject: (error: Error) => void;
    timeout: NodeJS.Timeout;
  }>();

  // Event handlers by message type
  private eventHandlers = new Map<WSMessageType, MessageEventHandler[]>();

  // Connection state listeners
  private connectionStateListeners: Array<(connected: boolean) => void> = [];

  // ==================== CONNECTION ====================

  /**
   * Connect to WebSocket server
   */
  connect(token: string) {
    if (this.isConnecting || (this.ws && this.ws.readyState === WebSocket.OPEN)) {
      console.log('[MessageWS] Already connected or connecting');
      return;
    }

    this.token = token;
    this.isConnecting = true;
    this.isIntentionallyClosed = false;

    const wsUrl = this.getWebSocketURL(token);
    console.log('[MessageWS] Connecting to:', wsUrl);

    try {
      this.ws = new WebSocket(wsUrl);
      this.setupWebSocketHandlers();
    } catch (error) {
      console.error('[MessageWS] Connection error:', error);
      this.isConnecting = false;
      this.attemptReconnect();
    }
  }

  /**
   * Disconnect from WebSocket server
   */
  disconnect() {
    console.log('[MessageWS] Disconnecting...');
    this.isIntentionallyClosed = true;

    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }

    // Clear all pending ACKs
    this.pendingAcks.forEach(({ reject, timeout }) => {
      clearTimeout(timeout);
      reject(new Error('WebSocket disconnected'));
    });
    this.pendingAcks.clear();

    this.notifyConnectionState(false);
  }

  /**
   * Get WebSocket URL with token
   */
  private getWebSocketURL(token: string): string {
    // Use environment variable or default to localhost
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'localhost:8081';
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';

    // Extract host without protocol
    const host = apiUrl.replace(/^https?:\/\//, '');

    return `${protocol}//${host}/api/v1/ws?token=${token}`;
  }

  /**
   * Setup WebSocket event handlers
   */
  private setupWebSocketHandlers() {
    if (!this.ws) return;

    this.ws.onopen = () => {
      console.log('[MessageWS] ✅ Connected');
      this.isConnecting = false;
      this.reconnectAttempts = 0;
      this.reconnectDelay = 1000;

      // Flush queued messages
      this.flushMessageQueue();

      // Notify listeners
      this.notifyConnectionState(true);
    };

    this.ws.onmessage = (event) => {
      try {
        const envelope: WSMessageEnvelope = JSON.parse(event.data);
        this.handleMessage(envelope);
      } catch (error) {
        console.error('[MessageWS] Failed to parse message:', error);
      }
    };

    this.ws.onerror = (error) => {
      console.error('[MessageWS] ❌ Error:', error);
    };

    this.ws.onclose = () => {
      console.log('[MessageWS] Disconnected');
      this.isConnecting = false;
      this.ws = null;

      this.notifyConnectionState(false);

      // Attempt reconnect if not intentionally closed
      if (!this.isIntentionallyClosed) {
        this.attemptReconnect();
      }
    };
  }

  /**
   * Handle incoming WebSocket message
   */
  private handleMessage(envelope: WSMessageEnvelope) {
    // Handle ACK
    if (envelope.type === 'ack') {
      this.handleACK(envelope.id);
      return;
    }

    // Handle pong (keep-alive)
    if (envelope.type === 'pong') {
      return;
    }

    // Route message to handlers based on channel + type
    if (envelope.channel === 'messaging') {
      this.routeMessageToHandlers(envelope.type, envelope.data);
    }
  }

  /**
   * Route message to registered handlers
   */
  private routeMessageToHandlers(type: WSMessageType, data: any) {
    console.log(`[MessageWS] Routing message type: ${type}, data:`, data);
    const handlers = this.eventHandlers.get(type) || [];
    console.log(`[MessageWS] Found ${handlers.length} handlers for ${type}`);
    handlers.forEach((handler) => {
      try {
        handler(data);
      } catch (error) {
        console.error(`[MessageWS] Handler error for ${type}:`, error);
      }
    });
  }

  /**
   * Handle ACK from server
   */
  private handleACK(messageId: string) {
    const pending = this.pendingAcks.get(messageId);
    if (pending) {
      clearTimeout(pending.timeout);
      pending.resolve();
      this.pendingAcks.delete(messageId);
    }
  }

  /**
   * Attempt to reconnect with exponential backoff
   */
  private attemptReconnect() {
    if (this.isIntentionallyClosed || !this.token) {
      return;
    }

    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('[MessageWS] Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = Math.min(this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1), 30000);

    console.log(`[MessageWS] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})...`);

    setTimeout(() => {
      if (!this.isIntentionallyClosed && this.token) {
        this.connect(this.token);
      }
    }, delay);
  }

  /**
   * Flush queued messages
   */
  private flushMessageQueue() {
    console.log(`[MessageWS] Flushing ${this.messageQueue.length} queued messages`);

    while (this.messageQueue.length > 0) {
      const message = this.messageQueue.shift();
      if (message) {
        this.sendEnvelope(message);
      }
    }
  }

  // ==================== SENDING ====================

  /**
   * Send a message with ACK tracking
   */
  sendMessage(type: WSMessageType, data: any, conversationId?: string): Promise<void> {
    const envelope: WSMessageEnvelope = {
      id: uuidv4(),
      type,
      channel: 'messaging',
      conversation_id: conversationId,
      data,
      timestamp: Date.now(),
    };

    return new Promise((resolve, reject) => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        // Send immediately
        this.sendEnvelope(envelope);

        // Track ACK (optional - for critical messages)
        if (type === 'new_message') {
          const timeout = setTimeout(() => {
            this.pendingAcks.delete(envelope.id);
            reject(new Error('ACK timeout'));
          }, 5000);

          this.pendingAcks.set(envelope.id, { resolve, reject, timeout });
        } else {
          resolve(); // Non-critical messages don't need ACK
        }
      } else {
        // Queue for later
        console.log('[MessageWS] Queuing message (offline)');
        this.messageQueue.push(envelope);
        resolve(); // Resolve immediately - will send when reconnected
      }
    });
  }

  /**
   * Send envelope to server
   */
  private sendEnvelope(envelope: WSMessageEnvelope) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(envelope));
    }
  }

  /**
   * Send ping to keep connection alive
   */
  private sendPing() {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type: 'ping' }));
    }
  }

  // ==================== EVENT HANDLERS ====================

  /**
   * Register event handler for a message type
   */
  on(type: WSMessageType, handler: MessageEventHandler) {
    if (!this.eventHandlers.has(type)) {
      this.eventHandlers.set(type, []);
    }

    this.eventHandlers.get(type)!.push(handler);

    // Return unsubscribe function
    return () => {
      const handlers = this.eventHandlers.get(type);
      if (handlers) {
        const index = handlers.indexOf(handler);
        if (index > -1) {
          handlers.splice(index, 1);
        }
      }
    };
  }

  /**
   * Remove event handler
   */
  off(type: WSMessageType, handler: MessageEventHandler) {
    const handlers = this.eventHandlers.get(type);
    if (handlers) {
      const index = handlers.indexOf(handler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    }
  }

  /**
   * Listen for connection state changes
   */
  onConnectionStateChange(listener: (connected: boolean) => void) {
    this.connectionStateListeners.push(listener);

    // Return unsubscribe function
    return () => {
      const index = this.connectionStateListeners.indexOf(listener);
      if (index > -1) {
        this.connectionStateListeners.splice(index, 1);
      }
    };
  }

  /**
   * Notify connection state listeners
   */
  private notifyConnectionState(connected: boolean) {
    this.connectionStateListeners.forEach((listener) => {
      try {
        listener(connected);
      } catch (error) {
        console.error('[MessageWS] Connection state listener error:', error);
      }
    });
  }

  // ==================== UTILITIES ====================

  /**
   * Check if WebSocket is connected
   */
  isConnected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }

  /**
   * Get connection state
   */
  getConnectionState(): string {
    if (!this.ws) return 'disconnected';

    switch (this.ws.readyState) {
      case WebSocket.CONNECTING:
        return 'connecting';
      case WebSocket.OPEN:
        return 'connected';
      case WebSocket.CLOSING:
        return 'closing';
      case WebSocket.CLOSED:
        return 'disconnected';
      default:
        return 'unknown';
    }
  }

  /**
   * Get number of queued messages
   */
  getQueuedMessageCount(): number {
    return this.messageQueue.length;
  }
}

// ============================================
// SINGLETON INSTANCE
// ============================================

// Export singleton instance - now uses UnifiedWebSocket
import { unifiedWS } from './UnifiedWebSocket';

export const messageWS = {
  connect: (token: string) => {
    unifiedWS.connect(token).catch(err => {
      console.error('[MessageWS] Connection failed:', err);
    });
  },
  disconnect: () => {
    unifiedWS.disconnect();
  },
  on: (event: WSMessageType, handler: MessageEventHandler) => {
    // Register handler with proper envelope support
    return unifiedWS.on(event, (data, envelope) => {
      handler(data);
    });
  },
  off: (event: WSMessageType, handler: MessageEventHandler) => {
    // Note: Use return value from on() for proper cleanup
    console.warn('[MessageWS] off() called - use return value from on() for proper cleanup');
  },
  sendMessage: (type: WSMessageType, data: any, conversationId?: string) => {
    // Send via unified WebSocket
    unifiedWS.send({
      type,
      data,
      channel: 'messaging',
      ...(conversationId && { conversation_id: conversationId })
    });
  },
  isConnected: () => unifiedWS.isConnected(),
  getConnectionState: () => {
    const state = unifiedWS.getConnectionState();
    return state === 'connected' ? 'connected' : 
           state === 'connecting' ? 'connecting' : 
           state === 'closing' ? 'closing' : 'disconnected';
  },
  onConnectionStateChange: (handler: (connected: boolean) => void) => {
    return unifiedWS.onConnectionStateChange(handler);
  },
};


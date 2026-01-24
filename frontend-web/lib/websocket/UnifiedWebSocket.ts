/**
 * Unified WebSocket Service
 * 
 * Single WebSocket connection with channel multiplexing for:
 * - Messaging (real-time messages, typing, reactions, etc.)
 * - Notifications (in-app notifications, count updates)
 * - Presence (online/offline status)
 * 
 * Features:
 * - Automatic reconnection with exponential backoff
 * - Connection state management
 * - Message queuing for offline scenarios
 * - ACK tracking for reliable delivery
 * - Proper handler registration and routing
 */

import type { Notification } from '../api/notifications';

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
  | 'notification'
  | 'count_update'
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

export interface WSMessage {
  type: string;
  data?: any;
  // Envelope fields (for backward compatibility)
  id?: string;
  channel?: string;
  conversation_id?: string;
  timestamp?: number;
}

type MessageHandler = (data: any, envelope?: WSMessageEnvelope) => void;
type ConnectionStateHandler = (connected: boolean) => void;

// ============================================
// UNIFIED WEBSOCKET SERVICE
// ============================================

class UnifiedWebSocket {
  private static instance: UnifiedWebSocket;
  private ws: WebSocket | null = null;
  private url: string;
  private token: string | null = null;
  
  // Connection management
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectDelay = 1000;
  private isIntentionallyClosed = false;
  private isConnecting = false;
  
  // Message handling
  private messageHandlers: Map<string, Set<MessageHandler>> = new Map();
  private connectionStateHandlers: Set<ConnectionStateHandler> = new Set();
  
  // Heartbeat
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private heartbeatIntervalMs = 30000; // 30 seconds
  
  // Message queue for offline scenarios
  private messageQueue: Array<{ type: string; data?: any; channel?: string }> = [];
  
  // Connection state
  private connectionState: 'disconnected' | 'connecting' | 'connected' | 'closing' = 'disconnected';
  
  private constructor() {
    this.url = this.buildWebSocketURL();
  }

  public static getInstance(): UnifiedWebSocket {
    if (!UnifiedWebSocket.instance) {
      UnifiedWebSocket.instance = new UnifiedWebSocket();
    }
    return UnifiedWebSocket.instance;
  }

  /**
   * Build WebSocket URL based on environment
   */
  private buildWebSocketURL(): string {
    if (typeof window === 'undefined') {
      return ''; // SSR
    }

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    
    // Check for explicit API URL in environment
    const envApiUrl = process.env.NEXT_PUBLIC_API_URL;
    
    if (envApiUrl) {
      // Extract host from API URL
      const host = envApiUrl.replace(/^https?:\/\//, '').replace(/\/$/, '');
      return `${protocol}//${host}/api/v1/ws`;
    }
    
    // Development: use localhost:8081
    const isDevelopment = 
      window.location.hostname === 'localhost' ||
      window.location.hostname === '127.0.0.1' ||
      process.env.NODE_ENV === 'development';
    
    if (isDevelopment) {
      return `${protocol}//localhost:8081/api/v1/ws`;
    }
    
    // Production: use current hostname
    return `${protocol}//${window.location.hostname}/api/v1/ws`;
  }

  /**
   * Check if backend is reachable (health check)
   * Returns false on any error (network, CORS, timeout) - non-blocking
   */
  private async checkBackendHealth(): Promise<boolean> {
    try {
      // Extract HTTP URL from WebSocket URL
      const httpUrl = this.url.replace(/^ws/, 'http').replace(/^wss/, 'https');
      const healthUrl = httpUrl.replace('/api/v1/ws', '/api/v1/status');
      
      const response = await fetch(healthUrl, {
        method: 'GET',
        signal: AbortSignal.timeout(3000), // 3 second timeout
        mode: 'cors', // Explicitly request CORS
      });
      
      return response.ok;
    } catch (error: any) {
      // CORS errors, network errors, timeouts - all are non-critical
      // We'll still attempt WebSocket connection which doesn't have CORS restrictions
      if (error?.name === 'AbortError') {
        // Timeout - backend might be slow, not necessarily down
        return false;
      }
      // CORS or network error - backend might be running but health endpoint not accessible
      // This is fine - WebSocket connections don't have CORS restrictions
      return false;
    }
  }

  /**
   * Connect to WebSocket server
   */
  public async connect(token: string): Promise<void> {
    if (!token) {
      console.error('[UnifiedWS] No token provided');
      return;
    }

    if (this.isConnecting || this.connectionState === 'connected') {
      console.log('[UnifiedWS] Already connected or connecting');
      return;
    }

    this.token = token;
    this.isIntentionallyClosed = false;
    this.isConnecting = true;
    this.setConnectionState('connecting');

    // Optional: Check backend health first (non-blocking)
    if (this.reconnectAttempts === 0) {
      const isHealthy = await this.checkBackendHealth();
      if (!isHealthy) {
        console.warn('[UnifiedWS] ⚠️ Backend health check failed - server may not be running');
        console.warn('[UnifiedWS] 💡 Start backend: cd backend && go run main.go');
      }
    }

    const wsUrl = `${this.url}?token=${token}`;
    console.log('[UnifiedWS] Connecting to:', wsUrl);

    try {
      this.ws = new WebSocket(wsUrl);
      this.setupEventHandlers();
    } catch (error) {
      console.error('[UnifiedWS] Connection error:', error);
      this.isConnecting = false;
      this.setConnectionState('disconnected');
      this.attemptReconnect();
    }
  }

  /**
   * Setup WebSocket event handlers
   */
  private setupEventHandlers(): void {
    if (!this.ws) return;

    this.ws.onopen = () => {
      console.log('[UnifiedWS] ✅ Connected successfully');
      this.isConnecting = false;
      this.reconnectAttempts = 0;
      this.reconnectDelay = 1000;
      this.setConnectionState('connected');
      this.startHeartbeat();
      this.flushMessageQueue();
    };

    this.ws.onmessage = (event) => {
      try {
        const rawMessage = JSON.parse(event.data);
        this.handleIncomingMessage(rawMessage);
      } catch (error) {
        console.error('[UnifiedWS] Failed to parse message:', error, event.data);
      }
    };

    this.ws.onerror = (error) => {
      console.error('[UnifiedWS] ❌ WebSocket error:', error);
      console.error('[UnifiedWS] 💡 Troubleshooting:');
      console.error('[UnifiedWS]   1. Is backend server running? Check: http://localhost:8081/api/v1/status');
      console.error('[UnifiedWS]   2. Is backend on port 8081? Check backend logs');
      console.error('[UnifiedWS]   3. Is WebSocket endpoint accessible? Check: ws://localhost:8081/api/v1/ws');
      console.error('[UnifiedWS]   4. Check browser console for CORS errors');
      // Error details are usually in the event, not the error object
    };

    this.ws.onclose = (event) => {
      const code = event.code;
      const reason = event.reason || 'No reason provided';
      
      console.log('[UnifiedWS] Disconnected. Code:', code, 'Reason:', reason);
      
      // Provide helpful error messages for common close codes
      if (code === 1006) {
        console.error('[UnifiedWS] ⚠️ Abnormal closure (1006) - Backend server likely not running or unreachable');
        console.error('[UnifiedWS] 💡 Solution: Start backend server on port 8081');
        console.error('[UnifiedWS]    Run: cd backend && go run main.go');
      } else if (code === 1000) {
        console.log('[UnifiedWS] ✅ Normal closure');
      } else if (code === 1001) {
        console.log('[UnifiedWS] Endpoint going away');
      } else if (code === 1002) {
        console.error('[UnifiedWS] Protocol error');
      } else if (code === 1003) {
        console.error('[UnifiedWS] Unsupported data type');
      } else if (code === 1008) {
        console.error('[UnifiedWS] Policy violation');
      } else if (code === 1011) {
        console.error('[UnifiedWS] Server error');
      }
      
      this.isConnecting = false;
      this.ws = null;
      this.setConnectionState('disconnected');
      this.stopHeartbeat();

      if (!this.isIntentionallyClosed && this.token) {
        this.attemptReconnect();
      }
    };
  }

  /**
   * Handle incoming message - supports both envelope and flat formats
   */
  private handleIncomingMessage(rawMessage: WSMessage | WSMessageEnvelope): void {
    // Check if it's an envelope format (has channel field)
    const isEnvelope = 'channel' in rawMessage && rawMessage.channel;
    
    if (isEnvelope) {
      const envelope = rawMessage as WSMessageEnvelope;
      this.handleEnvelopeMessage(envelope);
    } else {
      // Flat format (legacy notifications)
      const message = rawMessage as WSMessage;
      this.handleFlatMessage(message);
    }
  }

  /**
   * Handle envelope format (messaging channel)
   */
  private handleEnvelopeMessage(envelope: WSMessageEnvelope): void {
    console.log(`[UnifiedWS] 📨 Received envelope: ${envelope.type} on channel ${envelope.channel}`);
    
    // Route based on channel and type
    const handlers = this.messageHandlers.get(envelope.type);
    
    if (handlers && handlers.size > 0) {
      handlers.forEach(handler => {
        try {
          handler(envelope.data, envelope);
        } catch (error) {
          console.error(`[UnifiedWS] Handler error for ${envelope.type}:`, error);
        }
      });
    } else {
      console.warn(`[UnifiedWS] No handlers registered for type: ${envelope.type}`);
    }
    
    // Send ACK for critical messages
    if (envelope.type === 'new_message' || envelope.type === 'message_delivered') {
      this.sendACK(envelope.id);
    }
  }

  /**
   * Handle flat format (notifications, legacy)
   */
  private handleFlatMessage(message: WSMessage): void {
    // Handle ping/pong
    if (message.type === 'pong') {
      return; // Silent
    }
    
    if (message.type === 'ping') {
      this.send({ type: 'pong' });
      return;
    }
    
    // Route to handlers
    const handlers = this.messageHandlers.get(message.type);
    if (handlers) {
      handlers.forEach(handler => {
        try {
          handler(message.data);
        } catch (error) {
          console.error(`[UnifiedWS] Handler error for ${message.type}:`, error);
        }
      });
    }
  }

  /**
   * Send ACK for received message
   */
  private sendACK(messageId: string): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({
        type: 'ack',
        id: messageId,
        timestamp: Date.now()
      }));
    }
  }

  /**
   * Disconnect from WebSocket server
   */
  public disconnect(): void {
    console.log('[UnifiedWS] Disconnecting...');
    this.isIntentionallyClosed = true;
    this.stopHeartbeat();
    
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    
    this.setConnectionState('disconnected');
  }

  /**
   * Register event handler
   */
  public on(eventType: WSMessageType | string, handler: MessageHandler): () => void {
    if (!this.messageHandlers.has(eventType)) {
      this.messageHandlers.set(eventType, new Set());
    }
    
    this.messageHandlers.get(eventType)!.add(handler);
    
    // Return unsubscribe function
    return () => {
      this.off(eventType, handler);
    };
  }

  /**
   * Unregister event handler
   */
  public off(eventType: WSMessageType | string, handler: MessageHandler): void {
    const handlers = this.messageHandlers.get(eventType);
    if (handlers) {
      handlers.delete(handler);
      if (handlers.size === 0) {
        this.messageHandlers.delete(eventType);
      }
    }
  }

  /**
   * Register connection state change handler
   */
  public onConnectionStateChange(handler: ConnectionStateHandler): () => void {
    this.connectionStateHandlers.add(handler);
    
    // Immediately notify current state
    handler(this.connectionState === 'connected');
    
    // Return unsubscribe function
    return () => {
      this.connectionStateHandlers.delete(handler);
    };
  }

  /**
   * Unregister connection state change handler
   */
  public offConnectionStateChange(handler: ConnectionStateHandler): void {
    this.connectionStateHandlers.delete(handler);
  }

  /**
   * Send message to server
   */
  public send(message: { type: string; data?: any; channel?: string }): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({
        type: message.type,
        data: message.data ?? null,
        channel: message.channel,
        timestamp: Date.now()
      }));
    } else {
      // Queue for later
      console.log('[UnifiedWS] Queuing message (offline):', message.type);
      this.messageQueue.push(message);
    }
  }

  /**
   * Flush queued messages
   */
  private flushMessageQueue(): void {
    if (this.messageQueue.length === 0) return;
    
    console.log(`[UnifiedWS] Flushing ${this.messageQueue.length} queued messages`);
    
    while (this.messageQueue.length > 0) {
      const message = this.messageQueue.shift();
      if (message) {
        this.send(message);
      }
    }
  }

  /**
   * Attempt reconnection with exponential backoff
   */
  private attemptReconnect(): void {
    if (this.isIntentionallyClosed || !this.token) {
      return;
    }

    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('[UnifiedWS] Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = Math.min(
      this.reconnectDelay * Math.pow(1.5, this.reconnectAttempts - 1),
      30000 // Max 30 seconds
    );

    console.log(`[UnifiedWS] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

    setTimeout(() => {
      if (!this.isIntentionallyClosed && this.token) {
        this.connect(this.token);
      }
    }, delay);
  }

  /**
   * Start heartbeat (ping/pong)
   */
  private startHeartbeat(): void {
    this.stopHeartbeat();
    
    this.heartbeatInterval = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.send({ type: 'ping' });
      }
    }, this.heartbeatIntervalMs);
  }

  /**
   * Stop heartbeat
   */
  private stopHeartbeat(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  /**
   * Set connection state and notify handlers
   */
  private setConnectionState(state: 'disconnected' | 'connecting' | 'connected' | 'closing'): void {
    this.connectionState = state;
    const isConnected = state === 'connected';
    
    this.connectionStateHandlers.forEach(handler => {
      try {
        handler(isConnected);
      } catch (error) {
        console.error('[UnifiedWS] Connection state handler error:', error);
      }
    });
  }

  /**
   * Check if connected
   */
  public isConnected(): boolean {
    return this.connectionState === 'connected' && 
           this.ws !== null && 
           this.ws.readyState === WebSocket.OPEN;
  }

  /**
   * Get connection state
   */
  public getConnectionState(): 'disconnected' | 'connecting' | 'connected' | 'closing' {
    return this.connectionState;
  }

  /**
   * Get queued message count
   */
  public getQueuedMessageCount(): number {
    return this.messageQueue.length;
  }
}

// ============================================
// EXPORTS
// ============================================

export default UnifiedWebSocket;

// Export singleton instance
export const unifiedWS = UnifiedWebSocket.getInstance();

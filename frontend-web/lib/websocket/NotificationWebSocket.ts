/**
 * NotificationWebSocket - Backward Compatibility Wrapper
 * 
 * This file now delegates to UnifiedWebSocket for all operations.
 * Maintains backward compatibility for existing code.
 */

import { unifiedWS, type WSMessageType } from './UnifiedWebSocket';

type MessageHandler = (data: any) => void;
type ConnectionStateHandler = (connected: boolean) => void;

class NotificationWebSocket {
  private static instance: NotificationWebSocket;

  private constructor() {
    // All operations delegate to unifiedWS
  }

  public static getInstance(): NotificationWebSocket {
    if (!NotificationWebSocket.instance) {
      NotificationWebSocket.instance = new NotificationWebSocket();
    }
    return NotificationWebSocket.instance;
  }

  public connect(token: string): void {
    unifiedWS.connect(token).catch(err => {
      console.error('[NotificationWS] Connection failed:', err);
    });
  }

  public disconnect(): void {
    unifiedWS.disconnect();
  }

  public on(eventType: string, handler: MessageHandler): () => void {
    // Wrap handler to match unified signature and return unsubscribe function
    return unifiedWS.on(eventType, (data) => handler(data));
  }

  public off(eventType: string, handler: MessageHandler): void {
    // Note: This method is deprecated - use the return value from on() instead
    // Keeping for backward compatibility but it won't work properly
    console.warn('[NotificationWS] off() called - use return value from on() for proper cleanup');
  }

  public onConnectionStateChange(handler: ConnectionStateHandler): void {
    unifiedWS.onConnectionStateChange(handler);
  }

  public offConnectionStateChange(handler: ConnectionStateHandler): void {
    unifiedWS.offConnectionStateChange(handler);
  }

  public isConnected(): boolean {
    return unifiedWS.isConnected();
  }
}

export default NotificationWebSocket;

// Export singleton instance for direct use
export const notificationWS = NotificationWebSocket.getInstance();


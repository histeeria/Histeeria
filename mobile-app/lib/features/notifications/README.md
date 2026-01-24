# Notifications Module

## Overview
The notifications module provides a complete real-time notification system for Histeeria, integrating with the backend API and WebSocket for instant updates.

## Features

### ✅ Implemented Features
- **Real-time Notifications**: WebSocket connection for instant notification delivery
- **Notification Badge**: Unread count displayed in app header
- **Auto Mark as Read**: Opening notification screen marks all as read
- **Pagination**: Load more notifications as you scroll
- **Pull to Refresh**: Refresh notifications with pull-down gesture
- **Notification Actions**: Accept/decline connection requests inline
- **Notification Types**: Support for all backend notification types
  - Follow/Follow Back
  - Connection Requests
  - Post Likes/Comments/Mentions
  - Collaboration Requests
  - Messages
  - System Announcements
- **Category Filtering**: Separate tabs for different notification types
- **WebSocket Auto-Reconnect**: Automatic reconnection with exponential backoff
- **Connection Status**: Visual indicator of WebSocket connection status

## Architecture

### Data Layer
```
lib/features/notifications/data/
├── models/
│   └── notification.dart           # NotificationModel, Actor, Response models
├── services/
│   ├── notification_api_service.dart       # HTTP API calls
│   └── notification_websocket_service.dart # WebSocket connection
└── providers/
    └── notification_provider.dart  # State management
```

### Presentation Layer
```
lib/features/notifications/presentation/
└── screens/
    └── notifications_screen.dart   # Main notifications UI
```

## Usage

### 1. Provider Setup
The notification provider is already initialized in `main.dart`:

```dart
MultiProvider(
  providers: [
    // ... other providers
    ChangeNotifierProvider(create: (_) => NotificationProvider()),
  ],
)
```

### 2. Display Notification Badge
Use the `AppHeader` widget with notification badge:

```dart
Consumer<NotificationProvider>(
  builder: (context, notifProvider, _) => AppHeader(
    notificationBadge: notifProvider.unreadCount,
    // ... other properties
  ),
)
```

### 3. Access Notifications
Access notifications anywhere in the app:

```dart
// Get provider
final notifProvider = Provider.of<NotificationProvider>(context);

// Get notifications
final notifications = notifProvider.notifications;
final unreadCount = notifProvider.unreadCount;
final followRequests = notifProvider.followRequests;

// Refresh
await notifProvider.refresh();

// Mark as read
await notifProvider.markAsRead(notificationId);

// Delete notification
await notifProvider.deleteNotification(notificationId);

// Take action (accept/reject)
await notifProvider.takeAction(notificationId, 'accept');
```

## WebSocket Connection

### Connection Management
The WebSocket connection is automatically managed:
- **Auto-connect** on provider initialization
- **Auto-reconnect** on disconnect (max 5 attempts)
- **Ping/Pong** heartbeat to keep connection alive
- **Exponential backoff** for reconnection attempts

### WebSocket Events
The service handles these message types:
- `notification`: New notification received
- `count_update`: Unread count update
- `ping`/`pong`: Connection heartbeat
- `error`: Error messages

### Connection Status
Monitor connection status:

```dart
final isConnected = notifProvider.isConnected;

// Listen to connection stream
notifProvider._wsService.connectionStatusStream.listen((connected) {
  print('WebSocket connected: $connected');
});
```

## API Integration

### Backend Endpoints
The service integrates with these API endpoints:

- `GET /api/v1/notifications` - Get notifications (paginated)
- `GET /api/v1/notifications/unread-count` - Get unread count
- `PATCH /api/v1/notifications/:id/read` - Mark as read
- `PATCH /api/v1/notifications/read-all` - Mark all as read
- `DELETE /api/v1/notifications/:id` - Delete notification
- `POST /api/v1/notifications/:id/action` - Take action

### WebSocket Endpoint
- `WS /api/v1/ws?token={jwt_token}` - Real-time notifications

## Notification Types

### Supported Types
```dart
class NotificationType {
  static const String follow = 'follow';
  static const String followBack = 'follow_back';
  static const String connectionRequest = 'connection_request';
  static const String connectionAccepted = 'connection_accepted';
  static const String postLike = 'post_like';
  static const String postComment = 'post_comment';
  static const String postMention = 'post_mention';
  static const String message = 'message';
  // ... more types
}
```

### Categories
```dart
class NotificationCategory {
  static const String social = 'social';
  static const String messages = 'messages';
  static const String projects = 'projects';
  static const String communities = 'communities';
  static const String payments = 'payments';
  static const String system = 'system';
}
```

## UI Components

### Notification Item
Each notification displays:
- **Actor avatar** or notification icon
- **Actor name** (bold)
- **Notification message**
- **Time ago** (e.g., "2m", "1h", "3d")
- **Action buttons** (for actionable notifications)
- **Post thumbnail** (if applicable)
- **Unread indicator** (blue dot)

### Actions
Available actions:
- **Tap**: Mark as read and navigate to action URL
- **Long press**: Show options menu
  - Delete notification
  - View actor's profile
  - Block actor (coming soon)

### Empty States
- No notifications yet
- Failed to load (with retry button)
- No follow requests

## Performance Optimizations

### Pagination
- Load 20 notifications per page
- Auto-load more when scrolling near bottom (80% threshold)
- Smooth loading indicator

### Caching
- Local state caching in provider
- Optimistic UI updates
- WebSocket for real-time updates (no polling)

### Network Efficiency
- WebSocket reduces API calls (no polling)
- Batch operations (mark all as read)
- Efficient image loading with OptimizedCachedImage

## Error Handling

### Connection Errors
- Auto-retry with exponential backoff
- Max 5 reconnection attempts
- User-friendly error messages

### API Errors
- Try-catch blocks around all API calls
- SnackBar notifications for user feedback
- Graceful fallbacks

## Testing

### Manual Testing Checklist
- [ ] Receive real-time notification via WebSocket
- [ ] Badge count updates correctly
- [ ] Opening screen marks all as read
- [ ] Pagination works (scroll to load more)
- [ ] Pull-to-refresh works
- [ ] Accept/decline buttons work
- [ ] Delete notification works
- [ ] Navigate to action URL on tap
- [ ] WebSocket reconnects after disconnect
- [ ] App works offline (shows cached notifications)

## Future Enhancements

### Planned Features
- [ ] Push notifications (FCM/APNs)
- [ ] Notification sounds
- [ ] Notification grouping (e.g., "John and 5 others liked your post")
- [ ] Rich notifications (with full post preview)
- [ ] In-app notification banner
- [ ] Notification preferences/settings
- [ ] Mute notifications from specific users
- [ ] Custom notification sounds per category
- [ ] Schedule "Do Not Disturb" hours

## Troubleshooting

### WebSocket Not Connecting
1. Check if backend is running
2. Verify WebSocket URL in ApiConfig
3. Check if auth token is valid
4. Check network connectivity
5. Look for errors in console logs

### Notifications Not Appearing
1. Check WebSocket connection status
2. Verify provider is initialized in main.dart
3. Check API permissions (JWT token)
4. Test API endpoint directly (Postman/curl)

### Badge Not Updating
1. Ensure NotificationProvider is used in AppHeader
2. Check if unreadCount is being updated
3. Verify WebSocket count_update messages

## Dependencies

```yaml
dependencies:
  web_socket_channel: ^3.0.1  # WebSocket support
  provider: ^6.1.1            # State management
  dio: ^5.4.0                 # HTTP client
```

## Contributing

When adding new notification types:
1. Add type constant to `NotificationType` class
2. Update `_getNotificationIcon()` method
3. Add handling in backend notification service
4. Update this README

## License
Private - Histeeria App

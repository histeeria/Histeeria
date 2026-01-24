# API Integration Layer

Production-ready API integration layer for Histeeria mobile app, designed to handle millions of users with robust error handling, automatic token management, and network monitoring.

## Architecture

```
core/api/
├── api_client.dart          # Main HTTP client (Dio wrapper)
├── exceptions/              # Custom exception classes
│   └── api_exception.dart
├── interceptors/            # Request/response interceptors
│   ├── auth_interceptor.dart
│   └── logging_interceptor.dart
├── models/                  # Base response models
│   ├── api_response.dart
│   └── pagination_response.dart
└── utils/                   # Utility classes
    └── error_handler.dart
```

## Features

✅ **Automatic Token Management** - JWT tokens automatically added to requests  
✅ **Token Refresh** - Automatic token refresh on 401 errors  
✅ **Error Handling** - Typed exceptions for all error scenarios  
✅ **Network Monitoring** - Real-time connectivity status  
✅ **Request Logging** - Comprehensive request/response logging  
✅ **Retry Logic** - Built-in retry mechanism for failed requests  
✅ **Secure Storage** - Encrypted token storage  
✅ **Type Safety** - Full type safety with generics  

## Usage

### Basic API Call

```dart
import 'package:histeeria/core/api/api_client.dart';

final apiClient = ApiClient();

// GET request
final response = await apiClient.get<Map<String, dynamic>>(
  '/account/profile',
  fromJson: (json) => json as Map<String, dynamic>,
);

// POST request
final result = await apiClient.post<ApiResponse<User>>(
  '/auth/login',
  data: {
    'email': 'user@example.com',
    'password': 'password123',
  },
  fromJson: (json) => ApiResponse.fromJson(json, User.fromJson),
);
```

### Error Handling

```dart
try {
  final user = await apiClient.get<User>('/account/profile');
} on AuthenticationException {
  // Handle auth error - redirect to login
} on NetworkException {
  // Handle network error - show offline message
} on ValidationException catch (e) {
  // Handle validation errors
  print(e.errors);
} on ApiException catch (e) {
  // Handle any other API error
  print(e.message);
}
```

### File Upload

```dart
final result = await apiClient.uploadFile<ApiResponse<String>>(
  '/account/profile-picture',
  '/path/to/image.jpg',
  fileKey: 'file',
  additionalData: {'description': 'Profile picture'},
  onSendProgress: (sent, total) {
    final progress = sent / total;
    print('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
  },
);
```

## Configuration

Update `api_config.dart` to change:
- Base URL (development/production)
- Timeouts
- Retry settings
- Endpoint paths

## Security

- Tokens stored in encrypted secure storage
- Automatic token refresh on expiration
- HTTPS enforced in production
- Request/response validation

## Performance

- Connection pooling
- Request caching (where applicable)
- Efficient serialization
- Minimal memory footprint

## Next Steps

1. Create feature-specific services (AuthService, PostService, etc.)
2. Create data models for each feature
3. Implement repositories for business logic
4. Add caching layer if needed

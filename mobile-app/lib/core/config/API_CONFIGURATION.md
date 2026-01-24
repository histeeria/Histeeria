# API Configuration Guide

## Overview

The mobile app now uses **environment-based configuration** via `EnvironmentConfig` and `ApiConfig`. This allows easy switching between development, staging, and production environments without code changes.

## Environment Configuration

### Default Environment

By default, the app runs in **development** mode with `http://localhost:8081/api/v1` as the base URL.

### Setting Environment via Command Line

#### Development Mode (Default)
```bash
flutter run
# Or explicitly:
flutter run --dart-define=ENV=development
```

#### Production Mode
```bash
flutter run --dart-define=ENV=production
```

#### Staging Mode
```bash
flutter run --dart-define=ENV=staging
```

### Custom Base URL Override

For local development with physical devices or specific network configurations, you can override the base URL:

```bash
# Use your computer's IP for physical device testing
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8081/api/v1

# Use Android emulator special IP
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1

# Use custom staging URL
flutter run --dart-define=API_BASE_URL=https://my-staging-server.com/api/v1
```

### Environment URLs

- **Development**: `http://localhost:8081/api/v1` (default, overridable)
- **Staging**: `https://staging-api.histeeria.app/api/v1`
- **Production**: `https://api.histeeria.app/api/v1`

## Platform-Specific Configuration

### Android Emulator

The Android emulator uses a special IP `10.0.2.2` to reach the host machine:

```bash
# Run with emulator-specific URL
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1
```

### Physical Android Device

For physical devices, use your computer's IP address. Both device and computer must be on the same Wi-Fi network:

1. **Find your computer's IP address:**
   - **Windows**: Run `ipconfig` in Command Prompt, look for "IPv4 Address"
   - **Mac/Linux**: Run `ifconfig` or `ip addr`, look for your Wi-Fi adapter's IP

2. **Run with IP address:**
   ```bash
   flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8081/api/v1
   ```
   (Replace `192.168.1.100` with your actual IP)

### iOS Simulator

For iOS simulator, `localhost` works directly:

```bash
flutter run
# Uses http://localhost:8081/api/v1 by default
```

### Physical iOS Device

Same as Android - use your computer's IP address:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8081/api/v1
```

## Configuration in Code

### Using EnvironmentConfig

```dart
import 'package:your_app/core/config/environment.dart';

// Get current environment
final env = EnvironmentConfig.current;

// Get base URL for current environment
final baseUrl = EnvironmentConfig.baseUrl;

// Check environment
if (EnvironmentConfig.isDevelopment) {
  print('Running in development mode');
}
```

### Using ApiConfig

```dart
import 'package:your_app/core/config/api_config.dart';

// Get base URL (uses EnvironmentConfig internally)
final baseUrl = ApiConfig.baseUrl;

// Get WebSocket URL
final wsUrl = ApiConfig.wsUrl;
```

## Troubleshooting Connection Issues

### 1. "Cannot connect to server" Error

**Problem**: App can't reach backend server.

**Solutions**:
- Verify backend is running: `cd backend && go run main.go`
- Check backend is binding to all interfaces (`0.0.0.0:8081`, not just `127.0.0.1:8081`)
- Test backend from browser: `http://localhost:8081/api/v1/health`
- For physical devices: Ensure device and computer are on same Wi-Fi network
- Check firewall isn't blocking port 8081

### 2. Android Emulator Connection Issues

**Problem**: Android emulator can't connect to `localhost`.

**Solution**: Use `10.0.2.2` instead:
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1
```

### 3. Physical Device Connection Issues

**Problem**: Physical device can't reach backend.

**Solutions**:
- Use computer's IP address, not `localhost`
- Ensure both devices are on same Wi-Fi network
- Check firewall allows incoming connections on port 8081
- Verify backend is accessible from network (test with browser on device or another computer)

### 4. "401 Unauthorized" After Configuration Change

**Problem**: Token refresh failing after URL change.

**Solution**: Log out and log back in to get new tokens for the new endpoint.

## Testing Configuration

### Test Backend Connection

```bash
# Test from command line (replace with your actual base URL)
curl http://localhost:8081/api/v1/health
# Or
curl http://192.168.1.100:8081/api/v1/health
```

### Test from Mobile App

1. Open app in development mode
2. Navigate to login/registration screen
3. Check console/logs for connection errors
4. If connection fails, verify base URL matches your setup

## Security Notes

1. **Never commit sensitive URLs** - Use environment variables
2. **Production URLs** - Should always use HTTPS
3. **Development URLs** - HTTP is acceptable for local testing
4. **API Keys** - Never hardcode in source code

## Best Practices

1. **Use environment variables** for different environments
2. **Document IP addresses** for your local network setup
3. **Test on multiple devices** before releasing
4. **Use staging environment** for testing before production
5. **Keep configuration centralized** in `api_config.dart` and `environment.dart`

## Example Flutter Run Commands

```bash
# Development with default localhost
flutter run

# Development with Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1

# Development with physical device (replace IP)
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8081/api/v1

# Staging environment
flutter run --dart-define=ENV=staging

# Production environment
flutter run --dart-define=ENV=production

# Custom staging server
flutter run --dart-define=API_BASE_URL=https://my-custom-staging.com/api/v1
```

## File Structure

```
mobile-app/lib/core/config/
├── api_config.dart        # API configuration (uses EnvironmentConfig)
├── environment.dart       # Environment detection and configuration
└── API_CONFIGURATION.md  # This file
```

---

**Last Updated**: After environment-based configuration implementation
**Status**: Active documentation

# Assets Directory

## Logo Placement

Please add your app logo image here with the name `logo.png`.

The logo should be:
- Square format (recommended: 512x512 or 1024x1024)
- PNG format with transparency
- High resolution for crisp display

The logo will be used in:
- Splash screen
- App icon (after configuration)
- Various UI elements

## Current Usage

The splash screen currently uses a placeholder icon. Once you add `logo.png` to this directory, update `lib/features/auth/presentation/screens/splash_screen.dart` to use:

```dart
Image.asset('assets/images/logo.png')
```

instead of the current icon placeholder.


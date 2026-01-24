import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/config/api_config.dart';
import 'core/config/env_validator.dart';
import 'core/security/secure_storage_manager.dart';
import 'core/utils/app_logger.dart';
import 'features/auth/data/providers/auth_provider.dart';
import 'features/auth/data/providers/signup_state_provider.dart';
import 'features/profile/data/providers/profile_provider.dart';
import 'features/profile/data/providers/public_profile_provider.dart';
import 'features/posts/data/providers/posts_provider.dart';
import 'features/feed/data/providers/feed_provider.dart';
import 'features/notifications/data/providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize secure storage
  SecureStorageManager().initialize();
  AppLogger.success('Secure storage initialized', 'Main');
  
  // Initialize API configuration
  await ApiConfig.initializeBaseUrl();
  AppLogger.success('API configuration initialized', 'Main');
  
  // Validate environment configuration
  final validation = await EnvValidator.validate();
  if (!validation.isValid && kReleaseMode) {
    // In production, show error and exit
    AppLogger.error('Environment validation failed - cannot start app');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Configuration Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  EnvValidator.getErrorMessage(validation),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }
  
  // Fetch Supabase storage URL from backend (non-blocking)
  try {
    await ApiConfig.fetchStorageUrl().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        AppLogger.warning('Storage URL fetch timed out, will retry on-demand', 'Main');
      },
    );
  } catch (e) {
    AppLogger.warning('Failed to fetch storage URL: $e', 'Main');
  }
  
  AppLogger.success('App initialization complete', 'Main');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SignupStateProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PublicProfileProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp.router(
        title: 'Histeeria',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: AppColors.accentPrimary,
            secondary: AppColors.accentSecondary,
            surface: AppColors.surface,
            background: AppColors.backgroundPrimary,
            error: AppColors.error,
            onPrimary: AppColors.textPrimary,
            onSecondary: AppColors.textPrimary,
            onSurface: AppColors.textPrimary,
            onBackground: AppColors.textPrimary,
            onError: AppColors.textPrimary,
          ),
          scaffoldBackgroundColor: AppColors.backgroundPrimary,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
          ),
        ),
        routerConfig: appRouter,
      ),
    );
  }
}

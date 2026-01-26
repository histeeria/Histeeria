import 'dart:convert';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../data/models/user.dart';

/// Sign-in confirmation screen
///
/// Shows cached user data and asks "Is this your account?"
/// If yes, proceed to password. If no, go to email/password sign-in.
class SignInConfirmationScreen extends StatefulWidget {
  const SignInConfirmationScreen({super.key});

  @override
  State<SignInConfirmationScreen> createState() =>
      _SignInConfirmationScreenState();
}

class _SignInConfirmationScreenState extends State<SignInConfirmationScreen> {
  User? _cachedUser;
  bool _isLoading = true;
  final TokenStorageService _tokenStorage = TokenStorageService();

  @override
  void initState() {
    super.initState();
    _loadCachedUser();
  }

  Future<void> _loadCachedUser() async {
    try {
      final userData = await _tokenStorage.getUserData();
      if (userData != null && userData.isNotEmpty) {
        final userJson = jsonDecode(userData) as Map<String, dynamic>;
        setState(() {
          _cachedUser = User.fromJson(userJson);
          _isLoading = false;
        });
      } else {
        // No cached user - go to email/password sign-in
        if (mounted) {
          context.replace('/signin-email-password');
        }
      }
    } catch (e) {
      // Error loading cached user - go to email/password sign-in
      if (mounted) {
        context.replace('/signin-email-password');
      }
    }
  }

  void _handleYes() {
    // Navigate to password screen
    if (_cachedUser != null) {
      context.push('/signin-password', extra: _cachedUser!.email);
    }
  }

  void _handleNo() {
    // Navigate to email/password sign-in
    context.replace('/signin-email-password');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GradientBackground(
        colors: AppColors.gradientCool,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.accentPrimary,
              ),
            ),
          ),
        ),
      );
    }

    if (_cachedUser == null) {
      // This shouldn't happen, but handle it
      return const SizedBox.shrink();
    }

    return GradientBackground(
      colors: AppColors.gradientCool,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Is this your account?',
                  style: AppTextStyles.displayMedium(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We found an account associated with this device',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // User card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.glassBorder.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Profile picture
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.accentPrimary.withOpacity(
                          0.2,
                        ),
                        backgroundImage:
                            (_cachedUser!.profilePicture != null &&
                                _cachedUser!.profilePicture!.isNotEmpty)
                            ? NetworkImage(_cachedUser!.profilePicture!)
                            : null,
                        child:
                            (_cachedUser!.profilePicture == null ||
                                _cachedUser!.profilePicture!.isEmpty)
                            ? Text(
                                _cachedUser!.displayName.isNotEmpty
                                    ? _cachedUser!.displayName[0].toUpperCase()
                                    : _cachedUser!.username.isNotEmpty
                                    ? _cachedUser!.username[0].toUpperCase()
                                    : 'U',
                                style: AppTextStyles.displayMedium(),
                              )
                            : null,
                      ),
                      const SizedBox(height: 20),
                      // Display name
                      Text(
                        _cachedUser!.displayName,
                        style: AppTextStyles.headlineSmall(),
                      ),
                      const SizedBox(height: 8),
                      // Username
                      Text(
                        '@${_cachedUser!.username}',
                        style: AppTextStyles.bodyLarge(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Email
                      Text(
                        _cachedUser!.email,
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleNo,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.glassBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'No, that\'s not me',
                          style: AppTextStyles.labelLarge(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleYes,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Yes, continue',
                          style: AppTextStyles.labelLarge(
                            color: AppColors.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

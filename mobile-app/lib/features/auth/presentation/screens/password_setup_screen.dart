import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/providers/signup_state_provider.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/auth_service.dart';

class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({super.key});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  /// Upload profile picture in background (non-blocking for speed)
  void _uploadProfilePictureInBackground(
    File pictureFile,
    AuthProvider authProvider,
  ) {
    // Don't await - let it run in background without blocking navigation
    Future.microtask(() async {
      try {
        final token = await _authService.getAccessToken();
        if (token != null && token.isNotEmpty) {
          final pictureUrl = await _storageService.uploadProfilePicture(
            pictureFile,
          );
          developer.log('Profile picture uploaded in background: $pictureUrl');

          // Refresh user data in background
          final currentUserResponse = await _authService.getCurrentUser();
          if (currentUserResponse.success && currentUserResponse.data != null) {
            authProvider.setUser(currentUserResponse.data!);
            developer.log('User data refreshed in background');
          }
        }
      } catch (e) {
        developer.log('Background profile picture upload failed: $e');
        // Silently fail - user can upload later from settings
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePassword(String value) {
    setState(() {
      _isPasswordValid = value.length >= 8;
    });
    if (_confirmPasswordController.text.isNotEmpty) {
      _validateConfirmPassword(_confirmPasswordController.text);
    }
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      _isConfirmPasswordValid = value == _passwordController.text;
    });
  }

  Future<void> _handleComplete() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final signupProvider = context.read<SignupStateProvider>();
      final authProvider = context.read<AuthProvider>();

      // Store password in signup state
      signupProvider.setPassword(_passwordController.text);

      // Get complete signup state
      final signupState = signupProvider.state;

      // Validate all required fields are present
      if (!signupState.isComplete) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Please complete all required fields';
        });
        return;
      }

      // Register user with all collected data including verification code
      // Backend will verify the code if provided, or send a new one
      final registerResponse = await _authService.register(signupState);

      if (registerResponse.success && registerResponse.data != null) {
        // Check if user is already verified (if OTP was provided and valid)
        if (registerResponse.data!.token != null &&
            registerResponse.data!.user != null &&
            registerResponse.data!.user!.isEmailVerified) {
          // Registration and verification completed in one step
          authProvider.setUser(registerResponse.data!.user!);

          // Upload profile picture in background (non-blocking for speed)
          if (signupState.profilePicture != null &&
              signupState.profilePicture is File) {
            _uploadProfilePictureInBackground(
              signupState.profilePicture as File,
              authProvider,
            );
          }

          // Clear signup state
          signupProvider.clear();

          // Navigate to welcome complete
          if (mounted) {
            context.push('/welcome-complete');
          }
        } else if (registerResponse.data!.user != null) {
          // Registration successful, user object returned but email not verified yet
          // This can happen if OTP was invalid/expired during registration
          // Set user in auth provider (even if not verified)
          authProvider.setUser(registerResponse.data!.user!);

          // Try to verify email with the stored OTP code if available
          if (signupState.verificationCode != null &&
              signupState.verificationCode!.length == 6) {
            try {
              final verifyResponse = await _authService.verifyEmail(
                signupState.email!,
                signupState.verificationCode!,
              );

              if (verifyResponse.success &&
                  verifyResponse.data != null &&
                  verifyResponse.data!.token != null) {
                // Email verification successful - update user
                if (verifyResponse.data!.user != null) {
                  authProvider.setUser(verifyResponse.data!.user!);
                }

                // Upload profile picture in background (non-blocking for speed)
                if (signupState.profilePicture != null &&
                    signupState.profilePicture is File) {
                  _uploadProfilePictureInBackground(
                    signupState.profilePicture as File,
                    authProvider,
                  );
                }

                // Clear signup state
                signupProvider.clear();

                // Navigate to welcome complete
                if (mounted) {
                  context.push('/welcome-complete');
                }
                return; // Exit early on success
              }
            } catch (e) {
              developer.log('Email verification error: $e');
              // Continue to show message below
            }
          }

          // If verification failed or wasn't attempted, still proceed
          // User is created, they can verify email later
          developer.log(
            'Registration succeeded. Email verification: ${registerResponse.data!.user!.isEmailVerified}',
          );

          // Upload profile picture in background (non-blocking for speed)
          if (signupState.profilePicture != null &&
              signupState.profilePicture is File) {
            _uploadProfilePictureInBackground(
              signupState.profilePicture as File,
              authProvider,
            );
          }

          // Clear signup state
          signupProvider.clear();

          // Navigate to welcome complete (user can verify email later)
          if (mounted) {
            context.push('/welcome-complete');
          }
        } else {
          // Registration successful but no user object returned
          // This shouldn't happen, but handle it gracefully
          developer.log(
            'Registration succeeded but no user object. '
            'Response: ${registerResponse.message}',
          );

          setState(() {
            _isSubmitting = false;
            _errorMessage =
                registerResponse.message ??
                registerResponse.error ??
                'Registration successful! Please check your email for verification code.';
          });
        }
      } else {
        setState(() {
          _isSubmitting = false;
          // Extract user-friendly error message
          String errorMsg =
              registerResponse.message ??
              registerResponse.error ??
              'Registration failed. Please try again.';

          // Check for specific error patterns and provide better messages
          if (errorMsg.toLowerCase().contains('username') &&
              (errorMsg.toLowerCase().contains('already') ||
                  errorMsg.toLowerCase().contains('exists') ||
                  errorMsg.toLowerCase().contains('taken'))) {
            _errorMessage =
                'This username is already taken. Please choose a different username or sign in if you already have an account.';
          } else if (errorMsg.toLowerCase().contains('email') &&
              (errorMsg.toLowerCase().contains('already') ||
                  errorMsg.toLowerCase().contains('exists'))) {
            _errorMessage =
                'An account with this email already exists. Please sign in instead.';
          } else if (errorMsg.toLowerCase().contains('database')) {
            _errorMessage =
                'A server error occurred. Please try again or contact support if the problem persists.';
          } else {
            _errorMessage = errorMsg;
          }
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        // Provide user-friendly error messages
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('username') &&
            (errorString.contains('already') ||
                errorString.contains('exists') ||
                errorString.contains('taken'))) {
          _errorMessage =
              'This username is already taken. Please choose a different username or sign in if you already have an account.';
        } else {
          _errorMessage = 'An error occurred: ${e.toString()}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Secure your account',
                  style: AppTextStyles.displayMedium(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a strong password to keep your account safe. This is important!',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // Password form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.glassBorder.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Password
                        Text('Password', style: AppTextStyles.labelLarge()),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: AppTextStyles.bodyLarge(),
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            hintStyle: AppTextStyles.bodyMedium(),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.glassBorder,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.accentPrimary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.textSecondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          onChanged: _validatePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        if (_passwordController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _isPasswordValid
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                size: 16,
                                color: _isPasswordValid
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'At least 8 characters',
                                style: AppTextStyles.bodySmall(
                                  color: _isPasswordValid
                                      ? AppColors.success
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Confirm password
                        Text(
                          'Confirm password',
                          style: AppTextStyles.labelLarge(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: AppTextStyles.bodyLarge(),
                          decoration: InputDecoration(
                            hintText: 'Confirm your password',
                            hintStyle: AppTextStyles.bodyMedium(),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.glassBorder,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isConfirmPasswordValid
                                    ? AppColors.success
                                    : AppColors.accentPrimary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.textSecondary,
                            ),
                            suffixIcon:
                                _confirmPasswordController.text.isNotEmpty
                                ? Icon(
                                    _isConfirmPasswordValid
                                        ? Icons.check_circle
                                        : Icons.error_outline,
                                    color: _isConfirmPasswordValid
                                        ? AppColors.success
                                        : AppColors.error,
                                  )
                                : IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                          ),
                          onChanged: _validateConfirmPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Complete button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                (_isPasswordValid &&
                                    _isConfirmPasswordValid &&
                                    !_isSubmitting)
                                ? _handleComplete
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPrimary,
                              disabledBackgroundColor: AppColors.surface
                                  .withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.textPrimary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'All set, welcome onboard!',
                                    style: AppTextStyles.labelLarge(
                                      color: AppColors.textPrimary,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

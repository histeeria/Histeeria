import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/services/auth_service.dart';
import '../../data/providers/auth_provider.dart';

/// Sign-in with email and password screen
///
/// For users who don't have cached account or clicked "No, that's not me"
class SignInEmailPasswordScreen extends StatefulWidget {
  const SignInEmailPasswordScreen({super.key});

  @override
  State<SignInEmailPasswordScreen> createState() =>
      _SignInEmailPasswordScreenState();
}

class _SignInEmailPasswordScreenState extends State<SignInEmailPasswordScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (response.success && response.data != null) {
        final authProvider = context.read<AuthProvider>();
        if (response.data!.user != null) {
          authProvider.setUser(response.data!.user!);
        }

        if (mounted) {
          context.go('/home');
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              response.message ?? response.error ?? 'Sign-in failed';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: ${e.toString()}';
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text('Sign in', style: AppTextStyles.displayMedium()),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your email and password to continue',
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Email input
                  Text('Email', style: AppTextStyles.labelLarge()),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTextStyles.bodyLarge(),
                    decoration: InputDecoration(
                      hintText: 'your.email@example.com',
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
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // Password input
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
                      prefixIcon: Icon(
                        Icons.lock_outlined,
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
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
                  const SizedBox(height: 32),
                  // Sign in button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        disabledBackgroundColor: AppColors.surface.withOpacity(
                          0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
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
                              'Sign in',
                              style: AppTextStyles.labelLarge(
                                color: AppColors.textPrimary,
                                weight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

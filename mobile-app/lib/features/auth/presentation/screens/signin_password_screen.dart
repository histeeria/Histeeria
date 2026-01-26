import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/services/auth_service.dart';
import '../../data/providers/auth_provider.dart';

/// Sign-in password screen
///
/// Shows after user confirms their account from cache
class SignInPasswordScreen extends StatefulWidget {
  final String email;

  const SignInPasswordScreen({super.key, required this.email});

  @override
  State<SignInPasswordScreen> createState() => _SignInPasswordScreenState();
}

class _SignInPasswordScreenState extends State<SignInPasswordScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
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
        widget.email,
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
          // Extract user-friendly error message
          String errorMsg =
              response.message ?? response.error ?? 'Sign-in failed';

          // Check for common error patterns
          if (errorMsg.toLowerCase().contains('timeout') ||
              errorMsg.toLowerCase().contains('connection')) {
            errorMsg =
                'Cannot connect to server.\n\n'
                'Troubleshooting:\n'
                '• Ensure backend is running: cd backend && go run main.go\n'
                '• For Android emulator, use: http://10.0.2.2:8081/api/v1\n'
                '• For physical device, use your PC IP: http://192.168.x.x:8081/api/v1\n'
                '• Check API config: lib/core/config/api_config.dart';
          } else if (errorMsg.toLowerCase().contains('401') ||
              errorMsg.toLowerCase().contains('invalid') ||
              errorMsg.toLowerCase().contains('password')) {
            errorMsg = 'Invalid email or password. Please try again.';
          }

          _errorMessage = errorMsg;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Provide user-friendly error messages
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('timeout') ||
            errorString.contains('connection')) {
          _errorMessage =
              'Cannot connect to server. Please check:\n'
              '• Backend server is running\n'
              '• Correct IP address in API config\n'
              '• Device and server are on same network';
        } else if (errorString.contains('401') ||
            errorString.contains('authentication')) {
          _errorMessage = 'Invalid email or password. Please try again.';
        } else {
          _errorMessage = 'Sign-in failed: ${e.toString()}';
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Enter your password',
                    style: AppTextStyles.displayMedium(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Signing in as ${widget.email}',
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Password input
                  Text('Password', style: AppTextStyles.labelLarge()),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: AppTextStyles.bodyLarge(),
                    autofocus: true,
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
                    onFieldSubmitted: (_) => _handleSignIn(),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/providers/signup_state_provider.dart';
import '../../data/services/auth_service.dart';

class SignUpEmailScreen extends StatefulWidget {
  const SignUpEmailScreen({super.key});

  @override
  State<SignUpEmailScreen> createState() => _SignUpEmailScreenState();
}

class _SignUpEmailScreenState extends State<SignUpEmailScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEmailValid = false;
  bool _isSendingOTP = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    setState(() {
      _isEmailValid = RegExp(
        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
      ).hasMatch(value);
    });
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSendingOTP) return;

    setState(() {
      _isSendingOTP = true;
    });

    try {
      final email = _emailController.text.trim();
      final signupProvider = context.read<SignupStateProvider>();

      // Store email in signup state
      signupProvider.setEmail(email);

      // Send OTP for signup
      final response = await _authService.sendSignupOTP(email);

      if (response.success) {
        // Navigate to OTP verification screen
        if (mounted) {
          context.push('/otp-verification', extra: email);
        }
      } else {
        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message ?? response.error ?? 'Failed to send OTP',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
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
                  'What\'s your email?',
                  style: AppTextStyles.displayMedium(),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ll use this to keep your account secure and send you important updates.',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // Email input
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
                        Text(
                          'Email address',
                          style: AppTextStyles.labelLarge(),
                        ),
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
                            suffixIcon: _isEmailValid
                                ? Icon(
                                    Icons.check_circle,
                                    color: AppColors.success,
                                  )
                                : null,
                          ),
                          onChanged: _validateEmail,
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
                        // Continue button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_isEmailValid && !_isSendingOTP)
                                ? _handleContinue
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
                            child: _isSendingOTP
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
                                    'Continue',
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/api/exceptions/api_exception.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/providers/signup_state_provider.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/auth_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  
  const OTPVerificationScreen({super.key, required this.email});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isComplete = false;
  bool _isVerifying = false;
  bool _isVerified = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onOTPChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    
    // Check if all fields are filled
    bool allFilled = _controllers.every((c) => c.text.isNotEmpty);
    if (allFilled && !_isComplete) {
      setState(() {
        _isComplete = true;
      });
      // Auto verify immediately (no delay for speed)
        _verifyOTP();
    } else {
      setState(() {
        _isComplete = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_isVerifying || _isVerified) return;

    // Get OTP code from controllers
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final signupProvider = context.read<SignupStateProvider>();

      // Store email in signup state if not already set
      if (signupProvider.state.email != widget.email) {
        signupProvider.setEmail(widget.email);
      }

      // First, try to verify email (this will work if user exists - login flow)
      final verifyEmailResponse = await _authService.verifyEmail(
        widget.email,
        code,
      );

      if (verifyEmailResponse.success && verifyEmailResponse.data != null) {
        // User exists - this is a login flow
        setState(() {
          _isVerified = true;
          _isVerifying = false;
        });

        // Store verification code in state
        signupProvider.setVerificationCode(code);

        // Check if user is fully verified
        if (verifyEmailResponse.data!.user != null &&
            verifyEmailResponse.data!.user!.isEmailVerified) {
          // User is fully registered and verified - this is a login
          if (mounted) {
            final authProvider = context.read<AuthProvider>();
            authProvider.setUser(verifyEmailResponse.data!.user!);

            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                context.go('/home');
              }
            });
          }
          return;
        }
      }

      // User doesn't exist yet - this is a new signup
      // Verify the OTP against the signup OTP stored in Redis
      final verifySignupResponse = await _authService.verifySignupOTP(
        widget.email,
        code,
      );

      if (verifySignupResponse.success) {
        // OTP is valid for signup
        setState(() {
          _isVerified = true;
          _isVerifying = false;
        });

        // Store verification code in state
        signupProvider.setVerificationCode(code);

        // Continue to account name screen immediately (no delay for speed)
        if (mounted) {
    context.push('/account-name');
        }
      } else {
        // OTP verification failed - show user-friendly error
        String errorMessage = 'Invalid verification code. Please try again.';

        if (verifySignupResponse.error != null &&
            verifySignupResponse.error!.isNotEmpty) {
          errorMessage = verifySignupResponse.error!;
        } else if (verifySignupResponse.message != null &&
            verifySignupResponse.message!.isNotEmpty) {
          errorMessage = verifySignupResponse.message!;
        }

        setState(() {
          _isVerifying = false;
          _isComplete = false;
          _errorMessage = errorMessage;
        });

        // Clear OTP fields on error
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      // Extract user-friendly error message
      String errorMessage = 'Failed to verify code. Please try again.';

      if (e is ApiException) {
        if (e is ValidationException) {
          errorMessage = e.message.isNotEmpty
              ? e.message
              : 'Invalid verification code. Please check and try again.';
        } else if (e is NetworkException) {
          errorMessage =
              'Network error. Please check your connection and try again.';
        } else if (e.message.isNotEmpty) {
          errorMessage = e.message;
        }
      } else if (e.toString().contains('Invalid') ||
          e.toString().contains('invalid')) {
        errorMessage = 'Invalid verification code. Please try again.';
      } else if (e.toString().contains('expired') ||
          e.toString().contains('Expired')) {
        errorMessage =
            'Verification code has expired. Please request a new one.';
      }

      setState(() {
        _isVerifying = false;
        _isComplete = false;
        _errorMessage = errorMessage;
      });

      // Clear OTP fields on error
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      AppLogger.info('Resending OTP to: ${widget.email}', 'OTP');
      
      final response = await _authService.sendSignupOTP(widget.email);
      
      if (!mounted) return;
      
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification code sent! Check your email.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.error ?? 'Failed to resend code. Please try again.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to resend OTP', e, null, 'OTP');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to resend code. Please check your connection.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientPurple,
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
                Text('Almost there!', style: AppTextStyles.displayMedium()),
                const SizedBox(height: 8),
                Text(
                  'We\'ve sent a verification code to',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.accentPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),
                // OTP input fields
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
                      Text(
                        'Enter the code',
                        style: AppTextStyles.headlineSmall(),
                      ),
                      const SizedBox(height: 32),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth;
                          final spacing = 8.0;
                          final fieldWidth =
                              ((availableWidth - (5 * spacing)) / 6).clamp(
                                40.0,
                                48.0,
                              );
                          
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width: fieldWidth,
                                child: _OTPInputField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  onChanged: (value) =>
                                      _onOTPChanged(index, value),
                                  onBackspace: index > 0
                                      ? () => _focusNodes[index - 1]
                                            .requestFocus()
                                      : null,
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      if (_isVerifying) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.accentPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Verifying...',
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.accentPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_isVerified) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Verified!',
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Resend code
                Center(
                  child: TextButton(
                    onPressed: _isVerifying ? null : _resendOTP,
                    child: Text(
                      'Didn\'t receive the code? Resend',
                      style: AppTextStyles.bodyMedium(
                        color: _isVerifying
                            ? AppColors.textTertiary
                            : AppColors.accentPrimary,
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
    );
  }
}

class _OTPInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onBackspace;

  const _OTPInputField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focusNode.hasFocus
              ? AppColors.accentPrimary
              : AppColors.glassBorder.withOpacity(0.5),
          width: focusNode.hasFocus ? 2 : 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: AppTextStyles.displaySmall(),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            onChanged(value);
          } else if (value.isEmpty && onBackspace != null) {
            onBackspace!();
          }
        },
        onSubmitted: (_) {
          if (controller.text.isEmpty && onBackspace != null) {
            onBackspace!();
          }
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEmailValid = false;

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

  void _handleEmailSignIn() {
    if (_formKey.currentState!.validate()) {
      // Navigate to confirmation screen (will check for cached user)
      // If no cached user, it will redirect to email/password screen
      context.push('/signin-confirmation');
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
                Text('Welcome back!', style: AppTextStyles.displayMedium()),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue your journey',
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
                            onPressed: _isEmailValid
                                ? _handleEmailSignIn
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
                            child: Text(
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
                const SizedBox(height: 32),
                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Container(height: 1, color: AppColors.glassBorder),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: AppTextStyles.bodyMedium()),
                    ),
                    Expanded(
                      child: Container(height: 1, color: AppColors.glassBorder),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Social sign in buttons
                _SocialSignInButton(
                  icon: Icons.g_mobiledata,
                  label: 'Continue with Google',
                  color: AppColors.googleRed,
                  onPressed: () {
                    // TODO: Implement Google sign in
                  },
                ),
                const SizedBox(height: 16),
                _SocialSignInButton(
                  icon: Icons.business,
                  label: 'Continue with LinkedIn',
                  color: AppColors.linkedInBlue,
                  onPressed: () {
                    // TODO: Implement LinkedIn sign in
                  },
                ),
                const SizedBox(height: 16),
                _SocialSignInButton(
                  icon: Icons.code,
                  label: 'Continue with GitHub',
                  color: AppColors.githubGray,
                  onPressed: () {
                    // TODO: Implement GitHub sign in
                  },
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

class _SocialSignInButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _SocialSignInButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.glassBorder.withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3), width: 1),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: AppTextStyles.labelLarge())),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

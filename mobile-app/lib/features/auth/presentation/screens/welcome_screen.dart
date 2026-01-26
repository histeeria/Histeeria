import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        // Logo with animation
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentPrimary.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/icons/u.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.accentPrimary,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Icon(
                                      Icons.rocket_launch,
                                      size: 50,
                                      color: AppColors.textPrimary,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Welcome message
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              Text(
                                'Welcome to Histeeria',
                                style: AppTextStyles.displayLarge(),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Where creators connect, collaborate, and grow together. Join our vibrant community and start your journey today.',
                                style: AppTextStyles.bodyLarge(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(flex: 3),
                        // Action buttons
                        Column(
                          children: [
                            // Sign in button
                            _WelcomeButton(
                              text: 'I already have an account',
                              onPressed: () {
                                context.push('/signin-options');
                              },
                              isPrimary: false,
                            ),
                            const SizedBox(height: 16),
                            // Sign up button
                            _WelcomeButton(
                              text: 'I\'m new here',
                              onPressed: () {
                                context.push('/signup-options');
                              },
                              isPrimary: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Privacy policy and terms footer
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: _PrivacyTermsFooter(),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomeButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _WelcomeButton({
    required this.text,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  State<_WelcomeButton> createState() => _WelcomeButtonState();
}

class _WelcomeButtonState extends State<_WelcomeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.isPrimary
                ? LinearGradient(
                    colors: [
                      AppColors.accentPrimary.withOpacity(0.9),
                      AppColors.accentSecondary.withOpacity(0.9),
                    ],
                  )
                : null,
            color: widget.isPrimary ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: widget.isPrimary
                ? null
                : Border.all(
                    color: AppColors.glassBorder.withOpacity(0.5),
                    width: 1.5,
                  ),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.accentPrimary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.text,
              style: AppTextStyles.labelLarge(
                color: widget.isPrimary
                    ? AppColors.textPrimary
                    : AppColors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyTermsFooter extends StatelessWidget {
  const _PrivacyTermsFooter();

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.bodySmall(
          color: AppColors.textTertiary,
        ),
        children: [
          const TextSpan(text: 'By signing in, you agree to Histeeria\'s '),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _launchURL('https://www.histeeria.com/privacy-policy'),
              child: Text(
                'Privacy Policy',
                style: AppTextStyles.bodySmall(
                  color: AppColors.accentPrimary,
                  weight: FontWeight.w600,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accentPrimary,
                ),
              ),
            ),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _launchURL('https://www.histeeria.com/terms-of-use'),
              child: Text(
                'Terms & Conditions',
                style: AppTextStyles.bodySmall(
                  color: AppColors.accentPrimary,
                  weight: FontWeight.w600,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accentPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

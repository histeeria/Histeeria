import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';

class WelcomeCompleteScreen extends StatefulWidget {
  const WelcomeCompleteScreen({super.key});

  @override
  State<WelcomeCompleteScreen> createState() => _WelcomeCompleteScreenState();
}

class _WelcomeCompleteScreenState extends State<WelcomeCompleteScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();

    // Scale animation for reward icon
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Rotation animation
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );

    // Fade animation for button
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Start animations
    _scaleController.forward();
    _rotationController.repeat();

    // Show button immediately (no delay for speed)
      if (mounted) {
        setState(() {
          _showButton = true;
        });
        _fadeController.forward();
      }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleGetStarted() {
    // Navigate to home with smooth transition
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reward icon with animations
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _scaleAnimation,
                      _rotationAnimation,
                    ]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Transform.rotate(
                          angle: _rotationAnimation.value * 0.1,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accentPrimary, // Purple
                                  AppColors.accentSecondary, // Pink
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentPrimary.withOpacity(
                                    0.5,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.celebration,
                              size: 60,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  // Welcome message
                  Text(
                    'You\'re all set!',
                    style: AppTextStyles.displayMedium(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to your new creative home. Let\'s start building something amazing together!',
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  // Get started button
                  if (_showButton)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _RewardButton(onTap: _handleGetStarted),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardButton extends StatefulWidget {
  final VoidCallback onTap;

  const _RewardButton({required this.onTap});

  @override
  State<_RewardButton> createState() => _RewardButtonState();
}

class _RewardButtonState extends State<_RewardButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
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
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accentPrimary, // Purple
                AppColors.accentSecondary, // Pink
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Get Started',
              style: AppTextStyles.labelLarge(
                color: AppColors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

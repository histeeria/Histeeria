import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';

class SignUpOptionsScreen extends StatefulWidget {
  const SignUpOptionsScreen({super.key});

  @override
  State<SignUpOptionsScreen> createState() => _SignUpOptionsScreenState();
}

class _SignUpOptionsScreenState extends State<SignUpOptionsScreen> {
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentPrimary.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icons/u.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.rocket_launch,
                            size: 40,
                            color: AppColors.textPrimary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Let\'s get started!',
                  style: AppTextStyles.displayMedium(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you\'d like to sign up',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Email sign up button
                _SignUpOptionButton(
                  icon: Icons.email_outlined,
                  iconColor: AppColors.accentPrimary,
                  label: 'Email',
                  description: 'Create account with your email',
                  onPressed: () {
                    context.push('/signup-email');
                  },
                  isEmail: true,
                ),
                const SizedBox(height: 24),
                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Container(height: 1, color: AppColors.glassBorder),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(height: 1, color: AppColors.glassBorder),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Social sign up buttons in a row
                Row(
                  children: [
                    Expanded(
                      child: _SocialSignUpButton(
                        icon: FontAwesomeIcons.google,
                        iconColor: const Color(0xFFDB4437),
                        label: 'Google',
                        onPressed: () {
                          context.push('/account-name');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SocialSignUpButton(
                        icon: FontAwesomeIcons.linkedin,
                        iconColor: const Color(0xFF0077B5),
                        label: 'LinkedIn',
                        onPressed: () {
                          context.push('/account-name');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SocialSignUpButton(
                        icon: FontAwesomeIcons.github,
                        iconColor: AppColors.textPrimary,
                        label: 'GitHub',
                        onPressed: () {
                          context.push('/account-name');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _PrivacyTermsFooter(),
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

class _SignUpOptionButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? description;
  final VoidCallback onPressed;
  final bool isEmail;

  const _SignUpOptionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.description,
    required this.onPressed,
    this.isEmail = false,
  });

  @override
  State<_SignUpOptionButton> createState() => _SignUpOptionButtonState();
}

class _SignUpOptionButtonState extends State<_SignUpOptionButton>
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
      end: 0.97,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: widget.isEmail
                ? LinearGradient(
                    colors: [
                      AppColors.accentPrimary.withOpacity(0.15),
                      AppColors.accentSecondary.withOpacity(0.15),
                    ],
                  )
                : null,
            color: widget.isEmail ? null : AppColors.glassBackground,
            border: Border.all(
              color: widget.isEmail
                  ? AppColors.accentPrimary.withOpacity(0.4)
                  : AppColors.glassBorder.withOpacity(0.3),
              width: widget.isEmail ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.isEmail
                    ? AppColors.accentPrimary.withOpacity(0.15)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: widget.isEmail
                      ? LinearGradient(
                    colors: [
                      AppColors.accentPrimary.withOpacity(0.2),
                      AppColors.accentSecondary.withOpacity(0.2),
                    ],
                        )
                      : null,
                  color: widget.isEmail
                      ? null
                      : AppColors.surface.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isEmail
                        ? AppColors.accentPrimary.withOpacity(0.3)
                        : AppColors.glassBorder.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign up with ${widget.label}',
                      style: AppTextStyles.headlineSmall(),
                    ),
                    if (widget.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.description!,
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialSignUpButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onPressed;

  const _SocialSignUpButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_SocialSignUpButton> createState() => _SocialSignUpButtonState();
}

class _SocialSignUpButtonState extends State<_SocialSignUpButton>
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            border: Border.all(
              color: AppColors.glassBorder.withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                widget.icon,
                color: widget.iconColor,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: AppTextStyles.bodySmall(
                color: AppColors.textSecondary,
                ),
              ),
            ],
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
          const TextSpan(text: 'By signing up, you agree to Histeeria\'s '),
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


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../data/models/user.dart';

/// Sign-in options screen
///
/// Shows cached user account (if exists) and all sign-in options:
/// - "Yes, continue" (if cached user exists) → password screen
/// - "Continue with email" → email + password screen
/// - Social logins (Google, LinkedIn, GitHub) → OAuth flow
class SignInOptionsScreen extends StatefulWidget {
  const SignInOptionsScreen({super.key});

  @override
  State<SignInOptionsScreen> createState() => _SignInOptionsScreenState();
}

class _SignInOptionsScreenState extends State<SignInOptionsScreen> {
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
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleYesContinue() {
    if (_cachedUser != null) {
      context.push('/signin-password', extra: _cachedUser!.email);
    }
  }

  void _handleContinueWithEmail() {
    context.push('/signin-email-password');
  }

  void _handleSocialSignIn(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider sign-in coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
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
                  'Welcome back!',
                  style: AppTextStyles.displayMedium(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue your journey',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Cached user card (if exists)
                if (_cachedUser != null) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.glassBackground,
                      border: Border.all(
                        color: AppColors.glassBorder.withOpacity(0.3),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Is this your account?',
                          style: AppTextStyles.headlineSmall(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.accentPrimary.withOpacity(0.2),
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
                        Text(
                          _cachedUser!.displayName,
                          style: AppTextStyles.headlineSmall(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '@${_cachedUser!.username}',
                          style: AppTextStyles.bodyLarge(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _cachedUser!.email,
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _handleYesContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              shadowColor: AppColors.accentPrimary.withOpacity(0.3),
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
                  ),
                  const SizedBox(height: 32),
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
                  const SizedBox(height: 32),
                ],
                // Sign-in options grid
                _SignInOptionButton(
                  icon: Icons.email_outlined,
                  iconColor: AppColors.textPrimary,
                  label: 'Email',
                  onPressed: _handleContinueWithEmail,
                ),
                const SizedBox(height: 12),
                // Social options in a row
                Row(
                  children: [
                    Expanded(
                      child: _SocialSignInButton(
                        icon: FontAwesomeIcons.google,
                        iconColor: const Color(0xFFDB4437),
                  onPressed: () => _handleSocialSignIn('Google'),
                ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SocialSignInButton(
                        icon: FontAwesomeIcons.linkedin,
                        iconColor: const Color(0xFF0077B5),
                  onPressed: () => _handleSocialSignIn('LinkedIn'),
                ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SocialSignInButton(
                        icon: FontAwesomeIcons.github,
                        iconColor: AppColors.textPrimary,
                  onPressed: () => _handleSocialSignIn('GitHub'),
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

class _SignInOptionButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onPressed;

  const _SignInOptionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_SignInOptionButton> createState() => _SignInOptionButtonState();
}

class _SignInOptionButtonState extends State<_SignInOptionButton>
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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.glassBorder.withOpacity(0.2),
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
                child: Text(
                  'Continue with ${widget.label}',
                  style: AppTextStyles.headlineSmall(),
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

class _SocialSignInButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const _SocialSignInButton({
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  State<_SocialSignInButton> createState() => _SocialSignInButtonState();
}

class _SocialSignInButtonState extends State<_SocialSignInButton>
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
          height: 64,
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
          child: Center(
            child: FaIcon(
              widget.icon,
              color: widget.iconColor,
              size: 28,
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
              onTap: () => _launchURL('https://histeeria.com/privacy'),
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
              onTap: () => _launchURL('https://histeeria.com/terms'),
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


import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';

class SocialLinksScreen extends StatefulWidget {
  const SocialLinksScreen({super.key});

  @override
  State<SocialLinksScreen> createState() => _SocialLinksScreenState();
}

class _SocialLinksScreenState extends State<SocialLinksScreen> {
  final Map<String, TextEditingController> _controllers = {
    'Instagram': TextEditingController(text: '@johndoe'),
    'Twitter': TextEditingController(text: '@johndoe'),
    'LinkedIn': TextEditingController(text: 'linkedin.com/in/johndoe'),
    'GitHub': TextEditingController(text: 'github.com/johndoe'),
    'Facebook': TextEditingController(),
    'YouTube': TextEditingController(),
    'TikTok': TextEditingController(),
    'Website': TextEditingController(text: 'johndoe.com'),
  };

  bool _isLoading = false;

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _saveLinks() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });

    _showMessage('Social links updated successfully');
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.backgroundSecondary.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  IconData _getIcon(String platform) {
    switch (platform) {
      case 'Instagram':
        return FontAwesomeIcons.instagram;
      case 'Twitter':
        return FontAwesomeIcons.twitter;
      case 'LinkedIn':
        return FontAwesomeIcons.linkedin;
      case 'GitHub':
        return FontAwesomeIcons.github;
      case 'Facebook':
        return FontAwesomeIcons.facebook;
      case 'YouTube':
        return FontAwesomeIcons.youtube;
      case 'TikTok':
        return FontAwesomeIcons.tiktok;
      case 'Website':
        return Icons.language;
      default:
        return Icons.link;
    }
  }

  Color _getColor(String platform) {
    switch (platform) {
      case 'Instagram':
        return const Color(0xFFE4405F);
      case 'Twitter':
        return const Color(0xFF1DA1F2);
      case 'LinkedIn':
        return const Color(0xFF0077B5);
      case 'GitHub':
        return const Color(0xFF333333);
      case 'Facebook':
        return const Color(0xFF1877F2);
      case 'YouTube':
        return const Color(0xFFFF0000);
      case 'TikTok':
        return const Color(0xFF000000);
      case 'Website':
        return AppColors.accentPrimary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Social Links',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.accentPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Connect your social media profiles to make it easier for people to find and follow you.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Social Links
                    ..._controllers.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getIcon(entry.key),
                                  size: 20,
                                  color: _getColor(entry.key),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key,
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: entry.value,
                              style: AppTextStyles.bodyMedium(),
                              decoration: InputDecoration(
                                hintText: 'Enter your ${entry.key} profile',
                                hintStyle: AppTextStyles.bodyMedium(
                                  color: AppColors.textTertiary,
                                ),
                                prefixIcon: Icon(
                                  _getIcon(entry.key),
                                  color: _getColor(entry.key),
                                  size: 20,
                                ),
                                suffixIcon: entry.value.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: AppColors.textSecondary,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            entry.value.clear();
                                          });
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.glassBorder.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.glassBorder.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _getColor(entry.key),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 12),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveLinks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          disabledBackgroundColor:
                              AppColors.textTertiary.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Save Social Links',
                                style: AppTextStyles.bodyLarge(
                                  color: Colors.white,
                                  weight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


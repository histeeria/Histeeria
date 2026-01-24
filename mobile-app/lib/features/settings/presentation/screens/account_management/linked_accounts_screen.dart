import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  final Map<String, String?> _linkedAccounts = {
    'Facebook': null,
    'Twitter': null,
    'LinkedIn': null,
    'GitHub': null,
    'Instagram': null,
  };

  bool _isLoading = false;

  Future<void> _manageAccount(String platform) async {
    final currentUrl = _linkedAccounts[platform];

    if (currentUrl != null) {
      // Show options: Edit or Unlink
      final action = await _showAccountOptions(platform);
      if (action == 'edit') {
        _showAddUrlDialog(platform, currentUrl);
      } else if (action == 'unlink') {
        _unlinkAccount(platform);
      }
    } else {
      // Show add URL dialog
      _showAddUrlDialog(platform, null);
    }
  }

  Future<void> _unlinkAccount(String platform) async {
    final confirm = await _showUnlinkDialog(platform);
    if (confirm != true) return;

    setState(() {
      _linkedAccounts[platform] = null;
    });

    _showMessage('$platform account unlinked successfully');
  }

  Future<String?> _showAccountOptions(String platform) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.edit, color: AppColors.textPrimary),
                title: Text('Edit URL', style: AppTextStyles.bodyMedium()),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: Icon(Icons.link_off, color: AppColors.accentQuaternary),
                title: Text(
                  'Unlink Account',
                  style: AppTextStyles.bodyMedium(color: AppColors.accentQuaternary),
                ),
                onTap: () => Navigator.pop(context, 'unlink'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddUrlDialog(String platform, String? currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '${currentUrl == null ? 'Add' : 'Edit'} $platform Profile',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your $platform profile URL',
              style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTextStyles.bodyMedium(),
              decoration: InputDecoration(
                hintText: _getPlaceholder(platform),
                hintStyle: AppTextStyles.bodySmall(
                  color: AppColors.textTertiary,
                ),
                prefixIcon: Icon(
                  Icons.link,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.backgroundPrimary.withOpacity(0.5),
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
                    color: AppColors.accentPrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isEmpty) {
                Navigator.pop(context);
                _showMessage('Please enter a URL');
                return;
              }
              
              if (!_isValidUrl(url)) {
                Navigator.pop(context);
                _showMessage('Please enter a valid URL');
                return;
              }

              setState(() {
                _linkedAccounts[platform] = url;
              });
              
              Navigator.pop(context);
              _showMessage('$platform profile ${currentUrl == null ? 'added' : 'updated'} successfully');
            },
            child: Text(
              'Save',
              style: AppTextStyles.bodyMedium(
                color: AppColors.accentPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPlaceholder(String platform) {
    switch (platform) {
      case 'Facebook':
        return 'https://facebook.com/username';
      case 'Twitter':
        return 'https://twitter.com/username';
      case 'LinkedIn':
        return 'https://linkedin.com/in/username';
      case 'GitHub':
        return 'https://github.com/username';
      case 'Instagram':
        return 'https://instagram.com/username';
      default:
        return 'https://...';
    }
  }

  bool _isValidUrl(String url) {
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }

  Future<bool?> _showUnlinkDialog(String platform) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Unlink $platform?',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'You won\'t be able to sign in with $platform anymore. You can always link it again later.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Unlink',
              style: AppTextStyles.bodyMedium(
                color: AppColors.accentQuaternary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'Google':
        return FontAwesomeIcons.google;
      case 'Facebook':
        return FontAwesomeIcons.facebook;
      case 'Twitter':
        return FontAwesomeIcons.xTwitter;
      case 'LinkedIn':
        return FontAwesomeIcons.linkedin;
      case 'GitHub':
        return FontAwesomeIcons.github;
      case 'Instagram':
        return FontAwesomeIcons.instagram;
      default:
        return Icons.link;
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'Google':
        return const Color(0xFF4285F4);
      case 'Facebook':
        return const Color(0xFF4A9FF5);
      case 'Twitter':
        return const Color(0xFFE8E8E8);
      case 'LinkedIn':
        return const Color(0xFF2D9CDB);
      case 'GitHub':
        return const Color(0xFFBBBBBB);
      case 'Instagram':
        return const Color(0xFFFF6B9D);
      default:
        return AppColors.accentPrimary;
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
                      'Linked Accounts',
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
                              'Add URLs to your social media profiles. These will be displayed on your Histeeria profile.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Linked Accounts List
                    ..._linkedAccounts.entries.map((entry) {
                      final platform = entry.key;
                      final profileUrl = entry.value;
                      final isLinked = profileUrl != null;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoading ? null : () => _manageAccount(platform),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isLinked
                                      ? _getPlatformColor(platform).withOpacity(0.5)
                                      : AppColors.glassBorder.withOpacity(0.2),
                                  width: isLinked ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _getPlatformColor(platform).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: FaIcon(
                                        _getPlatformIcon(platform),
                                        color: _getPlatformColor(platform),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          platform,
                                          style: AppTextStyles.bodyMedium(
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isLinked
                                              ? profileUrl
                                              : 'Not connected',
                                          style: AppTextStyles.bodySmall(
                                            color: isLinked
                                                ? AppColors.success
                                                : AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isLoading)
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.accentPrimary,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      isLinked ? Icons.edit : Icons.add,
                                      color: isLinked
                                          ? AppColors.accentPrimary
                                          : AppColors.textSecondary,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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


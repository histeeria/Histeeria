import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _updateService = UpdateService();
  String _searchQuery = '';
  bool _checkingUpdate = false;

  Future<void> _checkForUpdates(BuildContext context) async {
    setState(() => _checkingUpdate = true);
    
    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking for updates...'), duration: Duration(seconds: 1)),
    );

    final info = await _updateService.checkForUpdates();
    setState(() => _checkingUpdate = false);

    if (!mounted) return;

    if (info != null && info.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Update Available! 🚀'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version ${info.latestVersion} is now available.'),
              const SizedBox(height: 8),
              Text(info.releaseNotes, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateService.downloadUpdate(info.downloadUrl);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the latest version! ✅')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredSettings {
    final allSettings = [
      {
        'icon': Icons.person_outline,
        'title': 'Account',
        'subtitle': 'Privacy, security, personal details',
      },
      {
        'icon': Icons.badge_outlined,
        'title': 'Profile',
        'subtitle': 'Edit your profile information',
        'route': '/settings/profile',
      },
      {
        'icon': Icons.lock_outline,
        'title': 'Security',
        'subtitle': 'Password, two-factor authentication',
        'route': '/settings/security',
      },
      {
        'icon': Icons.notifications_outlined,
        'title': 'Notifications',
        'subtitle': 'Manage your notification preferences',
        'route': '/settings/notifications',
      },
      {
        'icon': Icons.message_outlined,
        'title': 'Messages',
        'subtitle': 'Chat settings and preferences',
        'route': '/settings/messages',
      },
      {
        'icon': Icons.shield_outlined,
        'title': 'Data & Privacy',
        'subtitle': 'Control your data and privacy',
        'route': '/settings/privacy',
      },
      {
        'icon': Icons.groups_outlined,
        'title': 'Communities',
        'subtitle': 'Manage your communities',
      },
      {
        'icon': Icons.work_outline,
        'title': 'Jobs',
        'subtitle': 'Job preferences and applications',
      },
      {
        'icon': Icons.payment_outlined,
        'title': 'Payments & Orders',
        'subtitle': 'Payment methods and order history',
      },
      {
        'icon': Icons.verified_user_outlined,
        'title': 'Verification Center',
        'subtitle': 'Get verified badge',
      },
      {
        'icon': Icons.block_outlined,
        'title': 'Blocked & Restricted',
        'subtitle': 'Manage blocked accounts',
      },
      {
        'icon': Icons.phonelink_setup_outlined,
        'title': 'Device Permissions',
        'subtitle': 'Camera, microphone, location',
      },
      {
        'icon': Icons.accessibility_new_outlined,
        'title': 'Accessibility',
        'subtitle': 'Screen reader, captions',
      },
      {
        'icon': Icons.data_usage_outlined,
        'title': 'Data Usage & Media Quality',
        'subtitle': 'Network usage, media quality',
      },
      {
        'icon': Icons.family_restroom_outlined,
        'title': 'Parental Control',
        'subtitle': 'Supervision and safety',
      },
      {
        'icon': Icons.palette_outlined,
        'title': 'Appearance',
        'subtitle': 'Theme, dark mode',
      },
      {
        'icon': Icons.language_outlined,
        'title': 'Language',
        'subtitle': 'Change app language',
      },
      {
        'icon': Icons.system_update_outlined,
        'title': 'App Updates',
        'subtitle': 'Check for new versions',
        'action': 'check_update',
      },
      {
        'icon': Icons.help_outline,
        'title': 'Help & Support',
        'subtitle': 'Help center, contact us',
      },
    ];

    if (_searchQuery.isEmpty) {
      return allSettings;
    }

    return allSettings.where((setting) {
      final title = setting['title'].toString().toLowerCase();
      final subtitle = setting['subtitle'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || subtitle.contains(query);
    }).toList();
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
              // Settings Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                      'Settings',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Search Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: AppTextStyles.bodyLarge(),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search settings...',
                          hintStyle: AppTextStyles.bodyLarge(
                            color: AppColors.textTertiary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  child: Icon(
                                    Icons.clear,
                                    color: AppColors.textSecondary,
                                    size: 22,
                                  ),
                                )
                              : null,
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Settings List
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filteredSettings.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _filteredSettings.length) {
                      return const SizedBox(height: 20);
                    }
                    final setting = _filteredSettings[index];
                    final title = setting['title'] as String;
                    return _SettingsItem(
                      icon: setting['icon'] as IconData,
                      title: title,
                      subtitle: setting['subtitle'] as String,
                      onTap: () {
                        if (title == 'Account') {
                          context.push('/settings/account');
                        } else if (setting['route'] != null) {
                          context.push(setting['route']);
                        } else if (setting['action'] == 'check_update') {
                          _checkForUpdates(context);
                        } else {
                          // TODO: Navigate to other settings
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Settings Item - Instagram style
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 26),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium(weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Divider removed for cleaner look

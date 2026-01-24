import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  bool _personalizedAds = true;
  bool _allowTracking = false;
  bool _activityStatus = true;

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
                      'Data & Privacy',
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
                    // Privacy Dashboard Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success.withOpacity(0.2),
                            AppColors.accentPrimary.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.privacy_tip,
                                  color: AppColors.success,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Privacy Score',
                                      style: AppTextStyles.bodyMedium(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '78',
                                          style: AppTextStyles.headlineLarge(
                                            color: AppColors.success,
                                            weight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '/100',
                                          style: AppTextStyles.bodyLarge(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Good privacy settings',
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.success,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickStat(
                                  icon: Icons.shield_outlined,
                                  value: '6',
                                  label: 'Permissions',
                                ),
                              ),
                              Expanded(
                                child: _QuickStat(
                                  icon: Icons.apps,
                                  value: '3',
                                  label: 'Connected Apps',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                context.push('/settings/privacy/checkup');
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.success,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Run Privacy Checkup',
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.success,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Data Collection & Usage
                    _SectionHeader(
                      icon: Icons.dataset_outlined,
                      title: 'Data Collection & Usage',
                    ),
                    _SettingsItem(
                      icon: Icons.info_outline,
                      title: 'What We Collect',
                      subtitle: 'See data we collect',
                      onTap: () {
                        context.push('/settings/privacy/what-we-collect');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.insights_outlined,
                      title: 'How We Use Your Data',
                      subtitle: 'Data usage purposes',
                      onTap: () {
                        context.push('/settings/privacy/how-we-use-data');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.share_outlined,
                      title: 'Data Sharing',
                      subtitle: 'Third-party sharing',
                      onTap: () {
                        context.push('/settings/privacy/data-sharing');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Privacy Controls
                    _SectionHeader(
                      icon: Icons.lock_outline,
                      title: 'Privacy Controls',
                    ),
                    _SettingsItem(
                      icon: Icons.visibility_outlined,
                      title: 'Profile Privacy',
                      subtitle: 'Public',
                      onTap: () {
                        context.push('/settings/privacy/profile-privacy');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.circle,
                      title: 'Activity Status',
                      subtitle: _activityStatus ? 'Visible' : 'Hidden',
                      trailing: Switch(
                        value: _activityStatus,
                        onChanged: (value) => setState(() => _activityStatus = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.post_add_outlined,
                      title: 'Post Privacy Default',
                      subtitle: 'Public',
                      onTap: () {
                        context.push('/settings/privacy/post-privacy');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.comment_outlined,
                      title: 'Who Can Comment',
                      subtitle: 'Everyone',
                      onTap: () {
                        context.push('/settings/privacy/comment-privacy');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Your Data
                    _SectionHeader(
                      icon: Icons.folder_outlined,
                      title: 'Your Data',
                    ),
                    _SettingsItem(
                      icon: Icons.download_outlined,
                      title: 'Download Your Data',
                      subtitle: 'GDPR export',
                      onTap: () {
                        context.push('/settings/privacy/download-data');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.history,
                      title: 'Activity Log',
                      subtitle: 'View your activity',
                      onTap: () {
                        context.push('/settings/privacy/activity-log');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.delete_outline,
                      title: 'Delete Specific Data',
                      subtitle: 'Remove selected items',
                      onTap: () {
                        context.push('/settings/privacy/delete-data');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.clear_all,
                      title: 'Clear Activity History',
                      subtitle: 'Wipe activity log',
                      onTap: () {
                        context.push('/settings/privacy/clear-history');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Ads & Tracking
                    _SectionHeader(
                      icon: Icons.ads_click_outlined,
                      title: 'Ads & Tracking',
                    ),
                    _SettingsItem(
                      icon: Icons.ad_units,
                      title: 'Personalized Ads',
                      subtitle: _personalizedAds ? 'Enabled' : 'Disabled',
                      trailing: Switch(
                        value: _personalizedAds,
                        onChanged: (value) => setState(() => _personalizedAds = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.track_changes,
                      title: 'Allow Tracking',
                      subtitle: _allowTracking ? 'Apps can track' : 'Tracking disabled',
                      trailing: Switch(
                        value: _allowTracking,
                        onChanged: (value) => setState(() => _allowTracking = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.tune,
                      title: 'Ad Preferences',
                      subtitle: 'Manage ad interests',
                      onTap: () {
                        context.push('/settings/privacy/ad-preferences');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.link_off,
                      title: 'Off-Platform Activity',
                      subtitle: 'Activity from other sites',
                      onTap: () {
                        context.push('/settings/privacy/off-platform-activity');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Permissions
                    _SectionHeader(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Permissions',
                    ),
                    _SettingsItem(
                      icon: Icons.apps,
                      title: 'App Permissions',
                      subtitle: '6 permissions granted',
                      onTap: () {
                        context.push('/settings/privacy/permissions');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.location_on_outlined,
                      title: 'Location Services',
                      subtitle: 'While using the app',
                      onTap: () {
                        context.push('/settings/privacy/location-services');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Cookies & Tracking
                    _SectionHeader(
                      icon: Icons.cookie_outlined,
                      title: 'Cookies & Tracking',
                    ),
                    _SettingsItem(
                      icon: Icons.cookie,
                      title: 'Cookie Preferences',
                      subtitle: 'Manage cookies',
                      onTap: () {
                        context.push('/settings/privacy/cookies');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.cleaning_services_outlined,
                      title: 'Clear All Cookies',
                      subtitle: 'Reset tracking data',
                      onTap: () {
                        _showMessage('All cookies cleared');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Data Retention
                    _SectionHeader(
                      icon: Icons.schedule_outlined,
                      title: 'Data Retention',
                    ),
                    _SettingsItem(
                      icon: Icons.auto_delete_outlined,
                      title: 'Auto-Delete Activity',
                      subtitle: 'Keep for 18 months',
                      onTap: () {
                        context.push('/settings/privacy/auto-delete');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.archive_outlined,
                      title: 'Content Retention',
                      subtitle: 'Manage old content',
                      onTap: () {
                        context.push('/settings/privacy/content-retention');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Third-Party Apps
                    _SectionHeader(
                      icon: Icons.extension_outlined,
                      title: 'Third-Party Apps',
                    ),
                    _SettingsItem(
                      icon: Icons.apps_outlined,
                      title: 'Connected Apps',
                      subtitle: '3 apps connected',
                      onTap: () {
                        context.push('/settings/privacy/connected-apps');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.api_outlined,
                      title: 'API Access',
                      subtitle: 'Developer access',
                      onTap: () {
                        context.push('/settings/privacy/api-access');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Legal & Compliance
                    _SectionHeader(
                      icon: Icons.gavel_outlined,
                      title: 'Legal & Compliance',
                    ),
                    _SettingsItem(
                      icon: Icons.shield_outlined,
                      title: 'Your Rights (GDPR)',
                      subtitle: 'Data protection rights',
                      onTap: () {
                        context.push('/settings/privacy/your-rights');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.description_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'Read our privacy policy',
                      onTap: () {
                        context.push('/settings/privacy/privacy-policy');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.article_outlined,
                      title: 'Terms of Service',
                      subtitle: 'Terms and conditions',
                      onTap: () {
                        context.push('/settings/privacy/terms');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.request_page_outlined,
                      title: 'Submit Data Request',
                      subtitle: 'Exercise your rights',
                      onTap: () {
                        context.push('/settings/privacy/data-request');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Contact & Support
                    _SectionHeader(
                      icon: Icons.support_agent_outlined,
                      title: 'Contact & Support',
                    ),
                    _SettingsItem(
                      icon: Icons.email_outlined,
                      title: 'Contact DPO',
                      subtitle: 'Data Protection Officer',
                      onTap: () {
                        _showMessage('Contact DPO - Coming soon');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.help_outline,
                      title: 'Privacy Help',
                      subtitle: 'FAQ and support',
                      onTap: () {
                        _showMessage('Privacy help - Coming soon');
                      },
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.accentPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.bodyMedium(
              color: AppColors.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.glassBorder.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.accentPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: AppTextStyles.bodyMedium(
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.bodySmall(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w500,
                      ),
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
              trailing ??
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


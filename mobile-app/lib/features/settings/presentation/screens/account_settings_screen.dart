import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

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
                      'Account',
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Personal Information Section
                    _SectionHeader(title: 'Personal Information'),
                    _SettingsItem(
                      icon: Icons.email_outlined,
                      title: 'Email Address',
                      subtitle: 'john.doe@example.com',
                      onTap: () {
                        context.push('/settings/account/email');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.phone_outlined,
                      title: 'Phone Number',
                      subtitle: 'Not set',
                      onTap: () {
                        context.push('/settings/account/phone');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.person_outline,
                      title: 'Gender',
                      subtitle: 'Male',
                      onTap: () {
                        context.push('/settings/account/gender');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.cake_outlined,
                      title: 'Birthday',
                      subtitle: 'January 15, 2006',
                      onTap: () {
                        context.push('/settings/account/birthday');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.alternate_email,
                      title: 'Username',
                      subtitle: '@johndoe',
                      onTap: () {
                        context.push('/settings/account/username');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.vpn_key_outlined,
                      title: 'Password',
                      subtitle: 'Change your password',
                      onTap: () {
                        context.push('/settings/account/password');
                      },
                    ),
                    _SectionDivider(),
                    
                    // Account Management Section
                    _SectionHeader(title: 'Account Management'),
                    _SettingsItem(
                      icon: Icons.link,
                      title: 'Linked Accounts',
                      subtitle: 'Connect social accounts',
                      onTap: () {
                        context.push('/settings/account/linked-accounts');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.apps,
                      title: 'Connected Apps',
                      subtitle: 'Manage app permissions',
                      onTap: () {
                        context.push('/settings/account/connected-apps');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.history,
                      title: 'Login Activity',
                      subtitle: 'See where you\'re logged in',
                      onTap: () {
                        context.push('/settings/account/login-activity');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.download_outlined,
                      title: 'Download Your Data',
                      subtitle: 'Request a copy of your data',
                      onTap: () {
                        context.push('/settings/account/download-data');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.favorite_outline,
                      title: 'Account Memorialization',
                      subtitle: 'Legacy contact settings',
                      onTap: () {
                        context.push('/settings/account/memorialization');
                      },
                    ),
                    _SectionDivider(),
                    
                    // Earnings & Monetization Section
                    _SectionHeader(title: 'Earnings & Monetization'),
                    _SettingsItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Earnings Overview',
                      subtitle: '\$1,234.56 this month',
                      onTap: () {
                        context.push('/settings/account/earnings-overview');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.monetization_on_outlined,
                      title: 'Monetization Settings',
                      subtitle: 'Enable monetization features',
                      onTap: () {
                        context.push('/settings/account/monetization');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.credit_card_outlined,
                      title: 'Payout Methods',
                      subtitle: 'Bank account, PayPal',
                      onTap: () {
                        context.push('/settings/account/payout-methods');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.receipt_long_outlined,
                      title: 'Transaction History',
                      subtitle: 'View all transactions',
                      onTap: () {
                        context.push('/settings/account/transactions');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.trending_up,
                      title: 'Revenue Analytics',
                      subtitle: 'Track your earnings',
                      onTap: () {
                        context.push('/settings/account/revenue-analytics');
                      },
                    ),
                    _SectionDivider(),
                    
                    // Jobs & Projects Section
                    _SectionHeader(title: 'Jobs & Projects'),
                    _SettingsItem(
                      icon: Icons.work_outline,
                      title: 'Job Preferences',
                      subtitle: 'Set your job search preferences',
                      onTap: () {
                        context.push('/settings/account/job-preferences');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.assignment_outlined,
                      title: 'My Applications',
                      subtitle: '3 active applications',
                      onTap: () {
                        context.push('/settings/account/my-applications');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.folder_outlined,
                      title: 'Project Portfolio',
                      subtitle: 'Manage your projects',
                      onTap: () {
                        context.push('/settings/account/project-portfolio');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.business_outlined,
                      title: 'Company Profile',
                      subtitle: 'For recruiters and employers',
                      onTap: () {
                        context.push('/settings/account/company-profile');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Job Alerts',
                      subtitle: 'Get notified about new jobs',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {
                          // TODO: Toggle job alerts
                        },
                        activeColor: AppColors.accentPrimary,
                      ),
                    ),
                    _SectionDivider(),
                    
                    // Professional Accounts Section
                    _SectionHeader(title: 'Professional Accounts'),
                    _SettingsItem(
                      icon: Icons.business_center_outlined,
                      title: 'Switch to Professional Account',
                      subtitle: 'Get access to business tools',
                      onTap: () {
                        // TODO: Navigate to professional account
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.analytics_outlined,
                      title: 'Creator Studio',
                      subtitle: 'Analytics and insights',
                      onTap: () {
                        // TODO: Navigate to creator studio
                      },
                    ),
                    _SectionDivider(),
                    
                    // Account Actions Section
                    _SectionHeader(title: 'Account Actions'),
                    _SettingsItem(
                      icon: Icons.swap_horiz,
                      title: 'Switch Account Type',
                      subtitle: 'Personal • Business • Creator',
                      onTap: () {
                        // TODO: Navigate to account type
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.pause_circle_outline,
                      title: 'Temporarily Disable Account',
                      subtitle: 'Take a break from Histeeria',
                      onTap: () {
                        // TODO: Navigate to disable account
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.delete_outline,
                      title: 'Delete Account',
                      subtitle: 'Permanently delete your account',
                      isDestructive: true,
                      onTap: () {
                        _showDeleteAccountDialog(context);
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Account?',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
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
              Navigator.pop(context);
              // TODO: Handle account deletion
            },
            child: Text(
              'Delete',
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
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTextStyles.bodySmall(
          color: AppColors.textTertiary,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Section Divider - Gentle separator between sections
class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: 8,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.glassBorder.withOpacity(0.05),
            AppColors.glassBorder.withOpacity(0.1),
            AppColors.glassBorder.withOpacity(0.05),
          ],
        ),
      ),
    );
  }
}

// Settings Item
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
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
              Icon(
                icon,
                color: isDestructive
                    ? AppColors.accentQuaternary
                    : AppColors.textPrimary,
                size: 26,
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
                        color: isDestructive
                            ? AppColors.accentQuaternary
                            : AppColors.textPrimary,
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


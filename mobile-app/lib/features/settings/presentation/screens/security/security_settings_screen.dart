import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

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
                      'Security',
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
                    // Security Score Card
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
                                  Icons.security,
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
                                      'Security Score',
                                      style: AppTextStyles.bodyMedium(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '85',
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
                                      'Good security',
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
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                context.push('/settings/security/checkup');
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
                                'Run Security Checkup',
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
                    
                    // Password & Authentication
                    _SectionHeader(title: 'Password & Authentication'),
                    _SettingsItem(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      subtitle: 'Last changed: Nov 28, 2024',
                      onTap: () {
                        context.push('/settings/security/change-password');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.shield_outlined,
                      title: 'Password Strength',
                      subtitle: 'Strong',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Strong',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.success,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onTap: () {},
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Two-Factor Authentication
                    _SectionHeader(title: 'Two-Factor Authentication'),
                    _SettingsItem(
                      icon: Icons.verified_user_outlined,
                      title: 'Two-Factor Authentication',
                      subtitle: 'Add an extra layer of security',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {},
                        activeColor: AppColors.success,
                      ),
                      onTap: () {
                        context.push('/settings/security/two-factor');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.smartphone_outlined,
                      title: 'Authentication Method',
                      subtitle: 'Authenticator App',
                      onTap: () {
                        context.push('/settings/security/auth-method');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.backup_outlined,
                      title: 'Backup Codes',
                      subtitle: 'Generate recovery codes',
                      onTap: () {
                        context.push('/settings/security/backup-codes');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.devices_outlined,
                      title: 'Trusted Devices',
                      subtitle: '2 trusted devices',
                      onTap: () {
                        context.push('/settings/security/trusted-devices');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Active Sessions
                    _SectionHeader(title: 'Active Sessions'),
                    _SettingsItem(
                      icon: Icons.phone_android,
                      title: 'Active Sessions',
                      subtitle: '3 active devices',
                      onTap: () {
                        context.push('/settings/security/active-sessions');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.history,
                      title: 'Login Activity',
                      subtitle: 'View recent login history',
                      onTap: () {
                        context.push('/settings/security/login-activity');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Security Alerts
                    _SectionHeader(title: 'Security Alerts'),
                    _SettingsItem(
                      icon: Icons.notification_important_outlined,
                      title: 'Login Alerts',
                      subtitle: 'Notify on new device login',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {},
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {
                        context.push('/settings/security/login-alerts');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.security_outlined,
                      title: 'Security Notifications',
                      subtitle: 'Password & account changes',
                      onTap: () {
                        context.push('/settings/security/security-notifications');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Account Recovery
                    _SectionHeader(title: 'Account Recovery'),
                    _SettingsItem(
                      icon: Icons.email_outlined,
                      title: 'Recovery Email',
                      subtitle: 'john***@gmail.com',
                      onTap: () {
                        context.push('/settings/security/recovery-email');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.phone_outlined,
                      title: 'Recovery Phone',
                      subtitle: '+1 (***) ***-1234',
                      onTap: () {
                        context.push('/settings/security/recovery-phone');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.download_outlined,
                      title: 'Recovery Codes',
                      subtitle: 'Download backup codes',
                      onTap: () {
                        context.push('/settings/security/recovery-codes');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Biometric & App Security
                    _SectionHeader(title: 'Biometric & App Security'),
                    _SettingsItem(
                      icon: Icons.fingerprint,
                      title: 'Biometric Authentication',
                      subtitle: 'Face ID, Touch ID',
                      onTap: () {
                        context.push('/settings/security/biometric');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.lock_clock_outlined,
                      title: 'App Lock',
                      subtitle: 'Require authentication to open',
                      trailing: Switch(
                        value: false,
                        onChanged: (value) {},
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {
                        context.push('/settings/security/app-lock');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.screenshot_outlined,
                      title: 'Screenshot Protection',
                      subtitle: 'Prevent screenshots',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {},
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Advanced Security
                    _SectionHeader(title: 'Advanced'),
                    _SettingsItem(
                      icon: Icons.apps_outlined,
                      title: 'Connected Apps',
                      subtitle: 'Manage third-party access',
                      onTap: () {
                        context.push('/settings/security/connected-apps');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.description_outlined,
                      title: 'Security Logs',
                      subtitle: 'View security events',
                      onTap: () {
                        context.push('/settings/security/security-logs');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.report_outlined,
                      title: 'Report Security Issue',
                      subtitle: 'Contact security team',
                      onTap: () {
                        context.push('/settings/security/report-issue');
                      },
                    ),
                    
                    const SizedBox(height: 24),
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
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.bodySmall(
          color: AppColors.textSecondary,
          weight: FontWeight.w600,
        ),
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


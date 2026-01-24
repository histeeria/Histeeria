import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class LoginActivityScreen extends StatelessWidget {
  const LoginActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> _loginHistory = [
      {
        'device': 'iPhone 13 Pro',
        'location': 'San Francisco, CA',
        'ip': '192.168.1.1',
        'date': 'Dec 3, 2024 at 10:30 AM',
        'success': true,
        'method': 'Password',
      },
      {
        'device': 'Chrome on Windows',
        'location': 'New York, NY',
        'ip': '192.168.1.25',
        'date': 'Dec 2, 2024 at 2:15 PM',
        'success': true,
        'method': 'Password + 2FA',
      },
      {
        'device': 'Unknown Device',
        'location': 'Moscow, Russia',
        'ip': '45.142.212.61',
        'date': 'Dec 1, 2024 at 11:45 PM',
        'success': false,
        'method': 'Password',
      },
      {
        'device': 'Safari on MacBook Pro',
        'location': 'Los Angeles, CA',
        'ip': '192.168.1.50',
        'date': 'Nov 30, 2024 at 9:00 AM',
        'success': true,
        'method': 'Password',
      },
      {
        'device': 'Chrome on Android',
        'location': 'Chicago, IL',
        'ip': '192.168.1.75',
        'date': 'Nov 29, 2024 at 4:30 PM',
        'success': true,
        'method': 'Password + 2FA',
      },
    ];

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
                      'Login Activity',
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
                              'Review your recent login attempts. If you see anything suspicious, change your password immediately.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Login History
                    ...List.generate(_loginHistory.length, (index) {
                      final login = _loginHistory[index];
                      final isSuccess = login['success'] as bool;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSuccess
                              ? AppColors.backgroundSecondary.withOpacity(0.3)
                              : AppColors.accentQuaternary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSuccess
                                ? AppColors.glassBorder.withOpacity(0.2)
                                : AppColors.accentQuaternary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSuccess
                                        ? AppColors.success.withOpacity(0.15)
                                        : AppColors.accentQuaternary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isSuccess ? Icons.check_circle : Icons.error,
                                    color: isSuccess ? AppColors.success : AppColors.accentQuaternary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSuccess ? 'Successful Login' : 'Failed Login Attempt',
                                        style: AppTextStyles.bodyMedium(
                                          weight: FontWeight.w600,
                                          color: isSuccess ? AppColors.textPrimary : AppColors.accentQuaternary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        login['date'],
                                        style: AppTextStyles.bodySmall(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _DetailRow(
                              icon: Icons.phone_android,
                              text: login['device'],
                            ),
                            _DetailRow(
                              icon: Icons.location_on_outlined,
                              text: login['location'],
                            ),
                            _DetailRow(
                              icon: Icons.wifi,
                              text: 'IP: ${login['ip']}',
                            ),
                            _DetailRow(
                              icon: Icons.security_outlined,
                              text: 'Method: ${login['method']}',
                            ),
                          ],
                        ),
                      );
                    }),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


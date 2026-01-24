import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  final List<Map<String, dynamic>> _sessions = [
    {
      'device': 'iPhone 13 Pro',
      'location': 'San Francisco, CA',
      'ip': '192.168.1.1',
      'browser': 'Histeeria App',
      'lastActive': 'Active now',
      'current': true,
    },
    {
      'device': 'Chrome on Windows',
      'location': 'New York, NY',
      'ip': '192.168.1.25',
      'browser': 'Chrome 120',
      'lastActive': '2 hours ago',
      'current': false,
    },
    {
      'device': 'Safari on MacBook Pro',
      'location': 'Los Angeles, CA',
      'ip': '192.168.1.50',
      'browser': 'Safari 17',
      'lastActive': '1 day ago',
      'current': false,
    },
  ];

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

  void _logoutSession(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Log Out Session',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out this device?',
          style: AppTextStyles.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _sessions.removeAt(index);
              });
              _showMessage('Session logged out');
            },
            child: Text(
              'Log Out',
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

  void _logoutAllOthers() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Log Out All Other Sessions',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'This will log you out of all other devices. You\'ll need to sign in again on those devices.',
          style: AppTextStyles.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _sessions.removeWhere((session) => !session['current']);
              });
              _showMessage('All other sessions logged out');
            },
            child: Text(
              'Log Out All',
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
                      'Active Sessions',
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
                              'These are the devices currently logged into your account. If you see something unfamiliar, log it out.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Sessions List
                    ...List.generate(_sessions.length, (index) {
                      final session = _sessions[index];
                      final isCurrent = session['current'] as bool;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.accentPrimary.withOpacity(0.1)
                              : AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.accentPrimary.withOpacity(0.3)
                                : AppColors.glassBorder.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? AppColors.accentPrimary.withOpacity(0.2)
                                        : AppColors.textTertiary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    session['device'].toString().contains('iPhone') ||
                                            session['device'].toString().contains('App')
                                        ? Icons.phone_android
                                        : Icons.computer,
                                    color: isCurrent
                                        ? AppColors.accentPrimary
                                        : AppColors.textSecondary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            session['device'],
                                            style: AppTextStyles.bodyMedium(
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                          if (isCurrent) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Current',
                                                style: AppTextStyles.bodySmall(
                                                  color: AppColors.success,
                                                  weight: FontWeight.w600,
                                                ).copyWith(fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        session['browser'],
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
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  session['location'],
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.devices_outlined,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'IP: ${session['ip']}',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  session['lastActive'],
                                  style: AppTextStyles.bodySmall(
                                    color: isCurrent
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    weight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            if (!isCurrent) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => _logoutSession(index),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.accentQuaternary,
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: Text(
                                    'Log Out',
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.accentQuaternary,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 8),
                    
                    // Log Out All Others Button
                    if (_sessions.where((s) => !s['current']).isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _logoutAllOthers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentQuaternary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          child: Text(
                            'Log Out All Other Sessions',
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


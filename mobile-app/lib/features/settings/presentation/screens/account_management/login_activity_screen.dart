import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class LoginActivityScreen extends StatefulWidget {
  const LoginActivityScreen({super.key});

  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
  final List<Map<String, dynamic>> _loginSessions = [
    {
      'device': 'Windows PC',
      'location': 'San Francisco, CA',
      'ip': '192.168.1.100',
      'browser': 'Chrome 120',
      'lastActive': 'Active now',
      'isCurrent': true,
      'icon': Icons.computer,
    },
    {
      'device': 'iPhone 14 Pro',
      'location': 'San Francisco, CA',
      'ip': '192.168.1.101',
      'browser': 'Safari',
      'lastActive': '2 hours ago',
      'isCurrent': false,
      'icon': Icons.phone_iphone,
    },
    {
      'device': 'iPad Pro',
      'location': 'Los Angeles, CA',
      'ip': '192.168.2.50',
      'browser': 'Safari',
      'lastActive': '1 day ago',
      'isCurrent': false,
      'icon': Icons.tablet_mac,
    },
    {
      'device': 'Android Phone',
      'location': 'New York, NY',
      'ip': '192.168.3.75',
      'browser': 'Chrome',
      'lastActive': '3 days ago',
      'isCurrent': false,
      'icon': Icons.phone_android,
    },
  ];

  Future<void> _logoutSession(int index) async {
    final session = _loginSessions[index];
    
    if (session['isCurrent']) {
      _showMessage('Cannot logout from current session');
      return;
    }

    final confirm = await _showLogoutDialog(session['device']);
    if (confirm != true) return;

    setState(() {
      _loginSessions.removeAt(index);
    });

    _showMessage('Logged out from ${session['device']}');
  }

  Future<void> _logoutAllOthers() async {
    final confirm = await _showLogoutAllDialog();
    if (confirm != true) return;

    setState(() {
      _loginSessions.removeWhere((session) => !session['isCurrent']);
    });

    _showMessage('Logged out from all other devices');
  }

  Future<bool?> _showLogoutDialog(String device) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Logout from $device?',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'This device will be logged out and will need to sign in again.',
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
              'Logout',
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

  Future<bool?> _showLogoutAllDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Logout from all devices?',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'All other devices will be logged out. Your current session will remain active.',
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
              'Logout All',
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

  @override
  Widget build(BuildContext context) {
    final otherSessions = _loginSessions.where((s) => !s['isCurrent']).length;

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
                            Icons.security,
                            color: AppColors.accentPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Review devices and locations where your account is currently logged in. Logout from any suspicious activity.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (otherSessions > 0) ...[
                      const SizedBox(height: 20),
                      // Logout All Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _logoutAllOthers,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: AppColors.accentQuaternary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Logout from All Other Devices',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.accentQuaternary,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Login Sessions
                    ..._loginSessions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final session = entry.value;
                      final isCurrent = session['isCurrent'] as bool;
                      
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
                                ? AppColors.accentPrimary.withOpacity(0.5)
                                : AppColors.glassBorder.withOpacity(0.2),
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? AppColors.accentPrimary.withOpacity(0.2)
                                        : AppColors.backgroundPrimary.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    session['icon'],
                                    color: isCurrent
                                        ? AppColors.accentPrimary
                                        : AppColors.textSecondary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              session['device'],
                                              style: AppTextStyles.bodyLarge(
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (isCurrent) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Current',
                                                style: AppTextStyles.bodySmall(
                                                  color: AppColors.success,
                                                  weight: FontWeight.w600,
                                                ),
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
                            const SizedBox(height: 16),
                            
                            // Location
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  session['location'],
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // IP Address
                            Row(
                              children: [
                                Icon(
                                  Icons.router,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'IP: ${session['ip']}',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Last Active
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 8),
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
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => _logoutSession(index),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    side: BorderSide(
                                      color: AppColors.accentQuaternary,
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Logout',
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


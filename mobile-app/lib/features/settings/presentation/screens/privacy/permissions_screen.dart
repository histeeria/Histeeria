import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final List<Map<String, dynamic>> _permissions = [
    {
      'name': 'Camera',
      'icon': Icons.camera_alt_outlined,
      'status': 'Allowed',
      'description': 'Take photos and record videos',
      'lastUsed': '2 hours ago',
      'allowed': true,
    },
    {
      'name': 'Microphone',
      'icon': Icons.mic_outlined,
      'status': 'Allowed',
      'description': 'Record audio and voice messages',
      'lastUsed': '5 hours ago',
      'allowed': true,
    },
    {
      'name': 'Location',
      'icon': Icons.location_on_outlined,
      'status': 'While Using',
      'description': 'Access your location',
      'lastUsed': '1 day ago',
      'allowed': true,
    },
    {
      'name': 'Photos & Media',
      'icon': Icons.photo_library_outlined,
      'status': 'Allowed',
      'description': 'Read and write media files',
      'lastUsed': '3 hours ago',
      'allowed': true,
    },
    {
      'name': 'Contacts',
      'icon': Icons.contacts_outlined,
      'status': 'Allowed',
      'description': 'Access your contacts',
      'lastUsed': '2 days ago',
      'allowed': true,
    },
    {
      'name': 'Notifications',
      'icon': Icons.notifications_outlined,
      'status': 'Allowed',
      'description': 'Send notifications',
      'lastUsed': 'Active now',
      'allowed': true,
    },
    {
      'name': 'Background Refresh',
      'icon': Icons.refresh,
      'status': 'Denied',
      'description': 'Update content in background',
      'lastUsed': 'Never',
      'allowed': false,
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

  Color _getStatusColor(String status) {
    if (status == 'Allowed' || status == 'While Using') {
      return AppColors.success;
    } else {
      return AppColors.accentQuaternary;
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
                      'App Permissions',
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
                              'Manage app permissions. Some features may not work if permissions are denied.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Permissions List
                    ..._permissions.map((permission) {
                      final status = permission['status'] as String;
                      final allowed = permission['allowed'] as bool;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.3),
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
                                    color: allowed
                                        ? AppColors.success.withOpacity(0.15)
                                        : AppColors.accentQuaternary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    permission['icon'],
                                    color: allowed ? AppColors.success : AppColors.accentQuaternary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        permission['name'],
                                        style: AppTextStyles.bodyLarge(
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        permission['description'],
                                        style: AppTextStyles.bodySmall(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: AppTextStyles.bodySmall(
                                      color: _getStatusColor(status),
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Last used: ${permission['lastUsed']}',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  _showMessage('Open system settings to change');
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.accentPrimary,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: Text(
                                  'Change Permission',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.accentPrimary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
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


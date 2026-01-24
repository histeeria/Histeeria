import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class StorageUsageScreen extends StatefulWidget {
  const StorageUsageScreen({super.key});

  @override
  State<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends State<StorageUsageScreen> {
  final List<Map<String, dynamic>> _storageByChat = [
    {
      'name': 'Sarah Johnson',
      'size': '486 MB',
      'messages': '2,450',
      'media': '312',
    },
    {
      'name': 'Development Team',
      'size': '342 MB',
      'messages': '8,920',
      'media': '1,245',
    },
    {
      'name': 'Alex Martinez',
      'size': '198 MB',
      'messages': '1,680',
      'media': '156',
    },
    {
      'name': 'Family Group',
      'size': '876 MB',
      'messages': '12,450',
      'media': '2,890',
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

  void _clearChatStorage(String chatName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Clear Chat Storage',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'This will delete all media from $chatName but keep your messages.',
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
              _showMessage('Storage cleared for $chatName');
            },
            child: Text(
              'Clear',
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
                      'Storage Usage',
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
                    // Total Storage Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentPrimary.withOpacity(0.2),
                            AppColors.accentSecondary.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.storage,
                            color: AppColors.accentPrimary,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '2.4 GB',
                            style: AppTextStyles.headlineLarge(
                              weight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Storage Used',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Storage Breakdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StorageStat(
                                icon: Icons.photo,
                                label: 'Photos',
                                value: '1.2 GB',
                                color: AppColors.accentPrimary,
                              ),
                              _StorageStat(
                                icon: Icons.videocam,
                                label: 'Videos',
                                value: '890 MB',
                                color: AppColors.accentSecondary,
                              ),
                              _StorageStat(
                                icon: Icons.description,
                                label: 'Files',
                                value: '310 MB',
                                color: AppColors.accentTertiary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Storage by Chat
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Storage by Chat',
                          style: AppTextStyles.bodyMedium(
                            weight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _showMessage('Clear all cache - Coming soon');
                          },
                          child: Text(
                            'Clear All',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.accentQuaternary,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    ..._storageByChat.map((chat) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accentPrimary,
                                    AppColors.accentSecondary,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  chat['name'].toString().substring(0, 1),
                                  style: AppTextStyles.bodyLarge(
                                    color: Colors.white,
                                    weight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chat['name'],
                                    style: AppTextStyles.bodyMedium(
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${chat['messages']} messages • ${chat['media']} media',
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  chat['size'],
                                  style: AppTextStyles.bodyMedium(
                                    weight: FontWeight.w600,
                                    color: AppColors.accentPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _clearChatStorage(chat['name']),
                                  child: Text(
                                    'Clear',
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.accentQuaternary,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
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

class _StorageStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StorageStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodySmall(
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String _selectedFilter = 'All';
  
  final List<Map<String, dynamic>> _activities = [
    {
      'action': 'Posted a photo',
      'category': 'Posts',
      'time': '2 hours ago',
      'icon': Icons.photo,
      'color': AppColors.accentPrimary,
    },
    {
      'action': 'Updated profile picture',
      'category': 'Profile',
      'time': '5 hours ago',
      'icon': Icons.account_circle,
      'color': AppColors.accentSecondary,
    },
    {
      'action': 'Commented on a post',
      'category': 'Comments',
      'time': '1 day ago',
      'icon': Icons.comment,
      'color': AppColors.accentTertiary,
    },
    {
      'action': 'Sent a message to Sarah',
      'category': 'Messages',
      'time': '1 day ago',
      'icon': Icons.message,
      'color': AppColors.accentPrimary,
    },
    {
      'action': 'Followed Alex Martinez',
      'category': 'Social',
      'time': '2 days ago',
      'icon': Icons.person_add,
      'color': AppColors.success,
    },
    {
      'action': 'Logged in from new device',
      'category': 'Security',
      'time': '3 days ago',
      'icon': Icons.security,
      'color': AppColors.textTertiary,
    },
    {
      'action': 'Joined Tech Community',
      'category': 'Communities',
      'time': '5 days ago',
      'icon': Icons.groups,
      'color': AppColors.accentSecondary,
    },
    {
      'action': 'Liked a post',
      'category': 'Interactions',
      'time': '1 week ago',
      'icon': Icons.favorite,
      'color': AppColors.accentQuaternary,
    },
  ];

  List<Map<String, dynamic>> get _filteredActivities {
    if (_selectedFilter == 'All') return _activities;
    return _activities.where((activity) => activity['category'] == _selectedFilter).toList();
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
                      'Activity Log',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        _showMessage('Clear all activity - Coming soon');
                      },
                      child: Icon(
                        Icons.delete_sweep_outlined,
                        color: AppColors.accentQuaternary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Filter Tabs
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    'All',
                    'Posts',
                    'Comments',
                    'Messages',
                    'Social',
                    'Security',
                    'Communities',
                  ].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentPrimary
                              : AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style: AppTextStyles.bodySmall(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Activities List
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  itemCount: _filteredActivities.length,
                  itemBuilder: (context, index) {
                    final activity = _filteredActivities[index];
                    
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (activity['color'] as Color).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              activity['icon'],
                              color: activity['color'],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity['action'],
                                  style: AppTextStyles.bodyMedium(
                                    weight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (activity['color'] as Color).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        activity['category'],
                                        style: AppTextStyles.bodySmall(
                                          color: activity['color'],
                                          weight: FontWeight.w600,
                                        ).copyWith(fontSize: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      activity['time'],
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.more_vert,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () {
                              _showMessage('Activity options - Coming soon');
                            },
                          ),
                        ],
                      ),
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


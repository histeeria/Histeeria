import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';

class YourActivityScreen extends StatelessWidget {
  const YourActivityScreen({super.key});

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
                      'Your Activity',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Activity Options List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Content Section
                    _SectionHeader(title: 'Content'),
                    _ActivityItem(
                      icon: Icons.favorite_outline,
                      title: 'Liked Posts',
                      subtitle: 'Posts you\'ve liked',
                      onTap: () {
                        // TODO: Navigate to liked posts
                      },
                    ),
                    _ActivityItem(
                      icon: Icons.comment_outlined,
                      title: 'Your Comments',
                      subtitle: 'Comments you\'ve made',
                      onTap: () {
                        // TODO: Navigate to comments
                      },
                    ),
                    _ActivityItem(
                      icon: Icons.share_outlined,
                      title: 'Shares',
                      subtitle: 'Posts you\'ve shared',
                      onTap: () {
                        // TODO: Navigate to shares
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Storage Section
                    _SectionHeader(title: 'Storage'),
                    _ActivityItem(
                      icon: Icons.archive_outlined,
                      title: 'Archived',
                      subtitle: 'Posts you\'ve archived',
                      onTap: () {
                        // TODO: Navigate to archived
                      },
                    ),
                    _ActivityItem(
                      icon: Icons.delete_outline,
                      title: 'Recently Deleted',
                      subtitle: 'Content you\'ve deleted recently',
                      onTap: () {
                        // TODO: Navigate to recently deleted
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // History Section
                    _SectionHeader(title: 'History'),
                    _ActivityItem(
                      icon: Icons.search_outlined,
                      title: 'Recent Searches',
                      subtitle: 'Your search history',
                      onTap: () {
                        // TODO: Navigate to search history
                      },
                    ),
                    _ActivityItem(
                      icon: Icons.play_circle_outline,
                      title: 'Watch History',
                      subtitle: 'Videos and stories you\'ve watched',
                      onTap: () {
                        // TODO: Navigate to watch history
                      },
                    ),
                    _ActivityItem(
                      icon: Icons.history_outlined,
                      title: 'Account History',
                      subtitle: 'Changes to your account',
                      onTap: () {
                        // TODO: Navigate to account history
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Insights Section
                    _SectionHeader(title: 'Insights'),
                    _ActivityItem(
                      icon: Icons.timer_outlined,
                      title: 'Time Spent',
                      subtitle: 'See how much time you spend on Histeeria',
                      onTap: () {
                        // TODO: Navigate to time spent
                      },
                    ),
                    _ActivityItem(
                      icon: Icons.bar_chart_outlined,
                      title: 'Activity Status',
                      subtitle: 'Manage when others see you\'re active',
                      onTap: () {
                        // TODO: Navigate to activity status
                      },
                    ),
                    const SizedBox(height: 32),
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

// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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

// Activity Item Widget - matches Settings style
class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActivityItem({
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.accentPrimary,
                  size: 22,
                ),
              ),
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

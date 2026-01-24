import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/post.dart';
import '../../data/services/posts_service.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;

class PostPreviewDrawer extends StatefulWidget {
  final Post post;
  final bool isOwnPost;

  const PostPreviewDrawer({
    super.key,
    required this.post,
    required this.isOwnPost,
  });

  @override
  State<PostPreviewDrawer> createState() => _PostPreviewDrawerState();
}

class _PostPreviewDrawerState extends State<PostPreviewDrawer> {
  Map<String, int>? _insights;
  bool _isLoadingInsights = false;

  @override
  void initState() {
    super.initState();
    if (widget.isOwnPost) {
      _loadInsights();
    }
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoadingInsights = true;
    });

    try {
      final response = await PostsService().getPostInsights(widget.post.id);
      if (response.success && response.data != null) {
        setState(() {
          _insights = {
            'reach': response.data!['reach'] as int? ?? 0,
            'impressions': response.data!['impressions'] as int? ?? widget.post.viewsCount,
            'profile_visits': response.data!['profile_visits'] as int? ?? 0,
          };
          _isLoadingInsights = false;
        });
      } else {
        setState(() {
          _isLoadingInsights = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingInsights = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Post',
                      style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(bottom: safeAreaBottom + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Post Content
                      _buildPostContent(),
                      const SizedBox(height: 24),
                      // Insights Section (only for own posts)
                      if (widget.isOwnPost) _buildInsightsSection(),
                      // Engagement Metrics
                      _buildEngagementMetrics(),
                      SizedBox(height: safeAreaBottom > 0 ? 0 : 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post Media or Text Background
        if (widget.post.hasMedia && widget.post.firstMediaUrl != null)
          CachedNetworkImage(
            imageUrl: widget.post.firstMediaUrl!,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentPrimary.withOpacity(0.3),
                    AppColors.accentSecondary.withOpacity(0.3),
                  ],
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentPrimary.withOpacity(0.3),
                    AppColors.accentSecondary.withOpacity(0.3),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 48),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accentPrimary.withOpacity(0.6),
                  AppColors.accentSecondary.withOpacity(0.6),
                  AppColors.accentTertiary.withOpacity(0.6),
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.post.content,
                  style: AppTextStyles.headlineMedium(
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        // Post Info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post Type Badge
              if (widget.post.postType != null && widget.post.postType != 'post')
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPostTypeColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getPostTypeColor().withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPostTypeIcon(),
                        size: 16,
                        color: _getPostTypeColor(),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getPostTypeLabel(),
                        style: AppTextStyles.bodySmall(
                          color: _getPostTypeColor(),
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // Post Content (if has media)
              if (widget.post.hasMedia && widget.post.content.isNotEmpty)
                Text(
                  widget.post.content,
                  style: AppTextStyles.bodyLarge(),
                ),
              const SizedBox(height: 12),
              // Post Date
              Text(
                app_date_utils.DateUtils.timeAgo(widget.post.createdAt),
                style: AppTextStyles.bodySmall(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.glassBorder.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_outlined,
                color: AppColors.accentPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Insights',
                style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Overview Metrics
          if (_isLoadingInsights)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _buildInsightRow(
              icon: Icons.remove_red_eye_outlined,
              label: 'Reach',
              value: _formatCount(_insights?['reach'] ?? widget.post.viewsCount),
              description: 'Accounts that saw your post',
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              icon: Icons.visibility_outlined,
              label: 'Impressions',
              value: _formatCount(_insights?['impressions'] ?? widget.post.viewsCount),
              description: 'Total times your post was viewed',
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              icon: Icons.person_outline,
              label: 'Profile Visits',
              value: _formatCount(_insights?['profile_visits'] ?? 0),
              description: 'Visits to your profile from this post',
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              icon: Icons.favorite_outline,
              label: 'Engagement',
              value: _formatCount(widget.post.likesCount + widget.post.commentsCount + widget.post.sharesCount),
              description: 'Total likes, comments, and shares',
            ),
          ],
          const SizedBox(height: 16),
          // Engagement Rate
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: AppColors.accentPrimary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Engagement Rate',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_calculateEngagementRate()}%',
                        style: AppTextStyles.headlineSmall(
                          color: AppColors.accentPrimary,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement',
            style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.favorite_outline,
                  label: 'Likes',
                  value: _formatCount(widget.post.likesCount),
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.comment_outlined,
                  label: 'Comments',
                  value: _formatCount(widget.post.commentsCount),
                  color: AppColors.accentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.share_outlined,
                  label: 'Shares',
                  value: _formatCount(widget.post.sharesCount),
                  color: AppColors.accentSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.bookmark_outline,
                  label: 'Saves',
                  value: _formatCount(widget.post.savesCount),
                  color: AppColors.accentTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.remove_red_eye_outlined,
                  label: 'Views',
                  value: _formatCount(widget.post.viewsCount),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required String label,
    required String value,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.accentPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMedium(weight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTextStyles.bodySmall(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: AppTextStyles.headlineSmall(
            color: AppColors.accentPrimary,
            weight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.glassBorder.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headlineSmall(
              color: color,
              weight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  double _calculateEngagementRate() {
    // Use impressions (total views) for engagement rate calculation
    // Engagement rate = (Likes + Comments + Shares + Saves) / Impressions * 100
    final impressions = _insights?['impressions'] ?? widget.post.viewsCount;
    if (impressions == 0) return 0.0;
    
    final engagement = widget.post.likesCount + 
                      widget.post.commentsCount + 
                      widget.post.sharesCount + 
                      widget.post.savesCount;
    
    final rate = (engagement / impressions) * 100;
    return rate.clamp(0.0, 100.0);
  }

  IconData _getPostTypeIcon() {
    switch (widget.post.postType) {
      case 'poll':
        return Icons.bar_chart_rounded;
      case 'article':
        return Icons.article_outlined;
      case 'reel':
        return Icons.video_library_outlined;
      default:
        return Icons.image_outlined;
    }
  }

  Color _getPostTypeColor() {
    switch (widget.post.postType) {
      case 'poll':
        return const Color(0xFF11998E);
      case 'article':
        return const Color(0xFFF093FB);
      case 'reel':
        return AppColors.accentPrimary;
      default:
        return AppColors.accentSecondary;
    }
  }

  String _getPostTypeLabel() {
    switch (widget.post.postType) {
      case 'poll':
        return 'Poll';
      case 'article':
        return 'Article';
      case 'reel':
        return 'Reel';
      default:
        return 'Post';
    }
  }
}

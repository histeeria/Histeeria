import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class RevenueAnalyticsScreen extends StatefulWidget {
  const RevenueAnalyticsScreen({super.key});

  @override
  State<RevenueAnalyticsScreen> createState() => _RevenueAnalyticsScreenState();
}

class _RevenueAnalyticsScreenState extends State<RevenueAnalyticsScreen> {
  String _selectedPeriod = '30 Days';
  
  final Map<String, Map<String, dynamic>> _periodData = {
    '7 Days': {
      'total': '\$345.67',
      'change': '+8.2%',
      'views': '12.5K',
      'engagement': '3.2K',
    },
    '30 Days': {
      'total': '\$1,234.56',
      'change': '+12.5%',
      'views': '45.8K',
      'engagement': '11.2K',
    },
    '90 Days': {
      'total': '\$3,567.89',
      'change': '+15.3%',
      'views': '128.4K',
      'engagement': '32.5K',
    },
    'All Time': {
      'total': '\$8,456.78',
      'change': '+18.7%',
      'views': '256.7K',
      'engagement': '68.9K',
    },
  };

  final List<Map<String, dynamic>> _topPerformingContent = [
    {
      'title': 'Web Development Project',
      'type': 'Job',
      'views': '8.5K',
      'earnings': '\$485.00',
      'date': 'Nov 20, 2024',
      'icon': Icons.work,
    },
    {
      'title': 'Mobile App Collaboration',
      'type': 'Project',
      'views': '6.2K',
      'earnings': '\$356.80',
      'date': 'Nov 18, 2024',
      'icon': Icons.folder,
    },
    {
      'title': 'Digital Course - Flutter Mastery',
      'type': 'Product',
      'views': '5.1K',
      'earnings': '\$245.16',
      'date': 'Nov 15, 2024',
      'icon': Icons.shopping_bag,
    },
    {
      'title': 'Tutorial Video Series',
      'type': 'Content',
      'views': '12.3K',
      'earnings': '\$112.40',
      'date': 'Nov 12, 2024',
      'icon': Icons.video_library,
    },
  ];

  final Map<String, dynamic> _blockchainStats = {
    'totalTransactions': 156,
    'blockchainNetworks': ['Ethereum', 'Polygon', 'BSC'],
    'gasFeeSaved': '\$45.20',
    'smartContracts': 3,
  };

  @override
  Widget build(BuildContext context) {
    final currentData = _periodData[_selectedPeriod]!;

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
                      'Revenue Analytics',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Period Selector
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _periodData.keys.map((period) {
                    final isSelected = _selectedPeriod == period;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPeriod = period;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentPrimary
                              : AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(
                            period,
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
              // Content
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Key Metrics
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.trending_up,
                            title: 'Growth',
                            value: currentData['change'],
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.visibility_outlined,
                            title: 'Views',
                            value: currentData['views'],
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.favorite_outline,
                            title: 'Engagement',
                            value: currentData['engagement'],
                            color: AppColors.accentSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.attach_money,
                            title: 'Revenue',
                            value: currentData['total'],
                            color: AppColors.accentTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Chart Placeholder
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.glassBorder.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Revenue Chart',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Visual analytics coming soon',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Blockchain Analytics
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366F1).withOpacity(0.2),
                            const Color(0xFF8B5CF6).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.currency_bitcoin,
                                color: const Color(0xFF6366F1),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Blockchain Analytics',
                                style: AppTextStyles.bodyLarge(
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _BlockchainStat(
                                  label: 'Transactions',
                                  value: '${_blockchainStats['totalTransactions']}',
                                ),
                              ),
                              Expanded(
                                child: _BlockchainStat(
                                  label: 'Smart Contracts',
                                  value: '${_blockchainStats['smartContracts']}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _BlockchainStat(
                                  label: 'Networks',
                                  value: '${(_blockchainStats['blockchainNetworks'] as List).length}',
                                ),
                              ),
                              Expanded(
                                child: _BlockchainStat(
                                  label: 'Gas Saved',
                                  value: _blockchainStats['gasFeeSaved'],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Top Performing Content
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Top Revenue Sources',
                          style: AppTextStyles.bodyLarge(
                            weight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: View all
                          },
                          child: Text(
                            'View All',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.accentPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    ..._topPerformingContent.map((content) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentPrimary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    content['icon'],
                                    color: AppColors.accentPrimary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    content['title'],
                                    style: AppTextStyles.bodyMedium(
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentPrimary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    content['type'],
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.accentPrimary,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.visibility,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  content['views'],
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.attach_money,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  content['earnings'],
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.success,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  content['date'],
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textTertiary,
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

class _MetricCard extends StatelessWidget{
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.bodySmall(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyLarge(
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockchainStat extends StatelessWidget {
  final String label;
  final String value;

  const _BlockchainStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyLarge(
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


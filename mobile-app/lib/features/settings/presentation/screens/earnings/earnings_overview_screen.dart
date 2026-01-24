import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class EarningsOverviewScreen extends StatelessWidget {
  const EarningsOverviewScreen({super.key});

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
                      'Earnings Overview',
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
                    // Total Earnings Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentPrimary,
                            AppColors.accentSecondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPrimary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 28,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+12.5%',
                                      style: AppTextStyles.bodySmall(
                                        color: Colors.white,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Total Earnings',
                            style: AppTextStyles.bodyMedium(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$1,234.56',
                            style: AppTextStyles.headlineLarge(
                              color: Colors.white,
                              weight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This month',
                            style: AppTextStyles.bodySmall(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Quick Stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_month,
                            title: 'Last Month',
                            value: '\$1,089.32',
                            color: AppColors.accentSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_today,
                            title: 'All Time',
                            value: '\$8,456.78',
                            color: AppColors.accentTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Earnings Breakdown
                    Text(
                      'Earnings Breakdown',
                      style: AppTextStyles.bodyLarge(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _EarningsSourceItem(
                      icon: Icons.work_outline,
                      title: 'Jobs Completed',
                      amount: '\$485.20',
                      percentage: 39,
                      color: AppColors.accentPrimary,
                    ),
                    _EarningsSourceItem(
                      icon: Icons.folder_outlined,
                      title: 'Projects',
                      amount: '\$356.80',
                      percentage: 29,
                      color: AppColors.accentSecondary,
                    ),
                    _EarningsSourceItem(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Product Sales',
                      amount: '\$245.16',
                      percentage: 20,
                      color: AppColors.accentTertiary,
                    ),
                    _EarningsSourceItem(
                      icon: Icons.monetization_on_outlined,
                      title: 'Content Monetization',
                      amount: '\$112.40',
                      percentage: 9,
                      color: AppColors.success,
                    ),
                    _EarningsSourceItem(
                      icon: Icons.card_giftcard_outlined,
                      title: 'Tips & Donations',
                      amount: '\$35.00',
                      percentage: 3,
                      color: const Color(0xFFFF6B9D),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Blockchain Integration
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
                      child: Row(
                        children: [
                          Icon(
                            Icons.currency_bitcoin,
                            color: const Color(0xFF6366F1),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Blockchain Verified',
                                  style: AppTextStyles.bodyMedium(
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All transactions secured on blockchain',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.verified,
                            color: const Color(0xFF6366F1),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Pending Payments
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.glassBorder.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: AppColors.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pending Payout',
                                  style: AppTextStyles.bodyMedium(
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Next payout on Dec 15, 2024',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$1,234.56',
                            style: AppTextStyles.bodyLarge(
                              weight: FontWeight.w600,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Blockchain Integration
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
                      child: Row(
                        children: [
                          Icon(
                            Icons.currency_bitcoin,
                            color: const Color(0xFF6366F1),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Blockchain Verified',
                                  style: AppTextStyles.bodyMedium(
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All transactions secured on blockchain',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.verified,
                            color: const Color(0xFF6366F1),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Active Revenue Streams
                    Container(
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
                              Icon(
                                Icons.trending_up,
                                color: AppColors.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Active Revenue Streams',
                                style: AppTextStyles.bodyMedium(
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _StreamBadge(text: '3 Active Jobs'),
                          const SizedBox(height: 6),
                          _StreamBadge(text: '2 Ongoing Projects'),
                          const SizedBox(height: 6),
                          _StreamBadge(text: '5 Products Listed'),
                          const SizedBox(height: 6),
                          _StreamBadge(text: 'Monetization Enabled'),
                        ],
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

class _StreamBadge extends StatelessWidget {
  final String text;

  const _StreamBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTextStyles.bodySmall(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
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

class _EarningsSourceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String amount;
  final int percentage;
  final Color color;

  const _EarningsSourceItem({
    required this.icon,
    required this.title,
    required this.amount,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium(
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                amount,
                style: AppTextStyles.bodyMedium(
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: AppColors.backgroundPrimary.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}


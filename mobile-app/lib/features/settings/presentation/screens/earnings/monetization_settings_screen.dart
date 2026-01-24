import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class MonetizationSettingsScreen extends StatefulWidget {
  const MonetizationSettingsScreen({super.key});

  @override
  State<MonetizationSettingsScreen> createState() =>
      _MonetizationSettingsScreenState();
}

class _MonetizationSettingsScreenState
    extends State<MonetizationSettingsScreen> {
  bool _isMonetizationEnabled = true;
  bool _allowTips = true;
  bool _allowSponsorship = true;
  bool _allowProductSales = false;
  bool _showEarningsPublicly = false;
  bool _isLoading = false;

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });

    _showMessage('Monetization settings saved successfully');
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
                      'Monetization Settings',
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
                    // Master Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentPrimary.withOpacity(0.2),
                            AppColors.accentSecondary.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.monetization_on,
                            color: AppColors.accentPrimary,
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monetization',
                                  style: AppTextStyles.bodyLarge(
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isMonetizationEnabled ? 'Enabled' : 'Disabled',
                                  style: AppTextStyles.bodySmall(
                                    color: _isMonetizationEnabled
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isMonetizationEnabled,
                            onChanged: (value) {
                              setState(() {
                                _isMonetizationEnabled = value;
                              });
                            },
                            activeColor: AppColors.accentPrimary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Revenue Streams
                    Text(
                      'Revenue Streams',
                      style: AppTextStyles.bodyLarge(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _SettingItem(
                      icon: Icons.work_outline,
                      title: 'Job Marketplace',
                      subtitle: 'Accept and complete freelance jobs',
                      value: _allowTips,
                      onChanged: _isMonetizationEnabled
                          ? (value) {
                              setState(() {
                                _allowTips = value;
                              });
                            }
                          : null,
                    ),
                    _SettingItem(
                      icon: Icons.folder_outlined,
                      title: 'Project Collaborations',
                      subtitle: 'Work on collaborative projects',
                      value: _allowSponsorship,
                      onChanged: _isMonetizationEnabled
                          ? (value) {
                              setState(() {
                                _allowSponsorship = value;
                              });
                            }
                          : null,
                    ),
                    _SettingItem(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Product Sales',
                      subtitle: 'Sell digital & physical products',
                      value: _allowProductSales,
                      onChanged: _isMonetizationEnabled
                          ? (value) {
                              setState(() {
                                _allowProductSales = value;
                              });
                            }
                          : null,
                    ),
                    _SettingItem(
                      icon: Icons.video_library_outlined,
                      title: 'Content Monetization',
                      subtitle: 'Earn from posts, videos, and stories',
                      value: _allowProductSales,
                      onChanged: _isMonetizationEnabled
                          ? (value) {
                              setState(() {
                                _allowProductSales = value;
                              });
                            }
                          : null,
                    ),
                    _SettingItem(
                      icon: Icons.card_giftcard_outlined,
                      title: 'Tips & Donations',
                      subtitle: 'Receive tips from supporters',
                      value: _allowProductSales,
                      onChanged: _isMonetizationEnabled
                          ? (value) {
                              setState(() {
                                _allowProductSales = value;
                              });
                            }
                          : null,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Blockchain Settings
                    Text(
                      'Blockchain & Crypto',
                      style: AppTextStyles.bodyLarge(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _SettingItem(
                      icon: Icons.currency_bitcoin,
                      title: 'Accept Cryptocurrency',
                      subtitle: 'Receive payments in crypto',
                      value: _allowProductSales,
                      onChanged: _isMonetizationEnabled
                          ? (value) {
                              setState(() {
                                _allowProductSales = value;
                              });
                            }
                          : null,
                    ),
                    _SettingItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Smart Contracts',
                      subtitle: 'Automate payments with smart contracts',
                      value: _allowProductSales,
                      onChanged: _isMonetizationEnabled
                          ? (value) {
                              setState(() {
                                _allowProductSales = value;
                              });
                            }
                          : null,
                    ),
                    _SettingItem(
                      icon: Icons.verified_outlined,
                      title: 'NFT Marketplace',
                      subtitle: 'Sell your content as NFTs',
                      value: _allowProductSales,
                      onChanged: _isMonetizationEnabled
                          ? (value) {
                              setState(() {
                                _allowProductSales = value;
                              });
                            }
                          : null,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Privacy Settings
                    Text(
                      'Privacy',
                      style: AppTextStyles.bodyLarge(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _SettingItem(
                      icon: Icons.visibility_outlined,
                      title: 'Show Earnings Publicly',
                      subtitle: 'Display your earnings on your profile',
                      value: _showEarningsPublicly,
                      onChanged: (value) {
                        setState(() {
                          _showEarningsPublicly = value;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
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
                              'You must have a verified account and meet minimum requirements to enable monetization features.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          disabledBackgroundColor:
                              AppColors.textTertiary.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Save Changes',
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

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
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
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textPrimary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium(
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentPrimary,
          ),
        ],
      ),
    );
  }
}


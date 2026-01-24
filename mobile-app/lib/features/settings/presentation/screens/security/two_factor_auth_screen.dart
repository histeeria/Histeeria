import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  bool _isEnabled = true;
  String _selectedMethod = 'Authenticator App';

  final List<Map<String, dynamic>> _authMethods = [
    {
      'title': 'Authenticator App',
      'subtitle': 'Use Google Authenticator or similar',
      'icon': Icons.smartphone_outlined,
      'recommended': true,
    },
    {
      'title': 'SMS/Text Message',
      'subtitle': 'Receive codes via SMS',
      'icon': Icons.sms_outlined,
      'recommended': false,
    },
    {
      'title': 'Email Code',
      'subtitle': 'Receive codes via email',
      'icon': Icons.email_outlined,
      'recommended': false,
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
                      'Two-Factor Authentication',
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
                    // Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isEnabled
                              ? [
                                  AppColors.success.withOpacity(0.2),
                                  AppColors.accentPrimary.withOpacity(0.2),
                                ]
                              : [
                                  AppColors.textTertiary.withOpacity(0.2),
                                  AppColors.textTertiary.withOpacity(0.1),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_isEnabled ? AppColors.success : AppColors.textTertiary)
                              .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_isEnabled ? AppColors.success : AppColors.textTertiary)
                                  .withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isEnabled ? Icons.verified_user : Icons.security_outlined,
                              color: _isEnabled ? AppColors.success : AppColors.textTertiary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEnabled ? 'Enabled' : 'Disabled',
                                  style: AppTextStyles.bodyLarge(
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isEnabled
                                      ? 'Your account is protected'
                                      : 'Enable for extra security',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isEnabled,
                            onChanged: (value) {
                              setState(() {
                                _isEnabled = value;
                              });
                              _showMessage(
                                value ? '2FA enabled' : '2FA disabled',
                              );
                            },
                            activeColor: AppColors.success,
                          ),
                        ],
                      ),
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
                              'Two-factor authentication adds an extra layer of security to your account. You\'ll need both your password and a verification code to sign in.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Authentication Methods
                    Text(
                      'Choose Authentication Method',
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ..._authMethods.map((method) {
                      final isSelected = _selectedMethod == method['title'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMethod = method['title'];
                          });
                          _showMessage('Method changed to ${method['title']}');
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentPrimary.withOpacity(0.15)
                                : AppColors.backgroundSecondary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentPrimary
                                  : AppColors.glassBorder.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.accentPrimary.withOpacity(0.2)
                                      : AppColors.textTertiary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  method['icon'],
                                  color: isSelected
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
                                          method['title'],
                                          style: AppTextStyles.bodyMedium(
                                            weight: FontWeight.w600,
                                            color: isSelected
                                                ? AppColors.accentPrimary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        if (method['recommended']) ...[
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
                                              'Recommended',
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
                                      method['subtitle'],
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.accentPrimary,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 32),
                    
                    // Setup Button
                    if (_isEnabled)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _showMessage('Setup wizard - Coming soon');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          child: Text(
                            'Configure $_selectedMethod',
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


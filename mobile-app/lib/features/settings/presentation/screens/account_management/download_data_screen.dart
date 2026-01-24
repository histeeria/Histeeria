import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class DownloadDataScreen extends StatefulWidget {
  const DownloadDataScreen({super.key});

  @override
  State<DownloadDataScreen> createState() => _DownloadDataScreenState();
}

class _DownloadDataScreenState extends State<DownloadDataScreen> {
  final Map<String, bool> _dataCategories = {
    'Profile Information': true,
    'Posts and Media': true,
    'Comments': true,
    'Messages': true,
    'Stories': false,
    'Followers and Following': true,
    'Account Activity': false,
    'Search History': false,
    'Login History': true,
    'Settings and Preferences': false,
  };

  String _selectedFormat = 'JSON';
  bool _isRequesting = false;

  final List<Map<String, dynamic>> _previousRequests = [
    {
      'date': 'Nov 15, 2024',
      'status': 'Ready',
      'size': '245 MB',
      'expiresIn': '3 days',
    },
    {
      'date': 'Oct 1, 2024',
      'status': 'Expired',
      'size': '198 MB',
      'expiresIn': null,
    },
  ];

  Future<void> _requestData() async {
    final selectedCount = _dataCategories.values.where((v) => v).length;
    
    if (selectedCount == 0) {
      _showMessage('Please select at least one data category');
      return;
    }

    final confirm = await _showConfirmDialog();
    if (confirm != true) return;

    setState(() {
      _isRequesting = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _isRequesting = false;
    });

    _showMessage('Data download request submitted. You\'ll receive an email when it\'s ready.');
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context);
  }

  Future<bool?> _showConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Request Data Download?',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'We\'ll prepare your data and send you a download link via email within 48 hours. The link will be valid for 7 days.',
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
              'Request',
              style: AppTextStyles.bodyMedium(
                color: AppColors.accentPrimary,
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
                      'Download Your Data',
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
                    // GDPR Compliance Notice
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
                            Icons.verified_user_outlined,
                            color: AppColors.accentPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Under GDPR and data protection laws, you have the right to download a copy of your data. Select what you want to include.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Previous Requests
                    if (_previousRequests.isNotEmpty) ...[
                      Text(
                        'Previous Requests',
                        style: AppTextStyles.bodyMedium(
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._previousRequests.map((request) {
                        final isReady = request['status'] == 'Ready';
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
                                isReady ? Icons.check_circle : Icons.cancel,
                                color: isReady ? AppColors.success : AppColors.textTertiary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request['date'],
                                      style: AppTextStyles.bodyMedium(
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${request['size']} • ${request['status']}',
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (request['expiresIn'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Expires in ${request['expiresIn']}',
                                        style: AppTextStyles.bodySmall(
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isReady)
                                ElevatedButton(
                                  onPressed: () {
                                    // TODO: Download file
                                    _showMessage('Download started');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Download',
                                    style: AppTextStyles.bodySmall(
                                      color: Colors.white,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                    
                    // New Request Section
                    Text(
                      'Select Data to Download',
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Data Categories
                    ..._dataCategories.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _dataCategories[entry.key] = !entry.value;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    entry.value
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: entry.value
                                        ? AppColors.accentPrimary
                                        : AppColors.textSecondary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    entry.key,
                                    style: AppTextStyles.bodyMedium(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 24),
                    
                    // Format Selection
                    Text(
                      'Download Format',
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: ['JSON', 'CSV', 'HTML'].map((format) {
                        final isSelected = _selectedFormat == format;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFormat = format;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accentPrimary.withOpacity(0.15)
                                    : AppColors.backgroundSecondary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.accentPrimary
                                      : AppColors.glassBorder.withOpacity(0.2),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                format,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall(
                                  color: isSelected
                                      ? AppColors.accentPrimary
                                      : AppColors.textSecondary,
                                  weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Request Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isRequesting ? null : _requestData,
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
                        child: _isRequesting
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
                                'Request Data Download',
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


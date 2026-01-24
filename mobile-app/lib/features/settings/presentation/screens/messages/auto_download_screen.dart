import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class AutoDownloadScreen extends StatefulWidget {
  const AutoDownloadScreen({super.key});

  @override
  State<AutoDownloadScreen> createState() => _AutoDownloadScreenState();
}

class _AutoDownloadScreenState extends State<AutoDownloadScreen> {
  // Photos
  String _photosWifi = 'Enabled';
  String _photosMobile = 'Disabled';
  
  // Videos
  String _videosWifi = 'Enabled';
  String _videosMobile = 'Disabled';
  
  // Documents
  String _documentsWifi = 'Enabled';
  String _documentsMobile = 'Disabled';
  
  // Audio
  String _audioWifi = 'Enabled';
  String _audioMobile = 'Enabled';

  final List<String> _options = ['Enabled', 'Disabled'];

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

  void _showOptionsDialog(String mediaType, String network, String currentValue) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$mediaType on $network',
              style: AppTextStyles.headlineSmall(
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ..._options.map((option) {
              final isSelected = option == currentValue;
              return ListTile(
                title: Text(
                  option,
                  style: AppTextStyles.bodyMedium(
                    color: isSelected ? AppColors.accentPrimary : AppColors.textPrimary,
                    weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: AppColors.accentPrimary)
                    : null,
                onTap: () {
                  setState(() {
                    if (mediaType == 'Photos') {
                      if (network == 'Wi-Fi') _photosWifi = option;
                      else _photosMobile = option;
                    } else if (mediaType == 'Videos') {
                      if (network == 'Wi-Fi') _videosWifi = option;
                      else _videosMobile = option;
                    } else if (mediaType == 'Documents') {
                      if (network == 'Wi-Fi') _documentsWifi = option;
                      else _documentsMobile = option;
                    } else if (mediaType == 'Audio') {
                      if (network == 'Wi-Fi') _audioWifi = option;
                      else _audioMobile = option;
                    }
                  });
                  Navigator.pop(context);
                  _showMessage('$mediaType on $network: $option');
                },
              );
            }).toList(),
          ],
        ),
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
                      'Auto-Download Media',
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
                              'Choose which media types to automatically download when connected to Wi-Fi or mobile data.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Photos
                    _MediaSection(
                      icon: Icons.photo_outlined,
                      title: 'Photos',
                      wifiStatus: _photosWifi,
                      mobileStatus: _photosMobile,
                      onWifiTap: () => _showOptionsDialog('Photos', 'Wi-Fi', _photosWifi),
                      onMobileTap: () => _showOptionsDialog('Photos', 'Mobile Data', _photosMobile),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Videos
                    _MediaSection(
                      icon: Icons.videocam_outlined,
                      title: 'Videos',
                      wifiStatus: _videosWifi,
                      mobileStatus: _videosMobile,
                      onWifiTap: () => _showOptionsDialog('Videos', 'Wi-Fi', _videosWifi),
                      onMobileTap: () => _showOptionsDialog('Videos', 'Mobile Data', _videosMobile),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Documents
                    _MediaSection(
                      icon: Icons.description_outlined,
                      title: 'Documents',
                      wifiStatus: _documentsWifi,
                      mobileStatus: _documentsMobile,
                      onWifiTap: () => _showOptionsDialog('Documents', 'Wi-Fi', _documentsWifi),
                      onMobileTap: () => _showOptionsDialog('Documents', 'Mobile Data', _documentsMobile),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Audio
                    _MediaSection(
                      icon: Icons.audiotrack_outlined,
                      title: 'Audio',
                      wifiStatus: _audioWifi,
                      mobileStatus: _audioMobile,
                      onWifiTap: () => _showOptionsDialog('Audio', 'Wi-Fi', _audioWifi),
                      onMobileTap: () => _showOptionsDialog('Audio', 'Mobile Data', _audioMobile),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Data Saver Tip
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.data_saver_on,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tip: Disable auto-download on mobile data to save your data plan.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.textSecondary,
                              ).copyWith(height: 1.5),
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
        ),
      ),
    );
  }
}

class _MediaSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String wifiStatus;
  final String mobileStatus;
  final VoidCallback onWifiTap;
  final VoidCallback onMobileTap;

  const _MediaSection({
    required this.icon,
    required this.title,
    required this.wifiStatus,
    required this.mobileStatus,
    required this.onWifiTap,
    required this.onMobileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                icon,
                color: AppColors.accentPrimary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTextStyles.bodyLarge(
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Wi-Fi
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onWifiTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'When using Wi-Fi',
                        style: AppTextStyles.bodyMedium(),
                      ),
                    ),
                    Text(
                      wifiStatus,
                      style: AppTextStyles.bodySmall(
                        color: wifiStatus == 'Enabled'
                            ? AppColors.success
                            : AppColors.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Mobile Data
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onMobileTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'When using mobile data',
                        style: AppTextStyles.bodyMedium(),
                      ),
                    ),
                    Text(
                      mobileStatus,
                      style: AppTextStyles.bodySmall(
                        color: mobileStatus == 'Enabled'
                            ? AppColors.success
                            : AppColors.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


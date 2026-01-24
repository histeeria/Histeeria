import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class AdvancedNotificationsScreen extends StatefulWidget {
  const AdvancedNotificationsScreen({super.key});

  @override
  State<AdvancedNotificationsScreen> createState() => _AdvancedNotificationsScreenState();
}

class _AdvancedNotificationsScreenState extends State<AdvancedNotificationsScreen> {
  String _soundSelected = 'Default';
  String _vibrationSelected = 'Default';
  bool _badgeCount = true;
  bool _lockScreenPreview = true;
  bool _groupedNotifications = true;
  bool _notificationDots = true;
  bool _inAppSounds = true;
  bool _inAppVibration = false;

  final List<String> _sounds = [
    'Default',
    'None',
    'Ding',
    'Chime',
    'Bell',
    'Whistle',
  ];

  final List<String> _vibrations = [
    'Default',
    'None',
    'Short',
    'Long',
    'Double',
    'Triple',
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

  void _showSoundPicker() {
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
              'Notification Sound',
              style: AppTextStyles.headlineSmall(
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ..._sounds.map((sound) {
              final isSelected = sound == _soundSelected;
              return ListTile(
                title: Text(
                  sound,
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
                    _soundSelected = sound;
                  });
                  Navigator.pop(context);
                  _showMessage('Sound changed to $sound');
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showVibrationPicker() {
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
              'Vibration Pattern',
              style: AppTextStyles.headlineSmall(
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ..._vibrations.map((vibration) {
              final isSelected = vibration == _vibrationSelected;
              return ListTile(
                title: Text(
                  vibration,
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
                    _vibrationSelected = vibration;
                  });
                  Navigator.pop(context);
                  _showMessage('Vibration changed to $vibration');
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
                      'Advanced Settings',
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
                    // Sound Settings
                    Text(
                      'Sound & Vibration',
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showSoundPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volume_up_outlined,
                                color: AppColors.textSecondary,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notification Sound',
                                      style: AppTextStyles.bodyMedium(
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _soundSelected,
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
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showVibrationPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.vibration,
                                color: AppColors.textSecondary,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vibration Pattern',
                                      style: AppTextStyles.bodyMedium(
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _vibrationSelected,
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
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Display Settings
                    Text(
                      'Display',
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AdvancedToggle(
                      icon: Icons.notifications_active_outlined,
                      title: 'Badge Count',
                      subtitle: 'Show unread count on app icon',
                      value: _badgeCount,
                      onChanged: (value) => setState(() => _badgeCount = value),
                    ),
                    _AdvancedToggle(
                      icon: Icons.lock_outline,
                      title: 'Lock Screen Preview',
                      subtitle: 'Show notification content on lock screen',
                      value: _lockScreenPreview,
                      onChanged: (value) => setState(() => _lockScreenPreview = value),
                    ),
                    _AdvancedToggle(
                      icon: Icons.filter_none_outlined,
                      title: 'Grouped Notifications',
                      subtitle: 'Group similar notifications together',
                      value: _groupedNotifications,
                      onChanged: (value) => setState(() => _groupedNotifications = value),
                    ),
                    _AdvancedToggle(
                      icon: Icons.fiber_manual_record,
                      title: 'Notification Dots',
                      subtitle: 'Show dots on app icon',
                      value: _notificationDots,
                      onChanged: (value) => setState(() => _notificationDots = value),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // In-App Settings
                    Text(
                      'In-App Notifications',
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AdvancedToggle(
                      icon: Icons.music_note_outlined,
                      title: 'In-App Sounds',
                      subtitle: 'Play sounds while using the app',
                      value: _inAppSounds,
                      onChanged: (value) => setState(() => _inAppSounds = value),
                    ),
                    _AdvancedToggle(
                      icon: Icons.vibration,
                      title: 'In-App Vibration',
                      subtitle: 'Vibrate while using the app',
                      value: _inAppVibration,
                      onChanged: (value) => setState(() => _inAppVibration = value),
                    ),
                    
                    const SizedBox(height: 32),
                    
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
                              'Some settings may be overridden by your device\'s system settings.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
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

class _AdvancedToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AdvancedToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
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
            color: AppColors.textSecondary,
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


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class MessageSettingsScreen extends StatefulWidget {
  const MessageSettingsScreen({super.key});

  @override
  State<MessageSettingsScreen> createState() => _MessageSettingsScreenState();
}

class _MessageSettingsScreenState extends State<MessageSettingsScreen> {
  // Privacy
  bool _readReceipts = true;
  bool _typingIndicators = true;
  bool _onlineStatus = true;
  bool _lastSeen = true;
  
  // Chat Features
  String _textSize = 'Medium';
  bool _showTimestamps = true;
  
  // Media
  bool _saveToGallery = false;
  
  // Voice & Video
  String _playbackSpeed = '1x';
  bool _autoPlayVoice = false;
  bool _raiseToListen = true;
  
  // Disappearing Messages
  bool _disappearingDefault = false;
  
  // Groups
  String _whoCanAddToGroups = 'Everyone';
  bool _groupMentionsOnly = false;
  bool _leaveSilently = false;
  
  // Advanced
  bool _linkPreviews = true;
  bool _messageTranslation = false;
  bool _smartReply = true;

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
                      'Messages',
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
                    // Quick Access Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentPrimary.withOpacity(0.2),
                            AppColors.accentSecondary.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.flash_on,
                                color: AppColors.accentPrimary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Quick Access',
                                style: AppTextStyles.bodyLarge(
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _QuickToggle(
                            icon: Icons.done_all,
                            title: 'Read Receipts',
                            value: _readReceipts,
                            onChanged: (value) => setState(() => _readReceipts = value),
                          ),
                          const SizedBox(height: 8),
                          _QuickToggle(
                            icon: Icons.circle,
                            title: 'Online Status',
                            value: _onlineStatus,
                            onChanged: (value) => setState(() => _onlineStatus = value),
                          ),
                          const SizedBox(height: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _showMessage('Message Requests - Coming soon');
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSecondary.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.mail_outline,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Message Requests',
                                      style: AppTextStyles.bodySmall(
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentQuaternary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '5',
                                        style: AppTextStyles.bodySmall(
                                          color: Colors.white,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: AppColors.textTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Privacy & Security
                    _SectionHeader(
                      icon: Icons.lock_outline,
                      title: 'Privacy & Security',
                    ),
                    _SettingsItem(
                      icon: Icons.done_all,
                      title: 'Read Receipts',
                      subtitle: _readReceipts ? 'Show when you read' : 'Hidden',
                      trailing: Switch(
                        value: _readReceipts,
                        onChanged: (value) => setState(() => _readReceipts = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.keyboard_outlined,
                      title: 'Typing Indicators',
                      subtitle: _typingIndicators ? 'Show when typing' : 'Hidden',
                      trailing: Switch(
                        value: _typingIndicators,
                        onChanged: (value) => setState(() => _typingIndicators = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.circle,
                      title: 'Online Status',
                      subtitle: _onlineStatus ? 'Visible' : 'Hidden',
                      trailing: Switch(
                        value: _onlineStatus,
                        onChanged: (value) => setState(() => _onlineStatus = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.access_time,
                      title: 'Last Seen',
                      subtitle: _lastSeen ? 'Everyone' : 'Nobody',
                      onTap: () {
                        context.push('/settings/messages/last-seen');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.person_add_outlined,
                      title: 'Who Can Message You',
                      subtitle: 'Everyone',
                      onTap: () {
                        context.push('/settings/messages/who-can-message');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Chat Features
                    _SectionHeader(
                      icon: Icons.chat_bubble_outline,
                      title: 'Chat Features',
                    ),
                    _SettingsItem(
                      icon: Icons.wallpaper_outlined,
                      title: 'Chat Wallpaper',
                      subtitle: 'Customize background',
                      onTap: () {
                        context.push('/settings/messages/wallpaper');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.format_size,
                      title: 'Text Size',
                      subtitle: _textSize,
                      onTap: () {
                        _showMessage('Text size selector - Coming soon');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.schedule_outlined,
                      title: 'Show Timestamps',
                      subtitle: _showTimestamps ? 'Always show' : 'On tap',
                      trailing: Switch(
                        value: _showTimestamps,
                        onChanged: (value) => setState(() => _showTimestamps = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Media & Storage
                    _SectionHeader(
                      icon: Icons.perm_media_outlined,
                      title: 'Media & Storage',
                    ),
                    _SettingsItem(
                      icon: Icons.download_outlined,
                      title: 'Auto-Download Media',
                      subtitle: 'Photos, videos, documents',
                      onTap: () {
                        context.push('/settings/messages/auto-download');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.high_quality_outlined,
                      title: 'Media Quality',
                      subtitle: 'Standard',
                      onTap: () {
                        _showMessage('Media quality - Coming soon');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.save_outlined,
                      title: 'Save to Gallery',
                      subtitle: _saveToGallery ? 'Auto-save media' : 'Manual save',
                      trailing: Switch(
                        value: _saveToGallery,
                        onChanged: (value) => setState(() => _saveToGallery = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.storage_outlined,
                      title: 'Storage Usage',
                      subtitle: '2.4 GB used',
                      onTap: () {
                        context.push('/settings/messages/storage');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.delete_outline,
                      title: 'Clear Cache',
                      subtitle: 'Free up 186 MB',
                      onTap: () {
                        _showMessage('Cache cleared successfully');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Voice & Video
                    _SectionHeader(
                      icon: Icons.mic_outlined,
                      title: 'Voice & Video',
                    ),
                    _SettingsItem(
                      icon: Icons.speed_outlined,
                      title: 'Voice Message Playback',
                      subtitle: _playbackSpeed,
                      onTap: () {
                        _showMessage('Playback speed - Coming soon');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.play_circle_outline,
                      title: 'Auto-Play Voice Messages',
                      subtitle: _autoPlayVoice ? 'Enabled' : 'Disabled',
                      trailing: Switch(
                        value: _autoPlayVoice,
                        onChanged: (value) => setState(() => _autoPlayVoice = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.phone_in_talk_outlined,
                      title: 'Raise to Listen',
                      subtitle: _raiseToListen ? 'Play by raising phone' : 'Disabled',
                      trailing: Switch(
                        value: _raiseToListen,
                        onChanged: (value) => setState(() => _raiseToListen = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.videocam_outlined,
                      title: 'Video Quality',
                      subtitle: 'Auto',
                      onTap: () {
                        _showMessage('Video quality - Coming soon');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Disappearing Messages
                    _SectionHeader(
                      icon: Icons.timer_outlined,
                      title: 'Disappearing Messages',
                    ),
                    _SettingsItem(
                      icon: Icons.auto_delete_outlined,
                      title: 'Default Timer',
                      subtitle: _disappearingDefault ? '7 days' : 'Off',
                      onTap: () {
                        _showMessage('Disappearing timer - Coming soon');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.new_releases_outlined,
                      title: 'Apply to New Chats',
                      subtitle: 'Auto-enable for new conversations',
                      trailing: Switch(
                        value: _disappearingDefault,
                        onChanged: (value) => setState(() => _disappearingDefault = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Groups
                    _SectionHeader(
                      icon: Icons.groups_outlined,
                      title: 'Groups',
                    ),
                    _SettingsItem(
                      icon: Icons.group_add_outlined,
                      title: 'Who Can Add You to Groups',
                      subtitle: _whoCanAddToGroups,
                      onTap: () {
                        _showMessage('Group permissions - Coming soon');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.alternate_email,
                      title: 'Group Mentions Only',
                      subtitle: _groupMentionsOnly ? 'Only when mentioned' : 'All messages',
                      trailing: Switch(
                        value: _groupMentionsOnly,
                        onChanged: (value) => setState(() => _groupMentionsOnly = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.exit_to_app_outlined,
                      title: 'Leave Groups Silently',
                      subtitle: _leaveSilently ? 'Don\'t notify others' : 'Notify members',
                      trailing: Switch(
                        value: _leaveSilently,
                        onChanged: (value) => setState(() => _leaveSilently = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Chat Backup
                    _SectionHeader(
                      icon: Icons.backup_outlined,
                      title: 'Chat Backup',
                    ),
                    _SettingsItem(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Chat Backup',
                      subtitle: 'Last backup: Dec 3, 10:30 AM',
                      onTap: () {
                        context.push('/settings/messages/backup');
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Advanced
                    _SectionHeader(
                      icon: Icons.tune,
                      title: 'Advanced',
                    ),
                    _SettingsItem(
                      icon: Icons.link_outlined,
                      title: 'Link Previews',
                      subtitle: _linkPreviews ? 'Show preview cards' : 'Hidden',
                      trailing: Switch(
                        value: _linkPreviews,
                        onChanged: (value) => setState(() => _linkPreviews = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.translate_outlined,
                      title: 'Message Translation',
                      subtitle: _messageTranslation ? 'Enabled' : 'Disabled',
                      trailing: Switch(
                        value: _messageTranslation,
                        onChanged: (value) => setState(() => _messageTranslation = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Smart Reply',
                      subtitle: _smartReply ? 'AI suggestions enabled' : 'Disabled',
                      trailing: Switch(
                        value: _smartReply,
                        onChanged: (value) => setState(() => _smartReply = value),
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.file_download_outlined,
                      title: 'Export All Chats',
                      subtitle: 'Download chat history',
                      onTap: () {
                        _showMessage('Chat export - Coming soon');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.restore_outlined,
                      title: 'Reset Settings',
                      subtitle: 'Restore defaults',
                      onTap: () {
                        _showMessage('Reset settings - Coming soon');
                      },
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.accentPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.bodyMedium(
              color: AppColors.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.glassBorder.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _QuickToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _QuickToggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: AppTextStyles.bodySmall(
              weight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentPrimary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
              trailing ??
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


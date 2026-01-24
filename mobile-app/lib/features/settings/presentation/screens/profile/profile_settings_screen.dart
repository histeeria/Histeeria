import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

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
                      'Profile Settings',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    // Profile Preview Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentPrimary.withOpacity(0.15),
                            AppColors.accentSecondary.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accentPrimary,
                                  AppColors.accentSecondary,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'JD',
                                style: AppTextStyles.headlineSmall(
                                  color: Colors.white,
                                  weight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'John Doe',
                                  style: AppTextStyles.bodyLarge(
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@johndoe • Founder',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.push('/profile');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accentPrimary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.visibility_outlined,
                                color: AppColors.accentPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Basic Information Section
                    _SectionHeader(title: 'Basic Information'),
                    _SettingsItem(
                      icon: Icons.photo_camera_outlined,
                      title: 'Profile Photo',
                      subtitle: 'Change your profile picture',
                      onTap: () {
                        context.push('/settings/profile/photo');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.image_outlined,
                      title: 'Cover Photo',
                      subtitle: 'Add a banner to your profile',
                      onTap: () {
                        context.push('/settings/profile/cover-photo');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.person_outline,
                      title: 'Display Name',
                      subtitle: 'John Doe',
                      onTap: () {
                        context.push('/settings/profile/display-name');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.description_outlined,
                      title: 'Bio',
                      subtitle: 'Tell people about yourself',
                      onTap: () {
                        context.push('/settings/profile/bio');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.badge_outlined,
                      title: 'Tag',
                      subtitle: 'Founder',
                      onTap: () {
                        context.push('/settings/profile/tag');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      subtitle: 'Add your location',
                      onTap: () {
                        context.push('/settings/profile/location');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.language,
                      title: 'Website',
                      subtitle: 'Add your website URL',
                      onTap: () {
                        context.push('/settings/profile/website');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.link,
                      title: 'Social Links',
                      subtitle: 'Connect your social profiles',
                      onTap: () {
                        context.push('/settings/profile/social-links');
                      },
                    ),

                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),

                    // About Section
                    _SectionHeader(title: 'About Section'),
                    _SettingsItem(
                      icon: Icons.auto_stories_outlined,
                      title: 'Story',
                      subtitle: 'Share your journey',
                      onTap: () {
                        context.push('/settings/profile/story');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.work_outline,
                      title: 'Experience',
                      subtitle: 'Add your work experience',
                      onTap: () {
                        context.push('/settings/profile/experience');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.school_outlined,
                      title: 'Education',
                      subtitle: 'Add your education',
                      onTap: () {
                        context.push('/settings/profile/education');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.code_outlined,
                      title: 'Skills',
                      subtitle: 'Showcase your skills',
                      onTap: () {
                        context.push('/settings/profile/skills');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.verified_outlined,
                      title: 'Certifications',
                      subtitle: 'Add certifications',
                      onTap: () {
                        context.push('/settings/profile/certifications');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.translate_outlined,
                      title: 'Languages',
                      subtitle: 'Languages you speak',
                      onTap: () {
                        context.push('/settings/profile/languages');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.volunteer_activism_outlined,
                      title: 'Volunteering',
                      subtitle: 'Add volunteer experience',
                      onTap: () {
                        context.push('/settings/profile/volunteering');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.article_outlined,
                      title: 'Publications',
                      subtitle: 'Add your publications',
                      onTap: () {
                        context.push('/settings/profile/publications');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.favorite_outline,
                      title: 'Interests',
                      subtitle: 'What you\'re interested in',
                      onTap: () {
                        context.push('/settings/profile/interests');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.emoji_events_outlined,
                      title: 'Achievements',
                      subtitle: 'Add your achievements',
                      onTap: () {
                        context.push('/settings/profile/achievements');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.more_horiz,
                      title: 'More',
                      subtitle: 'Additional profile sections',
                      onTap: () {
                        context.push('/settings/profile/more-sections');
                      },
                    ),

                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),

                    // Profile Visibility
                    _SectionHeader(title: 'Profile Visibility'),
                    _SettingsItem(
                      icon: Icons.visibility_outlined,
                      title: 'Profile Type',
                      subtitle: 'Public',
                      onTap: () {
                        context.push('/settings/profile/visibility');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.circle,
                      title: 'Online Status',
                      subtitle: 'Show when you\'re active',
                      onTap: () {
                        context.push('/settings/profile/online-status');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.schedule_outlined,
                      title: 'Last Seen',
                      subtitle: 'Display last active time',
                      onTap: () {
                        context.push('/settings/profile/last-seen');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.search,
                      title: 'Search Engine Indexing',
                      subtitle: 'Allow search engines to find you',
                      onTap: () {
                        context.push('/settings/profile/search-indexing');
                      },
                    ),

                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),

                    // Professional Information
                    _SectionHeader(title: 'Professional Information'),
                    _SettingsItem(
                      icon: Icons.verified_user_outlined,
                      title: 'Verification Badge',
                      subtitle: 'Request verification',
                      onTap: () {
                        context.push('/settings/profile/verification');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.business_center_outlined,
                      title: 'Professional Title',
                      subtitle: 'Your job title or role',
                      onTap: () {
                        context.push('/settings/profile/professional-title');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.domain_outlined,
                      title: 'Industry',
                      subtitle: 'Your field of work',
                      onTap: () {
                        context.push('/settings/profile/industry');
                      },
                    ),

                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),

                    // Profile Sections Management
                    _SectionHeader(title: 'Profile Sections'),
                    _SettingsItem(
                      icon: Icons.grid_view_outlined,
                      title: 'Manage Sections',
                      subtitle: 'Show/hide profile sections',
                      onTap: () {
                        context.push('/settings/profile/manage-sections');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.push_pin_outlined,
                      title: 'Featured Content',
                      subtitle: 'Pin posts or projects',
                      onTap: () {
                        context.push('/settings/profile/featured-content');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.highlight_outlined,
                      title: 'Highlights',
                      subtitle: 'Organize your story highlights',
                      onTap: () {
                        context.push('/settings/profile/highlights');
                      },
                    ),

                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),

                    // Profile Customization
                    _SectionHeader(title: 'Customization'),
                    _SettingsItem(
                      icon: Icons.palette_outlined,
                      title: 'Profile Theme',
                      subtitle: 'Customize your profile colors',
                      onTap: () {
                        context.push('/settings/profile/theme');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.view_module_outlined,
                      title: 'Layout Style',
                      subtitle: 'Grid or list view',
                      onTap: () {
                        context.push('/settings/profile/layout');
                      },
                    ),

                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),

                    // QR Code & Sharing
                    _SectionHeader(title: 'QR Code & Sharing'),
                    _SettingsItem(
                      icon: Icons.qr_code,
                      title: 'Profile QR Code',
                      subtitle: 'Generate scannable code',
                      onTap: () {
                        context.push('/settings/profile/qr-code');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.share_outlined,
                      title: 'Share Profile',
                      subtitle: 'Share your profile link',
                      onTap: () {
                        context.push('/settings/profile/share');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.link,
                      title: 'Profile URL',
                      subtitle: 'histeeria.app/@johndoe',
                      onTap: () {
                        context.push('/settings/profile/custom-url');
                      },
                    ),

                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),

                    // Advanced Settings
                    _SectionHeader(title: 'Advanced'),
                    _SettingsItem(
                      icon: Icons.analytics_outlined,
                      title: 'Profile Analytics',
                      subtitle: 'View profile visits',
                      onTap: () {
                        context.push('/settings/profile/analytics');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.archive_outlined,
                      title: 'Profile Archive',
                      subtitle: 'Hide old posts',
                      onTap: () {
                        context.push('/settings/profile/archive');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.download_outlined,
                      title: 'Download Profile Data',
                      subtitle: 'Export your profile info',
                      onTap: () {
                        context.push('/settings/profile/download-data');
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.visibility_off_outlined,
                      title: 'Deactivate Profile',
                      subtitle: 'Temporarily hide your profile',
                      onTap: () {
                        context.push('/settings/profile/deactivate');
                      },
                    ),

                    const SizedBox(height: 24),
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
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              Icon(icon, color: AppColors.textSecondary, size: 24),
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

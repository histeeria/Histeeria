import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _smsEnabled = false;
  bool _doNotDisturb = false;

  // Posts & Interactions
  bool _likesEnabled = true;
  bool _commentsEnabled = true;
  bool _sharesEnabled = true;
  bool _mentionsEnabled = true;

  // Social
  bool _followersEnabled = true;
  bool _followRequestsEnabled = true;
  bool _friendSuggestionsEnabled = false;

  // Messages
  bool _directMessagesEnabled = true;
  bool _groupMessagesEnabled = true;
  bool _messageRequestsEnabled = true;
  bool _callsEnabled = true;

  // Communities
  bool _communityInvitesEnabled = true;
  bool _communityPostsEnabled = false;
  bool _communityAnnouncementsEnabled = true;

  // Projects & Jobs
  bool _projectUpdatesEnabled = true;
  bool _jobAlertsEnabled = true;
  bool _applicationsEnabled = true;

  // Monetization
  bool _earningsEnabled = true;
  bool _payoutsEnabled = true;
  bool _transactionsEnabled = true;

  // Security
  bool _loginAlertsEnabled = true;
  bool _securityUpdatesEnabled = true;
  bool _accountChangesEnabled = true;

  // Recommendations
  bool _suggestedContentEnabled = false;
  bool _trendingTopicsEnabled = false;
  bool _peopleToFollowEnabled = false;

  // Marketing
  bool _productUpdatesEnabled = false;
  bool _tipsEnabled = false;
  bool _specialOffersEnabled = false;

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
                      'Notifications',
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
                    // Quick Settings Card
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
                                Icons.notifications_active,
                                color: AppColors.accentPrimary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Quick Settings',
                                style: AppTextStyles.bodyLarge(
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _QuickToggle(
                            icon: Icons.notifications_outlined,
                            title: 'Push Notifications',
                            subtitle: 'Master control',
                            value: _pushEnabled,
                            onChanged: (value) {
                              setState(() {
                                _pushEnabled = value;
                              });
                              _showMessage(value ? 'Push notifications enabled' : 'Push notifications disabled');
                            },
                          ),
                          const SizedBox(height: 12),
                          _QuickToggle(
                            icon: Icons.email_outlined,
                            title: 'Email Notifications',
                            subtitle: 'Receive via email',
                            value: _emailEnabled,
                            onChanged: (value) {
                              setState(() {
                                _emailEnabled = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _QuickToggle(
                            icon: Icons.sms_outlined,
                            title: 'SMS Notifications',
                            subtitle: 'Text message alerts',
                            value: _smsEnabled,
                            onChanged: (value) {
                              setState(() {
                                _smsEnabled = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                context.push('/settings/notifications/do-not-disturb');
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSecondary.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.bedtime_outlined,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Do Not Disturb',
                                            style: AppTextStyles.bodyMedium(
                                              weight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _doNotDisturb ? '10 PM - 8 AM' : 'Off',
                                            style: AppTextStyles.bodySmall(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _doNotDisturb,
                                      onChanged: (value) {
                                        setState(() {
                                          _doNotDisturb = value;
                                        });
                                      },
                                      activeColor: AppColors.accentPrimary,
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
                    
                    // Posts & Interactions
                    _SectionHeader(
                      icon: Icons.favorite_outline,
                      title: 'Posts & Interactions',
                    ),
                    _NotificationItem(
                      title: 'Likes',
                      subtitle: 'Someone likes your post',
                      value: _likesEnabled,
                      onChanged: (value) => setState(() => _likesEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Comments',
                      subtitle: 'Someone comments on your post',
                      value: _commentsEnabled,
                      onChanged: (value) => setState(() => _commentsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Shares',
                      subtitle: 'Someone shares your post',
                      value: _sharesEnabled,
                      onChanged: (value) => setState(() => _sharesEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Mentions',
                      subtitle: 'Someone mentions you',
                      value: _mentionsEnabled,
                      onChanged: (value) => setState(() => _mentionsEnabled = value),
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Social
                    _SectionHeader(
                      icon: Icons.people_outline,
                      title: 'Social',
                    ),
                    _NotificationItem(
                      title: 'New Followers',
                      subtitle: 'Someone follows you',
                      value: _followersEnabled,
                      onChanged: (value) => setState(() => _followersEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Follow Requests',
                      subtitle: 'Someone requests to follow you',
                      value: _followRequestsEnabled,
                      onChanged: (value) => setState(() => _followRequestsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Friend Suggestions',
                      subtitle: 'People you might know',
                      value: _friendSuggestionsEnabled,
                      onChanged: (value) => setState(() => _friendSuggestionsEnabled = value),
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Messages
                    _SectionHeader(
                      icon: Icons.message_outlined,
                      title: 'Messages',
                    ),
                    _NotificationItem(
                      title: 'Direct Messages',
                      subtitle: 'New message received',
                      value: _directMessagesEnabled,
                      onChanged: (value) => setState(() => _directMessagesEnabled = value),
                      hasDetails: true,
                      onDetailsTap: () {
                        context.push('/settings/notifications/messages');
                      },
                    ),
                    _NotificationItem(
                      title: 'Group Messages',
                      subtitle: 'New group message',
                      value: _groupMessagesEnabled,
                      onChanged: (value) => setState(() => _groupMessagesEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Message Requests',
                      subtitle: 'New message request',
                      value: _messageRequestsEnabled,
                      onChanged: (value) => setState(() => _messageRequestsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Calls',
                      subtitle: 'Incoming calls',
                      value: _callsEnabled,
                      onChanged: (value) => setState(() => _callsEnabled = value),
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Communities
                    _SectionHeader(
                      icon: Icons.groups_outlined,
                      title: 'Communities',
                    ),
                    _NotificationItem(
                      title: 'Community Invitations',
                      subtitle: 'Someone invites you',
                      value: _communityInvitesEnabled,
                      onChanged: (value) => setState(() => _communityInvitesEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'New Posts',
                      subtitle: 'Posts in your communities',
                      value: _communityPostsEnabled,
                      onChanged: (value) => setState(() => _communityPostsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Announcements',
                      subtitle: 'Important community updates',
                      value: _communityAnnouncementsEnabled,
                      onChanged: (value) => setState(() => _communityAnnouncementsEnabled = value),
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Projects & Jobs
                    _SectionHeader(
                      icon: Icons.work_outline,
                      title: 'Projects & Jobs',
                    ),
                    _NotificationItem(
                      title: 'Project Updates',
                      subtitle: 'Updates on your projects',
                      value: _projectUpdatesEnabled,
                      onChanged: (value) => setState(() => _projectUpdatesEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Job Alerts',
                      subtitle: 'New job opportunities',
                      value: _jobAlertsEnabled,
                      onChanged: (value) => setState(() => _jobAlertsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Application Updates',
                      subtitle: 'Status of your applications',
                      value: _applicationsEnabled,
                      onChanged: (value) => setState(() => _applicationsEnabled = value),
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Monetization
                    _SectionHeader(
                      icon: Icons.attach_money,
                      title: 'Monetization',
                    ),
                    _NotificationItem(
                      title: 'Earnings',
                      subtitle: 'New earnings received',
                      value: _earningsEnabled,
                      onChanged: (value) => setState(() => _earningsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Payouts',
                      subtitle: 'Payout processing updates',
                      value: _payoutsEnabled,
                      onChanged: (value) => setState(() => _payoutsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Transactions',
                      subtitle: 'Transaction confirmations',
                      value: _transactionsEnabled,
                      onChanged: (value) => setState(() => _transactionsEnabled = value),
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Security
                    _SectionHeader(
                      icon: Icons.security_outlined,
                      title: 'Security',
                    ),
                    _NotificationItem(
                      title: 'Login Alerts',
                      subtitle: 'New device login',
                      value: _loginAlertsEnabled,
                      onChanged: (value) => setState(() => _loginAlertsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Security Updates',
                      subtitle: 'Important security info',
                      value: _securityUpdatesEnabled,
                      onChanged: (value) => setState(() => _securityUpdatesEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Account Changes',
                      subtitle: 'Password, email changes',
                      value: _accountChangesEnabled,
                      onChanged: (value) => setState(() => _accountChangesEnabled = value),
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Recommendations
                    _SectionHeader(
                      icon: Icons.recommend_outlined,
                      title: 'Recommendations',
                    ),
                    _NotificationItem(
                      title: 'Suggested Content',
                      subtitle: 'Posts you might like',
                      value: _suggestedContentEnabled,
                      onChanged: (value) => setState(() => _suggestedContentEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Trending Topics',
                      subtitle: 'What\'s trending now',
                      value: _trendingTopicsEnabled,
                      onChanged: (value) => setState(() => _trendingTopicsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'People to Follow',
                      subtitle: 'Suggested connections',
                      value: _peopleToFollowEnabled,
                      onChanged: (value) => setState(() => _peopleToFollowEnabled = value),
                    ),
                    
                    const SizedBox(height: 16),
                    _SectionDivider(),
                    const SizedBox(height: 16),
                    
                    // Marketing
                    _SectionHeader(
                      icon: Icons.campaign_outlined,
                      title: 'Marketing & Updates',
                    ),
                    _NotificationItem(
                      title: 'Product Updates',
                      subtitle: 'New features and improvements',
                      value: _productUpdatesEnabled,
                      onChanged: (value) => setState(() => _productUpdatesEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Tips & Tutorials',
                      subtitle: 'Learn new features',
                      value: _tipsEnabled,
                      onChanged: (value) => setState(() => _tipsEnabled = value),
                    ),
                    _NotificationItem(
                      title: 'Special Offers',
                      subtitle: 'Promotions and discounts',
                      value: _specialOffersEnabled,
                      onChanged: (value) => setState(() => _specialOffersEnabled = value),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Advanced Settings Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          context.push('/settings/notifications/advanced');
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.accentPrimary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune,
                              color: AppColors.accentPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Advanced Settings',
                              style: AppTextStyles.bodyLarge(
                                color: AppColors.accentPrimary,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
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
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _QuickToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
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

class _NotificationItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool hasDetails;
  final VoidCallback? onDetailsTap;

  const _NotificationItem({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.hasDetails = false,
    this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
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
          if (hasDetails && onDetailsTap != null)
            IconButton(
              icon: Icon(
                Icons.settings_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: onDetailsTap,
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


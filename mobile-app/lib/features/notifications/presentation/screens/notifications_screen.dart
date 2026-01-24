import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/optimized_cached_image.dart';
import '../../../../core/utils/date_utils.dart' as app_date;
import '../../data/models/notification.dart';
import '../../data/providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedBottomNavIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Mark all as read when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      provider.markAllAsRead();
    });
    
    // Setup pagination
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      context.read<NotificationProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Consumer<NotificationProvider>(
                builder: (context, provider, _) => AppHeader(
                onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  messageBadge: 0, // Message badge handled separately
                onMessageTap: () {
                  context.push('/messages');
                },
                ),
              ),
              // Notifications Header - Instagram style
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.glassBorder.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
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
                      'Notifications',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Tab Bar - Instagram style
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTextStyles.bodyMedium(weight: FontWeight.w600),
                  unselectedLabelStyle: AppTextStyles.bodyMedium(),
                  indicator: BoxDecoration(
                    color: AppColors.backgroundPrimary.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Follow Requests'),
                  ],
                ),
              ),
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: [
                    _AllNotificationsTab(scrollController: _scrollController),
                    _RequestsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNavigation(
          selectedIndex: _selectedBottomNavIndex,
          onTap: (index) {
            if (index == 0) {
              context.go('/home');
            } else if (index == 1) {
              context.push('/search');
            } else if (index == 4) {
              context.push('/profile');
            } else {
              setState(() {
                _selectedBottomNavIndex = index;
              });
            }
            // Index 3 (Notifications) stays on current screen
          },
        ),
      ),
    );
  }
}

// All Notifications Tab - Instagram style
class _AllNotificationsTab extends StatelessWidget {
  final ScrollController scrollController;

  const _AllNotificationsTab({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.notifications.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.accentPrimary,
            ),
          );
        }

        if (provider.error != null && provider.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load notifications',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => provider.refresh(),
                  child: Text(
                    'Retry',
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

        if (provider.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refresh(),
          color: AppColors.accentPrimary,
          child: ListView.separated(
            controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: provider.notifications.length + (provider.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.glassBorder.withOpacity(0.1),
        indent: 68,
      ),
      itemBuilder: (context, index) {
              if (index == provider.notifications.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentPrimary,
                    ),
                  ),
                );
              }
              
              final notification = provider.notifications[index];
        return _NotificationItem(notification: notification);
            },
          ),
        );
      },
    );
  }
}

// Requests Tab
class _RequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final requests = provider.followRequests;

        if (provider.isLoading && requests.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.accentPrimary,
            ),
          );
        }

        if (requests.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No requests',
            style: AppTextStyles.bodyLarge(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refresh(),
          color: AppColors.accentPrimary,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              color: AppColors.glassBorder.withOpacity(0.1),
              indent: 68,
            ),
            itemBuilder: (context, index) {
              final notification = requests[index];
              return _NotificationItem(notification: notification);
            },
          ),
        );
      },
    );
  }
}

// Notification Item - Instagram style (compact, no card)
class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationItem({required this.notification});

  String _getTimeAgo(DateTime dateTime) {
    return app_date.AppDateUtils.timeAgo(dateTime);
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case NotificationType.follow:
      case NotificationType.followBack:
        return Icons.person_add;
      case NotificationType.postLike:
        return Icons.favorite;
      case NotificationType.postComment:
        return Icons.comment;
      case NotificationType.postMention:
        return Icons.alternate_email;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.connectionRequest:
      case NotificationType.connectionAccepted:
        return Icons.group_add;
      case NotificationType.collaborationRequest:
        return Icons.handshake;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final hasButton = notification.isActionable && !notification.actionTaken;
    final hasImage = notification.metadata?['image_url'] != null;

    final provider = Provider.of<NotificationProvider>(context, listen: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!isRead) {
            provider.markAsRead(notification.id);
          }
          // Navigate to action URL if available
          if (notification.actionUrl != null) {
            context.push(notification.actionUrl!);
          }
        },
        onLongPress: () {
          _showNotificationOptions(context, notification, provider);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isRead
              ? Colors.transparent
              : AppColors.backgroundSecondary.withOpacity(0.2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture or Icon
              if (notification.actor?.profilePicture != null)
                ClipOval(
                  child: OptimizedCachedImage(
                    imageUrl: notification.actor!.profilePicture!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                )
              else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    _getNotificationIcon(notification.type),
                  color: AppColors.accentPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          if (notification.actor != null) ...[
                          TextSpan(
                              text: notification.actor!.displayName,
                            style: AppTextStyles.bodyMedium(
                              weight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                              text: ' ',
                              style: AppTextStyles.bodyMedium(),
                            ),
                          ],
                          TextSpan(
                            text: notification.message ?? notification.title,
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: ' ${_getTimeAgo(notification.createdAt)}',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasButton) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                try {
                                  await provider.takeAction(
                                    notification.id,
                                    'accept',
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Request accepted'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed: $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                side: BorderSide(
                                  color: AppColors.accentPrimary,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                notification.type == NotificationType.connectionRequest
                                    ? 'Accept'
                                    : 'Follow Back',
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.accentPrimary,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                try {
                                  await provider.deleteNotification(notification.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Request declined'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed: $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                side: BorderSide(
                                  color: AppColors.textTertiary,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Decline',
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.textSecondary,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: OptimizedCachedImage(
                    imageUrl: notification.metadata!['image_url'] as String,
                  width: 44,
                  height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              if (!isRead && !hasButton) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationOptions(
      BuildContext context, 
      NotificationModel notification,
      NotificationProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _OptionTile(
                icon: Icons.delete,
                title: 'Delete this notification',
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await provider.deleteNotification(notification.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notification deleted')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
              if (notification.actor != null) ...[
              _OptionTile(
                  icon: Icons.person,
                  title: 'View ${notification.actor!.displayName}\'s profile',
                onTap: () {
                  Navigator.pop(context);
                    context.push('/profile/${notification.actor!.username}');
                },
              ),
              _OptionTile(
                icon: Icons.block,
                  title: 'Block ${notification.actor!.displayName}',
                onTap: () {
                  Navigator.pop(context);
                    // TODO: Implement block functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Block feature coming soon')),
                    );
                },
                isDestructive: true,
              ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.accentQuaternary : AppColors.textPrimary,
        size: 24,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium(
          color: isDestructive ? AppColors.accentQuaternary : AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}


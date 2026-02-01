import 'package:flutter/material.dart';
import '../../../../core/utils/app_logger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_side_menu.dart';
import '../../../../core/config/api_config.dart';
import '../../data/providers/feed_provider.dart';
import '../../../notifications/data/providers/notification_provider.dart';
import '../../../messages/data/providers/messages_provider.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../posts/data/models/post.dart';
import '../../../posts/data/models/poll.dart';
import '../../../posts/data/models/article.dart';
import '../../../posts/data/services/posts_service.dart';
import '../../../posts/presentation/widgets/comment_drawer.dart';
import '../../../posts/presentation/widgets/share_drawer.dart';
import '../../../statuses/data/models/status.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedBottomNavIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<_ActivityTagsState> _activityTagsKey = GlobalKey<_ActivityTagsState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh counts when screen becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activityTagsKey.currentState?._loadCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: AppSideMenu(
          onClose: () => _scaffoldKey.currentState?.closeDrawer(),
        ),
        drawerEdgeDragWidth: 0,
        body: SafeArea(
          child: Column(
            children: [
              // Header - Instagram style with transparent overlay
              Consumer2<MessagesProvider, NotificationProvider>(
                builder: (context, messagesProvider, notificationProvider, _) => AppHeader(
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  messageBadge: messagesProvider.totalUnreadCount,
                  onMessageTap: () {
                    context.push('/messages');
                  },
                ),
              ),
              // Feed content
              Expanded(child: _FeedContent(activityTagsKey: _activityTagsKey)),
              // Bottom Navigation - Instagram style with transparent overlay
              // Bottom Navigation - Instagram style with transparent overlay
              Consumer<NotificationProvider>(
                builder: (context, notificationProvider, _) => AppBottomNavigation(
                  selectedIndex: _selectedBottomNavIndex,
                  notificationBadge: notificationProvider.unreadCount,
                  onTap: (index) {
                    if (index == 1) {
                      // Navigate to search screen
                      context.push('/search');
                    } else if (index == 3) {
                      // Navigate to notifications screen
                      context.push('/notifications');
                    } else if (index == 4) {
                      // Navigate to profile screen
                      context.push('/profile');
                    } else {
                      setState(() {
                        _selectedBottomNavIndex = index;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Header and Footer are now universal components in lib/core/widgets/

class _ActivityTags extends StatefulWidget {
  const _ActivityTags({super.key});

  @override
  State<_ActivityTags> createState() => _ActivityTagsState();
}

class _ActivityTagsState extends State<_ActivityTags> {
  final PostsService _postsService = PostsService();
  Map<String, int> _counts = {
    'posts': 0,
    'polls': 0,
    'articles': 0,
    'users': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _postsService.getSinceLastVisitCounts();
    if (response.success && response.data != null) {
      setState(() {
        _counts = response.data!;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToFilteredView(String type) async {
    // Navigate to explore feed with filter
    await context.push('/explore', extra: {'filter': type});
    // Refresh counts when returning from explore
    if (mounted) {
      _loadCounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total count
    final totalCount = _counts.values.fold(0, (sum, count) => sum + count);
    
    // Hide the entire section if all counts are 0 and not loading
    if (!_isLoading && totalCount == 0) {
      return const SizedBox.shrink();
    }

    final tags = [
    {
        'key': 'posts',
      'icon': Icons.photo_library_outlined,
      'label': 'Posts',
      'color': AppColors.accentPrimary,
    },
    {
        'key': 'polls',
      'icon': Icons.bar_chart_rounded,
      'label': 'Polls',
      'color': const Color(0xFF11998E),
    },
    {
        'key': 'articles',
      'icon': Icons.article_outlined,
      'label': 'Articles',
      'color': const Color(0xFFF093FB),
    },
    {
        'key': 'users',
        'icon': Icons.person_add_outlined,
        'label': 'New Users',
      'color': const Color(0xFF38EF7D),
    },
  ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text(
            'Since your last visit',
            style: AppTextStyles.bodySmall(
              color: AppColors.textSecondary,
              weight: FontWeight.w600,
            ).copyWith(fontSize: 11),
          ),
        ),
        SizedBox(
          height: 32,
          child: _isLoading
              ? Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accentPrimary,
                      ),
                    ),
                  ),
                )
              : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              return true;
            },
            child: ListView.builder(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: tags.length,
              itemBuilder: (context, index) {
                      final tag = tags[index];
                      final key = tag['key'] as String;
                      final count = _counts[key] ?? 0;

                return GestureDetector(
                        onTap: () => _navigateToFilteredView(key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: count > 0
                                ? (tag['color'] as Color).withOpacity(0.1)
                                : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                              Icon(
                                tag['icon'] as IconData,
                                size: 11,
                                color: tag['color'] as Color,
                              ),
                        const SizedBox(width: 3),
                        Text(
                                '$count',
                          style: AppTextStyles.bodySmall(
                                  color: tag['color'] as Color,
                            weight: FontWeight.w600,
                          ).copyWith(fontSize: 10),
                        ),
                        const SizedBox(width: 2),
                        Text(
                                tag['label'] as String,
                          style: AppTextStyles.bodySmall(
                            color: AppColors.textSecondary,
                            weight: FontWeight.w400,
                          ).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StoriesBar extends StatefulWidget {
  @override
  State<_StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<_StoriesBar> {
  @override
  void initState() {
    super.initState();
    // Load statuses when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      feedProvider.loadStatuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, child) {
        final statuses = feedProvider.statuses;
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUser = authProvider.currentUser;

        // Build stories list: current user first, then others
        final stories = <Map<String, dynamic>>[];

        // Add "Your Story" first
        final hasMyStory = statuses.any((s) => s.userId == currentUser?.id);
        Status? myStatus;
        if (hasMyStory) {
          try {
            myStatus = statuses.firstWhere((s) => s.userId == currentUser?.id);
          } catch (e) {
            myStatus = null;
          }
        }
        stories.add({
          'name': currentUser?.displayName ?? 'Your Story',
          'username': currentUser?.username ?? '',
          'hasStory': hasMyStory,
          'isYou': true,
          'seen': false,
          'profilePicture': currentUser?.profilePicture,
          'status': myStatus,
        });

        // Group statuses by user (get latest status per user)
        final userStatusMap = <String, Status>{};
        for (final status in statuses) {
          if (status.userId != currentUser?.id) {
            if (!userStatusMap.containsKey(status.userId) ||
                status.createdAt.isAfter(userStatusMap[status.userId]!.createdAt)) {
              userStatusMap[status.userId] = status;
            }
          }
        }

        // Add other users' stories
        for (final status in userStatusMap.values) {
          stories.add({
            'name': status.author?.displayName ?? status.author?.username ?? 'User',
            'username': status.author?.username ?? '',
            'hasStory': true,
            'isYou': false,
            'seen': status.isViewed,
            'profilePicture': status.author?.profilePicture,
            'status': status,
          });
        }

        if (stories.isEmpty) {
          // Show empty state with "Your Story"
          stories.add({
            'name': currentUser?.displayName ?? 'Your Story',
            'username': currentUser?.username ?? '',
            'hasStory': false,
            'isYou': true,
            'seen': false,
            'profilePicture': currentUser?.profilePicture,
          });
        }

        return Container(
          height: 110,
          color: Colors.transparent,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              return true;
            },
            child: ListView.builder(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                final isYou = story['isYou'] as bool;
                final hasStory = story['hasStory'] as bool;
                final seen = story['seen'] as bool;
                final profilePicture = story['profilePicture'] as String?;
                final name = story['name'] as String;

                return GestureDetector(
                  onTap: () {
                    if (isYou && !hasStory) {
                      context.push('/create/story');
                    } else if (isYou && hasStory && story['status'] != null) {
                      final status = story['status'] as Status;
                      context.push('/status/${status.id}');
                    } else {
                      // TODO: Navigate to story viewer for other users
                    }
                  },
                  child: Container(
                    width: 74,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        // Story Circle
                        Stack(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: !isYou && hasStory && !seen
                                    ? LinearGradient(
                                        begin: Alignment.topRight,
                                        end: Alignment.bottomLeft,
                                        colors: [
                                          AppColors.accentPrimary,
                                          AppColors.accentSecondary,
                                          AppColors.accentTertiary,
                                        ],
                                      )
                                    : null,
                                border: seen
                                    ? Border.all(
                                        color: AppColors.glassBorder.withOpacity(0.3),
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 0.1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(2.5),
                                child: profilePicture != null && profilePicture.isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: profilePicture,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: AppColors.backgroundSecondary,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  AppColors.accentPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => _buildInitials(name),
                                        ),
                                      )
                                    : _buildInitials(name),
                              ),
                            ),
                            // Add button for "Your Story"
                            if (isYou && !hasStory)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.accentPrimary,
                                        AppColors.accentSecondary,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.backgroundPrimary,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Name
                        Text(
                          name,
                          style: AppTextStyles.bodySmall(
                            weight: FontWeight.w400,
                          ).copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitials(String name) {
    final initials = name.isNotEmpty
        ? name.substring(0, name.length > 2 ? 2 : name.length).toUpperCase()
        : '?';
    return Container(
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
          initials,
          style: AppTextStyles.bodyMedium(
            color: Colors.white,
            weight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _FeedContent extends StatefulWidget {
  final GlobalKey<_ActivityTagsState> activityTagsKey;

  const _FeedContent({required this.activityTagsKey});

  @override
  State<_FeedContent> createState() => _FeedContentState();
}

class _FeedContentState extends State<_FeedContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load feed when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      feedProvider.loadFeed(refresh: true);
    });

    // Listen for scroll to load more
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        final feedProvider = Provider.of<FeedProvider>(context, listen: false);
        feedProvider.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, child) {
        final posts = feedProvider.posts;
        final isLoading = feedProvider.isLoading;
        final error = feedProvider.error;

        return RefreshIndicator(
          onRefresh: () => feedProvider.refresh(),
          color: AppColors.accentPrimary,
          backgroundColor: AppColors.backgroundSecondary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Stories Bar (scrolls away)
              SliverToBoxAdapter(child: _StoriesBar()),
              // Activity Tags (scrolls away)
              SliverToBoxAdapter(
                child: _ActivityTags(key: widget.activityTagsKey),
              ),
              // Feed Content
              if (isLoading && posts.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accentPrimary,
                        ),
                      ),
                    ),
                  ),
                )
              else if (error != null && posts.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          error,
                          style: AppTextStyles.bodyMedium(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => feedProvider.loadFeed(refresh: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (posts.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.feed_outlined,
                          color: AppColors.textSecondary,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No posts yet',
                          style: AppTextStyles.bodyMedium(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Follow people to see their posts here',
                          style: AppTextStyles.bodySmall(),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == 0) {
                        // Section header
                        return _SectionHeader(title: 'For You');
                      }

                      final postIndex = index - 1;
                      if (postIndex < posts.length) {
                        final post = posts[postIndex];
                        return _buildPostWidget(post, postIndex == 0);
                      } else if (isLoading) {
                        // Loading indicator at the end
                        return Container(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.accentPrimary,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    childCount: posts.length + 1 + (isLoading ? 1 : 0),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostWidget(Post post, bool isFirst) {
    final author = post.author;
    // Improved fallback logic for author name
    String username = 'Unknown';
    if (author != null) {
      if (author.displayName != null && author.displayName!.isNotEmpty) {
        username = author.displayName!;
      } else if (author.username != null && author.username!.isNotEmpty) {
        username = author.username!;
      } else if (author.email != null && author.email!.isNotEmpty) {
        // Extract username from email as fallback
        final emailParts = author.email!.split('@');
        if (emailParts.isNotEmpty && emailParts[0].isNotEmpty) {
          username = emailParts[0];
        }
      }
    }
    final userHandle = author?.username != null && author!.username!.isNotEmpty 
        ? '@${author.username}' 
        : '';
    final profilePictureUrl = author?.profilePicture;
    final timeAgo = app_date_utils.DateUtils.timeAgo(post.publishedAt ?? post.createdAt);
    final hasMedia = post.hasMedia;
    final firstMediaUrl = post.firstMediaUrl;
    final isVideo = post.isVideo;
    
    // Callback to refresh feed after post deletion
    final onPostDeleted = () {
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      feedProvider.loadFeed(refresh: true);
    };
    
    // Add divider before post (except first)
    final widgets = <Widget>[];
    if (!isFirst) {
      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 0.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.glassBorder.withOpacity(0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
      );
    }

    // Build post widget based on type
    if (post.postType == 'poll') {
      if (post.poll != null && post.poll!.options != null && post.poll!.options!.isNotEmpty) {
        // Poll card with options
        widgets.add(_PollCard(
          username: username,
          userHandle: userHandle,
          profilePictureUrl: profilePictureUrl,
          userId: post.userId,
          timeAgo: timeAgo,
          poll: post.poll!,
          likes: post.likesCount,
          comments: post.commentsCount,
          shares: post.sharesCount,
          isLiked: post.isLiked,
          isSaved: post.isSaved,
          postId: post.id,
          onPostDeleted: onPostDeleted,
        ));
      } else {
        // Fallback to regular post card if poll data is missing
      widgets.add(_PostCard(
        username: username,
        userHandle: userHandle,
          profilePictureUrl: profilePictureUrl,
          userId: post.userId,
        timeAgo: timeAgo,
        content: post.content,
        imageUrl: hasMedia ? firstMediaUrl : null,
        likes: post.likesCount,
        comments: post.commentsCount,
        shares: post.sharesCount,
        isLiked: post.isLiked,
        isSaved: post.isSaved,
        postId: post.id,
        onPostDeleted: onPostDeleted,
      ));
      }
    } else if (post.postType == 'article') {
      if (post.article != null) {
        // Article card with full article data
        widgets.add(_ArticleCard(
          username: username,
          userHandle: userHandle,
          profilePictureUrl: profilePictureUrl,
          userId: post.userId,
          timeAgo: timeAgo,
          article: post.article!,
          likes: post.likesCount,
          comments: post.commentsCount,
          shares: post.sharesCount,
          isLiked: post.isLiked,
          isSaved: post.isSaved,
          postId: post.id,
          onPostDeleted: onPostDeleted,
        ));
      } else {
        // Fallback to regular post card if article data is missing
      widgets.add(_PostCard(
        username: username,
        userHandle: userHandle,
          profilePictureUrl: profilePictureUrl,
          userId: post.userId,
        timeAgo: timeAgo,
        content: post.content,
        imageUrl: hasMedia ? firstMediaUrl : null,
        likes: post.likesCount,
        comments: post.commentsCount,
        shares: post.sharesCount,
        isLiked: post.isLiked,
        isSaved: post.isSaved,
        postId: post.id,
        onPostDeleted: onPostDeleted,
      ));
      }
    } else if (isVideo && hasMedia) {
      // Reel/Video card
      widgets.add(_ReelCard(
        username: username,
        userHandle: userHandle,
        caption: post.content,
        views: _formatCount(post.viewsCount),
        likes: _formatCount(post.likesCount),
      ));
    } else {
      // Regular post card
      widgets.add(_PostCard(
        username: username,
        userHandle: userHandle,
        profilePictureUrl: profilePictureUrl,
        userId: post.userId,
        timeAgo: timeAgo,
        content: post.content,
        imageUrl: hasMedia ? firstMediaUrl : null,
        likes: post.likesCount,
        comments: post.commentsCount,
        shares: post.sharesCount,
        isLiked: post.isLiked,
        isSaved: post.isSaved,
        postId: post.id,
        onPostDeleted: onPostDeleted,
      ));
    }

    return Column(children: widgets);
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _SectionHeader({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.accentPrimary),
            const SizedBox(width: 8),
          ],
          Text(title, style: AppTextStyles.bodyLarge(weight: FontWeight.bold)),
          const Spacer(),
          Text(
            'See All',
            style: AppTextStyles.bodySmall(
              color: AppColors.accentPrimary,
              weight: FontWeight.w600,
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: AppColors.accentPrimary),
        ],
      ),
    );
  }
}

// Post Card
class _PostCard extends StatefulWidget {
  final String username;
  final String userHandle;
  final String? profilePictureUrl;
  final String userId;
  final String timeAgo;
  final String content;
  final String? imageUrl;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final bool isSaved;
  final String postId;
  final VoidCallback? onPostDeleted;

  const _PostCard({
    required this.username,
    required this.userHandle,
    this.profilePictureUrl,
    required this.userId,
    required this.timeAgo,
    required this.content,
    this.imageUrl,
    required this.likes,
    required this.comments,
    required this.shares,
    this.isLiked = false,
    this.isSaved = false,
    required this.postId,
    this.onPostDeleted,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late bool _isLiked;
  late bool _isSaved;
  late int _likeCount;
  final PostsService _postsService = PostsService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _isSaved = widget.isSaved;
    _likeCount = widget.likes;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final response = wasLiked
          ? await _postsService.unlikePost(widget.postId)
          : await _postsService.likePost(widget.postId);

      if (!response.success) {
        // Revert on error
        setState(() {
          _isLiked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
    }
  }

  Future<void> _toggleSave() async {
    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !_isSaved;
    });

    try {
      final response = wasSaved
          ? await _postsService.unsavePost(widget.postId)
          : await _postsService.savePost(widget.postId);

      if (!response.success) {
        // Revert on error
        setState(() {
          _isSaved = wasSaved;
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isSaved = wasSaved;
      });
    }
  }

  void _openShareDrawer() {
    // We need the full post object, but we only have postId
    // For now, we'll show the drawer and it will handle the share
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Create a minimal post object for the drawer
        // In a real scenario, you'd pass the full post object
        final post = Post(
          id: widget.postId,
          userId: widget.userId,
          postType: 'post',
          content: widget.content,
          visibility: 'public',
          allowsComments: true,
          allowsSharing: true,
          isPublished: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        return ShareDrawer(post: post);
      },
    );
  }

  void _openCommentDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentDrawer(
        postId: widget.postId,
        postAuthorId: widget.userId,
        initialCommentCount: widget.comments,
      ),
    );
  }

  void _navigateToProfile() {
    // TODO: Navigate to profile page
    // Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: widget.userId)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: widget.profilePictureUrl != null && widget.profilePictureUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: widget.profilePictureUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                  width: 40,
                  height: 40,
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
                                  widget.username.isNotEmpty ? widget.username.substring(0, 1).toUpperCase() : '?',
                      style: AppTextStyles.bodyMedium(
                        color: Colors.white,
                        weight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 40,
                              height: 40,
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
                                  widget.username.isNotEmpty ? widget.username.substring(0, 1).toUpperCase() : '?',
                                  style: AppTextStyles.bodyMedium(
                                    color: Colors.white,
                                    weight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: 40,
                          height: 40,
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
                              widget.username.isNotEmpty ? widget.username.substring(0, 1).toUpperCase() : '?',
                              style: AppTextStyles.bodyMedium(
                                color: Colors.white,
                                weight: FontWeight.bold,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _navigateToProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.username,
                        style: AppTextStyles.bodyMedium(
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${widget.userHandle} • ${widget.timeAgo}',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
                _PostOptionsMenu(
                  postId: widget.postId,
                  postUserId: widget.userId,
                  onPostDeleted: widget.onPostDeleted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(widget.content, style: AppTextStyles.bodyMedium()),
          ),

          // Image (if exists)
          if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Use AspectRatio to maintain image proportions
            AspectRatio(
              aspectRatio: 1.0, // Square by default, will adjust based on image
              child: Container(
                width: double.infinity,
                color: AppColors.backgroundSecondary,
                child: Builder(
                  builder: (context) {
                    String imageUrl = widget.imageUrl!;
                    
                    // If URL doesn't start with http/https, construct full Supabase Storage URL
                    if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
                      // The backend is returning relative paths like "media/posts/..."
                      // Construct the full Supabase Storage public URL
                      imageUrl = ApiConfig.constructSupabaseStorageUrl(imageUrl);
                      
                      // If still not a full URL, try to fetch storage URL again (might not have been fetched on startup)
                      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
                        // Trigger async fetch (won't block, but will cache for next time)
                        ApiConfig.fetchStorageUrl().then((_) {
                          // If fetch succeeds, rebuild to try again
                          if (mounted) {
                            setState(() {});
                          }
                        });
                        
                        // Show placeholder while we try to fetch the URL
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accentPrimary.withOpacity(0.3),
                                AppColors.accentSecondary.withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.accentPrimary,
                              ),
                            ),
                          ),
                        );
                      }
                    }
                    
                    return CachedNetworkImage(
                      imageUrl: imageUrl,
                  fit: BoxFit.cover, // Cover the entire container
                  memCacheWidth: 1080, // Limit memory cache to 1080px width
                  memCacheHeight: 1080, // Limit memory cache to 1080px height
                  maxWidthDiskCache: 1080, // Limit disk cache to 1080px width
                  maxHeightDiskCache: 1080, // Limit disk cache to 1080px height
                  httpHeaders: const {
                    'Accept': 'image/*',
                  },
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentPrimary.withOpacity(0.3),
                          AppColors.accentSecondary.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accentPrimary,
                        ),
                      ),
                    ),
                  ),
                errorWidget: (context, url, error) {
                  return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentPrimary.withOpacity(0.3),
                            AppColors.accentSecondary.withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: AppTextStyles.bodySmall(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                url.length > 60 ? '${url.substring(0, 60)}...' : url,
                                style: AppTextStyles.bodySmall(
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                    );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Interaction Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                _InteractionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  label: _formatCount(_likeCount),
                  color: _isLiked
                      ? AppColors.accentQuaternary
                      : AppColors.textSecondary,
                  onTap: _toggleLike,
                ),
                const SizedBox(width: 20),
                _InteractionButton(
                  icon: Icons.comment_outlined,
                  label: _formatCount(widget.comments),
                  color: AppColors.textSecondary,
                  onTap: _openCommentDrawer,
                ),
                const SizedBox(width: 20),
                _InteractionButton(
                  icon: Icons.share_outlined,
                  label: _formatCount(widget.shares),
                  color: AppColors.textSecondary,
                  onTap: _openShareDrawer,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleSave,
                  child: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: _isSaved
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall(
              color: color,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Article Card
class _ArticleCard extends StatefulWidget {
  final String username;
  final String userHandle;
  final String? profilePictureUrl;
  final String userId;
  final String timeAgo;
  final Article article;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final bool isSaved;
  final String postId;
  final VoidCallback? onPostDeleted;

  const _ArticleCard({
    required this.username,
    required this.userHandle,
    this.profilePictureUrl,
    required this.userId,
    required this.timeAgo,
    required this.article,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isLiked,
    required this.isSaved,
    required this.postId,
    this.onPostDeleted,
  });

  @override
  State<_ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<_ArticleCard> {
  late bool _isLiked;
  late bool _isSaved;
  late int _likes;
  final PostsService _postsService = PostsService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _isSaved = widget.isSaved;
    _likes = widget.likes;
  }

  String _stripHtmlTags(String html) {
    // Simple HTML tag stripper
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  void _navigateToProfile() {
    context.push('/profile/${widget.userId}');
  }

  void _openArticleViewer() async {
    await context.push(
      '/article/${widget.article.id}',
      extra: widget.article,
    );
    // Refresh counts when returning from article viewer
    // The article viewer updates last_used_at, so counts should refresh
    if (mounted) {
      // Trigger refresh via parent widget's key
      final homeState = context.findAncestorStateOfType<_HomeScreenState>();
      homeState?._activityTagsKey.currentState?._loadCounts();
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        await _postsService.likePost(widget.postId);
      } else {
        await _postsService.unlikePost(widget.postId);
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !_isLiked;
        _likes += _isLiked ? 1 : -1;
      });
    }
  }

  Future<void> _toggleSave() async {
    setState(() {
      _isSaved = !_isSaved;
    });

    try {
      if (_isSaved) {
        await _postsService.savePost(widget.postId);
      } else {
        await _postsService.unsavePost(widget.postId);
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isSaved = !_isSaved;
      });
    }
  }

  void _openCommentDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentDrawer(
        postId: widget.postId,
        postAuthorId: widget.userId,
        initialCommentCount: widget.comments,
      ),
    );
  }

  void _openShareDrawer() {
    // Create a minimal post object for the drawer
    final post = Post(
      id: widget.postId,
      userId: widget.userId,
      postType: 'article',
      content: widget.article.title,
      visibility: 'public',
      allowsComments: true,
      allowsSharing: true,
      isPublished: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mediaUrls: widget.article.coverImageUrl != null
          ? [widget.article.coverImageUrl!]
          : null,
      article: widget.article,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareDrawer(post: post),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final previewText = _stripHtmlTags(widget.article.contentHtml);
    final previewTextShort = previewText.length > 150
        ? '${previewText.substring(0, 150)}...'
        : previewText;

    return GestureDetector(
      onTap: _openArticleViewer,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.glassBorder.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Header with profile picture and username
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                  GestureDetector(
                    onTap: _navigateToProfile,
                    child: _buildProfilePicture(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        GestureDetector(
                          onTap: _navigateToProfile,
                          child: Text(
                        widget.username,
                        style: AppTextStyles.bodyMedium(
                          weight: FontWeight.w600,
                        ),
                      ),
                        ),
                        const SizedBox(height: 2),
                      Text(
                          widget.timeAgo,
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _PostOptionsMenu(
                  postId: widget.postId,
                  postUserId: widget.userId,
                  onPostDeleted: widget.onPostDeleted,
                ),
              ],
            ),
          ),

            // Cover image (only if exists)
            if (widget.article.coverImageUrl != null &&
                widget.article.coverImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.article.coverImageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: AppColors.backgroundSecondary.withOpacity(0.3),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),

            // Article content
          Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                widget.article.coverImageUrl != null &&
                        widget.article.coverImageUrl!.isNotEmpty
                    ? 16
                    : 0,
                16,
                16,
              ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  if (widget.article.category != null)
                    Container(
                    margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    decoration: BoxDecoration(
                        color: AppColors.textTertiary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.textTertiary.withOpacity(0.2),
                          width: 0.5,
                      ),
                    ),
                      child: Text(
                        widget.article.category!,
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Title
                        Text(
                    widget.article.title,
                    style: AppTextStyles.headlineSmall(
                      weight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                          ),

                  // Subtitle
                  if (widget.article.subtitle != null &&
                      widget.article.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                        Text(
                      widget.article.subtitle!,
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Preview text
                  Text(
                    previewTextShort,
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textSecondary,
                    ).copyWith(height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Read time and views
                  Row(
              children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                Text(
                        '${widget.article.readTimeMinutes} min read',
                  style: AppTextStyles.bodySmall(
                          color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                      Icon(
                        Icons.visibility_outlined,
                        size: 12,
                    color: AppColors.textTertiary,
                  ),
                      const SizedBox(width: 4),
                Text(
                        _formatCount(widget.article.viewsCount),
                  style: AppTextStyles.bodySmall(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Interaction buttons
                  Row(
                    children: [
                      _InteractionButton(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        label: _formatCount(_likes),
                        color: _isLiked
                            ? AppColors.accentPrimary
                            : AppColors.textSecondary,
                        onTap: _toggleLike,
                      ),
                      const SizedBox(width: 20),
                      _InteractionButton(
                        icon: Icons.comment_outlined,
                        label: _formatCount(widget.comments),
                    color: AppColors.textSecondary,
                        onTap: _openCommentDrawer,
                      ),
                      const SizedBox(width: 20),
                      _InteractionButton(
                        icon: Icons.share_outlined,
                        label: _formatCount(widget.shares),
                        color: AppColors.textSecondary,
                        onTap: _openShareDrawer,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _toggleSave,
                        child: Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: _isSaved
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                          size: 22,
                  ),
                ),
              ],
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    if (widget.profilePictureUrl != null && widget.profilePictureUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget.profilePictureUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentPrimary,
                  AppColors.accentSecondary,
                ],
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentPrimary,
                  AppColors.accentSecondary,
                ],
              ),
            ),
            child: Center(
              child: Text(
                widget.username.isNotEmpty ? widget.username[0].toUpperCase() : 'U',
                style: AppTextStyles.bodyMedium(
                  color: Colors.white,
                  weight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentPrimary,
            AppColors.accentSecondary,
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.username.isNotEmpty ? widget.username[0].toUpperCase() : 'U',
          style: AppTextStyles.bodyMedium(
            color: Colors.white,
            weight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// Poll Card
class _PollCard extends StatefulWidget {
  final String username;
  final String userHandle;
  final String? profilePictureUrl;
  final String userId;
  final String timeAgo;
  final Poll poll;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final bool isSaved;
  final String postId;
  final VoidCallback? onPostDeleted;

  const _PollCard({
    required this.username,
    required this.userHandle,
    this.profilePictureUrl,
    required this.userId,
    required this.timeAgo,
    required this.poll,
    required this.likes,
    required this.comments,
    required this.shares,
    this.isLiked = false,
    this.isSaved = false,
    required this.postId,
    this.onPostDeleted,
  });

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  late Poll _poll;
  final PostsService _postsService = PostsService();
  bool _isVoting = false;
  late bool _isLiked;
  late bool _isSaved;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _poll = widget.poll;
    _isLiked = widget.isLiked;
    _isSaved = widget.isSaved;
    _likeCount = widget.likes;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final response = wasLiked
          ? await _postsService.unlikePost(widget.postId)
          : await _postsService.likePost(widget.postId);

      if (!response.success) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
      }
    } catch (e) {
      setState(() {
        _isLiked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
    }
  }

  Future<void> _toggleSave() async {
    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !_isSaved;
    });

    try {
      final response = wasSaved
          ? await _postsService.unsavePost(widget.postId)
          : await _postsService.savePost(widget.postId);

      if (!response.success) {
        setState(() {
          _isSaved = wasSaved;
        });
      }
    } catch (e) {
      setState(() {
        _isSaved = wasSaved;
      });
    }
  }

  void _openShareDrawer() {
    // We need the full post object for the share drawer
    // For now, create a minimal post object
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final post = Post(
          id: widget.postId,
          userId: widget.userId,
          postType: 'poll',
          content: _poll.question,
          visibility: 'public',
          allowsComments: true,
          allowsSharing: true,
          isPublished: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          poll: _poll,
        );
        return ShareDrawer(post: post);
      },
    );
  }

  void _openCommentDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentDrawer(
        postId: widget.postId,
        postAuthorId: widget.userId,
        initialCommentCount: widget.comments,
      ),
    );
  }

  void _navigateToProfile() {
    // TODO: Navigate to profile page
  }

  Future<void> _voteOnOption(String optionId) async {
    if (_isVoting || _poll.userVote != null) return;

    setState(() {
      _isVoting = true;
    });

    try {
      final response = await _postsService.votePoll(widget.postId, optionId);
      if (response.success && response.data != null) {
        // Parse the results and update poll
        final results = response.data!;
        final pollData = results['poll'] as Map<String, dynamic>?;
        if (pollData != null) {
          // Update poll with new data
          final updatedPoll = Poll.fromJson(pollData);
          
          // Update options with results (options array contains PollOptionResult with percentages)
          final optionsData = results['options'] as List<dynamic>?;
          if (optionsData != null) {
            final updatedOptions = optionsData.map((opt) {
              final optMap = opt as Map<String, dynamic>;
              // Convert PollOptionResult to PollOption (we only need the vote counts)
              return PollOption(
                id: optMap['id'] as String,
                pollId: optMap['poll_id'] as String? ?? updatedPoll.id,
                optionText: optMap['option_text'] as String,
                optionIndex: optMap['option_index'] as int,
                votesCount: optMap['votes_count'] as int? ?? 0,
              );
            }).toList();
            
            // Create updated poll with new options and vote counts
            final pollWithOptions = Poll(
              id: updatedPoll.id,
              postId: updatedPoll.postId,
              question: updatedPoll.question,
              durationHours: updatedPoll.durationHours,
              allowMultipleVotes: updatedPoll.allowMultipleVotes,
              showResultsBeforeVote: updatedPoll.showResultsBeforeVote,
              allowVoteChanges: updatedPoll.allowVoteChanges,
              anonymousVotes: updatedPoll.anonymousVotes,
              isClosed: updatedPoll.isClosed,
              closedAt: updatedPoll.closedAt,
              endsAt: updatedPoll.endsAt,
              totalVotes: results['total_votes'] as int? ?? updatedPoll.totalVotes,
              createdAt: updatedPoll.createdAt,
              options: updatedOptions,
              userVote: results['user_vote_id'] != null ? (results['user_vote_id'] as String) : null,
            );
            
            setState(() {
              _poll = pollWithOptions;
            });
          } else {
            // If no options in results, just update the poll with user vote
            final pollWithVote = Poll(
              id: updatedPoll.id,
              postId: updatedPoll.postId,
              question: updatedPoll.question,
              durationHours: updatedPoll.durationHours,
              allowMultipleVotes: updatedPoll.allowMultipleVotes,
              showResultsBeforeVote: updatedPoll.showResultsBeforeVote,
              allowVoteChanges: updatedPoll.allowVoteChanges,
              anonymousVotes: updatedPoll.anonymousVotes,
              isClosed: updatedPoll.isClosed,
              closedAt: updatedPoll.closedAt,
              endsAt: updatedPoll.endsAt,
              totalVotes: results['total_votes'] as int? ?? updatedPoll.totalVotes,
              createdAt: updatedPoll.createdAt,
              options: _poll.options, // Keep existing options
              userVote: results['user_vote_id'] != null ? (results['user_vote_id'] as String) : null,
            );
            
            setState(() {
              _poll = pollWithVote;
            });
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'Failed to vote'),
            backgroundColor: AppColors.accentQuaternary,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.accentQuaternary,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVoted = _poll.userVote != null;
    final showResults = hasVoted || _poll.showResultsBeforeVote || _poll.hasEnded;
    final options = _poll.options ?? [];
    final totalVotes = _poll.totalVotes;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
      decoration: BoxDecoration(
          color: AppColors.backgroundSecondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.glassBorder.withOpacity(0.2),
            width: 1,
          ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
                  GestureDetector(
                    onTap: _navigateToProfile,
                    child: widget.profilePictureUrl != null && widget.profilePictureUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: widget.profilePictureUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                  width: 40,
                  height: 40,
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
                                    widget.username.isNotEmpty ? widget.username.substring(0, 1).toUpperCase() : '?',
                      style: AppTextStyles.bodyMedium(
                  color: Colors.white,
                        weight: FontWeight.bold,
                ),
              ),
            ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 40,
                                height: 40,
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
                                    widget.username.isNotEmpty ? widget.username.substring(0, 1).toUpperCase() : '?',
                                    style: AppTextStyles.bodyMedium(
                                      color: Colors.white,
                                      weight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
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
                                widget.username.isNotEmpty ? widget.username.substring(0, 1).toUpperCase() : '?',
                                style: AppTextStyles.bodyMedium(
                                  color: Colors.white,
                                  weight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
            Expanded(
                    child: GestureDetector(
                      onTap: _navigateToProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Text(
                        widget.username,
                        style: AppTextStyles.bodyMedium(
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${widget.userHandle} • ${widget.timeAgo}',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                      ),
                  ),
                ),
                _PostOptionsMenu(
                  postId: widget.postId,
                  postUserId: widget.userId,
                  onPostDeleted: widget.onPostDeleted,
                ),
              ],
            ),
          ),
          // Poll Question
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                _poll.question,
                style: AppTextStyles.bodyLarge(
                  weight: FontWeight.w600,
                  ),
                ),
            ),
          // Poll Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                children: (() {
                  final sortedOptions = List<PollOption>.from(options)..sort((a, b) => a.optionIndex.compareTo(b.optionIndex));
                  return sortedOptions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = _poll.userVote == option.id;
                  final percentage = totalVotes > 0 ? (option.votesCount / totalVotes) * 100 : 0.0;

                  return Padding(
                    padding: EdgeInsets.only(bottom: index < sortedOptions.length - 1 ? 8 : 0),
                    child: GestureDetector(
                      onTap: hasVoted || _poll.hasEnded ? null : () => _voteOnOption(option.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentPrimary.withOpacity(0.15)
                              : AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentPrimary
                                : AppColors.glassBorder.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                        child: Stack(
                          children: [
                            // Percentage bar
                            if (showResults)
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.accentPrimary.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                              ),
                            // Option content
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                                  Expanded(
                    child: Text(
                                      option.optionText,
                          style: AppTextStyles.bodyMedium(
                                        weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                        color: isSelected ? AppColors.accentPrimary : AppColors.textPrimary,
                          ),
                        ),
                                  ),
                                  if (showResults) ...[
                                    const SizedBox(width: 8),
                        Text(
                                      '${percentage.toStringAsFixed(0)}%',
                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textSecondary,
                        weight: FontWeight.w600,
                    ),
                  ),
                                    const SizedBox(width: 4),
                  Text(
                                      '(${option.votesCount})',
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: AppColors.accentPrimary,
                                        size: 20,
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
                }).toList();
                })(),
                  ),
          ),
            // Poll Footer
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                  if (!_poll.hasEnded && _poll.timeRemaining != null)
                  Row(
                    children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                      Text(
                          _formatTimeRemaining(_poll.timeRemaining!),
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      ],
                      ),
                  const Spacer(),
                      Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
            ),
          ),
            // Actions (same as PostCard)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _ActionButton(
                    icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                    label: _formatCount(_likeCount),
                    color: _isLiked ? AppColors.accentQuaternary : AppColors.textSecondary,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 24),
                  _ActionButton(
                    icon: Icons.comment_outlined,
                    label: _formatCount(widget.comments),
                    color: AppColors.textSecondary,
                    onTap: _openCommentDrawer,
                  ),
                  const SizedBox(width: 24),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: _formatCount(widget.shares),
                    color: AppColors.textSecondary,
                    onTap: _openShareDrawer,
                  ),
                  const Spacer(),
                  _ActionButton(
                    icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    label: '',
                    color: _isSaved ? AppColors.accentPrimary : AppColors.textSecondary,
                    onTap: _toggleSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d left';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h left';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m left';
    } else {
      return 'Ending soon';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
        child: Row(
          children: [
          Icon(icon, size: 20, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
                  Text(
              label,
              style: AppTextStyles.bodySmall(color: color),
                      ),
                    ],
                ],
      ),
    );
  }
}

// Reel Card
class _ReelCard extends StatelessWidget {
  final String username;
  final String userHandle;
  final String caption;
  final String views;
  final String likes;

  const _ReelCard({
    required this.username,
    required this.userHandle,
    required this.caption,
    required this.views,
    required this.likes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 550,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentPrimary.withOpacity(0.5),
            AppColors.accentSecondary.withOpacity(0.7),
            AppColors.accentTertiary.withOpacity(0.5),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Play Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, size: 56, color: Colors.white),
            ),
          ),

          // Views count overlay (top right)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    views,
                    style: AppTextStyles.bodySmall(
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Info
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
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
                            username.substring(0, 1),
                            style: AppTextStyles.bodySmall(
                              color: Colors.white,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        username,
                        style: AppTextStyles.bodyMedium(
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caption,
                    style: AppTextStyles.bodySmall(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '$likes likes',
                        style: AppTextStyles.bodySmall(
                          color: Colors.white,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Job Card
class _JobCard extends StatelessWidget {
  final String company;
  final String position;
  final String location;
  final String salary;

  const _JobCard({
    required this.company,
    required this.position,
    required this.location,
    required this.salary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667EEA).withOpacity(0.2),
            const Color(0xFF764BA2).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF667EEA).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  color: const Color(0xFF667EEA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position,
                      style: AppTextStyles.bodyLarge(weight: FontWeight.w600),
                    ),
                    Text(
                      company,
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _JobChip(icon: Icons.location_on_outlined, text: location),
              _JobChip(icon: Icons.attach_money, text: salary),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'View Job',
                style: AppTextStyles.bodyMedium(
                  color: Colors.white,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _JobChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// Post Options Menu Widget
class _PostOptionsMenu extends StatefulWidget {
  final String postId;
  final String postUserId;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onPostRestricted;

  const _PostOptionsMenu({
    required this.postId,
    required this.postUserId,
    this.onPostDeleted,
    this.onPostRestricted,
  });

  @override
  State<_PostOptionsMenu> createState() => _PostOptionsMenuState();
}

class _PostOptionsMenuState extends State<_PostOptionsMenu> {
  void _showOptionsMenu() {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final isOwnPost = currentUser?.id == widget.postUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
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
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (isOwnPost)
                _OptionTile(
                  icon: Icons.delete_outline,
                  title: 'Delete',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showDeleteConfirmation();
                  },
                )
              else
                _OptionTile(
                  icon: Icons.block,
                  title: 'Restrict',
                  color: AppColors.textPrimary,
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _restrictPost();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    AppLogger.debug('[PostOptionsMenu] Showing delete confirmation dialog for post: ${widget.postId}');
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        AppLogger.debug('[PostOptionsMenu] Delete dialog shown');
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: Text(
            'Delete Post',
            style: AppTextStyles.headlineSmall(),
          ),
          content: Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
            style: AppTextStyles.bodyMedium(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppLogger.debug('[PostOptionsMenu] Delete cancelled');
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                AppLogger.debug('[PostOptionsMenu] Delete confirmed, closing dialog and calling _deletePost');
                Navigator.pop(dialogContext);
                // Call delete immediately after closing dialog
                // Use WidgetsBinding to ensure we're in the right frame
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _deletePost();
                  } else {
                    AppLogger.debug('[PostOptionsMenu] Widget no longer mounted, cannot delete');
                  }
                });
              },
              child: Text(
                'Delete',
                style: AppTextStyles.bodyMedium(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost() async {
    if (!mounted) return;
    
    AppLogger.debug('[PostOptionsMenu] Starting delete for post: ${widget.postId}');
    final postsService = PostsService();
    
    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    AppLogger.debug('[PostOptionsMenu] Calling deletePost API...');
    final response = await postsService.deletePost(widget.postId);
    AppLogger.debug('[PostOptionsMenu] Delete response received: success=${response.success}, error=${response.error}');

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (response.success) {
        AppLogger.debug('[PostOptionsMenu] Post deleted successfully, refreshing feed...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onPostDeleted?.call();
      } else {
        AppLogger.debug('[PostOptionsMenu] Delete failed: ${response.error}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'Failed to delete post'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _restrictPost() async {
    if (!mounted) return;
    
    final postsService = PostsService();
    
    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final response = await postsService.restrictPost(widget.postId);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post restricted. You won\'t see it in your feed.'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onPostRestricted?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'Failed to restrict post'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showOptionsMenu,
      child: Icon(
        Icons.more_horiz,
        color: AppColors.textSecondary,
        size: 24,
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium(color: color),
      ),
      onTap: onTap,
    );
  }
}

// Header, Footer, and Side Menu are now universal components in lib/core/widgets/

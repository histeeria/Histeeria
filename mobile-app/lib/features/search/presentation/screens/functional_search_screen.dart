import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../data/services/search_service.dart';
import '../../../posts/data/models/post.dart';
import '../../data/models/search_user.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/api/api_client.dart';

class FunctionalSearchScreen extends StatefulWidget {
  const FunctionalSearchScreen({super.key});

  @override
  State<FunctionalSearchScreen> createState() => _FunctionalSearchScreenState();
}

class _FunctionalSearchScreenState extends State<FunctionalSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  
  int _selectedBottomNavIndex = 1; // Search is selected
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';
  
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Removed Communities
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
        });
      }
    });
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
              AppHeader(
                onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                messageBadge: 0,
                onMessageTap: () {
                  context.push('/messages');
                },
              ),
              // Search Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: AppTextStyles.bodyLarge(),
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search users, posts...',
                          hintStyle: AppTextStyles.bodyLarge(
                            color: AppColors.textTertiary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  child: Icon(
                                    Icons.clear,
                                    color: AppColors.textSecondary,
                                    size: 22,
                                  ),
                                )
                              : null,
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tab Bar
              Container(
                height: 44,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTextStyles.bodySmall(weight: FontWeight.w600),
                  unselectedLabelStyle: AppTextStyles.bodySmall(),
                  indicator: BoxDecoration(
                    color: AppColors.backgroundPrimary.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Users'),
                    Tab(text: 'Posts'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tab Content
              Expanded(
                child: _searchQuery.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Start searching',
                              style: AppTextStyles.bodyLarge(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        children: [
                          _AllResultsTab(searchQuery: _searchQuery, searchService: _searchService),
                          _UsersTab(searchQuery: _searchQuery, searchService: _searchService),
                          _PostsTab(searchQuery: _searchQuery, searchService: _searchService),
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
            } else if (index == 3) {
              context.push('/notifications');
            } else if (index == 4) {
              context.push('/profile');
            }
          },
        ),
      ),
    );
  }
}

// All Results Tab
class _AllResultsTab extends StatelessWidget {
  final String searchQuery;
  final SearchService searchService;

  const _AllResultsTab({required this.searchQuery, required this.searchService});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SectionHeader(title: 'Users'),
        _UsersSection(searchQuery: searchQuery, searchService: searchService, limit: 3),
        const SizedBox(height: 16),
        _SectionHeader(title: 'Posts'),
        _PostsSection(searchQuery: searchQuery, searchService: searchService, limit: 5),
      ],
    );
  }
}

// Users Tab
class _UsersTab extends StatelessWidget {
  final String searchQuery;
  final SearchService searchService;

  const _UsersTab({required this.searchQuery, required this.searchService});

  @override
  Widget build(BuildContext context) {
    return _UsersSection(searchQuery: searchQuery, searchService: searchService);
  }
}

// Posts Tab
class _PostsTab extends StatelessWidget {
  final String searchQuery;
  final SearchService searchService;

  const _PostsTab({required this.searchQuery, required this.searchService});

  @override
  Widget build(BuildContext context) {
    return _PostsSection(searchQuery: searchQuery, searchService: searchService);
  }
}

// Users Section (Future Builder)
class _UsersSection extends StatelessWidget {
  final String searchQuery;
  final SearchService searchService;
  final int? limit;

  const _UsersSection({
    required this.searchQuery,
    required this.searchService,
    this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: searchService.searchUsers(searchQuery, limit: limit ?? 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          final errorMsg = snapshot.error.toString().replaceAll('Exception: ', '');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMsg,
                    style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data;
        if (response == null || response.users.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_search,
                    size: 64,
                    color: AppColors.textTertiary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.textSecondary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try searching with different keywords',
                    style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final users = limit != null && response.users.length > limit!
            ? response.users.take(limit!).toList()
            : response.users;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            return _UserResultItem(user: users[index]);
          },
        );
      },
    );
  }
}

// Posts Section (Future Builder)
class _PostsSection extends StatelessWidget {
  final String searchQuery;
  final SearchService searchService;
  final int? limit;

  const _PostsSection({
    required this.searchQuery,
    required this.searchService,
    this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: searchService.searchPosts(searchQuery, limit: limit ?? 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          final errorMsg = snapshot.error.toString().replaceAll('Exception: ', '');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMsg,
                    style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data;
        if (response == null || response.posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: AppColors.textTertiary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No posts found',
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.textSecondary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try searching with different keywords',
                    style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final posts = limit != null && response.posts.length > limit!
            ? response.posts.take(limit!).toList()
            : response.posts;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return _PostResultItem(post: posts[index]);
          },
        );
      },
    );
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.bodyLarge(weight: FontWeight.w600),
      ),
    );
  }
}

// User Result Item
class _UserResultItem extends StatefulWidget {
  final SearchUser user;

  const _UserResultItem({required this.user});

  @override
  State<_UserResultItem> createState() => _UserResultItemState();
}

class _UserResultItemState extends State<_UserResultItem> {
  bool _isFollowing = false;
  bool _isLoading = false;

  Future<void> _toggleFollow() async {
    setState(() => _isLoading = true);
    
    try {
      final apiClient = ApiClient();
      if (_isFollowing) {
        // Unfollow
        await apiClient.delete('/relationships/follow/${widget.user.id}');
      } else {
        // Follow
        await apiClient.post('/relationships/follow/${widget.user.id}');
      }
      
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isFollowing ? "unfollow" : "follow"} user'),
            backgroundColor: AppColors.accentQuaternary,
          ),
        );
      }
    }
  }

  void _startConversation() {
    // Navigate to chat screen with this user
    context.push('/chat/${widget.user.id}');
  }

  @override
  Widget build(BuildContext context) {
    final String profileImageUrl = widget.user.profilePicture != null &&
            widget.user.profilePicture!.isNotEmpty
        ? '${ApiConfig.supabaseStorageUrl}${widget.user.profilePicture}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/profile/${widget.user.username}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Profile Picture
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withOpacity(0.2),
                  shape: BoxShape.circle,
                  image: profileImageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(profileImageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profileImageUrl.isEmpty
                    ? Icon(Icons.person, color: AppColors.accentPrimary, size: 28)
                    : null,
              ),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.user.displayName ?? widget.user.username,
                            style: AppTextStyles.bodyMedium(weight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.user.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified, color: AppColors.success, size: 16),
                        ],
                      ],
                    ),
                    Text(
                      '@${widget.user.username}',
                      style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                    ),
                    if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.user.bio!,
                        style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Action Buttons
              Column(
                children: [
                  // Follow/Unfollow Button
                  SizedBox(
                    width: 80,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing
                            ? AppColors.backgroundTertiary
                            : AppColors.accentPrimary,
                        foregroundColor: _isFollowing
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textPrimary,
                                ),
                              ),
                            )
                          : Text(
                              _isFollowing ? 'Following' : 'Follow',
                              style: AppTextStyles.bodySmall(
                                weight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Message Button
                  SizedBox(
                    width: 80,
                    height: 32,
                    child: OutlinedButton(
                      onPressed: _startConversation,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.accentPrimary.withOpacity(0.5),
                          width: 1,
                        ),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Message',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.accentPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Post Result Item
class _PostResultItem extends StatelessWidget {
  final Post post;

  const _PostResultItem({required this.post});

  @override
  Widget build(BuildContext context) {
    final bool hasImage = post.mediaUrls != null && post.mediaUrls!.isNotEmpty;
    final String imageUrl = hasImage
        ? '${ApiConfig.supabaseStorageUrl}${post.mediaUrls!.first}'
        : '';

    return GestureDetector(
      onTap: () {
        // Navigate to post detail (will be implemented next)
        context.push('/post/${post.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppColors.accentPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User', // Will be populated when we enrich with user data
                        style: AppTextStyles.bodySmall(weight: FontWeight.w600),
                      ),
                      Text(
                        '@user',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTime(post.createdAt),
                  style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: AppTextStyles.bodyMedium(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasImage) ...[
              const SizedBox(height: 12),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageUrl.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.image,
                          color: AppColors.textTertiary,
                          size: 40,
                        ),
                      )
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.favorite_border,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likesCount}',
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.comment_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentsCount}',
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../posts/data/models/post.dart';
import '../../../posts/data/models/poll.dart';
import '../../../posts/data/services/posts_service.dart';
import '../../../posts/presentation/widgets/comment_drawer.dart';
import '../../../posts/presentation/widgets/share_drawer.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../data/providers/feed_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../account/data/services/account_service.dart';

class ExploreScreen extends StatefulWidget {
  final String? filter;

  const ExploreScreen({super.key, this.filter});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final PostsService _postsService = PostsService();
  final AccountService _accountService = AccountService();
  final ScrollController _scrollController = ScrollController();
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  String? _currentFilter;
  bool _hasUpdatedLastUsed = false;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter;
    _loadExploreFeed();
    _scrollController.addListener(_onScroll);
    // Update last_used_at when viewing explore content
    _updateLastUsed();
  }

  Future<void> _updateLastUsed() async {
    if (_hasUpdatedLastUsed) return;
    
    try {
      await _accountService.updateLastUsed();
      _hasUpdatedLastUsed = true;
    } catch (e) {
      // Silently fail - don't interrupt user experience
      debugPrint('Failed to update last used: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _loadExploreFeed(loadMore: true);
    }
  }

  Future<void> _loadExploreFeed({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _postsService.getExploreFeed(
        limit: _limit,
        offset: loadMore ? _offset : 0,
        filter: _currentFilter,
      );

      if (response.success && response.data != null) {
        setState(() {
          if (loadMore) {
            _posts.addAll(response.data!.posts);
          } else {
            _posts = response.data!.posts;
          }
          _offset = _posts.length;
          _hasMore = response.data!.hasMore ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load explore feed: ${e.toString()}'),
            backgroundColor: AppColors.accentQuaternary,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onFilterChanged(String? filter) {
    if (_currentFilter == filter) return;

    setState(() {
      _currentFilter = filter;
      _posts = [];
      _offset = 0;
      _hasMore = true;
    });

    _loadExploreFeed();
  }

  String _getFilterLabel() {
    switch (_currentFilter) {
      case 'posts':
        return 'New Posts';
      case 'polls':
        return 'New Polls';
      case 'articles':
        return 'New Articles';
      case 'users':
        return 'New Users';
      default:
        return 'All New Content';
    }
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
              // Custom Header with "Since your last visit" emphasis
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Since your last visit',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textSecondary,
                              weight: FontWeight.w500,
                            ).copyWith(fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getFilterLabel(),
                            style: AppTextStyles.headlineSmall(
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Refresh button
                    GestureDetector(
                      onTap: () async {
                        setState(() {
                          _posts = [];
                          _offset = 0;
                          _hasMore = true;
                        });
                        await _loadExploreFeed();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          color: AppColors.accentPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter tabs
              _FilterTabs(
                currentFilter: _currentFilter,
                onFilterChanged: _onFilterChanged,
              ),
              // Content
              Expanded(
                child: _isLoading && _posts.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accentPrimary,
                          ),
                        ),
                      )
                    : _posts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  color: AppColors.textTertiary,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No new content',
                                  style: AppTextStyles.bodyLarge(
                                    color: AppColors.textSecondary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Check back later for updates',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              setState(() {
                                _posts = [];
                                _offset = 0;
                                _hasMore = true;
                              });
                              await _loadExploreFeed();
                            },
                            color: AppColors.accentPrimary,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: _posts.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _posts.length) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          AppColors.accentPrimary,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final post = _posts[index];
                                // Use the same post building logic from home_screen
                                return _buildPostWidget(post);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostWidget(Post post) {
    final username = post.author?.displayName ?? post.author?.username ?? 'Unknown';
    final userHandle = post.author?.username != null ? '@${post.author!.username}' : '';
    final profilePictureUrl = post.author?.profilePicture;
    final timeAgo = app_date_utils.DateUtils.timeAgo(post.createdAt);
    
    if (post.postType == 'poll' && post.poll != null) {
      return _PollCard(
        username: username,
        userHandle: userHandle,
        profilePictureUrl: profilePictureUrl,
        userId: post.userId,
        timeAgo: timeAgo,
        poll: post.poll!,
        likes: post.likesCount,
        comments: post.commentsCount,
        shares: post.sharesCount,
        isLiked: post.isLiked ?? false,
        isSaved: post.isSaved ?? false,
        postId: post.id,
      );
    } else {
      final hasMedia = post.mediaUrls != null && post.mediaUrls!.isNotEmpty;
      final firstMediaUrl = hasMedia ? post.mediaUrls!.first : null;
      
      return _PostCard(
        username: username,
        userHandle: userHandle,
        profilePictureUrl: profilePictureUrl,
        userId: post.userId,
        timeAgo: timeAgo,
        content: post.content ?? '',
        imageUrl: firstMediaUrl,
        likes: post.likesCount,
        comments: post.commentsCount,
        shares: post.sharesCount,
        isLiked: post.isLiked ?? false,
        isSaved: post.isSaved ?? false,
        postId: post.id,
      );
    }
  }
}

class _FilterTabs extends StatelessWidget {
  final String? currentFilter;
  final Function(String?) onFilterChanged;

  const _FilterTabs({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'key': null, 'label': 'All', 'icon': Icons.grid_view_rounded},
      {'key': 'posts', 'label': 'Posts', 'icon': Icons.photo_library_outlined},
      {'key': 'polls', 'label': 'Polls', 'icon': Icons.bar_chart_rounded},
      {'key': 'articles', 'label': 'Articles', 'icon': Icons.article_outlined},
      {'key': 'users', 'label': 'Users', 'icon': Icons.person_add_alt_1_outlined},
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = currentFilter == filter['key'];
          final color = isSelected
              ? AppColors.accentPrimary
              : AppColors.textSecondary;

          return GestureDetector(
            onTap: () => onFilterChanged(filter['key'] as String?),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentPrimary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentPrimary.withOpacity(0.5)
                      : AppColors.glassBorder.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter['label'] as String,
                    style: AppTextStyles.bodySmall(
                      color: color,
                      weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ).copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Post card widget - full implementation from home_screen
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                Icon(
                  Icons.more_horiz,
                  color: AppColors.textSecondary,
                  size: 24,
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
          if (widget.imageUrl != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentPrimary.withOpacity(0.3),
                    AppColors.accentSecondary.withOpacity(0.3),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.image,
                  size: 64,
                  color: Colors.white.withOpacity(0.5),
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

// Poll card widget - full implementation from home_screen
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
        final results = response.data!;
        final pollData = results['poll'] as Map<String, dynamic>?;
        if (pollData != null) {
          final updatedPoll = Poll.fromJson(pollData);
          final optionsData = results['options'] as List<dynamic>?;
          if (optionsData != null) {
            final updatedOptions = optionsData.map((opt) {
              final optMap = opt as Map<String, dynamic>;
              return PollOption(
                id: optMap['id'] as String,
                pollId: optMap['poll_id'] as String? ?? updatedPoll.id,
                optionText: optMap['option_text'] as String,
                optionIndex: optMap['option_index'] as int,
                votesCount: optMap['votes_count'] as int? ?? 0,
              );
            }).toList();
            
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
          }
        }
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
                  Icon(
                    Icons.poll_outlined,
                    color: AppColors.accentPrimary,
                    size: 20,
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
                    final percentage = totalVotes > 0 ? (option.votesCount / totalVotes * 100) : 0.0;
                    final isSelected = _poll.userVote == option.id;

                    return GestureDetector(
                      onTap: showResults ? null : () => _voteOnOption(option.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentPrimary.withOpacity(0.1)
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.optionText,
                                    style: AppTextStyles.bodyMedium(
                                      weight: FontWeight.w500,
                                      color: isSelected ? AppColors.accentPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (showResults) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: percentage / 100,
                                            backgroundColor: AppColors.backgroundSecondary,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppColors.accentPrimary,
                                            ),
                                            minHeight: 4,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: AppTextStyles.bodySmall(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${option.votesCount} ${option.votesCount == 1 ? 'vote' : 'votes'}',
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: AppColors.accentPrimary,
                                size: 20,
                              ),
                          ],
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
                  Text(
                    '${totalVotes} ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_poll.endsAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _poll.hasEnded ? 'Ended' : '${_poll.timeRemaining} left',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Interaction Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

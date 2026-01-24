import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart' as date_utils;
import '../../../auth/data/providers/auth_provider.dart';
import '../../data/models/status.dart';
import '../../data/models/status_view.dart';
import '../../data/services/status_service.dart';
import '../widgets/status_comment_drawer.dart';

class StatusViewerScreen extends StatefulWidget {
  final String statusId;

  const StatusViewerScreen({
    super.key,
    required this.statusId,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  final StatusService _statusService = StatusService();
  Status? _status;
  List<StatusView> _views = [];
  List<Map<String, dynamic>> _reactions = [];
  bool _isLoading = true;
  bool _isLoadingViews = false;
  bool _isLoadingReactions = false;
  String? _error;
  bool _showViewsSheet = false;
  bool _showReactionsSheet = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Load status details
    final statusResponse = await _statusService.getStatus(widget.statusId);
    if (statusResponse.success && statusResponse.data != null) {
      setState(() {
        _status = statusResponse.data;
        _isLoading = false;
      });
      
      // Load views and reactions
      _loadViews();
      _loadReactions();
      
      // Record view if not already viewed
      if (!_status!.isViewed) {
        _statusService.viewStatus(widget.statusId);
      }
    } else {
      setState(() {
        _error = statusResponse.error ?? 'Failed to load status';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadViews() async {
    if (_status == null) return;
    
    setState(() {
      _isLoadingViews = true;
    });

    final viewsResponse = await _statusService.getStatusViews(widget.statusId);
    if (viewsResponse.success && viewsResponse.data != null) {
      setState(() {
        _views = viewsResponse.data!;
        _isLoadingViews = false;
      });
    } else {
      setState(() {
        _isLoadingViews = false;
      });
    }
  }

  Future<void> _loadReactions() async {
    if (_status == null) return;
    
    setState(() {
      _isLoadingReactions = true;
    });

    final reactionsResponse = await _statusService.getStatusReactions(widget.statusId);
    if (reactionsResponse.success && reactionsResponse.data != null) {
      setState(() {
        _reactions = reactionsResponse.data!;
        _isLoadingReactions = false;
      });
    } else {
      setState(() {
        _isLoadingReactions = false;
      });
    }
  }

  Future<void> _reactToStatus(String emoji) async {
    if (_status == null) return;

    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;

    // Optimistic update
    final previousReaction = _status!.userReaction;
    setState(() {
      _status = Status(
        id: _status!.id,
        userId: _status!.userId,
        statusType: _status!.statusType,
        content: _status!.content,
        mediaUrl: _status!.mediaUrl,
        mediaType: _status!.mediaType,
        backgroundColor: _status!.backgroundColor,
        viewsCount: _status!.viewsCount,
        reactionsCount: previousReaction != null 
            ? _status!.reactionsCount 
            : _status!.reactionsCount + 1,
        commentsCount: _status!.commentsCount,
        expiresAt: _status!.expiresAt,
        createdAt: _status!.createdAt,
        updatedAt: _status!.updatedAt,
        author: _status!.author,
        isViewed: _status!.isViewed,
        userReaction: previousReaction == emoji ? null : emoji,
      );
    });

    if (previousReaction == emoji) {
      // Remove reaction
      final response = await _statusService.removeStatusReaction(widget.statusId);
      if (response.success) {
        await _loadReactions();
        final statusResponse = await _statusService.getStatus(widget.statusId);
        if (statusResponse.success && statusResponse.data != null) {
          setState(() {
            _status = statusResponse.data;
          });
        }
      } else {
        // Revert on error
        setState(() {
          _status = Status(
            id: _status!.id,
            userId: _status!.userId,
            statusType: _status!.statusType,
            content: _status!.content,
            mediaUrl: _status!.mediaUrl,
            mediaType: _status!.mediaType,
            backgroundColor: _status!.backgroundColor,
            viewsCount: _status!.viewsCount,
            reactionsCount: _status!.reactionsCount - 1,
            commentsCount: _status!.commentsCount,
            expiresAt: _status!.expiresAt,
            createdAt: _status!.createdAt,
            updatedAt: _status!.updatedAt,
            author: _status!.author,
            isViewed: _status!.isViewed,
            userReaction: previousReaction,
          );
        });
      }
    } else {
      // Add/update reaction
      final response = await _statusService.reactToStatus(widget.statusId, emoji);
      if (response.success) {
        await _loadReactions();
        final statusResponse = await _statusService.getStatus(widget.statusId);
        if (statusResponse.success && statusResponse.data != null) {
          setState(() {
            _status = statusResponse.data;
          });
        }
      } else {
        // Revert on error
        setState(() {
          _status = Status(
            id: _status!.id,
            userId: _status!.userId,
            statusType: _status!.statusType,
            content: _status!.content,
            mediaUrl: _status!.mediaUrl,
            mediaType: _status!.mediaType,
            backgroundColor: _status!.backgroundColor,
            viewsCount: _status!.viewsCount,
            reactionsCount: previousReaction != null 
                ? _status!.reactionsCount 
                : _status!.reactionsCount - 1,
            commentsCount: _status!.commentsCount,
            expiresAt: _status!.expiresAt,
            createdAt: _status!.createdAt,
            updatedAt: _status!.updatedAt,
            author: _status!.author,
            isViewed: _status!.isViewed,
            userReaction: previousReaction,
          );
        });
      }
    }
  }

  void _openCommentDrawer() {
    if (_status == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatusCommentDrawer(
        statusId: widget.statusId,
        statusAuthorId: _status!.userId,
        initialCommentCount: _status!.commentsCount,
        onCommentAdded: () {
          _loadStatus(); // Reload to update comment count
        },
      ),
    );
  }

  String _getTimeRemaining() {
    if (_status == null) return '';
    final now = DateTime.now();
    final expiresAt = _status!.expiresAt;
    if (now.isAfter(expiresAt)) return 'Expired';
    
    final difference = expiresAt.difference(now);
    final hours = difference.inHours;
    if (hours > 0) {
      return '${hours}h left';
    }
    final minutes = difference.inMinutes;
    return '${minutes}m left';
  }

  String _getAuthorName() {
    if (_status?.author == null) return 'Unknown';
    return _status!.author!.displayName ?? 
        _status!.author!.username ?? 
        (_status!.author!.email != null && _status!.author!.email!.contains('@')
            ? _status!.author!.email!.split('@')[0]
            : 'Unknown');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentPrimary,
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: AppTextStyles.bodyLarge(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _status == null
                  ? const Center(
                      child: Text('Status not found', style: TextStyle(color: Colors.white)),
                    )
                  : GestureDetector(
                      onTapDown: (details) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final tapX = details.globalPosition.dx;
                        // Tap left side = previous, right side = next (for future multi-status support)
                        // For now, just handle exit on tap
                      },
                      onVerticalDragEnd: (details) {
                        // Swipe down to exit
                        if (details.primaryVelocity! > 500) {
                          Navigator.pop(context);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Status Content (Full Screen Background)
                          _buildFullScreenContent(),
                          
                          // Top Overlay Bar (Positioned top left)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: _buildTopOverlay(),
                          ),
                          
                          // Bottom Overlay Bar
                          _buildBottomOverlay(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildFullScreenContent() {
    if (_status == null) return Container(color: Colors.black);

    if (_status!.statusType == 'text') {
      return Container(
        color: Color(int.parse(_status!.backgroundColor.replaceFirst('#', '0xFF'))),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _status!.content ?? '',
              style: AppTextStyles.displayLarge(
                color: Colors.white,
                weight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else if (_status!.statusType == 'image' && _status!.mediaUrl != null) {
      return CachedNetworkImage(
        imageUrl: _status!.mediaUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.accentPrimary,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.black,
          child: const Center(
            child: Icon(
              Icons.error,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
      );
    } else if (_status!.statusType == 'video' && _status!.mediaUrl != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_circle_outline,
                size: 80,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                'Video playback coming soon',
                style: AppTextStyles.bodyLarge(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(color: Colors.black);
  }

  Widget _buildTopOverlay() {
    if (_status == null) return const SizedBox.shrink();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close Button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Profile Picture
            CircleAvatar(
              radius: 16,
              backgroundImage: _status!.author?.profilePicture != null
                  ? CachedNetworkImageProvider(_status!.author!.profilePicture!)
                  : null,
              backgroundColor: AppColors.backgroundSecondary,
              child: _status!.author?.profilePicture == null
                  ? Text(
                      _getAuthorName().isNotEmpty ? _getAuthorName()[0].toUpperCase() : '?',
                      style: AppTextStyles.bodySmall(
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            
            // Name and Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getAuthorName(),
                  style: AppTextStyles.bodySmall(
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getTimeRemaining(),
                  style: AppTextStyles.bodySmall(
                    color: Colors.white70,
                  ).copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomOverlay() {
    if (_status == null) return const SizedBox.shrink();

    final reactionEmojis = ['👍', '💯', '❤️', '🤝', '💡'];
    final currentReaction = _status!.userReaction;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick Reactions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: reactionEmojis.map((emoji) {
                  final isSelected = currentReaction == emoji;
                  return GestureDetector(
                    onTap: () => _reactToStatus(emoji),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentPrimary.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentPrimary
                              : Colors.white.withOpacity(0.4),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              // Engagement Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Views
                  GestureDetector(
                    onTap: () {
                      if (_status!.viewsCount > 0) {
                        setState(() {
                          _showViewsSheet = true;
                        });
                        _showViewsBottomSheet();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_status!.viewsCount}',
                            style: AppTextStyles.bodyMedium(
                              color: Colors.white,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Reactions
                  GestureDetector(
                    onTap: () {
                      if (_status!.reactionsCount > 0) {
                        setState(() {
                          _showReactionsSheet = true;
                        });
                        _showReactionsBottomSheet();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_status!.reactionsCount}',
                            style: AppTextStyles.bodyMedium(
                              color: Colors.white,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Comments
                  GestureDetector(
                    onTap: _openCommentDrawer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.comment,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_status!.commentsCount}',
                            style: AppTextStyles.bodyMedium(
                              color: Colors.white,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  void _showViewsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Views (${_status!.viewsCount})',
                      style: AppTextStyles.headlineSmall(
                        color: AppColors.textPrimary,
                        weight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: AppColors.glassBorder),

              // Views List
              Expanded(
                child: _isLoadingViews
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentPrimary,
                        ),
                      )
                    : _views.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 64,
                                  color: AppColors.textSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No views yet',
                                  style: AppTextStyles.bodyLarge(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your status hasn\'t been viewed yet',
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.textSecondary.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _views.length,
                            itemBuilder: (context, index) {
                              final view = _views[index];
                              final user = view.user;
                              final username = user?.displayName ?? 
                                  user?.username ?? 
                                  'Unknown';
                              final profilePic = user?.profilePicture;
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: profilePic != null
                                          ? CachedNetworkImageProvider(profilePic)
                                          : null,
                                      backgroundColor: AppColors.backgroundSecondary,
                                      child: profilePic == null
                                          ? Text(
                                              username.isNotEmpty 
                                                  ? username[0].toUpperCase() 
                                                  : '?',
                                              style: AppTextStyles.bodyMedium(
                                                color: AppColors.textPrimary,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            username,
                                            style: AppTextStyles.bodyMedium(
                                              color: AppColors.textPrimary,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                          if (user?.username != null)
                                            Text(
                                              '@${user!.username}',
                                              style: AppTextStyles.bodySmall(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            date_utils.DateUtils.timeAgo(view.viewedAt),
                                            style: AppTextStyles.bodySmall(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        _showViewsSheet = false;
      });
    });
  }

  void _showReactionsBottomSheet() {
    // Group reactions by emoji
    final Map<String, List<Map<String, dynamic>>> groupedReactions = {};
    for (final reaction in _reactions) {
      final emoji = reaction['emoji'] as String? ?? '👍';
      if (!groupedReactions.containsKey(emoji)) {
        groupedReactions[emoji] = [];
      }
      groupedReactions[emoji]!.add(reaction);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Reactions (${_status!.reactionsCount})',
                      style: AppTextStyles.headlineSmall(
                        color: AppColors.textPrimary,
                        weight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: AppColors.glassBorder),

              // Reactions List
              Expanded(
                child: _isLoadingReactions
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentPrimary,
                        ),
                      )
                    : _reactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_outline,
                                  size: 64,
                                  color: AppColors.textSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No reactions yet',
                                  style: AppTextStyles.bodyLarge(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to react!',
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.textSecondary.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: groupedReactions.length,
                            itemBuilder: (context, index) {
                              final emoji = groupedReactions.keys.elementAt(index);
                              final reactionsForEmoji = groupedReactions[emoji]!;
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Emoji Header
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${reactionsForEmoji.length}',
                                          style: AppTextStyles.bodyMedium(
                                            color: AppColors.textSecondary,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Users who reacted with this emoji
                                  ...reactionsForEmoji.map((reaction) {
                                    final user = reaction['user'] as Map<String, dynamic>?;
                                    final username = user?['display_name'] as String? ?? 
                                        user?['username'] as String? ?? 
                                        'Unknown';
                                    final profilePic = user?['profile_picture'] as String?;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundImage: profilePic != null
                                                ? CachedNetworkImageProvider(profilePic)
                                                : null,
                                            backgroundColor: AppColors.backgroundSecondary,
                                            child: profilePic == null
                                                ? Text(
                                                    username.isNotEmpty 
                                                        ? username[0].toUpperCase() 
                                                        : '?',
                                                    style: AppTextStyles.bodyMedium(
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  username,
                                                  style: AppTextStyles.bodyMedium(
                                                    color: AppColors.textPrimary,
                                                    weight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (user?['username'] != null)
                                                  Text(
                                                    '@${user!['username']}',
                                                    style: AppTextStyles.bodySmall(
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  
                                  // Divider between emoji groups
                                  if (index < groupedReactions.length - 1)
                                    Divider(
                                      height: 1,
                                      color: AppColors.glassBorder.withOpacity(0.3),
                                      indent: 20,
                                      endIndent: 20,
                                    ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        _showReactionsSheet = false;
      });
    });
  }
}

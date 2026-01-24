import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/config/api_config.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../data/models/post.dart';
import '../../data/services/posts_service.dart';

/// Professional Instagram-style share drawer with improved UI/UX
class ShareDrawer extends StatefulWidget {
  final Post post;

  const ShareDrawer({
    super.key,
    required this.post,
  });

  @override
  State<ShareDrawer> createState() => _ShareDrawerState();
}

class _ShareDrawerState extends State<ShareDrawer> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final PostsService _postsService = PostsService();
  bool _isSharing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _getPostUrl() {
    // Construct the post URL for sharing with Open Graph preview
    // Use the preview endpoint which serves HTML with Open Graph tags
    final baseUrl = ApiConfig.baseUrl;
    // Remove trailing slash if present
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    // Use the preview endpoint for Open Graph support
    return '$cleanBaseUrl/posts/${widget.post.id}/preview';
  }

  Future<void> _shareToOtherApps() async {
    try {
      final postUrl = _getPostUrl();
      
      // Get author name for the share message
      final authorName = widget.post.author?.displayName ?? 
                        widget.post.author?.username ?? 
                        'Someone';
      
      // Create a share message that includes the URL
      // For Open Graph to work, the URL must be included in the shared text
      // Apps like WhatsApp will automatically fetch Open Graph metadata when they detect a URL
      final shareText = 'Check out this post by $authorName on Histeeria:\n\n$postUrl';
      
      // Share with both text and URL to ensure Open Graph preview works
      await Share.share(
        shareText,
        subject: 'Shared from Histeeria',
      );
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: ${e.toString()}'),
            backgroundColor: AppColors.accentQuaternary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _sharePost() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      final comment = _messageController.text.trim();
      final response = await _postsService.sharePost(
        widget.post.id,
        comment: comment.isNotEmpty ? comment : null,
      );
      
      if (mounted) {
        if (response.success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Post shared successfully'),
              backgroundColor: AppColors.accentPrimary,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to share post'),
              backgroundColor: AppColors.accentQuaternary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: ${e.toString()}'),
            backgroundColor: AppColors.accentQuaternary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  String _getAuthorName() {
    final author = widget.post.author;
    if (author == null) return 'Unknown';
    
    // Try display name first, then username, then email prefix as fallback
    if (author.displayName != null && author.displayName!.isNotEmpty) {
      return author.displayName!;
    }
    if (author.username != null && author.username!.isNotEmpty) {
      return author.username!;
    }
    if (author.email != null && author.email!.isNotEmpty) {
      // Extract username from email
      final emailParts = author.email!.split('@');
      if (emailParts.isNotEmpty && emailParts[0].isNotEmpty) {
        return emailParts[0];
      }
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.5, 0.75, 0.95],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar with improved styling
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Header with better spacing
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                  child: Row(
                    children: [
                      Text(
                        'Share',
                        style: AppTextStyles.headlineMedium(
                          weight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.close,
                              size: 22,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),
                // Post preview with improved design
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Post thumbnail with better styling
                      Hero(
                        tag: 'post_${widget.post.id}',
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: widget.post.hasMedia && widget.post.firstMediaUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: widget.post.firstMediaUrl!,
                                    fit: BoxFit.cover,
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
                                    errorWidget: (context, url, error) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.accentPrimary.withOpacity(0.3),
                                            AppColors.accentSecondary.withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: AppColors.textSecondary,
                                        size: 24,
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.accentPrimary.withOpacity(0.3),
                                          AppColors.accentSecondary.withOpacity(0.3),
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.article_outlined,
                                      color: AppColors.textSecondary,
                                      size: 28,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Post info with better typography
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getAuthorName(),
                              style: AppTextStyles.bodyMedium(
                                weight: FontWeight.w700,
                              ).copyWith(fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.post.content.isNotEmpty
                                  ? widget.post.content.length > 60
                                      ? '${widget.post.content.substring(0, 60)}...'
                                      : widget.post.content
                                  : 'Shared a post',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),
                // Share options with improved layout
                Flexible(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Share to story
                      _ShareOption(
                        icon: Icons.auto_stories_rounded,
                        title: 'Add to your story',
                        subtitle: 'Share to your story',
                        iconColor: AppColors.accentPrimary,
                        onTap: () {
                          Navigator.of(context).pop();
                          // TODO: Navigate to create story
                        },
                      ),
                      // Share to feed
                      _ShareOption(
                        icon: Icons.feed_rounded,
                        title: 'Share to feed',
                        subtitle: 'Share as a new post',
                        iconColor: AppColors.accentSecondary,
                        onTap: () {
                          Navigator.of(context).pop();
                          // TODO: Navigate to create post with shared content
                        },
                      ),
                      // Copy link
                      _ShareOption(
                        icon: Icons.link_rounded,
                        title: 'Copy link',
                        subtitle: 'Copy post link to clipboard',
                        iconColor: AppColors.accentTertiary,
                        onTap: () async {
                          final postUrl = _getPostUrl();
                          await Clipboard.setData(ClipboardData(text: postUrl));
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                                    const SizedBox(width: 12),
                                    const Text('Link copied to clipboard'),
                                  ],
                                ),
                                backgroundColor: AppColors.accentPrimary,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      // Share via section header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'Share via...',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.textTertiary,
                            weight: FontWeight.w700,
                          ).copyWith(letterSpacing: 0.5),
                        ),
                      ),
                      // Share to other apps
                      _ShareOption(
                        icon: Icons.share_rounded,
                        title: 'Share to other apps',
                        subtitle: 'WhatsApp, Instagram, Drive, and more',
                        iconColor: AppColors.accentPrimary,
                        onTap: () async {
                          await _shareToOtherApps();
                        },
                      ),
                    ],
                  ),
                ),
                // Message input section with improved design
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + keyboardHeight + safeAreaBottom,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary.withOpacity(0.3),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.glassBorder.withOpacity(0.15),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _messageController,
                        style: AppTextStyles.bodyMedium(),
                        decoration: InputDecoration(
                          hintText: 'Write a message...',
                          hintStyle: AppTextStyles.bodyMedium(
                            color: AppColors.textTertiary,
                          ),
                          filled: true,
                          fillColor: AppColors.backgroundSecondary.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.accentPrimary.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _sharePost(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSharing ? null : _sharePost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPrimary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.accentPrimary.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: _isSharing
                              ? SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Share',
                                  style: AppTextStyles.bodyLarge(
                                    color: Colors.white,
                                    weight: FontWeight.w700,
                                  ),
                                ),
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
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w600,
                      ).copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary.withOpacity(0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

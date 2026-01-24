import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../posts/data/models/article.dart';
import '../../../posts/data/models/post.dart';
import '../../../posts/data/services/posts_service.dart';
import '../../../posts/presentation/widgets/comment_drawer.dart';
import '../../../posts/presentation/widgets/share_drawer.dart';
import '../../../account/data/services/account_service.dart';
import '../../../feed/data/providers/feed_provider.dart';
import 'package:provider/provider.dart';

class ArticleViewerScreen extends StatefulWidget {
  final String articleId;
  final Article? article; // Optional: if passed, use it directly

  const ArticleViewerScreen({
    super.key,
    required this.articleId,
    this.article,
  });

  @override
  State<ArticleViewerScreen> createState() => _ArticleViewerScreenState();
}

class _ArticleViewerScreenState extends State<ArticleViewerScreen> {
  Article? _article;
  bool _isLoading = false;
  String? _error;
  final PostsService _postsService = PostsService();
  final AccountService _accountService = AccountService();
  final ScrollController _scrollController = ScrollController();
  bool _hasUpdatedLastUsed = false;

  @override
  void initState() {
    super.initState();
    // Use article if provided, otherwise show error (for now)
    if (widget.article != null) {
      _article = widget.article;
      _isLoading = false;
      // Update last_used_at when viewing article
      _updateLastUsed();
    } else {
      // TODO: Fetch article by ID from backend
      _isLoading = false;
      _error = 'Article data not available. Please navigate from the feed.';
    }
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

  String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  List<String> _splitIntoParagraphs(String text) {
    return text.split('\n').where((p) => p.trim().isNotEmpty).toList();
  }

  void _openCommentDrawer() {
    if (_article == null) return;
    // TODO: Get post author ID and comment count from article/post
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentDrawer(
        postId: _article!.postId,
        postAuthorId: '', // TODO: Get from article/post
        initialCommentCount: 0, // TODO: Get from article/post
      ),
    );
  }

  void _openShareDrawer() {
    if (_article == null) return;
    // Create a minimal post object for the drawer
    final post = Post(
      id: _article!.postId,
      userId: '', // TODO: Get from article/post
      postType: 'article',
      content: _article!.title,
      visibility: 'public',
      allowsComments: true,
      allowsSharing: true,
      isPublished: true,
      createdAt: _article!.createdAt,
      updatedAt: _article!.updatedAt,
      mediaUrls: _article!.coverImageUrl != null
          ? [_article!.coverImageUrl!]
          : null,
      article: _article,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareDrawer(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _isLoading
              ? Center(
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
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.pop(),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    )
                  : _article == null
                      ? Center(
                          child: Text(
                            'Article not found',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            // App bar
                            SliverAppBar(
                              pinned: true,
                              backgroundColor: AppColors.backgroundSecondary.withOpacity(0.95),
                              elevation: 0,
                              leading: IconButton(
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: AppColors.textPrimary,
                                ),
                                onPressed: () => context.pop(),
                              ),
                            ),

                            // Article content
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cover image (only if exists)
                                  if (_article!.coverImageUrl != null &&
                                      _article!.coverImageUrl!.isNotEmpty)
                                    CachedNetworkImage(
                                      imageUrl: _article!.coverImageUrl!,
                                      width: double.infinity,
                                      height: 300,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        height: 300,
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

                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      20,
                                      _article!.coverImageUrl != null &&
                                              _article!.coverImageUrl!.isNotEmpty
                                          ? 20
                                          : 20,
                                      20,
                                      20,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Category
                                        if (_article!.category != null)
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 16),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
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
                                              _article!.category!,
                                              style: AppTextStyles.bodySmall(
                                                color: AppColors.textSecondary,
                                                weight: FontWeight.w500,
                                              ),
                                            ),
                                          ),

                                        // Title
                                        Text(
                                          _article!.title,
                                          style: AppTextStyles.headlineLarge(
                                            weight: FontWeight.bold,
                                          ),
                                        ),

                                        // Subtitle
                                        if (_article!.subtitle != null) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            _article!.subtitle!,
                                            style: AppTextStyles.headlineMedium(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],

                                        const SizedBox(height: 24),

                                        // Meta info
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: AppColors.textTertiary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${_article!.readTimeMinutes} min read',
                                              style: AppTextStyles.bodySmall(
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Icon(
                                              Icons.visibility_outlined,
                                              size: 16,
                                              color: AppColors.textTertiary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${_article!.viewsCount} views',
                                              style: AppTextStyles.bodySmall(
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 32),

                                        // Article content
                                        ..._splitIntoParagraphs(
                                          _stripHtmlTags(_article!.contentHtml),
                                        ).map(
                                          (paragraph) => Padding(
                                            padding: const EdgeInsets.only(bottom: 16),
                                            child: Text(
                                              paragraph,
                                              style: AppTextStyles.bodyLarge().copyWith(
                                                height: 1.6,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 32),

                                        // Tags
                                        if (_article!.tags != null && _article!.tags!.isNotEmpty)
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: _article!.tags!.map((tag) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accentPrimary.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: AppColors.accentPrimary.withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  '#$tag',
                                                  style: AppTextStyles.bodySmall(
                                                    color: AppColors.accentPrimary,
                                                    weight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),

                                        const SizedBox(height: 40),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
        ),
        bottomNavigationBar: _article != null
            ? Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary.withOpacity(0.95),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.glassBorder.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.comment_outlined,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: _openCommentDrawer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Comments',
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.share_outlined,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: _openShareDrawer,
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

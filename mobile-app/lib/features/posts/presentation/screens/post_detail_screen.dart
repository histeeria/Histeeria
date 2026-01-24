import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/services/posts_service.dart';
import '../../data/models/post.dart';
import '../../../../core/config/api_config.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostsService _postsService = PostsService();
  Post? _post;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Note: You'll need to add a getPostById method to PostsService
      // For now, this will show an error
      throw UnimplementedError('getPostById not implemented in PostsService yet');

      // When implemented:
      // final post = await _postsService.getPostById(widget.postId);
      // if (mounted) {
      //   setState(() {
      //     _post = post;
      //     _isLoading = false;
      //   });
      // }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Post',
            style: AppTextStyles.headlineSmall(weight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.share, color: AppColors.textPrimary),
              onPressed: () {
                // Share functionality
                // Share the URL: https://histeeria.app/post/${widget.postId}
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load post',
                            style: AppTextStyles.bodyLarge(
                              color: AppColors.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadPost,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _post == null
                    ? Center(
                        child: Text(
                          'Post not found',
                          style: AppTextStyles.bodyLarge(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Post content would go here
                            // This is a simplified version - you'll want to reuse
                            // your post card widget from home_screen.dart
                            Text(
                              _post!.content,
                              style: AppTextStyles.bodyLarge(),
                            ),
                            // Add images, likes, comments, etc.
                          ],
                        ),
                      ),
      ),
    );
  }
}

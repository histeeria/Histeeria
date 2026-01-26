import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
// import '../../../posts/presentation/widgets/post_card.dart'; // Removed missing import
import '../../data/services/activity_service.dart';
import '../../../posts/data/models/post.dart';

class LikedPostsScreen extends StatefulWidget {
  const LikedPostsScreen({super.key});

  @override
  State<LikedPostsScreen> createState() => _LikedPostsScreenState();
}

class _LikedPostsScreenState extends State<LikedPostsScreen> {
  final ActivityService _activityService = ActivityService();
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final posts = await _activityService.getLikedPosts();
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Liked Posts',
            style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text('Error: $_errorMessage'))
                : _posts.isEmpty
                    ? Center(
                        child: Text(
                          'No liked posts yet',
                          style: AppTextStyles.bodyLarge(color: AppColors.textSecondary),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                          childAspectRatio: 1, // Standard Instagram-like grid
                        ),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          // Use first media as thumbnail, or generate placeholder
                          final imageUrl = post.mediaUrls != null && post.mediaUrls!.isNotEmpty ? post.mediaUrls!.first : null;
                          
                          return GestureDetector(
                            onTap: () {
                              // TODO: Navigate to full post view 
                              // context.push('/post/${post.id}');
                            },
                            child: Container(
                              color: AppColors.surface,
                              child: imageUrl != null 
                                  ? Image.network(imageUrl, fit: BoxFit.cover)
                                  : Center(child: Icon(Icons.article, color: AppColors.textSecondary)),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/services/activity_service.dart';
import '../../../posts/data/models/comment.dart';

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final ActivityService _activityService = ActivityService();
  List<Comment> _comments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final comments = await _activityService.getUserComments();
      setState(() {
        _comments = comments;
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
            'Your Comments',
            style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text('Error: $_errorMessage'))
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet',
                          style: AppTextStyles.bodyLarge(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        separatorBuilder: (context, index) => Divider(color: AppColors.glassBorder),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              comment.content,
                              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Commented on ${comment.createdAt.toLocal().toString().split(' ')[0]}',
                              style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.accentPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.comment, color: AppColors.accentPrimary, size: 20),
                            ),
                            // TODO: Add tapping to go to the comment context
                          );
                        },
                      ),
      ),
    );
  }
}

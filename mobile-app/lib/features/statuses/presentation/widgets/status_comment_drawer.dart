import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart' as date_utils;
import '../../../auth/data/providers/auth_provider.dart';
import '../../data/models/status_comment.dart';
import '../../data/services/status_service.dart';

/// Professional Instagram-style comment drawer for statuses
class StatusCommentDrawer extends StatefulWidget {
  final String statusId;
  final String statusAuthorId;
  final int initialCommentCount;
  final VoidCallback? onCommentAdded;

  const StatusCommentDrawer({
    super.key,
    required this.statusId,
    required this.statusAuthorId,
    required this.initialCommentCount,
    this.onCommentAdded,
  });

  @override
  State<StatusCommentDrawer> createState() => _StatusCommentDrawerState();
}

class _StatusCommentDrawerState extends State<StatusCommentDrawer> {
  final StatusService _statusService = StatusService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  
  List<StatusComment> _comments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _editingCommentId;
  final Map<String, TextEditingController> _editControllers = {};
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _commentController.addListener(_onCommentChanged);
  }

  void _onCommentChanged() {
    setState(() {}); // Trigger rebuild for send button state
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _statusService.getStatusComments(
      widget.statusId,
      limit: 50,
      offset: 0,
    );

    if (response.success && response.data != null) {
      setState(() {
        _comments = response.data!.comments;
        _hasMore = response.data!.hasMore;
        _offset = _comments.length;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    final response = await _statusService.getStatusComments(
      widget.statusId,
      limit: 50,
      offset: _offset,
    );

    if (response.success && response.data != null) {
      setState(() {
        _comments.addAll(response.data!.comments);
        _hasMore = response.data!.hasMore;
        _offset = _comments.length;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSendingComment) return;

    setState(() {
      _isSendingComment = true;
    });

    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null) {
      setState(() {
        _isSendingComment = false;
      });
      return;
    }

    // Optimistic update
    final optimisticComment = StatusComment(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      statusId: widget.statusId,
      userId: currentUser.id,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      author: currentUser,
    );

    setState(() {
      _comments.insert(0, optimisticComment);
      _commentController.clear();
      _isSendingComment = false;
    });

    // Scroll to top
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Send to backend
    final response = await _statusService.createStatusComment(
      widget.statusId,
      content,
    );

    if (response.success && response.data != null) {
      // Replace optimistic comment with real one
      setState(() {
        final index = _comments.indexWhere((c) => c.id == optimisticComment.id);
        if (index != -1) {
          _comments[index] = response.data!;
        }
      });
      
      if (widget.onCommentAdded != null) {
        widget.onCommentAdded!();
      }
    } else {
      // Remove optimistic comment on error
      setState(() {
        _comments.removeWhere((c) => c.id == optimisticComment.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.error ?? 'Failed to post comment',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;

    // Find comment
    final comment = _comments.firstWhere(
      (c) => c.id == commentId,
      orElse: () => StatusComment(
        id: '',
        statusId: widget.statusId,
        userId: '',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Only allow deletion of own comments
    if (comment.userId != currentUser.id) return;

    // Optimistic update
    setState(() {
      _comments.removeWhere((c) => c.id == commentId);
    });

    // Delete from backend
    final response = await _statusService.deleteStatusComment(commentId);
    if (!response.success) {
      // Revert on error
      setState(() {
        _comments.insert(0, comment);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.error ?? 'Failed to delete comment',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _startEditing(String commentId) {
    final comment = _comments.firstWhere((c) => c.id == commentId);
    _editControllers[commentId] = TextEditingController(text: comment.content);
    setState(() {
      _editingCommentId = commentId;
    });
  }

  void _cancelEditing() {
    _editControllers[_editingCommentId!]?.dispose();
    _editControllers.remove(_editingCommentId);
    setState(() {
      _editingCommentId = null;
    });
  }

  Future<void> _saveEdit(String commentId) async {
    final controller = _editControllers[commentId];
    if (controller == null) return;

    final newContent = controller.text.trim();
    if (newContent.isEmpty) {
      _cancelEditing();
      return;
    }

    // Find comment
    final commentIndex = _comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final oldComment = _comments[commentIndex];

    // Optimistic update
    setState(() {
      _comments[commentIndex] = StatusComment(
        id: oldComment.id,
        statusId: oldComment.statusId,
        userId: oldComment.userId,
        content: newContent,
        createdAt: oldComment.createdAt,
        updatedAt: DateTime.now(),
        author: oldComment.author,
      );
      _editingCommentId = null;
    });

    controller.dispose();
    _editControllers.remove(commentId);

    // TODO: Add update comment endpoint to backend
    // For now, we'll just reload comments
    await _loadComments();
  }

  String _getAuthorName(StatusComment comment) {
    if (comment.author == null) return 'Unknown';
    return comment.author!.displayName ?? 
        comment.author!.username ?? 
        (comment.author!.email != null && comment.author!.email!.contains('@')
            ? comment.author!.email!.split('@')[0]
            : 'Unknown');
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Comments (${_comments.length})',
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

              // Comments List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentPrimary,
                        ),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.comment_outlined,
                                  size: 64,
                                  color: AppColors.textSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No comments yet',
                                  style: AppTextStyles.bodyLarge(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to comment!',
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
                            itemCount: _comments.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _comments.length) {
                                return _isLoadingMore
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(
                                            color: AppColors.accentPrimary,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: TextButton(
                                          onPressed: _loadMoreComments,
                                          child: Text(
                                            'Load more comments',
                                            style: AppTextStyles.bodyMedium(
                                              color: AppColors.accentPrimary,
                                            ),
                                          ),
                                        ),
                                      );
                              }

                              final comment = _comments[index];
                              final isEditing = _editingCommentId == comment.id;
                              final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
                              final isOwnComment = currentUser?.id == comment.userId;

                              return _CommentItem(
                                comment: comment,
                                isEditing: isEditing,
                                isOwnComment: isOwnComment,
                                editController: _editControllers[comment.id],
                                onStartEdit: () => _startEditing(comment.id),
                                onCancelEdit: _cancelEditing,
                                onSaveEdit: () => _saveEdit(comment.id),
                                onDelete: () => _deleteComment(comment.id),
                                getAuthorName: _getAuthorName,
                              );
                            },
                          ),
              ),

              // Input Field
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 12 + keyboardHeight + safeAreaBottom,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.glassBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: AppTextStyles.bodyMedium(
                            color: AppColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: AppColors.backgroundSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: _commentController.text.trim().isNotEmpty && !_isSendingComment
                            ? AppColors.accentPrimary
                            : AppColors.textSecondary,
                      ),
                      onPressed: _commentController.text.trim().isNotEmpty && !_isSendingComment
                          ? _addComment
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentItem extends StatelessWidget {
  final StatusComment comment;
  final bool isEditing;
  final bool isOwnComment;
  final TextEditingController? editController;
  final VoidCallback onStartEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onDelete;
  final String Function(StatusComment) getAuthorName;

  const _CommentItem({
    required this.comment,
    required this.isEditing,
    required this.isOwnComment,
    this.editController,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
    required this.getAuthorName,
  });

  @override
  Widget build(BuildContext context) {
    final authorName = getAuthorName(comment);
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 18,
            backgroundImage: comment.author?.profilePicture != null
                ? CachedNetworkImageProvider(comment.author!.profilePicture!)
                : null,
            backgroundColor: AppColors.backgroundSecondary,
            child: comment.author?.profilePicture == null
                ? Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textPrimary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEditing)
                  TextField(
                    controller: editController,
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    autofocus: true,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username
                      Text(
                        authorName,
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Comment Text
                      Text(
                        comment.content,
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      date_utils.DateUtils.timeAgo(comment.createdAt),
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (isOwnComment && !isEditing) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onStartEdit,
                        child: Text(
                          'Edit',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Comment'),
                              content: const Text('Are you sure you want to delete this comment?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onDelete();
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          'Delete',
                          style: AppTextStyles.bodySmall(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                    if (isEditing) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onSaveEdit,
                        child: Text(
                          'Save',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onCancelEdit,
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart' as date_utils;
import '../../../auth/data/providers/auth_provider.dart';
import '../../data/models/comment.dart';
import '../../data/services/comments_service.dart';

/// Professional Instagram-style comment drawer with improved UI/UX
class CommentDrawer extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final int initialCommentCount;

  const CommentDrawer({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.initialCommentCount,
  });

  @override
  State<CommentDrawer> createState() => _CommentDrawerState();
}

class _CommentDrawerState extends State<CommentDrawer> {
  final CommentsService _commentsService = CommentsService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _replyingToCommentId;
  String? _editingCommentId;
  final Map<String, TextEditingController> _editControllers = {};
  bool _isSendingComment = false;
  bool _isSendingReply = false;
  // Track which comments have their replies expanded and how many are shown
  final Map<String, bool> _expandedReplies = {}; // commentId -> isExpanded
  final Map<String, int> _loadedRepliesCount = {}; // commentId -> number of replies loaded

  @override
  void initState() {
    super.initState();
    _loadComments();
    _commentController.addListener(_onCommentChanged);
  }

  void _onCommentChanged() {
    setState(() {}); // Trigger rebuild for send button state
  }

  String _getReplyingToHint() {
    if (_replyingToCommentId == null) return 'Add a comment...';
    final comment = _comments.firstWhere(
      (c) => c.id == _replyingToCommentId,
      orElse: () => Comment(
        id: '',
        postId: widget.postId,
        userId: '',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    // Improved fallback logic for author name
    String authorName = 'Unknown';
    if (comment.author != null) {
      if (comment.author!.displayName != null && comment.author!.displayName!.isNotEmpty) {
        authorName = comment.author!.displayName!;
      } else if (comment.author!.username != null && comment.author!.username!.isNotEmpty) {
        authorName = comment.author!.username!;
      } else if (comment.author!.email != null && comment.author!.email!.isNotEmpty) {
        final emailParts = comment.author!.email!.split('@');
        if (emailParts.isNotEmpty && emailParts[0].isNotEmpty) {
          authorName = emailParts[0];
        }
      }
    }
    return 'Reply to $authorName...';
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

  Future<void> _loadComments({bool loadMore = false}) async {
    if (_isLoadingMore && loadMore) return;
    
    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _comments = [];
        _offset = 0;
      }
    });

    try {
      final response = await _commentsService.getComments(
        widget.postId,
        limit: 20,
        offset: loadMore ? _offset : 0,
      );

      if (response.success && response.data != null) {
        setState(() {
          if (loadMore) {
            _comments.addAll(response.data!.comments);
          } else {
            _comments = response.data!.comments;
          }
          _hasMore = response.data!.hasMore ?? false;
          _offset = _comments.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        if (mounted && !loadMore) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to load comments'),
              backgroundColor: AppColors.accentQuaternary,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted && !loadMore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading comments: ${e.toString()}'),
            backgroundColor: AppColors.accentQuaternary,
          ),
        );
      }
    }
  }

  Future<void> _addComment({String? parentCommentId}) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to comment'),
          backgroundColor: AppColors.accentQuaternary,
        ),
      );
      return;
    }

    // Set sending state
    if (parentCommentId != null) {
      setState(() => _isSendingReply = true);
    } else {
      setState(() => _isSendingComment = true);
    }

    // Optimistic update
    final tempComment = Comment(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      postId: widget.postId,
      userId: currentUser.id,
      parentCommentId: parentCommentId,
      content: text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      author: currentUser,
      isLiked: false,
      likesCount: 0,
      repliesCount: 0,
    );

    setState(() {
      if (parentCommentId != null) {
        // Add as reply
        final parentIndex = _comments.indexWhere((c) => c.id == parentCommentId);
        if (parentIndex != -1) {
          final parent = _comments[parentIndex];
          final updatedParent = Comment(
            id: parent.id,
            postId: parent.postId,
            userId: parent.userId,
            parentCommentId: parent.parentCommentId,
            content: parent.content,
            createdAt: parent.createdAt,
            updatedAt: parent.updatedAt,
            author: parent.author,
            isLiked: parent.isLiked,
            likesCount: parent.likesCount,
            repliesCount: (parent.repliesCount) + 1,
            replies: [
              ...(parent.replies ?? []),
              tempComment,
            ],
          );
          _comments[parentIndex] = updatedParent;
        }
        _commentController.clear();
        _replyingToCommentId = null;
        _commentFocusNode.unfocus();
      } else {
        _comments.insert(0, tempComment);
        _commentController.clear();
        _replyingToCommentId = null;
        _commentFocusNode.unfocus();
      }
    });

    try {
      final response = await _commentsService.createComment(
        postId: widget.postId,
        parentCommentId: parentCommentId,
        content: text,
      );

      if (response.success && response.data != null) {
        setState(() {
          if (parentCommentId != null) {
            final parentIndex = _comments.indexWhere((c) => c.id == parentCommentId);
            if (parentIndex != -1) {
              final parent = _comments[parentIndex];
              final updatedReplies = (parent.replies ?? []).map((r) {
                if (r.id == tempComment.id) return response.data!;
                return r;
              }).toList();
              final updatedParent = Comment(
                id: parent.id,
                postId: parent.postId,
                userId: parent.userId,
                parentCommentId: parent.parentCommentId,
                content: parent.content,
                createdAt: parent.createdAt,
                updatedAt: parent.updatedAt,
                author: parent.author,
                isLiked: parent.isLiked,
                likesCount: parent.likesCount,
                repliesCount: updatedReplies.length,
                replies: updatedReplies,
              );
              _comments[parentIndex] = updatedParent;
            }
          } else {
            final index = _comments.indexWhere((c) => c.id == tempComment.id);
            if (index != -1) {
              _comments[index] = response.data!;
            }
          }
          _isSendingComment = false;
          _isSendingReply = false;
        });
      } else {
        // Revert optimistic update
        setState(() {
          _isSendingComment = false;
          _isSendingReply = false;
        });
        _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to post comment'),
              backgroundColor: AppColors.accentQuaternary,
            ),
          );
        }
      }
    } catch (e) {
      // Revert optimistic update
      setState(() {
        _isSendingComment = false;
        _isSendingReply = false;
      });
      _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.accentQuaternary,
          ),
        );
      }
    }
  }

  Future<void> _likeComment(String commentId, bool isLiked) async {
    setState(() {
      _updateCommentLike(commentId, !isLiked);
    });

    try {
      final response = isLiked
          ? await _commentsService.unlikeComment(commentId)
          : await _commentsService.likeComment(commentId);

      if (!response.success) {
        // Revert on error
        setState(() {
          _updateCommentLike(commentId, isLiked);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to update like'),
              backgroundColor: AppColors.accentQuaternary,
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _updateCommentLike(commentId, isLiked);
      });
    }
  }

  void _updateCommentLike(String commentId, bool isLiked) {
    for (int i = 0; i < _comments.length; i++) {
      if (_comments[i].id == commentId) {
        _comments[i] = Comment(
          id: _comments[i].id,
          postId: _comments[i].postId,
          userId: _comments[i].userId,
          parentCommentId: _comments[i].parentCommentId,
          content: _comments[i].content,
          createdAt: _comments[i].createdAt,
          updatedAt: _comments[i].updatedAt,
          author: _comments[i].author,
          isLiked: isLiked,
          likesCount: _comments[i].likesCount + (isLiked ? 1 : -1),
          repliesCount: _comments[i].repliesCount,
          replies: _comments[i].replies,
        );
        return;
      }
      // Check replies
      if (_comments[i].replies != null) {
        final updatedReplies = _comments[i].replies!.map((reply) {
          if (reply.id == commentId) {
            return Comment(
              id: reply.id,
              postId: reply.postId,
              userId: reply.userId,
              parentCommentId: reply.parentCommentId,
              content: reply.content,
              createdAt: reply.createdAt,
              updatedAt: reply.updatedAt,
              author: reply.author,
              isLiked: isLiked,
              likesCount: reply.likesCount + (isLiked ? 1 : -1),
              repliesCount: reply.repliesCount,
            );
          }
          return reply;
        }).toList();
        _comments[i] = Comment(
          id: _comments[i].id,
          postId: _comments[i].postId,
          userId: _comments[i].userId,
          parentCommentId: _comments[i].parentCommentId,
          content: _comments[i].content,
          createdAt: _comments[i].createdAt,
          updatedAt: _comments[i].updatedAt,
          author: _comments[i].author,
          isLiked: _comments[i].isLiked,
          likesCount: _comments[i].likesCount,
          repliesCount: _comments[i].repliesCount,
          replies: updatedReplies,
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;

    // Optimistic delete
    setState(() {
      _comments.removeWhere((c) => c.id == commentId);
      // Also remove from replies
      for (int i = 0; i < _comments.length; i++) {
        if (_comments[i].replies != null) {
          final updatedReplies = _comments[i].replies!.where((r) => r.id != commentId).toList();
          if (updatedReplies.length != _comments[i].replies!.length) {
            _comments[i] = Comment(
              id: _comments[i].id,
              postId: _comments[i].postId,
              userId: _comments[i].userId,
              parentCommentId: _comments[i].parentCommentId,
              content: _comments[i].content,
              createdAt: _comments[i].createdAt,
              updatedAt: _comments[i].updatedAt,
              author: _comments[i].author,
              isLiked: _comments[i].isLiked,
              likesCount: _comments[i].likesCount,
              repliesCount: updatedReplies.length,
              replies: updatedReplies,
            );
          }
        }
      }
    });

    try {
      final response = await _commentsService.deleteComment(commentId);
      if (!response.success) {
        // Reload on error
        _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to delete comment'),
              backgroundColor: AppColors.accentQuaternary,
            ),
          );
        }
      }
    } catch (e) {
      // Reload on error
      _loadComments();
    }
  }

  Future<void> _updateComment(String commentId, String newContent) async {
    if (newContent.trim().isEmpty) return;

    // Optimistic update
    setState(() {
      for (int i = 0; i < _comments.length; i++) {
        if (_comments[i].id == commentId) {
          _comments[i] = Comment(
            id: _comments[i].id,
            postId: _comments[i].postId,
            userId: _comments[i].userId,
            parentCommentId: _comments[i].parentCommentId,
            content: newContent,
            createdAt: _comments[i].createdAt,
            updatedAt: DateTime.now(),
            author: _comments[i].author,
            isLiked: _comments[i].isLiked,
            likesCount: _comments[i].likesCount,
            repliesCount: _comments[i].repliesCount,
            replies: _comments[i].replies,
            isEdited: true,
            editedAt: DateTime.now(),
          );
          break;
        }
      }
      _editingCommentId = null;
      _editControllers[commentId]?.dispose();
      _editControllers.remove(commentId);
    });

    try {
      final response = await _commentsService.updateComment(
        commentId: commentId,
        content: newContent,
      );
      if (response.success && response.data != null) {
        setState(() {
          final index = _comments.indexWhere((c) => c.id == commentId);
          if (index != -1) {
            _comments[index] = response.data!;
          }
        });
      } else {
        _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to update comment'),
              backgroundColor: AppColors.accentQuaternary,
            ),
          );
        }
      }
    } catch (e) {
      _loadComments();
    }
  }

  void _startEditing(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _editControllers[comment.id] = TextEditingController(text: comment.content);
    });
  }

  void _cancelEditing() {
    setState(() {
      final editingId = _editingCommentId;
      _editingCommentId = null;
      if (editingId != null) {
        _editControllers[editingId]?.dispose();
        _editControllers.remove(editingId);
      }
    });
  }

  void _toggleReplies(String commentId) {
    setState(() {
      final isExpanded = _expandedReplies[commentId] ?? false;
      _expandedReplies[commentId] = !isExpanded;
      
      if (!isExpanded) {
        // When expanding, load first 5 replies
        final commentIndex = _comments.indexWhere((c) => c.id == commentId);
        if (commentIndex != -1) {
          final comment = _comments[commentIndex];
          final totalReplies = comment.replies?.length ?? 0;
          _loadedRepliesCount[commentId] = totalReplies > 5 ? 5 : totalReplies;
        }
      }
    });
  }

  void _loadMoreReplies(String commentId) {
    setState(() {
      final currentLoaded = _loadedRepliesCount[commentId] ?? 0;
      final commentIndex = _comments.indexWhere((c) => c.id == commentId);
      if (commentIndex != -1) {
        final comment = _comments[commentIndex];
        final totalReplies = comment.replies?.length ?? 0;
        final nextLoad = currentLoaded + 5;
        _loadedRepliesCount[commentId] = nextLoad > totalReplies ? totalReplies : nextLoad;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
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
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight + safeAreaBottom),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Comments',
                        style: AppTextStyles.bodyLarge(
                          weight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                        color: AppColors.textPrimary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Comments list
                Expanded(
                  child: _isLoading
                      ? Center(
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
                                    color: AppColors.textTertiary,
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
                                      color: AppColors.textTertiary,
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
                                  if (_isLoadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }
                                return _CommentItem(
                                  comment: _comments[index],
                                  currentUserId: currentUser?.id,
                                  onLike: (commentId, isLiked) => _likeComment(commentId, isLiked),
                                  onReply: (commentId) {
                                    setState(() {
                                      _replyingToCommentId = commentId;
                                    });
                                    _commentFocusNode.requestFocus();
                                  },
                                  onDelete: (commentId) => _deleteComment(commentId),
                                  onEdit: (comment) => _startEditing(comment),
                                  editingCommentId: _editingCommentId,
                                  editController: _editControllers[_comments[index].id],
                                  onUpdate: (commentId, content) => _updateComment(commentId, content),
                                  onCancelEdit: _cancelEditing,
                                  onProfileTap: (userId) {
                                    Navigator.of(context).pop();
                                    // TODO: Navigate to profile page
                                  },
                                  isRepliesExpanded: _expandedReplies[_comments[index].id] ?? false,
                                  loadedRepliesCount: _loadedRepliesCount[_comments[index].id] ?? 0,
                                  onToggleReplies: (commentId) => _toggleReplies(commentId),
                                  onLoadMoreReplies: (commentId) => _loadMoreReplies(commentId),
                                );
                              },
                            ),
                ),
                // Comment input (used for both comments and replies)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary.withOpacity(0.5),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.glassBorder.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (currentUser != null && currentUser!.profilePicture != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CachedNetworkImage(
                            imageUrl: currentUser!.profilePicture!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accentPrimary,
                                    AppColors.accentSecondary,
                                  ],
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accentPrimary,
                                    AppColors.accentSecondary,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accentPrimary,
                                AppColors.accentSecondary,
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          style: AppTextStyles.bodyMedium(),
                          decoration: InputDecoration(
                            hintText: _replyingToCommentId != null
                                ? _getReplyingToHint()
                                : 'Add a comment...',
                            hintStyle: AppTextStyles.bodyMedium(
                              color: AppColors.textTertiary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: AppColors.glassBorder.withOpacity(0.3),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            filled: true,
                            fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (_commentController.text.trim().isNotEmpty && 
                                !_isSendingComment && 
                                !_isSendingReply) {
                              _addComment(parentCommentId: _replyingToCommentId);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_replyingToCommentId != null)
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                          onPressed: () {
                            setState(() {
                              _replyingToCommentId = null;
                            });
                            _commentFocusNode.unfocus();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (_isSendingComment || _isSendingReply)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(
                            Icons.send_rounded,
                            color: _commentController.text.trim().isNotEmpty
                                ? AppColors.accentPrimary
                                : AppColors.textTertiary,
                          ),
                          onPressed: _commentController.text.trim().isNotEmpty && 
                                    !_isSendingComment && 
                                    !_isSendingReply
                              ? () => _addComment(parentCommentId: _replyingToCommentId)
                              : null,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final String? currentUserId;
  final Function(String, bool) onLike;
  final Function(String) onReply;
  final Function(String) onDelete;
  final Function(Comment) onEdit;
  final String? editingCommentId;
  final TextEditingController? editController;
  final Function(String, String) onUpdate;
  final VoidCallback onCancelEdit;
  final Function(String) onProfileTap;
  final bool isRepliesExpanded;
  final int loadedRepliesCount;
  final Function(String) onToggleReplies;
  final Function(String) onLoadMoreReplies;

  const _CommentItem({
    required this.comment,
    this.currentUserId,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onEdit,
    this.editingCommentId,
    this.editController,
    required this.onUpdate,
    required this.onCancelEdit,
    required this.onProfileTap,
    this.isRepliesExpanded = false,
    this.loadedRepliesCount = 0,
    required this.onToggleReplies,
    required this.onLoadMoreReplies,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnComment = comment.userId == currentUserId;
    final isEditing = editingCommentId == comment.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile picture
              GestureDetector(
                onTap: () => onProfileTap(comment.userId),
                child: comment.author?.profilePicture != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CachedNetworkImage(
                          imageUrl: comment.author!.profilePicture!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accentPrimary,
                                  AppColors.accentSecondary,
                                ],
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accentPrimary,
                                  AppColors.accentSecondary,
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentPrimary,
                              AppColors.accentSecondary,
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username with improved fallback
                    Text(
                      () {
                        final author = comment.author;
                        if (author == null) return 'Unknown';
                        if (author.displayName != null && author.displayName!.isNotEmpty) {
                          return author.displayName!;
                        }
                        if (author.username != null && author.username!.isNotEmpty) {
                          return author.username!;
                        }
                        if (author.email != null && author.email!.isNotEmpty) {
                          final emailParts = author.email!.split('@');
                          if (emailParts.isNotEmpty && emailParts[0].isNotEmpty) {
                            return emailParts[0];
                          }
                        }
                        return 'Unknown';
                      }(),
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Comment content on next line
                    Text(
                      comment.content,
                      style: AppTextStyles.bodyMedium(),
                    ),
                    const SizedBox(height: 6),
                    // Actions row
                    Row(
                      children: [
                        Text(
                          date_utils.DateUtils.timeAgo(comment.createdAt),
                          style: AppTextStyles.bodySmall(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        if (comment.isEdited) ...[
                          const SizedBox(width: 8),
                          Text(
                            'edited',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => onLike(comment.id, comment.isLiked),
                          child: Row(
                            children: [
                              Icon(
                                comment.isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: comment.isLiked
                                    ? AppColors.accentQuaternary
                                    : AppColors.textSecondary,
                              ),
                              if (comment.likesCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${comment.likesCount}',
                                  style: AppTextStyles.bodySmall(
                                    color: comment.isLiked
                                        ? AppColors.accentQuaternary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Only show Reply button for top-level comments (not replies)
                        if (comment.parentCommentId == null) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => onReply(comment.id),
                            child: Text(
                              'Reply',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        if (isOwnComment) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => onEdit(comment),
                            child: Text(
                              'Edit',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: AppColors.backgroundPrimary,
                                  title: Text(
                                    'Delete Comment',
                                    style: AppTextStyles.bodyLarge(weight: FontWeight.w600),
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete this comment?',
                                    style: AppTextStyles.bodyMedium(),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'Cancel',
                                        style: AppTextStyles.bodyMedium(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        onDelete(comment.id);
                                      },
                                      child: Text(
                                        'Delete',
                                        style: AppTextStyles.bodyMedium(
                                          color: AppColors.accentQuaternary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Text(
                              'Delete',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentQuaternary,
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
        ),
        // Replies section
        if (comment.replies != null && comment.replies!.isNotEmpty) ...[
          // Show "View replies" button when collapsed
          if (!isRepliesExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 64, top: 8),
              child: GestureDetector(
                onTap: () => onToggleReplies(comment.id),
                child: Text(
                  '${comment.replies!.length} ${comment.replies!.length == 1 ? 'reply' : 'replies'}, view them?',
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textSecondary,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Show replies when expanded
          if (isRepliesExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 64),
              child: Column(
                children: [
                  // Show loaded replies (up to loadedRepliesCount)
                  ...comment.replies!.take(loadedRepliesCount).map((reply) {
                    return _CommentItem(
                      comment: reply,
                      currentUserId: currentUserId,
                      onLike: onLike,
                      onReply: onReply,
                      onDelete: onDelete,
                      onEdit: onEdit,
                      editingCommentId: editingCommentId,
                      editController: editController,
                      onUpdate: onUpdate,
                      onCancelEdit: onCancelEdit,
                      onProfileTap: onProfileTap,
                      isRepliesExpanded: false,
                      loadedRepliesCount: 0,
                      onToggleReplies: onToggleReplies,
                      onLoadMoreReplies: onLoadMoreReplies,
                    );
                  }).toList(),
                  // "Load more replies" button if there are more replies
                  if (loadedRepliesCount < comment.replies!.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: GestureDetector(
                        onTap: () => onLoadMoreReplies(comment.id),
                        child: Text(
                          'Load more replies',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.accentPrimary,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // Hide replies button
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: GestureDetector(
                      onTap: () => onToggleReplies(comment.id),
                      child: Text(
                        'Hide replies',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        // Edit input
        if (isEditing && editController != null)
          Padding(
            padding: const EdgeInsets.only(left: 64, right: 16, top: 8, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: editController,
                    style: AppTextStyles.bodyMedium(),
                    decoration: InputDecoration(
                      hintText: 'Edit comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.glassBorder.withOpacity(0.3),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                    ),
                    maxLines: null,
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check, color: AppColors.accentPrimary),
                  onPressed: () {
                    onUpdate(comment.id, editController!.text);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: onCancelEdit,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

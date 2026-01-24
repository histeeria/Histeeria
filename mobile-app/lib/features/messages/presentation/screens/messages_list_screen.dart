import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/services/messages_service.dart';
import '../../data/services/messages_cache_service.dart';
import '../../data/models/conversation.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MessagesService _messagesService = MessagesService();
  final MessagesCacheService _cacheService = MessagesCacheService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  List<Conversation> _conversations = [];
  bool _isLoading = false; // Start with false - show cached data immediately
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversations(); // Load cached first, then refresh
  }

  Future<void> _loadConversations({bool showLoading = false}) async {
    // Load cached data first for instant display
    final cached = await _cacheService.getCachedConversations();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _conversations = cached;
        _isLoading = false;
      });
    } else if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // Fetch fresh data in background
    final response = await _messagesService.getConversations(
      limit: 20, // Reduced for faster loading
      offset: 0,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        if (response.success && response.data != null) {
          _conversations = response.data!;
          // Cache the fresh data
          _cacheService.cacheConversations(response.data!);
        } else {
          // Only show error if we don't have cached data
          if (_conversations.isEmpty) {
            _errorMessage = response.error ?? 'Failed to load conversations';
          }
        }
      });
    }
  }

  Future<void> _refreshConversations() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadConversations(showLoading: false);
  }

  // Helper method to format timestamp
  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}w';
    }
  }

  // Convert Conversation to UI format
  List<Map<String, dynamic>> _getConversationsForUI() {
    return _conversations.map((conv) {
      final otherUser = conv.otherUser;
      return {
        'conversationId': conv.id,
        'userId': otherUser?.id ?? conv.participant2Id,
        'name': otherUser?.displayName ?? 'Unknown User',
        'username': otherUser != null ? '@${otherUser.username}' : '@unknown',
        'avatar': otherUser?.profilePicture,
        'lastMessage': conv.lastMessageContent ?? '',
        'timestamp': _formatTimestamp(conv.lastMessageAt),
        'unreadCount': conv.unreadCount,
        'isOnline': conv.isOnline ?? false,
      };
    }).toList();
  }

  // Mock conversation data (fallback)
  final List<Map<String, dynamic>> _mockConversations = [
    {
      'userId': 'sarahj',
      'name': 'Sarah Johnson',
      'username': '@sarahj',
      'avatar': null,
      'lastMessage': 'Hey! How are you doing?',
      'timestamp': '2m',
      'unreadCount': 2,
      'isOnline': true,
    },
    {
      'userId': 'michaelc',
      'name': 'Michael Chen',
      'username': '@michaelc',
      'avatar': null,
      'lastMessage': 'Thanks for the help!',
      'timestamp': '1h',
      'unreadCount': 0,
      'isOnline': false,
    },
    {
      'userId': 'emmaw',
      'name': 'Emma Wilson',
      'username': '@emmaw',
      'avatar': null,
      'lastMessage': 'See you tomorrow!',
      'timestamp': '3h',
      'unreadCount': 1,
      'isOnline': true,
    },
    {
      'userId': 'davidb',
      'name': 'David Brown',
      'username': '@davidb',
      'avatar': null,
      'lastMessage': 'Great work on the project!',
      'timestamp': '5h',
      'unreadCount': 0,
      'isOnline': false,
    },
    {
      'userId': 'lisaa',
      'name': 'Lisa Anderson',
      'username': '@lisaa',
      'avatar': null,
      'lastMessage': 'Can we schedule a meeting?',
      'timestamp': '1d',
      'unreadCount': 3,
      'isOnline': true,
    },
    {
      'userId': 'jamest',
      'name': 'James Taylor',
      'username': '@jamest',
      'avatar': null,
      'lastMessage': 'Looking forward to working together!',
      'timestamp': '2d',
      'unreadCount': 0,
      'isOnline': false,
    },
    {
      'userId': 'oliviam',
      'name': 'Olivia Martinez',
      'username': '@oliviam',
      'avatar': null,
      'lastMessage': 'The design looks amazing!',
      'timestamp': '3d',
      'unreadCount': 1,
      'isOnline': true,
    },
    {
      'userId': 'robertl',
      'name': 'Robert Lee',
      'username': '@robertl',
      'avatar': null,
      'lastMessage': 'Thanks for the feedback',
      'timestamp': '4d',
      'unreadCount': 0,
      'isOnline': false,
    },
    {
      'userId': 'sophiag',
      'name': 'Sophia Garcia',
      'username': '@sophiag',
      'avatar': null,
      'lastMessage': 'When can we meet?',
      'timestamp': '5d',
      'unreadCount': 2,
      'isOnline': true,
    },
    {
      'userId': 'williamd',
      'name': 'William Davis',
      'username': '@williamd',
      'avatar': null,
      'lastMessage': 'Great job on the presentation!',
      'timestamp': '1w',
      'unreadCount': 0,
      'isOnline': false,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessagesMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MessagesMenuDialog(
        onOptionSelected: _handleMenuOption,
      ),
    );
  }

  void _handleMenuOption(String option) {
    // Handle menu option selection
    Navigator.pop(context); // Close the menu dialog
    
    // Show a snackbar or handle the action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(option),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.backgroundSecondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            context.push('/messages/new');
          },
          backgroundColor: AppColors.accentPrimary,
          child: const Icon(
            Icons.edit,
            color: Colors.white,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Header - Instagram style
              _MessagesHeader(
                onBack: () => context.pop(),
                onMenuTap: _showMessagesMenu,
              ),
              // Warning banner about messaging stability
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentQuaternary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.accentQuaternary.withOpacity(0.12),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    "Messages won't work great! After the end-to-end encryption, a lot of features are failing. We recommend using an alternative way of messaging until we solve this in the next update.",
                    style: AppTextStyles.bodySmall(color: AppColors.accentQuaternary),
                  ),
                ),
              ),
              // Conversations list with search bar
              Expanded(
                child: _isLoading && _conversations.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentPrimary,
                        ),
                      )
                    : _errorMessage != null && _conversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppColors.accentQuaternary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load conversations',
                                  style: AppTextStyles.headlineSmall(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () => _loadConversations(showLoading: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentPrimary,
                                  ),
                                  child: Text(
                                    'Retry',
                                    style: AppTextStyles.labelLarge(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshConversations,
                            color: AppColors.accentPrimary,
                            child: Stack(
                              children: [
                                _ConversationsList(
                                  conversations: _getConversationsForUI(),
                                  searchController: _searchController,
                                ),
                                if (_isRefreshing)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 3,
                                      child: LinearProgressIndicator(
                                        backgroundColor: Colors.transparent,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.accentPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onMenuTap;

  const _MessagesHeader({
    required this.onBack,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              // Back arrow
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title
              Expanded(
                child: Text(
                  'Messages',
                  style: AppTextStyles.headlineSmall(
                    weight: FontWeight.bold,
                  ),
                ),
              ),
              // Menu dots
              GestureDetector(
                onTap: onMenuTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.more_vert,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.glassBorder.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: TextField(
          controller: controller,
          style: AppTextStyles.bodyMedium(),
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: AppTextStyles.bodyMedium(
              color: AppColors.textTertiary,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppColors.textSecondary,
              size: 20,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            filled: false,
          ),
        ),
      ),
    );
  }
}

class _ConversationsList extends StatelessWidget {
  final List<Map<String, dynamic>> conversations;
  final TextEditingController searchController;

  const _ConversationsList({
    required this.conversations,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No messages yet',
              style: AppTextStyles.headlineSmall(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation',
              style: AppTextStyles.bodyMedium(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // Search bar (scrolls away)
        SliverToBoxAdapter(
          child: _SearchBar(controller: searchController),
        ),
        // Conversations list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) {
                return Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.glassBorder.withOpacity(0.1),
                  indent: 80,
                );
              }
              
              final conversationIndex = index ~/ 2;
        final conversation = conversations[conversationIndex];
        return _ConversationTile(
          name: conversation['name'] as String,
          username: conversation['username'] as String,
          lastMessage: conversation['lastMessage'] as String,
          timestamp: conversation['timestamp'] as String,
          unreadCount: conversation['unreadCount'] as int,
          isOnline: conversation['isOnline'] as bool,
          onTap: () {
            // Navigate to chat screen
            context.push(
              '/chat/${conversation['conversationId']}',
              extra: {
                'conversationId': conversation['conversationId'],
                'userName': conversation['name'],
                'userUsername': conversation['username'],
                'isOnline': conversation['isOnline'],
              },
            );
          },
        );
      },
      childCount: conversations.length * 2 - 1,
    ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String username;
  final String lastMessage;
  final String timestamp;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.username,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentPrimary.withOpacity(0.2),
                    border: Border.all(
                      color: AppColors.glassBorder.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppColors.accentPrimary,
                    size: 28,
                  ),
                ),
                // Online indicator
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.backgroundPrimary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.bodyLarge(
                            weight: unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timestamp,
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: AppTextStyles.bodyMedium(
                            color: unreadCount > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            weight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Messages Menu Dialog - Wheel animated dialog
class _MessagesMenuDialog extends StatefulWidget {
  final Function(String) onOptionSelected;

  const _MessagesMenuDialog({
    required this.onOptionSelected,
  });

  @override
  State<_MessagesMenuDialog> createState() => _MessagesMenuDialogState();
}

class _MessagesMenuDialogState extends State<_MessagesMenuDialog> {
  late final FixedExtentScrollController _scrollController;
  int _selectedIndex = 0;

  List<Map<String, dynamic>> get _menuOptions {
    return [
      {
        'icon': Icons.edit_outlined,
        'title': 'New Message',
        'message': 'New message feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.search,
        'title': 'Search',
        'message': 'Search messages feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.archive_outlined,
        'title': 'Archive All',
        'message': 'Archive all conversations feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.done_all,
        'title': 'Mark All as Read',
        'message': 'Mark all as read feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.notifications_outlined,
        'title': 'Notification Settings',
        'message': 'Notification settings feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.settings_outlined,
        'title': 'Message Settings',
        'message': 'Message settings feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.backup_outlined,
        'title': 'Chat Backup',
        'message': 'Chat backup feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.delete_sweep_outlined,
        'title': 'Clear All',
        'message': 'Clear all conversations feature coming soon',
        'isDestructive': true,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(initialItem: 0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSelection() {
    final option = _menuOptions[_selectedIndex];
    Navigator.pop(context); // Close the menu dialog
    widget.onOptionSelected(option['message'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: AppColors.glassBorder.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Wheel picker for menu options
          Container(
            height: 280,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                // Selection indicator overlay
                Center(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // Wheel picker
                ListWheelScrollView.useDelegate(
                  controller: _scrollController,
                  itemExtent: 50,
                  physics: const FixedExtentScrollPhysics(),
                  perspective: 0.003,
                  diameterRatio: 1.5,
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      if (index < 0 || index >= _menuOptions.length) {
                        return const SizedBox.shrink();
                      }
                      final option = _menuOptions[index];
                      final isSelected = index == _selectedIndex;

                      return _MessagesMenuWheelItem(
                        icon: option['icon'] as IconData,
                        title: option['title'] as String,
                        isSelected: isSelected,
                        isDestructive: option['isDestructive'] as bool,
                      );
                    },
                    childCount: _menuOptions.length,
                  ),
                ),
              ],
            ),
          ),
          // Select button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Select',
                  style: AppTextStyles.labelLarge(
                    color: AppColors.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesMenuWheelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool isDestructive;

  const _MessagesMenuWheelItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? (isDestructive
                      ? AppColors.accentQuaternary
                      : AppColors.accentPrimary)
                : AppColors.textSecondary.withOpacity(0.5),
            size: isSelected ? 28 : 22,
          ),
          const SizedBox(width: 12),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            style: isSelected
                ? AppTextStyles.headlineSmall(
                    color: isDestructive
                        ? AppColors.accentQuaternary
                        : AppColors.textPrimary,
                    weight: FontWeight.bold,
                  )
                : AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
            child: Text(title, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

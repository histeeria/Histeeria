import 'dart:async';
import '../../../../core/utils/app_logger.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../features/auth/data/providers/auth_provider.dart';
import '../../data/providers/messages_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/config/api_config.dart';
import '../../data/services/messages_service.dart';
import '../../data/services/messages_cache_service.dart';
import '../../data/services/e2ee_service.dart';
import '../../data/services/websocket_service.dart';
import '../../data/models/message.dart';
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
  final E2EEService _e2eeService = E2EEService();
  final WebSocketService _wsService = WebSocketService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  List<Conversation> _conversations = [];
  Map<String, String> _decryptedLastMessages = {};
  bool _isLoading = false; // Start with false - show cached data immediately
  bool _isRefreshing = false;
  String? _errorMessage;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations(); // Load cached first, then refresh
    _initializeWebSocket();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // Poll every 5 seconds for new messages while screen is active
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadConversations(showLoading: false);
      }
    });
  }

  Future<void> _initializeWebSocket() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUserId;
    AppLogger.debug('[MessagesListScreen] 🔌 Initializing WebSocket for user: $currentUserId');
    
    if (currentUserId == null) {
      AppLogger.debug('[MessagesListScreen] ❌ No current user ID - skipping WebSocket init');
      return;
    }

    // Connect WebSocket
    final connected = await _wsService.connect(currentUserId);
    AppLogger.debug('[MessagesListScreen] 🔌 WebSocket connect result: $connected, isConnected: ${_wsService.isConnected}');
    
    // Register global listener for real-time list updates
    _wsService.setGlobalHandler(_handleGlobalWebSocketMessage);
    AppLogger.debug('[MessagesListScreen] ✅ Global handler registered');
  }

  void _handleGlobalWebSocketMessage(WSMessageEnvelope envelope) {
    if (!mounted) return;

    AppLogger.debug('[MessagesListScreen] 🌐 GLOBAL HANDLER received: type=${envelope.type}, conversationId=${envelope.conversationId}');
    AppLogger.debug('[MessagesListScreen] 🌐 GLOBAL HANDLER data: ${envelope.data}');

    if (envelope.type == 'new_message') {
      try {
        final messageData = envelope.data as Map<String, dynamic>;
        AppLogger.debug('[MessagesListScreen] ✅ Parsing message data: $messageData');
        final message = Message.fromJson(messageData);
        AppLogger.debug('[MessagesListScreen] ✅ Message parsed successfully: id=${message.id}, content=${message.content}');
        _updateConversationWithNewMessage(message);
      } catch (e, stack) {
        AppLogger.debug('[MessagesListScreen] ❌ Error parsing real-time message: $e');
        AppLogger.debug('[MessagesListScreen] Stack: $stack');
      }
    }
  }

  Future<void> _updateConversationWithNewMessage(Message message) async {
    if (!mounted) return;

    setState(() {
      final index = _conversations.indexWhere((c) => c.id == message.conversationId);
      
      if (index != -1) {
        // Update existing conversation
        final updatedConv = _conversations[index].copyWith(
          lastMessageContent: message.content,
          lastMessageEncrypted: message.encryptedContent,
          lastMessageIv: message.iv,
          lastMessageAt: message.createdAt,
          lastMessageSenderId: message.senderId,
          unreadCount: message.isMine ? _conversations[index].unreadCount : _conversations[index].unreadCount + 1,
        );
        
        // Remove and re-insert at top
        _conversations.removeAt(index);
        _conversations.insert(0, updatedConv);
      } else {
        // Conversation not in list, might need full refresh or build new one
        // For simplicity, just refresh
        _loadConversations(showLoading: false);
      }
    });

    // Decrypt if E2EE
    if (message.encryptedContent != null && message.iv != null) {
      try {
        final decrypted = await _e2eeService.decrypt(
          message.encryptedContent!,
          message.iv!,
          message.conversationId,
        );
        
        if (mounted) {
          setState(() {
            _decryptedLastMessages[message.conversationId] = decrypted;
          });
        }
      } catch (e) {
        AppLogger.debug('[MessagesListScreen] Failed to decrypt real-time message: $e');
      }
    } else {
      if (mounted) {
        setState(() {
          _decryptedLastMessages[message.conversationId] = message.content;
        });
      }
    }

    // Cache updated list
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUserId != null) {
      _cacheService.cacheConversations(authProvider.currentUserId!, _conversations);
    }
  }

  Future<void> _loadConversations({bool showLoading = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUserId;
    if (currentUserId == null) return;

    // Load cached data first for instant display
    final cached = await _cacheService.getCachedConversations(currentUserId);
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _conversations = cached;
        _isLoading = false;
      });
      _decryptLastMessagesInBackground(cached);
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
      if (response.success && response.data != null) {
        // Refresh total unread count in provider
        try {
          final messagesProvider = Provider.of<MessagesProvider>(context, listen: false);
          messagesProvider.refreshUnreadCount();
        } catch (_) {}
        
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _conversations = response.data!;
          // Cache the fresh data
          _cacheService.cacheConversations(currentUserId, response.data!);
        });
        _decryptLastMessagesInBackground(response.data!);
      } else {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          // Only show error if we don't have cached data
          if (_conversations.isEmpty) {
            _errorMessage = response.error ?? 'Failed to load conversations';
          }
        });
      }
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

  /// Decrypt last messages in background for all conversations
  Future<void> _decryptLastMessagesInBackground(List<Conversation> conversations) async {
    for (final conv in conversations) {
      // Skip if already decrypted
      if (_decryptedLastMessages.containsKey(conv.id)) continue;

      // Handle encrypted last message
      if (conv.lastMessageEncrypted != null && conv.lastMessageIv != null) {
        try {
          final decrypted = await _e2eeService.decrypt(
            conv.lastMessageEncrypted!,
            conv.lastMessageIv!,
            conv.id,
          );
          
          if (mounted) {
            setState(() {
              _decryptedLastMessages[conv.id] = decrypted;
            });
          }
        } catch (e) {
          AppLogger.debug('[MessagesList] Failed to decrypt preview for ${conv.id}: $e');
          if (mounted) {
            setState(() {
              _decryptedLastMessages[conv.id] = 'Encrypted message';
            });
          }
        }
      } 
      // Fallback: If it's a legacy plaintext message or system message
      else if (conv.lastMessageContent != null && conv.lastMessageContent!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _decryptedLastMessages[conv.id] = conv.lastMessageContent!;
          });
        }
      }
    }
  }

  // Convert Conversation to UI format
  List<Map<String, dynamic>> _getConversationsForUI() {
    return _conversations.map((conv) {
      final otherUser = conv.otherUser;
      final rawAvatar = otherUser?.profilePicture;
      final resolvedAvatar = rawAvatar != null 
          ? ApiConfig.constructSupabaseStorageUrl(rawAvatar)
          : null;

      return {
        'conversationId': conv.id,
        'userId': otherUser?.id ?? conv.participant2Id,
        'name': otherUser?.displayName ?? 'Unknown User',
        'username': otherUser != null ? '@${otherUser.username}' : '@unknown',
        'avatar': resolvedAvatar,
        'lastMessage': _decryptedLastMessages[conv.id] ?? conv.lastMessageContent ?? '',
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
    _autoRefreshTimer?.cancel();
    _wsService.setGlobalHandler(null);
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

  void _showE2EEDetailDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            
            // Security Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.security_rounded,
                size: 40,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Your privacy is our priority',
              style: AppTextStyles.headlineSmall(
                weight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Description
            Text(
              'Histeeria protects your privacy with end-to-end encryption. This means your conversations are fully private and secure.',
              style: AppTextStyles.bodyLarge(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Feature list
            _buildPrivacyFeature(
              Icons.chat_bubble_outline_rounded,
              'Messages & Media',
              'Your chats, audios, videos, images, and files are only visible to you and the person you\'re talking to.',
            ),
            const SizedBox(height: 20),
            _buildPrivacyFeature(
              Icons.call_outlined,
              'Voice & Video Calls',
              'Your calls are secure. No one in the world, including Histeeria, can listen to or see them.',
            ),
            const SizedBox(height: 32),
            
            // Reassurance
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.glassBorder.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                   Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Not even Histeeria can access your data.',
                      style: AppTextStyles.bodySmall(
                        weight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Understood',
                  style: AppTextStyles.labelLarge(
                    color: Colors.white,
                    weight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyFeature(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 24,
          color: AppColors.accentPrimary,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyLarge(
                  weight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodySmall(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
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
                                  onE2EETap: _showE2EEDetailDrawer,
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
              // Current User Profile Photo
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  final user = authProvider.currentUser;
                  final profilePicture = user?.profilePicture;
                  
                  return Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.glassBorder.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: profilePicture != null && profilePicture.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profilePicture,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.accentPrimary.withOpacity(0.1),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.person,
                                size: 20,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 20,
                            color: AppColors.accentPrimary,
                          ),
                  );
                },
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
              // Back arrow (moved to right or kept as is? instructions just said add photo inside header... usually left)
              // I'll put photo on left, title in middle, menu on right.
              // Instagram has story circles... I'll just add it before title.
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
  final VoidCallback onE2EETap;

  const _ConversationsList({
    required this.conversations,
    required this.searchController,
    required this.onE2EETap,
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
        // E2EE Banner
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: onE2EETap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Your messages are '),
                        TextSpan(
                          text: 'end-to-end encrypted',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
          avatar: conversation['avatar'] as String?,
          lastMessage: conversation['lastMessage'] as String,
          timestamp: conversation['timestamp'] as String,
          unreadCount: conversation['unreadCount'] as int,
          isOnline: conversation['isOnline'] as bool,
          onTap: () {
            // Navigate to chat screen
            context.push(
              '/chat/${conversation['userId']}',
              extra: {
                'conversationId': conversation['conversationId'],
                'userName': conversation['name'],
                'userUsername': conversation['username'],
                'profilePicture': conversation['avatar'],
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
  final String? avatar;
  final String lastMessage;
  final String timestamp;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.username,
    this.avatar,
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
                  child: avatar != null && avatar!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatar!,
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                            placeholder: (context, url) => Center(
                              child: Icon(
                                Icons.person,
                                color: AppColors.accentPrimary,
                                size: 28,
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                Icons.person,
                                color: AppColors.accentPrimary,
                                size: 28,
                              ),
                            ),
                          ),
                        )
                      : Icon(
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

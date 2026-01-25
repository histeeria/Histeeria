import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../../../../features/auth/data/providers/auth_provider.dart';
import '../../../../features/auth/data/models/user.dart';
import '../../data/providers/messages_provider.dart';
import '../../data/services/messages_service.dart';
import '../../data/services/websocket_service.dart';
import '../../data/services/e2ee_service.dart';
import '../../data/services/deleted_messages_service.dart';
import '../../data/services/file_storage_service.dart';
import '../../data/services/audio_service.dart';
import '../../data/models/message.dart';
import '../../data/models/conversation.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/audio_message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userUsername;
  final String? profilePicture;
  final bool isOnline;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.profilePicture,
    required this.isOnline,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  // Services
  final MessagesService _messagesService = MessagesService();
  final WebSocketService _wsService = WebSocketService();
  final E2EEService _e2eeService = E2EEService();
  final DeletedMessagesService _deletedMessagesService = DeletedMessagesService();
  final FileStorageService _fileStorageService = FileStorageService();
  final AudioService _audioService = AudioService();
  final ImagePicker _imagePicker = ImagePicker();
  
  // Audio recording state
  bool _isRecordingAudio = false;
  bool _isRecordingLocked = false;
  String? _currentRecordingPath;
  StreamSubscription<Duration>? _recordingDurationSubscription;
  
  // State
  String? _conversationId;
  List<Message> _messages = [];
  final Map<String, Message> _pendingMessages = {}; // tempId -> Message
  final Map<String, Map<String, String>> _messageReactions = {}; // messageId -> {userId: emoji}
  Set<String> _deletedMessageIds = {}; // Locally deleted message IDs (for "Delete for Me")
  Set<String> _deletedForEveryoneIds = {}; // Locally deleted message IDs (for "Delete for Everyone")
  final Map<String, String> _decryptedMessagesMap = {}; // messageId -> decryptedContent
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  String? _currentUserId;
  Message? _replyingToMessage; // Message being replied to
  
  // Forward state
  bool _isSelectionMode = false; // Multi-message selection mode
  final Set<String> _selectedMessageIds = {}; // Selected message IDs for forwarding
  
  // File upload/download state
  final Map<String, double> _uploadProgress = {}; // messageId -> progress (0.0 to 1.0)
  final Map<String, double> _downloadProgress = {}; // messageId -> progress (0.0 to 1.0)
  final Map<String, CancelToken> _uploadCancelTokens = {}; // messageId -> CancelToken
  
  // WebSocket subscription
  StreamSubscription? _wsSubscription;

  // Messages list (for UI compatibility)
  List<Map<String, dynamic>> get _messagesForUI {
    return _messages.map((msg) {
      // Find replied-to message if exists
      Message? repliedToMessage;
      if (msg.replyToId != null && msg.replyToId!.isNotEmpty) {
        try {
          repliedToMessage = _messages.firstWhere(
            (m) => m.id == msg.replyToId,
          );
          print('[ChatScreen] Found replied-to message for ${msg.id}: replyToId=${msg.replyToId}, found=${repliedToMessage.id}');
        } catch (e) {
          // Message not found - might be from another conversation or not loaded yet
          print('[ChatScreen] Replied-to message not found for ${msg.id}: replyToId=${msg.replyToId}, error=$e');
          repliedToMessage = null;
        }
      } else {
        print('[ChatScreen] Message ${msg.id} has no replyToId');
      }
      
      return {
        'id': msg.id,
        'text': _decryptedMessagesMap[msg.id] ?? msg.content,
        'isMe': msg.isMine,
        'timestamp': msg.createdAt,
        'status': msg.status,
        'deliveredAt': msg.deliveredAt,
        'readAt': msg.readAt,
        'editedAt': msg.editedAt,
        'editCount': msg.editCount,
        'messageType': msg.messageType,
        'attachmentUrl': msg.attachmentUrl,
        'attachmentName': msg.attachmentName,
        'attachmentSize': msg.attachmentSize,
        'attachmentType': msg.attachmentType,
        'reactions': {
          ...?(msg.reactions),
          ...(_messageReactions[msg.id] ?? {}),
        },
        'isStarred': msg.isStarred ?? false,
        'isPinned': msg.isPinned ?? false,
        'replyToId': msg.replyToId,
        'repliedToMessage': repliedToMessage,
        'message': msg, // Store full message object
      };
    }).toList();
  }

  // Mock messages (fallback)
  final List<Map<String, dynamic>> _mockMessages = [
    {
      'id': '1',
      'text': 'Hey! How are you doing?',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      'reactions': <String, String>{}, // userId -> emoji
      'isStarred': false,
      'isPinned': false,
    },
    {
      'id': '2',
      'text': 'I\'m doing great! Thanks for asking. How about you?',
      'isMe': true,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 4)),
      'reactions': <String, String>{},
      'isStarred': false,
      'isPinned': false,
    },
    {
      'id': '3',
      'text': 'I\'m good too! Just working on some projects.',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 3)),
      'reactions': <String, String>{},
      'isStarred': false,
      'isPinned': false,
    },
    {
      'id': '4',
      'text': 'That sounds interesting! What kind of projects?',
      'isMe': true,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 2)),
      'reactions': <String, String>{},
      'isStarred': false,
      'isPinned': false,
    },
    {
      'id': '5',
      'text':
          'Mostly mobile app development. Working on a new social platform.',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 1)),
      'reactions': <String, String>{},
      'isStarred': false,
      'isPinned': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Get current user ID
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.currentUser?.id;
    
    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    // Connect WebSocket
    await _wsService.connect(_currentUserId!);
    _wsService.addConnectionListener(_onWebSocketConnectionChanged);

    // Get or create conversation
    await _loadOrCreateConversation();

    // Load messages
    if (_conversationId != null) {
      await _loadMessages();
      
      // Subscribe to WebSocket messages for this conversation
      _wsService.subscribeToConversation(_conversationId!, _handleWebSocketMessage);
      
      // Mark as read
      _messagesService.markAsRead(_conversationId!).then((_) {
        // Refresh total unread count in provider
        try {
          final messagesProvider = Provider.of<MessagesProvider>(context, listen: false);
          messagesProvider.refreshUnreadCount();
        } catch (_) {}
      });
    } else {
      // If we couldn't get a conversation, we must stop loading
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrCreateConversation() async {
    try {
      // UUIDs have format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (36 chars with dashes)
      final isUUID = widget.userId.length == 36 && widget.userId.contains('-');
      
      if (isUUID) {
        // First try to treat as userId and start/get conversation
        // This is more robust as clicking from profile usually provides a userId
        final response = await _messagesService.startConversation(widget.userId);
        if (response.success && response.data != null) {
          setState(() {
            _conversationId = response.data!.id;
          });
          return;
        }

        // If that fails, try to load it as a direct conversation ID
        final convResponse = await _messagesService.getConversation(widget.userId);
        if (convResponse.success && convResponse.data != null) {
          setState(() {
            _conversationId = convResponse.data!.id;
          });
          return;
        }
      } 
      
      // Fallback or non-UUID
      await _createNewConversation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load conversation: ${e.toString()}';
      });
    }
  }

  Future<void> _createNewConversation() async {
    final response = await _messagesService.startConversation(widget.userId);
    if (response.success && response.data != null) {
      setState(() {
        _conversationId = response.data!.id;
      });
    } else {
      setState(() {
        _errorMessage = response.error ?? 'Failed to create conversation';
      });
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load locally deleted message IDs
      _deletedMessageIds = await _deletedMessagesService.getDeletedMessageIds(_conversationId!);
      _deletedForEveryoneIds = await _deletedMessagesService.getDeletedForEveryoneIds(_conversationId!);
      
      print('[ChatScreen] Loaded deleted message IDs - For Me: ${_deletedMessageIds.length}, For Everyone: ${_deletedForEveryoneIds.length}');
      
      final response = await _messagesService.getMessages(_conversationId!);
      
      if (response.success && response.data != null) {
        print('[ChatScreen] Loaded ${response.data!.length} messages from API');
        
        // Extract reactions from messages by making a direct API call
        // The backend includes reactions in the message response
        await _loadReactionsFromAPI();
        
        // Backend returns messages in descending order (newest first), reverse to show oldest first (newest at bottom)
        final reversedMessages = response.data!.reversed.toList();
        
        // Filter out locally deleted messages (Delete for Me) and mark deleted for everyone
        final filteredMessages = reversedMessages.map((msg) {
          print('[ChatScreen] Processing message ${msg.id}, type: ${msg.messageType}, attachmentUrl: ${msg.attachmentUrl}, attachmentName: ${msg.attachmentName}');
          // Filter out "Delete for Me" messages
          if (_deletedMessageIds.contains(msg.id)) {
            return null;
          }
          
          // Mark as deleted if in "Delete for Everyone" list
          if (_deletedForEveryoneIds.contains(msg.id)) {
            return Message(
              id: msg.id,
              conversationId: msg.conversationId,
              senderId: msg.senderId,
              content: msg.content,
              encryptedContent: msg.encryptedContent,
              iv: msg.iv,
              messageType: msg.messageType,
              status: msg.status,
              deliveredAt: msg.deliveredAt,
              readAt: msg.readAt,
              replyToId: msg.replyToId,
              createdAt: msg.createdAt,
              updatedAt: msg.updatedAt,
              editedAt: msg.editedAt,
              editCount: msg.editCount,
              isForwarded: msg.isForwarded,
              isDeleted: true,
              deletedAt: msg.deletedAt ?? DateTime.now(),
              deletedFor: 'everyone',
              isMine: msg.isMine,
              sender: msg.sender,
              isStarred: msg.isStarred,
              isPinned: msg.isPinned,
              // Preserve attachment fields for document messages
              attachmentUrl: msg.attachmentUrl,
              attachmentName: msg.attachmentName,
              attachmentSize: msg.attachmentSize,
              attachmentType: msg.attachmentType,
            );
          }
          
          return msg;
        }).where((msg) => msg != null).cast<Message>().toList();
        
        // Set messages immediately (show encrypted content if needed)
        // Sort messages by timestamp (oldest to newest, so newest appear at bottom like WhatsApp)
        filteredMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        print('[ChatScreen] Setting ${filteredMessages.length} filtered messages to state');
        setState(() {
          _messages = filteredMessages;
          _isLoading = false;
        });

        // Scroll to bottom immediately after setting messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottomImmediate();
          
          // Second pass after a short delay to account for potential image/layout shifts
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _scrollToBottomImmediate();
          });
        });

        // Decrypt messages in background (non-blocking)
        _decryptMessagesInBackground(filteredMessages);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = response.error ?? 'Failed to load messages';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load messages: ${e.toString()}';
      });
    }
  }

  /// Load reactions from API for all messages
  Future<void> _loadReactionsFromAPI() async {
    if (_conversationId == null) return;
    
    try {
      // Use Dio directly to get raw response with reactions
      // Access the ApiClient's dio instance
      final apiClient = ApiClient();
      final dio = apiClient.dio;
      final response = await dio.get<Map<String, dynamic>>(
        '/conversations/$_conversationId/messages',
        queryParameters: {'limit': 50, 'offset': 0},
      );
      
      if (response.data != null && response.data!['success'] == true) {
        final messagesList = response.data!['messages'] as List<dynamic>?;
        if (messagesList != null) {
          for (final msgJson in messagesList) {
            if (msgJson is Map<String, dynamic>) {
              final messageId = msgJson['id'] as String?;
              final reactions = msgJson['reactions'] as List<dynamic>?;
              if (messageId != null && reactions != null && reactions.isNotEmpty) {
                final messageReactions = <String, String>{};
                for (final reaction in reactions) {
                  if (reaction is Map<String, dynamic>) {
                    final userId = reaction['user_id'] as String?;
                    final emoji = reaction['emoji'] as String?;
                    if (userId != null && emoji != null) {
                      messageReactions[userId] = emoji;
                    }
                  }
                }
                if (messageReactions.isNotEmpty) {
                  setState(() {
                    _messageReactions[messageId] = messageReactions;
                  });
                  print('[ChatScreen] Loaded reactions for message $messageId: $messageReactions');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('[ChatScreen] Failed to load reactions: $e');
    }
  }

  /// Decrypt messages in background without blocking UI
  Future<void> _decryptMessagesInBackground(List<Message> messages) async {
    print('[ChatScreen] Decrypting ${messages.length} messages in background');
    // Decrypt messages that need decryption
    final decryptedResults = await Future.wait(
      messages.map((msg) async {
        if (msg.encryptedContent == null || msg.encryptedContent!.isEmpty) {
          return MapEntry(msg.id, msg.content);
        }
        try {
          final decrypted = await _e2eeService.decrypt(
            msg.encryptedContent!,
            msg.iv!,
            _conversationId!,
          );
          return MapEntry(msg.id, decrypted);
        } catch (e) {
          print('[ChatScreen] Decryption failed for ${msg.id}: $e');
          return MapEntry(msg.id, 'Encrypted message');
        }
      }),
    );

    if (mounted) {
      setState(() {
        for (final entry in decryptedResults) {
          _decryptedMessagesMap[entry.key] = entry.value;
        }
      });
    }
  }

  Future<Message> _decryptMessageIfNeeded(Message message) async {
    // Check if message is deleted locally (for everyone) - preserve this state
    final isDeletedForEveryone = _deletedForEveryoneIds.contains(message.id);
    
    // If message is encrypted, decrypt it
    if (message.encryptedContent != null && 
        message.encryptedContent!.isNotEmpty && 
        message.iv != null &&
        _conversationId != null) {
      try {
        final decryptedContent = await _e2eeService.decrypt(
          message.encryptedContent!,
          message.iv!,
          _conversationId!,
        );
        
        // Return message with decrypted content - preserve ALL fields including deleted state and attachments
        return Message(
          id: message.id,
          conversationId: message.conversationId,
          senderId: message.senderId,
          content: decryptedContent,
          encryptedContent: message.encryptedContent,
          iv: message.iv,
          messageType: message.messageType,
          status: message.status,
          deliveredAt: message.deliveredAt,
          readAt: message.readAt,
          replyToId: message.replyToId,
          createdAt: message.createdAt,
          updatedAt: message.updatedAt,
          editedAt: message.editedAt,
          editCount: message.editCount,
          isForwarded: message.isForwarded,
          isDeleted: isDeletedForEveryone || message.isDeleted, // Check local deleted list OR preserve from message
          deletedAt: isDeletedForEveryone ? (message.deletedAt ?? DateTime.now()) : message.deletedAt,
          deletedFor: isDeletedForEveryone ? 'everyone' : message.deletedFor,
          isMine: message.isMine,
          sender: message.sender,
          isStarred: message.isStarred,
          isPinned: message.isPinned,
          // Preserve attachment fields
          attachmentUrl: message.attachmentUrl,
          attachmentName: message.attachmentName,
          attachmentSize: message.attachmentSize,
          attachmentType: message.attachmentType,
        );
      } catch (e) {
        print('[ChatScreen] Decryption error: $e');
        // Return original message if decryption fails, but still check deleted state
        if (isDeletedForEveryone) {
          return Message(
            id: message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            content: message.content,
            encryptedContent: message.encryptedContent,
            iv: message.iv,
            messageType: message.messageType,
            status: message.status,
            deliveredAt: message.deliveredAt,
            readAt: message.readAt,
            replyToId: message.replyToId,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
            editedAt: message.editedAt,
            editCount: message.editCount,
            isForwarded: message.isForwarded,
            isDeleted: true,
            deletedAt: message.deletedAt ?? DateTime.now(),
            deletedFor: 'everyone',
            isMine: message.isMine,
            sender: message.sender,
            isStarred: message.isStarred,
            isPinned: message.isPinned,
            // Preserve attachment fields
            attachmentUrl: message.attachmentUrl,
            attachmentName: message.attachmentName,
            attachmentSize: message.attachmentSize,
            attachmentType: message.attachmentType,
          );
        }
        return message;
      }
    }
    
    // Message is not encrypted, but still check deleted state
    if (isDeletedForEveryone) {
      return Message(
        id: message.id,
        conversationId: message.conversationId,
        senderId: message.senderId,
        content: message.content,
        encryptedContent: message.encryptedContent,
        iv: message.iv,
        messageType: message.messageType,
        status: message.status,
        deliveredAt: message.deliveredAt,
        readAt: message.readAt,
        replyToId: message.replyToId,
        createdAt: message.createdAt,
        updatedAt: message.updatedAt,
        editedAt: message.editedAt,
        editCount: message.editCount,
        isForwarded: message.isForwarded,
        isDeleted: true,
        deletedAt: message.deletedAt ?? DateTime.now(),
        deletedFor: 'everyone',
        isMine: message.isMine,
        sender: message.sender,
        isStarred: message.isStarred,
        isPinned: message.isPinned,
        // Preserve attachment fields
        attachmentUrl: message.attachmentUrl,
        attachmentName: message.attachmentName,
        attachmentSize: message.attachmentSize,
        attachmentType: message.attachmentType,
      );
    }
    
    return message;
  }

  void _onWebSocketConnectionChanged(bool connected) {
    if (mounted) {
      setState(() {
        // Update connection state if needed
      });
    }
  }

  void _handleWebSocketMessage(WSMessageEnvelope envelope) {
    print('[ChatScreen] Received WebSocket message: type=${envelope.type}, channel=${envelope.channel}, conversationId=${envelope.conversationId}');
    
    // Only handle messages for this conversation
    if (envelope.conversationId != _conversationId) {
      print('[ChatScreen] Ignoring message for different conversation: ${envelope.conversationId}');
      return;
    }
    
    switch (envelope.type) {
      case 'new_message':
        _handleNewMessage(envelope);
        break;
      case 'message_read':
        _handleMessageRead(envelope);
        break;
      case 'message_delivered':
        _handleMessageDelivered(envelope);
        break;
      case 'message_edited':
        _handleMessageEdited(envelope);
        break;
      case 'message_deleted':
        _handleMessageDeleted(envelope);
        break;
      case 'message_reaction':
        _handleMessageReaction(envelope);
        break;
      case 'message_reaction_removed':
        _handleMessageReactionRemoved(envelope);
        break;
      case 'typing':
      case 'stop_typing':
        // Typing indicators - can be implemented later
        print('[ChatScreen] Typing indicator: ${envelope.type}');
        break;
      default:
        print('[ChatScreen] Unhandled WebSocket message type: ${envelope.type}');
    }
  }
  
  void _handleNewMessage(WSMessageEnvelope envelope) {
    if (envelope.data == null) {
      print('[ChatScreen] New message envelope has no data');
      return;
    }
    
      try {
        final messageData = envelope.data as Map<String, dynamic>;
        
        // Set isMine based on sender ID
        if (_currentUserId != null) {
          messageData['is_mine'] = messageData['sender_id'] == _currentUserId;
        }
        
        final message = Message.fromJson(messageData);
      final isMyMessage = message.senderId == _currentUserId;
      
      print('[ChatScreen] WebSocket new_message: id=${message.id}, replyToId=${message.replyToId}, isMyMessage=$isMyMessage');
      
      // Send ACK to backend
      _wsService.sendAck(envelope.id);
        
        // Decrypt if needed
        _decryptMessageIfNeeded(message).then((decryptedMessage) {
          if (mounted) {
            // Skip if message is in deleted list (Delete for Me)
            if (_deletedMessageIds.contains(decryptedMessage.id)) {
              print('[ChatScreen] Skipping deleted message (for me): ${decryptedMessage.id}');
              return;
            }
            
            // Mark as deleted if in "Delete for Everyone" list
            if (_deletedForEveryoneIds.contains(decryptedMessage.id)) {
              print('[ChatScreen] Marking WebSocket message as deleted (for everyone): ${decryptedMessage.id}');
              decryptedMessage = Message(
                id: decryptedMessage.id,
                conversationId: decryptedMessage.conversationId,
                senderId: decryptedMessage.senderId,
                content: decryptedMessage.content,
                encryptedContent: decryptedMessage.encryptedContent,
                iv: decryptedMessage.iv,
                messageType: decryptedMessage.messageType,
                status: decryptedMessage.status,
                deliveredAt: decryptedMessage.deliveredAt,
                readAt: decryptedMessage.readAt,
                replyToId: decryptedMessage.replyToId,
                createdAt: decryptedMessage.createdAt,
                updatedAt: decryptedMessage.updatedAt,
                editedAt: decryptedMessage.editedAt,
                editCount: decryptedMessage.editCount,
                isForwarded: decryptedMessage.isForwarded,
                isDeleted: true,
                deletedAt: decryptedMessage.deletedAt ?? DateTime.now(),
                deletedFor: 'everyone',
                isMine: decryptedMessage.isMine,
                sender: decryptedMessage.sender,
                isStarred: decryptedMessage.isStarred,
                isPinned: decryptedMessage.isPinned,
              );
            }
            
            setState(() {
              // Check if message already exists (avoid duplicates)
              final existingIndex = _messages.indexWhere((m) => m.id == decryptedMessage.id);
              
              if (existingIndex == -1) {
              // Check if this is replacing a pending message (by content match for my messages)
              if (isMyMessage) {
              final pendingEntry = _pendingMessages.entries.firstWhere(
                (entry) => entry.value.senderId == decryptedMessage.senderId &&
                           entry.value.content == decryptedMessage.content &&
                           entry.value.replyToId == decryptedMessage.replyToId,
                  orElse: () => MapEntry('', Message(
                  id: '',
                  conversationId: '',
                  senderId: '',
                  content: '',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
                )),
              );
              
              if (pendingEntry.key.isNotEmpty) {
                  // Replace pending message - preserve reply_to_id
                  final pendingIndex = _messages.indexWhere((m) => m.id == pendingEntry.key);
                  if (pendingIndex != -1) {
                    // Ensure reply_to_id and attachment fields are preserved
                    final finalMessage = decryptedMessage.replyToId != null && 
                                         decryptedMessage.attachmentUrl != null
                        ? decryptedMessage
                        : Message(
                            id: decryptedMessage.id,
                            conversationId: decryptedMessage.conversationId,
                            senderId: decryptedMessage.senderId,
                            content: decryptedMessage.content,
                            encryptedContent: decryptedMessage.encryptedContent,
                            iv: decryptedMessage.iv,
                            messageType: decryptedMessage.messageType,
                            status: decryptedMessage.status,
                            deliveredAt: decryptedMessage.deliveredAt,
                            readAt: decryptedMessage.readAt,
                            replyToId: pendingEntry.value.replyToId ?? decryptedMessage.replyToId,
                            createdAt: decryptedMessage.createdAt,
                            updatedAt: decryptedMessage.updatedAt,
                            editedAt: decryptedMessage.editedAt,
                            editCount: decryptedMessage.editCount,
                            isForwarded: decryptedMessage.isForwarded,
                            sender: decryptedMessage.sender,
                            isMine: decryptedMessage.isMine,
                            isStarred: decryptedMessage.isStarred,
                            isPinned: decryptedMessage.isPinned,
                            // Preserve attachment fields from pending message or use from decrypted
                            attachmentUrl: decryptedMessage.attachmentUrl ?? pendingEntry.value.attachmentUrl,
                            attachmentName: decryptedMessage.attachmentName ?? pendingEntry.value.attachmentName,
                            attachmentSize: decryptedMessage.attachmentSize ?? pendingEntry.value.attachmentSize,
                            attachmentType: decryptedMessage.attachmentType ?? pendingEntry.value.attachmentType,
                          );
                    _messages[pendingIndex] = finalMessage;
                _pendingMessages.remove(pendingEntry.key);
                    print('[ChatScreen] Replaced pending message: ${pendingEntry.key}, replyToId: ${finalMessage.replyToId}');
                  } else {
                    // Pending message not found, add new one
                    _messages.add(decryptedMessage);
                    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                    print('[ChatScreen] Added new message (pending not found): ${decryptedMessage.id}');
                  }
                } else {
                  // No pending message, add new one
                  _messages.add(decryptedMessage);
                  _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  print('[ChatScreen] Added new message: ${decryptedMessage.id}');
                }
              } else {
                // Not my message, just add it
                _messages.add(decryptedMessage);
                _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                print('[ChatScreen] Added new message from other user: ${decryptedMessage.id}');
              }
            } else {
              // Update existing message (optimistic update replacement)
              // Preserve reply_to_id and attachment fields from existing message if new one doesn't have them
              final existingMsg = _messages[existingIndex];
              final finalMessage = decryptedMessage.replyToId != null && 
                                   decryptedMessage.attachmentUrl != null
                  ? decryptedMessage
                  : Message(
                      id: decryptedMessage.id,
                      conversationId: decryptedMessage.conversationId,
                      senderId: decryptedMessage.senderId,
                      content: decryptedMessage.content,
                      encryptedContent: decryptedMessage.encryptedContent,
                      iv: decryptedMessage.iv,
                      messageType: decryptedMessage.messageType,
                      status: decryptedMessage.status,
                      deliveredAt: decryptedMessage.deliveredAt,
                      readAt: decryptedMessage.readAt,
                      replyToId: existingMsg.replyToId ?? decryptedMessage.replyToId,
                      createdAt: decryptedMessage.createdAt,
                      updatedAt: decryptedMessage.updatedAt,
                      editedAt: decryptedMessage.editedAt,
                      editCount: decryptedMessage.editCount,
                      isForwarded: decryptedMessage.isForwarded,
                      sender: decryptedMessage.sender,
                      isMine: decryptedMessage.isMine,
                      isStarred: decryptedMessage.isStarred,
                      isPinned: decryptedMessage.isPinned,
                      // Preserve attachment fields from existing message or use from decrypted
                      attachmentUrl: decryptedMessage.attachmentUrl ?? existingMsg.attachmentUrl,
                      attachmentName: decryptedMessage.attachmentName ?? existingMsg.attachmentName,
                      attachmentSize: decryptedMessage.attachmentSize ?? existingMsg.attachmentSize,
                      attachmentType: decryptedMessage.attachmentType ?? existingMsg.attachmentType,
                    );
              _messages[existingIndex] = finalMessage;
              print('[ChatScreen] Updated existing message: ${decryptedMessage.id}, replyToId: ${finalMessage.replyToId}');
            }
          });
          
          // Always auto-scroll for new messages (like WhatsApp)
          WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
          });
            }
      });
    } catch (e) {
      print('[ChatScreen] Error handling new message: $e');
      print('[ChatScreen] Message data: ${envelope.data}');
    }
  }
  
  void _handleMessageRead(WSMessageEnvelope envelope) {
    if (envelope.data == null) return;
    
    try {
      final data = envelope.data as Map<String, dynamic>;
      final messageId = data['message_id'] as String?;
      final readAt = data['read_at'] as String?;
      
      if (messageId != null && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            // Update message status to read
            final message = _messages[index];
            _messages[index] = Message(
              id: message.id,
              conversationId: message.conversationId,
              senderId: message.senderId,
              content: message.content,
              encryptedContent: message.encryptedContent,
              iv: message.iv,
              messageType: message.messageType,
              status: MessageStatus.read,
              readAt: readAt != null ? DateTime.parse(readAt).toLocal() : DateTime.now(),
              createdAt: message.createdAt,
              updatedAt: message.updatedAt,
              isMine: message.isMine,
              sender: message.sender,
            );
          }
        });
      }
      } catch (e) {
      print('[ChatScreen] Error handling message read: $e');
    }
  }
  
  void _handleMessageDelivered(WSMessageEnvelope envelope) {
    if (envelope.data == null) return;
    
    try {
      final data = envelope.data as Map<String, dynamic>;
      final messageId = data['message_id'] as String?;
      
      if (messageId != null && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            final message = _messages[index];
            _messages[index] = Message(
              id: message.id,
              conversationId: message.conversationId,
              senderId: message.senderId,
              content: message.content,
              encryptedContent: message.encryptedContent,
              iv: message.iv,
              messageType: message.messageType,
              status: MessageStatus.delivered,
              deliveredAt: DateTime.now(),
              createdAt: message.createdAt,
              updatedAt: message.updatedAt,
              isMine: message.isMine,
              sender: message.sender,
            );
          }
        });
      }
    } catch (e) {
      print('[ChatScreen] Error handling message delivered: $e');
      }
  }
  
  void _handleMessageEdited(WSMessageEnvelope envelope) async {
    if (envelope.data == null) return;
    
    try {
      final messageData = envelope.data as Map<String, dynamic>;
      final messageId = messageData['id'] as String?;
      
      if (messageId != null && mounted) {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          // Update message with edited content
          if (_currentUserId != null) {
            messageData['is_mine'] = messageData['sender_id'] == _currentUserId;
          }
          
          final updatedMessage = Message.fromJson(messageData);
          
          // Decrypt if needed (for encrypted messages)
          final decryptedMessage = await _decryptMessageIfNeeded(updatedMessage);
          
          setState(() {
            _messages[index] = decryptedMessage;
          });
          
          print('[ChatScreen] Message edited: $messageId');
        } else {
          print('[ChatScreen] Edited message not found in list: $messageId');
        }
      }
    } catch (e) {
      print('[ChatScreen] Error handling message edited: $e');
    }
  }
  
  void _handleMessageDeleted(WSMessageEnvelope envelope) async {
    if (envelope.data == null) return;
    
    try {
      final data = envelope.data as Map<String, dynamic>;
      final messageId = data['message_id'] as String?;
      final deleteFor = data['delete_for'] as String? ?? 'everyone';
      
      if (messageId != null && mounted) {
        if (deleteFor == 'me') {
          // Remove from local view only
          setState(() {
            _messages.removeWhere((m) => m.id == messageId);
          });
        } else {
          // Delete for everyone - update message to show placeholder
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            // Get message data from envelope or fetch from API
            if (data['message'] != null) {
              final messageData = data['message'] as Map<String, dynamic>;
              if (_currentUserId != null) {
                messageData['is_mine'] = messageData['sender_id'] == _currentUserId;
              }
              final updatedMessage = Message.fromJson(messageData);
              final decryptedMessage = await _decryptMessageIfNeeded(updatedMessage);
              
              setState(() {
                _messages[index] = decryptedMessage;
              });
            } else {
              // Fallback: mark as deleted
              final message = _messages[index];
              final updatedMessage = Message(
                id: message.id,
                conversationId: message.conversationId,
                senderId: message.senderId,
                content: message.content,
                encryptedContent: message.encryptedContent,
                iv: message.iv,
                messageType: message.messageType,
                status: message.status,
                createdAt: message.createdAt,
                updatedAt: DateTime.now(),
                isDeleted: true,
                deletedAt: DateTime.now(),
                deletedFor: 'everyone',
                isMine: message.isMine,
                sender: message.sender,
              );
              setState(() {
                _messages[index] = updatedMessage;
              });
            }
          }
        }
        print('[ChatScreen] Message deleted: $messageId (for: $deleteFor)');
      }
    } catch (e) {
      print('[ChatScreen] Error handling message deleted: $e');
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size ?? 0;
        final fileExtension = result.files.single.extension ?? '';
        
        await _sendDocument(filePath, fileName, fileSize, fileExtension);
      }
    } catch (e) {
      _showNotification('Failed to pick document: ${e.toString()}', true);
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Compress to 85% quality
        maxWidth: 1920, // Max width for large images
        maxHeight: 1920, // Max height for large images
      );

      if (image == null) {
        // User cancelled
        return;
      }

      await _sendImageMessage(image.path);
    } catch (e) {
      _showNotification('Failed to pick image: ${e.toString()}', true);
    }
  }

  Future<void> _takePhotoAndSend() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Compress to 85% quality
        maxWidth: 1920, // Max width for large images
        maxHeight: 1920, // Max height for large images
      );

      if (image == null) {
        // User cancelled
        return;
      }

      await _sendImageMessage(image.path);
    } catch (e) {
      _showNotification('Failed to take photo: ${e.toString()}', true);
    }
  }

  /// Send image message
  Future<void> _sendImageMessage(String imagePath) async {
    if (_conversationId == null) return;

    final file = File(imagePath);
    if (!await file.exists()) {
      _showNotification('Image file not found', true);
      return;
    }

    final fileSize = await file.length();
    final tempId = 'temp_image_${DateTime.now().millisecondsSinceEpoch}';
    final cancelToken = CancelToken();

    // Create optimistic message
    final optimisticMessage = Message(
      id: tempId,
      conversationId: _conversationId!,
      senderId: _currentUserId ?? '',
      content: '',
      messageType: MessageType.image,
      attachmentUrl: null, // Will be set after upload
      attachmentName: imagePath.split('/').last,
      attachmentSize: fileSize,
      attachmentType: 'image/jpeg', // Default, will be updated from upload response
      createdAt: DateTime.now().toLocal(),
      updatedAt: DateTime.now().toLocal(),
      replyToId: _replyingToMessage?.id,
    );

    setState(() {
      _messages.add(optimisticMessage);
      _pendingMessages[tempId] = optimisticMessage;
      _uploadProgress[tempId] = 0.0;
      _uploadCancelTokens[tempId] = cancelToken;
    });

    _scrollToBottom();

    try {
      // Upload image with progress
      final uploadResponse = await _messagesService.uploadImage(
        imagePath,
        quality: 'standard', // Can be 'standard' or 'hd'
        onProgress: (sent, total) {
          if (mounted) {
            setState(() {
              _uploadProgress[tempId] = sent / total;
            });
          }
        },
        cancelToken: cancelToken,
      );

      if (!uploadResponse.success || uploadResponse.data == null) {
        throw Exception(uploadResponse.error ?? 'Failed to upload image');
      }

      final uploadData = uploadResponse.data!;
      final attachmentUrl = uploadData['url'] as String? ?? '';
      final uploadedFileType = uploadData['type'] as String? ?? 'image/jpeg';

      // Send message with attachment
      final response = await _messagesService.sendMessage(
        _conversationId!,
        '', // Empty content for image
        messageType: MessageType.image,
        attachmentUrl: attachmentUrl,
        attachmentName: imagePath.split('/').last,
        attachmentSize: fileSize,
        attachmentType: uploadedFileType,
        tempId: tempId,
        replyToId: _replyingToMessage?.id,
      );

      if (response.success && response.data != null) {
        // Replace optimistic with real message
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _messages[index] = response.data!;
          }
          _pendingMessages.remove(tempId);
          _uploadProgress.remove(tempId);
          _uploadCancelTokens.remove(tempId);
          _replyingToMessage = null; // Clear reply state
        });
      } else {
        throw Exception(response.error ?? 'Failed to send message');
      }
    } catch (e) {
      // Remove failed message
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
        _pendingMessages.remove(tempId);
        _uploadProgress.remove(tempId);
        _uploadCancelTokens.remove(tempId);
      });
      _showNotification('Failed to send image: ${e.toString()}', true);
    }
  }

  /// Start audio recording
  Future<void> _startAudioRecording() async {
    try {
      final hasPermission = await _audioService.checkMicrophonePermission();
      if (!hasPermission) {
        _showNotification('Microphone permission is required', true);
        return;
      }

      final recordingPath = await _audioService.startRecording();
      if (recordingPath == null) {
        _showNotification('Failed to start recording', true);
        return;
      }

      setState(() {
        _isRecordingAudio = true;
        _isRecordingLocked = false;
        _currentRecordingPath = recordingPath;
      });

      // Listen to recording duration
      _recordingDurationSubscription = _audioService.recordingDurationStream.listen((duration) {
        if (mounted) {
          setState(() {
            // Duration is updated via stream
          });
        }
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      _showNotification('Failed to start recording: ${e.toString()}', true);
    }
  }

  /// Stop audio recording and send
  Future<void> _stopAudioRecordingAndSend() async {
    if (!_isRecordingAudio || _currentRecordingPath == null) return;

    try {
      final recordingPath = await _audioService.stopRecording();
      if (recordingPath == null) {
        _showNotification('Failed to stop recording', true);
        return;
      }

      await _sendAudioMessage(recordingPath);
    } catch (e) {
      _showNotification('Failed to send audio: ${e.toString()}', true);
    } finally {
      setState(() {
        _isRecordingAudio = false;
        _isRecordingLocked = false;
        _currentRecordingPath = null;
      });
      _recordingDurationSubscription?.cancel();
      _recordingDurationSubscription = null;
    }
  }

  /// Cancel audio recording
  Future<void> _cancelAudioRecording() async {
    try {
      await _audioService.cancelRecording();
    } catch (e) {
      print('[ChatScreen] Error canceling recording: $e');
    } finally {
      setState(() {
        _isRecordingAudio = false;
        _isRecordingLocked = false;
        _currentRecordingPath = null;
      });
      _recordingDurationSubscription?.cancel();
      _recordingDurationSubscription = null;
    }
  }

  /// Lock audio recording
  void _lockAudioRecording() {
    setState(() {
      _isRecordingLocked = true;
    });
    HapticFeedback.mediumImpact();
  }

  /// Send audio message
  Future<void> _sendAudioMessage(String filePath) async {
    if (_conversationId == null) return;

    final file = File(filePath);
    if (!await file.exists()) {
      _showNotification('Audio file not found', true);
      return;
    }

    final fileSize = await file.length();
    final tempId = 'temp_audio_${DateTime.now().millisecondsSinceEpoch}';
    final cancelToken = CancelToken();

    // Get audio duration
    int durationSeconds = 0;
    try {
      final duration = await _audioService.getDuration(filePath);
      if (duration != null) {
        durationSeconds = duration.inSeconds;
      }
    } catch (e) {
      print('[ChatScreen] Error getting audio duration: $e');
    }

    // Create optimistic message
    final optimisticMessage = Message(
      id: tempId,
      conversationId: _conversationId!,
      senderId: _currentUserId ?? '',
      content: '',
      messageType: MessageType.audio,
      attachmentUrl: null, // Will be set after upload
      attachmentName: 'Voice Note',
      attachmentSize: durationSeconds > 0 ? durationSeconds : null, // Duration in seconds
      attachmentType: 'audio/m4a', // M4A format from recorder
      createdAt: DateTime.now().toLocal(),
      updatedAt: DateTime.now().toLocal(),
      replyToId: _replyingToMessage?.id,
    );

    setState(() {
      _messages.add(optimisticMessage);
      _pendingMessages[tempId] = optimisticMessage;
      _uploadProgress[tempId] = 0.0;
      _uploadCancelTokens[tempId] = cancelToken;
    });

    _scrollToBottom();

    try {
      // Upload audio
      final uploadResponse = await _messagesService.uploadAudio(
        filePath,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() {
              _uploadProgress[tempId] = sent / total;
            });
          }
        },
        cancelToken: cancelToken,
      );

      if (!uploadResponse.success || uploadResponse.data == null) {
        throw Exception(uploadResponse.error ?? 'Failed to upload audio');
      }

      final uploadData = uploadResponse.data!;
      final attachmentUrl = uploadData['url'] as String? ?? '';
      final uploadedFileType = uploadData['type'] as String? ?? 'audio/m4a';

      // Send message with attachment (use duration, not file size)
      final response = await _messagesService.sendMessage(
        _conversationId!,
        '', // Empty content for audio
        messageType: MessageType.audio,
        attachmentUrl: attachmentUrl,
        attachmentName: 'Voice Note',
        attachmentSize: durationSeconds > 0 ? durationSeconds : null, // Duration in seconds
        attachmentType: uploadedFileType, // Use the type returned by backend
        tempId: tempId,
        replyToId: _replyingToMessage?.id,
      );

      if (response.success && response.data != null) {
        // Replace optimistic with real message
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _messages[index] = response.data!;
          }
          _pendingMessages.remove(tempId);
          _uploadProgress.remove(tempId);
          _uploadCancelTokens.remove(tempId);
        });
      } else {
        throw Exception(response.error ?? 'Failed to send message');
      }
    } catch (e) {
      // Remove failed message
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
        _pendingMessages.remove(tempId);
        _uploadProgress.remove(tempId);
        _uploadCancelTokens.remove(tempId);
      });
      _showNotification('Failed to send audio: ${e.toString()}', true);
    }
  }

  Future<void> _sendDocument(
    String filePath,
    String fileName,
    int fileSize,
    String fileExtension,
  ) async {
    if (_conversationId == null) return;

    // Generate temp ID for optimistic UI
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final cancelToken = CancelToken();
    
    try {
      // Create optimistic message
      final optimisticMessage = Message(
        id: tempId,
        conversationId: _conversationId!,
        senderId: _currentUserId!,
        content: '', // Empty for document
        messageType: MessageType.file,
        attachmentName: fileName,
        attachmentSize: fileSize,
        attachmentType: fileExtension,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isMine: true,
        replyToId: _replyingToMessage?.id,
      );

      // Store for replacement
      _pendingMessages[tempId] = optimisticMessage;
      _uploadCancelTokens[tempId] = cancelToken;

      // Add optimistically
      setState(() {
        _messages.add(optimisticMessage);
        _uploadProgress[tempId] = 0.0;
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _replyingToMessage = null; // Clear reply state
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      // Upload file with progress
      final uploadResponse = await _messagesService.uploadFile(
        filePath,
        onProgress: (sent, total) {
          setState(() {
            _uploadProgress[tempId] = sent / total;
          });
        },
        cancelToken: cancelToken,
      );

      if (!uploadResponse.success || uploadResponse.data == null) {
        throw Exception(uploadResponse.error ?? 'Upload failed');
      }

      final uploadData = uploadResponse.data!;
      final attachmentUrl = uploadData['url'] as String? ?? '';
      final uploadedFileName = uploadData['name'] as String? ?? fileName;
      final uploadedFileSize = uploadData['size'] as int? ?? fileSize;
      final uploadedFileType = uploadData['type'] as String? ?? fileExtension;

      // Send message with attachment
      final response = await _messagesService.sendMessage(
        _conversationId!,
        '', // Empty content for document
        messageType: MessageType.file,
        attachmentUrl: attachmentUrl,
        attachmentName: uploadedFileName,
        attachmentSize: uploadedFileSize,
        attachmentType: uploadedFileType,
        tempId: tempId,
        replyToId: _replyingToMessage?.id,
      );

      if (response.success && response.data != null) {
        // Replace optimistic with real message
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _messages[index] = response.data!;
          }
          _pendingMessages.remove(tempId);
          _uploadProgress.remove(tempId);
          _uploadCancelTokens.remove(tempId);
        });
      } else {
        throw Exception(response.error ?? 'Failed to send message');
      }
    } catch (e) {
      // Remove failed message
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
        _pendingMessages.remove(tempId);
        _uploadProgress.remove(tempId);
        _uploadCancelTokens.remove(tempId);
      });
      _showNotification('Failed to send document: ${e.toString()}', true);
    }
  }

  /// Build full URL from relative attachment URL
  String _buildFullAttachmentUrl(String? attachmentUrl) {
    if (attachmentUrl == null) return '';
    // If already a full URL (starts with http:// or https://), return as-is
    if (attachmentUrl.startsWith('http://') || attachmentUrl.startsWith('https://')) {
      return attachmentUrl;
    }
    // Otherwise, build full URL from base URL
    final baseUrl = ApiConfig.baseUrlSync;
    // Remove /api/v1 from base URL if present, as attachment URLs are typically at root
    final cleanBaseUrl = baseUrl.replaceAll('/api/v1', '');
    // Ensure attachment URL starts with /
    final attachmentPath = attachmentUrl.startsWith('/') ? attachmentUrl : '/$attachmentUrl';
    return '$cleanBaseUrl$attachmentPath';
  }

  Future<void> _downloadDocument(Message message) async {
    if (message.attachmentUrl == null) return;
    
    final messageId = message.id;
    
    // Build full URL for download
    final fullUrl = _buildFullAttachmentUrl(message.attachmentUrl);
    if (fullUrl.isEmpty) {
      _showNotification('Invalid file URL', true);
      return;
    }
    
    // Check if already downloaded
    final isDownloaded = await _fileStorageService.isFileDownloaded(messageId);
    if (isDownloaded) {
      // Open file
      final file = await _fileStorageService.getDownloadedFile(messageId);
      if (file != null) {
        await OpenFile.open(file.path);
      }
      return;
    }

    // Download file
    try {
      setState(() {
        _downloadProgress[messageId] = 0.0;
      });

      final file = await _fileStorageService.downloadFile(
        messageId,
        fullUrl,
        onProgress: (received, total) {
          setState(() {
            _downloadProgress[messageId] = received / total;
          });
        },
      );

      if (file != null) {
        setState(() {
          _downloadProgress.remove(messageId);
        });
        // Open file
        await OpenFile.open(file.path);
      } else {
        setState(() {
          _downloadProgress.remove(messageId);
        });
        _showNotification('Failed to download file', true);
      }
    } catch (e) {
      setState(() {
        _downloadProgress.remove(messageId);
      });
      _showNotification('Failed to download file: ${e.toString()}', true);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null || _isSending) return;

    setState(() {
      _isSending = true;
    });

    // Generate temp ID for optimistic UI
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Encrypt message
      final encrypted = await _e2eeService.encrypt(text, _conversationId!);
      
      // Get reply_to_id if replying
      final replyToId = _replyingToMessage?.id;
      
      // Create optimistic message (using temp ID)
      final optimisticMessage = Message(
        id: tempId,
        conversationId: _conversationId!,
        senderId: _currentUserId!,
        content: text,
        encryptedContent: encrypted['encrypted_content'],
        iv: encrypted['iv'],
        messageType: MessageType.text,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isMine: true,
        replyToId: replyToId,
      );
      
      print('[ChatScreen] Created optimistic message: tempId=$tempId, replyToId=$replyToId');
      
      // Store mapping for later replacement
      _pendingMessages[tempId] = optimisticMessage;

      // Add optimistically
      setState(() {
        _messages.add(optimisticMessage);
        _pendingMessages[tempId] = optimisticMessage;
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        // Clear reply state after sending
        _replyingToMessage = null;
      });
      _messageController.clear();
      
      // Scroll to bottom immediately after adding optimistic message
      WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      });

      // Send to backend
      final response = await _messagesService.sendMessage(
        _conversationId!,
        text,
        encryptedContent: encrypted['encrypted_content'],
        iv: encrypted['iv'],
        tempId: tempId,
        replyToId: replyToId,
      );

      if (response.success && response.data != null) {
        // Replace optimistic message with real one
        setState(() {
          _pendingMessages.remove(tempId);
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            // Replace the optimistic message - ensure reply_to_id is preserved
            final optimisticMsg = _messages[index];
            final backendMsg = response.data!;
            // Use reply_to_id from backend if available, otherwise keep from optimistic
            final finalMessage = Message(
              id: backendMsg.id,
              conversationId: backendMsg.conversationId,
              senderId: backendMsg.senderId,
              content: backendMsg.content,
              encryptedContent: backendMsg.encryptedContent,
              iv: backendMsg.iv,
              messageType: backendMsg.messageType,
              status: backendMsg.status,
              deliveredAt: backendMsg.deliveredAt,
              readAt: backendMsg.readAt,
              replyToId: backendMsg.replyToId ?? optimisticMsg.replyToId,
              createdAt: backendMsg.createdAt,
              updatedAt: backendMsg.updatedAt,
              editedAt: backendMsg.editedAt,
              editCount: backendMsg.editCount,
              isForwarded: backendMsg.isForwarded,
              sender: backendMsg.sender,
              isMine: backendMsg.isMine,
              isStarred: backendMsg.isStarred,
              isPinned: backendMsg.isPinned,
            );
            _messages[index] = finalMessage;
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            print('[ChatScreen] Replaced optimistic message, replyToId: ${finalMessage.replyToId}');
          } else {
            // Optimistic message not found (might have been replaced by WebSocket)
            // Check if message already exists
            final existingIndex = _messages.indexWhere((m) => m.id == response.data!.id);
            if (existingIndex == -1) {
            _messages.add(response.data!);
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            }
          }
        });
        
        // Scroll to bottom after sending
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      } else {
        // Remove optimistic message on error
        setState(() {
          _pendingMessages.remove(tempId);
          _messages.removeWhere((m) => m.id == tempId);
        });
        _showNotification('Failed to send message', true);
      }
    } catch (e) {
      // Remove optimistic message on error
      setState(() {
        _pendingMessages.remove(tempId);
        _messages.removeWhere((m) => m.id == tempId);
      });
      _showNotification('Failed to send message: ${e.toString()}', true);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _wsService.unsubscribeFromConversation(_conversationId ?? '');
    _wsService.removeConnectionListener(_onWebSocketConnectionChanged);
    _wsSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Scroll to bottom immediately (for initial load)
  void _scrollToBottomImmediate() {
    if (_scrollController.hasClients) {
      // Use jumpTo for instant scroll on initial load
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _showNotification(String message, bool isError) {
    // Notifications disabled - no popups shown
  }

  void _showUserPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _UserPreviewDialog(
        userName: widget.userName,
        userUsername: widget.userUsername,
        profilePicture: widget.profilePicture,
        isOnline: widget.isOnline,
      ),
      routeSettings: const RouteSettings(),
    ).then((_) {
      // Optional: Handle when dialog is dismissed
    });
  }

  void _showChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ChatMenuDialog(
        userName: widget.userName,
        onShowNotification: _showNotification,
      ),
    );
  }

  void _showMessageOptions(String messageId) {
    final messageMap = _messagesForUI.firstWhere((m) => m['id'] == messageId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MessageOptionsMenu(
        messageId: messageId,
        isMe: messageMap['isMe'] as bool,
        messageText: messageMap['text'] as String,
        onReaction: () => _handleReaction(messageId),
        onReply: () => _handleReply(messageId),
        onCopy: () => _handleCopy(messageId),
        onForward: () => _handleForward(messageId),
        onEdit: () => _handleEdit(messageId),
        onStar: () => _handleStar(messageId),
        onPin: () => _handlePin(messageId),
        onDelete: () => _handleDelete(messageId),
        onShare: () => _handleShare(messageId),
        onInfo: () => _handleInfo(messageId),
      ),
    );
  }

  void _handleReaction(String messageId) {
    // Menu is already closed by _handleSelection, just show emoji picker
    _showEmojiPicker(messageId);
  }
  
  Future<void> _addReaction(String messageId, String emoji) async {
    try {
      // Use stored current user ID
      if (_currentUserId == null) return;
      
      final response = await _messagesService.addReaction(messageId, emoji);
      if (response.success && mounted) {
        // Update reactions optimistically
        setState(() {
          if (!_messageReactions.containsKey(messageId)) {
            _messageReactions[messageId] = {};
          }
          _messageReactions[messageId]![_currentUserId!] = emoji;
        });
      }
    } catch (e) {
      print('[ChatScreen] Failed to add reaction: $e');
    }
  }

  void _handleMessageReaction(WSMessageEnvelope envelope) {
    if (envelope.data == null) return;
    
    try {
      final data = envelope.data as Map<String, dynamic>;
      final messageId = data['message_id'] as String?;
      final userId = data['user_id'] as String?;
      final emoji = data['emoji'] as String?;
      
      if (messageId != null && userId != null && emoji != null && mounted) {
        setState(() {
          if (!_messageReactions.containsKey(messageId)) {
            _messageReactions[messageId] = {};
          }
          _messageReactions[messageId]![userId] = emoji;
        });
      }
    } catch (e) {
      print('[ChatScreen] Error handling message reaction: $e');
    }
  }

  void _handleMessageReactionRemoved(WSMessageEnvelope envelope) {
    if (envelope.data == null) return;
    
    try {
      final data = envelope.data as Map<String, dynamic>;
      final messageId = data['message_id'] as String?;
      final userId = data['user_id'] as String?;
      
      if (messageId != null && userId != null && mounted) {
        setState(() {
          if (_messageReactions.containsKey(messageId)) {
            _messageReactions[messageId]!.remove(userId);
            if (_messageReactions[messageId]!.isEmpty) {
              _messageReactions.remove(messageId);
            }
          }
        });
      }
    } catch (e) {
      print('[ChatScreen] Error handling message reaction removed: $e');
    }
  }

  void _showEmojiPicker(String messageId) {
    // Comprehensive emoji list organized by categories
    final emojiCategories = {
      'Smileys & People': [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '😂',
        '🤣',
        '😊',
        '😇',
        '🙂',
        '🙃',
        '😉',
        '😌',
        '😍',
        '🥰',
        '😘',
        '😗',
        '😙',
        '😚',
        '😋',
        '😛',
        '😝',
        '😜',
        '🤪',
        '🤨',
        '🧐',
        '🤓',
        '😎',
        '🤩',
        '🥳',
        '😏',
        '😒',
        '😞',
        '😔',
        '😟',
        '😕',
        '🙁',
        '☹️',
        '😣',
        '😖',
        '😫',
        '😩',
        '🥺',
        '😢',
        '😭',
        '😤',
        '😠',
        '😡',
        '🤬',
        '🤯',
        '😳',
        '🥵',
        '🥶',
        '😱',
        '😨',
        '😰',
        '😥',
        '😓',
        '🤗',
        '🤔',
        '🤭',
        '🤫',
        '🤥',
        '😶',
        '😐',
        '😑',
        '😬',
        '🙄',
        '😯',
        '😦',
        '😧',
        '😮',
        '😲',
        '🥱',
        '😴',
        '🤤',
        '😪',
        '😵',
        '🤐',
        '🥴',
        '🤢',
        '🤮',
        '🤧',
        '😷',
        '🤒',
        '🤕',
        '🤑',
        '🤠',
        '😈',
        '👿',
        '👹',
        '👺',
        '🤡',
        '💩',
        '👻',
        '💀',
        '☠️',
        '👽',
        '👾',
        '🤖',
        '🎃',
      ],
      'Gestures': [
        '👋',
        '🤚',
        '🖐',
        '✋',
        '🖖',
        '👌',
        '🤏',
        '✌️',
        '🤞',
        '🤟',
        '🤘',
        '🤙',
        '👈',
        '👉',
        '👆',
        '🖕',
        '👇',
        '☝️',
        '👍',
        '👎',
        '✊',
        '👊',
        '🤛',
        '🤜',
        '👏',
        '🙌',
        '👐',
        '🤲',
        '🤝',
        '🙏',
        '✍️',
        '💪',
        '🦾',
        '🦿',
        '🦵',
        '🦶',
        '👂',
        '🦻',
        '👃',
        '🧠',
        '🦷',
        '🦴',
        '👀',
        '👁',
        '👅',
        '👄',
      ],
      'Hearts & Love': [
        '💋',
        '💌',
        '💘',
        '💝',
        '💖',
        '💗',
        '💓',
        '💞',
        '💕',
        '💟',
        '❣️',
        '💔',
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '🤎',
        '💯',
        '💢',
        '💥',
        '💫',
        '💦',
        '💨',
        '🕳️',
        '💣',
        '💬',
        '👁️‍🗨️',
        '🗨️',
        '🗯️',
        '💭',
        '💤',
      ],
      'Objects': [
        '👓',
        '🕶️',
        '🥽',
        '🥼',
        '🦺',
        '👔',
        '👕',
        '👖',
        '🧣',
        '🧤',
        '🧥',
        '🧦',
        '👗',
        '👘',
        '🥻',
        '🩱',
        '🩲',
        '🩳',
        '👙',
        '👚',
        '👛',
        '👜',
        '👝',
        '🛍️',
        '🎒',
        '👞',
        '👟',
        '🥾',
        '🥿',
        '👠',
        '👡',
        '🩰',
        '👢',
        '👑',
        '👒',
        '🎩',
        '🎓',
        '🧢',
        '⛑️',
        '📿',
        '💄',
        '💍',
        '💎',
      ],
      'Nature': [
        '🌱',
        '🌲',
        '🌳',
        '🌴',
        '🌵',
        '🌶️',
        '🌷',
        '🌸',
        '🌹',
        '🌺',
        '🌻',
        '🌼',
        '🌽',
        '🌾',
        '🌿',
        '🍀',
        '🍁',
        '🍂',
        '🍃',
        '🍄',
        '🍇',
        '🍈',
        '🍉',
        '🍊',
        '🍋',
        '🍌',
        '🍍',
        '🥭',
        '🍎',
        '🍏',
        '🍐',
        '🍑',
        '🍒',
        '🍓',
        '🥝',
        '🍅',
        '🥥',
        '🥑',
        '🍆',
        '🥔',
        '🥕',
        '🌽',
        '🌶️',
        '🥒',
        '🥬',
        '🥦',
        '🧄',
        '🧅',
        '🍄',
        '🥜',
        '🌰',
      ],
      'Food': [
        '🍞',
        '🥐',
        '🥖',
        '🫓',
        '🥨',
        '🥯',
        '🥞',
        '🧇',
        '🧀',
        '🍖',
        '🍗',
        '🥩',
        '🥓',
        '🍔',
        '🍟',
        '🍕',
        '🌭',
        '🥪',
        '🌮',
        '🌯',
        '🫔',
        '🥙',
        '🧆',
        '🥚',
        '🍳',
        '🥘',
        '🍲',
        '🫕',
        '🥣',
        '🥗',
        '🍿',
        '🧈',
        '🧂',
        '🥫',
        '🍱',
        '🍘',
        '🍙',
        '🍚',
        '🍛',
        '🍜',
        '🍝',
        '🍠',
        '🍢',
        '🍣',
        '🍤',
        '🍥',
        '🥮',
        '🍡',
        '🥟',
        '🥠',
        '🥡',
        '🦀',
        '🦞',
        '🦐',
        '🦑',
        '🦪',
      ],
      'Activities': [
        '⚽',
        '🏀',
        '🏈',
        '⚾',
        '🥎',
        '🎾',
        '🏐',
        '🏉',
        '🥏',
        '🎱',
        '🏓',
        '🏸',
        '🏒',
        '🏑',
        '🏏',
        '🥅',
        '⛳',
        '🏹',
        '🎣',
        '🤿',
        '🥊',
        '🥋',
        '🎽',
        '🛹',
        '🛷',
        '⛸️',
        '🥌',
        '🎿',
        '⛷️',
        '🏂',
        '🪂',
        '🏋️',
        '🤼',
        '🤸',
        '🤺',
        '🤾',
        '🏌️',
        '🏇',
        '🧘',
        '🏄',
        '🏊',
        '🤽',
        '🚣',
        '🧗',
        '🚵',
        '🚴',
        '🏆',
        '🥇',
        '🥈',
        '🥉',
        '🏅',
        '🎖️',
        '🏵️',
        '🎗️',
        '🎫',
        '🎟️',
        '🎪',
        '🤹',
        '🎭',
        '🩰',
        '🎨',
        '🎬',
        '🎤',
        '🎧',
        '🎼',
        '🎹',
        '🥁',
        '🎷',
        '🎺',
        '🎸',
        '🪕',
        '🎻',
        '🎲',
        '♟️',
        '🎯',
        '🎳',
        '🎮',
        '🎰',
        '🧩',
      ],
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Emoji categories with tabs
              Expanded(
                child: DefaultTabController(
                  length: emojiCategories.length,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        labelColor: AppColors.accentPrimary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.accentPrimary,
                        tabs: emojiCategories.keys
                            .map((category) => Tab(text: category))
                            .toList(),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: emojiCategories.values.map((emojis) {
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemCount: emojis.length,
                              itemBuilder: (context, index) {
                                final emoji = emojis[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _addReaction(messageId, emoji);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundPrimary
                                          .withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
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

  void _handleReply(String messageId) {
    final message = _messages.firstWhere((m) => m.id == messageId);
    setState(() {
      _replyingToMessage = message;
    });
    // Focus on input field
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _handleCopy(String messageId) async {
    try {
      final message = _messages.firstWhere((m) => m.id == messageId);
      await Clipboard.setData(ClipboardData(text: message.content));
    _showNotification('Message copied', false);
    } catch (e) {
      _showNotification('Failed to copy message', true);
    }
  }

  void _handleForward(String messageId) async {
    // Enter selection mode and select the first message
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(messageId);
    });
    
    // Show forward picker
    _showForwardPicker();
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        // Exit selection mode if no messages selected
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _showForwardPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ForwardPickerScreen(
        selectedMessageIds: _selectedMessageIds.toList(),
        onForward: (conversationIds) async {
          Navigator.pop(context); // Close picker
          await _forwardMessages(_selectedMessageIds.toList(), conversationIds);
          _exitSelectionMode();
        },
        onCancel: () {
          Navigator.pop(context);
          _exitSelectionMode();
        },
      ),
    );
  }

  Future<void> _forwardMessages(List<String> messageIds, List<String> conversationIds) async {
    if (messageIds.isEmpty || conversationIds.isEmpty) {
      _showNotification('No messages or conversations selected', true);
      return;
    }

    try {
      setState(() {
        _isSending = true;
      });

      int successCount = 0;
      int failCount = 0;
      final List<String> errors = [];

      // Forward each message to each conversation
      for (final messageId in messageIds) {
        try {
          final message = _messages.firstWhere((m) => m.id == messageId);
          
          for (final conversationId in conversationIds) {
            // Skip forwarding to the same conversation
            if (conversationId == _conversationId) {
              print('[ChatScreen] Skipping forwarding to same conversation: $conversationId');
              continue;
            }
            
            print('[ChatScreen] Forwarding message $messageId to conversation $conversationId');
            final response = await _messagesService.forwardMessage(
              messageId,
              conversationId,
            );
            
            if (response.success) {
              successCount++;
              print('[ChatScreen] Successfully forwarded message $messageId to $conversationId');
            } else {
              failCount++;
              final error = response.error ?? 'Unknown error';
              errors.add(error);
              print('[ChatScreen] Failed to forward message $messageId to $conversationId: $error');
            }
          }
        } catch (e) {
          failCount++;
          errors.add('Failed to forward message: ${e.toString()}');
          print('[ChatScreen] Error forwarding message $messageId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isSending = false;
        });

        // Show user feedback via SnackBar
        if (failCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                successCount == 1
                    ? 'Message forwarded successfully'
                    : '$successCount messages forwarded successfully',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (successCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to forward messages: ${errors.first}'),
              backgroundColor: AppColors.accentQuaternary,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount forwarded, $failCount failed'),
              backgroundColor: AppColors.accentTertiary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('[ChatScreen] Error forwarding messages: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _showNotification('Failed to forward messages: ${e.toString()}', true);
      }
    }
  }

  void _handleEdit(String messageId) {
    final message = _messages.firstWhere((m) => m.id == messageId);
    
    // Check if message is editable (within 15 minutes)
    final now = DateTime.now();
    final timeSinceSent = now.difference(message.createdAt);
    const editTimeLimit = Duration(minutes: 15);
    
    if (timeSinceSent > editTimeLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Messages can only be edited within 15 minutes of sending'),
          backgroundColor: AppColors.accentQuaternary,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => _EditMessageDialog(
        initialText: message.content,
        onSave: (newText) async {
          if (newText.trim().isEmpty || newText == message.content) {
            return;
          }
          
          final response = await _messagesService.editMessage(messageId, newText.trim());
          if (response.success && mounted) {
    setState(() {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
                final updatedMessage = Message(
                  id: _messages[index].id,
                  conversationId: _messages[index].conversationId,
                  senderId: _messages[index].senderId,
                  content: newText.trim(),
                  encryptedContent: _messages[index].encryptedContent,
                  iv: _messages[index].iv,
                  messageType: _messages[index].messageType,
                  status: _messages[index].status,
                  createdAt: _messages[index].createdAt,
                  updatedAt: DateTime.now(),
                  editedAt: DateTime.now(),
                  editCount: (_messages[index].editCount) + 1,
                  isMine: _messages[index].isMine,
                  sender: _messages[index].sender,
                );
                _messages[index] = updatedMessage;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Message edited'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.error ?? 'Failed to edit message'),
                backgroundColor: AppColors.accentQuaternary,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      ),
    );
  }
  
  /// Check if a message can be edited (own message, within 15 minutes)
  bool _canEditMessage(Message message) {
    if (!message.isMine) return false;
    final now = DateTime.now();
    final timeSinceSent = now.difference(message.createdAt);
    const editTimeLimit = Duration(minutes: 15);
    return timeSinceSent <= editTimeLimit;
  }

  void _handleStar(String messageId) async {
    try {
      final message = _messages.firstWhere((m) => m.id == messageId);
      final isStarred = message.isStarred ?? false;
      
      final response = isStarred
          ? await _messagesService.unstarMessage(messageId)
          : await _messagesService.starMessage(messageId);
      
      if (response.success && mounted) {
    setState(() {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
            final updatedMessage = Message(
              id: _messages[index].id,
              conversationId: _messages[index].conversationId,
              senderId: _messages[index].senderId,
              content: _messages[index].content,
              encryptedContent: _messages[index].encryptedContent,
              iv: _messages[index].iv,
              messageType: _messages[index].messageType,
              status: _messages[index].status,
              createdAt: _messages[index].createdAt,
              updatedAt: _messages[index].updatedAt,
              isMine: _messages[index].isMine,
              sender: _messages[index].sender,
              isStarred: !isStarred,
            );
            _messages[index] = updatedMessage;
          }
        });
        _showNotification(isStarred ? 'Message unstarred' : 'Message starred', false);
      } else {
        _showNotification(response.error ?? 'Failed to star message', true);
      }
    } catch (e) {
      _showNotification('Failed to star message: ${e.toString()}', true);
    }
  }

  void _handlePin(String messageId) async {
    try {
      final message = _messages.firstWhere((m) => m.id == messageId);
      final isPinned = message.isPinned ?? false;
      
      final response = isPinned
          ? await _messagesService.unpinMessage(messageId)
          : await _messagesService.pinMessage(messageId);
      
      if (response.success && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            final updatedMessage = Message(
              id: _messages[index].id,
              conversationId: _messages[index].conversationId,
              senderId: _messages[index].senderId,
              content: _messages[index].content,
              encryptedContent: _messages[index].encryptedContent,
              iv: _messages[index].iv,
              messageType: _messages[index].messageType,
              status: _messages[index].status,
              createdAt: _messages[index].createdAt,
              updatedAt: _messages[index].updatedAt,
              isMine: _messages[index].isMine,
              sender: _messages[index].sender,
              isPinned: !isPinned,
            );
            _messages[index] = updatedMessage;
          }
        });
        _showNotification(isPinned ? 'Message unpinned' : 'Message pinned', false);
      } else {
        _showNotification(response.error ?? 'Failed to pin message', true);
      }
    } catch (e) {
      _showNotification('Failed to pin message: ${e.toString()}', true);
    }
  }

  void _handleDelete(String messageId) async {
    final message = _messages.firstWhere((m) => m.id == messageId);
    
    // Check if message can be deleted for everyone (within 1 hour, own message)
    final now = DateTime.now();
    final timeSinceSent = now.difference(message.createdAt);
    const deleteTimeLimit = Duration(hours: 1);
    final canDeleteForEveryone = message.isMine && timeSinceSent <= deleteTimeLimit;
    
    // Show delete dialog with options
    final deleteOption = await showDialog<String>(
      context: context,
      builder: (context) => _DeleteMessageDialog(
        canDeleteForEveryone: canDeleteForEveryone,
      ),
    );

    if (deleteOption == null || !mounted) return;

    try {
      final response = await _messagesService.deleteMessage(
        messageId,
        deleteFor: deleteOption,
      );
      
      if (response.success && mounted) {
        if (deleteOption == 'me') {
          // Mark as deleted locally and persist
          await _deletedMessagesService.markAsDeleted(_conversationId!, messageId);
          _deletedMessageIds.add(messageId);
          
          // Remove from local view
    setState(() {
      _messages.removeWhere((m) => m.id == messageId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Delete for everyone - message will be updated via WebSocket
          // Update optimistically if we have the updated message
          if (response.data != null) {
            setState(() {
              final index = _messages.indexWhere((m) => m.id == messageId);
              if (index != -1) {
                _messages[index] = response.data!;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message deleted for everyone'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            // Backend may not return updated message - update optimistically and persist
            await _deletedMessagesService.markAsDeletedForEveryone(_conversationId!, messageId);
            _deletedForEveryoneIds.add(messageId);
            
            setState(() {
              final index = _messages.indexWhere((m) => m.id == messageId);
              if (index != -1) {
                final msg = _messages[index];
                final updatedMessage = Message(
                  id: msg.id,
                  conversationId: msg.conversationId,
                  senderId: msg.senderId,
                  content: msg.content,
                  encryptedContent: msg.encryptedContent,
                  iv: msg.iv,
                  messageType: msg.messageType,
                  status: msg.status,
                  createdAt: msg.createdAt,
                  updatedAt: DateTime.now(),
                  isDeleted: true,
                  deletedAt: DateTime.now(),
                  deletedFor: 'everyone',
                  isMine: msg.isMine,
                  sender: msg.sender,
                );
                _messages[index] = updatedMessage;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message deleted for everyone'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // Handle error - if backend fails, still update locally for better UX
        if (deleteOption == 'everyone') {
          // Update optimistically and persist even if API fails
          await _deletedMessagesService.markAsDeletedForEveryone(_conversationId!, messageId);
          _deletedForEveryoneIds.add(messageId);
          
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              final msg = _messages[index];
              final updatedMessage = Message(
                id: msg.id,
                conversationId: msg.conversationId,
                senderId: msg.senderId,
                content: msg.content,
                encryptedContent: msg.encryptedContent,
                iv: msg.iv,
                messageType: msg.messageType,
                status: msg.status,
                createdAt: msg.createdAt,
                updatedAt: DateTime.now(),
                isDeleted: true,
                deletedAt: DateTime.now(),
                deletedFor: 'everyone',
                isMine: msg.isMine,
                sender: msg.sender,
              );
              _messages[index] = updatedMessage;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted for everyone'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to delete message'),
              backgroundColor: AppColors.accentQuaternary,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('[ChatScreen] Error deleting message: $e');
      
      // If API fails but user selected "Delete for Everyone", update optimistically and persist
      if (deleteOption == 'everyone' && mounted) {
        await _deletedMessagesService.markAsDeletedForEveryone(_conversationId!, messageId);
        _deletedForEveryoneIds.add(messageId);
        
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            final msg = _messages[index];
            final updatedMessage = Message(
              id: msg.id,
              conversationId: msg.conversationId,
              senderId: msg.senderId,
              content: msg.content,
              encryptedContent: msg.encryptedContent,
              iv: msg.iv,
              messageType: msg.messageType,
              status: msg.status,
              createdAt: msg.createdAt,
              updatedAt: DateTime.now(),
              isDeleted: true,
              deletedAt: DateTime.now(),
              deletedFor: 'everyone',
              isMine: msg.isMine,
              sender: msg.sender,
            );
            _messages[index] = updatedMessage;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted for everyone'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: ${e.toString()}'),
            backgroundColor: AppColors.accentQuaternary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleShare(String messageId) async {
    try {
      final message = _messages.firstWhere((m) => m.id == messageId);
      await Share.share(message.content);
    } catch (e) {
      _showNotification('Failed to share message', true);
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 24) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _handleInfo(String messageId) {
    final message = _messages.firstWhere((m) => m.id == messageId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text('Message Info', style: AppTextStyles.headlineSmall()),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sent: ${_formatTimestamp(message.createdAt)}',
              style: AppTextStyles.bodyMedium(),
            ),
              if (message.deliveredAt != null) ...[
            const SizedBox(height: 8),
            Text(
                  'Delivered: ${_formatTimestamp(message.deliveredAt!)}',
              style: AppTextStyles.bodyMedium(),
            ),
              ],
            if (message.readAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Read: ${_formatTimestamp(message.readAt!)}',
                style: AppTextStyles.bodyMedium(),
              ),
            ],
              if (message.editedAt != null) ...[
              const SizedBox(height: 8),
                Text(
                  'Edited: ${_formatTimestamp(message.editedAt!)} (${message.editCount} time${message.editCount > 1 ? 's' : ''})',
                  style: AppTextStyles.bodyMedium(),
                ),
            ],
              const SizedBox(height: 8),
              Text(
                'Status: ${message.status.name}',
                style: AppTextStyles.bodyMedium(),
              ),
              if (message.isStarred == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, color: AppColors.accentPrimary, size: 16),
                    const SizedBox(width: 4),
                    Text('Starred', style: AppTextStyles.bodyMedium()),
                  ],
                ),
              ],
              if (message.isPinned == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.push_pin, color: AppColors.accentPrimary, size: 16),
                    const SizedBox(width: 4),
                    Text('Pinned', style: AppTextStyles.bodyMedium()),
            ],
                ),
          ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: AppTextStyles.labelLarge()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Selection mode header or Chat Header
              if (_isSelectionMode)
                _SelectionModeHeader(
                  selectedCount: _selectedMessageIds.length,
                  onCancel: _exitSelectionMode,
                  onForward: () {
                    if (_selectedMessageIds.isNotEmpty) {
                      _showForwardPicker();
                    }
                  },
                )
              else
              _ChatHeader(
                userName: widget.userName,
                userUsername: widget.userUsername,
                profilePicture: widget.profilePicture,
                isOnline: widget.isOnline,
                onBack: () => context.pop(),
                onVoiceCall: () {
                  _showNotification('This feature is coming in the next update! stay tuned', false);
                },
                onVideoCall: () {
                  _showNotification('This feature is coming in the next update! stay tuned', false);
                },
                onMenuTap: () => _showChatMenu(),
                onProfileTap: () => _showUserPreview(),
              ),
              // Messages list
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentPrimary,
                        ),
                      )
                    : _errorMessage != null
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
                                  'Failed to load messages',
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
                                  onPressed: _loadMessages,
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
                        : _MessagesList(
                            messages: _messagesForUI,
                            scrollController: _scrollController,
                            onMessageLongPress: _showMessageOptions,
                            isSelectionMode: _isSelectionMode,
                            selectedMessageIds: _selectedMessageIds,
                            onMessageTap: _toggleMessageSelection,
                            uploadProgress: _uploadProgress,
                            downloadProgress: _downloadProgress,
                            onDocumentTap: (msg) => _downloadDocument(msg),
                          ),
              ),
              // Chat Footer - WhatsApp style
              _ChatFooter(
                messageController: _messageController,
                focusNode: _focusNode,
                onSend: _sendMessage,
                onVoiceMessage: () {}, // Not used anymore, audio recording handled separately
                replyingToMessage: _replyingToMessage,
                onCancelReply: _cancelReply,
                onDocumentSelected: _pickAndSendDocument,
                onImageSelected: _pickAndSendImage,
                onCameraSelected: _takePhotoAndSend,
                isRecordingAudio: _isRecordingAudio,
                isRecordingLocked: _isRecordingLocked,
                recordingDuration: _audioService.isRecording 
                    ? _audioService.currentRecordingDuration 
                    : Duration.zero,
                onStartRecording: _startAudioRecording,
                onStopRecording: _stopAudioRecordingAndSend,
                onCancelRecording: _cancelAudioRecording,
                onLockRecording: _lockAudioRecording,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selection Mode Header - Shows when messages are selected for forwarding
class _SelectionModeHeader extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onForward;

  const _SelectionModeHeader({
    required this.selectedCount,
    required this.onCancel,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(
            color: AppColors.glassBorder.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
            color: AppColors.textPrimary,
          ),
          Expanded(
            child: Text(
              '$selectedCount ${selectedCount == 1 ? 'message' : 'messages'} selected',
              style: AppTextStyles.headlineSmall(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.forward),
            onPressed: selectedCount > 0 ? onForward : null,
            color: selectedCount > 0
                ? AppColors.accentPrimary
                : AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String userName;
  final String userUsername;
  final String? profilePicture;
  final bool isOnline;
  final VoidCallback onBack;
  final VoidCallback onVoiceCall;
  final VoidCallback onVideoCall;
  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;

  const _ChatHeader({
    required this.userName,
    required this.userUsername,
    this.profilePicture,
    required this.isOnline,
    required this.onBack,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onMenuTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(color: Colors.transparent),
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
              const SizedBox(width: 8),
              // Profile picture - tappable
              GestureDetector(
                onTap: onProfileTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentPrimary.withOpacity(0.2),
                        border: Border.all(
                          color: AppColors.glassBorder.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: profilePicture != null && profilePicture!.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: profilePicture!,
                                fit: BoxFit.cover,
                                width: 40,
                                height: 40,
                                placeholder: (context, url) => Center(
                                  child: Icon(
                                    Icons.person,
                                    color: AppColors.accentPrimary,
                                    size: 24,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Icon(
                                    Icons.person,
                                    color: AppColors.accentPrimary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.person,
                              color: AppColors.accentPrimary,
                              size: 24,
                            ),
                    ),
                    // Online indicator
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
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
              ),
              const SizedBox(width: 12),
              // Name and status - tappable
              Expanded(
                child: GestureDetector(
                  onTap: onProfileTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: AppTextStyles.bodyLarge(weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isOnline ? 'online' : 'offline',
                        style: AppTextStyles.bodySmall(
                          color: isOnline
                              ? AppColors.success
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Voice call icon
              GestureDetector(
                onTap: onVoiceCall,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.call,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
              // Video call icon
              GestureDetector(
                onTap: onVideoCall,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.videocam,
                    color: AppColors.textPrimary,
                    size: 22,
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

class _MessagesList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final ScrollController scrollController;
  final Function(String) onMessageLongPress;
  final bool isSelectionMode;
  final Set<String> selectedMessageIds;
  final Function(String) onMessageTap;
  final Map<String, double> uploadProgress;
  final Map<String, double> downloadProgress;
  final Function(Message)? onDocumentTap;

  const _MessagesList({
    required this.messages,
    required this.scrollController,
    required this.onMessageLongPress,
    this.isSelectionMode = false,
    this.selectedMessageIds = const {},
    required this.onMessageTap,
    this.uploadProgress = const {},
    this.downloadProgress = const {},
    this.onDocumentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
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
              'Start the conversation',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final messageId = message['id'] as String;
        final msg = message['message'] as Message;
        final isSelected = isSelectionMode && selectedMessageIds.contains(messageId);
        
        return GestureDetector(
          onTap: isSelectionMode
              ? () => onMessageTap(messageId)
              : null,
          onLongPress: isSelectionMode
              ? null
              : () => onMessageLongPress(messageId),
          child: Stack(
            children: [
              // Show AudioMessageBubble for audio messages
              msg.messageType == MessageType.audio
                  ? AudioMessageBubble(
                      messageId: messageId,
                      attachmentUrl: msg.attachmentUrl,
                      attachmentSize: msg.attachmentSize,
                      isMe: message['isMe'] as bool,
                      timestamp: message['timestamp'] as DateTime,
                      status: message['status'] as MessageStatus?,
                    )
                  : _MessageBubble(
                      messageId: messageId,
          text: message['text'] as String,
          isMe: message['isMe'] as bool,
          timestamp: message['timestamp'] as DateTime,
                      status: message['status'] as MessageStatus?,
                      deliveredAt: message['deliveredAt'] as DateTime?,
                      readAt: message['readAt'] as DateTime?,
                      editedAt: message['editedAt'] as DateTime?,
                      editCount: message['editCount'] as int? ?? 0,
          reactions:
              (message['reactions'] as Map<String, String>?) ??
              <String, String>{},
          isStarred: (message['isStarred'] as bool?) ?? false,
          isPinned: (message['isPinned'] as bool?) ?? false,
                      repliedToMessage: message['repliedToMessage'] as Message?,
                      replyToId: message['replyToId'] as String?,
                      isForwarded: msg.isForwarded,
                      forwardedFrom: msg.sender, // Original sender
                      isDeleted: msg.isDeleted,
                      deletedFor: msg.deletedFor,
                      messageType: msg.messageType,
                      attachmentUrl: msg.attachmentUrl,
                      attachmentName: msg.attachmentName,
                      attachmentSize: msg.attachmentSize,
                      attachmentType: msg.attachmentType,
                      uploadProgress: uploadProgress[messageId],
                      downloadProgress: downloadProgress[messageId],
                      onDocumentTap: msg.messageType == MessageType.file && (msg.attachmentName != null || msg.attachmentUrl != null) && onDocumentTap != null
                          ? () => onDocumentTap!(msg)
                          : null,
                      isFileDownloaded: false, // Will be checked via FutureBuilder in the bubble
                      thumbnailUrl: msg.thumbnailUrl,
                      onLongPress: () => onMessageLongPress(messageId),
                      onQuotedMessageTap: (replyToId) {
                        // Scroll to original message - will be handled by parent
                        // For now, just scroll to bottom and let user find it
                        // TODO: Implement proper scroll-to-message with GlobalKey
                        scrollController.animateTo(
                          scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
              // Selection indicator
              if (isSelectionMode)
                Positioned(
                  top: 8,
                  left: message['isMe'] as bool ? null : 8,
                  right: message['isMe'] as bool ? 8 : null,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentPrimary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentPrimary
                            : AppColors.textTertiary,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String messageId;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final MessageStatus? status;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? editedAt;
  final int editCount;
  final Map<String, String> reactions;
  final bool isStarred;
  final bool isPinned;
  final Message? repliedToMessage;
  final String? replyToId;
  final bool isForwarded;
  final User? forwardedFrom; // Original sender
  final bool isDeleted;
  final String? deletedFor; // 'me' or 'everyone'
  final MessageType messageType;
  final String? attachmentUrl;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentType;
  final double? uploadProgress;
  final double? downloadProgress;
  final VoidCallback? onDocumentTap;
  final bool isFileDownloaded; // Whether the file is already downloaded
  final String? thumbnailUrl; // Thumbnail URL for preview
  final VoidCallback onLongPress;
  final Function(String)? onQuotedMessageTap;

  const _MessageBubble({
    required this.messageId,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.status,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
    this.editCount = 0,
    required this.reactions,
    required this.isStarred,
    required this.isPinned,
    this.repliedToMessage,
    this.replyToId,
    this.isForwarded = false,
    this.forwardedFrom,
    this.isDeleted = false,
    this.deletedFor,
    this.messageType = MessageType.text,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentType,
    this.uploadProgress,
    this.downloadProgress,
    this.onDocumentTap,
    this.isFileDownloaded = false,
    this.thumbnailUrl,
    required this.onLongPress,
    this.onQuotedMessageTap,
  });

  /// Format timestamp for display (12-hour format with AM/PM)
  /// Converts to local time and displays in Pakistan timezone
  String _formatTime(DateTime dateTime) {
    // Ensure timestamp is in local time
    final localDateTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final now = DateTime.now();
    final difference = now.difference(localDateTime);
    
    // Convert to 12-hour format using local time
    int hour = localDateTime.hour;
    final String period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final String minute = localDateTime.minute.toString().padLeft(2, '0');
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inDays < 1) {
      // Today: show time only (e.g., "2:30 PM")
      return '$hour:$minute $period';
    } else if (difference.inDays < 7) {
      // This week: show day and time (e.g., "Mon 2:30 PM")
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[localDateTime.weekday - 1]} $hour:$minute $period';
    } else {
      // Older: show date and time (e.g., "12/25 2:30 PM")
      return '${localDateTime.month}/${localDateTime.day} $hour:$minute $period';
    }
  }

  /// Build document bubble UI - WhatsApp style with preview
  Widget _buildDocumentBubble() {
    final fileName = attachmentName ?? 'Unknown File';
    final fileSize = attachmentSize ?? 0;
    final isUploading = uploadProgress != null && uploadProgress! < 1.0;
    final isDownloading = downloadProgress != null && downloadProgress! < 1.0;
    
    // Determine file type
    bool isImage = false;
    bool isPdf = false;
    IconData fileIcon = Icons.description;
    
    if (attachmentType != null) {
      final ext = attachmentType!.toLowerCase();
      final mimeType = ext.contains('/') ? ext.split('/').first : ext;
      final fileExt = fileName.toLowerCase().split('.').last;
      
      if (mimeType == 'image' || ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExt)) {
        isImage = true;
        fileIcon = Icons.image;
      } else if (mimeType == 'application' && (ext.contains('pdf') || fileExt == 'pdf')) {
        isPdf = true;
        fileIcon = Icons.picture_as_pdf;
      } else if (mimeType == 'video' || ['mp4', 'mov', 'avi', 'webm'].contains(fileExt)) {
        fileIcon = Icons.video_file;
      } else if (mimeType == 'audio' || ['mp3', 'wav', 'm4a', 'aac'].contains(fileExt)) {
        fileIcon = Icons.audio_file;
      }
    } else if (fileName.isNotEmpty) {
      final fileExt = fileName.toLowerCase().split('.').last;
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExt)) {
        isImage = true;
        fileIcon = Icons.image;
      } else if (fileExt == 'pdf') {
        isPdf = true;
        fileIcon = Icons.picture_as_pdf;
      } else if (['mp4', 'mov', 'avi', 'webm'].contains(fileExt)) {
        fileIcon = Icons.video_file;
      } else if (['mp3', 'wav', 'm4a', 'aac'].contains(fileExt)) {
        fileIcon = Icons.audio_file;
      }
    }

    String formatFileSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    // Build full URL from relative attachment URL
    String? getFullAttachmentUrl(String? url) {
      if (url == null) return null;
      // If already a full URL (starts with http:// or https://), return as-is
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
      // Otherwise, build full URL from base URL
      final baseUrl = ApiConfig.baseUrlSync;
      // Remove /api/v1 from base URL if present, as attachment URLs are typically at root
      final cleanBaseUrl = baseUrl.replaceAll('/api/v1', '');
      // Ensure attachment URL starts with /
      final attachmentPath = url.startsWith('/') ? url : '/$url';
      return '$cleanBaseUrl$attachmentPath';
    }

    final fullAttachmentUrl = getFullAttachmentUrl(attachmentUrl);
    final fullThumbnailUrl = getFullAttachmentUrl(thumbnailUrl);
    
    // Show preview for images and PDFs
    final showPreview = (isImage || isPdf) && fullAttachmentUrl != null && !isUploading && !isDownloading;

    // Check if file is downloaded (async check)
    return FutureBuilder<bool>(
      future: fullAttachmentUrl != null && messageType == MessageType.file
          ? FileStorageService().isFileDownloaded(messageId)
          : Future.value(false),
      builder: (context, snapshot) {
        final fileIsDownloaded = snapshot.data ?? isFileDownloaded;
        
    return GestureDetector(
      onTap: onDocumentTap,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.accentPrimary
              : AppColors.backgroundSecondary.withOpacity(0.8),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(12),
          ),
          border: Border(
            left: BorderSide(
              color: isMe
                  ? AppColors.accentPrimary
                  : AppColors.backgroundSecondary.withOpacity(0.8),
              width: 1,
            ),
            right: BorderSide(
              color: isMe
                  ? AppColors.accentPrimary
                  : AppColors.backgroundSecondary.withOpacity(0.8),
              width: 1,
            ),
            top: BorderSide(
              color: isMe
                  ? AppColors.accentPrimary
                  : AppColors.backgroundSecondary.withOpacity(0.8),
              width: 1,
            ),
            bottom: BorderSide.none, // No bottom border
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview section (for images/PDFs)
            if (showPreview)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
                child: Stack(
                  children: [
                    // Preview image
                    if (isImage && fullAttachmentUrl != null)
                      CachedNetworkImage(
                        imageUrl: fullAttachmentUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: isMe
                              ? Colors.white.withOpacity(0.1)
                              : AppColors.backgroundPrimary.withOpacity(0.3),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMe ? Colors.white : AppColors.accentPrimary,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: isMe
                              ? Colors.white.withOpacity(0.1)
                              : AppColors.backgroundPrimary.withOpacity(0.3),
                          child: Icon(
                            fileIcon,
                            size: 48,
                            color: isMe
                                ? Colors.white.withOpacity(0.5)
                                : AppColors.textSecondary,
                          ),
                        ),
                      )
                    else if (isPdf)
                      // Show thumbnail if available, otherwise show PDF icon placeholder
                      fullThumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: fullThumbnailUrl!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 200,
                                color: isMe
                                    ? Colors.white.withOpacity(0.1)
                                    : AppColors.backgroundPrimary.withOpacity(0.3),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isMe ? Colors.white : AppColors.accentPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 200,
                                color: isMe
                                    ? Colors.white.withOpacity(0.1)
                                    : AppColors.backgroundPrimary.withOpacity(0.3),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf,
                                        size: 64,
                                        color: isMe
                                            ? Colors.white.withOpacity(0.8)
                                            : AppColors.accentPrimary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'PDF Document',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isMe
                                              ? Colors.white.withOpacity(0.8)
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              height: 200,
                              color: isMe
                                  ? Colors.white.withOpacity(0.1)
                                  : AppColors.backgroundPrimary.withOpacity(0.3),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      size: 64,
                                      color: isMe
                                          ? Colors.white.withOpacity(0.8)
                                          : AppColors.accentPrimary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'PDF Document',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isMe
                                            ? Colors.white.withOpacity(0.8)
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    // Progress overlay
                    if (isUploading || isDownloading)
                      Container(
                        height: 200,
                        color: Colors.black.withOpacity(0.3),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: isUploading ? uploadProgress : downloadProgress,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isUploading
                                    ? '${((uploadProgress ?? 0) * 100).toInt()}%'
                                    : '${((downloadProgress ?? 0) * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            // File info section
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // File icon (if no preview shown)
                  if (!showPreview)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.backgroundPrimary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        fileIcon,
                        size: 32,
                        color: isMe ? Colors.white : AppColors.accentPrimary,
                      ),
                    ),
                  if (!showPreview) const SizedBox(width: 12),
                  // File name and size
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isMe ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatFileSize(fileSize),
                          style: TextStyle(
                            fontSize: 12,
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Download/Open icon (only show if not uploading/downloading)
                  if (!isUploading && !isDownloading)
                    Icon(
                      fileIsDownloaded ? Icons.open_in_new : Icons.download,
                      size: 24,
                      color: isMe
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textSecondary,
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

  /// Get status icon based on message status
  Widget _getStatusIcon() {
    if (!isMe) return const SizedBox.shrink();
    
    // Single tick (sent) - gray
    if (status == MessageStatus.sent) {
      return Icon(
        Icons.done,
        size: 16,
        color: AppColors.textTertiary.withOpacity(0.7),
      );
    }
    // Double tick (delivered) - gray
    else if (status == MessageStatus.delivered || deliveredAt != null) {
      return Icon(
        Icons.done_all,
        size: 16,
        color: AppColors.textTertiary.withOpacity(0.7),
      );
    }
    // Double tick (read) - blue
    else if (status == MessageStatus.read || readAt != null) {
      return Icon(
        Icons.done_all,
        size: 16,
        color: Colors.blueAccent,
      );
    }
    // Default: single tick
    return Icon(
      Icons.done,
      size: 16,
      color: AppColors.textTertiary.withOpacity(0.7),
    );
  }

  /// Build reaction emojis list (group by emoji, show count if > 1)
  List<Widget> _buildReactionEmojis() {
    if (reactions.isEmpty) return [];
    
    // Group reactions by emoji
    final Map<String, int> emojiCounts = {};
    for (final emoji in reactions.values) {
      emojiCounts[emoji] = (emojiCounts[emoji] ?? 0) + 1;
    }
    
    // Build widgets for each unique emoji
    final List<Widget> widgets = [];
    emojiCounts.forEach((emoji, count) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 14),
              ),
              if (count > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
    
    return widgets;
  }


  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
          padding: const EdgeInsets.only(left: 7, top: 6, right: 7, bottom: 6),
              decoration: BoxDecoration(
                color: isMe
                ? AppColors.accentPrimary
                : AppColors.backgroundSecondary.withOpacity(0.8),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 12),
                ),
              ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Forwarded indicator (if forwarded)
                  if (isForwarded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Forwarded',
                            style: TextStyle(
                              fontSize: 11,
                              color: isMe
                                  ? Colors.white.withOpacity(0.7)
                                  : AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Original sender name (if available)
                          if (forwardedFrom != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              forwardedFrom?.displayName ?? forwardedFrom?.username ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe
                                    ? Colors.white.withOpacity(0.7)
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  // Quoted message preview (if replying)
                  if (repliedToMessage != null && replyToId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _QuotedMessageInBubble(
                        message: repliedToMessage!,
                        isMe: isMe,
                        onTap: () => onQuotedMessageTap?.call(replyToId!),
                      ),
                    ),
                  // Message content: text, document, or deleted placeholder
                  Padding(
                    padding: EdgeInsets.only(
                      right: 60,
                      bottom: reactions.isNotEmpty ? 20 : 16,
                    ),
                    child: isDeleted && deletedFor == 'everyone'
                        ? Text(
                            'This message was deleted',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: isMe
                                  ? Colors.white.withOpacity(0.7)
                                  : AppColors.textTertiary,
                            ),
                          )
                        : messageType == MessageType.file && (attachmentName != null || attachmentUrl != null)
                            ? _buildDocumentBubble()
                            : text.isNotEmpty
                                ? Text(
                text,
                style: AppTextStyles.bodyMedium(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                ),
                                  )
                                : const SizedBox.shrink(),
              ),
                ],
            ),
              // Reactions at bottom-left (like WhatsApp)
            if (reactions.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withOpacity(0.2)
                          : AppColors.backgroundPrimary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show unique emojis (group by emoji, show count if > 1)
                        ..._buildReactionEmojis(),
                      ],
                    ),
                  ),
                ),
              // Timestamp and status at bottom-right corner
              Positioned(
                bottom: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Timestamp
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        color: isMe
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                    // Status icon (only for my messages)
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _getStatusIcon(),
                    ],
                    // Edited indicator (after timestamp/status, like WhatsApp)
                    if (editedAt != null && editCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        'edited',
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : AppColors.textTertiary,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                    ],
                  ],
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

class _MessageOptionsMenu extends StatefulWidget {
  final String messageId;
  final bool isMe;
  final String messageText;
  final bool canEdit;
  final VoidCallback onReaction;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onEdit;
  final VoidCallback onStar;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onInfo;

  const _MessageOptionsMenu({
    required this.messageId,
    required this.isMe,
    required this.messageText,
    this.canEdit = false,
    required this.onReaction,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    required this.onEdit,
    required this.onStar,
    required this.onPin,
    required this.onDelete,
    required this.onShare,
    required this.onInfo,
  });

  @override
  State<_MessageOptionsMenu> createState() => _MessageOptionsMenuState();
}

class _MessageOptionsMenuState extends State<_MessageOptionsMenu> {
  late final FixedExtentScrollController _scrollController;
  int _selectedIndex = 0;

  List<Map<String, dynamic>> get _options {
    final options = [
      {
        'icon': Icons.add_reaction,
        'label': 'Reaction',
        'callback': widget.onReaction,
        'isDestructive': false,
      },
      {
        'icon': Icons.reply,
        'label': 'Reply',
        'callback': widget.onReply,
        'isDestructive': false,
      },
      {
        'icon': Icons.copy,
        'label': 'Copy',
        'callback': widget.onCopy,
        'isDestructive': false,
      },
      {
        'icon': Icons.forward,
        'label': 'Forward',
        'callback': widget.onForward,
        'isDestructive': false,
      },
      if (widget.isMe && widget.canEdit)
        {
          'icon': Icons.edit,
          'label': 'Edit',
          'callback': widget.onEdit,
          'isDestructive': false,
        },
      {
        'icon': Icons.star_border,
        'label': 'Star',
        'callback': widget.onStar,
        'isDestructive': false,
      },
      {
        'icon': Icons.push_pin,
        'label': 'Pin',
        'callback': widget.onPin,
        'isDestructive': false,
      },
      {
        'icon': Icons.delete_outline,
        'label': 'Delete',
        'callback': widget.onDelete,
        'isDestructive': true,
      },
      {
        'icon': Icons.share,
        'label': 'Share',
        'callback': widget.onShare,
        'isDestructive': false,
      },
      {
        'icon': Icons.info_outline,
        'label': 'Info',
        'callback': widget.onInfo,
        'isDestructive': false,
      },
    ];
    return options;
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
    final option = _options[_selectedIndex];
    Navigator.pop(context);
    // Small delay to ensure menu is closed before triggering action
    Future.delayed(const Duration(milliseconds: 100), () {
      (option['callback'] as VoidCallback)();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Wheel picker for message options
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
                        if (index < 0 || index >= _options.length) {
                          return const SizedBox.shrink();
                        }
                        final option = _options[index];
                        final isSelected = index == _selectedIndex;

                        return _MessageOptionWheelItem(
                          icon: option['icon'] as IconData,
                          label: option['label'] as String,
                          isSelected: isSelected,
                          isDestructive: option['isDestructive'] as bool,
                        );
                      },
                      childCount: _options.length,
                    ),
                  ),
                ],
              ),
            ),
            // Select button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Select',
                    style: AppTextStyles.bodyLarge(
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageOptionWheelItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDestructive;

  const _MessageOptionWheelItem({
    required this.icon,
    required this.label,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected
                ? (isDestructive
                      ? AppColors.accentQuaternary
                      : AppColors.accentPrimary)
                : (isDestructive
                      ? AppColors.accentQuaternary.withOpacity(0.5)
                      : AppColors.textSecondary.withOpacity(0.5)),
            size: isSelected ? 24 : 20,
          ),
          const SizedBox(width: 12),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            style: isSelected
                ? AppTextStyles.bodyLarge(
                    color: isDestructive
                        ? AppColors.accentQuaternary
                        : AppColors.accentPrimary,
                    weight: FontWeight.w600,
                  )
                : AppTextStyles.bodyMedium(
                    color: isDestructive
                        ? AppColors.accentQuaternary.withOpacity(0.5)
                        : AppColors.textSecondary.withOpacity(0.5),
                  ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _ChatFooter extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onVoiceMessage;
  final Message? replyingToMessage;
  final VoidCallback? onCancelReply;
  final VoidCallback? onDocumentSelected;
  final VoidCallback? onImageSelected;
  final VoidCallback? onCameraSelected;
  final bool isRecordingAudio;
  final bool isRecordingLocked;
  final Duration recordingDuration;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onLockRecording;

  const _ChatFooter({
    required this.messageController,
    required this.focusNode,
    required this.onSend,
    required this.onVoiceMessage,
    this.replyingToMessage,
    this.onCancelReply,
    this.onDocumentSelected,
    this.onImageSelected,
    this.onCameraSelected,
    required this.isRecordingAudio,
    required this.isRecordingLocked,
    required this.recordingDuration,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.onLockRecording,
  });

  @override
  State<_ChatFooter> createState() => _ChatFooterState();
}

class _ChatFooterState extends State<_ChatFooter>
    with TickerProviderStateMixin {
  bool _isTyping = false;
  bool _isRecording = false;
  bool _isLocked = false;
  bool _isCanceling = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Offset _dragOffset = Offset.zero;
  Timer? _recordingTimer;
  late AnimationController _waveformController;
  int _timerTickCount = 0;

  @override
  void initState() {
    super.initState();
    widget.messageController.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isTyping = widget.messageController.text.trim().isNotEmpty;
    });
  }

  void _onFocusChanged() {
    setState(() {});
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AttachmentMenu(
        onDocumentSelected: widget.onDocumentSelected,
        onImageSelected: widget.onImageSelected,
        onCameraSelected: widget.onCameraSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const BoxDecoration(color: Colors.transparent),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quoted message preview
                    if (widget.replyingToMessage != null)
                      _QuotedMessagePreview(
                        message: widget.replyingToMessage!,
                        onCancel: widget.onCancelReply ?? () {},
                      ),
                    // Audio recorder widget (when recording) - replaces text field
                    if (widget.isRecordingAudio)
                      AudioRecorderWidget(
                        isLocked: widget.isRecordingLocked,
                        onCancel: widget.onCancelRecording,
                        onSend: (filePath) => widget.onStopRecording(),
                        onLock: widget.onLockRecording,
                      )
                    else
                    // Text input field with attachment icon
                    IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 100),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary.withOpacity(
                              0.5,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.glassBorder.withOpacity(0.2),
                              width: 0.5,
                            ),
                          ),
                          child: TextField(
                            controller: widget.messageController,
                            focusNode: widget.focusNode,
                            textAlign: TextAlign.left,
                            textAlignVertical: TextAlignVertical.center,
                            style: AppTextStyles.bodyMedium(),
                            maxLines: null,
                                textInputAction: TextInputAction.newline,
                                keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                                  hintText: widget.replyingToMessage != null
                                      ? 'Replying to ${widget.replyingToMessage!.sender?.displayName ?? widget.replyingToMessage!.sender?.username ?? "message"}'
                                      : 'Type a message',
                              hintStyle: AppTextStyles.bodyMedium(
                                color: AppColors.textTertiary,
                              ),
                              border: InputBorder.none,
                              suffixIcon: GestureDetector(
                                onTap: () => _showAttachmentMenu(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.attach_file,
                                    color: AppColors.textSecondary,
                                    size: 24,
                                  ),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              filled: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send button or voice button - matches typing box height
                      if (_isTyping)
                        GestureDetector(
                          onTap: widget.onSend,
                          child: Container(
                            width: 48,
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "We appologize for the inconvenience but voice notes are not working properly after end to end encryption.. we are working very hard to fix this feature",
                                  style: AppTextStyles.bodyMedium(color: Colors.white),
                                ),
                                backgroundColor: AppColors.error,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                          child: Container(
                            width: 48,
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 24,
                            ),
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
          ),
      ],
    );
  }
}

/// Quoted message preview widget (shown above input when replying)
class _QuotedMessagePreview extends StatelessWidget {
  final Message message;
  final VoidCallback onCancel;

  const _QuotedMessagePreview({
    required this.message,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMine;
    final senderName = message.sender?.displayName ?? 
                      message.sender?.username ?? 
                      'Unknown';
    
    // Truncate message text if too long
    final displayText = message.content.length > 50
        ? '${message.content.substring(0, 50)}...'
        : message.content;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Colored bar on left (purple for sent, gray for received)
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: isMe ? AppColors.accentPrimary : AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender name
                Text(
                  senderName,
                  style: AppTextStyles.bodySmall(
                    color: isMe ? AppColors.accentPrimary : AppColors.textSecondary,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                // Message text
                Text(
                  displayText,
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Cancel button
          GestureDetector(
            onTap: onCancel,
            child: Icon(
              Icons.close,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quoted message display inside message bubble
class _QuotedMessageInBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback onTap;

  const _QuotedMessageInBubble({
    required this.message,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final quotedIsMe = message.isMine;
    final senderName = message.sender?.displayName ?? 
                      message.sender?.username ?? 
                      'Unknown';
    
    // Truncate message text if too long
    final displayText = message.content.length > 50
        ? '${message.content.substring(0, 50)}...'
        : message.content;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.15)
              : AppColors.backgroundPrimary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              color: quotedIsMe ? AppColors.accentPrimary : AppColors.textTertiary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender name
            Text(
              senderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMe
                    ? Colors.white.withOpacity(0.9)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            // Message text
            Text(
              displayText,
              style: TextStyle(
                fontSize: 13,
                color: isMe
                    ? Colors.white.withOpacity(0.8)
                    : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Forward Picker Screen - Select conversations to forward messages to
class _ForwardPickerScreen extends StatefulWidget {
  final List<String> selectedMessageIds;
  final Function(List<String>) onForward;
  final VoidCallback onCancel;

  const _ForwardPickerScreen({
    required this.selectedMessageIds,
    required this.onForward,
    required this.onCancel,
  });

  @override
  State<_ForwardPickerScreen> createState() => _ForwardPickerScreenState();
}

class _ForwardPickerScreenState extends State<_ForwardPickerScreen> {
  final MessagesService _messagesService = MessagesService();
  final TextEditingController _searchController = TextEditingController();
  List<Conversation> _conversations = [];
  final Set<String> _selectedConversationIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _messagesService.getConversations(limit: 100);
      if (response.success && response.data != null) {
        setState(() {
          _conversations = response.data!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = response.error ?? 'Failed to load conversations';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load conversations: ${e.toString()}';
      });
    }
  }

  void _toggleConversationSelection(String conversationId) {
    setState(() {
      if (_selectedConversationIds.contains(conversationId)) {
        _selectedConversationIds.remove(conversationId);
      } else {
        _selectedConversationIds.add(conversationId);
      }
    });
  }

  List<Conversation> get _filteredConversations {
    if (_searchController.text.isEmpty) {
      return _conversations;
    }
    final query = _searchController.text.toLowerCase();
    return _conversations.where((conv) {
      final name = conv.otherUser?.displayName?.toLowerCase() ?? '';
      final username = conv.otherUser?.username?.toLowerCase() ?? '';
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                  color: AppColors.textPrimary,
                ),
                Expanded(
                  child: Text(
                    'Forward to',
                    style: AppTextStyles.headlineSmall(),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: _selectedConversationIds.isNotEmpty
                        ? AppColors.accentPrimary
                        : AppColors.textTertiary,
                  ),
                  onPressed: _selectedConversationIds.isNotEmpty
                      ? () => widget.onForward(_selectedConversationIds.toList())
                      : null,
                ),
              ],
            ),
          ),
          // Selected count
          if (_selectedConversationIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.backgroundPrimary.withOpacity(0.5),
              child: Row(
                children: [
                  Text(
                    '${_selectedConversationIds.length} selected',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.backgroundPrimary.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Conversations list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : _filteredConversations.isEmpty
                        ? Center(
                            child: Text(
                              'No conversations found',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredConversations.length,
                            itemBuilder: (context, index) {
                              final conversation = _filteredConversations[index];
                              final isSelected = _selectedConversationIds.contains(conversation.id);
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: conversation.otherUser?.profilePicture != null
                                      ? NetworkImage(conversation.otherUser!.profilePicture!)
                                      : null,
                                  child: conversation.otherUser?.profilePicture == null
                                      ? Text(
                                          (conversation.otherUser?.displayName?[0] ?? 
                                           conversation.otherUser?.username?[0] ?? 
                                           '?').toUpperCase(),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  conversation.otherUser?.displayName ?? 
                                  conversation.otherUser?.username ?? 
                                  'Unknown',
                                  style: AppTextStyles.bodyMedium(),
                                ),
                                subtitle: conversation.otherUser?.username != null
                                    ? Text(
                                        conversation.otherUser!.username!,
                                        style: AppTextStyles.bodySmall(
                                          color: AppColors.textTertiary,
                                        ),
                                      )
                                    : null,
                                trailing: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accentPrimary
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accentPrimary
                                          : AppColors.textTertiary,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                onTap: () => _toggleConversationSelection(conversation.id),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentMenu extends StatelessWidget {
  final VoidCallback? onDocumentSelected;
  final VoidCallback? onImageSelected;
  final VoidCallback? onCameraSelected;

  List<Map<String, dynamic>> get _attachments => [
    {'icon': Icons.photo_library, 'label': 'Gallery', 'color': Colors.blue, 'action': 'gallery'},
    {'icon': Icons.camera_alt, 'label': 'Camera', 'color': Colors.pink, 'action': 'camera'},
    {'icon': Icons.location_on, 'label': 'Location', 'color': Colors.teal, 'action': 'location'},
    {'icon': Icons.person, 'label': 'Contact', 'color': Colors.blue, 'action': 'contact'},
    {'icon': Icons.description, 'label': 'Document', 'color': Colors.purple, 'action': 'document'},
    {'icon': Icons.headphones, 'label': 'Audio', 'color': Colors.orange, 'action': 'audio'},
    {'icon': Icons.poll, 'label': 'Poll', 'color': Colors.yellow, 'action': 'poll'},
    {'icon': Icons.event, 'label': 'Event', 'color': Colors.pink, 'action': 'event'},
    {'icon': Icons.auto_awesome, 'label': 'AI images', 'color': Colors.blue, 'action': 'ai'},
  ];

  const _AttachmentMenu({
    this.onDocumentSelected,
    this.onImageSelected,
    this.onCameraSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 16, left: 16, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Attachment options grid (3 columns like WhatsApp)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemCount: _attachments.length,
              itemBuilder: (context, index) {
                final attachment = _attachments[index];
                final action = attachment['action'] as String;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    switch (action) {
                      case 'document':
                        onDocumentSelected?.call();
                        break;
                      case 'gallery':
                        onImageSelected?.call();
                        break;
                      case 'camera':
                        onCameraSelected?.call();
                        break;
                      default:
                        // TODO: Handle other attachment types
                        break;
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: (attachment['color'] as Color).withOpacity(
                            0.2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          attachment['icon'] as IconData,
                          color: attachment['color'] as Color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        attachment['label'] as String,
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Professional top-right notification widget
class _TopRightNotification extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _TopRightNotification({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_TopRightNotification> createState() => _TopRightNotificationState();
}

class _TopRightNotificationState extends State<_TopRightNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final accentColor = widget.isError
        ? AppColors.accentQuaternary
        : AppColors.success;

    return Positioned(
      top: safeAreaTop + 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: screenWidth * 0.75,
                      minWidth: 200,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      // Transparent background with subtle tint
                      color: AppColors.backgroundSecondary.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: accentColor.withOpacity(0.1),
                          blurRadius: 15,
                          spreadRadius: -5,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon with accent background
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentColor.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            widget.isError
                                ? Icons.error_rounded
                                : Icons.check_circle_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Message
                        Flexible(
                          child: Text(
                            widget.message,
                            style:
                                AppTextStyles.bodyMedium(
                                  color: AppColors.textPrimary,
                                  weight: FontWeight.w600,
                                ).copyWith(
                                  fontSize: 14,
                                  letterSpacing: 0.1,
                                  height: 1.4,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Close button with glass effect
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _dismiss,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// User Preview Dialog - WhatsApp style
class _UserPreviewDialog extends StatelessWidget {
  final String userName;
  final String userUsername;
  final String? profilePicture;
  final bool isOnline;

  const _UserPreviewDialog({
    required this.userName,
    required this.userUsername,
    this.profilePicture,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _UserPreviewHeader(
                userName: userName,
                userUsername: userUsername,
                profilePicture: profilePicture,
                isOnline: isOnline,
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: bottomPadding + 16,
                    left: 0,
                    right: 0,
                  ),
                  children: [
                    _SettingsSection(),
                    const SizedBox(height: 8),
                    _PrivacySection(),
                    const SizedBox(height: 8),
                    _CommunitiesSection(),
                    const SizedBox(height: 8),
                    _MediaGallerySection(),
                    const SizedBox(height: 8),
                    _ActionsSection(
                      userName: userName,
                      userUsername: userUsername.replaceAll('@', ''),
                    ),
                    SizedBox(height: bottomPadding + 8),
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

class _UserPreviewHeader extends StatelessWidget {
  final String userName;
  final String userUsername;
  final String? profilePicture;
  final bool isOnline;

  const _UserPreviewHeader({
    required this.userName,
    required this.userUsername,
    this.profilePicture,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentPrimary.withOpacity(0.2),
                  border: Border.all(
                    color: AppColors.accentPrimary.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: profilePicture != null && profilePicture!.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: profilePicture!,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          placeholder: (context, url) => Center(
                            child: Icon(
                              Icons.person,
                              color: AppColors.accentPrimary,
                              size: 60,
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              Icons.person,
                              color: AppColors.accentPrimary,
                              size: 60,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: AppColors.accentPrimary,
                        size: 60,
                      ),
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.backgroundSecondary,
                        width: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            style: AppTextStyles.headlineMedium(weight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            userUsername,
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.textTertiary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? AppColors.success
                        : AppColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: AppTextStyles.bodySmall(
                    color: isOnline
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      children: [
        _SectionTitle(title: 'Settings'),
        _SettingTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Customize notification settings',
          onTap: () {},
        ),
        _Divider(),
        _SettingTile(
          icon: Icons.visibility_outlined,
          title: 'Media Visibility',
          subtitle: 'Show media in gallery',
          trailing: Switch(
            value: true,
            onChanged: (value) {},
            activeColor: AppColors.accentPrimary,
          ),
        ),
        _Divider(),
        _SettingTile(
          icon: Icons.star_outline,
          title: 'Starred Messages',
          subtitle: 'View starred messages',
          onTap: () {},
        ),
        _Divider(),
        _SettingTile(
          icon: Icons.lock_outline,
          title: 'Encryption',
          subtitle: 'Messages are end-to-end encrypted',
          trailing: Icon(Icons.verified, color: AppColors.success, size: 20),
        ),
      ],
    );
  }
}

class _PrivacySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      children: [
        _SectionTitle(title: 'Privacy'),
        _SettingTile(
          icon: Icons.timer_outlined,
          title: 'Disappearing Messages',
          subtitle: 'Off',
          onTap: () {},
        ),
        _Divider(),
        _SettingTile(
          icon: Icons.lock_outline,
          title: 'Chat Lock',
          subtitle: 'Lock this chat with fingerprint',
          trailing: Switch(
            value: false,
            onChanged: (value) {},
            activeColor: AppColors.accentPrimary,
          ),
        ),
        _Divider(),
        _SettingTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Advanced Chat Privacy',
          subtitle: 'Manage advanced privacy settings',
          onTap: () {},
        ),
      ],
    );
  }
}

class _CommunitiesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      children: [
        _SectionTitle(title: 'Communities & Groups'),
        _SettingTile(
          icon: Icons.people_outline,
          title: 'Communities and Groups in Common',
          subtitle: '2 groups in common',
          onTap: () {},
        ),
      ],
    );
  }
}

class _MediaGallerySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      children: [
        _SectionTitle(title: 'Media, Links, and Docs'),
        _MediaGalleryTile(
          icon: Icons.photo_library_outlined,
          title: 'Media',
          count: 24,
          onTap: () {},
        ),
        _Divider(),
        _MediaGalleryTile(
          icon: Icons.link_outlined,
          title: 'Links',
          count: 8,
          onTap: () {},
        ),
        _Divider(),
        _MediaGalleryTile(
          icon: Icons.description_outlined,
          title: 'Docs',
          count: 5,
          onTap: () {},
        ),
        _Divider(),
        _MediaGalleryTile(
          icon: Icons.audiotrack_outlined,
          title: 'Audio',
          count: 12,
          onTap: () {},
        ),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final String userName;
  final String userUsername;

  const _ActionsSection({
    required this.userName,
    required this.userUsername,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      children: [
        _SectionTitle(title: 'Actions'),
        _ActionTile(
          icon: Icons.person_outline,
          title: 'View Profile',
          isDestructive: false,
          onTap: () {
            Navigator.pop(context); // Close dialog
            context.push('/profile/$userUsername');
          },
        ),
        _Divider(),
        _ActionTile(
          icon: Icons.person_remove_outlined,
          title: 'Unfollow',
          isDestructive: false,
          onTap: () => Navigator.pop(context),
        ),
        _Divider(),
        _ActionTile(
          icon: Icons.link_off_outlined,
          title: 'Unconnect',
          isDestructive: false,
          onTap: () => Navigator.pop(context),
        ),
        _Divider(),
        _ActionTile(
          icon: Icons.cancel_outlined,
          title: 'Uncollaborate',
          isDestructive: false,
          onTap: () => Navigator.pop(context),
        ),
        _Divider(),
        _ActionTile(
          icon: Icons.block_outlined,
          title: 'Block $userName',
          isDestructive: true,
          onTap: () => Navigator.pop(context),
        ),
        _Divider(),
        _ActionTile(
          icon: Icons.flag_outlined,
          title: 'Report $userName',
          isDestructive: true,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final List<Widget> children;

  const _SectionContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.glassBorder.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppTextStyles.labelLarge(
          color: AppColors.textSecondary,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.accentPrimary, size: 22),
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium(weight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _MediaGalleryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  const _MediaGalleryTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.accentPrimary, size: 22),
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium(weight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
        ],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.isDestructive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color:
              (isDestructive
                      ? AppColors.accentQuaternary
                      : AppColors.accentPrimary)
                  .withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? AppColors.accentQuaternary
              : AppColors.accentPrimary,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium(
          weight: FontWeight.w500,
          color: isDestructive
              ? AppColors.accentQuaternary
              : AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 72,
      color: AppColors.glassBorder.withOpacity(0.1),
    );
  }
}

/// Chat Menu Dialog - WhatsApp style
class _ChatMenuDialog extends StatefulWidget {
  final String userName;
  final Function(String, bool) onShowNotification;

  const _ChatMenuDialog({
    required this.userName,
    required this.onShowNotification,
  });

  @override
  State<_ChatMenuDialog> createState() => _ChatMenuDialogState();
}

class _ChatMenuDialogState extends State<_ChatMenuDialog> {
  late final FixedExtentScrollController _scrollController;
  int _selectedIndex = 0;

  List<Map<String, dynamic>> get _menuOptions {
    return [
      {
        'icon': Icons.search,
        'title': 'Search',
        'message': 'Search feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.group_add,
        'title': 'New Group',
        'message': 'New group feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.photo_library,
        'title': 'Media',
        'message': 'Media gallery feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.notifications_off,
        'title': 'Mute',
        'message': 'Mute notifications feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.timer_outlined,
        'title': 'Disappearing Messages',
        'message': 'Disappearing messages feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.palette_outlined,
        'title': 'Theme',
        'message': 'Chat theme feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.flag_outlined,
        'title': 'Report',
        'message': 'Report feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.block_outlined,
        'title': 'Block ${widget.userName}',
        'message': 'Block user feature coming soon',
        'isDestructive': true,
      },
      {
        'icon': Icons.delete_outline,
        'title': 'Clear Chat',
        'message': 'Clear chat feature coming soon',
        'isDestructive': true,
      },
      {
        'icon': Icons.file_download_outlined,
        'title': 'Export Chat',
        'message': 'Export chat feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.add_to_home_screen,
        'title': 'Add Shortcut',
        'message': 'Add shortcut feature coming soon',
        'isDestructive': false,
      },
      {
        'icon': Icons.list,
        'title': 'Add to List',
        'message': 'Add to list feature coming soon',
        'isDestructive': false,
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
    // Show notification - stays on chat screen
    widget.onShowNotification(
      option['message'] as String,
      false, // Not an error
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              color: AppColors.textTertiary,
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

                      return _ChatMenuWheelItem(
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
            padding: const EdgeInsets.symmetric(vertical: 8.0),
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
        ],
      ),
    );
  }
}

class _ChatMenuWheelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool isDestructive;

  const _ChatMenuWheelItem({
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

/// Audio Recording Dialog with waveform animation
class _AudioRecordingDialog extends StatefulWidget {
  final Function(String?) onSend;
  final VoidCallback onCancel;

  const _AudioRecordingDialog({required this.onSend, required this.onCancel});

  @override
  State<_AudioRecordingDialog> createState() => _AudioRecordingDialogState();
}

class _AudioRecordingDialogState extends State<_AudioRecordingDialog>
    with TickerProviderStateMixin {
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  late AnimationController _waveformController;
  late AnimationController _pulseController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _startRecording();
  }

  @override
  void dispose() {
    _waveformController.dispose();
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isPaused = false;
      _recordingDuration = Duration.zero;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      }
    });

    // TODO: Start actual audio recording
    // final recorder = Record();
    // await recorder.start(
    //   path: 'audio_recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
    //   encoder: AudioEncoder.aacLc,
    // );
  }

  void _pauseRecording() {
    setState(() {
      _isPaused = !_isPaused;
    });
    // TODO: Pause actual audio recording
  }

  void _stopRecording() {
    _timer?.cancel();
    // TODO: Stop actual audio recording and get file path
    // final path = await recorder.stop();
    // widget.onSend(path);
    Navigator.pop(context);
    widget.onSend(null); // For now, just close
  }

  void _cancelRecording() {
    _timer?.cancel();
    // TODO: Cancel and delete recording
    Navigator.pop(context);
    widget.onCancel();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Timer
                Text(
                  _formatDuration(_recordingDuration),
                  style: AppTextStyles.headlineMedium(weight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                // Waveform animation
                _WaveformAnimation(
                  controller: _waveformController,
                  isPaused: _isPaused,
                ),
                const SizedBox(height: 32),
                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel button
                    _ControlButton(
                      icon: Icons.close,
                      label: 'Cancel',
                      color: AppColors.accentQuaternary,
                      onTap: _cancelRecording,
                    ),
                    // Pause/Resume button
                    _ControlButton(
                      icon: _isPaused ? Icons.play_arrow : Icons.pause,
                      label: _isPaused ? 'Resume' : 'Pause',
                      color: AppColors.accentTertiary,
                      onTap: _pauseRecording,
                    ),
                    // Stop/Send button
                    _ControlButton(
                      icon: Icons.stop,
                      label: 'Send',
                      color: AppColors.success,
                      onTap: _stopRecording,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformAnimation extends StatelessWidget {
  final AnimationController controller;
  final bool isPaused;

  const _WaveformAnimation({required this.controller, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (isPaused) {
          return Container(
            height: 80,
            alignment: Alignment.center,
            child: Icon(
              Icons.pause_circle_outline,
              size: 48,
              color: AppColors.textSecondary,
            ),
          );
        }

        return Container(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(20, (index) {
              // Create animated waveform bars
              final delay = index * 0.1;
              final animationValue = (controller.value + delay) % 1.0;
              final height =
                  20 + (math.sin(animationValue * 2 * math.pi) * 30).abs();

              return Container(
                width: 4,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accentPrimary,
                      AppColors.accentSecondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}


class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Recording overlay - WhatsApp style
class _RecordingOverlay extends StatelessWidget {
  final Duration duration;
  final bool isLocked;
  final bool isCanceling;
  final bool isPaused;
  final Offset dragOffset;
  final AnimationController waveformController;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final VoidCallback onPauseResume;

  const _RecordingOverlay({
    required this.duration,
    required this.isLocked,
    required this.isCanceling,
    required this.isPaused,
    required this.dragOffset,
    required this.waveformController,
    required this.onCancel,
    required this.onSend,
    required this.onPauseResume,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dragY = dragOffset.dy;
    final dragX = dragOffset.dx;
    final isLockedPosition = isLocked && dragY < -100;
    final isCancelPosition = isCanceling && dragX > 50;

    // Calculate position relative to screen
    final footerHeight = 80.0; // Approximate footer height
    final overlayBottom = isLockedPosition
        ? screenSize.height * 0.35
        : footerHeight + 40; // Position above footer

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: false,
        child: GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.translucent,
          child: Container(
            color: Colors.black.withOpacity(0.2),
            child: Stack(
              children: [
                // Main recording indicator - Always show above footer
                Positioned(
                  bottom: overlayBottom,
                  left: isCancelPosition
                      ? screenSize.width * 0.3
                      : (screenSize.width / 2) - 140,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: 280,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isCanceling
                          ? AppColors.accentQuaternary.withOpacity(0.95)
                          : AppColors.backgroundSecondary.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Always show waveform (or pause icon when paused)
                        if (isCanceling)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 36,
                            ),
                          )
                        else
                          _RecordingWaveform(
                            controller: waveformController,
                            isPaused: isPaused,
                          ),
                        const SizedBox(height: 16),
                        // Timer with pause indicator - Always visible
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isPaused) ...[
                              Icon(
                                Icons.pause,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _formatDuration(duration),
                              style: AppTextStyles.headlineMedium(
                                weight: FontWeight.bold,
                                color: isCanceling
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Status text or control buttons
                        if (isLocked) ...[
                          Text(
                            'Recording locked',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Control buttons row - Only show when locked
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Pause/Resume button
                              GestureDetector(
                                onTap: onPauseResume,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundPrimary
                                        .withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPaused ? Icons.play_arrow : Icons.pause,
                                    color: AppColors.textPrimary,
                                    size: 24,
                                  ),
                                ),
                              ),
                              // Delete button
                              GestureDetector(
                                onTap: onCancel,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentQuaternary
                                        .withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: AppColors.accentQuaternary,
                                    size: 24,
                                  ),
                                ),
                              ),
                              // Send button
                              GestureDetector(
                                onTap: onSend,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (!isCanceling) ...[
                          Text(
                            'Slide up to lock',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Cancel indicator (when dragging left)
                if (isCanceling && !isLocked)
                  Positioned(
                    bottom: 100,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentQuaternary.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 32),
                    ),
                  ),
                // Lock indicator (when dragging up)
                if (isLocked && !isCanceling)
                  Positioned(
                    top: 100,
                    left: (screenSize.width / 2) - 40,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock, color: Colors.white, size: 32),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingWaveform extends StatelessWidget {
  final AnimationController controller;
  final bool isPaused;

  const _RecordingWaveform({required this.controller, this.isPaused = false});

  @override
  Widget build(BuildContext context) {
    if (isPaused) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Icon(
          Icons.pause_circle_outline,
          size: 48,
          color: AppColors.textSecondary,
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(25, (index) {
              final delay = index * 0.08;
              final animationValue = (controller.value + delay) % 1.0;
              // Create more dynamic waveform with varying amplitudes
              final baseHeight = 8.0;
              final amplitude = 25.0 + (math.sin(index * 0.5) * 10);
              final height =
                  baseHeight +
                  (math.sin(animationValue * 2 * math.pi) * amplitude).abs();

              return Container(
                width: 3.5,
                height: height.clamp(8.0, 50.0),
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accentPrimary,
                      AppColors.accentSecondary,
                      AppColors.accentPrimary,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentPrimary.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// Edit Message Dialog
class _EditMessageDialog extends StatefulWidget {
  final String initialText;
  final Function(String) onSave;

  const _EditMessageDialog({
    required this.initialText,
    required this.onSave,
  });

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.addListener(() {
      setState(() {
        _hasChanges = _controller.text.trim() != widget.initialText.trim();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.edit,
            size: 20,
            color: AppColors.accentPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            'Edit Message',
            style: AppTextStyles.headlineSmall(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: null,
          minLines: 3,
          style: AppTextStyles.bodyMedium(),
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            hintStyle: AppTextStyles.bodyMedium(
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: AppColors.backgroundPrimary.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.glassBorder.withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.glassBorder.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.accentPrimary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.labelLarge(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: _hasChanges
              ? () {
                  widget.onSave(_controller.text);
                  Navigator.pop(context);
                }
              : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentPrimary,
            disabledForegroundColor: AppColors.textTertiary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check,
                size: 18,
                color: _hasChanges
                    ? AppColors.accentPrimary
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                'Save',
                style: AppTextStyles.labelLarge(
                  color: _hasChanges
                      ? AppColors.accentPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Delete Message Dialog - WhatsApp style with two options
class _DeleteMessageDialog extends StatefulWidget {
  final bool canDeleteForEveryone;

  const _DeleteMessageDialog({
    required this.canDeleteForEveryone,
  });

  @override
  State<_DeleteMessageDialog> createState() => _DeleteMessageDialogState();
}

class _DeleteMessageDialogState extends State<_DeleteMessageDialog> {
  String _selectedOption = 'everyone'; // Default to 'everyone' if available

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.canDeleteForEveryone ? 'everyone' : 'me';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.delete_outline,
            size: 20,
            color: AppColors.accentQuaternary,
          ),
          const SizedBox(width: 8),
          Text(
            'Delete message?',
            style: AppTextStyles.headlineSmall(),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.canDeleteForEveryone) ...[
            // Delete for Everyone option
            InkWell(
              onTap: () => setState(() => _selectedOption = 'everyone'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedOption == 'everyone'
                      ? AppColors.accentPrimary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedOption == 'everyone'
                        ? AppColors.accentPrimary
                        : AppColors.glassBorder.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'everyone',
                      groupValue: _selectedOption,
                      onChanged: (value) => setState(() => _selectedOption = value!),
                      activeColor: AppColors.accentPrimary,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete for Everyone',
                            style: AppTextStyles.bodyMedium(
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This message will be deleted for everyone in this chat.',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Delete for Me option
          InkWell(
            onTap: () => setState(() => _selectedOption = 'me'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedOption == 'me'
                    ? AppColors.accentPrimary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedOption == 'me'
                      ? AppColors.accentPrimary
                      : AppColors.glassBorder.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: 'me',
                    groupValue: _selectedOption,
                    onChanged: (value) => setState(() => _selectedOption = value!),
                    activeColor: AppColors.accentPrimary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete for Me',
                          style: AppTextStyles.bodyMedium(
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This message will be removed from your device only.',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.labelLarge(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedOption),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentQuaternary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.accentQuaternary,
              ),
              const SizedBox(width: 4),
              Text(
                'Delete',
                style: AppTextStyles.labelLarge(
                  color: AppColors.accentQuaternary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


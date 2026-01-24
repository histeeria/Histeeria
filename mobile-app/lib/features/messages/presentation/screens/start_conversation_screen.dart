import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../features/auth/data/models/user.dart';
import '../../data/services/relationships_service.dart';
import '../../data/services/messages_service.dart';

class StartConversationScreen extends StatefulWidget {
  const StartConversationScreen({super.key});

  @override
  State<StartConversationScreen> createState() => _StartConversationScreenState();
}

class _StartConversationScreenState extends State<StartConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RelationshipsService _relationshipsService = RelationshipsService();
  final MessagesService _messagesService = MessagesService();
  
  List<User> _allContacts = [];
  List<User> _filteredContacts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterContacts();
    });
  }

  void _filterContacts() {
    if (_searchQuery.isEmpty) {
      _filteredContacts = _allContacts;
    } else {
      _filteredContacts = _allContacts.where((user) {
        final name = user.displayName.toLowerCase();
        final username = user.username.toLowerCase();
        return name.contains(_searchQuery) || username.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _relationshipsService.getContactsForMessaging();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.success && response.data != null) {
          _allContacts = response.data!;
          _filterContacts();
        } else {
          _errorMessage = response.error ?? 'Failed to load contacts';
        }
      });
    }
  }

  Future<void> _startConversation(User user) async {
    // Show loading indicator
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.accentPrimary,
        ),
      ),
    );

    try {
      // Navigate to chat screen - conversation will be created when first message is sent
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Navigate to chat screen
        context.pop(); // Close this screen
        context.push(
          '/chat/${user.id}',
          extra: {
            'userName': user.displayName,
            'userUsername': user.username,
            'isOnline': false, // Will be updated by chat screen
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: ${e.toString()}'),
            backgroundColor: AppColors.accentQuaternary,
          ),
        );
      }
    }
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
              // Header
              _StartConversationHeader(
                onBack: () => context.pop(),
                searchController: _searchController,
              ),
              // Contacts list
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
                                  'Failed to load contacts',
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
                                  onPressed: _loadContacts,
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
                        : _filteredContacts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 80,
                                      color: AppColors.textSecondary.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'No contacts found'
                                          : 'No results found',
                                      style: AppTextStyles.headlineSmall(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'Follow people to start conversations'
                                          : 'Try a different search term',
                                      style: AppTextStyles.bodyMedium(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _ContactsList(
                                contacts: _filteredContacts,
                                onContactTap: _startConversation,
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartConversationHeader extends StatelessWidget {
  final VoidCallback onBack;
  final TextEditingController searchController;

  const _StartConversationHeader({
    required this.onBack,
    required this.searchController,
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
          child: Column(
            children: [
              Row(
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
                      'New Message',
                      style: AppTextStyles.headlineSmall(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search bar
              Container(
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
                  controller: searchController,
                  style: AppTextStyles.bodyMedium(),
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactsList extends StatelessWidget {
  final List<User> contacts;
  final Function(User) onContactTap;

  const _ContactsList({
    required this.contacts,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _ContactTile(
          user: contact,
          onTap: () => onContactTap(contact),
        );
      },
    );
  }
}

class _ContactTile extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const _ContactTile({
    required this.user,
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
              child: user.profilePicture != null && user.profilePicture!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        user.profilePicture!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            color: AppColors.accentPrimary,
                            size: 28,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: AppColors.accentPrimary,
                      size: 28,
                    ),
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: AppTextStyles.bodyLarge(
                      weight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user.username}',
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Arrow icon
            Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

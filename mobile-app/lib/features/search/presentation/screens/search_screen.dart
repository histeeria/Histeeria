import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/optimized_cached_image.dart';
import '../../data/services/search_service.dart';
import '../../data/models/search_user.dart';
import '../../../notifications/data/providers/notification_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  int _selectedBottomNavIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';
  bool _isSearching = false;
  List<SearchUser> _searchResults = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _errorMessage = 'Please enter at least 2 characters';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      print('[SearchScreen] Performing search for: "$query"');
      final response = await _searchService.searchUsers(query.trim());
      print('[SearchScreen] Search response: ${response.users.length} users found');
      
      if (!mounted) return;
      
      setState(() {
        _searchResults = response.users;
        _isSearching = false;
        if (response.users.isEmpty) {
          _errorMessage = 'No users found';
        }
      });
    } catch (e) {
      print('[SearchScreen] Search error: $e');
      if (!mounted) return;
      
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = 'Search failed: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Consumer<NotificationProvider>(
                builder: (context, notifProvider, _) => AppHeader(
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  messageBadge: 0,
                  notificationBadge: notifProvider.unreadCount,
                  onMessageTap: () {
                    context.push('/messages');
                  },
                ),
              ),
              // Search Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: AppTextStyles.bodyLarge(),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          // Debounce search - wait 500ms after user stops typing
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_searchQuery == value) {
                              _performSearch(value);
                            }
                          });
                        },
                        onSubmitted: (value) {
                          _performSearch(value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search users by name or username...',
                          hintStyle: AppTextStyles.bodyLarge(
                            color: AppColors.textTertiary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _searchResults = [];
                                      _errorMessage = null;
                                    });
                                  },
                                  child: Icon(
                                    Icons.clear,
                                    color: AppColors.textSecondary,
                                    size: 22,
                                  ),
                                )
                              : null,
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Results
              Expanded(
                child: _buildSearchResults(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNavigation(
          selectedIndex: _selectedBottomNavIndex,
          onTap: (index) {
            if (index == 0) {
              context.go('/home');
            } else if (index == 3) {
              context.push('/notifications');
            } else if (index == 4) {
              context.push('/profile');
            } else if (index != 1) {
              setState(() {
                _selectedBottomNavIndex = index;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        title: 'Search for users',
        subtitle: 'Enter a name or username to search',
      );
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accentPrimary,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        title: 'No results',
        subtitle: _errorMessage!,
        showRetry: true,
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search,
        title: 'No users found',
        subtitle: 'Try a different search term',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _UserResultItem(user: user);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showRetry = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentPrimary.withOpacity(0.2),
                    AppColors.accentSecondary.withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (showRetry) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _performSearch(_searchQuery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: AppTextStyles.bodyMedium(
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// User Result Item
class _UserResultItem extends StatelessWidget {
  final User user;

  const _UserResultItem({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(0),
        leading: user.profilePicture != null && user.profilePicture!.isNotEmpty
            ? ClipOval(
                child: OptimizedCachedImage(
                  imageUrl: user.profilePicture!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: AppColors.accentPrimary, size: 28),
              ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.displayName,
                style: AppTextStyles.bodyMedium(weight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 4),
              Icon(Icons.verified, color: AppColors.success, size: 16),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.username}',
              style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
            ),
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.bio!,
                style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: OutlinedButton(
          onPressed: () {
            // Navigate to profile
            context.push('/profile/${user.username}');
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            side: BorderSide(color: AppColors.accentPrimary, width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'View',
            style: AppTextStyles.bodySmall(
              color: AppColors.accentPrimary,
              weight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () {
          context.push('/profile/${user.username}');
        },
      ),
    );
  }
}

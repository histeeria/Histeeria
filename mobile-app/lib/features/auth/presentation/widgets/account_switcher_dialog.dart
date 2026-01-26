import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/multi_account_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Instagram-style account switcher dialog
/// Shows when user long-presses profile icon in bottom navigation
class AccountSwitcherDialog extends StatefulWidget {
  const AccountSwitcherDialog({Key? key}) : super(key: key);

  @override
  State<AccountSwitcherDialog> createState() => _AccountSwitcherDialogState();
}

class _AccountSwitcherDialogState extends State<AccountSwitcherDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _hasRefreshed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }


  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Trigger refresh on first build
        if (!_hasRefreshed) {
          _hasRefreshed = true;
          Future.microtask(() async {
            await authProvider.refreshLinkedAccounts();
          });
        }

        final linkedAccounts = authProvider.linkedAccounts;
        final currentUserId = authProvider.currentUserId;
        final currentUser = authProvider.currentUser;

        // Debug logging
        AppLogger.debug('Current User ID: $currentUserId', 'AccountSwitcher');
        AppLogger.debug('Linked Accounts: ${linkedAccounts.length}', 'AccountSwitcher');

        // Build list of all accounts (current + linked)
        final allAccounts = <LinkedAccount>[];
        final seenUserIds = <String>{};

        // Add current account first if it exists
        if (currentUser != null) {
          allAccounts.add(LinkedAccount(
            userId: currentUser.id,
            username: currentUser.username,
            email: currentUser.email,
            displayName: currentUser.displayName,
            profilePicture: currentUser.profilePicture,
            isPrimary: false,
            addedAt: '',
          ));
          seenUserIds.add(currentUser.id);
        }

        // Add other linked accounts (excluding current to avoid duplicates)
        for (final account in linkedAccounts) {
          if (!seenUserIds.contains(account.userId)) {
            allAccounts.add(account);
            seenUserIds.add(account.userId);
          }
        }

        AppLogger.debug('Total accounts: ${allAccounts.length}', 'AccountSwitcher');

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar with better styling
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Title section with better spacing
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Row(
                      children: [
                        Text(
                          'Switch Account',
                          style: AppTextStyles.headlineMedium(
                            weight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (allAccounts.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${allAccounts.length}',
                              style: TextStyle(
                                color: AppColors.accentPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Account list with better spacing - make it scrollable
                  if (allAccounts.isEmpty)
                    _buildEmptyState()
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: allAccounts.length,
                        itemBuilder: (context, index) {
                          final account = allAccounts[index];
                          return _AccountItem(
                            account: account,
                            isCurrent: account.userId == currentUserId,
                            index: index,
                            onTap: () => _handleAccountSwitch(
                              context,
                              authProvider,
                              account,
                              currentUserId,
                            ),
                            onLogout: () => _handleLogout(
                              context,
                              authProvider,
                              account,
                              currentUserId,
                            ),
                          );
                        },
                      ),
                    ),

                  // Divider with better styling
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: AppColors.glassBorder,
                  ),

                  // Add Account button with better styling
                  _buildAddAccountButton(context, authProvider),

                  // Bottom safe area padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              size: 32,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No other accounts',
            style: AppTextStyles.bodyLarge(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add an account to switch between profiles',
            style: AppTextStyles.bodySmall(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddAccountButton(BuildContext context, AuthProvider authProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          Navigator.pop(context);
          if (!context.mounted) return;
          final result = await context.push('/add-account');
          if (result == true && context.mounted) {
            await authProvider.refreshLinkedAccounts();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentPrimary,
                    width: 2.5,
                  ),
                  color: AppColors.accentPrimary.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.accentPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Account',
                      style: AppTextStyles.bodyLarge(
                        weight: FontWeight.w600,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Login or create a new account',
                      style: AppTextStyles.bodySmall(),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAccountSwitch(
    BuildContext context,
    AuthProvider authProvider,
    LinkedAccount account,
    String? currentUserId,
  ) async {
    if (account.userId == currentUserId) return;

    // Check if we have cached data for instant switch
    final storedToken = await authProvider.tokenStorage.getAccessTokenForUser(account.userId);
    final storedUserData = await authProvider.tokenStorage.getUserDataForUser(account.userId);
    final isInstant = storedToken != null && storedUserData != null;

    Navigator.pop(context);
    
    // Only show loading indicator if not instant
    if (context.mounted && !isInstant) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text('Switching to ${account.username}...'),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.backgroundSecondary,
        ),
      );
    }

    final success = await authProvider.switchAccount(account.userId);
    
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Switched to ${account.username}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.accentPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _handleLogout(
    BuildContext context,
    AuthProvider authProvider,
    LinkedAccount account,
    String? currentUserId,
  ) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.2),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Logout ${account.username}?',
                style: AppTextStyles.headlineSmall(),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout from this account? You\'ll need to login again to access it.',
          style: AppTextStyles.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      if (account.userId == currentUserId) {
        await authProvider.logout(logoutCurrentOnly: true);
        if (context.mounted) {
          Navigator.pop(context);
        }
      } else {
        final success = await authProvider.unlinkAccount(account.userId);
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.link_off_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text('Account unlinked'),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.backgroundSecondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }
}

/// Account item in the switcher dialog with enhanced UI
class _AccountItem extends StatefulWidget {
  final LinkedAccount account;
  final bool isCurrent;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLogout;

  const _AccountItem({
    required this.account,
    required this.isCurrent,
    required this.index,
    required this.onTap,
    required this.onLogout,
  });

  @override
  State<_AccountItem> createState() => _AccountItemState();
}

class _AccountItemState extends State<_AccountItem>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isCurrent ? null : widget.onTap,
              onTapDown: widget.isCurrent
                  ? null
                  : (_) {
                      setState(() => _isPressed = true);
                      _pressController.forward();
                    },
              onTapUp: widget.isCurrent
                  ? null
                  : (_) {
                      setState(() => _isPressed = false);
                      _pressController.reverse();
                    },
              onTapCancel: widget.isCurrent
                  ? null
                  : () {
                      setState(() => _isPressed = false);
                      _pressController.reverse();
                    },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                margin: EdgeInsets.only(
                  bottom: widget.index == 0 ? 0 : 8,
                ),
                decoration: BoxDecoration(
                  color: widget.isCurrent
                      ? AppColors.accentPrimary.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: widget.isCurrent
                      ? Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.account.username,
                                  style: AppTextStyles.bodyLarge(
                                    weight: widget.isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: widget.isCurrent
                                        ? AppColors.accentPrimary
                                        : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.accentPrimary,
                                        AppColors.accentSecondary,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentPrimary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Active',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.account.email,
                            style: AppTextStyles.bodySmall(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isCurrent) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showAccountOptions(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.more_vert_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    final initials = widget.account.username.isNotEmpty
        ? widget.account.username.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isCurrent
              ? AppColors.accentPrimary
              : AppColors.glassBorder,
          width: widget.isCurrent ? 3 : 2,
        ),
        boxShadow: widget.isCurrent
            ? [
                BoxShadow(
                  color: AppColors.accentPrimary.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: widget.account.profilePicture != null &&
                widget.account.profilePicture!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.account.profilePicture!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.backgroundSecondary,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accentPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildInitials(initials),
              )
            : _buildInitials(initials),
      ),
    );
  }

  Widget _buildInitials(String initials) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentPrimary,
            AppColors.accentSecondary,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showAccountOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              ),
              title: Text(
                'Logout ${widget.account.username}',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onLogout();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.link_off_rounded, color: Colors.red, size: 20),
              ),
              title: Text(
                'Unlink Account',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onLogout();
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

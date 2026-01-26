import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/multi_account_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Instagram-style account switcher widget
/// Shows current profile picture and allows switching between linked accounts
class AccountSwitcher extends StatelessWidget {
  final VoidCallback? onAddAccount;
  final VoidCallback? onAccountSelected;

  const AccountSwitcher({
    Key? key,
    this.onAddAccount,
    this.onAccountSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final currentUser = authProvider.currentUser;
        final linkedAccounts = authProvider.linkedAccounts;
        final currentUserId = authProvider.currentUserId;

        // If no linked accounts, just show current user
        if (linkedAccounts.isEmpty && currentUser != null) {
          return _buildProfileAvatar(
            context,
            currentUser.profilePicture,
            currentUser.username,
            onTap: () => _showAccountMenu(context, authProvider, linkedAccounts, currentUserId),
          );
        }

        // Find current account in linked accounts
        final currentAccount = linkedAccounts.firstWhere(
          (account) => account.userId == currentUserId,
          orElse: () => linkedAccounts.isNotEmpty ? linkedAccounts.first : LinkedAccount(
            userId: currentUser?.id ?? '',
            username: currentUser?.username ?? '',
            email: currentUser?.email ?? '',
            displayName: currentUser?.displayName ?? '',
            profilePicture: currentUser?.profilePicture,
            isPrimary: false,
            addedAt: '',
          ),
        );

        return _buildProfileAvatar(
          context,
          currentAccount.profilePicture ?? currentUser?.profilePicture,
          currentAccount.username,
          onTap: () => _showAccountMenu(context, authProvider, linkedAccounts, currentUserId),
        );
      },
    );
  }

  Widget _buildProfileAvatar(
    BuildContext context,
    String? profilePicture,
    String username, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accentPrimary,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: profilePicture != null && profilePicture.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: profilePicture,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.backgroundSecondary,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildInitialsAvatar(username),
                )
              : _buildInitialsAvatar(username),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(String username) {
    final initials = username.isNotEmpty
        ? username.substring(0, 1).toUpperCase()
        : '?';
    
    return Container(
      color: AppColors.accentPrimary,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showAccountMenu(
    BuildContext context,
    AuthProvider authProvider,
    List<LinkedAccount> linkedAccounts,
    String? currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AccountSwitcherMenu(
        linkedAccounts: linkedAccounts,
        currentUserId: currentUserId,
        onAccountSelected: (account) async {
          Navigator.pop(context);
          if (account.userId != currentUserId) {
            final success = await authProvider.switchAccount(account.userId);
            if (success && onAccountSelected != null) {
              onAccountSelected!();
            }
          }
        },
        onAddAccount: () {
          Navigator.pop(context);
          if (onAddAccount != null) {
            onAddAccount!();
          }
        },
        onLogout: (account) async {
          Navigator.pop(context);
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Logout ${account.username}?'),
              content: Text('Are you sure you want to logout from this account?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('Logout'),
                ),
              ],
            ),
          );

          if (shouldLogout == true) {
            if (account.userId == currentUserId) {
              // Logout current account
              await authProvider.logout(logoutCurrentOnly: true);
            } else {
              // Unlink other account
              await authProvider.unlinkAccount(account.userId);
            }
          }
        },
      ),
    );
  }
}

/// Account switcher menu (bottom sheet)
class _AccountSwitcherMenu extends StatelessWidget {
  final List<LinkedAccount> linkedAccounts;
  final String? currentUserId;
  final Function(LinkedAccount) onAccountSelected;
  final VoidCallback onAddAccount;
  final Function(LinkedAccount) onLogout;

  const _AccountSwitcherMenu({
    required this.linkedAccounts,
    required this.currentUserId,
    required this.onAccountSelected,
    required this.onAddAccount,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Switch Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Account list
          ...linkedAccounts.map((account) => _AccountMenuItem(
            account: account,
            isCurrent: account.userId == currentUserId,
            onTap: () => onAccountSelected(account),
            onLogout: () => onLogout(account),
          )),

          // Add account button
          Divider(height: 20),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentPrimary,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(
                Icons.add,
                color: AppColors.accentPrimary,
              ),
            ),
            title: Text(
              'Add Account',
              style: TextStyle(
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: onAddAccount,
          ),

          SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Account menu item
class _AccountMenuItem extends StatelessWidget {
  final LinkedAccount account;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onLogout;

  const _AccountMenuItem({
    required this.account,
    required this.isCurrent,
    required this.onTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAvatar(account.profilePicture, account.username),
      title: Row(
        children: [
          Expanded(
            child: Text(
              account.username,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (isCurrent)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Current',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        account.email,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.more_vert,
          color: AppColors.textSecondary,
          size: 20,
        ),
        onPressed: () => _showAccountOptions(context),
      ),
      onTap: isCurrent ? null : onTap,
    );
  }

  Widget _buildAvatar(String? profilePicture, String username) {
    final initials = username.isNotEmpty
        ? username.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrent ? AppColors.accentPrimary : AppColors.glassBorder,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: ClipOval(
        child: profilePicture != null && profilePicture.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: profilePicture,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.backgroundSecondary,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
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
      color: AppColors.accentPrimary,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
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
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Logout ${account.username}',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),
            if (!isCurrent)
              ListTile(
                leading: Icon(Icons.link_off, color: Colors.red),
                title: Text(
                  'Unlink Account',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onLogout(); // Unlink uses same handler
                },
              ),
          ],
        ),
      ),
    );
  }
}

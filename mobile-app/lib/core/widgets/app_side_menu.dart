import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../features/auth/data/providers/auth_provider.dart';
import '../../core/services/token_storage_service.dart';

class AppSideMenu extends StatefulWidget {
  final VoidCallback onClose;

  const AppSideMenu({super.key, required this.onClose});

  @override
  State<AppSideMenu> createState() => _AppSideMenuState();
}

class _AppSideMenuState extends State<AppSideMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClose() {
    _controller.reverse().then((_) {
      widget.onClose();
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) {
      debugPrint('[Logout] User cancelled logout');
      return;
    }

    debugPrint('[Logout] User confirmed logout');

    // Show loading indicator first (before closing drawer)
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingContext) =>
            const Center(child: CircularProgressIndicator()),
      );
    }

    // Close the drawer after showing loading
    _handleClose();

    try {
      final authProvider = context.read<AuthProvider>();
      final tokenStorage = TokenStorageService();

      // Clear tokens immediately (don't wait - speed optimization)
      tokenStorage.clearAll().catchError((_) {
        // Ignore errors
      });

      // Clear auth state immediately (for instant UI response)
      authProvider.logout();

      // Close loading dialog
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Navigate immediately (don't wait for API - speed optimization)
      if (context.mounted) {
        context.go('/welcome');
      }
    } catch (e) {
      // Even if logout fails, clear local state and navigate immediately
      final tokenStorage = TokenStorageService();
      final authProvider = context.read<AuthProvider>();

      // Clear everything immediately (speed optimization)
      tokenStorage.clearAll().catchError((_) {});
      authProvider.logout();

      // Close loading dialog if still open
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Navigate immediately
      if (context.mounted) {
        context.go('/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Compact Header - same color as sidebar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.glassBorder.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Menu',
                          style: AppTextStyles.headlineSmall(
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _handleClose,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Compact Menu items - no scrolling needed
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _MenuTile(
                        icon: Icons.search_rounded,
                        title: 'Search',
                        onTap: () {
                          _handleClose();
                          context.push('/search');
                        },
                      ),
                      _MenuTile(
                        icon: Icons.settings_rounded,
                        title: 'Settings',
                        onTap: () {
                          _handleClose();
                          context.push('/settings');
                        },
                      ),
                      _MenuTile(
                        icon: Icons.timeline_rounded,
                        title: 'Your Activity',
                        onTap: () {
                          _handleClose();
                          context.push('/activity');
                        },
                      ),
                      _MenuTile(
                        icon: Icons.bookmark_rounded,
                        title: 'Saved',
                        onTap: () {
                          _handleClose();
                          // TODO: Navigate to saved
                        },
                      ),
                      _MenuTile(
                        icon: Icons.edit_rounded,
                        title: 'Edit Profile',
                        onTap: () {
                          _handleClose();
                          context.push('/edit-profile');
                        },
                      ),
                      _MenuTile(
                        icon: Icons.bar_chart_rounded,
                        title: 'Account Summary',
                        onTap: () {
                          _handleClose();
                          // TODO: Navigate to account summary
                        },
                      ),
                      _MenuTile(
                        icon: Icons.switch_account_rounded,
                        title: 'Switch Profiles',
                        onTap: () {
                          _handleClose();
                          // TODO: Switch profiles
                        },
                      ),
                      _MenuTile(
                        icon: Icons.language_rounded,
                        title: 'Switch Language',
                        onTap: () {
                          _handleClose();
                          // TODO: Switch language
                        },
                      ),
                      Divider(
                        color: AppColors.glassBorder,
                        thickness: 0.5,
                        height: 16,
                      ),
                      _MenuTile(
                        icon: Icons.flag_rounded,
                        title: 'Report a Problem',
                        onTap: () {
                          _handleClose();
                          // TODO: Report problem
                        },
                      ),
                      _MenuTile(
                        icon: Icons.info_rounded,
                        title: 'About',
                        onTap: () {
                          _handleClose();
                          // TODO: Navigate to about
                        },
                      ),
                      Divider(
                        color: AppColors.glassBorder,
                        thickness: 0.5,
                        height: 16,
                      ),
                      _MenuTile(
                        icon: Icons.exit_to_app_rounded,
                        title: 'Logout',
                        isLogout: true,
                        onTap: () {
                          // Don't close drawer here - let logout handler manage it
                          _handleLogout(context);
                        },
                      ),
                    ],
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

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isLogout;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        color: isLogout ? AppColors.accentQuaternary : AppColors.textPrimary,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? AppColors.accentQuaternary : AppColors.textPrimary,
          fontSize: 14,
          fontWeight: isLogout ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      minLeadingWidth: 32,
    );
  }
}

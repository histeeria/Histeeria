import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../../features/auth/data/providers/auth_provider.dart';
import '../../features/auth/presentation/widgets/account_switcher_dialog.dart';
import 'create_menu_overlay.dart';

class AppBottomNavigation extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int? notificationBadge;

  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.notificationBadge,
  });

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation> {
  final GlobalKey _createButtonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void _showCreateMenu() {
    final RenderBox? renderBox =
        _createButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final buttonCenter = Offset(position.dx + (size.width / 2), position.dy);

    _overlayEntry = OverlayEntry(
      builder: (context) => CreateMenuOverlay(
        buttonPosition: buttonCenter,
        onClose: _closeCreateMenu,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeCreateMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _closeCreateMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary.withOpacity(0.3),
            border: Border(
              top: BorderSide(
                color: AppColors.glassBorder.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _BottomNavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      isSelected: widget.selectedIndex == 0,
                      onTap: () => widget.onTap(0),
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      icon: Icons.search_outlined,
                      selectedIcon: Icons.search,
                      isSelected: widget.selectedIndex == 1,
                      onTap: () => widget.onTap(1),
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      key: _createButtonKey,
                      icon: Icons.add_box_outlined,
                      selectedIcon: Icons.add_box_rounded,
                      isSelected: widget.selectedIndex == 2,
                      isCreate: true,
                      onTap: _showCreateMenu,
                    ),
                  ),
                  Expanded(
                    child: _NotificationNavItem(
                      isSelected: widget.selectedIndex == 3,
                      badge: widget.notificationBadge,
                      onTap: () => widget.onTap(3),
                    ),
                  ),
                  Expanded(
                    child: _ProfileNavItem(
                      isSelected: widget.selectedIndex == 4,
                      onTap: () => widget.onTap(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationNavItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final int? badge;

  const _NotificationNavItem({
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.center,
            child: Icon(
              isSelected ? Icons.notifications : Icons.notifications_outlined,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              size: 28,
            ),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.accentQuaternary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundPrimary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileNavItem({required this.isSelected, required this.onTap});

  void _showAccountSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AccountSwitcherDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final profilePicture = user?.profilePicture;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showAccountSwitcher(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        child: profilePicture != null && profilePicture.isNotEmpty
            ? Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                    width: isSelected ? 2 : 1.5,
                  ),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: profilePicture,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.surface,
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surface,
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              )
            : Icon(
                isSelected ? Icons.person_rounded : Icons.person_outline,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                size: 28,
              ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final bool isCreate;
  final VoidCallback onTap;
  final Key? key;

  const _BottomNavItem({
    this.key,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
    this.isCreate = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isCreate) {
      return GestureDetector(
        onTap: onTap,
        child: Center(
          child: Icon(
            isSelected ? selectedIcon : icon,
            color: isSelected ? AppColors.accentPrimary : AppColors.textPrimary,
            size: 28,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}

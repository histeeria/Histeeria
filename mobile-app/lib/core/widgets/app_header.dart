import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onMessageTap;
  final int? messageBadge;

  const AppHeader({
    super.key,
    this.onMenuTap,
    this.onMessageTap,
    this.messageBadge,
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
              // Logo/Brand name - Professional gradient styling
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    AppColors.accentPrimary,
                    AppColors.accentSecondary,
                    AppColors.accentPrimary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: Text(
                  'Histeeria',
                  style: AppTextStyles.headlineMedium(
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ).copyWith(
                    letterSpacing: 1.5,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: AppColors.accentPrimary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Header icons
              _HeaderIconButton(
                icon: Icons.menu_rounded,
                onTap: onMenuTap ?? () {},
              ),
              const SizedBox(width: 20),
              _HeaderIconButton(
                icon: Icons.send_rounded,
                badge: messageBadge,
                onTap: onMessageTap ?? () => context.push('/messages'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final VoidCallback onTap;
  final int? badge;
  final bool isSelected;

  const _HeaderIconButton({
    required this.icon,
    this.selectedIcon,
    required this.onTap,
    this.badge,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            child: Icon(
              isSelected && selectedIcon != null ? selectedIcon! : icon,
              color: AppColors.textPrimary,
              size: 26,
            ),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.accentQuaternary, // Red
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


import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CreateMenuOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final Offset buttonPosition;

  const CreateMenuOverlay({
    super.key,
    required this.onClose,
    required this.buttonPosition,
  });

  @override
  State<CreateMenuOverlay> createState() => _CreateMenuOverlayState();
}

class _CreateMenuOverlayState extends State<CreateMenuOverlay>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _rotationAnimations;
  bool _isClosing = false;

  List<Map<String, dynamic>> get _createOptions => [
    {
      'icon': Icons.image_outlined,
      'label': 'Post',
      'gradient': <Color>[AppColors.accentPrimary, AppColors.accentSecondary],
    },
    {
      'icon': Icons.bar_chart_rounded,
      'label': 'Poll',
      'gradient': <Color>[AppColors.accentSecondary, AppColors.accentTertiary],
    },
    {
      'icon': Icons.edit_note_outlined,
      'label': 'Article',
      'gradient': <Color>[AppColors.accentTertiary, AppColors.accentPrimary],
    },
    {
      'icon': Icons.play_circle_outline,
      'label': 'Reel',
      'gradient': <Color>[AppColors.accentPrimary, AppColors.accentTertiary],
    },
    {
      'icon': Icons.bolt_outlined,
      'label': 'Story',
      'gradient': <Color>[AppColors.accentSecondary, AppColors.accentPrimary],
    },
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _createOptions.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeInBack,
      );
    }).toList();

    _fadeAnimations = _controllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
    }).toList();

    _rotationAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
      );
    }).toList();

    _startAnimations();
  }

  void _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(Duration(milliseconds: i * 80));
      if (mounted) {
        _controllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Offset _getIconPosition(int index, Size screenSize) {
    final radius = 140.0;
    final centerX = widget.buttonPosition.dx;
    final centerY = widget.buttonPosition.dy - 20;

    // Distribute icons in a semi-circle (180 degrees)
    final angleStep = math.pi / (_createOptions.length + 1);
    final angle = math.pi - (angleStep * (index + 1));

    final x = centerX + (radius * math.cos(angle));
    final y = centerY - (radius * math.sin(angle));

    return Offset(x, y);
  }

  void _handleOptionTap(String label, BuildContext context) async {
    await _closeWithAnimation();

    // Navigate to respective create screen
    switch (label) {
      case 'Post':
        context.push('/create/post');
        break;
      case 'Poll':
        context.push('/create/poll');
        break;
      case 'Article':
        context.push('/create/article');
        break;
      case 'Reel':
        context.push('/create/reel');
        break;
      case 'Story':
        context.push('/create/story');
        break;
    }
  }

  Future<void> _closeWithAnimation() async {
    if (_isClosing) return;

    setState(() {
      _isClosing = true;
    });

    // Reverse animations in reverse order
    for (int i = _controllers.length - 1; i >= 0; i--) {
      _controllers[i].reverse();
      await Future.delayed(const Duration(milliseconds: 60));
    }

    await Future.delayed(const Duration(milliseconds: 200));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: _closeWithAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Stack(
          children: [
            // Create options in semi-circle
            ...List.generate(_createOptions.length, (index) {
              final option = _createOptions[index];
              final position = _getIconPosition(index, screenSize);

              return AnimatedBuilder(
                animation: _controllers[index],
                builder: (context, child) {
                  return Positioned(
                    left: position.dx - 28,
                    top: position.dy - 28,
                    child: Transform.scale(
                      scale: _scaleAnimations[index].value,
                      child: Transform.rotate(
                        angle:
                            (1 - _rotationAnimations[index].value) *
                            math.pi *
                            2,
                        child: Opacity(
                          opacity: _fadeAnimations[index].value,
                          child: GestureDetector(
                            onTap: () =>
                                _handleOptionTap(option['label'], context),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: List<Color>.from(
                                        option['gradient'],
                                      ),
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (List<Color>.from(
                                          option['gradient'],
                                        ))[0].withOpacity(0.4),
                                        blurRadius: 16,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      option['icon'],
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    option['label'],
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.backgroundPrimary,
                                      weight: FontWeight.w600,
                                    ).copyWith(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

            // Close button (X cross)
            Positioned(
              left: widget.buttonPosition.dx - 24,
              top: widget.buttonPosition.dy - 80,
              child: GestureDetector(
                onTap: _closeWithAnimation,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: value * math.pi / 2,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.accentQuaternary,
                              AppColors.accentQuaternary.withOpacity(0.8),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentQuaternary.withOpacity(
                                0.4,
                              ),
                              blurRadius: 12,
                              spreadRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

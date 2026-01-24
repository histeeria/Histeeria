import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../theme/app_colors.dart';

/// Gradient background widget with YouTube Music style and animated transitions
class GradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final bool animate;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.animate = true,
  });

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Color> _gradientColors;

  @override
  void initState() {
    super.initState();
    _gradientColors = widget.colors ?? AppColors.gradientWarm;
    _controller = AnimationController(
      duration: const Duration(seconds: 8), // Slow, smooth transition
      vsync: this,
    )..repeat(); // Loop the animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColors = _gradientColors;
    final screenSize = MediaQuery.of(context).size;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Create smooth color transitions using sine waves
        final t = _controller.value;
        
        // Interpolate between colors for smooth transitions
        final color1 = Color.lerp(
          baseColors[0],
          baseColors[1 % baseColors.length],
          (math.sin(t * 2 * math.pi) + 1) / 2,
        )!;
        
        final color2 = Color.lerp(
          baseColors[1 % baseColors.length],
          baseColors[2 % baseColors.length],
          (math.sin(t * 2 * math.pi + math.pi / 3) + 1) / 2,
        )!;
        
        final color3 = Color.lerp(
          baseColors[2 % baseColors.length],
          baseColors[0],
          (math.sin(t * 2 * math.pi + 2 * math.pi / 3) + 1) / 2,
        )!;

        // Reduced opacity for softer, more merged appearance
        // Create mist-style gradient with multiple soft, evolving radial gradients
        // No hard diagonal lines - just soft, diffused color mists
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.backgroundPrimary, // Dark base like YT Music
          child: Stack(
            children: [
              // Mist 1 - Top left evolving
              Positioned(
                left: -100 + (math.sin(t * 2 * math.pi) * 50),
                top: -100 + (math.cos(t * 2 * math.pi) * 50),
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color1.withOpacity(0.25),
                        color1.withOpacity(0.15),
                        color1.withOpacity(0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // Mist 2 - Top right evolving
              Positioned(
                right: -100 + (math.cos(t * 2 * math.pi + math.pi / 3) * 50),
                top: -100 + (math.sin(t * 2 * math.pi + math.pi / 3) * 50),
                child: Container(
                  width: 450,
                  height: 450,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color2.withOpacity(0.25),
                        color2.withOpacity(0.15),
                        color2.withOpacity(0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // Mist 3 - Bottom center evolving
              Positioned(
                left: screenSize.width / 2 - 200,
                bottom: -150 + (math.sin(t * 2 * math.pi + 2 * math.pi / 3) * 60),
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color3.withOpacity(0.25),
                        color3.withOpacity(0.15),
                        color3.withOpacity(0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // Mist 4 - Center evolving (subtle)
              Positioned(
                left: screenSize.width / 2 - 150,
                top: screenSize.height / 2 - 150,
                child: Container(
                  width: 300 + (math.sin(t * 2 * math.pi) * 30),
                  height: 300 + (math.cos(t * 2 * math.pi) * 30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color1.withOpacity(0.18),
                        color2.withOpacity(0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Blur filter to create mist effect (slightly reduced for more prominence)
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                  ),
                ),
              ),
              // Child content
              widget.child,
            ],
          ),
        );
      },
    );
  }
}


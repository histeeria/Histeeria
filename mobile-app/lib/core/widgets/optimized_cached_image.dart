import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Optimized cached network image widget for profile pictures
/// 
/// Features:
/// - Automatic caching (memory + disk)
/// - Fast loading with placeholders
/// - Error handling
/// - Optimized for Supabase CDN
class OptimizedCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool isCircular;

  const OptimizedCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.isCircular = false,
  });

  /// Optimize image URL for Supabase CDN
  /// Adds query parameters for better performance if needed
  String get _optimizedUrl {
    // If Supabase Image Transformations are enabled, you can add:
    // return '$imageUrl?width=${width?.toInt() ?? 200}&height=${height?.toInt() ?? 200}&quality=80';
    return imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: _optimizedUrl,
      width: width,
      height: height,
      fit: fit,
      // Cache configuration for optimal performance
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: (width != null && width! > 0) ? (width! * 2).toInt() : null,
      maxHeightDiskCache: (height != null && height! > 0) ? (height! * 2).toInt() : null,
      // Fast placeholder
      placeholder: (context, url) => placeholder ??
          Container(
            width: width,
            height: height,
            color: AppColors.surface,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      // Error widget
      errorWidget: (context, url, error) => errorWidget ??
          Container(
            width: width,
            height: height,
            color: AppColors.surface,
            child: Icon(
              Icons.person,
              color: AppColors.textSecondary,
              size: (width != null && height != null)
                  ? (width! < height! ? width! * 0.5 : height! * 0.5)
                  : 50,
            ),
          ),
      // Fade in animation for smooth loading
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );

    // Apply border radius or circular clipping
    if (isCircular) {
      return ClipOval(child: image);
    } else if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// Optimized profile picture widget
class OptimizedProfilePicture extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedProfilePicture({
    super.key,
    this.imageUrl,
    this.size = 100,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.accentPrimary,
              AppColors.accentSecondary,
            ],
          ),
        ),
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: size * 0.5,
        ),
      );
    }

    return OptimizedCachedImage(
      imageUrl: imageUrl!,
      width: size,
      height: size,
      isCircular: true,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}

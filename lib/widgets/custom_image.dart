// lib/widgets/custom_image.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A reusable widget for displaying network images with caching support.
///
/// This widget acts as a wrapper around [CachedNetworkImage] to provide
/// a consistent look and feel across the application. It automatically handles:
/// 1. **Caching:** Images are saved locally to save bandwidth (Fixes issue 7.2).
/// 2. **Loading State:** Shows a spinner while the image is downloading.
/// 3. **Error State:** Shows a broken image icon if the URL is invalid or offline.
class CustomImage extends StatelessWidget {
  /// The remote URL of the image to display.
  final String imageUrl;

  /// Optional width constraint.
  final double? width;

  /// Optional height constraint.
  final double? height;

  /// How the image should be inscribed into the space. Defaults to [BoxFit.cover].
  final BoxFit fit;

  /// Creates a [CustomImage] widget.
  const CustomImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // FAIL FAST: If the URL is empty or null, don't even attempt a network request.
    // This prevents unnecessary errors and shows a placeholder immediately.
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    // We use CachedNetworkImage instead of Image.network to persist the image
    // on the device disk. This significantly reduces data usage on subsequent views.
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,

      // UX IMPROVEMENT: Show a loading spinner so the user knows data is coming.
      // Without this, the area would just be blank, looking like a bug.
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),

      // ERROR HANDLING: If the download fails (404 or no internet), show a visual indicator
      // instead of crashing or showing a raw console error.
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}

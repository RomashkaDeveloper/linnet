import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_config.dart';
import '../screens/photo_viewer_screen.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final bool showOnlineDot;

  /// When true and an image is set, tapping the avatar opens it full-screen
  /// via [PhotoViewerScreen]. Left off by default because most avatars sit
  /// inside an already-tappable row (a chat list tile, a member row) where
  /// a nested tap target would fight with the row's own onTap.
  final bool enableViewer;

  const AvatarWidget({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
    this.showOnlineDot = false,
    this.enableViewer = false,
  });

  String get _initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  String? get _fullUrl {
    final url = imageUrl;
    if (url == null || url.isEmpty) return null;
    return ApiConfig.instance.resolveMediaUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final url = _fullUrl;
    final colorScheme = Theme.of(context).colorScheme;
    final content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: url != null
                ? CachedNetworkImage(
                    imageUrl: url,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _fallback(colorScheme),
                    errorWidget: (_, __, ___) => _fallback(colorScheme),
                  )
                : _fallback(colorScheme),
          ),
          if (showOnlineDot)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (enableViewer && url != null) {
      return GestureDetector(
        onTap: () => PhotoViewerScreen.open(context, url, heroTag: url),
        child: content,
      );
    }
    return content;
  }

  Widget _fallback(ColorScheme colorScheme) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
      child: Text(
        _initial,
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

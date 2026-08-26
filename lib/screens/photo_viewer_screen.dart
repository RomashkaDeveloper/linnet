import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PhotoViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const PhotoViewerScreen({super.key, required this.imageUrl, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Hero(
            tag: heroTag ?? imageUrl,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }

  static void open(BuildContext context, String imageUrl, {String? heroTag}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PhotoViewerScreen(imageUrl: imageUrl, heroTag: heroTag),
      fullscreenDialog: true,
    ));
  }
}

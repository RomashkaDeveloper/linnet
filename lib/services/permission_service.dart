import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around permission_handler — requests are made lazily,
/// right before the feature that needs them is used (opening the camera,
/// starting a call, etc.), rather than all at once on first launch.
class AppPermissions {
  AppPermissions._();

  static Future<bool> ensureCamera() => _ensure(Permission.camera);

  static Future<bool> ensureMicrophone() => _ensure(Permission.microphone);

  /// Android 13+ uses granular Permission.photos/videos; older Android and
  /// most other cases fall back to Permission.storage.
  static Future<bool> ensurePhotos() async {
    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  static Future<bool> ensureNotifications() => _ensure(Permission.notification);

  static Future<bool> _ensure(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await permission.request();
    return result.isGranted;
  }
}

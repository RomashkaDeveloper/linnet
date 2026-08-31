import 'package:flutter/services.dart';

class RingtoneService {
  static const MethodChannel _channel =
      MethodChannel('linnet/call_audio');

  static Future<void> start() async {
    await _channel.invokeMethod('startRingtone');
  }

  static Future<void> stop() async {
    await _channel.invokeMethod('stopRingtone');
  }
}
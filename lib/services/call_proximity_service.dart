import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

class CallProximityService {
  static const MethodChannel _channel =
      MethodChannel('linnet/call_audio');

  StreamSubscription<dynamic>? _subscription;

  bool _running = false;
  bool _lastNear = false;

  // Если true — пользователь вручную включил громкую связь,
  // и датчик приближения больше не должен трогать спикер
  // (он всё ещё может гасить/включать экран).
  bool _speakerOverride = false;

  /// Вызывается извне (из CallProvider/CallScreen), когда пользователь
  /// вручную переключает спикер. Пока громкая связь включена вручную,
  /// датчик приближения не переопределяет её при поднесении к уху.
  void setManualSpeakerOverride(bool enabled) {
    _speakerOverride = enabled;
  }

  Future<void> start() async {
    if (_running) return;

    _running = true;

    _subscription = ProximitySensor.events.listen((event) async {
      final isNear = _isNear(event);

      if (isNear == _lastNear) return;

      _lastNear = isNear;

      if (!Platform.isAndroid) return;

      try {
        if (isNear) {
          // Поднесли к уху: гасим экран и переключаем на разговорный динамик,
          // только если пользователь не включил громкую связь вручную
          if (!_speakerOverride) {
            await Helper.setSpeakerphoneOn(false);
          }
          await _channel.invokeMethod('screenOff');
        } else {
          // Убрали от уха: включаем экран.
          // Если громкая связь выключена вручную, оставляем звук на разговорном динамике (false),
          // а не переключаем на внешний динамик (true).
          await _channel.invokeMethod('screenOn');
          if (!_speakerOverride) {
            await Helper.setSpeakerphoneOn(false); // <--- Важно: false вместо true!
          }
        }
      } catch (e) {
        // Не даём ошибке датчика уронить звонок.
      }
    });
  }

  Future<void> stop() async {
    if (!_running) return;

    _running = false;

    await _subscription?.cancel();
    _subscription = null;

    _lastNear = false;
    _speakerOverride = false;

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('screenOn');
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}
    }
  }

  bool _isNear(dynamic event) {
    if (event is bool) {
      return event;
    }

    if (event is num) {
      return event < 1;
    }

    return false;
  }

  Future<void> dispose() async {
    await stop();
  }
}
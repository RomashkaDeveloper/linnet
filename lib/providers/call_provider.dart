import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/call.dart';
import '../models/user.dart';
import '../services/call_proximity_service.dart';
import '../services/call_service.dart';
import '../services/permission_service.dart';
import '../services/push_service.dart';
import '../services/ringtone_service.dart';
import '../services/socket_service.dart';

enum CallState {
  idle,
  outgoingRinging,
  incomingRinging,
  connecting,
  active,
}

class CallProvider extends ChangeNotifier {
  final CallService _service = CallService();
  final CallProximityService _proximityService = CallProximityService();

  StreamSubscription? _sub;

  CallState state = CallState.idle;
  CallOut? currentCall;
  CallType callType = CallType.audio;
  bool isCaller = false;
  UserPublic? remoteUser;
  String? lastEndReason;

  RTCPeerConnection? _pc;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCSessionDescription? _pendingRemoteOffer;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  bool _remoteDescriptionSet = false;
  List<Map<String, dynamic>> _iceServers = [];

  RTCSessionDescription? _localOffer;

  bool micMuted = false;
  bool cameraOff = false;
  bool speakerEnabled = false;

  Timer? _durationTimer;
  DateTime? _connectedAt;
  Duration callDuration = Duration.zero;

  bool _renderersReady = false;

  CallProvider() {
    _sub = SocketService.instance.events.listen(_onEvent);
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  Future<void> _ensureRenderers() async {
    if (!_renderersReady) {
      await _initRenderers();
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'incoming_call':
        _handleIncomingCall(event);
        break;

      case 'call_answered':
        _handleCallAnswered(event);
        break;

      case 'webrtc_signal':
        _handleSignal(event);
        break;

      case 'call_ended':
      case 'call_declined':
      case 'call_rejected':
        _handleCallEnded(event);
        break;

      case 'call_missed':
        _handleCallMissed(event);
        break;
    }
  }

  Future<bool> restoreIncomingCall(String callId) async {
    if (state != CallState.idle) {
      return state == CallState.incomingRinging &&
          currentCall?.id == callId;
    }

    try {
      final call = await _service.get(callId);

      if (call.status != CallStatus.ringing) {
        return false;
      }

      callType = call.callType;
      isCaller = false;
      remoteUser = call.caller;
      currentCall = call;
      state = CallState.incomingRinging;

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> startCall(
    String chatId,
    CallType type,
    UserPublic otherUser,
  ) async {
    if (state != CallState.idle) {
      throw Exception('Уже есть активный звонок');
    }

    if (!await AppPermissions.ensureMicrophone()) {
      throw Exception('Нет доступа к микрофону');
    }

    if (type == CallType.video &&
        !await AppPermissions.ensureCamera()) {
      throw Exception('Нет доступа к камере');
    }

    callType = type;
    isCaller = true;
    remoteUser = otherUser;
    state = CallState.outgoingRinging;

    notifyListeners();

    try {
      await _ensureRenderers();

      _iceServers = await _service.iceServers();

      await _createPeerConnection();
      await _acquireLocalMedia(type);

      final call = await _service.start(chatId, type);

      currentCall = call;

      notifyListeners();

      final offer = await _pc!.createOffer();

      await _pc!.setLocalDescription(offer);

      _localOffer = offer;

      _sendSignal(
        call.id,
        'offer',
        {
          'sdp': offer.sdp,
          'type': offer.type,
        },
      );
    } catch (e) {
      await _cleanup();
      rethrow;
    }
  }

  void _handleCallAnswered(Map<String, dynamic> event) {
    if (currentCall == null ||
        event['call_id']?.toString() != currentCall!.id) {
      return;
    }

    if (state == CallState.outgoingRinging) {
      state = CallState.connecting;

      notifyListeners();

      if (_localOffer != null) {
        _sendSignal(
          currentCall!.id,
          'offer',
          {
            'sdp': _localOffer!.sdp,
            'type': _localOffer!.type,
          },
        );
      }
    }
  }

  void _handleIncomingCall(Map<String, dynamic> event) {
    final callData =
        event['call'] is Map<String, dynamic>
            ? event['call'] as Map<String, dynamic>
            : event;

    final callId =
        callData['id']?.toString() ??
            event['call_id']?.toString();

    if (callId == null) return;

    if (state != CallState.idle) {
      if (state == CallState.incomingRinging &&
          currentCall?.id == callId) {
        return;
      }

      _service.reject(callId).catchError((_) {});
      return;
    }

    callType = callTypeFromString(
      callData['call_type'] as String? ?? 'audio',
    );

    isCaller = false;

    final callerJson = event['caller'];

    remoteUser =
        callerJson is Map<String, dynamic>
            ? UserPublic.fromJson(callerJson)
            : null;

    currentCall = CallOut(
      id: callId,
      chatId: (callData['chat_id'] ?? '').toString(),
      callerId: (callData['caller_id'] ??
              remoteUser?.id ??
              '')
          .toString(),
      calleeId: (callData['callee_id'] ?? '').toString(),
      callType: callType,
      status: CallStatus.ringing,
      caller: remoteUser,
      startedAt: DateTime.now(),
    );

    state = CallState.incomingRinging;

    RingtoneService.start();

    notifyListeners();
  }

  Future<void> acceptCall() async {
    if (state != CallState.incomingRinging ||
        currentCall == null) {
      return;
    }

    await RingtoneService.stop();
    await PushService.cancelIncomingCallNotification();

    if (!await AppPermissions.ensureMicrophone()) {
      await declineCall();
      throw Exception('Нет доступа к микрофону');
    }

    if (callType == CallType.video &&
        !await AppPermissions.ensureCamera()) {
      callType = CallType.audio;
    }

    state = CallState.connecting;

    notifyListeners();

    try {
      await _ensureRenderers();

      _iceServers = await _service.iceServers();

      await _createPeerConnection();
      await _acquireLocalMedia(callType);

      await _service.answer(currentCall!.id);

      if (_pendingRemoteOffer != null) {
        await _applyRemoteOfferAndAnswer();
      }
    } catch (e) {
      await hangUp();
      rethrow;
    }
  }

  Future<void> declineCall() async {
    await RingtoneService.stop();
    await PushService.cancelIncomingCallNotification();

    if (currentCall != null) {
      try {
        await _service.reject(currentCall!.id);
      } catch (_) {}
    }

    await _cleanup();
  }

  void _sendSignal(
    String callId,
    String signalType,
    Map<String, dynamic> payload,
  ) {
    SocketService.instance.send({
      'type': 'webrtc_signal',
      'call_id': callId,
      'signal_type': signalType,
      'payload': payload,
    });
  }

  Future<void> _handleSignal(
    Map<String, dynamic> event,
  ) async {
    if (currentCall == null ||
        event['call_id']?.toString() != currentCall!.id) {
      return;
    }

    final payload =
        (event['payload'] as Map<String, dynamic>?) ?? event;

    switch (event['signal_type']) {
      case 'offer':
        _pendingRemoteOffer = RTCSessionDescription(
          payload['sdp'] as String?,
          payload['type'] as String? ?? 'offer',
        );

        if (state == CallState.connecting &&
            !isCaller &&
            _pc != null) {
          await _applyRemoteOfferAndAnswer();
        }
        break;

      case 'answer':
        if (_pc != null) {
          await _pc!.setRemoteDescription(
            RTCSessionDescription(
              payload['sdp'] as String?,
              payload['type'] as String? ?? 'answer',
            ),
          );

          _remoteDescriptionSet = true;

          await _flushPendingCandidates();

          state = CallState.active;

          await _onCallConnected();

          notifyListeners();
        }
        break;

      case 'ice_candidate':
        final candidate = RTCIceCandidate(
          payload['candidate'] as String?,
          payload['sdpMid'] as String?,
          payload['sdpMLineIndex'] as int?,
        );

        if (_remoteDescriptionSet && _pc != null) {
          await _pc!.addCandidate(candidate);
        } else {
          _pendingRemoteCandidates.add(candidate);
        }
        break;
    }
  }

  Future<void> _applyRemoteOfferAndAnswer() async {
    if (_pc == null ||
        _pendingRemoteOffer == null ||
        currentCall == null) {
      return;
    }

    await _pc!.setRemoteDescription(_pendingRemoteOffer!);

    _remoteDescriptionSet = true;

    await _flushPendingCandidates();

    final answer = await _pc!.createAnswer();

    await _pc!.setLocalDescription(answer);

    _sendSignal(
      currentCall!.id,
      'answer',
      {
        'sdp': answer.sdp,
        'type': answer.type,
      },
    );

    state = CallState.active;

    await _onCallConnected();

    notifyListeners();
  }

  Future<void> _onCallConnected() async {
    _startDurationTimer();

    if (Platform.isAndroid) {
      // Не небольшая задержка 300мс дает Android временно инициализировать поток
      Future.delayed(const Duration(milliseconds: 300), () async {
        try {
          await Helper.setSpeakerphoneOn(speakerEnabled);
        } catch (_) {}
      });
    }

    await _proximityService.start();
  }

  Future<void> _flushPendingCandidates() async {
    for (final candidate in _pendingRemoteCandidates) {
      try {
        await _pc?.addCandidate(candidate);
      } catch (_) {}
    }

    _pendingRemoteCandidates.clear();
  }

  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': _iceServers.isNotEmpty
          ? _iceServers
          : [
              {
                'urls': 'stun:stun.l.google.com:19302',
              }
            ],
      'sdpSemantics': 'unified-plan',
    };

    _pc = await createPeerConnection(config);

    _pc!.onIceCandidate = (candidate) {
      if (currentCall == null ||
          candidate.candidate == null) {
        return;
      }

      _sendSignal(
        currentCall!.id,
        'ice_candidate',
        {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        remoteRenderer.srcObject = remoteStream;
        notifyListeners();
      }
    };
  }

  Future<void> _acquireLocalMedia(
    CallType type,
  ) async {
    final constraints = {
      'audio': true,
      'video': type == CallType.video
          ? {'facingMode': 'user'}
          : false,
    };

    localStream =
        await navigator.mediaDevices.getUserMedia(constraints);

    localRenderer.srcObject = localStream;

    for (final track in localStream!.getTracks()) {
      await _pc?.addTrack(track, localStream!);
    }

    notifyListeners();
  }

  void toggleMic() {
    if (localStream == null) return;

    micMuted = !micMuted;

    for (final track in localStream!.getAudioTracks()) {
      track.enabled = !micMuted;
    }

    notifyListeners();
  }

  void toggleCamera() {
    if (localStream == null ||
        callType != CallType.video) {
      return;
    }

    cameraOff = !cameraOff;

    for (final track in localStream!.getVideoTracks()) {
      track.enabled = !cameraOff;
    }

    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = localStream?.getVideoTracks();

    if (tracks == null || tracks.isEmpty) return;

    await Helper.switchCamera(tracks.first);
  }

  /// Единая точка управления динамиком. Обновляет системный аудио-путь
  /// и сообщает CallProximityService, что дальше датчик приближения
  /// не должен перебивать этот выбор, пока пользователь его не сменит.
  Future<void> setSpeaker(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);
      speakerEnabled = enabled;
      _proximityService.setManualSpeakerOverride(enabled);
      notifyListeners();
    } catch (_) {
      // Если устройство не поддерживает переключение — не падаем.
    }
  }

  Future<void> toggleSpeaker() => setSpeaker(!speakerEnabled);

  Future<void> hangUp() async {
    await RingtoneService.stop();

    if (currentCall != null) {
      try {
        await _service.end(currentCall!.id);
      } catch (_) {}
    }

    await _cleanup();
  }

  void _handleCallEnded(Map<String, dynamic> event) {
    if (currentCall == null ||
        event['call_id']?.toString() != currentCall!.id) {
      return;
    }

    lastEndReason = event['reason'] as String?;

    _cleanup();
  }

  void _handleCallMissed(Map<String, dynamic> event) {
    if (currentCall == null ||
        event['call_id']?.toString() != currentCall!.id) {
      return;
    }

    lastEndReason = 'missed';

    _cleanup();
  }

  void _startDurationTimer() {
    _connectedAt = DateTime.now();

    _durationTimer?.cancel();

    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        callDuration =
            DateTime.now().difference(_connectedAt!);

        notifyListeners();
      },
    );
  }

  Future<void> _cleanup() async {
    await RingtoneService.stop();
    await PushService.cancelIncomingCallNotification();
    await _proximityService.stop();

    _durationTimer?.cancel();
    _durationTimer = null;

    callDuration = Duration.zero;
    _connectedAt = null;

    try {
      for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
      await localStream?.dispose();
    } catch (_) {}

    try {
      await _pc?.close();
      await _pc?.dispose();
    } catch (_) {}

    // Возвращаем динамик в обычный режим при завершении звонка
    // if (Platform.isAndroid) {
    //   try {
    //     await Helper.setSpeakerphoneOn(true);
    //   } catch (_) {}
    // }

    _pc = null;
    localStream = null;
    remoteStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    _pendingRemoteOffer = null;
    _localOffer = null;
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;

    micMuted = false;
    cameraOff = false;
    speakerEnabled = false;

    currentCall = null;
    remoteUser = null;

    state = CallState.idle;

    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _durationTimer?.cancel();
    _proximityService.dispose();
    RingtoneService.stop();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
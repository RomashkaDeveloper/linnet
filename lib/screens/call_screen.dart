import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import '../models/call.dart';
import '../widgets/avatar_widget.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final CallProvider _callProvider;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _callProvider = context.read<CallProvider>();
    _callProvider.addListener(_onChange);
  }

  void _onChange() {
    if (_callProvider.state == CallState.idle && !_popped) {
      _popped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _callProvider.removeListener(_onChange);
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  String _statusText(CallProvider p) {
    switch (p.state) {
      case CallState.outgoingRinging:
        return 'Вызов…';
      case CallState.connecting:
        return 'Соединение…';
      case CallState.active:
        return _fmtDuration(p.callDuration);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF161A22),
        body: SafeArea(
          child: Consumer<CallProvider>(
            builder: (context, p, _) {
              final showRemoteVideo = p.callType == CallType.video &&
                  p.remoteStream != null &&
                  p.remoteStream!.getVideoTracks().isNotEmpty;
              return Stack(
                children: [
                  if (showRemoteVideo)
                    Positioned.fill(
                      child: RTCVideoView(p.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AvatarWidget(name: p.remoteUser?.displayName ?? '?', imageUrl: p.remoteUser?.avatarUrl, size: 120),
                          const SizedBox(height: 16),
                          Text(
                            p.remoteUser?.displayName ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(_statusText(p), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                  ),
                  if (p.callType == CallType.video && p.localStream != null)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        width: 100,
                        height: 140,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
                        clipBehavior: Clip.antiAlias,
                        child: p.cameraOff
                            ? const Center(child: Icon(Icons.videocam_off, color: Colors.white54))
                            : RTCVideoView(p.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                      ),
                    ),
                  if (p.callType == CallType.video && p.state == CallState.active)
                    Positioned(
                      bottom: 100,
                      right: 16,
                      child: _controlButton(
                        icon: Icons.cameraswitch,
                        onTap: p.switchCamera,
                        background: Colors.white24,
                        iconColor: Colors.white,
                        size: 44,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _controlButton(
                          icon: p.micMuted ? Icons.mic_off : Icons.mic,
                          onTap: p.toggleMic,
                          background: p.micMuted ? Colors.white : Colors.white24,
                          iconColor: p.micMuted ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 20),
                        _controlButton(
                          icon: Icons.call_end,
                          onTap: () => p.hangUp(),
                          background: Colors.red,
                          iconColor: Colors.white,
                          size: 68,
                        ),
                        const SizedBox(width: 20),
                        if (p.callType == CallType.video)
                          _controlButton(
                            icon: p.cameraOff ? Icons.videocam_off : Icons.videocam,
                            onTap: p.toggleCamera,
                            background: p.cameraOff ? Colors.white : Colors.white24,
                            iconColor: p.cameraOff ? Colors.black : Colors.white,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color background,
    required Color iconColor,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import '../models/call.dart';
import '../widgets/avatar_widget.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final CallProvider _callProvider;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _callProvider = context.read<CallProvider>();
    _callProvider.addListener(_onChange);
  }

  void _onChange() {
    // Звонок сорвался (звонящий отменил / истёк таймаут) до нашего ответа.
    if (_callProvider.state == CallState.idle && !_handled) {
      _handled = true;
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

  Future<void> _accept() async {
    if (_handled) return;
    _handled = true;
    try {
      await _callProvider.acceptCall();
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CallScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось принять звонок: $e')));
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _decline() async {
    if (_handled) return;
    _handled = true;
    await _callProvider.declineCall();
    if (mounted) Navigator.of(context).pop();
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
              return Column(
                children: [
                  const Spacer(),
                  AvatarWidget(name: p.remoteUser?.displayName ?? '?', imageUrl: p.remoteUser?.avatarUrl, size: 120),
                  const SizedBox(height: 20),
                  Text(
                    p.remoteUser?.displayName ?? 'Неизвестный',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.callType == CallType.video ? 'Входящий видеозвонок' : 'Входящий звонок',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _actionButton(icon: Icons.call_end, color: Colors.red, label: 'Отклонить', onTap: _decline),
                        _actionButton(
                          icon: p.callType == CallType.video ? Icons.videocam : Icons.call,
                          color: Colors.green,
                          label: 'Принять',
                          onTap: _accept,
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

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

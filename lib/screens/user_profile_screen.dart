import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/call.dart';
import '../providers/call_provider.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_widget.dart';
import '../utils/formatters.dart';
import 'call_screen.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserPublic? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await UserService().getUser(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _startCall(CallType type) async {
    final user = _user;
    if (user == null) return;
    try {
      final chat = await ChatService().createPrivate(user.id);
      if (!mounted) return;
      await context.read<CallProvider>().startCall(chat.id, type, user);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallScreen(), fullscreenDialog: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось начать звонок: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: AvatarWidget(
                        name: _user!.displayName,
                        imageUrl: _user!.avatarUrl,
                        size: 100,
                        showOnlineDot: _user!.isOnline,
                        enableViewer: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _user!.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '@${_user!.username}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _user!.isOnline ? 'В сети' : formatLastSeen(_user!.lastSeen),
                      textAlign: TextAlign.center,
                    ),
                    if (_user!.bio != null && _user!.bio!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(_user!.bio!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _startCall(CallType.audio),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Аудио'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _startCall(CallType.video),
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Видео'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          final chat = await ChatService().createPrivate(_user!.id);
                          if (mounted) {
                            Navigator.of(context)
                                .pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id)));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                          }
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Написать сообщение'),
                    ),
                  ],
                ),
    );
  }
}

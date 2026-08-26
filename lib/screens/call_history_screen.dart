import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/call.dart';
import '../providers/auth_provider.dart';
import '../services/call_service.dart';
import '../utils/formatters.dart';
import '../widgets/avatar_widget.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _service = CallService();
  List<CallOut> _calls = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final calls = await _service.history();
      if (mounted) {
        setState(() {
          _calls = calls;
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().currentUser?.id ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('История звонков', style: TextStyle(fontWeight: FontWeight.w700))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text('Ошибка загрузки:\n$_error', textAlign: TextAlign.center)),
                      const SizedBox(height: 12),
                      Center(child: OutlinedButton(onPressed: _load, child: const Text('Повторить'))),
                    ],
                  )
                : _calls.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          Icon(Icons.call_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 12),
                          const Center(child: Text('Звонков пока не было')),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: _calls.length,
                        itemBuilder: (context, index) {
                          final call = _calls[index];
                          
                          // Проверяем по callerId
                          final isOutgoing = call.callerId == currentUserId;
                          
                          // Бэкенд теперь присылает объекты caller и callee!
                          final other = isOutgoing ? call.callee : call.caller;
                          
                          final missed = call.status == CallStatus.missed;
                          
                          return ListTile(
                            leading: AvatarWidget(
                              name: other?.displayName ?? '?', 
                              imageUrl: other?.avatarUrl, 
                              size: 48,
                            ),
                            title: Text(other?.displayName ?? 'Неизвестный'),
                            subtitle: Row(
                              children: [
                                Icon(
                                  isOutgoing ? Icons.call_made : Icons.call_received,
                                  size: 14,
                                  color: missed ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  missed
                                      ? 'Пропущенный'
                                      : call.callType == CallType.video
                                          ? 'Видеозвонок'
                                          : 'Аудиозвонок',
                                  style: TextStyle(
                                    color: missed ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              formatChatTimestamp(call.startedAt),
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
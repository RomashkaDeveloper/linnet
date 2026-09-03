import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_list_provider.dart';
import '../widgets/avatar_widget.dart';

/// Lets the user pick a chat to forward a message into. Pops with the
/// selected chat's id, or null if the user backed out.
class ForwardScreen extends StatelessWidget {
  const ForwardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatList = context.watch<ChatListProvider>();
    final currentUserId = context.read<AuthProvider>().currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Переслать в...')),
      body: chatList.chats.isEmpty
          ? const Center(child: Text('Нет доступных чатов'))
          : ListView.builder(
              itemCount: chatList.chats.length,
              itemBuilder: (context, i) {
                final chat = chatList.chats[i];
                return ListTile(
                  leading: AvatarWidget(
                    name: chat.displayName(currentUserId),
                    imageUrl: chat.avatarUrl,
                    size: 40,
                  ),
                  title: Text(chat.displayName(currentUserId)),
                  onTap: () => Navigator.of(context).pop(chat.id),
                );
              },
            ),
    );
  }
}

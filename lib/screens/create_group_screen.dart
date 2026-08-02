import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/chat.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_widget.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  Timer? _debounce;
  List<UserPublic> _results = [];
  final Map<String, UserPublic> _selected = {};
  bool _loading = false;
  bool _creating = false;

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await UserService().search(query);
      if (mounted) setState(() => _results = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите название группы')));
      return;
    }
    setState(() => _creating = true);
    try {
      final chat = await ChatService().createGroup(name, _selected.keys.toList());
      if (mounted) Navigator.of(context).pop<ChatOut>(chat);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось создать группу: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая группа'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Создать'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Название группы')),
          ),
          if (_selected.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _selected.values
                    .map((u) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Chip(
                            label: Text(u.displayName),
                            onDeleted: () => setState(() => _selected.remove(u.id)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onChanged,
              decoration: const InputDecoration(hintText: 'Добавить участников', prefixIcon: Icon(Icons.search)),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final user = _results[index];
                final isSelected = _selected.containsKey(user.id);
                return CheckboxListTile(
                  value: isSelected,
                  secondary: AvatarWidget(name: user.displayName, imageUrl: user.avatarUrl, size: 44),
                  title: Text(user.displayName),
                  subtitle: Text('@${user.username}'),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected[user.id] = user;
                    } else {
                      _selected.remove(user.id);
                    }
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

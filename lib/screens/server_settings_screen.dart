import 'package:flutter/material.dart';
import '../services/api_config.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ApiConfig.instance.baseUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ApiConfig.instance.setBaseUrl(_ctrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Адрес сервера сохранён')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки сервера')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Адрес backend-сервера (например, http://10.0.2.2:8000 для '
              'эмулятора Android или http://192.168.x.x:8000 для реального '
              'устройства в той же сети).',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(controller: _ctrl, decoration: const InputDecoration(labelText: 'Base URL')),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}

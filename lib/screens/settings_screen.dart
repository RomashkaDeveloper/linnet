import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/permission_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlCtrl;
  String? _buildNumber;
  String? _appVersion;
  String? _appName;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiConfig.instance.baseUrl);
    _getAppInfo();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    await ApiConfig.instance.setBaseUrl(_urlCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Адрес сервера сохранён')));
    }
  }

  Future<void> _checkPermission(Future<bool> Function() request, String label) async {
    final granted = await request();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(granted ? '$label: доступ есть' : '$label: доступа нет — включите в настройках системы')),
    );
  }

  Future<void> _getAppInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String appName = packageInfo.appName;
    // String packageName = packageInfo.packageName;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;

    if (!mounted) return;

    setState(() {
      _buildNumber = buildNumber;
      _appVersion = version;
      _appName = appName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Text('Сервер', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'Base URL')),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _saveUrl, child: const Text('Сохранить'))),
          const SizedBox(height: 28),
          Text('Разрешения', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Приложение запрашивает их по мере необходимости, но здесь можно проверить статус заранее.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mic_outlined),
            title: const Text('Микрофон'),
            subtitle: const Text('Нужен для звонков'),
            trailing: TextButton(
              onPressed: () => _checkPermission(AppPermissions.ensureMicrophone, 'Микрофон'),
              child: const Text('Проверить'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Камера'),
            subtitle: const Text('Нужна для видеозвонков и фото'),
            trailing: TextButton(
              onPressed: () => _checkPermission(AppPermissions.ensureCamera, 'Камера'),
              child: const Text('Проверить'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Уведомления'),
            subtitle: const Text('Push о новых сообщениях и звонках'),
            trailing: TextButton(
              onPressed: () => _checkPermission(AppPermissions.ensureNotifications, 'Уведомления'),
              child: const Text('Проверить'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Фото и медиа'),
            subtitle: const Text('Нужны для отправки вложений'),
            trailing: TextButton(
              onPressed: () => _checkPermission(AppPermissions.ensurePhotos, 'Фото и медиа'),
              child: const Text('Проверить'),
            ),
          ),
          const SizedBox(height: 28),
          Text('О приложении', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text(_appName ?? "Загружается"),
            subtitle: Text('Версия: ${_appVersion ?? "Загружается"}+${_buildNumber ?? "Загружается"}'),
          ),
        ],
      ),
    );
  }
}

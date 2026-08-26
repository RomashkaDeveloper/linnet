import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import '../widgets/floating_nav_bar.dart';
import 'call_history_screen.dart';
import 'home_screen.dart';
import 'incoming_call_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;
  bool _incomingScreenOpen = false;
  late final CallProvider _callProvider;

  final List<Widget> _tabs = const [
    HomeScreen(),
    CallHistoryScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _callProvider = context.read<CallProvider>();
    _callProvider.addListener(_onCallStateChange);
  }

  void _onCallStateChange() {
    if (_callProvider.state == CallState.incomingRinging && !_incomingScreenOpen) {
      _incomingScreenOpen = true;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const IncomingCallScreen(), fullscreenDialog: true))
          .then((_) => _incomingScreenOpen = false);
    }
  }

  @override
  void dispose() {
    _callProvider.removeListener(_onCallStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _tabs),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: FloatingNavBar(
              index: _index,
              onChanged: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}

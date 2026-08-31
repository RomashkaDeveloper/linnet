import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:linnet/firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/chat_list_provider.dart';
import 'services/api_config.dart';
import 'services/push_service.dart';
import 'screens/splash_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/chat_screen.dart';

const kSeedColor = Color(0xFF244B9B);

/// Глобальный ключ навигатора — нужен PushService, чтобы открывать экраны
/// по тапу на уведомление. PushService не виджет и не имеет BuildContext,
/// поэтому обычный Navigator.of(context) ему недоступен.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Регистрировать background handler нужно ДО runApp и именно top-level
  // функцией (см. push_service.dart) — Android поднимает для неё отдельный
  // изолят, когда приложение полностью в фоне/убито.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await ApiConfig.instance.load();

  PushService.onNotificationRoute = _handleNotificationRoute;
  await PushService.init();

  runApp(const LinnetApp());
}

/// Обрабатывает payload вида "call:<id>" или "chat:<id>" по тапу на
/// уведомление. Для звонков — сначала восстанавливаем состояние через API
/// (WebSocket на холодном старте ещё может быть не подключён), и только
/// если звонок ещё актуален (не завершился/не отклонён до открытия
/// приложения) — открываем IncomingCallScreen.
void _handleNotificationRoute(String payload) {
  final parts = payload.split(':');
  if (parts.length != 2) return;
  final type = parts[0];
  final id = parts[1];

  _withReadyNavigator((context) {
    if (type == 'call') {
      final callProvider = context.read<CallProvider>();
      callProvider.restoreIncomingCall(id).then((ok) {
        if (!ok) return;
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        nav.push(MaterialPageRoute(builder: (_) => const IncomingCallScreen()));
      });
    } else if (type == 'chat') {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: id)));
    }
  });
}

/// После запуска приложения _withReadyNavigator() ждёт и готовность
/// Navigator, и завершение восстановления авторизации. Это важно для
/// холодного старта по уведомлению: restoreIncomingCall() должен иметь
/// действующий токен, иначе API-запрос за данными звонка может получить 401.
void _withReadyNavigator(void Function(BuildContext context) action) {
  final context = navigatorKey.currentContext;
  if (context == null) {
    Future.delayed(const Duration(milliseconds: 100), () {
      _withReadyNavigator(action);
    });
    return;
  }

  final authStatus = context.read<AuthProvider>().status;
  if (authStatus == AuthStatus.unknown) {
    Future.delayed(const Duration(milliseconds: 100), () {
      _withReadyNavigator(action);
    });
    return;
  }

  if (authStatus == AuthStatus.unauthenticated) {
    // Не залогинен — открывать чат/звонок нет смысла, пусть пользователь
    // сначала пройдёт экран логина обычным путём.
    return;
  }

  action(context);
}

class LinnetApp extends StatefulWidget {
  const LinnetApp({super.key});

  @override
  State<LinnetApp> createState() => _LinnetAppState();
}

class _LinnetAppState extends State<LinnetApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushService.handleInitialMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatListProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Linnet',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // ─────────────────────────────────────────────
      // Общий фон
      // ─────────────────────────────────────────────

      scaffoldBackgroundColor: isLight
          ? const Color(0xFFF4F5F7)
          : const Color(0xFF0B0D10),

      // ─────────────────────────────────────────────
      // AppBar
      // ─────────────────────────────────────────────

      appBarTheme: AppBarTheme(
        backgroundColor: isLight
            ? const Color(0xFFF4F5F7)
            : const Color(0xFF0B0D10),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ─────────────────────────────────────────────
      // Поля ввода
      // ─────────────────────────────────────────────

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? Colors.white
            : const Color(0xFF15181D),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),

        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // ─────────────────────────────────────────────
      // Основные кнопки
      // ─────────────────────────────────────────────

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),

      // ─────────────────────────────────────────────
      // FAB
      // ─────────────────────────────────────────────

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: const CircleBorder(),
        elevation: 3,
        highlightElevation: 6,
        // backgroundColor: colorScheme.primary,
        // foregroundColor: colorScheme.onPrimary,
      ),

      // ─────────────────────────────────────────────
      // Списки
      // ─────────────────────────────────────────────

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // ─────────────────────────────────────────────
      // Разделители
      // ─────────────────────────────────────────────

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.45),
        thickness: 1,
        space: 1,
      ),

      // ─────────────────────────────────────────────
      // Диалоги
      // ─────────────────────────────────────────────

      dialogTheme: DialogThemeData(
        backgroundColor: isLight
            ? Colors.white
            : const Color(0xFF15181D),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // ─────────────────────────────────────────────
      // Bottom Sheet
      // ─────────────────────────────────────────────

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight
            ? Colors.white
            : const Color(0xFF15181D),
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
      ),

      // ─────────────────────────────────────────────
      // Карточки
      // ─────────────────────────────────────────────

      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight
            ? Colors.white
            : const Color(0xFF15181D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}

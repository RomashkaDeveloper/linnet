import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:linnet/firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/chat_list_provider.dart';
import 'services/api_config.dart';
import 'screens/splash_screen.dart';

const kSeedColor = Color(0xFF244B9B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ApiConfig.instance.load();
  runApp(const LinnetApp());
}

class LinnetApp extends StatelessWidget {
  const LinnetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatListProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
      ],
      child: MaterialApp(
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

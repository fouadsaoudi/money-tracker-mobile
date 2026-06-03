import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_config.dart';
import 'core/app_session.dart';
import 'core/shared_widgets.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';

void main() {
  runApp(const MoneyTrackerApp());
}

class MoneyTrackerApp extends StatefulWidget {
  const MoneyTrackerApp({super.key});

  @override
  State<MoneyTrackerApp> createState() => _MoneyTrackerAppState();
}

class _MoneyTrackerAppState extends State<MoneyTrackerApp>
    with WidgetsBindingObserver {
  late final AppSession session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = AppSession(ApiClient(defaultApiBaseUrl))..restore();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final platformBrightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final brightness = switch (session.themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => platformBrightness,
        };
        AppColors.useBrightness(brightness);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Money Tracker',
          themeMode: session.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: session.isRestoring
              ? const LoadingScreen()
              : session.isSignedIn
              ? HomeShell(session: session)
              : AuthScreen(session: session),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = brightness == Brightness.dark
        ? const ColorScheme.dark(
            primary: Color(0xff2dd4bf),
            onPrimary: Color(0xff042f2e),
            primaryContainer: Color(0xff134e4a),
            onPrimaryContainer: Color(0xffccfbf1),
            secondary: Color(0xff93c5fd),
            onSecondary: Color(0xff0f172a),
            secondaryContainer: Color(0xff1e3a5f),
            onSecondaryContainer: Color(0xffdbeafe),
            tertiary: Color(0xfffbbf24),
            onTertiary: Color(0xff271700),
            error: Color(0xfffb7185),
            onError: Color(0xff4c0519),
            surface: Color(0xff17211f),
            onSurface: Color(0xfff6f8f4),
            surfaceContainerHighest: Color(0xff22302c),
            outline: Color(0xff4b5f59),
          )
        : ColorScheme.fromSeed(
            seedColor: AppColors.teal,
            brightness: Brightness.light,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.8),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        elevation: 8,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 20,
          color: AppColors.ink,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

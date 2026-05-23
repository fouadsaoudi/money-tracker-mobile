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

class _MoneyTrackerAppState extends State<MoneyTrackerApp> {
  late final AppSession session;

  @override
  void initState() {
    super.initState();
    session = AppSession(ApiClient(defaultApiBaseUrl))..restore();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Money Tracker',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.teal,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: AppColors.canvas,
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: AppColors.ink,
              displayColor: AppColors.ink,
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            dialogTheme: DialogThemeData(
              elevation: 8,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titleTextStyle: const TextStyle(
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
          ),
          home: session.isRestoring
              ? const LoadingScreen()
              : session.isSignedIn
              ? HomeShell(session: session)
              : AuthScreen(session: session),
        );
      },
    );
  }
}

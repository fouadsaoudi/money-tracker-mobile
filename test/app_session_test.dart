import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/api_client.dart';
import 'package:money_tracker/core/app_config.dart';
import 'package:money_tracker/core/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('theme defaults to the system style', () async {
    SharedPreferences.setMockInitialValues({});
    final session = AppSession(ApiClient(defaultApiBaseUrl));

    await session.restore();

    expect(session.themeMode, ThemeMode.system);
  });

  test('theme selection is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final session = AppSession(ApiClient(defaultApiBaseUrl));

    await session.restore();
    await session.updateThemeMode(ThemeMode.dark);

    final restoredSession = AppSession(ApiClient(defaultApiBaseUrl));
    await restoredSession.restore();
    expect(restoredSession.themeMode, ThemeMode.dark);
  });
}

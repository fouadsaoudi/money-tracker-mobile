import 'package:flutter/material.dart';

const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://165.22.31.57:8080/api',
);

const apiBaseUrlPreferenceKey = 'api_base_url';
const themeModePreferenceKey = 'theme_mode';

class AppColors {
  static Brightness _brightness = Brightness.light;

  static void useBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static bool get _isDark => _brightness == Brightness.dark;

  static Color get ink =>
      _isDark ? const Color(0xfff3f4f6) : const Color(0xff151515);
  static Color get muted =>
      _isDark ? const Color(0xffa7b0ad) : const Color(0xff66726d);
  static Color get canvas =>
      _isDark ? const Color(0xff111817) : const Color(0xfff4f7f3);
  static Color get surface =>
      _isDark ? const Color(0xff1b2523) : const Color(0xffffffff);
  static Color get border =>
      _isDark ? const Color(0xff34423f) : const Color(0xffdde6df);
  static const authBackground = Color(0xff151515);
  static const teal = Color(0xff0f766e);
  static const blue = Color(0xff2563eb);
  static const amber = Color(0xffd97706);
  static const rose = Color(0xffbe123c);
  static const green = Color(0xff15803d);
}

import 'package:flutter/material.dart';

const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api',
);

const apiBaseUrlPreferenceKey = 'api_base_url';

class AppColors {
  static const ink = Color(0xff151515);
  static const muted = Color(0xff66726d);
  static const canvas = Color(0xfff4f7f3);
  static const surface = Color(0xffffffff);
  static const border = Color(0xffdde6df);
  static const teal = Color(0xff0f766e);
  static const blue = Color(0xff2563eb);
  static const amber = Color(0xffd97706);
  static const rose = Color(0xffbe123c);
  static const green = Color(0xff15803d);
}

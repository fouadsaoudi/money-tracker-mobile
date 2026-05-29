import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'app_config.dart';

class AppSession extends ChangeNotifier {
  AppSession(this.api);

  final ApiClient api;
  UserProfile? user;
  bool isRestoring = true;
  Timer? _syncTimer;

  bool get isSignedIn => api.token != null;
  String get apiBaseUrl => api.baseUrl;

  void startSyncTimer() {
    _syncTimer?.cancel();
    unawaited(api.checkConnection());
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (isSignedIn) {
        await api.syncOutbox();
        await api.checkConnection();
      }
    });
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    api.baseUrl = prefs.getString(apiBaseUrlPreferenceKey) ?? defaultApiBaseUrl;
    api.token = prefs.getString('auth_token');
    if (api.token == null) {
      isRestoring = false;
      notifyListeners();
      return;
    }

    try {
      user = await api.profile();
      startSyncTimer();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        await prefs.remove('auth_token');
        api.token = null;
      } else {
        // Network offline error, start sync timer anyway for cached session
        startSyncTimer();
      }
    } finally {
      isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final auth = await api.login(email: email, password: password);
    await _persistAuth(auth);
    startSyncTimer();
  }

  Future<void> register(String name, String email, String password) async {
    final auth = await api.register(
      name: name,
      email: email,
      password: password,
    );
    await _persistAuth(auth);
    startSyncTimer();
  }

  Future<void> refreshProfile() async {
    user = await api.profile();
    notifyListeners();
  }

  Future<void> updateReportingCurrency(int currencyId) async {
    user = await api.updatePreferences(currencyId);
    notifyListeners();
  }

  Future<void> logout() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    api.token = null;
    user = null;
    notifyListeners();
  }

  Future<void> updateApiBaseUrl(String value) async {
    final nextBaseUrl = _normalizeApiBaseUrl(value);
    if (nextBaseUrl == api.baseUrl) return;

    _syncTimer?.cancel();
    _syncTimer = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(apiBaseUrlPreferenceKey, nextBaseUrl);
    await prefs.remove('auth_token');
    api.baseUrl = nextBaseUrl;
    api.token = null;
    user = null;
    notifyListeners();
  }

  Future<void> _persistAuth(AuthResult auth) async {
    api.token = auth.token;
    user = auth.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', auth.token);
    notifyListeners();
  }

  String _normalizeApiBaseUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Enter a valid http or https API URL.');
    }

    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

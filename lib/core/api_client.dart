import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'helpers.dart';

class InvoiceImageUpload {
  const InvoiceImageUpload({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}

class ApiClient {
  ApiClient(this.baseUrl);

  String baseUrl;
  String? token;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final json = await post('/login', {
      'email': email,
      'password': password,
      'device_name': 'flutter-app',
    });
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await post('/register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'device_name': 'flutter-app',
    });
    return AuthResult.fromJson(json);
  }

  Future<void> forgotPassword(String email) async {
    await post('/forgot-password', {'email': email});
  }

  Future<UserProfile> profile() async {
    final json = await get('/me');
    return UserProfile.fromJson(asMap(json['user']));
  }

  Future<UserProfile> updatePreferences(int reportingCurrencyId) async {
    final json = await patch('/me/preferences', {
      'reporting_currency_id': reportingCurrencyId,
    });
    return UserProfile.fromJson(asMap(json['user']));
  }

  Future<List<Currency>> currencies() async {
    final json = await get('/currencies');
    return asList(
      json['data'],
    ).map((item) => Currency.fromJson(asMap(item))).toList();
  }

  Future<List<Category>> categories() async {
    final json = await get('/categories');
    return asList(
      json['data'],
    ).map((item) => Category.fromJson(asMap(item))).toList();
  }

  Future<Category> createCategory({
    required String name,
    String? color,
    String? icon,
  }) async {
    final json = await post('/categories', {
      'name': name,
      'color': color,
      'icon': icon,
    });
    return Category.fromJson(asMap(json['data']));
  }

  Future<void> deleteCategory(int id) async {
    await delete('/categories/$id');
  }

  Future<List<Wallet>> wallets() async {
    final json = await get('/wallets');
    return asList(
      json['data'],
    ).map((item) => Wallet.fromJson(asMap(item))).toList();
  }

  Future<Wallet> createWallet({
    required int currencyId,
    String? name,
    String? balance,
    bool isDefault = false,
  }) async {
    final json = await post('/wallets', {
      'currency_id': currencyId,
      'name': name,
      'balance': balance,
      'is_default': isDefault,
    });
    return Wallet.fromJson(asMap(json['data']));
  }

  Future<Wallet> updateWallet({
    required int id,
    String? name,
    String? balance,
    bool? isDefault,
  }) async {
    final json = await patch('/wallets/$id', {
      'name': name,
      'balance': balance,
      'is_default': isDefault,
    });
    return Wallet.fromJson(asMap(json['data']));
  }

  Future<List<Goal>> goals() async {
    final json = await get('/goals');
    return asList(
      json['data'],
    ).map((item) => Goal.fromJson(asMap(item))).toList();
  }

  Future<Goal> createGoal({
    required String name,
    required int currencyId,
    required String targetAmount,
    String? note,
  }) async {
    final json = await post('/goals', {
      'name': name,
      'currency_id': currencyId,
      'target_amount': targetAmount,
      'note': note,
    });
    return Goal.fromJson(asMap(json['data']));
  }

  Future<Goal> contributeToGoal({
    required int goalId,
    required int walletId,
    required String amount,
    required DateTime occurredOn,
    String? note,
    List<InvoiceImageUpload> invoiceImages = const [],
  }) async {
    final body = {
      'wallet_id': walletId,
      'amount': amount,
      'occurred_on': isoDateTime(occurredOn),
      'note': note,
    };
    final json = invoiceImages.isEmpty
        ? await post('/goals/$goalId/contributions', body)
        : await multipart(
            'POST',
            '/goals/$goalId/contributions',
            fields: body,
            fileField: 'invoice_images[]',
            files: invoiceImages,
          );
    return Goal.fromJson(asMap(json['data']));
  }

  Future<DashboardData> dashboard() async {
    return DashboardData.fromJson(await get('/dashboard'));
  }

  Future<AnalyticsData> analytics({
    String? from,
    String? to,
    int? categoryId,
    String? type,
  }) async {
    final params = <String, String>{};
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;
    if (categoryId != null) params['category_id'] = '$categoryId';
    if (type != null && type.isNotEmpty) params['type'] = type;
    return AnalyticsData.fromJson(await get('/analytics', params));
  }

  Future<PagedTransactions> transactions({
    String? search,
    int? categoryId,
    String? type,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category_id'] = '$categoryId';
    if (type != null && type.isNotEmpty) params['type'] = type;
    final json = await get('/transactions', params);
    return PagedTransactions.fromJson(json);
  }

  Future<TransactionRecord> createTransaction({
    required int categoryId,
    required int walletId,
    required String type,
    required String amount,
    required DateTime occurredOn,
    String? note,
    List<InvoiceImageUpload> invoiceImages = const [],
  }) async {
    final body = {
      'category_id': categoryId,
      'wallet_id': walletId,
      'type': type,
      'amount': amount,
      'note': note,
      'occurred_on': isoDateTime(occurredOn),
    };
    final json = invoiceImages.isEmpty
        ? await post('/transactions', body)
        : await multipart(
            'POST',
            '/transactions',
            fields: body,
            fileField: 'invoice_images[]',
            files: invoiceImages,
          );
    return TransactionRecord.fromJson(asMap(json['data']));
  }

  Future<void> convertWalletMoney({
    required int sourceWalletId,
    required int destinationWalletId,
    required String sourceAmount,
    required String destinationAmount,
    required DateTime occurredOn,
    String? note,
  }) async {
    await post('/wallet-conversions', {
      'source_wallet_id': sourceWalletId,
      'destination_wallet_id': destinationWalletId,
      'source_amount': sourceAmount,
      'destination_amount': destinationAmount,
      'occurred_on': isoDateTime(occurredOn),
      'note': note,
    });
  }

  Future<TransactionRecord> updateTransaction({
    required int id,
    required int categoryId,
    required int walletId,
    required String type,
    required String amount,
    required DateTime occurredOn,
    String? note,
    List<InvoiceImageUpload> invoiceImages = const [],
    bool removeInvoiceImages = false,
    List<int> removeInvoiceImageIds = const [],
  }) async {
    final body = {
      'category_id': categoryId,
      'wallet_id': walletId,
      'type': type,
      'amount': amount,
      'note': note,
      'occurred_on': isoDateTime(occurredOn),
      if (removeInvoiceImages) 'remove_invoice_images': true,
      if (removeInvoiceImageIds.isNotEmpty)
        'remove_invoice_image_ids': removeInvoiceImageIds,
    };
    final json = invoiceImages.isEmpty
        ? await patch('/transactions/$id', body)
        : await multipart(
            'POST',
            '/transactions/$id',
            fields: {...body, '_method': 'PATCH'},
            fileField: 'invoice_images[]',
            files: invoiceImages,
          );
    return TransactionRecord.fromJson(asMap(json['data']));
  }

  Future<void> deleteTransaction(int id) async {
    await delete('/transactions/$id');
  }

  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? query,
  ]) async {
    return send('GET', path, query: query);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    return send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) {
    return send('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> delete(String path) {
    return send('DELETE', path);
  }

  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri);
    request.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final response = await request.send().timeout(const Duration(seconds: 20));
    return handleResponse(response);
  }

  Future<Map<String, dynamic>> multipart(
    String method,
    String path, {
    required Map<String, dynamic> fields,
    required String fileField,
    required List<InvoiceImageUpload> files,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest(method, uri);
    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    for (final entry in fields.entries) {
      final value = entry.value;
      if (value is Iterable) {
        var index = 0;
        for (final item in value) {
          request.fields['${entry.key}[$index]'] = '$item';
          index++;
        }
      } else if (value != null) {
        request.fields[entry.key] = '$value';
      }
    }

    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          file.bytes,
          filename: file.filename,
        ),
      );
    }

    final response = await request.send().timeout(const Duration(seconds: 40));
    return handleResponse(response);
  }

  Future<Map<String, dynamic>> handleResponse(
    http.StreamedResponse response,
  ) async {
    final text = await response.stream.bytesToString();
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    final json = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, json);
    }

    return json;
  }
}

class ApiException implements Exception {
  ApiException(
    this.message, {
    required this.statusCode,
    this.errors = const {},
  });

  factory ApiException.fromResponse(int statusCode, Map<String, dynamic> json) {
    final errors = <String, List<String>>{};
    final rawErrors = json['errors'];
    if (rawErrors is Map) {
      for (final entry in rawErrors.entries) {
        errors['${entry.key}'] = asList(
          entry.value,
        ).map((value) => '$value').toList();
      }
    }
    final fallback = statusCode == 401
        ? 'Please sign in again.'
        : 'Request failed.';
    return ApiException(
      '${json['message'] ?? errors.values.firstOrNull?.firstOrNull ?? fallback}',
      statusCode: statusCode,
      errors: errors,
    );
  }

  final String message;
  final int statusCode;
  final Map<String, List<String>> errors;

  @override
  String toString() => message;
}

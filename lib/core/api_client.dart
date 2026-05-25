import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'helpers.dart';
import 'local_db.dart';

class InvoiceImageUpload {
  const InvoiceImageUpload({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}

class ApiClient {
  ApiClient(this.baseUrl);

  String baseUrl;
  String? token;
  bool _syncing = false;

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
    final p = UserProfile.fromJson(asMap(json['user']));
    if (p.reportingCurrency != null) {
      await LocalDb.instance.saveCurrencies([p.reportingCurrency!]);
    }
    return p;
  }

  Future<UserProfile> updatePreferences(int reportingCurrencyId) async {
    final json = await patch('/me/preferences', {
      'reporting_currency_id': reportingCurrencyId,
    });
    return UserProfile.fromJson(asMap(json['user']));
  }

  Future<List<Currency>> currencies() async {
    try {
      final json = await get('/currencies');
      final list = asList(
        json['data'],
      ).map((item) => Currency.fromJson(asMap(item))).toList();
      await LocalDb.instance.saveCurrencies(list);
      unawaited(syncOutbox());
      return list;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        return await LocalDb.instance.getCurrencies();
      }
      rethrow;
    }
  }

  Future<List<Category>> categories() async {
    try {
      final json = await get('/categories');
      final list = asList(
        json['data'],
      ).map((item) => Category.fromJson(asMap(item))).toList();
      await LocalDb.instance.saveCategories(list);
      unawaited(syncOutbox());
      return list;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        return await LocalDb.instance.getCategories();
      }
      rethrow;
    }
  }

  Future<Category> createCategory({
    required String name,
    String? color,
    String? icon,
  }) async {
    try {
      final json = await post('/categories', {
        'name': name,
        'color': color,
        'icon': icon,
      });
      final cat = Category.fromJson(asMap(json['data']));
      await LocalDb.instance.saveCategories([cat]);
      return cat;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        final cat = await LocalDb.instance.createCategoryLocally(
          name: name,
          color: color,
          icon: icon,
        );
        await LocalDb.instance.queueOperation('createCategory', {
          'temp_id': cat.id,
          'name': name,
          'color': color,
          'icon': icon,
        });
        return cat;
      }
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await delete('/categories/$id');
      await LocalDb.instance.deleteCategoryLocally(id);
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        await LocalDb.instance.deleteCategoryLocally(id);
        await LocalDb.instance.queueOperation('deleteCategory', {
          'id': id,
        });
        return;
      }
      rethrow;
    }
  }

  Future<List<Wallet>> wallets() async {
    try {
      final json = await get('/wallets');
      final list = asList(
        json['data'],
      ).map((item) => Wallet.fromJson(asMap(item))).toList();
      await LocalDb.instance.saveWallets(list);
      unawaited(syncOutbox());
      return list;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        return await LocalDb.instance.getWallets();
      }
      rethrow;
    }
  }

  Future<Wallet> createWallet({
    required int currencyId,
    String? name,
    String? balance,
    bool isDefault = false,
  }) async {
    try {
      final json = await post('/wallets', {
        'currency_id': currencyId,
        'name': name,
        'balance': balance,
        'is_default': isDefault,
      });
      final wallet = Wallet.fromJson(asMap(json['data']));
      await LocalDb.instance.saveWallets([wallet]);
      return wallet;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        final wallet = await LocalDb.instance.createWalletLocally(
          currencyId: currencyId,
          name: name,
          balance: balance,
          isDefault: isDefault,
        );
        await LocalDb.instance.queueOperation('createWallet', {
          'temp_id': wallet.id,
          'currency_id': currencyId,
          'name': name,
          'balance': balance,
          'is_default': isDefault,
        });
        return wallet;
      }
      rethrow;
    }
  }

  Future<Wallet> updateWallet({
    required int id,
    String? name,
    String? balance,
    bool? isDefault,
  }) async {
    try {
      final json = await patch('/wallets/$id', {
        'name': name,
        'balance': balance,
        'is_default': isDefault,
      });
      final wallet = Wallet.fromJson(asMap(json['data']));
      await LocalDb.instance.saveWallets([wallet]);
      return wallet;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        final wallet = await LocalDb.instance.updateWalletLocally(
          id: id,
          name: name,
          balance: balance,
          isDefault: isDefault,
        );
        await LocalDb.instance.queueOperation('updateWallet', {
          'id': id,
          'name': name,
          'balance': balance,
          'is_default': isDefault,
        });
        return wallet;
      }
      rethrow;
    }
  }

  Future<List<Goal>> goals() async {
    try {
      final json = await get('/goals');
      final list = asList(
        json['data'],
      ).map((item) => Goal.fromJson(asMap(item))).toList();
      await LocalDb.instance.saveGoals(list);
      unawaited(syncOutbox());
      return list;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        return await LocalDb.instance.getGoals();
      }
      rethrow;
    }
  }

  Future<Goal> createGoal({
    required String name,
    required int currencyId,
    required String targetAmount,
    String? note,
  }) async {
    try {
      final json = await post('/goals', {
        'name': name,
        'currency_id': currencyId,
        'target_amount': targetAmount,
        'note': note,
      });
      final goal = Goal.fromJson(asMap(json['data']));
      await LocalDb.instance.saveGoals([goal]);
      return goal;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        final goal = await LocalDb.instance.createGoalLocally(
          name: name,
          currencyId: currencyId,
          targetAmount: targetAmount,
          note: note,
        );
        await LocalDb.instance.queueOperation('createGoal', {
          'temp_id': goal.id,
          'name': name,
          'currency_id': currencyId,
          'target_amount': targetAmount,
          'note': note,
        });
        return goal;
      }
      rethrow;
    }
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
    try {
      final json = invoiceImages.isEmpty
          ? await post('/goals/$goalId/contributions', body)
          : await multipart(
              'POST',
              '/goals/$goalId/contributions',
              fields: body,
              fileField: 'invoice_images[]',
              files: invoiceImages,
            );
      final goal = Goal.fromJson(asMap(json['data']));
      await LocalDb.instance.saveGoals([goal]);
      return goal;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        final goal = await LocalDb.instance.contributeToGoalLocally(
          goalId: goalId,
          walletId: walletId,
          amount: amount,
          occurredOn: occurredOn,
          note: note,
        );
        await LocalDb.instance.queueOperation('contributeToGoal', {
          'goal_id': goalId,
          'wallet_id': walletId,
          'amount': amount,
          'occurred_on': occurredOn.toIso8601String(),
          'note': note,
        });
        return goal;
      }
      rethrow;
    }
  }

  Future<DashboardData> dashboard() async {
    try {
      final json = await get('/dashboard');
      final rawData = DashboardData.fromJson(json);

      // Recalculate daily budget from net amount (combined balance)
      final double combinedBalance = double.tryParse(rawData.balance) ?? 0;
      final int days = rawData.dailySpending.daysUntilMonthEnd;
      final double newBudget = days > 0 ? (combinedBalance / days) : combinedBalance;
      final double spent = double.tryParse(rawData.dailySpending.spentToday) ?? 0;
      final double newRemaining = newBudget - spent;

      final data = DashboardData(
        reportingCurrency: rawData.reportingCurrency,
        balance: rawData.balance,
        income: rawData.income,
        expense: rawData.expense,
        dailySpending: DailySpending(
          daysUntilMonthEnd: days,
          budgetToday: newBudget.toStringAsFixed(4),
          budgetTodaySecondary: rawData.dailySpending.budgetTodaySecondary,
          spentToday: rawData.dailySpending.spentToday,
          remainingToday: newRemaining.toStringAsFixed(4),
        ),
        totalsByCurrency: rawData.totalsByCurrency,
        recentTransactions: rawData.recentTransactions,
      );

      await LocalDb.instance.saveDashboard(data);
      unawaited(syncOutbox());
      return data;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        final cached = await LocalDb.instance.getDashboard();
        if (cached != null) return cached;
      }
      rethrow;
    }
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

    final key = 'analytics_${from ?? ""}_${to ?? ""}_${categoryId ?? ""}_${type ?? ""}';
    try {
      final json = await get('/analytics', params);
      final data = AnalyticsData.fromJson(json);
      await LocalDb.instance.saveAnalytics(key, data);
      unawaited(syncOutbox());
      return data;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        final cached = await LocalDb.instance.getAnalytics(key);
        if (cached != null) return cached;
      }
      rethrow;
    }
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

    try {
      final json = await get('/transactions', params);
      final paged = PagedTransactions.fromJson(json);
      await LocalDb.instance.saveTransactions(paged.data);
      unawaited(syncOutbox());
      return paged;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        final list = await LocalDb.instance.getTransactions(
          search: search,
          categoryId: categoryId,
          type: type,
        );
        return PagedTransactions(data: list, total: list.length);
      }
      rethrow;
    }
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
    try {
      final json = invoiceImages.isEmpty
          ? await post('/transactions', body)
          : await multipart(
              'POST',
              '/transactions',
              fields: body,
              fileField: 'invoice_images[]',
              files: invoiceImages,
            );
      final tx = TransactionRecord.fromJson(asMap(json['data']));
      await LocalDb.instance.saveTransactions([tx]);
      return tx;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        final tx = await LocalDb.instance.createTransactionLocally(
          categoryId: categoryId,
          walletId: walletId,
          type: type,
          amount: amount,
          occurredOn: occurredOn,
          note: note,
        );
        await LocalDb.instance.queueOperation('createTransaction', {
          'temp_id': tx.id,
          'category_id': categoryId,
          'wallet_id': walletId,
          'type': type,
          'amount': amount,
          'occurred_on': occurredOn.toIso8601String(),
          'note': note,
        });
        return tx;
      }
      rethrow;
    }
  }

  Future<void> convertWalletMoney({
    required int sourceWalletId,
    required int destinationWalletId,
    required String sourceAmount,
    required String destinationAmount,
    required DateTime occurredOn,
    String? note,
  }) async {
    final body = {
      'source_wallet_id': sourceWalletId,
      'destination_wallet_id': destinationWalletId,
      'source_amount': sourceAmount,
      'destination_amount': destinationAmount,
      'occurred_on': isoDateTime(occurredOn),
      'note': note,
    };
    try {
      await post('/wallet-conversions', body);
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        await LocalDb.instance.convertWalletMoneyLocally(
          sourceWalletId: sourceWalletId,
          destinationWalletId: destinationWalletId,
          sourceAmount: sourceAmount,
          destinationAmount: destinationAmount,
          occurredOn: occurredOn,
          note: note,
        );
        await LocalDb.instance.queueOperation('convertWalletMoney', body);
        return;
      }
      rethrow;
    }
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
    try {
      final json = invoiceImages.isEmpty
          ? await patch('/transactions/$id', body)
          : await multipart(
              'POST',
              '/transactions/$id',
              fields: {...body, '_method': 'PATCH'},
              fileField: 'invoice_images[]',
              files: invoiceImages,
            );
      final tx = TransactionRecord.fromJson(asMap(json['data']));
      await LocalDb.instance.saveTransactions([tx]);
      return tx;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        await LocalDb.instance.deleteTransactionLocally(id);
        final tx = await LocalDb.instance.createTransactionLocally(
          categoryId: categoryId,
          walletId: walletId,
          type: type,
          amount: amount,
          occurredOn: occurredOn,
          note: note,
        );
        await LocalDb.instance.resolveTemporaryId('transactions', tx.id, id);

        await LocalDb.instance.queueOperation('updateTransaction', {
          'id': id,
          'category_id': categoryId,
          'wallet_id': walletId,
          'type': type,
          'amount': amount,
          'occurred_on': occurredOn.toIso8601String(),
          'note': note,
        });
        return tx;
      }
      rethrow;
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await delete('/transactions/$id');
      await LocalDb.instance.deleteTransactionLocally(id);
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        await LocalDb.instance.deleteTransactionLocally(id);
        await LocalDb.instance.queueOperation('deleteTransaction', {
          'id': id,
        });
        return;
      }
      rethrow;
    }
  }

  Future<void> syncOutbox() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final operations = await LocalDb.instance.getPendingOperations();
      for (final op in operations) {
        final opId = op['id'] as int;
        final methodName = op['method_name'] as String;
        final arguments = jsonDecode(op['arguments_json'] as String) as Map<String, dynamic>;

        try {
          if (methodName == 'createCategory') {
            final tempId = arguments['temp_id'] as int;
            final res = await createCategory(
              name: arguments['name'] as String,
              color: arguments['color'] as String?,
              icon: arguments['icon'] as String?,
            );
            await LocalDb.instance.resolveTemporaryId('categories', tempId, res.id);
          } else if (methodName == 'deleteCategory') {
            await deleteCategory(arguments['id'] as int);
          } else if (methodName == 'createWallet') {
            final tempId = arguments['temp_id'] as int;
            final res = await createWallet(
              currencyId: arguments['currency_id'] as int,
              name: arguments['name'] as String?,
              balance: arguments['balance'] as String?,
              isDefault: arguments['is_default'] == true,
            );
            await LocalDb.instance.resolveTemporaryId('wallets', tempId, res.id);
          } else if (methodName == 'updateWallet') {
            await updateWallet(
              id: arguments['id'] as int,
              name: arguments['name'] as String?,
              balance: arguments['balance'] as String?,
              isDefault: arguments['is_default'] as bool?,
            );
          } else if (methodName == 'createGoal') {
            final tempId = arguments['temp_id'] as int;
            final res = await createGoal(
              name: arguments['name'] as String,
              currencyId: arguments['currency_id'] as int,
              targetAmount: arguments['target_amount'] as String,
              note: arguments['note'] as String?,
            );
            await LocalDb.instance.resolveTemporaryId('goals', tempId, res.id);
          } else if (methodName == 'contributeToGoal') {
            await contributeToGoal(
              goalId: arguments['goal_id'] as int,
              walletId: arguments['wallet_id'] as int,
              amount: arguments['amount'] as String,
              occurredOn: DateTime.parse(arguments['occurred_on'] as String),
              note: arguments['note'] as String?,
            );
          } else if (methodName == 'createTransaction') {
            final tempId = arguments['temp_id'] as int;
            final res = await createTransaction(
              categoryId: arguments['category_id'] as int,
              walletId: arguments['wallet_id'] as int,
              type: arguments['type'] as String,
              amount: arguments['amount'] as String,
              occurredOn: DateTime.parse(arguments['occurred_on'] as String),
              note: arguments['note'] as String?,
            );
            await LocalDb.instance.resolveTemporaryId('transactions', tempId, res.id);
          } else if (methodName == 'convertWalletMoney') {
            await convertWalletMoney(
              sourceWalletId: arguments['source_wallet_id'] as int,
              destinationWalletId: arguments['destination_wallet_id'] as int,
              sourceAmount: arguments['source_amount'] as String,
              destinationAmount: arguments['destination_amount'] as String,
              occurredOn: DateTime.parse(arguments['occurred_on'] as String),
              note: arguments['note'] as String?,
            );
          } else if (methodName == 'updateTransaction') {
            await updateTransaction(
              id: arguments['id'] as int,
              categoryId: arguments['category_id'] as int,
              walletId: arguments['wallet_id'] as int,
              type: arguments['type'] as String,
              amount: arguments['amount'] as String,
              occurredOn: DateTime.parse(arguments['occurred_on'] as String),
              note: arguments['note'] as String?,
            );
          } else if (methodName == 'deleteTransaction') {
            await deleteTransaction(arguments['id'] as int);
          }

          await LocalDb.instance.deletePendingOperation(opId);
        } catch (e) {
          if (e is SocketException || e is TimeoutException || e is http.ClientException) {
            break;
          }
          await LocalDb.instance.deletePendingOperation(opId);
        }
      }
    } finally {
      _syncing = false;
    }
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

import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import 'helpers.dart';

class LocalDb {
  LocalDb._privateConstructor();
  static final LocalDb instance = LocalDb._privateConstructor();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'money_tracker.db');
    return await openDatabase(pathString, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE currencies (
        id INTEGER PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        symbol TEXT NOT NULL,
        decimal_places INTEGER NOT NULL,
        is_active INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT,
        icon TEXT,
        is_archived INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        balance TEXT NOT NULL,
        is_default INTEGER NOT NULL,
        currency_id INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        target_amount TEXT NOT NULL,
        current_amount TEXT NOT NULL,
        remaining_amount TEXT NOT NULL,
        progress REAL NOT NULL,
        contributions_count INTEGER NOT NULL,
        note TEXT,
        completed_at TEXT,
        currency_id INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE goal_contributions (
        id INTEGER PRIMARY KEY,
        goal_id INTEGER NOT NULL,
        amount TEXT NOT NULL,
        occurred_on TEXT,
        transaction_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        amount TEXT NOT NULL,
        note TEXT,
        occurred_on TEXT,
        converted_amount TEXT NOT NULL,
        category_id INTEGER,
        wallet_id INTEGER,
        currency_id INTEGER,
        reporting_currency_id INTEGER,
        invoice_images TEXT,
        invoice_image_urls TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE dashboard_cache (
        id INTEGER PRIMARY KEY,
        json_data TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE analytics_cache (
        key TEXT PRIMARY KEY,
        json_data TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        method_name TEXT NOT NULL,
        arguments_json TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  // --- Currencies ---

  Future<void> _saveCurrencyTxn(Transaction txn, Currency item) async {
    await txn.insert('currencies', {
      'id': item.id,
      'code': item.code,
      'name': item.name,
      'symbol': item.symbol,
      'decimal_places': item.decimalPlaces,
      'is_active': item.isActive ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveCurrencies(List<Currency> list) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in list) {
        await _saveCurrencyTxn(txn, item);
      }
    });
  }

  Future<List<Currency>> getCurrencies() async {
    final db = await database;
    final res = await db.query('currencies');
    return res
        .map((row) => Currency.fromJson(_currencyRowToJson(row)))
        .toList();
  }

  Future<Currency?> getCurrency(int id) async {
    final db = await database;
    final res = await db.query('currencies', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return Currency.fromJson(_currencyRowToJson(res.first));
  }

  Map<String, dynamic> _currencyRowToJson(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'code': row['code'],
      'name': row['name'],
      'symbol': row['symbol'],
      'decimal_places': row['decimal_places'],
      'is_active': row['is_active'] == 1,
    };
  }

  Map<String, dynamic> _currencyToJsonMap(Currency c) {
    return {
      'id': c.id,
      'code': c.code,
      'name': c.name,
      'symbol': c.symbol,
      'decimal_places': c.decimalPlaces,
      'is_active': c.isActive,
    };
  }

  // --- Categories ---

  Future<void> saveCategories(List<Category> list) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in list) {
        await txn.insert('categories', {
          'id': item.id,
          'name': item.name,
          'color': item.color,
          'icon': item.icon,
          'is_archived': item.isArchived ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final res = await db.query('categories');
    return res
        .map((row) => Category.fromJson(_categoryRowToJson(row)))
        .toList();
  }

  Future<Category?> getCategory(int id) async {
    final db = await database;
    final res = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return Category.fromJson(_categoryRowToJson(res.first));
  }

  Map<String, dynamic> _categoryRowToJson(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'color': row['color'],
      'icon': row['icon'],
      'is_archived': row['is_archived'] == 1,
    };
  }

  Map<String, dynamic>? _categoryToJsonMap(Category? c) {
    if (c == null) return null;
    return {
      'id': c.id,
      'name': c.name,
      'color': c.color,
      'icon': c.icon,
      'is_archived': c.isArchived,
    };
  }

  // --- Wallets ---

  Future<void> saveWallets(List<Wallet> list) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in list) {
        await txn.insert('wallets', {
          'id': item.id,
          'name': item.name,
          'balance': item.balance,
          'is_default': item.isDefault ? 1 : 0,
          'currency_id': item.currency.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _saveCurrencyTxn(txn, item.currency);
      }
    });
  }

  Future<List<Wallet>> getWallets() async {
    final db = await database;
    final walletRows = await db.query('wallets');
    final List<Wallet> list = [];
    for (final row in walletRows) {
      final currencyId = row['currency_id'] as int;
      final currency = await getCurrency(currencyId);
      if (currency != null) {
        list.add(
          Wallet.fromJson({
            'id': row['id'],
            'name': row['name'],
            'balance': row['balance'],
            'is_default': row['is_default'] == 1,
            'currency': _currencyToJsonMap(currency),
          }),
        );
      }
    }
    return list;
  }

  Future<Wallet?> getWallet(int id) async {
    final db = await database;
    final res = await db.query('wallets', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    final row = res.first;
    final currencyId = row['currency_id'] as int;
    final currency = await getCurrency(currencyId);
    if (currency == null) return null;
    return Wallet.fromJson({
      'id': row['id'],
      'name': row['name'],
      'balance': row['balance'],
      'is_default': row['is_default'] == 1,
      'currency': _currencyToJsonMap(currency),
    });
  }

  Map<String, dynamic> _walletToJsonMap(Wallet w) {
    return {
      'id': w.id,
      'name': w.name,
      'balance': w.balance,
      'is_default': w.isDefault,
      'currency': _currencyToJsonMap(w.currency),
    };
  }

  // --- Goals ---

  Future<void> saveGoals(List<Goal> list) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in list) {
        await txn.insert('goals', {
          'id': item.id,
          'name': item.name,
          'target_amount': item.targetAmount,
          'current_amount': item.currentAmount,
          'remaining_amount': item.remainingAmount,
          'progress': item.progress,
          'contributions_count': item.contributionsCount,
          'note': item.note,
          'completed_at': item.completedAt?.toIso8601String(),
          'currency_id': item.currency.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _saveCurrencyTxn(txn, item.currency);

        // Clean old contributions
        await txn.delete(
          'goal_contributions',
          where: 'goal_id = ?',
          whereArgs: [item.id],
        );

        for (final contrib in item.recentContributions) {
          await txn.insert('goal_contributions', {
            'id': contrib.id,
            'goal_id': item.id,
            'amount': contrib.amount,
            'occurred_on': contrib.occurredOn?.toIso8601String(),
            'transaction_id': contrib.transaction?.id,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          if (contrib.transaction != null) {
            await _saveTransactionTxn(txn, contrib.transaction!);
          }
        }
      }
    });
  }

  Future<List<Goal>> getGoals() async {
    final db = await database;
    final goalRows = await db.query('goals');
    final List<Goal> list = [];
    for (final row in goalRows) {
      final currencyId = row['currency_id'] as int;
      final currency = await getCurrency(currencyId);
      if (currency != null) {
        final contribRows = await db.query(
          'goal_contributions',
          where: 'goal_id = ?',
          whereArgs: [row['id']],
        );
        final List<Map<String, dynamic>> contributionsJson = [];
        for (final cRow in contribRows) {
          Map<String, dynamic>? txJson;
          if (cRow['transaction_id'] != null) {
            final tx = await getTransaction(cRow['transaction_id'] as int);
            if (tx != null) {
              txJson = _transactionToJsonMap(tx);
            }
          }
          contributionsJson.add({
            'id': cRow['id'],
            'amount': cRow['amount'],
            'occurred_on': cRow['occurred_on'],
            'transaction': txJson,
          });
        }

        list.add(
          Goal.fromJson({
            'id': row['id'],
            'name': row['name'],
            'target_amount': row['target_amount'],
            'current_amount': row['current_amount'],
            'remaining_amount': row['remaining_amount'],
            'progress': row['progress'],
            'contributions_count': row['contributions_count'],
            'note': row['note'],
            'completed_at': row['completed_at'],
            'recent_contributions': contributionsJson,
            'currency': _currencyToJsonMap(currency),
          }),
        );
      }
    }
    return list;
  }

  // --- Transactions ---

  Future<void> _saveTransactionTxn(
    Transaction txn,
    TransactionRecord item,
  ) async {
    await txn.insert('transactions', {
      'id': item.id,
      'type': item.type,
      'amount': item.amount,
      'note': item.note,
      'occurred_on': item.occurredOn?.toIso8601String(),
      'converted_amount': item.convertedAmount,
      'category_id': item.category?.id,
      'wallet_id': item.wallet?.id,
      'currency_id': item.currency?.id,
      'reporting_currency_id': item.reportingCurrency?.id,
      'invoice_images': jsonEncode(
        item.invoiceImages.map((e) => {'id': e.id, 'url': e.url}).toList(),
      ),
      'invoice_image_urls': jsonEncode(item.invoiceImageUrls),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (item.currency != null) {
      await _saveCurrencyTxn(txn, item.currency!);
    }
    if (item.reportingCurrency != null) {
      await _saveCurrencyTxn(txn, item.reportingCurrency!);
    }
    if (item.category != null) {
      await txn.insert('categories', {
        'id': item.category!.id,
        'name': item.category!.name,
        'color': item.category!.color,
        'icon': item.category!.icon,
        'is_archived': item.category!.isArchived ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    if (item.wallet != null) {
      await txn.insert('wallets', {
        'id': item.wallet!.id,
        'name': item.wallet!.name,
        'balance': item.wallet!.balance,
        'is_default': item.wallet!.isDefault ? 1 : 0,
        'currency_id': item.wallet!.currency.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _saveCurrencyTxn(txn, item.wallet!.currency);
    }
  }

  Future<void> saveTransactions(List<TransactionRecord> list) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in list) {
        await _saveTransactionTxn(txn, item);
      }
    });
  }

  Future<TransactionRecord?> getTransaction(int id) async {
    final db = await database;
    final res = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (res.isEmpty) return null;
    final row = res.first;

    final categoryId = row['category_id'] as int?;
    final category = categoryId != null ? await getCategory(categoryId) : null;

    final walletId = row['wallet_id'] as int?;
    final wallet = walletId != null ? await getWallet(walletId) : null;

    final currencyId = row['currency_id'] as int?;
    final currency = currencyId != null ? await getCurrency(currencyId) : null;

    final reportingCurrencyId = row['reporting_currency_id'] as int?;
    final reportingCurrency = reportingCurrencyId != null
        ? await getCurrency(reportingCurrencyId)
        : null;

    final List<dynamic> invoiceImagesRaw = jsonDecode(
      row['invoice_images'] as String? ?? '[]',
    );
    final List<dynamic> invoiceImageUrlsRaw = jsonDecode(
      row['invoice_image_urls'] as String? ?? '[]',
    );

    return TransactionRecord.fromJson({
      'id': row['id'],
      'type': row['type'],
      'amount': row['amount'],
      'note': row['note'],
      'occurred_on': row['occurred_on'],
      'converted_amount': row['converted_amount'],
      'category': category != null ? _categoryToJsonMap(category) : null,
      'wallet': wallet != null ? _walletToJsonMap(wallet) : null,
      'currency': currency != null ? _currencyToJsonMap(currency) : null,
      'reporting_currency': reportingCurrency != null
          ? _currencyToJsonMap(reportingCurrency)
          : null,
      'invoice_images': invoiceImagesRaw,
      'invoice_image_urls': invoiceImageUrlsRaw,
    });
  }

  Future<List<TransactionRecord>> getTransactions({
    String? search,
    int? categoryId,
    String? type,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    var query = 'SELECT transactions.id FROM transactions WHERE 1=1';
    final List<dynamic> args = [];
    if (search != null && search.trim().isNotEmpty) {
      query += '''
        AND (
          transactions.note LIKE ?
          OR CAST(transactions.id AS TEXT) = ?
          OR EXISTS (
            SELECT 1 FROM categories
            WHERE categories.id = transactions.category_id
              AND categories.name LIKE ?
          )
        )
      ''';
      args.addAll(['%${search.trim()}%', search.trim(), '%${search.trim()}%']);
    }
    if (categoryId != null) {
      query += ' AND category_id = ?';
      args.add(categoryId);
    }
    if (type != null && type.isNotEmpty) {
      query += ' AND type = ?';
      args.add(type);
    }
    if (from != null) {
      query += ' AND occurred_on >= ?';
      args.add(DateTime(from.year, from.month, from.day).toIso8601String());
    }
    if (to != null) {
      query += ' AND occurred_on < ?';
      args.add(DateTime(to.year, to.month, to.day + 1).toIso8601String());
    }
    query += ' ORDER BY transactions.occurred_on DESC';

    final res = await db.rawQuery(query, args);
    final List<TransactionRecord> list = [];
    for (final row in res) {
      final tx = await getTransaction(row['id'] as int);
      if (tx != null) {
        list.add(tx);
      }
    }
    return list;
  }

  Map<String, dynamic> _transactionToJsonMap(TransactionRecord tx) {
    return {
      'id': tx.id,
      'type': tx.type,
      'amount': tx.amount,
      'note': tx.note,
      'occurred_on': tx.occurredOn?.toIso8601String(),
      'converted_amount': tx.convertedAmount,
      'category': _categoryToJsonMap(tx.category),
      'wallet': tx.wallet == null ? null : _walletToJsonMap(tx.wallet!),
      'currency': tx.currency == null ? null : _currencyToJsonMap(tx.currency!),
      'reporting_currency': tx.reportingCurrency == null
          ? null
          : _currencyToJsonMap(tx.reportingCurrency!),
      'invoice_images': tx.invoiceImages
          .map((e) => {'id': e.id, 'url': e.url})
          .toList(),
      'invoice_image_urls': tx.invoiceImageUrls,
    };
  }

  // --- Dashboard Cache ---

  Future<void> saveDashboard(DashboardData data) async {
    final db = await database;
    await db.insert('dashboard_cache', {
      'id': 1,
      'json_data': jsonEncode(_dashboardToJsonMap(data)),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DashboardData?> getDashboard() async {
    final db = await database;
    final res = await db.query('dashboard_cache', where: 'id = 1');
    if (res.isEmpty) return null;
    final data = DashboardData.fromJson(
      jsonDecode(res.first['json_data'] as String),
    );
    return _rollDashboardForward(data);
  }

  DashboardData _rollDashboardForward(DashboardData data) {
    final now = DateTime.now();
    final today = isoDate(now);
    if (data.dailySpending.asOfDate == today) return data;

    final daysUntilMonthEnd =
        DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    final balance = double.tryParse(data.balance) ?? 0;
    final budget = balance / daysUntilMonthEnd;

    return DashboardData(
      reportingCurrency: data.reportingCurrency,
      balance: data.balance,
      income: data.income,
      expense: data.expense,
      dailySpending: DailySpending(
        asOfDate: today,
        daysUntilMonthEnd: daysUntilMonthEnd,
        budgetToday: budget.toStringAsFixed(4),
        spentToday: '0.0000',
        remainingToday: budget.toStringAsFixed(4),
      ),
      totalsByCurrency: data.totalsByCurrency,
      recentTransactions: data.recentTransactions,
    );
  }

  Map<String, dynamic> _dashboardToJsonMap(DashboardData data) {
    return {
      'reporting_currency': _currencyToJsonMap(data.reportingCurrency),
      'combined_balance': data.balance,
      'combined_income': data.income,
      'combined_expense': data.expense,
      'daily_spending': {
        'as_of_date': data.dailySpending.asOfDate,
        'days_until_month_end': data.dailySpending.daysUntilMonthEnd,
        'budget_today': data.dailySpending.budgetToday,
        'budget_today_secondary':
            data.dailySpending.budgetTodaySecondary == null
            ? null
            : {
                'amount': data.dailySpending.budgetTodaySecondary!.amount,
                'currency': _currencyToJsonMap(
                  data.dailySpending.budgetTodaySecondary!.currency,
                ),
              },
        'spent_today': data.dailySpending.spentToday,
        'remaining_today': data.dailySpending.remainingToday,
      },
      'totals_by_currency': data.totalsByCurrency
          .map(
            (e) => {
              'currency': _currencyToJsonMap(e.currency),
              'balance': e.balance,
              'income': e.income,
              'expense': e.expense,
            },
          )
          .toList(),
      'recent_transactions': data.recentTransactions
          .map((e) => _transactionToJsonMap(e))
          .toList(),
    };
  }

  // --- Analytics Cache ---

  Future<void> saveAnalytics(String key, AnalyticsData data) async {
    final db = await database;
    await db.insert('analytics_cache', {
      'key': key,
      'json_data': jsonEncode(_analyticsToJsonMap(data)),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AnalyticsData?> getAnalytics(String key) async {
    final db = await database;
    final res = await db.query(
      'analytics_cache',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (res.isEmpty) return null;
    return AnalyticsData.fromJson(jsonDecode(res.first['json_data'] as String));
  }

  Map<String, dynamic> _analyticsToJsonMap(AnalyticsData data) {
    return {
      'reporting_currency': _currencyToJsonMap(data.reportingCurrency),
      'combined_totals': {
        'balance': data.totals.balance,
        'income': data.totals.income,
        'expense': data.totals.expense,
      },
      'totals_by_category': data.byCategory
          .map(
            (e) => {
              'category_name': e.categoryName,
              'balance': e.balance,
              'income': e.income,
              'expense': e.expense,
            },
          )
          .toList(),
      'monthly_trend': data.monthlyTrend
          .map(
            (e) => {
              'month': e.month,
              'balance': e.balance,
              'income': e.income,
              'expense': e.expense,
            },
          )
          .toList(),
    };
  }

  // --- Outbox Queue ---

  Future<void> queueOperation(
    String methodName,
    Map<String, dynamic> arguments,
  ) async {
    final db = await database;
    await db.insert('pending_operations', {
      'method_name': methodName,
      'arguments_json': jsonEncode(arguments),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query('pending_operations', orderBy: 'id ASC');
  }

  Future<int> pendingOperationCount() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_operations',
    );
    return res.first['count'] as int? ?? 0;
  }

  Future<void> deletePendingOperation(int id) async {
    final db = await database;
    await db.delete('pending_operations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePendingOperationArguments(int tempId, int realId) async {
    final db = await database;
    final operations = await db.query('pending_operations');
    for (final op in operations) {
      final argumentsJson = op['arguments_json'] as String;
      if (argumentsJson.contains('$tempId')) {
        final Map<String, dynamic> map = jsonDecode(argumentsJson);
        final updatedMap = _replaceIdInMap(map, tempId, realId);
        await db.update(
          'pending_operations',
          {'arguments_json': jsonEncode(updatedMap)},
          where: 'id = ?',
          whereArgs: [op['id']],
        );
      }
    }
  }

  Map<String, dynamic> _replaceIdInMap(
    Map<String, dynamic> map,
    int tempId,
    int realId,
  ) {
    final Map<String, dynamic> result = {};
    for (final entry in map.entries) {
      final value = entry.value;
      if (value == tempId &&
          (entry.key.endsWith('_id') ||
              entry.key == 'id' ||
              entry.key == 'categoryId' ||
              entry.key == 'walletId' ||
              entry.key == 'sourceWalletId' ||
              entry.key == 'destinationWalletId')) {
        result[entry.key] = realId;
      } else if (value is Map<String, dynamic>) {
        result[entry.key] = _replaceIdInMap(value, tempId, realId);
      } else if (value is List) {
        result[entry.key] = value.map((item) {
          if (item == tempId) {
            return realId;
          }
          if (item is Map<String, dynamic>) {
            return _replaceIdInMap(item, tempId, realId);
          }
          return item;
        }).toList();
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  Future<void> resolveTemporaryId(
    String tableName,
    int tempId,
    int realId,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate('UPDATE $tableName SET id = ? WHERE id = ?', [
        realId,
        tempId,
      ]);

      if (tableName == 'categories') {
        await txn.rawUpdate(
          'UPDATE transactions SET category_id = ? WHERE category_id = ?',
          [realId, tempId],
        );
      } else if (tableName == 'wallets') {
        await txn.rawUpdate(
          'UPDATE transactions SET wallet_id = ? WHERE wallet_id = ?',
          [realId, tempId],
        );
        await txn.rawUpdate(
          'UPDATE goal_contributions SET transaction_id = ? WHERE transaction_id = ?',
          [realId, tempId],
        );
      } else if (tableName == 'goals') {
        await txn.rawUpdate(
          'UPDATE goal_contributions SET goal_id = ? WHERE goal_id = ?',
          [realId, tempId],
        );
      } else if (tableName == 'transactions') {
        await txn.rawUpdate(
          'UPDATE goal_contributions SET transaction_id = ? WHERE transaction_id = ?',
          [realId, tempId],
        );
      }
    });

    await updatePendingOperationArguments(tempId, realId);
  }

  // --- Offline Mutations ---

  Future<int> getNextTempId(String tableName) async {
    final db = await database;
    final res = await db.rawQuery('SELECT MIN(id) as min_id FROM $tableName');
    final minId = res.first['min_id'] as int?;
    if (minId == null || minId >= 0) return -1;
    return minId - 1;
  }

  Future<TransactionRecord> createTransactionLocally({
    required int categoryId,
    required int walletId,
    required String type,
    required String amount,
    required DateTime occurredOn,
    String? note,
    List<String> invoiceImageUrls = const [],
  }) async {
    final db = await database;
    final tempId = await getNextTempId('transactions');

    final category = await getCategory(categoryId);
    final wallet = await getWallet(walletId);
    if (wallet == null) throw Exception('Wallet not found');

    final double currentBalance = double.tryParse(wallet.balance) ?? 0;
    final double txAmount = double.tryParse(amount) ?? 0;
    double newBalance = currentBalance;
    if (type == 'incoming') {
      newBalance += txAmount;
    } else {
      newBalance -= txAmount;
    }

    await db.update(
      'wallets',
      {'balance': newBalance.toStringAsFixed(4)},
      where: 'id = ?',
      whereArgs: [walletId],
    );

    final newTx = TransactionRecord(
      id: tempId,
      type: type,
      amount: amount,
      note: note,
      occurredOn: occurredOn,
      convertedAmount: amount,
      category: category,
      wallet: await getWallet(walletId),
      currency: wallet.currency,
      reportingCurrency: wallet.currency,
      invoiceImageUrls: invoiceImageUrls,
    );

    await saveTransactions([newTx]);

    final dashboard = await getDashboard();
    if (dashboard != null) {
      final double oldTotalBalance = double.tryParse(dashboard.balance) ?? 0;
      final double oldTotalIncome = double.tryParse(dashboard.income) ?? 0;
      final double oldTotalExpense = double.tryParse(dashboard.expense) ?? 0;

      double newTotalBalance = oldTotalBalance;
      double newTotalIncome = oldTotalIncome;
      double newTotalExpense = oldTotalExpense;

      if (type == 'incoming') {
        newTotalBalance += txAmount;
        newTotalIncome += txAmount;
      } else {
        newTotalBalance -= txAmount;
        newTotalExpense += txAmount;
      }

      final recent = List<TransactionRecord>.from(dashboard.recentTransactions);
      recent.insert(0, newTx);
      if (recent.length > 10) recent.removeLast();

      final double spent =
          double.tryParse(dashboard.dailySpending.spentToday) ?? 0;
      double newSpent = spent;
      if (occurredOn.day == DateTime.now().day &&
          occurredOn.month == DateTime.now().month &&
          occurredOn.year == DateTime.now().year) {
        if (type == 'outgoing') {
          newSpent += txAmount;
        }
      }

      final double newBudget = dashboard.dailySpending.daysUntilMonthEnd > 0
          ? ((newTotalBalance + newSpent) /
                dashboard.dailySpending.daysUntilMonthEnd)
          : newTotalBalance;
      final double newRemaining = newBudget - newSpent;

      final updatedDashboard = DashboardData(
        reportingCurrency: dashboard.reportingCurrency,
        balance: newTotalBalance.toStringAsFixed(4),
        income: newTotalIncome.toStringAsFixed(4),
        expense: newTotalExpense.toStringAsFixed(4),
        dailySpending: DailySpending(
          asOfDate: dashboard.dailySpending.asOfDate,
          daysUntilMonthEnd: dashboard.dailySpending.daysUntilMonthEnd,
          budgetToday: newBudget.toStringAsFixed(4),
          budgetTodaySecondary: dashboard.dailySpending.budgetTodaySecondary,
          spentToday: newSpent.toStringAsFixed(4),
          remainingToday: newRemaining.toStringAsFixed(4),
        ),
        totalsByCurrency: dashboard.totalsByCurrency,
        recentTransactions: recent,
      );

      await saveDashboard(updatedDashboard);
    }

    return newTx;
  }

  Future<Wallet> createWalletLocally({
    required int currencyId,
    String? name,
    String? balance,
    bool isDefault = false,
  }) async {
    final db = await database;
    final tempId = await getNextTempId('wallets');
    final currency = await getCurrency(currencyId);
    if (currency == null) throw Exception('Currency not found');

    if (isDefault) {
      await db.update('wallets', {'is_default': 0});
    }

    final newWallet = Wallet(
      id: tempId,
      name: name ?? currency.name,
      balance: balance ?? '0',
      isDefault: isDefault,
      currency: currency,
    );

    await db.insert('wallets', {
      'id': tempId,
      'name': newWallet.name,
      'balance': newWallet.balance,
      'is_default': isDefault ? 1 : 0,
      'currency_id': currencyId,
    });

    return newWallet;
  }

  Future<Wallet> updateWalletLocally({
    required int id,
    String? name,
    String? balance,
    bool? isDefault,
  }) async {
    final db = await database;
    final wallet = await getWallet(id);
    if (wallet == null) throw Exception('Wallet not found');

    if (isDefault == true) {
      await db.update('wallets', {'is_default': 0});
    }

    await db.update(
      'wallets',
      {
        'name': ?name,
        'balance': ?balance,
        if (isDefault != null) 'is_default': isDefault ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return (await getWallet(id))!;
  }

  Future<Category> createCategoryLocally({
    required String name,
    String? color,
    String? icon,
  }) async {
    final db = await database;
    final tempId = await getNextTempId('categories');
    final newCat = Category(
      id: tempId,
      name: name,
      color: color,
      icon: icon,
      isArchived: false,
    );
    await db.insert('categories', {
      'id': tempId,
      'name': name,
      'color': color,
      'icon': icon,
      'is_archived': 0,
    });
    return newCat;
  }

  Future<void> deleteCategoryLocally(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<Goal> createGoalLocally({
    required String name,
    required int currencyId,
    required String targetAmount,
    String? note,
  }) async {
    final db = await database;
    final tempId = await getNextTempId('goals');
    final currency = await getCurrency(currencyId);
    if (currency == null) throw Exception('Currency not found');

    final newGoal = Goal(
      id: tempId,
      name: name,
      targetAmount: targetAmount,
      currentAmount: '0',
      remainingAmount: targetAmount,
      progress: 0.0,
      contributionsCount: 0,
      recentContributions: [],
      note: note,
      currency: currency,
    );

    await db.insert('goals', {
      'id': tempId,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': '0',
      'remaining_amount': targetAmount,
      'progress': 0.0,
      'contributions_count': 0,
      'note': note,
      'completed_at': null,
      'currency_id': currencyId,
    });

    return newGoal;
  }

  Future<Goal> contributeToGoalLocally({
    required int goalId,
    required int walletId,
    required String amount,
    required DateTime occurredOn,
    String? note,
  }) async {
    final db = await database;
    final goalsList = await getGoals();
    final goal = goalsList.firstWhere((e) => e.id == goalId);
    final wallet = await getWallet(walletId);
    if (wallet == null) throw Exception('Wallet not found');

    final tx = await createTransactionLocally(
      categoryId: -1,
      walletId: walletId,
      type: 'outgoing',
      amount: amount,
      occurredOn: occurredOn,
      note: 'Goal Contribution: ${goal.name}. ${note ?? ""}',
    );

    final tempContribId = await getNextTempId('goal_contributions');
    await db.insert('goal_contributions', {
      'id': tempContribId,
      'goal_id': goalId,
      'amount': amount,
      'occurred_on': occurredOn.toIso8601String(),
      'transaction_id': tx.id,
    });

    final double currentVal = double.tryParse(goal.currentAmount) ?? 0;
    final double contribVal = double.tryParse(amount) ?? 0;
    final double targetVal = double.tryParse(goal.targetAmount) ?? 0;
    final double newVal = currentVal + contribVal;
    final double remaining = targetVal - newVal;
    final double progress = targetVal > 0
        ? (newVal / targetVal).clamp(0.0, 1.0)
        : 1.0;
    final DateTime? completedAt = progress >= 1.0 ? DateTime.now() : null;

    await db.update(
      'goals',
      {
        'current_amount': newVal.toStringAsFixed(4),
        'remaining_amount': remaining.toStringAsFixed(4),
        'progress': progress,
        'contributions_count': goal.contributionsCount + 1,
        'completed_at': completedAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );

    final refreshedGoals = await getGoals();
    return refreshedGoals.firstWhere((e) => e.id == goalId);
  }

  Future<List<TransactionRecord>> convertWalletMoneyLocally({
    required int sourceWalletId,
    required int destinationWalletId,
    required String sourceAmount,
    required String destinationAmount,
    required DateTime occurredOn,
    String? note,
  }) async {
    final sourceTransaction = await createTransactionLocally(
      categoryId: -1,
      walletId: sourceWalletId,
      type: 'outgoing',
      amount: sourceAmount,
      occurredOn: occurredOn,
      note: 'Convert Money (Out): ${note ?? ""}',
    );

    final destinationTransaction = await createTransactionLocally(
      categoryId: -1,
      walletId: destinationWalletId,
      type: 'incoming',
      amount: destinationAmount,
      occurredOn: occurredOn,
      note: 'Convert Money (In): ${note ?? ""}',
    );

    return [sourceTransaction, destinationTransaction];
  }

  Future<void> deleteTransactionLocally(int id) async {
    final db = await database;
    final tx = await getTransaction(id);
    if (tx == null) return;

    if (tx.wallet != null) {
      final double txAmount = double.tryParse(tx.amount) ?? 0;
      final double currentBalance = double.tryParse(tx.wallet!.balance) ?? 0;
      double newBalance = currentBalance;
      if (tx.type == 'incoming') {
        newBalance -= txAmount;
      } else {
        newBalance += txAmount;
      }

      await db.update(
        'wallets',
        {'balance': newBalance.toStringAsFixed(4)},
        where: 'id = ?',
        whereArgs: [tx.wallet!.id],
      );
    }

    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);

    final dashboard = await getDashboard();
    if (dashboard != null) {
      final recent = List<TransactionRecord>.from(dashboard.recentTransactions);
      recent.removeWhere((e) => e.id == id);

      final double txAmount = double.tryParse(tx.amount) ?? 0;
      double newTotalBalance = double.tryParse(dashboard.balance) ?? 0;
      double newTotalIncome = double.tryParse(dashboard.income) ?? 0;
      double newTotalExpense = double.tryParse(dashboard.expense) ?? 0;

      if (tx.type == 'incoming') {
        newTotalBalance -= txAmount;
        newTotalIncome -= txAmount;
      } else {
        newTotalBalance += txAmount;
        newTotalExpense -= txAmount;
      }

      final double spent =
          double.tryParse(dashboard.dailySpending.spentToday) ?? 0;
      double newSpent = spent;
      if (tx.occurredOn != null &&
          tx.occurredOn!.day == DateTime.now().day &&
          tx.occurredOn!.month == DateTime.now().month &&
          tx.occurredOn!.year == DateTime.now().year) {
        if (tx.type == 'outgoing') {
          newSpent -= txAmount;
        }
      }

      final double newBudget = dashboard.dailySpending.daysUntilMonthEnd > 0
          ? ((newTotalBalance + newSpent) /
                dashboard.dailySpending.daysUntilMonthEnd)
          : newTotalBalance;
      final double newRemaining = newBudget - newSpent;

      await saveDashboard(
        DashboardData(
          reportingCurrency: dashboard.reportingCurrency,
          balance: newTotalBalance.toStringAsFixed(4),
          income: newTotalIncome.toStringAsFixed(4),
          expense: newTotalExpense.toStringAsFixed(4),
          dailySpending: DailySpending(
            asOfDate: dashboard.dailySpending.asOfDate,
            daysUntilMonthEnd: dashboard.dailySpending.daysUntilMonthEnd,
            budgetToday: newBudget.toStringAsFixed(4),
            budgetTodaySecondary: dashboard.dailySpending.budgetTodaySecondary,
            spentToday: newSpent.toStringAsFixed(4),
            remainingToday: newRemaining.toStringAsFixed(4),
          ),
          totalsByCurrency: dashboard.totalsByCurrency,
          recentTransactions: recent,
        ),
      );
    }
  }
}

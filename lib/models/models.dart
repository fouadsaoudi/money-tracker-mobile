import '../core/helpers.dart';

class AuthResult {
  AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: '${json['token']}',
      user: UserProfile.fromJson(asMap(json['user'])),
    );
  }

  final String token;
  final UserProfile user;
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.reportingCurrency,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: asInt(json['id']),
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      reportingCurrency: json['reporting_currency'] == null
          ? null
          : Currency.fromJson(asMap(json['reporting_currency'])),
    );
  }

  final int id;
  final String name;
  final String email;
  final Currency? reportingCurrency;
}

class Currency {
  Currency({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimalPlaces,
    required this.isActive,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      id: asInt(json['id']),
      code: '${json['code'] ?? ''}',
      name: '${json['name'] ?? ''}',
      symbol: '${json['symbol'] ?? ''}',
      decimalPlaces: asInt(json['decimal_places']),
      isActive: json['is_active'] == true,
    );
  }

  final int id;
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final bool isActive;
}

class Category {
  Category({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    required this.isArchived,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: asInt(json['id']),
      name: '${json['name'] ?? ''}',
      color: json['color'] == null ? null : '${json['color']}',
      icon: json['icon'] == null ? null : '${json['icon']}',
      isArchived: json['is_archived'] == true,
    );
  }

  final int id;
  final String name;
  final String? color;
  final String? icon;
  final bool isArchived;
}

class Wallet {
  Wallet({
    required this.id,
    required this.name,
    required this.balance,
    required this.isDefault,
    required this.currency,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: asInt(json['id']),
      name: '${json['name'] ?? ''}',
      balance: '${json['balance'] ?? '0'}',
      isDefault: json['is_default'] == true,
      currency: Currency.fromJson(asMap(json['currency'])),
    );
  }

  final int id;
  final String name;
  final String balance;
  final bool isDefault;
  final Currency currency;
}

class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.remainingAmount,
    required this.progress,
    required this.contributionsCount,
    required this.recentContributions,
    this.note,
    this.completedAt,
    required this.currency,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: asInt(json['id']),
      name: '${json['name'] ?? ''}',
      targetAmount: '${json['target_amount'] ?? '0'}',
      currentAmount: '${json['current_amount'] ?? '0'}',
      remainingAmount: '${json['remaining_amount'] ?? '0'}',
      progress: double.tryParse('${json['progress'] ?? '0'}') ?? 0,
      contributionsCount: asInt(json['contributions_count']),
      recentContributions: asList(
        json['recent_contributions'],
      ).map((item) => GoalContribution.fromJson(asMap(item))).toList(),
      note: json['note'] == null ? null : '${json['note']}',
      completedAt: DateTime.tryParse('${json['completed_at'] ?? ''}'),
      currency: Currency.fromJson(asMap(json['currency'])),
    );
  }

  final int id;
  final String name;
  final String targetAmount;
  final String currentAmount;
  final String remainingAmount;
  final double progress;
  final int contributionsCount;
  final List<GoalContribution> recentContributions;
  final String? note;
  final DateTime? completedAt;
  final Currency currency;
}

class GoalContribution {
  GoalContribution({
    required this.id,
    required this.amount,
    this.occurredOn,
    this.transaction,
  });

  factory GoalContribution.fromJson(Map<String, dynamic> json) {
    return GoalContribution(
      id: asInt(json['id']),
      amount: '${json['amount'] ?? '0'}',
      occurredOn: DateTime.tryParse('${json['occurred_on'] ?? ''}'),
      transaction: json['transaction'] == null
          ? null
          : TransactionRecord.fromJson(asMap(json['transaction'])),
    );
  }

  final int id;
  final String amount;
  final DateTime? occurredOn;
  final TransactionRecord? transaction;
}

class TransactionRecord {
  TransactionRecord({
    required this.id,
    required this.type,
    required this.amount,
    this.note,
    this.occurredOn,
    required this.convertedAmount,
    this.category,
    this.wallet,
    this.currency,
    this.reportingCurrency,
    this.invoiceImages = const [],
    this.invoiceImageUrls = const [],
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: asInt(json['id']),
      type: '${json['type'] ?? ''}',
      amount: '${json['amount'] ?? '0'}',
      note: json['note'] == null ? null : '${json['note']}',
      occurredOn: DateTime.tryParse('${json['occurred_on'] ?? ''}'),
      convertedAmount: '${json['converted_amount'] ?? '0'}',
      category: json['category'] == null
          ? null
          : Category.fromJson(asMap(json['category'])),
      wallet: json['wallet'] == null
          ? null
          : Wallet.fromJson(asMap(json['wallet'])),
      currency: json['currency'] == null
          ? null
          : Currency.fromJson(asMap(json['currency'])),
      reportingCurrency: json['reporting_currency'] == null
          ? null
          : Currency.fromJson(asMap(json['reporting_currency'])),
      invoiceImages: asList(
        json['invoice_images'],
      ).map((item) => TransactionInvoiceImage.fromJson(asMap(item))).toList(),
      invoiceImageUrls: [
        ...asList(json['invoice_image_urls']).map((item) => '$item'),
        if (json['invoice_image_urls'] == null &&
            json['invoice_image_url'] != null)
          '${json['invoice_image_url']}',
      ],
    );
  }

  final int id;
  final String type;
  final String amount;
  final String? note;
  final DateTime? occurredOn;
  final String convertedAmount;
  final Category? category;
  final Wallet? wallet;
  final Currency? currency;
  final Currency? reportingCurrency;
  final List<TransactionInvoiceImage> invoiceImages;
  final List<String> invoiceImageUrls;
}

class TransactionInvoiceImage {
  TransactionInvoiceImage({required this.id, required this.url});

  factory TransactionInvoiceImage.fromJson(Map<String, dynamic> json) {
    return TransactionInvoiceImage(
      id: asInt(json['id']),
      url: '${json['url'] ?? ''}',
    );
  }

  final int id;
  final String url;
}

class PagedTransactions {
  PagedTransactions({
    required this.data,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    this.servedLocally = false,
  });

  factory PagedTransactions.fromJson(Map<String, dynamic> json) {
    final meta = asMap(json['meta']);
    return PagedTransactions(
      data: asList(
        json['data'],
      ).map((item) => TransactionRecord.fromJson(asMap(item))).toList(),
      total: asInt(meta['total']),
      currentPage: asInt(meta['current_page']),
      lastPage: asInt(meta['last_page']),
    );
  }

  final List<TransactionRecord> data;
  final int total;
  final int currentPage;
  final int lastPage;
  final bool servedLocally;

  bool get hasMore => currentPage < lastPage;
}

class DashboardData {
  DashboardData({
    required this.reportingCurrency,
    required this.balance,
    required this.income,
    required this.expense,
    required this.dailySpending,
    required this.totalsByCurrency,
    required this.recentTransactions,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      reportingCurrency: Currency.fromJson(asMap(json['reporting_currency'])),
      balance: '${json['combined_balance'] ?? '0'}',
      income: '${json['combined_income'] ?? '0'}',
      expense: '${json['combined_expense'] ?? '0'}',
      dailySpending: DailySpending.fromJson(asMap(json['daily_spending'])),
      totalsByCurrency: asList(
        json['totals_by_currency'],
      ).map((item) => CurrencyTotal.fromJson(asMap(item))).toList(),
      recentTransactions: asList(
        json['recent_transactions'],
      ).map((item) => TransactionRecord.fromJson(asMap(item))).toList(),
    );
  }

  final Currency reportingCurrency;
  final String balance;
  final String income;
  final String expense;
  final DailySpending dailySpending;
  final List<CurrencyTotal> totalsByCurrency;
  final List<TransactionRecord> recentTransactions;
}

class DailySpending {
  DailySpending({
    required this.daysUntilMonthEnd,
    required this.budgetToday,
    this.budgetTodaySecondary,
    required this.spentToday,
    required this.remainingToday,
  });

  factory DailySpending.fromJson(Map<String, dynamic> json) {
    return DailySpending(
      daysUntilMonthEnd: asInt(json['days_until_month_end']),
      budgetToday: '${json['budget_today'] ?? '0'}',
      budgetTodaySecondary: json['budget_today_secondary'] == null
          ? null
          : ConvertedMoney.fromJson(asMap(json['budget_today_secondary'])),
      spentToday: '${json['spent_today'] ?? '0'}',
      remainingToday: '${json['remaining_today'] ?? '0'}',
    );
  }

  final int daysUntilMonthEnd;
  final String budgetToday;
  final ConvertedMoney? budgetTodaySecondary;
  final String spentToday;
  final String remainingToday;
}

class ConvertedMoney {
  ConvertedMoney({required this.amount, required this.currency});

  factory ConvertedMoney.fromJson(Map<String, dynamic> json) {
    return ConvertedMoney(
      amount: '${json['amount'] ?? '0'}',
      currency: Currency.fromJson(asMap(json['currency'])),
    );
  }

  final String amount;
  final Currency currency;
}

class CurrencyTotal {
  CurrencyTotal({
    required this.currency,
    required this.balance,
    required this.income,
    required this.expense,
  });

  factory CurrencyTotal.fromJson(Map<String, dynamic> json) {
    return CurrencyTotal(
      currency: Currency.fromJson(asMap(json['currency'])),
      balance: '${json['balance'] ?? '0'}',
      income: '${json['income'] ?? '0'}',
      expense: '${json['expense'] ?? '0'}',
    );
  }

  final Currency currency;
  final String balance;
  final String income;
  final String expense;
}

class AnalyticsData {
  AnalyticsData({
    required this.reportingCurrency,
    required this.totals,
    required this.byCategory,
    required this.monthlyTrend,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      reportingCurrency: Currency.fromJson(asMap(json['reporting_currency'])),
      totals: CombinedTotals.fromJson(asMap(json['combined_totals'])),
      byCategory: asList(
        json['totals_by_category'],
      ).map((item) => CategoryTotal.fromJson(asMap(item))).toList(),
      monthlyTrend: asList(
        json['monthly_trend'],
      ).map((item) => MonthTotal.fromJson(asMap(item))).toList(),
    );
  }

  final Currency reportingCurrency;
  final CombinedTotals totals;
  final List<CategoryTotal> byCategory;
  final List<MonthTotal> monthlyTrend;
}

class CombinedTotals {
  CombinedTotals({
    required this.balance,
    required this.income,
    required this.expense,
  });

  factory CombinedTotals.fromJson(Map<String, dynamic> json) {
    return CombinedTotals(
      balance: '${json['balance'] ?? '0'}',
      income: '${json['income'] ?? '0'}',
      expense: '${json['expense'] ?? '0'}',
    );
  }

  final String balance;
  final String income;
  final String expense;
}

class CategoryTotal extends CombinedTotals {
  CategoryTotal({
    required this.categoryName,
    required super.balance,
    required super.income,
    required super.expense,
  });

  factory CategoryTotal.fromJson(Map<String, dynamic> json) {
    return CategoryTotal(
      categoryName: '${json['category_name'] ?? 'Uncategorized'}',
      balance: '${json['balance'] ?? '0'}',
      income: '${json['income'] ?? '0'}',
      expense: '${json['expense'] ?? '0'}',
    );
  }

  final String categoryName;
}

class MonthTotal extends CombinedTotals {
  MonthTotal({
    required this.month,
    required super.balance,
    required super.income,
    required super.expense,
  });

  factory MonthTotal.fromJson(Map<String, dynamic> json) {
    return MonthTotal(
      month: '${json['month'] ?? ''}',
      balance: '${json['balance'] ?? '0'}',
      income: '${json['income'] ?? '0'}',
      expense: '${json['expense'] ?? '0'}',
    );
  }

  final String month;
}

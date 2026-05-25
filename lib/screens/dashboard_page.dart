import 'dart:async';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/app_session.dart';
import '../core/helpers.dart';
import '../core/shared_widgets.dart';
import '../models/models.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.session});

  static const routeName = '/dashboard';

  final AppSession session;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardBundle> future = load();

  Future<DashboardBundle> load() async {
    final results = await Future.wait([
      widget.session.api.dashboard(),
      widget.session.api.wallets(),
      widget.session.api.currencies(),
    ]);

    return DashboardBundle(
      dashboard: results[0] as DashboardData,
      wallets: results[1] as List<Wallet>,
      currencies: results[2] as List<Currency>,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() {
      future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      onRefresh: refresh,
      child: FutureBuilder<DashboardBundle>(
        future: future,
        builder: (context, snapshot) {
          return AppPage(
            title: 'Dashboard',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Add wallet',
                  onPressed: snapshot.hasData
                      ? () => addWallet(snapshot.requireData)
                      : null,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                RefreshActionButton(onPressed: refresh),
              ],
            ),
            child: AsyncBody(
              snapshot: snapshot,
              builder: (bundle) {
                final dashboard = bundle.dashboard;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    ActivityHero(dashboard: dashboard),
                    const SizedBox(height: 8),
                    DailySpendingCards(
                      dashboard: dashboard,
                      onRefresh: refresh,
                    ),
                    const SizedBox(height: 16),
                    SurfacePanel(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: DashboardSectionTitle(
                                  title: 'Wallet balances',
                                ),
                              ),
                            ],
                          ),
                          if (bundle.wallets.isEmpty)
                            const EmptyState(text: 'No wallets yet.'),
                          ...bundle.wallets.map(
                            (wallet) => WalletTile(
                              wallet,
                              onTap: () => editWallet(bundle, wallet),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SurfacePanel(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DashboardSectionTitle(
                            title: 'Activity by currency',
                          ),
                          if (dashboard.totalsByCurrency.isEmpty)
                            const EmptyState(text: 'No activity totals yet.'),
                          ...dashboard.totalsByCurrency.map(
                            (total) => CurrencyTotalTile(total: total),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SurfacePanel(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DashboardSectionTitle(
                            title: 'Recent transactions',
                          ),
                          if (dashboard.recentTransactions.isEmpty)
                            const EmptyState(text: 'No transactions yet.'),
                          ...dashboard.recentTransactions
                              .take(4)
                              .map(CompactTransactionTile.new),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> addWallet(DashboardBundle bundle) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => WalletDialog(session: widget.session, bundle: bundle),
    );

    if (created == true) {
      await refresh();
    }
  }

  Future<void> editWallet(DashboardBundle bundle, Wallet wallet) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => EditWalletDialog(session: widget.session, wallet: wallet),
    );

    if (updated == true) {
      await refresh();
    }
  }
}

class DashboardBundle {
  DashboardBundle({
    required this.dashboard,
    required this.wallets,
    required this.currencies,
  });

  final DashboardData dashboard;
  final List<Wallet> wallets;
  final List<Currency> currencies;
}

class DashboardSectionTitle extends StatelessWidget {
  const DashboardSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.ink.withValues(alpha: 0.8),
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class ActivityHero extends StatelessWidget {
  const ActivityHero({super.key, required this.dashboard});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff115e59), Color(0xff0f766e), Color(0xff14b8a6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0f766e).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet balance',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      money(dashboard.balance, dashboard.reportingCurrency),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    HeroPill(
                      icon: Icons.trending_up_rounded,
                      label: 'In',
                      value: money(
                        dashboard.income,
                        dashboard.reportingCurrency,
                      ),
                      color: const Color(0xFF6EE7B7),
                    ),
                    HeroPill(
                      icon: Icons.trending_down_rounded,
                      label: 'Out',
                      value: money(
                        dashboard.expense,
                        dashboard.reportingCurrency,
                      ),
                      color: const Color(0xFFFCA5A5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeroPill extends StatelessWidget {
  const HeroPill({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Center(
              child: Text(
                '$label $value',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DailySpendingCards extends StatelessWidget {
  const DailySpendingCards({
    super.key,
    required this.dashboard,
    this.onRefresh,
  });

  final DashboardData dashboard;
  final FutureOr<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final dailySpending = dashboard.dailySpending;
    final secondaryBudget = dailySpending.budgetTodaySecondary;
    final daysLeftText = '${dailySpending.daysUntilMonthEnd} days left in month';
    final budgetDetail = secondaryBudget == null
        ? 'You have a total of ${money(dailySpending.budgetToday, dashboard.reportingCurrency)} to spend today ($daysLeftText)'
        : '${money(dailySpending.budgetToday, dashboard.reportingCurrency)} = ${money(secondaryBudget.amount, secondaryBudget.currency)} today ($daysLeftText)';
    final remainingToday = double.tryParse(dailySpending.remainingToday) ?? 0;
    final remainingText = money(
      remainingToday < 0
          ? (-remainingToday).toString()
          : dailySpending.remainingToday,
      dashboard.reportingCurrency,
    );
    final isOverBudget = remainingToday < 0;
    final remainingDetail = remainingToday < 0
        ? 'Stop spending! You are -$remainingText over daily budget'
        : 'You have $remainingText more to spend today';

    final budgetCard = DailySpendingCard(
      icon: Icons.today_rounded,
      title: 'Daily budget',
      value: money(
        dailySpending.budgetToday,
        dashboard.reportingCurrency,
      ),
      detail: budgetDetail,
      color: AppColors.teal,
      onRefresh: onRefresh,
      dashboard: dashboard,
    );

    final spentCard = DailySpendingCard(
      icon: Icons.shopping_bag_rounded,
      title: 'Spent today',
      value: money(
        dailySpending.spentToday,
        dashboard.reportingCurrency,
      ),
      detail: 'Total amount spent today',
      color: AppColors.rose,
    );

    final remainingCard = DailySpendingCard(
      icon: Icons.savings_rounded,
      title: 'How much left',
      value: isOverBudget ? '-$remainingText' : remainingText,
      detail: remainingDetail,
      color: isOverBudget ? AppColors.rose : AppColors.green,
      valueColor: isOverBudget ? AppColors.rose : null,
    );

    final isWide = MediaQuery.sizeOf(context).width >= 720;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: budgetCard),
          const SizedBox(width: 12),
          Expanded(child: spentCard),
          const SizedBox(width: 12),
          Expanded(child: remainingCard),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: budgetCard),
              const SizedBox(width: 12),
              Expanded(child: spentCard),
            ],
          ),
          const SizedBox(height: 12),
          remainingCard,
        ],
      );
    }
  }
}

class DailySpendingCard extends StatelessWidget {
  const DailySpendingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
    this.valueColor,
    this.onRefresh,
    this.dashboard,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color color;
  final Color? valueColor;
  final FutureOr<void> Function()? onRefresh;
  final DashboardData? dashboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 124),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onRefresh != null && dashboard != null) ...[
                const SizedBox(width: 8),
                _SmallRefreshButton(
                  onPressed: onRefresh!,
                  dashboard: dashboard!,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor ?? AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class WalletTile extends StatelessWidget {
  const WalletTile(this.wallet, {super.key, this.onTap});

  final Wallet wallet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: wallet.isDefault
              ? AppColors.teal.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: wallet.isDefault
                ? AppColors.teal.withValues(alpha: 0.4)
                : AppColors.border.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.teal.withValues(alpha: 0.15),
              foregroundColor: AppColors.teal,
              child: Text(
                wallet.currency.code,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        wallet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (wallet.isDefault) ...[
                        const SizedBox(width: 8),
                        const TypeBadge(type: 'default'),
                      ],
                    ],
                  ),
                  Text(
                    wallet.currency.name,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              money(wallet.balance, wallet.currency),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class WalletDialog extends StatefulWidget {
  const WalletDialog({super.key, required this.session, required this.bundle});

  final AppSession session;
  final DashboardBundle bundle;

  @override
  State<WalletDialog> createState() => _WalletDialogState();
}

class _WalletDialogState extends State<WalletDialog> {
  final name = TextEditingController();
  final balance = TextEditingController(text: '0');
  int? currencyId;
  bool isDefault = false;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final existingCurrencyIds = widget.bundle.wallets
        .map((wallet) => wallet.currency.id)
        .toSet();
    final available = widget.bundle.currencies
        .where((currency) => !existingCurrencyIds.contains(currency.id))
        .toList();
    currencyId = available.isEmpty ? null : available.first.id;
  }

  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingCurrencyIds = widget.bundle.wallets
        .map((wallet) => wallet.currency.id)
        .toSet();
    final available = widget.bundle.currencies
        .where((currency) => !existingCurrencyIds.contains(currency.id))
        .toList();

    return AlertDialog(
      title: const Text('New wallet'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (available.isEmpty)
              const EmptyState(
                text: 'You already have wallets for all currencies.',
              )
            else ...[
              DropdownButtonFormField<int>(
                initialValue: currencyId,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: available
                    .map(
                      (currency) => DropdownMenuItem(
                        value: currency.id,
                        child: Text('${currency.code} - ${currency.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => currencyId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Wallet name',
                  hintText: 'Leave empty to use currency name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Opening balance'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Make default wallet'),
                value: isDefault,
                onChanged: (value) => setState(() => isDefault = value),
              ),
            ],
            if (error != null) MessageBanner(text: error!, isError: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy || available.isEmpty ? null : save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> save() async {
    if (currencyId == null) return;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await widget.session.api.createWallet(
        currencyId: currencyId!,
        name: name.text.trim().isEmpty ? null : name.text.trim(),
        balance: balance.text.trim().isEmpty ? '0' : balance.text.trim(),
        isDefault: isDefault,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class EditWalletDialog extends StatefulWidget {
  const EditWalletDialog({
    super.key,
    required this.session,
    required this.wallet,
  });

  final AppSession session;
  final Wallet wallet;

  @override
  State<EditWalletDialog> createState() => _EditWalletDialogState();
}

class _EditWalletDialogState extends State<EditWalletDialog> {
  late final TextEditingController name;
  late final TextEditingController balance;
  late bool isDefault;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.wallet.name);
    balance = TextEditingController(text: widget.wallet.balance);
    isDefault = widget.wallet.isDefault;
  }

  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit wallet'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: name,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Wallet name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balance,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: 'Current balance',
                suffixText: widget.wallet.currency.code,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Changing the balance creates a Wallet adjustment transaction for the difference.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Make default wallet'),
              value: isDefault,
              onChanged: busy
                  ? null
                  : (value) => setState(() => isDefault = value),
            ),
            if (error != null) MessageBanner(text: error!, isError: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });

    try {
      await widget.session.api.updateWallet(
        id: widget.wallet.id,
        name: name.text.trim(),
        balance: balance.text.trim(),
        isDefault: isDefault,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class CurrencyTotalTile extends StatelessWidget {
  const CurrencyTotalTile({super.key, required this.total});

  final CurrencyTotal total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.teal.withValues(alpha: 0.15),
            foregroundColor: AppColors.teal,
            child: Text(
              total.currency.code,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total.currency.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'In ${money(total.income, total.currency)}  •  Out ${money(total.expense, total.currency)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              money(total.balance, total.currency),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallRefreshButton extends StatefulWidget {
  const _SmallRefreshButton({
    required this.onPressed,
    required this.dashboard,
  });

  final FutureOr<void> Function() onPressed;
  final DashboardData dashboard;

  @override
  State<_SmallRefreshButton> createState() => _SmallRefreshButtonState();
}

class _SmallRefreshButtonState extends State<_SmallRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCalcRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13).merge(valueStyle)),
        ],
      ),
    );
  }

  Future<void> _handlePress() async {
    if (_isLoading) return;

    final double combinedBalance = double.tryParse(widget.dashboard.balance) ?? 0;
    final int days = widget.dashboard.dailySpending.daysUntilMonthEnd;
    final double budget = days > 0 ? (combinedBalance / days) : combinedBalance;
    final double spent = double.tryParse(widget.dashboard.dailySpending.spentToday) ?? 0;
    final double remaining = budget - spent;
    final currency = widget.dashboard.reportingCurrency;

    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.calculate_outlined, color: AppColors.teal),
              SizedBox(width: 10),
              Text('Budget Calculation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCalcRow('Net balance:', money(combinedBalance.toString(), currency)),
              _buildCalcRow('Days remaining:', '$days days'),
              const Divider(height: 20),
              _buildCalcRow(
                'Daily budget:',
                money(budget.toString(), currency),
                valueStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildCalcRow('Spent today:', '-${money(spent.toString(), currency)}'),
              const Divider(height: 20),
              _buildCalcRow(
                'Remaining today:',
                money(remaining.toString(), currency),
                valueStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: remaining < 0 ? AppColors.rose : AppColors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Would you like to refresh and update these calculations?',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Refresh'),
            ),
          ],
        );
      },
    );

    if (shouldRefresh != true) return;

    setState(() {
      _isLoading = true;
    });
    _controller.repeat();
    try {
      final res = widget.onPressed();
      if (res is Future) {
        await res;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        constraints: const BoxConstraints(),
        onPressed: _handlePress,
        icon: RotationTransition(
          turns: _controller,
          child: Icon(
            Icons.refresh_rounded,
            color: AppColors.muted.withValues(alpha: 0.8),
          ),
        ),
        tooltip: 'Refresh calculations',
      ),
    );
  }
}

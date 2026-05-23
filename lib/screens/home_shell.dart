import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_session.dart';
import '../core/shared_widgets.dart';
import '../models/models.dart';
import 'analytics_page.dart';
import 'categories_page.dart';
import 'dashboard_page.dart';
import 'goals_page.dart';
import 'settings_page.dart';
import 'transactions_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});

  final AppSession session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final navigatorKey = GlobalKey<NavigatorState>();
  int index = 0;
  String currentRoute = DashboardPage.routeName;
  bool addingTransaction = false;

  static const routes = [
    DashboardPage.routeName,
    TransactionsPage.routeName,
    AnalyticsPage.routeName,
    SettingsPage.routeName,
  ];

  void selectDestination(int value) {
    if (value == index && currentRoute == routes[value]) return;
    navigateToRoute(routes[value], index: value);
  }

  void navigateToRoute(String routeName, {int? index}) {
    if (index != null) {
      setState(() => this.index = index);
    }
    currentRoute = routeName;
    navigatorKey.currentState?.pushReplacementNamed(routeName);
  }

  void openCategories() {
    Navigator.pop(context);
    navigateToRoute(CategoriesPage.routeName);
  }

  void openGoals() {
    Navigator.pop(context);
    navigateToRoute(GoalsPage.routeName);
  }

  Future<void> addTransaction() async {
    if (addingTransaction) return;

    setState(() => addingTransaction = true);

    try {
      final results = await Future.wait([
        widget.session.api.transactions(),
        widget.session.api.categories(),
        widget.session.api.wallets(),
      ]);

      if (!mounted) return;

      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => TransactionForm(
          session: widget.session,
          bundle: TransactionsBundle(
            transactions: results[0] as PagedTransactions,
            categories: results[1] as List<Category>,
            wallets: results[2] as List<Wallet>,
          ),
        ),
      );

      if (created == true) {
        navigatorKey.currentState?.pushReplacementNamed(currentRoute);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open transaction form: $error')),
      );
    } finally {
      if (mounted) setState(() => addingTransaction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final navigator = Navigator(
      key: navigatorKey,
      initialRoute: DashboardPage.routeName,
      onGenerateRoute: routeFor,
    );

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Container(
                width: 224,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  extended: true,
                  selectedIndex: index,
                  onDestinationSelected: selectDestination,
                  groupAlignment: -0.72,
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Money Tracker',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.swap_vert),
                      label: Text('Transactions'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.query_stats),
                      label: Text('Analytics'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      label: Text('Settings'),
                    ),
                  ],
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AddTransactionSideButton(
                              onPressed: addingTransaction
                                  ? null
                                  : addTransaction,
                              busy: addingTransaction,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  navigateToRoute(GoalsPage.routeName),
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('Goals'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  navigateToRoute(CategoriesPage.routeName),
                              icon: const Icon(Icons.category_outlined),
                              label: const Text('Categories'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: navigator),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Money Tracker'),
                titleTextStyle: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Goals'),
                onTap: openGoals,
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Categories'),
                onTap: openCategories,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: navigator),
      bottomNavigationBar: MoneyBottomNavigation(
        selectedIndex: index,
        onDestinationSelected: selectDestination,
        onAddTransaction: addingTransaction ? null : addTransaction,
        addingTransaction: addingTransaction,
      ),
    );
  }

  Route<void> routeFor(RouteSettings settings) {
    final page = switch (settings.name) {
      TransactionsPage.routeName => TransactionsPage(session: widget.session),
      CategoriesPage.routeName => CategoriesPage(session: widget.session),
      GoalsPage.routeName => GoalsPage(session: widget.session),
      AnalyticsPage.routeName => AnalyticsPage(session: widget.session),
      SettingsPage.routeName => SettingsPage(session: widget.session),
      _ => DashboardPage(session: widget.session),
    };

    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }
}

class MoneyBottomNavigation extends StatelessWidget {
  const MoneyBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onAddTransaction,
    required this.addingTransaction,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onAddTransaction;
  final bool addingTransaction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 12,
      shadowColor: AppColors.ink.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: Container(
          height: 72,
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: BottomNavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onPressed: () => onDestinationSelected(0),
                ),
              ),
              Expanded(
                child: BottomNavItem(
                  icon: Icons.swap_vert,
                  label: 'Transactions',
                  selected: selectedIndex == 1,
                  onPressed: () => onDestinationSelected(1),
                ),
              ),
              Expanded(
                child: Center(
                  child: EmbeddedAddButton(
                    onPressed: onAddTransaction,
                    busy: addingTransaction,
                  ),
                ),
              ),
              Expanded(
                child: BottomNavItem(
                  icon: Icons.query_stats,
                  label: 'Stats',
                  selected: selectedIndex == 2,
                  onPressed: () => onDestinationSelected(2),
                ),
              ),
              Expanded(
                child: BottomNavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  selected: selectedIndex == 3,
                  onPressed: () => onDestinationSelected(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BottomNavItem extends StatelessWidget {
  const BottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teal : AppColors.muted;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.teal.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmbeddedAddButton extends StatelessWidget {
  const EmbeddedAddButton({
    super.key,
    required this.onPressed,
    required this.busy,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Tooltip(
      message: 'Add transaction',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: disabled ? 0.65 : 1,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.teal, Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.6),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Center(
                child: busy
                    ? const AppLoader(size: 28, color: Colors.white)
                    : const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AddTransactionSideButton extends StatelessWidget {
  const AddTransactionSideButton({
    super.key,
    required this.onPressed,
    required this.busy,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.teal, Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const AppLoader(size: 22, color: Colors.white)
              else
                const Icon(Icons.add, color: Colors.white, size: 21),
              const SizedBox(width: 8),
              Text(
                busy ? 'Opening...' : 'Add transaction',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

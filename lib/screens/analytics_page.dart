import 'package:flutter/material.dart';

import '../core/app_session.dart';
import '../core/helpers.dart';
import '../core/shared_widgets.dart';
import '../models/models.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.session});

  static const routeName = '/analytics';

  final AppSession session;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime? from;
  DateTime? to;
  int? categoryId;
  String type = '';
  late Future<AnalyticsBundle> future = load();
  bool _showAllCategories = false;

  Future<AnalyticsBundle> load() async {
    final results = await Future.wait([
      widget.session.api.analytics(
        from: from == null ? null : isoDate(from!),
        to: to == null ? null : isoDate(to!),
        categoryId: categoryId,
        type: type,
      ),
      widget.session.api.categories(),
    ]);
    return AnalyticsBundle(
      analytics: results[0] as AnalyticsData,
      categories: results[1] as List<Category>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyticsBundle>(
      future: future,
      builder: (context, snapshot) {
        return AppPage(
          title: 'Analytics',
          action: IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {
              _showAllCategories = false;
              future = load();
            }),
            icon: const Icon(Icons.refresh),
          ),
          child: AsyncBody(
            snapshot: snapshot,
            builder: (bundle) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                SurfacePanel(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => pickRange(true),
                        icon: const Icon(Icons.event),
                        label: Text(from == null ? 'From' : isoDate(from!)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => pickRange(false),
                        icon: const Icon(Icons.event_available),
                        label: Text(to == null ? 'To' : isoDate(to!)),
                      ),
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<int?>(
                          initialValue: categoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              child: Text('All categories'),
                            ),
                            ...bundle.categories.map(
                              (category) => DropdownMenuItem<int?>(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(() {
                            categoryId = value;
                            _showAllCategories = false;
                            future = load();
                          }),
                        ),
                      ),
                      FilterChip(
                        avatar: const Icon(Icons.arrow_downward),
                        label: const Text('Income'),
                        selected: type == 'incoming',
                        onSelected: (_) => setState(() {
                          type = type == 'incoming' ? '' : 'incoming';
                          _showAllCategories = false;
                          future = load();
                        }),
                      ),
                      FilterChip(
                        avatar: const Icon(Icons.arrow_upward),
                        label: const Text('Expense'),
                        selected: type == 'outgoing',
                        onSelected: (_) => setState(() {
                          type = type == 'outgoing' ? '' : 'outgoing';
                          _showAllCategories = false;
                          future = load();
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    MetricCard(
                      title: 'Balance',
                      value: money(
                        bundle.analytics.totals.balance,
                        bundle.analytics.reportingCurrency,
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    MetricCard(
                      title: 'Income',
                      value: money(
                        bundle.analytics.totals.income,
                        bundle.analytics.reportingCurrency,
                      ),
                      icon: Icons.trending_up,
                    ),
                    MetricCard(
                      title: 'Expense',
                      value: money(
                        bundle.analytics.totals.expense,
                        bundle.analytics.reportingCurrency,
                      ),
                      icon: Icons.trending_down,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SurfacePanel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'By category'),
                      if (bundle.analytics.byCategory.isEmpty)
                        const EmptyState(text: 'No category totals.')
                      else ...[
                        ...(_showAllCategories
                                ? bundle.analytics.byCategory
                                : bundle.analytics.byCategory.take(4))
                            .map(
                          (item) => SummaryRow(
                            title: item.categoryName,
                            subtitle:
                                'Income ${money(item.income, bundle.analytics.reportingCurrency)} · Expense ${money(item.expense, bundle.analytics.reportingCurrency)}',
                            value: money(
                              item.balance,
                              bundle.analytics.reportingCurrency,
                            ),
                            icon: Icons.category_outlined,
                          ),
                        ),
                        if (bundle.analytics.byCategory.length > 4) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _showAllCategories = !_showAllCategories;
                            }),
                            icon: Icon(
                              _showAllCategories
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                            ),
                            label: Text(
                              _showAllCategories ? 'Show less' : 'View all',
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SurfacePanel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'Monthly trend'),
                      if (bundle.analytics.monthlyTrend.isEmpty)
                        const EmptyState(text: 'No monthly totals yet.'),
                      ...bundle.analytics.monthlyTrend.map(
                        (item) => SummaryRow(
                          title: item.month,
                          subtitle:
                              'Income ${money(item.income, bundle.analytics.reportingCurrency)} · Expense ${money(item.expense, bundle.analytics.reportingCurrency)}',
                          value: money(
                            item.balance,
                            bundle.analytics.reportingCurrency,
                          ),
                          icon: Icons.calendar_month_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> pickRange(bool isFrom) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? (from ?? DateTime.now()) : (to ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        from = selected;
      } else {
        to = selected;
      }
      _showAllCategories = false;
      future = load();
    });
  }
}

class AnalyticsBundle {
  AnalyticsBundle({required this.analytics, required this.categories});

  final AnalyticsData analytics;
  final List<Category> categories;
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../category_style_options.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'app_config.dart';
import 'app_session.dart';
import 'helpers.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: AppLoader(size: 46)));
  }
}

Future<bool> showApiBaseUrlDialog(
  BuildContext context,
  AppSession session,
) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (context) => _ApiBaseUrlDialog(session: session),
  );
  return changed ?? false;
}

class _ApiBaseUrlDialog extends StatefulWidget {
  const _ApiBaseUrlDialog({required this.session});

  final AppSession session;

  @override
  State<_ApiBaseUrlDialog> createState() => _ApiBaseUrlDialogState();
}

class _ApiBaseUrlDialogState extends State<_ApiBaseUrlDialog> {
  late final TextEditingController controller;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.session.apiBaseUrl);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API base URL'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              enabled: !saving,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Backend URL',
                hintText: defaultApiBaseUrl,
                errorText: error,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Changing this URL signs out the current user.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: saving
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
      saving = true;
      error = null;
    });
    try {
      final previousBaseUrl = widget.session.apiBaseUrl;
      await widget.session.updateApiBaseUrl(controller.text);
      if (!mounted) return;
      Navigator.of(context).pop(widget.session.apiBaseUrl != previousBaseUrl);
    } on FormatException catch (exception) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = exception.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = 'Could not save the API URL.';
      });
    }
  }
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.size = 42, this.color = AppColors.teal});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LoadingAnimationWidget.fourRotatingDots(color: color, size: size);
  }
}

class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
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
            backgroundColor: AppColors.teal.withValues(alpha: 0.12),
            foregroundColor: AppColors.teal,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final connection = ConnectionStatusScope.maybeOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
              child: Row(
                children: [
                  if (Scaffold.maybeOf(context)?.hasDrawer ?? false) ...[
                    IconButton(
                      tooltip: 'Menu',
                      onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (connection != null) ...[
                          const SizedBox(width: 10),
                          ConnectionIndicator(
                            statusListenable: connection.statusListenable,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (connection != null) ...[
                    const SizedBox(width: 4),
                    SyncHeaderButton(
                      onPressed: connection.syncing ? null : connection.onSync,
                      syncing: connection.syncing,
                      pendingCount: connection.pendingCount,
                    ),
                  ],
                  ?action,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class ConnectionStatusScope extends InheritedWidget {
  const ConnectionStatusScope({
    super.key,
    required this.statusListenable,
    required this.onSync,
    required this.syncing,
    required this.pendingCount,
    required super.child,
  });

  final ValueListenable<bool?> statusListenable;
  final VoidCallback onSync;
  final bool syncing;
  final int pendingCount;

  static ConnectionStatusScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ConnectionStatusScope>();
  }

  @override
  bool updateShouldNotify(ConnectionStatusScope oldWidget) {
    return statusListenable != oldWidget.statusListenable ||
        onSync != oldWidget.onSync ||
        syncing != oldWidget.syncing ||
        pendingCount != oldWidget.pendingCount;
  }
}

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key, required this.statusListenable});

  final ValueListenable<bool?> statusListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: statusListenable,
      builder: (context, connected, _) {
        final color = connected == null
            ? AppColors.muted
            : connected
            ? const Color(0xFF16A34A)
            : Theme.of(context).colorScheme.error;
        final label = connected == null
            ? 'Checking connection'
            : connected
            ? 'Connected'
            : 'Offline';

        return Tooltip(
          message: label,
          child: Semantics(
            label: label,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SyncHeaderButton extends StatelessWidget {
  const SyncHeaderButton({
    super.key,
    required this.onPressed,
    required this.syncing,
    required this.pendingCount,
  });

  final VoidCallback? onPressed;
  final bool syncing;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final label = pendingCount > 0 ? 'Sync ($pendingCount)' : 'Sync';
    final compact = MediaQuery.sizeOf(context).width < 520;

    if (compact) {
      return Tooltip(
        message: label,
        child: Badge(
          isLabelVisible: pendingCount > 0,
          label: Text('$pendingCount'),
          child: IconButton(
            onPressed: onPressed,
            icon: syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ),
      );
    }

    return Tooltip(
      message: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: syncing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }
}

class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.snapshot, required this.builder});

  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: AppLoader());
    }
    if (snapshot.hasError) {
      final error = snapshot.error;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SurfacePanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 34,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 10),
                Text(
                  error is ApiException
                      ? error.message
                      : 'Could not load data from the configured API.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const EmptyState(text: 'No data.');
    }
    return builder(snapshot.requireData);
  }
}

class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.white,
      backgroundColor: AppColors.ink,
      displacement: 22,
      strokeWidth: 2.2,
      child: child,
    );
  }
}

class RefreshActionButton extends StatelessWidget {
  const RefreshActionButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh',
      child: IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.teal.withValues(alpha: 0.10),
          foregroundColor: AppColors.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.sync, size: 20),
      ),
    );
  }
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final accent = switch (title) {
      'Income' => AppColors.green,
      'Expense' => AppColors.rose,
      _ => AppColors.teal,
    };
    return SizedBox(
      width: MediaQuery.sizeOf(context).width < 520 ? double.infinity : 250,
      child: SurfacePanel(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: accent.withValues(alpha: 0.12),
                        foregroundColor: accent,
                        child: Icon(icon),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              value,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile(this.transaction, {super.key});

  final TransactionRecord transaction;

  @override
  Widget build(BuildContext context) {
    final currency = transaction.currency;
    final reportingCurrency = transaction.reportingCurrency ?? currency;
    final category = transaction.category;
    final isIncoming = transaction.type == 'incoming';
    final isConvert = transaction.type == 'convert';
    final accent = isIncoming
        ? AppColors.green
        : isConvert
        ? AppColors.teal
        : AppColors.rose;
    final categoryColor = parseColor(category?.color) ?? accent;
    final note = transaction.note?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        /// Category Circular Icon
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 23,
                              backgroundColor: categoryColor.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: categoryColor,
                              child: Icon(iconFor(category?.icon), size: 22),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  isIncoming
                                      ? Icons.arrow_downward
                                      : isConvert
                                      ? Icons.currency_exchange
                                      : Icons.arrow_upward,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      category?.name ?? 'Uncategorized',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                              if (note?.isNotEmpty == true) ...[
                                Container(
                                  margin: const EdgeInsets.only(
                                    top: 6,
                                    bottom: 6,
                                  ),
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 2,
                                    bottom: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: AppColors.muted.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    note!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.ink.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontStyle: FontStyle.italic,
                                          height: 1.3,
                                        ),
                                  ),
                                ),
                              ],
                              _buildMetadata(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${isIncoming
                                      ? '+'
                                      : isConvert
                                      ? '⇄ '
                                      : '-'}${money(transaction.amount, currency)}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                              if (currency?.code !=
                                  reportingCurrency?.code) ...[
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    money(
                                      transaction.convertedAmount,
                                      reportingCurrency,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.muted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: Text(
              '(#${transaction.id})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(BuildContext context) {
    final wallet = transaction.wallet;
    final List<Widget> metaItems = [
      if (transaction.occurredOn != null)
        InlineMetaItem(
          icon: Icons.calendar_today_outlined,
          text: shortDateTime(transaction.occurredOn!),
        ),
      if (wallet != null)
        InlineMetaItem(
          icon: Icons.account_balance_wallet_outlined,
          text: wallet.name,
        ),
      if (transaction.invoiceImages.isNotEmpty ||
          transaction.invoiceImageUrls.isNotEmpty)
        const InlineMetaItem(
          icon: Icons.receipt_long_outlined,
          text: 'Invoice',
          color: AppColors.teal,
        ),
    ];

    if (metaItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: metaItems,
      ),
    );
  }
}

class CompactTransactionTile extends StatelessWidget {
  const CompactTransactionTile(this.transaction, {super.key});

  final TransactionRecord transaction;

  @override
  Widget build(BuildContext context) {
    final currency = transaction.currency;
    final category = transaction.category;
    final wallet = transaction.wallet;
    final isIncoming = transaction.type == 'incoming';
    final isConvert = transaction.type == 'convert';
    final accent = isIncoming
        ? AppColors.green
        : isConvert
        ? AppColors.teal
        : AppColors.rose;
    final categoryColor = parseColor(category?.color) ?? accent;
    final note = transaction.note?.trim();

    final hasNote = note?.isNotEmpty == true;
    final title = hasNote ? note! : (category?.name ?? 'Uncategorized');
    final subtitle = [
      if (hasNote) category?.name ?? 'Uncategorized',
      if (wallet != null) wallet.name,
      if (transaction.occurredOn != null)
        shortDateTime(transaction.occurredOn!),
    ].join('  •  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: categoryColor.withValues(
                            alpha: 0.14,
                          ),
                          foregroundColor: categoryColor,
                          child: Icon(iconFor(category?.icon), size: 18),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              isIncoming
                                  ? Icons.arrow_downward
                                  : isConvert
                                  ? Icons.currency_exchange
                                  : Icons.arrow_upward,
                              size: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${isIncoming
                              ? '+'
                              : isConvert
                              ? '⇄ '
                              : '-'}${money(transaction.amount, currency)}',
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InlineMetaItem extends StatelessWidget {
  const InlineMetaItem({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: themeColor.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: themeColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class TransactionTypeBadge extends StatelessWidget {
  const TransactionTypeBadge({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final isIncoming = type == 'incoming';
    final isConvert = type == 'convert';
    final color = isIncoming
        ? AppColors.green
        : isConvert
        ? AppColors.teal
        : AppColors.rose;
    final text = isIncoming
        ? 'Income'
        : isConvert
        ? 'Conversion'
        : 'Expense';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final incoming = type == 'incoming';
    final archived = type == 'archived';
    final defaultWallet = type == 'default';
    final color = defaultWallet
        ? AppColors.teal
        : archived
        ? AppColors.muted
        : incoming
        ? AppColors.green
        : AppColors.rose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        defaultWallet
            ? 'Pri.'
            : archived
            ? 'Archived'
            : incoming
            ? 'Income'
            : 'Expense',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class CategoryDot extends StatelessWidget {
  const CategoryDot({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor:
          parseColor(category.color) ??
          Theme.of(context).colorScheme.primaryContainer,
      child: Icon(iconFor(category.icon), color: Colors.white, size: 20),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              color: AppColors.muted.withValues(alpha: 0.65),
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBanner extends StatelessWidget {
  const MessageBanner({super.key, required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError
                ? colors.error.withValues(alpha: 0.18)
                : colors.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String text) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/app_session.dart';
import '../core/helpers.dart';
import '../core/shared_widgets.dart';
import '../models/models.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key, required this.session});

  static const routeName = '/goals';

  final AppSession session;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late Future<GoalsBundle> future = load();

  Future<GoalsBundle> load() async {
    final results = await Future.wait([
      widget.session.api.goals(),
      widget.session.api.currencies(),
      widget.session.api.wallets(),
    ]);

    return GoalsBundle(
      goals: results[0] as List<Goal>,
      currencies: results[1] as List<Currency>,
      wallets: results[2] as List<Wallet>,
    );
  }

  void reload() {
    setState(() {
      future = load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GoalsBundle>(
      future: future,
      builder: (context, snapshot) {
        return AppPage(
          title: 'Goals',
          action: IconButton(
            tooltip: 'Add goal',
            onPressed: snapshot.hasData
                ? () => addGoal(snapshot.requireData)
                : null,
            icon: const Icon(Icons.add),
          ),
          child: AsyncBody(
            snapshot: snapshot,
            builder: (bundle) {
              return AppRefreshIndicator(
                onRefresh: () async {
                  final next = load();
                  setState(() {
                    future = next;
                  });
                  await next;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (bundle.goals.isEmpty)
                      SurfacePanel(
                        child: Column(
                          children: [
                            const EmptyState(text: 'No goals yet.'),
                            FilledButton.icon(
                              onPressed: () => addGoal(bundle),
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('Create goal'),
                            ),
                          ],
                        ),
                      ),
                    ...bundle.goals.map(
                      (goal) => GoalCard(
                        goal: goal,
                        onOpen: () => showGoalDetails(goal),
                        onContribute: () => addContribution(bundle, goal),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> addGoal(GoalsBundle bundle) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => GoalDialog(session: widget.session, bundle: bundle),
    );
    if (created == true) reload();
  }

  Future<void> addContribution(GoalsBundle bundle, Goal goal) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GoalContributionSheet(
        session: widget.session,
        bundle: bundle,
        goal: goal,
      ),
    );
    if (created == true) reload();
  }

  Future<void> showGoalDetails(Goal goal) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,

      builder: (_) => GoalDetailsSheet(goal: goal),
    );
  }
}

class GoalsBundle {
  GoalsBundle({
    required this.goals,
    required this.currencies,
    required this.wallets,
  });

  final List<Goal> goals;
  final List<Currency> currencies;
  final List<Wallet> wallets;
}

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.onOpen,
    required this.onContribute,
  });

  final Goal goal;
  final VoidCallback onOpen;
  final VoidCallback onContribute;

  @override
  Widget build(BuildContext context) {
    final complete = goal.completedAt != null || goal.progress >= 1;
    final progress = goal.progress.clamp(0, 1).toDouble();

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: complete
                ? AppColors.green.withValues(alpha: 0.32)
                : AppColors.border.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: complete
                      ? AppColors.green.withValues(alpha: 0.12)
                      : AppColors.teal.withValues(alpha: 0.12),
                  foregroundColor: complete ? AppColors.green : AppColors.teal,
                  child: Icon(complete ? Icons.check : Icons.flag_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${money(goal.currentAmount, goal.currency)} of ${money(goal.targetAmount, goal.currency)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(progress * 100).round()}%',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: complete ? AppColors.green : AppColors.ink,
                      ),
                    ),
                    Text(
                      '${goal.contributionsCount} tx',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: progress,
                backgroundColor: AppColors.canvas,
                valueColor: AlwaysStoppedAnimation(
                  complete ? AppColors.green : AppColors.teal,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Remaining ${money(goal.remainingAmount, goal.currency)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
                FilledButton.icon(
                  onPressed: complete ? null : onContribute,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GoalDetailsSheet extends StatelessWidget {
  const GoalDetailsSheet({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              goal.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GoalStatChip(
                  icon: Icons.receipt_long_outlined,
                  label: '${goal.contributionsCount} transactions',
                ),
                GoalStatChip(
                  icon: Icons.savings_outlined,
                  label: money(goal.currentAmount, goal.currency),
                ),
                GoalStatChip(
                  icon: Icons.flag_outlined,
                  label: 'Target ${money(goal.targetAmount, goal.currency)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: goal.recentContributions.isEmpty
                  ? const EmptyState(text: 'No contributions yet.')
                  : ListView(
                      children: goal.recentContributions.map((contribution) {
                        final transaction = contribution.transaction;
                        if (transaction != null) {
                          return TransactionTile(transaction);
                        }

                        return CompactContributionRow(
                          contribution: contribution,
                          currency: goal.currency,
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoalStatChip extends StatelessWidget {
  const GoalStatChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.teal),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class CompactContributionRow extends StatelessWidget {
  const CompactContributionRow({
    super.key,
    required this.contribution,
    required this.currency,
  });

  final GoalContribution contribution;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              contribution.occurredOn == null
                  ? 'Contribution'
                  : shortDateTime(contribution.occurredOn!),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            money(contribution.amount, currency),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class GoalDialog extends StatefulWidget {
  const GoalDialog({super.key, required this.session, required this.bundle});

  final AppSession session;
  final GoalsBundle bundle;

  @override
  State<GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<GoalDialog> {
  final name = TextEditingController();
  final target = TextEditingController();
  final note = TextEditingController();
  int? currencyId;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    currencyId = widget.bundle.currencies.isEmpty
        ? null
        : widget.bundle.currencies.first.id;
  }

  @override
  void dispose() {
    name.dispose();
    target.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New goal'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Target amount'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: currencyId,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: widget.bundle.currencies
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
              controller: note,
              decoration: const InputDecoration(labelText: 'Note'),
              minLines: 1,
              maxLines: 3,
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
        FilledButton(onPressed: busy ? null : save, child: const Text('Save')),
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
      await widget.session.api.createGoal(
        name: name.text.trim(),
        currencyId: currencyId!,
        targetAmount: target.text.trim(),
        note: note.text.trim().isEmpty ? null : note.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class GoalContributionSheet extends StatefulWidget {
  const GoalContributionSheet({
    super.key,
    required this.session,
    required this.bundle,
    required this.goal,
  });

  final AppSession session;
  final GoalsBundle bundle;
  final Goal goal;

  @override
  State<GoalContributionSheet> createState() => _GoalContributionSheetState();
}

class _GoalContributionSheetState extends State<GoalContributionSheet> {
  final amount = TextEditingController();
  final note = TextEditingController();
  final invoiceImages = <GoalPendingInvoiceImage>[];
  int? walletId;
  DateTime occurredOn = DateTime.now();
  bool busy = false;
  String? error;

  List<Wallet> get wallets => widget.bundle.wallets
      .where((wallet) => wallet.currency.id == widget.goal.currency.id)
      .toList();

  @override
  void initState() {
    super.initState();
    walletId = wallets.isEmpty ? null : wallets.first.id;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add to ${widget.goal.name}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (wallets.isEmpty)
              MessageBanner(
                text:
                    'Create a ${widget.goal.currency.code} wallet before adding to this goal.',
                isError: true,
              )
            else ...[
              DropdownButtonFormField<int>(
                initialValue: walletId,
                decoration: const InputDecoration(
                  labelText: 'Wallet',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: wallets
                    .map(
                      (wallet) => DropdownMenuItem(
                        value: wallet.id,
                        child: Text(
                          '${wallet.name} - ${money(wallet.balance, wallet.currency)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => walletId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note'),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              invoiceImagePicker(),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(shortDateTime(occurredOn)),
              ),
            ],
            if (error != null) MessageBanner(text: error!, isError: true),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy || wallets.isEmpty ? null : save,
              icon: const Icon(Icons.savings_outlined),
              label: const Text('Add contribution'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: occurredOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(occurredOn),
    );
    setState(() {
      occurredOn = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? occurredOn.hour,
        time?.minute ?? occurredOn.minute,
      );
    });
  }

  Widget invoiceImagePicker() {
    final hasImages = invoiceImages.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Invoice images',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (hasImages)
                IconButton(
                  tooltip: 'Remove invoice images',
                  onPressed: clearInvoiceImages,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (hasImages) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final image in invoiceImages)
                  invoiceThumbnail(
                    child: Image.memory(image.bytes, fit: BoxFit.cover),
                    onTap: () => openInvoiceImage(
                      Image.memory(image.bytes, fit: BoxFit.contain),
                    ),
                    onRemove: () => removeInvoiceImage(image),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : pickInvoiceImages,
            icon: const Icon(Icons.attach_file),
            label: Text(hasImages ? 'Add invoices' : 'Attach invoices'),
          ),
        ],
      ),
    );
  }

  Widget invoiceThumbnail({
    required Widget child,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Tooltip(
      message: 'Open invoice image',
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 132, height: 112, child: child),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filled(
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove invoice image',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> openInvoiceImage(Widget image) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(child: image),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: IconButton.filled(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickInvoiceImages() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (picked.isEmpty) return;
    final pendingImages = <GoalPendingInvoiceImage>[];
    for (final image in picked) {
      pendingImages.add(
        GoalPendingInvoiceImage(file: image, bytes: await image.readAsBytes()),
      );
    }
    if (!mounted) return;
    setState(() => invoiceImages.addAll(pendingImages));
  }

  void clearInvoiceImages() {
    setState(() => invoiceImages.clear());
  }

  void removeInvoiceImage(GoalPendingInvoiceImage image) {
    setState(() => invoiceImages.remove(image));
  }

  Future<void> save() async {
    if (walletId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final invoiceUploads = invoiceImages
          .map(
            (image) =>
                InvoiceImageUpload(bytes: image.bytes, filename: image.name),
          )
          .toList();
      await widget.session.api.contributeToGoal(
        goalId: widget.goal.id,
        walletId: walletId!,
        amount: amount.text.trim(),
        occurredOn: occurredOn,
        note: note.text.trim().isEmpty ? null : note.text.trim(),
        invoiceImages: invoiceUploads,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class GoalPendingInvoiceImage {
  GoalPendingInvoiceImage({required this.file, required this.bytes});

  final XFile file;
  final Uint8List bytes;

  String get name => file.name.isEmpty ? 'invoice.jpg' : file.name;
}

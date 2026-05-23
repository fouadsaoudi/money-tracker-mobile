import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/app_session.dart';
import '../core/helpers.dart';
import '../core/shared_widgets.dart';
import '../models/models.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, required this.session});

  static const routeName = '/transactions';

  final AppSession session;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final search = TextEditingController();
  String type = '';
  int? categoryId;
  late Future<TransactionsBundle> future = load();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<TransactionsBundle> load() async {
    final results = await Future.wait([
      widget.session.api.transactions(
        search: search.text.trim(),
        categoryId: categoryId,
        type: type,
      ),
      widget.session.api.categories(),
      widget.session.api.wallets(),
    ]);
    return TransactionsBundle(
      transactions: results[0] as PagedTransactions,
      categories: results[1] as List<Category>,
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
    return FutureBuilder<TransactionsBundle>(
      future: future,
      builder: (context, snapshot) {
        return AppPage(
          title: 'Transactions',
          child: AsyncBody(
            snapshot: snapshot,
            builder: (bundle) {
              final activeCategories = bundle.categories
                  .where((item) => !item.isArchived)
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  SurfacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: search,
                          decoration: InputDecoration(
                            labelText: 'Search notes',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              tooltip: 'Apply',
                              onPressed: reload,
                              icon: const Icon(Icons.check),
                            ),
                          ),
                          onSubmitted: (_) => reload(),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilterChip(
                              avatar: const Icon(Icons.arrow_downward),
                              label: const Text('Income'),
                              selected: type == 'incoming',
                              onSelected: (_) => setState(() {
                                type = type == 'incoming' ? '' : 'incoming';
                                future = load();
                              }),
                            ),
                            FilterChip(
                              avatar: const Icon(Icons.arrow_upward),
                              label: const Text('Expense'),
                              selected: type == 'outgoing',
                              onSelected: (_) => setState(() {
                                type = type == 'outgoing' ? '' : 'outgoing';
                                future = load();
                              }),
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
                                  ...activeCategories.map(
                                    (category) => DropdownMenuItem<int?>(
                                      value: category.id,
                                      child: Text(category.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) => setState(() {
                                  categoryId = value;
                                  future = load();
                                }),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SurfacePanel(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: '${bundle.transactions.total} transactions',
                        ),
                        if (bundle.transactions.data.isEmpty)
                          const EmptyState(text: 'No transactions found.'),
                        ...bundle.transactions.data.map(
                          (transaction) => Dismissible(
                            key: ValueKey(transaction.id),
                            background: Container(
                              alignment: Alignment.centerRight,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) =>
                                confirm(context, 'Delete this transaction?'),
                            onDismissed: (_) async {
                              await widget.session.api.deleteTransaction(
                                transaction.id,
                              );
                              reload();
                            },
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => editTransaction(bundle, transaction),
                              child: TransactionTile(transaction),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> addTransaction(TransactionsBundle bundle) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionForm(session: widget.session, bundle: bundle),
    );
    if (created == true) reload();
  }

  Future<void> editTransaction(
    TransactionsBundle bundle,
    TransactionRecord transaction,
  ) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionForm(
        session: widget.session,
        bundle: bundle,
        transaction: transaction,
      ),
    );
    if (updated == true) reload();
  }
}

class TransactionsBundle {
  TransactionsBundle({
    required this.transactions,
    required this.categories,
    required this.wallets,
  });

  final PagedTransactions transactions;
  final List<Category> categories;
  final List<Wallet> wallets;
}

class TransactionForm extends StatefulWidget {
  const TransactionForm({
    super.key,
    required this.session,
    required this.bundle,
    this.transaction,
  });

  final AppSession session;
  final TransactionsBundle bundle;
  final TransactionRecord? transaction;

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final amount = TextEditingController();
  final destinationAmount = TextEditingController();
  final note = TextEditingController();
  String type = 'outgoing';
  int? categoryId;
  int? walletId;
  int? destinationWalletId;
  DateTime occurredOn = DateTime.now();
  final invoiceImages = <PendingInvoiceImage>[];
  final removedExistingInvoiceImageIds = <int>{};
  bool removeExistingInvoiceImages = false;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    amount.text = transaction?.amount ?? '';
    note.text = transaction?.note ?? '';
    type = transaction?.type ?? 'outgoing';
    occurredOn = transaction?.occurredOn ?? DateTime.now();

    final categories = selectableCategories;
    categoryId =
        transaction?.category?.id ??
        (categories.isEmpty ? null : categories.first.id);

    final defaultWallet = widget.bundle.wallets.where(
      (wallet) => wallet.isDefault,
    );
    walletId =
        transaction?.wallet?.id ??
        (defaultWallet.isNotEmpty
            ? defaultWallet.first.id
            : widget.bundle.wallets.isEmpty
            ? null
            : widget.bundle.wallets.first.id);
    destinationWalletId = firstOtherWalletId(walletId);
  }

  @override
  void dispose() {
    amount.dispose();
    destinationAmount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final categories = selectableCategories;
    final hasWallets = widget.bundle.wallets.isNotEmpty;
    final editing = widget.transaction != null;
    final converting = type == 'convert';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit transaction' : 'New transaction',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 'outgoing',
                  label: Text('Spend'),
                  icon: Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: 'incoming',
                  label: Text('Add funds'),
                  icon: Icon(Icons.add),
                ),
                if (!editing)
                  const ButtonSegment(
                    value: 'convert',
                    label: Text('Convert'),
                    icon: Icon(Icons.currency_exchange),
                  ),
              ],
              selected: {type},
              onSelectionChanged: (value) => setState(() => type = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: converting ? 'Amount to exchange' : 'Amount',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: walletId,
              decoration: const InputDecoration(
                labelText: 'Wallet',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: widget.bundle.wallets
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
              onChanged: (value) => setState(() {
                walletId = value;
                if (destinationWalletId == value) {
                  destinationWalletId = firstOtherWalletId(value);
                }
              }),
            ),
            if (!hasWallets)
              const MessageBanner(
                text: 'Create a wallet before adding transactions.',
                isError: true,
              ),
            if (converting) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: destinationWalletId,
                decoration: const InputDecoration(
                  labelText: 'Receive into',
                  prefixIcon: Icon(Icons.call_received),
                ),
                items: widget.bundle.wallets
                    .where((wallet) => wallet.id != walletId)
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
                onChanged: (value) =>
                    setState(() => destinationWalletId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: destinationAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount received'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => categoryId = value),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note'),
              minLines: 1,
              maxLines: 3,
            ),
            if (!converting) ...[
              const SizedBox(height: 12),
              invoiceImagePicker(),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: pickDate,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(shortDateTime(occurredOn)),
            ),
            if (error != null) MessageBanner(text: error!, isError: true),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: busy || !hasWallets ? null : save,
              icon: const Icon(Icons.save_outlined),
              label: Text(editing ? 'Save changes' : 'Save transaction'),
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
    final transaction = widget.transaction;
    final existingImages = removeExistingInvoiceImages
        ? <TransactionInvoiceImage>[]
        : transaction?.invoiceImages
                  .where(
                    (image) =>
                        !removedExistingInvoiceImageIds.contains(image.id),
                  )
                  .toList() ??
              const <TransactionInvoiceImage>[];
    final fallbackExistingUrls =
        transaction?.invoiceImages.isEmpty == true &&
            !removeExistingInvoiceImages
        ? transaction!.invoiceImageUrls
        : const <String>[];
    final hasImages =
        existingImages.isNotEmpty ||
        fallbackExistingUrls.isNotEmpty ||
        invoiceImages.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(20),
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
                for (final image in existingImages)
                  invoiceThumbnail(
                    child: Image.network(
                      image.url,
                      fit: BoxFit.cover,
                      errorBuilder: invoiceImageError,
                    ),
                    onTap: () => openInvoiceImage(
                      Image.network(
                        image.url,
                        fit: BoxFit.contain,
                        errorBuilder: invoiceImageError,
                      ),
                    ),
                    onRemove: () => removeExistingInvoiceImage(image),
                    tooltip: 'Open invoice image',
                  ),
                for (final url in fallbackExistingUrls)
                  invoiceThumbnail(
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: invoiceImageError,
                    ),
                    onTap: () => openInvoiceImage(
                      Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: invoiceImageError,
                      ),
                    ),
                    tooltip: 'Open invoice image',
                  ),
                for (final image in invoiceImages)
                  invoiceThumbnail(
                    child: Image.memory(image.bytes, fit: BoxFit.cover),
                    onTap: () => openInvoiceImage(
                      Image.memory(image.bytes, fit: BoxFit.contain),
                    ),
                    onRemove: () => removePendingInvoiceImage(image),
                    tooltip: 'Open invoice image',
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
    required String tooltip,
    VoidCallback? onRemove,
  }) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(width: 132, height: 112, child: child),
            ),
          ),
          if (onRemove != null)
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

  Widget invoiceImageError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return Container(
      height: 90,
      alignment: Alignment.center,
      color: AppColors.surface,
      child: const Icon(Icons.broken_image_outlined),
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
    final pendingImages = <PendingInvoiceImage>[];
    for (final image in picked) {
      pendingImages.add(
        PendingInvoiceImage(file: image, bytes: await image.readAsBytes()),
      );
    }
    if (!mounted) return;
    setState(() {
      invoiceImages.addAll(pendingImages);
    });
  }

  void clearInvoiceImages() {
    setState(() {
      invoiceImages.clear();
      removedExistingInvoiceImageIds.clear();
      removeExistingInvoiceImages =
          widget.transaction?.invoiceImageUrls.isNotEmpty ?? false;
    });
  }

  void removeExistingInvoiceImage(TransactionInvoiceImage image) {
    setState(() => removedExistingInvoiceImageIds.add(image.id));
  }

  void removePendingInvoiceImage(PendingInvoiceImage image) {
    setState(() => invoiceImages.remove(image));
  }

  Future<void> save() async {
    if (walletId == null) return;
    if (type != 'convert' && categoryId == null) return;
    if (type == 'convert' && destinationWalletId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final transaction = widget.transaction;
      final invoiceUploads = invoiceImages
          .map(
            (image) =>
                InvoiceImageUpload(bytes: image.bytes, filename: image.name),
          )
          .toList();
      if (type == 'convert') {
        await widget.session.api.convertWalletMoney(
          sourceWalletId: walletId!,
          destinationWalletId: destinationWalletId!,
          sourceAmount: amount.text.trim(),
          destinationAmount: destinationAmount.text.trim(),
          occurredOn: occurredOn,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
        );
      } else if (transaction == null) {
        await widget.session.api.createTransaction(
          categoryId: categoryId!,
          walletId: walletId!,
          type: type,
          amount: amount.text.trim(),
          occurredOn: occurredOn,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          invoiceImages: invoiceUploads,
        );
      } else {
        await widget.session.api.updateTransaction(
          id: transaction.id,
          categoryId: categoryId!,
          walletId: walletId!,
          type: type,
          amount: amount.text.trim(),
          occurredOn: occurredOn,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          invoiceImages: invoiceUploads,
          removeInvoiceImages: removeExistingInvoiceImages,
          removeInvoiceImageIds: removedExistingInvoiceImageIds.toList(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Category> get selectableCategories {
    final transactionCategoryId = widget.transaction?.category?.id;

    return widget.bundle.categories
        .where((item) => !item.isArchived || item.id == transactionCategoryId)
        .toList();
  }

  int? firstOtherWalletId(int? sourceWalletId) {
    for (final wallet in widget.bundle.wallets) {
      if (wallet.id != sourceWalletId) return wallet.id;
    }

    return null;
  }
}

class PendingInvoiceImage {
  PendingInvoiceImage({required this.file, required this.bytes});

  final XFile file;
  final Uint8List bytes;

  String get name => file.name.isEmpty ? 'invoice.jpg' : file.name;
}

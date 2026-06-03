import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/app_session.dart';
import '../core/helpers.dart';
import '../core/shared_widgets.dart';
import '../models/models.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.session});

  static const routeName = '/settings';

  final AppSession session;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<SettingsBundle> future = load();
  bool saving = false;

  Future<SettingsBundle> load() async {
    final results = await Future.wait([
      widget.session.api.currencies(),
      widget.session.api.exchangeRates(),
    ]);
    return SettingsBundle(
      currencies: results[0] as List<Currency>,
      exchangeRates: results[1] as List<ExchangeRate>,
    );
  }

  Future<void> reload() async {
    final next = load();
    setState(() {
      future = next;
    });
    await next;
  }

  Future<void> addExchangeRate(SettingsBundle bundle) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => ExchangeRateDialog(
        session: widget.session,
        currencies: bundle.currencies,
        existingRates: bundle.exchangeRates,
        preferredFromCurrency: widget.session.user?.reportingCurrency,
      ),
    );
    if (created == true) {
      await reload();
    }
  }

  Future<void> editExchangeRate(
    SettingsBundle bundle,
    ExchangeRate rate,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => ExchangeRateDialog(
        session: widget.session,
        currencies: bundle.currencies,
        existingRates: bundle.exchangeRates,
        exchangeRate: rate,
      ),
    );
    if (updated == true) {
      await reload();
    }
  }

  Future<void> deleteExchangeRate(ExchangeRate rate) async {
    final ok = await confirm(
      context,
      'Delete ${rate.fromCurrency.code} to ${rate.toCurrency.code} rate?',
    );
    if (!ok) return;

    await widget.session.api.deleteExchangeRate(rate.id);
    await reload();
  }

  Future<void> _confirmLogout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await widget.session.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return AppPage(
      title: 'Settings',
      child: FutureBuilder<SettingsBundle>(
        future: future,
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.teal.withValues(
                            alpha: 0.12,
                          ),
                          foregroundColor: AppColors.teal,
                          child: const Icon(Icons.person_outline),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(child: AppLoader(size: 30))
                    else if (snapshot.hasError)
                      MessageBanner(
                        text: snapshot.error is ApiException
                            ? (snapshot.error as ApiException).message
                            : 'Could not load settings.',
                        isError: true,
                      )
                    else
                      ReportingCurrencyField(
                        currencies: snapshot.requireData.currencies,
                        selectedCurrencyId: user?.reportingCurrency?.id,
                        saving: saving,
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() => saving = true);
                          try {
                            await widget.session.updateReportingCurrency(value);
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.hasData)
                ExchangeRatesSection(
                  bundle: snapshot.requireData,
                  onAdd: () => addExchangeRate(snapshot.requireData),
                  onEdit: (rate) =>
                      editExchangeRate(snapshot.requireData, rate),
                  onDelete: deleteExchangeRate,
                )
              else if (snapshot.connectionState != ConnectionState.waiting)
                SurfacePanel(
                  child: MessageBanner(
                    text: 'Exchange rates could not be loaded.',
                    isError: true,
                  ),
                ),
              const SizedBox(height: 14),
              AppearanceSection(session: widget.session),
              const SizedBox(height: 14),
              SurfacePanel(
                child: Row(
                  children: [
                    const Icon(Icons.api_outlined, color: AppColors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'API base URL',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.session.apiBaseUrl,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          showApiBaseUrlDialog(context, widget.session),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsBundle {
  SettingsBundle({required this.currencies, required this.exchangeRates});

  final List<Currency> currencies;
  final List<ExchangeRate> exchangeRates;

  bool hasExchangeRatePair(int fromCurrencyId, int toCurrencyId) {
    return exchangeRates.any(
      (rate) =>
          (rate.fromCurrency.id == fromCurrencyId &&
              rate.toCurrency.id == toCurrencyId) ||
          (rate.fromCurrency.id == toCurrencyId &&
              rate.toCurrency.id == fromCurrencyId),
    );
  }
}

class ReportingCurrencyField extends StatelessWidget {
  const ReportingCurrencyField({
    super.key,
    required this.currencies,
    required this.selectedCurrencyId,
    required this.saving,
    required this.onChanged,
  });

  final List<Currency> currencies;
  final int? selectedCurrencyId;
  final bool saving;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: selectedCurrencyId,
      decoration: const InputDecoration(labelText: 'Reporting currency'),
      items: currencies
          .map(
            (currency) => DropdownMenuItem(
              value: currency.id,
              child: Text('${currency.code} - ${currency.name}'),
            ),
          )
          .toList(),
      onChanged: saving ? null : onChanged,
    );
  }
}

class ExchangeRatesSection extends StatelessWidget {
  const ExchangeRatesSection({
    super.key,
    required this.bundle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final SettingsBundle bundle;
  final VoidCallback onAdd;
  final Future<void> Function(ExchangeRate rate) onEdit;
  final Future<void> Function(ExchangeRate rate) onDelete;

  @override
  Widget build(BuildContext context) {
    final canAddRate = bundle.currencies.any(
      (fromCurrency) => bundle.currencies.any(
        (toCurrency) =>
            toCurrency.id != fromCurrency.id &&
            !bundle.hasExchangeRatePair(fromCurrency.id, toCurrency.id),
      ),
    );

    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Exchange rates',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Add exchange rate',
                onPressed: canAddRate ? onAdd : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (bundle.exchangeRates.isEmpty)
            const EmptyState(text: 'No exchange rates configured.')
          else
            ...bundle.exchangeRates.map(
              (rate) => ExchangeRateTile(
                rate: rate,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
        ],
      ),
    );
  }
}

class ExchangeRateTile extends StatelessWidget {
  const ExchangeRateTile({
    super.key,
    required this.rate,
    required this.onEdit,
    required this.onDelete,
  });

  final ExchangeRate rate;
  final Future<void> Function(ExchangeRate rate) onEdit;
  final Future<void> Function(ExchangeRate rate) onDelete;

  @override
  Widget build(BuildContext context) {
    final date = rate.effectiveAt == null
        ? 'No effective date'
        : shortDateTime(rate.effectiveAt!);
    final displayRate = decimalText(rate.rate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.teal.withValues(alpha: 0.12),
            foregroundColor: AppColors.teal,
            child: const Icon(Icons.currency_exchange, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 ${rate.fromCurrency.code} = $displayRate ${rate.toCurrency.code}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit rate',
            onPressed: () => onEdit(rate),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete rate',
            onPressed: () => onDelete(rate),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class ExchangeRateDialog extends StatefulWidget {
  const ExchangeRateDialog({
    super.key,
    required this.session,
    required this.currencies,
    required this.existingRates,
    this.preferredFromCurrency,
    this.exchangeRate,
  });

  final AppSession session;
  final List<Currency> currencies;
  final List<ExchangeRate> existingRates;
  final Currency? preferredFromCurrency;
  final ExchangeRate? exchangeRate;

  @override
  State<ExchangeRateDialog> createState() => _ExchangeRateDialogState();
}

class _ExchangeRateDialogState extends State<ExchangeRateDialog> {
  final rate = TextEditingController();
  int? fromCurrencyId;
  int? toCurrencyId;
  DateTime effectiveAt = DateTime.now();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final exchangeRate = widget.exchangeRate;
    if (exchangeRate != null) {
      fromCurrencyId = exchangeRate.fromCurrency.id;
      toCurrencyId = exchangeRate.toCurrency.id;
      rate.text = decimalText(exchangeRate.rate);
      effectiveAt = exchangeRate.effectiveAt ?? DateTime.now();
      return;
    }

    final preferred = widget.preferredFromCurrency;
    final availableFrom = availableFromCurrencies();
    fromCurrencyId =
        availableFrom.any((currency) => currency.id == preferred?.id)
        ? preferred?.id
        : availableFrom.firstOrNull?.id;
    toCurrencyId = firstCurrencyIdExcept(fromCurrencyId);
  }

  @override
  void dispose() {
    rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromCurrency = currencyById(fromCurrencyId);
    final toCurrency = currencyById(toCurrencyId);
    final isEditing = widget.exchangeRate != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit exchange rate' : 'New exchange rate'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: fromCurrencyId,
              decoration: const InputDecoration(labelText: 'From'),
              items: currencyItems(availableFromCurrencies()),
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      fromCurrencyId = value;
                      if (toCurrencyId == value ||
                          pairExists(value, toCurrencyId)) {
                        toCurrencyId = firstCurrencyIdExcept(value);
                      }
                    }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: toCurrencyId,
              decoration: const InputDecoration(labelText: 'To'),
              items: currencyItems(availableToCurrencies(fromCurrencyId)),
              onChanged: busy
                  ? null
                  : (value) => setState(() => toCurrencyId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rate,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: fromCurrency == null || toCurrency == null
                    ? 'Rate'
                    : '1 ${fromCurrency.code} = ? ${toCurrency.code}',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : pickEffectiveDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(shortDateTime(effectiveAt)),
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

  List<Currency> availableFromCurrencies() {
    return widget.currencies
        .where(
          (fromCurrency) => availableToCurrencies(fromCurrency.id).isNotEmpty,
        )
        .toList();
  }

  List<Currency> availableToCurrencies(int? fromCurrencyId) {
    if (fromCurrencyId == null) return const [];

    return widget.currencies
        .where(
          (currency) =>
              currency.id != fromCurrencyId &&
              !pairExists(fromCurrencyId, currency.id),
        )
        .toList();
  }

  List<DropdownMenuItem<int>> currencyItems(List<Currency> currencies) {
    return currencies
        .map(
          (currency) => DropdownMenuItem(
            value: currency.id,
            child: Text('${currency.code} - ${currency.name}'),
          ),
        )
        .toList();
  }

  Currency? currencyById(int? id) {
    for (final currency in widget.currencies) {
      if (currency.id == id) return currency;
    }

    return null;
  }

  int? firstCurrencyIdExcept(int? id) {
    for (final currency in availableToCurrencies(id)) {
      return currency.id;
    }

    return null;
  }

  bool pairExists(int? fromCurrencyId, int? toCurrencyId) {
    if (fromCurrencyId == null || toCurrencyId == null) return false;

    return widget.existingRates.any((rate) {
      if (rate.id == widget.exchangeRate?.id) return false;

      return (rate.fromCurrency.id == fromCurrencyId &&
              rate.toCurrency.id == toCurrencyId) ||
          (rate.fromCurrency.id == toCurrencyId &&
              rate.toCurrency.id == fromCurrencyId);
    });
  }

  Future<void> pickEffectiveDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: effectiveAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;

    setState(() {
      effectiveAt = DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> save() async {
    final value = rate.text.trim();
    if (fromCurrencyId == null || toCurrencyId == null) {
      setState(() => error = 'Choose both currencies.');
      return;
    }
    if (value.isEmpty) {
      setState(() => error = 'Enter an exchange rate.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final exchangeRate = widget.exchangeRate;
      if (exchangeRate == null) {
        await widget.session.api.createExchangeRate(
          fromCurrencyId: fromCurrencyId!,
          toCurrencyId: toCurrencyId!,
          rate: value,
          effectiveAt: effectiveAt,
        );
      } else {
        await widget.session.api.updateExchangeRate(
          id: exchangeRate.id,
          fromCurrencyId: fromCurrencyId!,
          toCurrencyId: toCurrencyId!,
          rate: value,
          effectiveAt: effectiveAt,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          busy = false;
          error = exception.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not save the exchange rate.';
        });
      }
    }
  }
}

class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appearance',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Use your device theme by default, or choose a fixed style.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_brightness_outlined),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {session.themeMode},
              onSelectionChanged: (selection) {
                session.updateThemeMode(selection.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

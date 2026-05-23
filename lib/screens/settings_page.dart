import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/app_session.dart';
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
  late Future<List<Currency>> currencies = widget.session.api.currencies();
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return AppPage(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.teal.withValues(alpha: 0.12),
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
                            style: const TextStyle(fontWeight: FontWeight.w900),
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
                FutureBuilder<List<Currency>>(
                  future: currencies,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: AppLoader(size: 30));
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return MessageBanner(
                        text: error is ApiException
                            ? error.message
                            : 'Could not load currencies.',
                        isError: true,
                      );
                    }
                    final items = snapshot.data ?? [];
                    return DropdownButtonFormField<int>(
                      initialValue: user?.reportingCurrency?.id,
                      decoration: const InputDecoration(
                        labelText: 'Reporting currency',
                      ),
                      items: items
                          .map(
                            (currency) => DropdownMenuItem(
                              value: currency.id,
                              child: Text(
                                '${currency.code} - ${currency.name}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) async {
                              if (value == null) return;
                              setState(() => saving = true);
                              try {
                                await widget.session.updateReportingCurrency(
                                  value,
                                );
                              } finally {
                                if (mounted) setState(() => saving = false);
                              }
                            },
                    );
                  },
                ),
              ],
            ),
          ),
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
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
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
            onPressed: widget.session.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

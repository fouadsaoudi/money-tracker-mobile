import 'package:flutter/material.dart';

import '../category_style_options.dart';
import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/app_session.dart';
import '../core/helpers.dart';
import '../core/shared_widgets.dart';
import '../models/models.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.session});

  static const routeName = '/categories';

  final AppSession session;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late Future<List<Category>> future = widget.session.api.categories();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: future,
      builder: (context, snapshot) {
        return AppPage(
          title: 'Categories',
          action: IconButton(
            tooltip: 'Add category',
            onPressed: addCategory,
            icon: const Icon(Icons.add),
          ),
          child: AsyncBody(
            snapshot: snapshot,
            builder: (categories) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                SurfacePanel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(title: '${categories.length} categories'),
                      if (categories.isEmpty)
                        const EmptyState(text: 'No categories yet.'),
                      ...categories.map(
                        (category) => CategoryRow(
                          category: category,
                          onDelete: () async {
                            if (await confirm(
                                  context,
                                  'Delete or archive ${category.name}?',
                                ) !=
                                true) {
                              return;
                            }
                            await widget.session.api.deleteCategory(
                              category.id,
                            );
                            setState(() {
                              future = widget.session.api.categories();
                            });
                          },
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

  Future<void> addCategory() async {
    final created = await showDialog<Category>(
      context: context,
      builder: (_) => CategoryDialog(api: widget.session.api),
    );
    if (created != null) {
      setState(() {
        future = widget.session.api.categories();
      });
    }
  }
}

class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    required this.category,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onDelete;

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
          CategoryDot(category: category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  category.isArchived ? 'Archived' : category.icon ?? 'Active',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (category.isArchived)
            const TypeBadge(type: 'archived')
          else
            IconButton(
              tooltip: 'Delete or archive',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class CategoryDialog extends StatefulWidget {
  const CategoryDialog({super.key, required this.api});

  final ApiClient api;

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final name = TextEditingController();
  String selectedColor = '#0f766e';
  String selectedIcon = 'wallet';
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              CategoryStyleButton(
                title: 'Icon',
                value: categoryIconLabel(selectedIcon),
                leading: CategoryPreview(
                  color: selectedColor,
                  icon: selectedIcon,
                ),
                onTap: pickIcon,
              ),
              const SizedBox(height: 8),
              CategoryStyleButton(
                title: 'Color',
                value: selectedColor,
                leading: ColorPreview(color: selectedColor),
                onTap: pickColor,
              ),
              if (error != null) MessageBanner(text: error!, isError: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: busy ? null : save, child: const Text('Save')),
      ],
    );
  }

  Future<void> pickIcon() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => IconPickerDialog(
        selectedIcon: selectedIcon,
        selectedColor: selectedColor,
      ),
    );
    if (value == null) return;
    setState(() => selectedIcon = value);
  }

  Future<void> pickColor() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: selectedColor),
    );
    if (value == null) return;
    setState(() => selectedColor = value);
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final category = await widget.api.createCategory(
        name: name.text.trim(),
        color: selectedColor,
        icon: selectedIcon,
      );
      if (mounted) Navigator.pop(context, category);
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class CategoryStyleButton extends StatelessWidget {
  const CategoryStyleButton({
    super.key,
    required this.title,
    required this.value,
    required this.leading,
    required this.onTap,
  });

  final String title;
  final String value;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class CategoryPreview extends StatelessWidget {
  const CategoryPreview({super.key, required this.color, required this.icon});

  final String color;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: parseColor(color) ?? AppColors.teal,
      child: Icon(iconFor(icon), color: Colors.white, size: 20),
    );
  }
}

class ColorPreview extends StatelessWidget {
  const ColorPreview({super.key, required this.color});

  final String color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: parseColor(color) ?? AppColors.teal,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

class IconPickerDialog extends StatefulWidget {
  const IconPickerDialog({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
  });

  final String selectedIcon;
  final String selectedColor;

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = parseColor(widget.selectedColor) ?? AppColors.teal;
    final query = search.text.trim().toLowerCase();
    final options = query.isEmpty
        ? categoryIconOptions
        : categoryIconOptions.where((option) {
            return option.key.toLowerCase().contains(query) ||
                option.label.toLowerCase().contains(query);
          }).toList();

    return AlertDialog(
      title: const Text('Choose icon'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: search,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Search icons',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () => setState(search.clear),
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: options.isEmpty
                    ? const EmptyState(text: 'No icons found.')
                    : Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          for (final option in options)
                            Tooltip(
                              message: option.label,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.pop(context, option.key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: widget.selectedIcon == option.key
                                        ? color.withValues(alpha: 0.16)
                                        : AppColors.canvas,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: widget.selectedIcon == option.key
                                          ? color
                                          : AppColors.border.withValues(
                                              alpha: 0.6,
                                            ),
                                      width: widget.selectedIcon == option.key
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                  child: Icon(option.icon, color: color),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${options.length} icons',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({super.key, required this.initialColor});

  final String initialColor;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor hsv = HSVColor.fromColor(
    parseColor(widget.initialColor) ?? AppColors.teal,
  );

  Color get color => hsv.toColor();
  String get hex => colorToHex(color);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose color'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 86,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                hex,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ColorSlider(
              label: 'Hue',
              value: hsv.hue,
              max: 360,
              onChanged: (value) => setState(() {
                hsv = hsv.withHue(value);
              }),
            ),
            ColorSlider(
              label: 'Saturation',
              value: hsv.saturation,
              max: 1,
              onChanged: (value) => setState(() {
                hsv = hsv.withSaturation(value);
              }),
            ),
            ColorSlider(
              label: 'Brightness',
              value: hsv.value,
              max: 1,
              onChanged: (value) => setState(() {
                hsv = hsv.withValue(value);
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, hex),
          child: const Text('Use color'),
        ),
      ],
    );
  }
}

class ColorSlider extends StatelessWidget {
  const ColorSlider({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              max == 360 ? value.round().toString() : value.toStringAsFixed(2),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        Slider(value: value, max: max, onChanged: onChanged),
      ],
    );
  }
}

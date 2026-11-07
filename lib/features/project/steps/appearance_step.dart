import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/models.dart';

class AppearanceStep extends ConsumerWidget {
  const AppearanceStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectEditorProvider)!;
    final theme = project.theme;
    final layout = project.printLayout;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Appearance & print layout',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text(
          'The preview and exported PDF use the same embedded fonts and dimensions.',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Card style',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: theme.preset,
                  decoration: const InputDecoration(labelText: 'Preset'),
                  items:
                      const [
                            'Comfort',
                            'High contrast',
                            'Grayscale',
                            'Ink saver',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(projectEditorProvider.notifier)
                          .setTheme(_preset(value));
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: theme.fontFamily,
                  decoration: const InputDecoration(labelText: 'Font'),
                  items:
                      const [
                            'Atkinson Hyperlegible',
                            'Noto Sans',
                            'Roboto Slab',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(projectEditorProvider.notifier)
                          .setTheme(theme.copyWith(fontFamily: value));
                    }
                  },
                ),
                const SizedBox(height: 12),
                _ValueSlider(
                  label: 'Number size',
                  value: theme.fontSize,
                  min: 8,
                  max: 24,
                  divisions: 16,
                  suffix: 'pt',
                  onChanged: (value) => ref
                      .read(projectEditorProvider.notifier)
                      .setTheme(theme.copyWith(fontSize: value)),
                ),
                _ValueSlider(
                  label: 'Inner grid',
                  value: theme.lineWidth,
                  min: .5,
                  max: 3,
                  divisions: 10,
                  suffix: 'pt',
                  onChanged: (value) => ref
                      .read(projectEditorProvider.notifier)
                      .setTheme(theme.copyWith(lineWidth: value)),
                ),
                _ValueSlider(
                  label: 'Outer border',
                  value: theme.outerLineWidth,
                  min: .5,
                  max: 4,
                  divisions: 14,
                  suffix: 'pt',
                  onChanged: (value) => ref
                      .read(projectEditorProvider.notifier)
                      .setTheme(theme.copyWith(outerLineWidth: value)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ColorControl(
                      label: 'Background',
                      value: theme.backgroundColor,
                      onChanged: (value) => _setTheme(
                        ref,
                        theme.copyWith(backgroundColor: value),
                      ),
                    ),
                    _ColorControl(
                      label: 'Text',
                      value: theme.textColor,
                      onChanged: (value) =>
                          _setTheme(ref, theme.copyWith(textColor: value)),
                    ),
                    _ColorControl(
                      label: 'Grid',
                      value: theme.gridColor,
                      onChanged: (value) =>
                          _setTheme(ref, theme.copyWith(gridColor: value)),
                    ),
                    _ColorControl(
                      label: 'Header',
                      value: theme.headerColor,
                      onChanged: (value) =>
                          _setTheme(ref, theme.copyWith(headerColor: value)),
                    ),
                    _ColorControl(
                      label: 'Header text',
                      value: theme.headerTextColor,
                      onChanged: (value) => _setTheme(
                        ref,
                        theme.copyWith(headerTextColor: value),
                      ),
                    ),
                    _ColorControl(
                      label: 'Free cell',
                      value: theme.freeColor,
                      onChanged: (value) =>
                          _setTheme(ref, theme.copyWith(freeColor: value)),
                    ),
                    _ColorControl(
                      label: 'Accent',
                      value: theme.accentColor,
                      onChanged: (value) =>
                          _setTheme(ref, theme.copyWith(accentColor: value)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _editFreeLabel(context, ref, theme),
                  icon: const Icon(Icons.text_fields),
                  label: Text('Free cell label: ${theme.freeLabel}'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Page', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: layout.paper,
                        decoration: const InputDecoration(labelText: 'Paper'),
                        items: const ['A4', 'Letter']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            _setLayout(ref, layout.copyWith(paper: value)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: layout.orientation,
                        decoration: const InputDecoration(
                          labelText: 'Orientation',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'portrait',
                            child: Text('Portrait'),
                          ),
                          DropdownMenuItem(
                            value: 'landscape',
                            child: Text('Landscape'),
                          ),
                        ],
                        onChanged: (value) => _setLayout(
                          ref,
                          layout.copyWith(orientation: value),
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Exact physical card size'),
                  subtitle: Text(
                    layout.exactSize
                        ? '${layout.cardWidth} × ${layout.cardHeight} ${layout.unit}'
                        : 'Auto-fit to the page grid',
                  ),
                  value: layout.exactSize,
                  onChanged: (value) =>
                      _setLayout(ref, layout.copyWith(exactSize: value)),
                ),
                if (layout.exactSize)
                  OutlinedButton.icon(
                    onPressed: () => _editDimensions(context, ref, layout),
                    icon: const Icon(Icons.straighten),
                    label: const Text('Edit dimensions'),
                  ),
                _IntSlider(
                  label: 'Cards across',
                  value: layout.columns,
                  min: 1,
                  max: 3,
                  onChanged: (value) =>
                      _setLayout(ref, layout.copyWith(columns: value)),
                ),
                _ValueSlider(
                  label: 'Page margin',
                  value: layout.margin,
                  min: layout.unit == 'in' ? .1 : 3,
                  max: layout.unit == 'in' ? 1 : 25,
                  divisions: layout.unit == 'in' ? 18 : 22,
                  suffix: layout.unit,
                  onChanged: (value) =>
                      _setLayout(ref, layout.copyWith(margin: value)),
                ),
                _ValueSlider(
                  label: 'Card gutter',
                  value: layout.gutter,
                  min: layout.unit == 'in' ? 0 : 0,
                  max: layout.unit == 'in' ? .5 : 12,
                  divisions: 12,
                  suffix: layout.unit,
                  onChanged: (value) =>
                      _setLayout(ref, layout.copyWith(gutter: value)),
                ),
                _IntSlider(
                  label: 'Cards down',
                  value: layout.rows,
                  min: 1,
                  max: 4,
                  onChanged: (value) =>
                      _setLayout(ref, layout.copyWith(rows: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cut marks'),
                  value: layout.cutMarks,
                  onChanged: (value) =>
                      _setLayout(ref, layout.copyWith(cutMarks: value)),
                ),
                Text('${layout.cardsPerPage} card(s) per page'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _setTheme(WidgetRef ref, CardThemeConfig value) => ref
      .read(projectEditorProvider.notifier)
      .setTheme(value.copyWith(preset: 'Custom'));

  void _setLayout(WidgetRef ref, PrintLayoutConfig value) =>
      ref.read(projectEditorProvider.notifier).setPrintLayout(value);

  Future<void> _editFreeLabel(
    BuildContext context,
    WidgetRef ref,
    CardThemeConfig theme,
  ) async {
    final controller = TextEditingController(text: theme.freeLabel);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Free cell label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(labelText: 'Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      _setTheme(ref, theme.copyWith(freeLabel: value));
    }
  }

  Future<void> _editDimensions(
    BuildContext context,
    WidgetRef ref,
    PrintLayoutConfig layout,
  ) async {
    final width = TextEditingController(text: '${layout.cardWidth}');
    final height = TextEditingController(text: '${layout.cardHeight}');
    var unit = layout.unit;
    final result = await showDialog<PrintLayoutConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Exact card dimensions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'mm', label: Text('Millimeters')),
                  ButtonSegment(value: 'in', label: Text('Inches')),
                ],
                selected: {unit},
                onSelectionChanged: (value) {
                  final nextUnit = value.first;
                  if (nextUnit == unit) {
                    return;
                  }
                  final factor = nextUnit == 'in' ? 1 / 25.4 : 25.4;
                  width.text =
                      ((double.tryParse(width.text) ?? layout.cardWidth) *
                              factor)
                          .toStringAsFixed(nextUnit == 'in' ? 2 : 1);
                  height.text =
                      ((double.tryParse(height.text) ?? layout.cardHeight) *
                              factor)
                          .toStringAsFixed(nextUnit == 'in' ? 2 : 1);
                  setState(() => unit = nextUnit);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: width,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: 'Width ($unit)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: height,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: 'Height ($unit)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                layout.copyWith(
                  unit: unit,
                  cardWidth: double.tryParse(width.text),
                  cardHeight: double.tryParse(height.text),
                  margin: unit == layout.unit
                      ? layout.margin
                      : layout.margin * (unit == 'in' ? 1 / 25.4 : 25.4),
                  gutter: unit == layout.unit
                      ? layout.gutter
                      : layout.gutter * (unit == 'in' ? 1 / 25.4 : 25.4),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null) _setLayout(ref, result);
  }

  CardThemeConfig _preset(String name) => switch (name) {
    'High contrast' => const CardThemeConfig(
      preset: 'High contrast',
      fontFamily: 'Atkinson Hyperlegible',
      fontSize: 15,
      lineWidth: 1.5,
      outerLineWidth: 2,
      backgroundColor: 0xFFFFFFFF,
      textColor: 0xFF000000,
      gridColor: 0xFF000000,
      headerColor: 0xFF102A43,
      headerTextColor: 0xFFFFFFFF,
      freeColor: 0xFFFFD166,
      accentColor: 0xFF005A9C,
    ),
    'Grayscale' => const CardThemeConfig(
      preset: 'Grayscale',
      fontFamily: 'Noto Sans',
      fontSize: 14,
      lineWidth: 1,
      outerLineWidth: 1.5,
      backgroundColor: 0xFFFFFFFF,
      textColor: 0xFF222222,
      gridColor: 0xFF555555,
      headerColor: 0xFFE0E0E0,
      headerTextColor: 0xFF111111,
      freeColor: 0xFFF2F2F2,
      accentColor: 0xFF444444,
    ),
    'Ink saver' => const CardThemeConfig(
      preset: 'Ink saver',
      fontFamily: 'Atkinson Hyperlegible',
      fontSize: 14,
      lineWidth: .7,
      outerLineWidth: 1,
      backgroundColor: 0xFFFFFFFF,
      textColor: 0xFF111111,
      gridColor: 0xFF777777,
      headerColor: 0xFFFFFFFF,
      headerTextColor: 0xFF111111,
      freeColor: 0xFFF5F5F5,
      accentColor: 0xFF555555,
    ),
    _ => CardThemeConfig.comfort(),
  };
}

class _ValueSlider extends StatelessWidget {
  const _ValueSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 112,
        child: Text('$label: ${value.toStringAsFixed(1)}$suffix'),
      ),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

class _IntSlider extends StatelessWidget {
  const _IntSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 112, child: Text('$label: $value')),
      Expanded(
        child: Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (next) => onChanged(next.round()),
        ),
      ),
    ],
  );
}

class _ColorControl extends StatelessWidget {
  const _ColorControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: CircleAvatar(backgroundColor: Color(value)),
    label: Text(label),
    onPressed: () async {
      final controller = TextEditingController(
        text: value
            .toRadixString(16)
            .padLeft(8, '0')
            .substring(2)
            .toUpperCase(),
      );
      final result = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$label color'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9A-Fa-f]')),
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              prefixText: '#',
              labelText: 'Hex RGB',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text, radix: 16);
                Navigator.pop(
                  context,
                  parsed == null ? null : 0xFF000000 | parsed,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (result != null) onChanged(result);
    },
  );
}

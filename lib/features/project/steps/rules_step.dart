import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/models.dart';

class RulesStep extends ConsumerWidget {
  const RulesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectEditorProvider)!;
    final rules = project.rules;
    final hasSavedGames =
        ref.watch(playSessionsProvider(project.id)).asData?.value.isNotEmpty ??
        false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('Game rules', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
          'Cards are grouped into independent sets of six for each game.',
        ),
        const SizedBox(height: 20),
        if (hasSavedGames) ...[
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Changing card count or rules will end saved games for this project.',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Number of cards',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${project.cardCount}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                Slider(
                  value: project.cardCount.toDouble(),
                  min: 1,
                  max: 18,
                  divisions: 17,
                  label: '${project.cardCount}',
                  onChanged: (value) => ref
                      .read(projectEditorProvider.notifier)
                      .setCardCount(value.round()),
                ),
                Text(
                  '${(project.cardCount / 6).ceil()} set${project.cardCount > 6 ? 's' : ''} to print',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              label: Text('75-ball'),
              icon: Icon(Icons.grid_4x4),
            ),
            ButtonSegment(
              value: false,
              label: Text('Custom'),
              icon: Icon(Icons.dashboard_customize),
            ),
          ],
          selected: {rules.isStandard75},
          onSelectionChanged: (selection) {
            final standard = selection.first;
            ref
                .read(projectEditorProvider.notifier)
                .setRules(standard ? RuleSet.standard75() : RuleSet.custom());
          },
        ),
        const SizedBox(height: 16),
        if (rules.isStandard75)
          const _StandardSummary()
        else
          _CustomRuleEditor(rules: rules),
      ],
    );
  }
}

class _StandardSummary extends StatelessWidget {
  const _StandardSummary();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Standard 5×5 B-I-N-G-O',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('B 1–15  ·  I 16–30  ·  N 31–45  ·  G 46–60  ·  O 61–75'),
          const SizedBox(height: 4),
          const Text('Center cell is free.'),
        ],
      ),
    ),
  );
}

class _CustomRuleEditor extends ConsumerWidget {
  const _CustomRuleEditor({required this.rules});

  final RuleSet rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = rules.validate();
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DimensionSlider(
                  label: 'Rows',
                  value: rules.rows,
                  onChanged: (value) => _resize(ref, rows: value),
                ),
                _DimensionSlider(
                  label: 'Columns',
                  value: rules.columns,
                  onChanged: (value) => _resize(ref, columns: value),
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
                Text(
                  'Column ranges',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < rules.columns; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${rules.columnLabels[i]} · ${rules.columnRanges[i].start}–${rules.columnRanges[i].end}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editColumn(context, ref, i),
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
                Text(
                  'Free cells',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('Tap cells that should be automatically covered.'),
                const SizedBox(height: 12),
                _FreeCellGrid(rules: rules),
              ],
            ),
          ),
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [for (final error in errors) Text(error)],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _resize(WidgetRef ref, {int? rows, int? columns}) {
    ref
        .read(projectEditorProvider.notifier)
        .setRules(
          RuleSet.custom(
            rows: rows ?? rules.rows,
            columns: columns ?? rules.columns,
          ),
        );
  }

  Future<void> _editColumn(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    final label = TextEditingController(text: rules.columnLabels[index]);
    final start = TextEditingController(
      text: '${rules.columnRanges[index].start}',
    );
    final end = TextEditingController(text: '${rules.columnRanges[index].end}');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Column ${index + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: start,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'First number',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: end,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Last number'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final labels = List<String>.from(rules.columnLabels);
    final ranges = List<NumberRange>.from(rules.columnRanges);
    labels[index] = label.text.trim().isEmpty
        ? '${index + 1}'
        : label.text.trim();
    ranges[index] = NumberRange(
      start: int.tryParse(start.text) ?? ranges[index].start,
      end: int.tryParse(end.text) ?? ranges[index].end,
    );
    await ref
        .read(projectEditorProvider.notifier)
        .setRules(rules.copyWith(columnLabels: labels, columnRanges: ranges));
  }
}

class _DimensionSlider extends StatelessWidget {
  const _DimensionSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 72, child: Text('$label: $value')),
      Expanded(
        child: Slider(
          value: value.toDouble(),
          min: 3,
          max: 7,
          divisions: 4,
          onChanged: (next) => onChanged(next.round()),
        ),
      ),
    ],
  );
}

class _FreeCellGrid extends ConsumerWidget {
  const _FreeCellGrid({required this.rules});

  final RuleSet rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AspectRatio(
    aspectRatio: rules.columns / rules.rows,
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: rules.columns,
      ),
      itemCount: rules.rows * rules.columns,
      itemBuilder: (context, index) {
        final position = CellPosition(
          index ~/ rules.columns,
          index % rules.columns,
        );
        final selected = rules.freeCells.contains(position);
        return InkWell(
          onTap: () {
            final cells = Set<CellPosition>.from(rules.freeCells);
            selected ? cells.remove(position) : cells.add(position);
            ref
                .read(projectEditorProvider.notifier)
                .setRules(rules.copyWith(freeCells: cells));
          },
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.white,
              border: Border.all(color: Colors.blueGrey),
            ),
            child: Center(
              child: Text(
                selected
                    ? 'FREE'
                    : '${position.row + 1},${position.column + 1}',
              ),
            ),
          ),
        );
      },
    ),
  );
}

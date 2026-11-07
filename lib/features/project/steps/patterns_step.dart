import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../domain/models.dart';
import '../../../domain/pattern_service.dart';

class PatternsStep extends ConsumerWidget {
  const PatternsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectEditorProvider)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Winning patterns',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text(
                    'The optimizer diversifies the numbered cells in these masks.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Pattern'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (project.patterns.isEmpty)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add at least one winning pattern before generating cards.',
              ),
            ),
          ),
        for (final pattern in project.patterns) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: SizedBox(
                width: 52,
                height: 52,
                child: _MiniPattern(pattern: pattern, rules: project.rules),
              ),
              title: Text(
                pattern.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${pattern.cells.length} cells · '
                '${const PatternService().expand(pattern, project.rules).length} variant(s)',
              ),
              onTap: () => _edit(context, ref, pattern),
              trailing: IconButton(
                tooltip: 'Delete pattern',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  final updated = project.patterns
                      .where((item) => item.id != pattern.id)
                      .toList();
                  ref.read(projectEditorProvider.notifier).setPatterns(updated);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    PatternDefinition? existing,
  ) async {
    final project = ref.read(projectEditorProvider)!;
    final name = TextEditingController(text: existing?.name ?? 'My pattern');
    var cells = Set<CellPosition>.from(existing?.cells ?? const {});
    var rotations = existing?.includeRotations ?? false;
    var reflections = existing?.includeReflections ?? false;
    final result = await showDialog<PatternDefinition>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New pattern' : 'Edit pattern'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: project.rules.columns / project.rules.rows,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: project.rules.columns,
                      ),
                      itemCount: project.rules.rows * project.rules.columns,
                      itemBuilder: (_, index) {
                        final position = CellPosition(
                          index ~/ project.rules.columns,
                          index % project.rules.columns,
                        );
                        final selected = cells.contains(position);
                        return InkWell(
                          onTap: () => setDialogState(() {
                            selected
                                ? cells.remove(position)
                                : cells.add(position);
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surface,
                              border: Border.all(color: Colors.blueGrey),
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include rotations'),
                    subtitle: Text(
                      project.rules.rows == project.rules.columns
                          ? 'Includes 90°, 180°, and 270° variants.'
                          : 'Includes the dimension-preserving 180° variant.',
                    ),
                    value: rotations,
                    onChanged: (value) =>
                        setDialogState(() => rotations = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include mirrors'),
                    value: reflections,
                    onChanged: (value) =>
                        setDialogState(() => reflections = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: cells.isEmpty || name.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      PatternDefinition(
                        id: existing?.id ?? const Uuid().v4(),
                        name: name.text.trim(),
                        cells: cells,
                        includeRotations: rotations,
                        includeReflections: reflections,
                      ),
                    ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final patterns = List<PatternDefinition>.from(project.patterns);
    final index = patterns.indexWhere((pattern) => pattern.id == result.id);
    if (index < 0) {
      patterns.add(result);
    } else {
      patterns[index] = result;
    }
    await ref.read(projectEditorProvider.notifier).setPatterns(patterns);
  }
}

class _MiniPattern extends StatelessWidget {
  const _MiniPattern({required this.pattern, required this.rules});

  final PatternDefinition pattern;
  final RuleSet rules;

  @override
  Widget build(BuildContext context) => GridView.builder(
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: rules.columns,
    ),
    itemCount: rules.rows * rules.columns,
    itemBuilder: (_, index) {
      final position = CellPosition(
        index ~/ rules.columns,
        index % rules.columns,
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          color: pattern.cells.contains(position)
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          border: Border.all(color: Colors.blueGrey.shade200, width: .5),
        ),
      );
    },
  );
}

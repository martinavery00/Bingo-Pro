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
    final hasSavedGames =
        ref.watch(playSessionsProvider(project.id)).asData?.value.isNotEmpty ??
        false;
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
        if (hasSavedGames) ...[
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Changing winning patterns will end saved games for this project.',
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
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
    final result = await showDialog<PatternDefinition>(
      context: context,
      builder: (context) =>
          PatternEditorDialog(rules: project.rules, existing: existing),
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

class PatternEditorDialog extends StatefulWidget {
  const PatternEditorDialog({required this.rules, this.existing, super.key});

  final RuleSet rules;
  final PatternDefinition? existing;

  @override
  State<PatternEditorDialog> createState() => _PatternEditorDialogState();
}

class _PatternEditorDialogState extends State<PatternEditorDialog> {
  late final TextEditingController _name;
  late Set<CellPosition> _cells;
  late bool _rotations;
  late bool _reflections;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? 'My pattern');
    _cells = Set<CellPosition>.from(widget.existing?.cells ?? const {});
    _rotations = widget.existing?.includeRotations ?? false;
    _reflections = widget.existing?.includeReflections ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewPattern = PatternDefinition(
      id: widget.existing?.id ?? 'preview',
      name: _name.text,
      cells: _cells,
      includeRotations: _rotations,
      includeReflections: _reflections,
    );
    final variants = const PatternService().expandVariants(
      previewPattern,
      widget.rules,
    );

    return AlertDialog(
      title: Text(widget.existing == null ? 'New pattern' : 'Edit pattern'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: widget.rules.columns / widget.rules.rows,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.rules.columns,
                  ),
                  itemCount: widget.rules.rows * widget.rules.columns,
                  itemBuilder: (_, index) {
                    final position = CellPosition(
                      index ~/ widget.rules.columns,
                      index % widget.rules.columns,
                    );
                    final selected = _cells.contains(position);
                    return InkWell(
                      key: ValueKey('pattern-cell-$index'),
                      onTap: () => setState(() {
                        selected
                            ? _cells.remove(position)
                            : _cells.add(position);
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
                                color: Theme.of(context).colorScheme.onPrimary,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              SwitchListTile(
                key: const ValueKey('include-rotations'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Include rotations'),
                subtitle: Text(
                  widget.rules.rows == widget.rules.columns
                      ? 'Includes 90°, 180°, and 270° variants.'
                      : 'Includes the dimension-preserving 180° variant.',
                ),
                value: _rotations,
                onChanged: (value) => setState(() => _rotations = value),
              ),
              SwitchListTile(
                key: const ValueKey('include-mirrors'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Include mirrors'),
                value: _reflections,
                onChanged: (value) => setState(() => _reflections = value),
              ),
              const SizedBox(height: 8),
              _PatternVariantsPreview(
                rules: widget.rules,
                variants: _cells.isEmpty ? const [] : variants,
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
          onPressed: _cells.isEmpty || _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  PatternDefinition(
                    id: widget.existing?.id ?? const Uuid().v4(),
                    name: _name.text.trim(),
                    cells: _cells,
                    includeRotations: _rotations,
                    includeReflections: _reflections,
                  ),
                ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PatternVariantsPreview extends StatelessWidget {
  const _PatternVariantsPreview({required this.rules, required this.variants});

  final RuleSet rules;
  final List<PatternVariant> variants;

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) {
      return const Text('Select cells to preview variants.');
    }
    final count = variants.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Variants ($count unique ${count == 1 ? 'variant' : 'variants'})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 108,
          child: ListView.separated(
            key: const ValueKey('pattern-variants-list'),
            scrollDirection: Axis.horizontal,
            itemCount: variants.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final variant = variants[index];
              final label = _transformLabel(variant.transform);
              return Semantics(
                label: '$label pattern preview',
                child: SizedBox(
                  width: 104,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: _PatternGrid(cells: variant.cells, rules: rules),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _transformLabel(PatternTransform transform) => switch (transform) {
    PatternTransform.original => 'Original',
    PatternTransform.rotate90 => '90°',
    PatternTransform.rotate180 => '180°',
    PatternTransform.rotate270 => '270°',
    PatternTransform.mirror => 'Mirror',
    PatternTransform.mirrorRotate90 => 'Mirror + 90°',
    PatternTransform.mirrorRotate180 => 'Mirror + 180°',
    PatternTransform.mirrorRotate270 => 'Mirror + 270°',
  };
}

class _MiniPattern extends StatelessWidget {
  const _MiniPattern({required this.pattern, required this.rules});

  final PatternDefinition pattern;
  final RuleSet rules;

  @override
  Widget build(BuildContext context) =>
      _PatternGrid(cells: pattern.cells, rules: rules);
}

class _PatternGrid extends StatelessWidget {
  const _PatternGrid({required this.cells, required this.rules});

  final Set<CellPosition> cells;
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
          color: cells.contains(position)
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          border: Border.all(color: Colors.blueGrey.shade200, width: .5),
        ),
      );
    },
  );
}

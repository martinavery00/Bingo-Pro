import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/models.dart';
import '../card_viewer_screen.dart';
import '../pdf_preview_screen.dart';
import '../widgets/virtual_bingo_card.dart';

enum _GenerationAction { newBatch, repeatSeed }

class CardsStep extends ConsumerStatefulWidget {
  const CardsStep({super.key});

  @override
  ConsumerState<CardsStep> createState() => _CardsStepState();
}

class _CardsStepState extends ConsumerState<CardsStep> {
  var _working = false;
  var _editLocks = false;
  var _selectedSet = 1;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectEditorProvider)!;
    final errors = _validationErrors(project);
    if (project.cards.isEmpty) {
      return _EmptyCards(
        project: project,
        errors: errors,
        working: _working,
        error: _error,
        onGenerate: () => _generate(keepSeed: false),
      );
    }

    final sets = project.cards.map((card) => card.setIndex).toSet().toList()
      ..sort();
    final selectedSet = sets.contains(_selectedSet) ? _selectedSet : sets.first;
    final visibleCards =
        project.cards.where((card) => card.setIndex == selectedSet).toList()
          ..sort((a, b) => a.cardIndex.compareTo(b.cardIndex));

    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        key: const ValueKey('cards-workspace'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${project.cards.length} cards',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      _editLocks
                          ? 'Edit locks is on. Protected content survives regeneration.'
                          : 'Choose a card to open the screen-optimized viewer.',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                key: const ValueKey('print-cards'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PdfPreviewScreen(project: project),
                  ),
                ),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                key: const ValueKey('edit-locks'),
                selected: _editLocks,
                avatar: Icon(_editLocks ? Icons.lock : Icons.lock_outline),
                label: Text(_editLocks ? 'Done editing locks' : 'Edit locks'),
                onSelected: (value) => setState(() => _editLocks = value),
              ),
              if (_editLocks)
                FilledButton.icon(
                  key: const ValueKey('regenerate-unlocked'),
                  onPressed: _working ? null : _regenerateUnlocked,
                  icon: _working
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Regenerate all unlocked content'),
                )
              else
                PopupMenuButton<_GenerationAction>(
                  key: const ValueKey('generation-actions'),
                  tooltip: 'Generation actions',
                  onSelected: _handleGenerationAction,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _GenerationAction.newBatch,
                      child: ListTile(
                        leading: Icon(Icons.auto_awesome),
                        title: Text('Generate new batch'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _GenerationAction.repeatSeed,
                      child: ListTile(
                        leading: Icon(Icons.replay),
                        title: Text('Repeat saved seed'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.more_horiz),
                    label: Text('Generation'),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorCard(message: _error!),
          ],
          if (sets.length > 1) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                key: const ValueKey('set-selector'),
                segments: [
                  for (final set in sets)
                    ButtonSegment(value: set, label: Text('Set $set')),
                ],
                selected: {selectedSet},
                onSelectionChanged: (selection) => setState(() {
                  _selectedSet = selection.first;
                }),
              ),
            ),
          ],
          const SizedBox(height: 12),
          GridView.builder(
            key: ValueKey('card-grid-set-$selectedSet'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: constraints.maxWidth >= 720 ? 340 : 280,
              childAspectRatio:
                  (project.rules.columns / (project.rules.rows + 1.75)).clamp(
                    .55,
                    1.35,
                  ),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: visibleCards.length,
            itemBuilder: (context, index) {
              final card = visibleCards[index];
              final globalIndex = project.cards.indexWhere(
                (candidate) => candidate.id == card.id,
              );
              return _CardTile(
                card: card,
                rules: project.rules,
                editLocks: _editLocks,
                onOpen: () => _openCard(card, selectedSet),
                onToggleCardLock: globalIndex < 0
                    ? null
                    : () => ref
                          .read(projectEditorProvider.notifier)
                          .toggleCardLock(globalIndex),
              );
            },
          ),
          const SizedBox(height: 16),
          if (project.report case final report?)
            Card(
              child: ExpansionTile(
                key: const ValueKey('coverage-summary'),
                title: Text(
                  'Coverage score ${report.score.toStringAsFixed(0)}/100',
                ),
                subtitle: const Text('Coverage and overlap details'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  LinearProgressIndicator(
                    value: report.score / 100,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Average card overlap: '
                      '${(report.pairwiseOverlap * 100).toStringAsFixed(1)}%',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pattern overlap: '
                      '${(report.patternOverlap * 100).toStringAsFixed(1)}%',
                    ),
                  ),
                  for (final warning in report.warnings)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        warning,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<String> _validationErrors(BingoProject project) {
    final errors = project.rules.validate();
    if (project.patterns.isEmpty) {
      errors.add('Add at least one winning pattern.');
    }
    return errors;
  }

  Future<void> _openCard(BingoCard card, int setIndex) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardViewerScreen(
          setIndex: setIndex,
          initialCardId: card.id,
          editLocks: _editLocks,
        ),
      ),
    );
  }

  Future<void> _handleGenerationAction(_GenerationAction action) async {
    final repeat = action == _GenerationAction.repeatSeed;
    final confirmed = await _confirmReplacement(
      title: repeat ? 'Repeat saved seed?' : 'Generate a new batch?',
      message: repeat
          ? 'All unlocked content will be rebuilt from the saved seed. Locks will be preserved.'
          : 'All unlocked content in every set will be replaced using a new seed. Locks will be preserved.',
      action: repeat ? 'Repeat seed' : 'Generate',
    );
    if (confirmed) await _generate(keepSeed: repeat);
  }

  Future<void> _regenerateUnlocked() async {
    final confirmed = await _confirmReplacement(
      title: 'Regenerate unlocked content?',
      message: 'Unlocked content in every set will be replaced using a new seed. All card and cell locks will be preserved.',
      action: 'Regenerate',
    );
    if (confirmed) {
      await _generate(keepSeed: false);
      if (mounted && _error == null) setState(() => _editLocks = false);
    }
  }

  Future<bool> _confirmReplacement({
    required String title,
    required String message,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _generate({required bool keepSeed}) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref
          .read(projectEditorProvider.notifier)
          .generate(keepSeed: keepSeed);
    } catch (error) {
      if (mounted) setState(() => _error = 'Generation failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({
    required this.project,
    required this.errors,
    required this.working,
    required this.error,
    required this.onGenerate,
  });

  final BingoProject project;
  final List<String> errors;
  final bool working;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('empty-cards'),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    children: [
      Text('Cards', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      const Text(
        'Generate diversified sets, then inspect them in a screen-optimized viewer or open the print-faithful PDF preview.',
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _SummaryRow(label: 'Cards', value: '${project.cardCount}'),
              _SummaryRow(
                label: 'Sets',
                value: '${(project.cardCount / 6).ceil()}',
              ),
              _SummaryRow(label: 'Rules', value: project.rules.name),
              _SummaryRow(
                label: 'Patterns',
                value: '${project.patterns.length}',
              ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final message in errors) Text('• $message')],
            ),
          ),
        ),
      ],
      if (error != null) ...[
        const SizedBox(height: 12),
        _ErrorCard(message: error!),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        key: const ValueKey('generate-cards'),
        onPressed: working || errors.isNotEmpty ? null : onGenerate,
        icon: working
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(working ? 'Generating…' : 'Generate cards'),
      ),
    ],
  );
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.rules,
    required this.editLocks,
    required this.onOpen,
    required this.onToggleCardLock,
  });

  final BingoCard card;
  final RuleSet rules;
  final bool editLocks;
  final VoidCallback onOpen;
  final VoidCallback? onToggleCardLock;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('card-tile-${card.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${card.displayId} · ${card.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (editLocks)
                  IconButton(
                    key: ValueKey('card-lock-${card.id}'),
                    tooltip: card.isLocked
                        ? 'Unlock whole card'
                        : 'Lock whole card',
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleCardLock,
                    icon: Icon(card.isLocked ? Icons.lock : Icons.lock_open),
                  )
                else
                  const Icon(Icons.open_in_full, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: VirtualBingoCard(card: card, rules: rules),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

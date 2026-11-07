import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

class GenerateStep extends ConsumerStatefulWidget {
  const GenerateStep({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  ConsumerState<GenerateStep> createState() => _GenerateStepState();
}

class _GenerateStepState extends ConsumerState<GenerateStep> {
  var _working = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectEditorProvider)!;
    final errors = project.rules.validate();
    if (project.patterns.isEmpty) {
      errors.add('Add at least one winning pattern.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Generate diversified sets',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Bingo Pro balances number use and reduces overlap between the six cards played together. '
          'It does not guarantee a win or make any single card luckier.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                _SummaryRow(label: 'Seed', value: '${project.seed}'),
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
                children: [for (final error in errors) Text('• $error')],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _working || errors.isNotEmpty
              ? null
              : () => _generate(false),
          icon: _working
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            project.cards.isEmpty ? 'Generate cards' : 'Generate a new batch',
          ),
        ),
        if (project.cards.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _working ? null : () => _generate(true),
            icon: const Icon(Icons.replay),
            label: const Text('Repeat saved seed'),
          ),
          const SizedBox(height: 20),
          _ReportCard(onContinue: widget.onContinue),
        ],
      ],
    );
  }

  Future<void> _generate(bool keepSeed) async {
    setState(() => _working = true);
    try {
      await ref
          .read(projectEditorProvider.notifier)
          .generate(keepSeed: keepSeed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Generation failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }
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

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(projectEditorProvider)!.report!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coverage score',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  report.score.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.displayMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('/100'),
                ),
              ],
            ),
            LinearProgressIndicator(value: report.score / 100, minHeight: 10),
            const SizedBox(height: 12),
            Text(
              'Average card overlap: ${(report.pairwiseOverlap * 100).toStringAsFixed(1)}%',
            ),
            Text(
              'Pattern overlap: ${(report.patternOverlap * 100).toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 8),
            for (final warning in report.warnings)
              Text(warning, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.grid_view),
              label: const Text('Review cards'),
            ),
          ],
        ),
      ),
    );
  }
}

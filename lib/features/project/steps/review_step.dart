import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../pdf_preview_screen.dart';
import '../widgets/bingo_card_preview.dart';

class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectEditorProvider)!;
    if (project.cards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Generate cards first, then return here to lock, review, and print them.',
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${project.cards.length} cards',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Text('Tap a number to lock it before regenerating.'),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PdfPreviewScreen(project: project),
                  ),
                ),
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              childAspectRatio: .88,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: project.cards.length,
            itemBuilder: (context, index) {
              final card = project.cards[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${card.displayId} · ${card.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: card.isLocked
                                ? 'Unlock whole card'
                                : 'Lock whole card',
                            icon: Icon(
                              card.isLocked ? Icons.lock : Icons.lock_open,
                            ),
                            onPressed: () => ref
                                .read(projectEditorProvider.notifier)
                                .toggleCardLock(index),
                          ),
                        ],
                      ),
                      Expanded(
                        child: BingoCardPreview(
                          card: card,
                          rules: project.rules,
                          theme: project.theme,
                          onCellTap: (position) => ref
                              .read(projectEditorProvider.notifier)
                              .toggleCellLock(index, position),
                        ),
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
}

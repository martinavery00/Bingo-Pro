import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../project/widgets/virtual_bingo_card.dart';

class CardViewerScreen extends ConsumerStatefulWidget {
  const CardViewerScreen({
    required this.setIndex,
    required this.initialCardId,
    required this.editLocks,
    super.key,
  });

  final int setIndex;
  final String initialCardId;
  final bool editLocks;

  @override
  ConsumerState<CardViewerScreen> createState() => _CardViewerScreenState();
}

class _CardViewerScreenState extends ConsumerState<CardViewerScreen> {
  late final PageController _controller;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    final project = ref.read(projectEditorProvider)!;
    final cards = project.cards
        .where((card) => card.setIndex == widget.setIndex)
        .toList();
    _page = cards.indexWhere((card) => card.id == widget.initialCardId);
    if (_page < 0) _page = 0;
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectEditorProvider)!;
    final cards = project.cards
        .where((card) => card.setIndex == widget.setIndex)
        .toList();
    if (cards.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final page = _page.clamp(0, cards.length - 1);
    final current = cards[page];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Set ${widget.setIndex} · Card ${page + 1} of ${cards.length}',
        ),
        actions: [
          IconButton(
            tooltip: 'Return to card overview',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.grid_view_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.editLocks)
            MaterialBanner(
              content: const Text(
                'Edit locks is on. Tap a numbered cell to lock or unlock it.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          Expanded(
            child: PageView.builder(
              key: const ValueKey('focused-card-pages'),
              controller: _controller,
              itemCount: cards.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final card = cards[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio:
                          project.rules.columns / (project.rules.rows + .8),
                      child: VirtualBingoCard(
                        key: ValueKey('focused-card-${card.id}'),
                        card: card,
                        rules: project.rules,
                        onCellTap: widget.editLocks
                            ? (position) {
                                final globalIndex = project.cards.indexWhere(
                                  (candidate) => candidate.id == card.id,
                                );
                                if (globalIndex >= 0) {
                                  ref
                                      .read(projectEditorProvider.notifier)
                                      .toggleCellLock(globalIndex, position);
                                }
                              }
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '${current.displayId} · ${current.id}',
                key: const ValueKey('focused-card-identity'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

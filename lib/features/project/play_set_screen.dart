import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../domain/play_session.dart';
import 'widgets/virtual_bingo_card.dart';

class PlaySetScreen extends ConsumerStatefulWidget {
  const PlaySetScreen({required this.setIndex, super.key});

  final int setIndex;

  @override
  ConsumerState<PlaySetScreen> createState() => _PlaySetScreenState();
}

class _PlaySetScreenState extends ConsumerState<PlaySetScreen> {
  PlaySession? _session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession());
  }

  Future<void> _loadSession() async {
    final project = ref.read(projectEditorProvider)!;
    final repository = ref.read(playSessionRepositoryProvider);
    final signature = playSourceSignature(project, widget.setIndex);
    var session = await repository.find(project.id, widget.setIndex);
    if (!mounted) return;
    if (session != null && session.sourceSignature != signature) {
      final replace = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Cards changed'),
          content: const Text(
            'This saved game belongs to an earlier version of this set. Start a new game with the current cards?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start new game'),
            ),
          ],
        ),
      );
      if (replace != true) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      session = null;
    }
    session ??= PlaySession(
      projectId: project.id,
      setIndex: widget.setIndex,
      sourceSignature: signature,
      calledNumbers: const [],
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.save(session);
    if (mounted) setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectEditorProvider)!;
    final cards =
        project.cards.where((card) => card.setIndex == widget.setIndex).toList()
          ..sort((a, b) => a.cardIndex.compareTo(b.cardIndex));
    final session = _session;
    if (session == null || cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Play · Set ${widget.setIndex}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final evaluation = const PlayEvaluator().evaluate(
      rules: project.rules,
      patterns: project.patterns,
      cards: cards,
      calledNumbers: session.calledNumbers,
    );
    final latest = session.calledNumbers.lastOrNull;

    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Play · Set ${widget.setIndex}'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Game actions',
              onSelected: (value) {
                if (value == 'restart') _startOver();
                if (value == 'end') _endGame();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'restart', child: Text('Start over')),
                PopupMenuItem(value: 'end', child: Text('End game')),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                key: ValueKey('play-numbers-tab'),
                icon: Icon(Icons.dialpad_outlined),
                text: 'Numbers',
              ),
              Tab(
                key: ValueKey('play-cards-tab'),
                icon: Icon(Icons.grid_view_outlined),
                text: 'Cards',
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _NumbersView(
                rules: project.rules,
                session: session,
                evaluation: evaluation,
                onNumberTap: _toggleBoardNumber,
              ),
              _CardsOverview(
                cards: cards,
                rules: project.rules,
                evaluation: evaluation,
                latestCalledNumber: latest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBoardNumber(int number) async {
    final session = _session!;
    if (session.calledNumbers.contains(number)) {
      final index = session.calledNumbers.indexOf(number);
      final updated = List<int>.from(session.calledNumbers)..removeAt(index);
      await _saveCalls(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$number removed from called numbers.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              final restored = List<int>.from(_session!.calledNumbers);
              restored.insert(index.clamp(0, restored.length), number);
              _saveCalls(restored);
            },
          ),
        ),
      );
      return;
    }
    await _addNumber(number);
  }

  Future<void> _addNumber(int number) async {
    final project = ref.read(projectEditorProvider)!;
    final cards = project.cards
        .where((card) => card.setIndex == widget.setIndex)
        .toList();
    final before = const PlayEvaluator().evaluate(
      rules: project.rules,
      patterns: project.patterns,
      cards: cards,
      calledNumbers: _session!.calledNumbers,
    );
    final updated = [..._session!.calledNumbers, number];
    await _saveCalls(updated);
    if (!mounted) return;
    final after = const PlayEvaluator().evaluate(
      rules: project.rules,
      patterns: project.patterns,
      cards: cards,
      calledNumbers: updated,
    );
    final oldWins = before.completedPatterns
        .map((result) => result.identity)
        .toSet();
    final newWins = after.completedPatterns
        .where((result) => !oldWins.contains(result.identity))
        .toList();
    if (newWins.isNotEmpty) {
      HapticFeedback.mediumImpact();
      await _showBingo(newWins);
    }
  }

  Future<void> _saveCalls(List<int> numbers) async {
    final updated = _session!.copyWith(
      calledNumbers: numbers,
      updatedAt: DateTime.now(),
    );
    setState(() => _session = updated);
    await ref.read(playSessionRepositoryProvider).save(updated);
  }

  Future<void> _showBingo(List<PlayPatternResult> wins) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      icon: const Icon(Icons.emoji_events, size: 54),
      title: const Text('Bingo!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final win in wins)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle),
              title: Text(win.cardDisplayId),
              subtitle: Text(win.variantLabel),
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continue playing'),
        ),
      ],
    ),
  );

  Future<void> _startOver() async {
    final confirmed = await _confirm(
      'Start over?',
      'All called numbers for Set ${widget.setIndex} will be cleared.',
      'Start over',
    );
    if (confirmed) await _saveCalls(const []);
  }

  Future<void> _endGame() async {
    final confirmed = await _confirm(
      'End game?',
      'Saved progress for Set ${widget.setIndex} will be deleted.',
      'End game',
    );
    if (!confirmed) return;
    final project = ref.read(projectEditorProvider)!;
    await ref
        .read(playSessionRepositoryProvider)
        .delete(project.id, widget.setIndex);
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirm(String title, String message, String action) async =>
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
}

class _NumbersView extends StatelessWidget {
  const _NumbersView({
    required this.rules,
    required this.session,
    required this.evaluation,
    required this.onNumberTap,
  });

  final RuleSet rules;
  final PlaySession session;
  final PlayEvaluation evaluation;
  final ValueChanged<int> onNumberTap;

  @override
  Widget build(BuildContext context) {
    final latest = session.calledNumbers.lastOrNull;
    final puroNumbers = evaluation.oneAwayPatterns
        .map((result) => result.missingNumbers.single.value)
        .toSet();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${session.calledNumbers.length} called',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (latest != null)
                ActionChip(
                  key: const ValueKey('called-number-history-action'),
                  tooltip: 'View called-number history',
                  avatar: const Icon(Icons.history, size: 17),
                  label: Text('Last ${_numberLabel(rules, latest)}'),
                  onPressed: () => _showCalledNumberHistory(
                    context,
                    rules: rules,
                    calledNumbers: session.calledNumbers,
                  ),
                ),
            ],
          ),
          if (evaluation.completedPatterns.isNotEmpty) ...[
            const SizedBox(height: 6),
            _CompletedBanner(results: evaluation.completedPatterns),
          ],
          const SizedBox(height: 6),
          Expanded(
            child: _FullNumberBoard(
              rules: rules,
              calledNumbers: session.calledNumbers.toSet(),
              puroNumbers: puroNumbers,
              latestCalledNumber: latest,
              onNumberTap: onNumberTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({required this.results});

  final List<PlayPatternResult> results;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('completed-patterns-banner'),
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.emoji_events),
      title: Text(
        '${results.length} completed pattern${results.length == 1 ? '' : 's'}',
      ),
      subtitle: Text(
        results
            .take(2)
            .map((result) => '${result.cardDisplayId} · ${result.variantLabel}')
            .join('  •  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showPatternResults(
        context,
        title: 'Completed patterns',
        results: results,
        completed: true,
      ),
    ),
  );
}

class _FullNumberBoard extends StatelessWidget {
  const _FullNumberBoard({
    required this.rules,
    required this.calledNumbers,
    required this.puroNumbers,
    required this.latestCalledNumber,
    required this.onNumberTap,
  });

  final RuleSet rules;
  final Set<int> calledNumbers;
  final Set<int> puroNumbers;
  final int? latestCalledNumber;
  final ValueChanged<int> onNumberTap;

  @override
  Widget build(BuildContext context) {
    final maxRows = rules.columnRanges.fold<int>(
      0,
      (current, range) => max(
        current,
        range.end >= range.start ? range.end - range.start + 1 : 0,
      ),
    );
    return Card(
      key: const ValueKey('full-number-board'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardWidth = max(constraints.maxWidth, rules.columns * 52.0);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: boardWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Container(
                    height: 42,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                      children: [
                        for (final label in rules.columnLabels)
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: FittedBox(
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      key: const ValueKey('number-board-rows'),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemExtent: 50,
                      itemCount: maxRows,
                      itemBuilder: (context, row) => Row(
                        children: [
                          for (var column = 0; column < rules.columns; column++)
                            Expanded(
                              child: _NumberCell(
                                range: rules.columnRanges[column],
                                columnLabel: rules.columnLabels[column],
                                offset: row,
                                calledNumbers: calledNumbers,
                                puroNumbers: puroNumbers,
                                latestCalledNumber: latestCalledNumber,
                                onNumberTap: onNumberTap,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({
    required this.range,
    required this.columnLabel,
    required this.offset,
    required this.calledNumbers,
    required this.puroNumbers,
    required this.latestCalledNumber,
    required this.onNumberTap,
  });

  final NumberRange range;
  final String columnLabel;
  final int offset;
  final Set<int> calledNumbers;
  final Set<int> puroNumbers;
  final int? latestCalledNumber;
  final ValueChanged<int> onNumberTap;

  @override
  Widget build(BuildContext context) {
    final number = range.start + offset;
    if (number > range.end) return const SizedBox.shrink();
    final called = calledNumbers.contains(number);
    final puro = !called && puroNumbers.contains(number);
    final latest = number == latestCalledNumber;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '$columnLabel-$number, ${called
              ? 'called'
              : puro
              ? 'not called, puro; would complete a pattern'
              : 'not called'}',
      button: true,
      selected: called,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          key: ValueKey('call-number-$number'),
          color: called
              ? colors.primaryContainer
              : puro
              ? colors.tertiaryContainer
              : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(
              color: latest
                  ? colors.primary
                  : called
                  ? colors.primary
                  : puro
                  ? colors.tertiary
                  : colors.outlineVariant,
              width: latest
                  ? 3
                  : puro
                  ? 2
                  : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onNumberTap(number),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: called
                          ? colors.onPrimaryContainer
                          : puro
                          ? colors.onTertiaryContainer
                          : colors.onSurface,
                      fontWeight: called || puro
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardsOverview extends StatelessWidget {
  const _CardsOverview({
    required this.cards,
    required this.rules,
    required this.evaluation,
    required this.latestCalledNumber,
  });

  final List<BingoCard> cards;
  final RuleSet rules;
  final PlayEvaluation evaluation;
  final int? latestCalledNumber;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.builder(
      key: const ValueKey('play-cards-overview'),
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: constraints.maxWidth >= 720 ? 280 : 220,
        childAspectRatio: (rules.columns / (rules.rows + 2.15)).clamp(.55, 1.2),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final result = evaluation.forCard(card.id);
        return _OverviewCardTile(
          key: ValueKey('play-overview-card-${card.id}'),
          card: card,
          rules: rules,
          evaluation: result,
          latestCalledNumber: latestCalledNumber,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _PlayCardDetail(
                cards: cards,
                rules: rules,
                evaluation: evaluation,
                latestCalledNumber: latestCalledNumber,
                initialIndex: index,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _OverviewCardTile extends StatelessWidget {
  const _OverviewCardTile({
    required this.card,
    required this.rules,
    required this.evaluation,
    required this.latestCalledNumber,
    required this.onTap,
    super.key,
  });

  final BingoCard card;
  final RuleSet rules;
  final PlayCardEvaluation evaluation;
  final int? latestCalledNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBingo = evaluation.completedPatterns.isNotEmpty;
    final needs = evaluation.oneAwayPatterns
        .map((result) => result.missingNumbers.single.displayLabel)
        .toSet()
        .take(2)
        .join(', ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.displayId,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (hasBingo)
                    const Icon(Icons.emoji_events, size: 19)
                  else if (needs.isNotEmpty)
                    const Icon(Icons.notifications_active_outlined, size: 19)
                  else
                    const Icon(Icons.open_in_full, size: 17),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  hasBingo
                      ? 'Bingo · ${evaluation.completedPatterns.length} pattern${evaluation.completedPatterns.length == 1 ? '' : 's'}'
                      : needs.isNotEmpty
                      ? 'Needs $needs'
                      : 'No near patterns',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: VirtualBingoCard(
                  card: card,
                  rules: rules,
                  markedPositions: evaluation.markedPositions,
                  lastCalledNumber: latestCalledNumber,
                  showCalledState: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayCardDetail extends StatefulWidget {
  const _PlayCardDetail({
    required this.cards,
    required this.rules,
    required this.evaluation,
    required this.latestCalledNumber,
    required this.initialIndex,
  });

  final List<BingoCard> cards;
  final RuleSet rules;
  final PlayEvaluation evaluation;
  final int? latestCalledNumber;
  final int initialIndex;

  @override
  State<_PlayCardDetail> createState() => _PlayCardDetailState();
}

class _PlayCardDetailState extends State<_PlayCardDetail> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_page];
    final result = widget.evaluation.forCard(card.id);
    final status = result.completedPatterns.isNotEmpty
        ? 'Bingo · ${result.completedPatterns.map((item) => item.variantLabel).join(', ')}'
        : result.oneAwayPatterns.isNotEmpty
        ? 'Needs ${result.oneAwayPatterns.map((item) => item.missingNumbers.single.displayLabel).toSet().join(', ')}'
        : 'No patterns are one number away.';
    return Scaffold(
      appBar: AppBar(
        title: Text('Card ${_page + 1} of ${widget.cards.length}'),
        actions: [
          IconButton(
            tooltip: 'Close card detail',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              status,
              key: const ValueKey('play-card-detail-status'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: PageView.builder(
              key: const ValueKey('play-card-detail-pages'),
              controller: _controller,
              itemCount: widget.cards.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final pageCard = widget.cards[index];
                final pageResult = widget.evaluation.forCard(pageCard.id);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio:
                          widget.rules.columns / (widget.rules.rows + .8),
                      child: VirtualBingoCard(
                        key: ValueKey('play-detail-card-${pageCard.id}'),
                        card: pageCard,
                        rules: widget.rules,
                        markedPositions: pageResult.markedPositions,
                        lastCalledNumber: widget.latestCalledNumber,
                        showCalledState: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void _showPatternResults(
  BuildContext context, {
  required String title,
  required List<PlayPatternResult> results,
  required bool completed,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final result in results)
              ListTile(
                leading: Icon(
                  completed ? Icons.check_circle : Icons.looks_one_outlined,
                ),
                title: Text('${result.cardDisplayId} · ${result.variantLabel}'),
                subtitle: completed
                    ? Text('${result.requiredCount} numbered cells complete')
                    : Text(
                        'Needs ${result.missingNumbers.single.displayLabel}',
                      ),
              ),
          ],
        ),
      ),
    ),
  );
}

void _showCalledNumberHistory(
  BuildContext context, {
  required RuleSet rules,
  required List<int> calledNumbers,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Called numbers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${calledNumbers.length} called · oldest to newest',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                key: const ValueKey('called-number-history-list'),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                itemCount: calledNumbers.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final number = calledNumbers[index];
                  final latest = index == calledNumbers.length - 1;
                  return ListTile(
                    key: ValueKey('called-number-history-$index'),
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(_numberLabel(rules, number)),
                    trailing: latest ? const Chip(label: Text('Latest')) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _numberLabel(RuleSet rules, int number) {
  for (var column = 0; column < rules.columns; column++) {
    final range = rules.columnRanges[column];
    if (number >= range.start && number <= range.end) {
      return '${rules.columnLabels[column]}-$number';
    }
  }
  return '$number';
}

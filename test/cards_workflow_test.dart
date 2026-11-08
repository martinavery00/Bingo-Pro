import 'package:bingo_pro/app/app_theme.dart';
import 'package:bingo_pro/app/providers.dart';
import 'package:bingo_pro/domain/contracts.dart';
import 'package:bingo_pro/domain/coverage_card_generator.dart';
import 'package:bingo_pro/domain/models.dart';
import 'package:bingo_pro/domain/play_session.dart';
import 'package:bingo_pro/features/project/project_editor_screen.dart';
import 'package:bingo_pro/features/project/steps/cards_step.dart';
import 'package:bingo_pro/features/project/widgets/virtual_bingo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('project editor exposes the four-destination workflow', (
    tester,
  ) async {
    await _pumpEditor(tester, _project());

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('Patterns'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Generate'), findsNothing);
    expect(find.text('Review'), findsNothing);
  });

  testWidgets('empty Cards state shows validation and generation summary', (
    tester,
  ) async {
    final invalid = _project(patterns: const []);
    await _pumpCards(tester, invalid);

    expect(find.byKey(const ValueKey('empty-cards')), findsOneWidget);
    expect(
      find.textContaining('Add at least one winning pattern.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('generate-cards')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('generation failure is presented inside Cards', (tester) async {
    final project = _project();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectEditorProvider.overrideWith(() => _FailingEditor(project)),
          projectRepositoryProvider.overrideWithValue(_MemoryRepository()),
          playSessionRepositoryProvider.overrideWithValue(
            _MemoryPlaySessionRepository(),
          ),
        ],
        child: MaterialApp(
          theme: BingoAppTheme.light,
          home: const Scaffold(body: CardsStep()),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('generate-cards')));
    await tester.pump();
    expect(find.textContaining('Generation failed:'), findsOneWidget);
  });

  testWidgets('generated Cards groups sets and focus stays inside a set', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = _generatedProject(cardCount: 7);
    await _pumpCards(tester, project);

    expect(find.byKey(const ValueKey('set-selector')), findsOneWidget);
    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-grid-set-1')), findsOneWidget);

    final first = project.cards.first;
    final firstTile = find.byKey(ValueKey('card-tile-${first.id}'));
    await tester.ensureVisible(firstTile);
    await tester.tap(firstTile);
    await tester.pumpAndSettle();

    expect(find.text('Set 1 · Card 1 of 6'), findsOneWidget);
    expect(find.byKey(const ValueKey('focused-card-pages')), findsOneWidget);
    expect(find.textContaining(first.id), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await tester.drag(
        find.byKey(const ValueKey('focused-card-pages')),
        const Offset(-350, 0),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Set 1 · Card 6 of 6'), findsOneWidget);
    expect(find.textContaining(project.cards.last.id), findsNothing);
  });

  testWidgets('lock editing is explicit and updates card and cell locks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = _generatedProject(cardCount: 2);
    final repository = _MemoryRepository();
    await _pumpCards(tester, project, repository: repository);
    final first = project.cards.first;

    expect(find.byKey(ValueKey('card-lock-${first.id}')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('edit-locks')));
    await tester.pump();
    expect(find.byKey(ValueKey('card-lock-${first.id}')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('card-lock-${first.id}')));
    await tester.pump();
    expect(repository.saved.single.cards.first.isLocked, isTrue);

    await tester.tap(find.byKey(ValueKey('card-lock-${first.id}')));
    await tester.pump();
    expect(repository.saved.last.cards.first.isLocked, isFalse);

    final tile = find.byKey(ValueKey('card-tile-${first.id}'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(
      find.text('Edit locks is on. Tap a numbered cell to lock or unlock it.'),
      findsOneWidget,
    );
    final value = first.cells.firstWhere((cell) => !cell.isFree).value!;
    final cell = find.descendant(
      of: find.byKey(ValueKey('focused-card-${first.id}')),
      matching: find.text('$value'),
    );
    expect(cell, findsOneWidget);
    await tester.tap(cell);
    await tester.pump();
    expect(
      repository.saved.last.cards.first.cells
          .firstWhere((candidate) => candidate.value == value)
          .isLocked,
      isTrue,
    );
  });

  testWidgets('screen card supports custom grids across responsive sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rules = RuleSet.custom(
      rows: 7,
      columns: 3,
    ).copyWith(freeCells: {const CellPosition(3, 1)});
    final pattern = PatternDefinition(
      id: 'top-row',
      name: 'Top row',
      cells: {
        for (var column = 0; column < rules.columns; column++)
          CellPosition(0, column),
      },
    );
    final card = const CoverageCardGenerator()
        .generate(rules: rules, patterns: [pattern], cardCount: 1, seed: 12345)
        .cards
        .single;

    for (final size in [const Size(390, 844), const Size(900, 600)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: BingoAppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size.width * .7,
                height: size.height * .8,
                child: VirtualBingoCard(card: card, rules: rules),
              ),
            ),
          ),
        ),
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Free cell',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Play set records calls, reports near wins, and continues after Bingo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = _generatedProject(cardCount: 2);
    final playRepository = _MemoryPlaySessionRepository();
    await _pumpCards(tester, project, playRepository: playRepository);

    await tester.tap(find.byKey(const ValueKey('play-set')));
    await tester.pumpAndSettle();
    expect(find.text('Play · Set 1'), findsOneWidget);
    expect(playRepository.sessions, hasLength(1));
    expect(find.byKey(const ValueKey('full-number-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('almost-complete-section')), findsNothing);
    expect(
      find.byKey(const ValueKey('called-number-history-action')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('keypad-input')), findsNothing);

    final topRow =
        project.cards.first.cells
            .where((cell) => cell.position.row == 0 && !cell.isFree)
            .toList()
          ..sort((a, b) => a.position.column.compareTo(b.position.column));
    for (final cell in topRow) {
      expect(find.byKey(ValueKey('call-number-${cell.value}')), findsOneWidget);
    }
    final firstColumnStart = project.rules.columnRanges.first.start;
    final initialRowStride =
        tester
            .getTopLeft(
              find.byKey(ValueKey('call-number-${firstColumnStart + 1}')),
            )
            .dy -
        tester
            .getTopLeft(find.byKey(ValueKey('call-number-$firstColumnStart')))
            .dy;
    expect(initialRowStride, 50);

    for (final cell in topRow.take(topRow.length - 1)) {
      await tester.tap(find.byKey(ValueKey('call-number-${cell.value}')));
      await tester.pump();
    }
    expect(
      find.byKey(const ValueKey('called-number-history-action')),
      findsOneWidget,
    );
    final latestNumberMaterial = tester.widget<Material>(
      find.byKey(ValueKey('call-number-${topRow[topRow.length - 2].value}')),
    );
    expect(
      (latestNumberMaterial.shape! as RoundedRectangleBorder).side.width,
      3,
    );
    final puroNumber = topRow.last.value!;
    final puroNumberMaterial = tester.widget<Material>(
      find.byKey(ValueKey('call-number-$puroNumber')),
    );
    expect(puroNumberMaterial.color, BingoPlayColors.golden.puroContainer);
    expect((puroNumberMaterial.shape! as RoundedRectangleBorder).side.width, 2);
    expect(
      find.bySemanticsLabel(
        '${project.rules.columnLabels[topRow.last.position.column]}-$puroNumber, not called, puro; would complete a pattern',
      ),
      findsOneWidget,
    );
    final updatedRowStride =
        tester
            .getTopLeft(
              find.byKey(ValueKey('call-number-${firstColumnStart + 1}')),
            )
            .dy -
        tester
            .getTopLeft(find.byKey(ValueKey('call-number-$firstColumnStart')))
            .dy;
    expect(updatedRowStride, initialRowStride);

    await tester.tap(
      find.byKey(const ValueKey('called-number-history-action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Called numbers'), findsOneWidget);
    expect(find.text('4 called · oldest to newest'), findsOneWidget);
    for (var index = 0; index < topRow.length - 1; index++) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('called-number-history-$index')),
          matching: find.text(
            '${project.rules.columnLabels[topRow[index].position.column]}-${topRow[index].value}',
          ),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Latest'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('play-cards-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play-cards-overview')), findsOneWidget);
    for (final card in project.cards) {
      expect(
        find.byKey(ValueKey('play-overview-card-${card.id}')),
        findsOneWidget,
      );
    }
    expect(
      find.text(
        'Needs ${project.rules.columnLabels[topRow.last.position.column]}-${topRow.last.value}',
      ),
      findsWidgets,
    );
    await tester.tap(
      find.byKey(ValueKey('play-overview-card-${project.cards.first.id}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('play-card-detail-pages')),
      findsOneWidget,
    );
    expect(find.text('Card 1 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Close card detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-numbers-tab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('call-number-${topRow.last.value}')));
    await tester.pumpAndSettle();
    expect(find.text('Bingo!'), findsOneWidget);
    await tester.tap(find.text('Continue playing'));
    await tester.pumpAndSettle();
    expect(find.textContaining('completed pattern'), findsOneWidget);
    final completedNumberMaterial = tester.widget<Material>(
      find.byKey(ValueKey('call-number-$puroNumber')),
    );
    expect(
      completedNumberMaterial.color,
      BingoAppTheme.light.colorScheme.primaryContainer,
    );
    expect(
      find.bySemanticsLabel(
        '${project.rules.columnLabels[topRow.last.position.column]}-$puroNumber, called',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey('call-number-${topRow.last.value}')));
    await tester.pump();
    expect(find.textContaining('removed from called numbers'), findsOneWidget);
    expect(
      playRepository.sessions.single.calledNumbers,
      isNot(contains(topRow.last.value)),
    );
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    expect(
      playRepository.sessions.single.calledNumbers,
      topRow.map((cell) => cell.value).toList(),
    );
    await tester.tap(find.byTooltip('Game actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();
    expect(find.text('Start over?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start over'));
    await tester.pumpAndSettle();
    expect(playRepository.sessions.single.calledNumbers, isEmpty);

    await tester.tap(find.byTooltip('Game actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End game'));
    await tester.pumpAndSettle();
    expect(find.text('End game?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'End game'));
    await tester.pumpAndSettle();
    expect(playRepository.sessions, isEmpty);
    expect(find.byKey(const ValueKey('cards-workspace')), findsOneWidget);
  });

  testWidgets('Cards labels a matching saved set as resumable', (tester) async {
    final project = _generatedProject(cardCount: 2);
    final playRepository = _MemoryPlaySessionRepository();
    await playRepository.save(
      PlaySession(
        projectId: project.id,
        setIndex: 1,
        sourceSignature: playSourceSignature(project, 1),
        calledNumbers: const [1],
        startedAt: DateTime(2026, 11, 8),
        updatedAt: DateTime(2026, 11, 8),
      ),
    );
    await _pumpCards(tester, project, playRepository: playRepository);
    expect(find.text('Resume game'), findsOneWidget);
  });

  testWidgets('puro highlights every distinct one-away number', (tester) async {
    final project = _manyNearPatternsProject();
    final playRepository = _MemoryPlaySessionRepository();
    final anchor = project.cards.single.cellAt(0, 0).value!;
    await playRepository.save(
      PlaySession(
        projectId: project.id,
        setIndex: 1,
        sourceSignature: playSourceSignature(project, 1),
        calledNumbers: [anchor],
        startedAt: DateTime(2026, 11, 8),
        updatedAt: DateTime(2026, 11, 8),
      ),
    );
    await _pumpCards(tester, project, playRepository: playRepository);

    await tester.tap(find.byKey(const ValueKey('play-set')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('almost-complete-section')), findsNothing);
    final evaluation = const PlayEvaluator().evaluate(
      rules: project.rules,
      patterns: project.patterns,
      cards: project.cards,
      calledNumbers: [anchor],
    );
    final puroNumbers = evaluation.oneAwayPatterns
        .map((result) => result.missingNumbers.single.value)
        .toSet();
    expect(puroNumbers, hasLength(4));
    for (final number in puroNumbers) {
      final material = tester.widget<Material>(
        find.byKey(ValueKey('call-number-$number')),
      );
      expect(material.color, BingoPlayColors.golden.puroContainer);
      expect((material.shape! as RoundedRectangleBorder).side.width, 2);
    }
    final ordinaryNumber = project.rules.columnRanges
        .expand(
          (range) => [
            for (var value = range.start; value <= range.end; value++) value,
          ],
        )
        .firstWhere(
          (number) => number != anchor && !puroNumbers.contains(number),
        );
    final ordinaryMaterial = tester.widget<Material>(
      find.byKey(ValueKey('call-number-$ordinaryNumber')),
    );
    expect(ordinaryMaterial.color, BingoAppTheme.light.colorScheme.surface);
    expect((ordinaryMaterial.shape! as RoundedRectangleBorder).side.width, 1);
  });

  testWidgets('called-number history follows removal and re-call order', (
    tester,
  ) async {
    final project = _sevenColumnProject();
    final playRepository = _MemoryPlaySessionRepository();
    await playRepository.save(
      PlaySession(
        projectId: project.id,
        setIndex: 1,
        sourceSignature: playSourceSignature(project, 1),
        calledNumbers: const [1, 10, 60],
        startedAt: DateTime(2026, 11, 8),
        updatedAt: DateTime(2026, 11, 8),
      ),
    );
    await _pumpCards(tester, project, playRepository: playRepository);

    await tester.tap(find.byKey(const ValueKey('play-set')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('call-number-10')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('call-number-10')));
    await tester.pump();

    expect(playRepository.sessions.single.calledNumbers, [1, 60, 10]);
    await tester.tap(
      find.byKey(const ValueKey('called-number-history-action')),
    );
    await tester.pumpAndSettle();
    for (final entry in const [(0, 'A-1'), (1, 'G-60'), (2, 'B-10')]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('called-number-history-${entry.$1}')),
          matching: find.text(entry.$2),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('called-number-history-2')),
        matching: find.text('Latest'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('full number board supports seven unequal custom columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = _sevenColumnProject();
    await _pumpCards(tester, project);

    await tester.tap(find.byKey(const ValueKey('play-set')));
    await tester.pumpAndSettle();
    final board = find.byKey(const ValueKey('full-number-board'));
    expect(board, findsOneWidget);
    expect(
      find.descendant(of: board, matching: find.text('A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: board, matching: find.text('G')),
      findsOneWidget,
    );
    for (final cardCell in project.cards.single.cells.where(
      (cell) => cell.position.row == 0,
    )) {
      expect(
        find.byKey(ValueKey('call-number-${cardCell.value}')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpEditor(WidgetTester tester, BingoProject project) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectEditorProvider.overrideWith(() => _TestEditor(project)),
        projectRepositoryProvider.overrideWithValue(_MemoryRepository()),
        playSessionRepositoryProvider.overrideWithValue(
          _MemoryPlaySessionRepository(),
        ),
      ],
      child: MaterialApp(
        theme: BingoAppTheme.light,
        home: const ProjectEditorScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpCards(
  WidgetTester tester,
  BingoProject project, {
  _MemoryRepository? repository,
  _MemoryPlaySessionRepository? playRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectEditorProvider.overrideWith(() => _TestEditor(project)),
        projectRepositoryProvider.overrideWithValue(
          repository ?? _MemoryRepository(),
        ),
        playSessionRepositoryProvider.overrideWithValue(
          playRepository ?? _MemoryPlaySessionRepository(),
        ),
      ],
      child: MaterialApp(
        theme: BingoAppTheme.light,
        home: const Scaffold(body: CardsStep()),
      ),
    ),
  );
  await tester.pump();
}

class _TestEditor extends ProjectEditor {
  _TestEditor(this.project);

  final BingoProject project;

  @override
  BingoProject? build() => project;
}

class _FailingEditor extends _TestEditor {
  _FailingEditor(super.project);

  @override
  Future<void> generate({bool keepSeed = false}) async {
    throw StateError('test generation failure');
  }
}

class _MemoryRepository implements ProjectRepository {
  final saved = <BingoProject>[];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<BingoProject?> find(String id) async =>
      saved.where((project) => project.id == id).firstOrNull;

  @override
  Future<void> save(BingoProject project) async => saved.add(project);

  @override
  Stream<List<BingoProject>> watchAll() => Stream.value(saved);
}

class _MemoryPlaySessionRepository implements PlaySessionRepository {
  final sessions = <PlaySession>[];

  @override
  Future<void> delete(String projectId, int setIndex) async {
    sessions.removeWhere(
      (session) =>
          session.projectId == projectId && session.setIndex == setIndex,
    );
  }

  @override
  Future<void> deleteForProject(String projectId) async {
    sessions.removeWhere((session) => session.projectId == projectId);
  }

  @override
  Future<PlaySession?> find(String projectId, int setIndex) async => sessions
      .where(
        (session) =>
            session.projectId == projectId && session.setIndex == setIndex,
      )
      .firstOrNull;

  @override
  Future<void> save(PlaySession session) async {
    await delete(session.projectId, session.setIndex);
    sessions.add(session);
  }

  @override
  Stream<List<PlaySession>> watchForProject(String projectId) => Stream.value(
    sessions.where((session) => session.projectId == projectId).toList(),
  );
}

BingoProject _generatedProject({required int cardCount}) {
  final base = _project(cardCount: cardCount);
  final result = const CoverageCardGenerator().generate(
    rules: base.rules,
    patterns: base.patterns,
    cardCount: cardCount,
    seed: base.seed,
  );
  return base.copyWith(cards: result.cards, report: result.report);
}

BingoProject _manyNearPatternsProject() {
  final rules = RuleSet.custom(rows: 3, columns: 3);
  final targets = const [
    CellPosition(0, 1),
    CellPosition(0, 2),
    CellPosition(1, 0),
    CellPosition(1, 1),
  ];
  final patterns = [
    for (var index = 0; index < targets.length; index++)
      PatternDefinition(
        id: 'near-$index',
        name: 'Pattern ${index + 1}',
        cells: {const CellPosition(0, 0), targets[index]},
      ),
  ];
  final base = _customProject(rules: rules, patterns: patterns);
  final result = const CoverageCardGenerator().generate(
    rules: rules,
    patterns: patterns,
    cardCount: 1,
    seed: base.seed,
  );
  return base.copyWith(cards: result.cards, report: result.report);
}

BingoProject _sevenColumnProject() {
  final rules = RuleSet(
    name: 'Seven columns',
    rows: 3,
    columns: 7,
    columnLabels: const ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
    columnRanges: const [
      NumberRange(start: 1, end: 3),
      NumberRange(start: 10, end: 13),
      NumberRange(start: 20, end: 24),
      NumberRange(start: 30, end: 35),
      NumberRange(start: 40, end: 46),
      NumberRange(start: 50, end: 57),
      NumberRange(start: 60, end: 68),
    ],
    freeCells: const {},
  );
  final pattern = PatternDefinition(
    id: 'top-row',
    name: 'Top row',
    cells: {
      for (var column = 0; column < rules.columns; column++)
        CellPosition(0, column),
    },
  );
  final base = _customProject(rules: rules, patterns: [pattern]);
  final result = const CoverageCardGenerator().generate(
    rules: rules,
    patterns: [pattern],
    cardCount: 1,
    seed: base.seed,
  );
  return base.copyWith(cards: result.cards, report: result.report);
}

BingoProject _customProject({
  required RuleSet rules,
  required List<PatternDefinition> patterns,
}) {
  final now = DateTime(2026, 11, 8);
  return BingoProject(
    id: 'custom-${rules.columns}-${patterns.length}',
    name: 'Custom play cards',
    rules: rules,
    patterns: patterns,
    theme: CardThemeConfig.comfort(),
    printLayout: const PrintLayoutConfig(),
    cardCount: 1,
    seed: 2468,
    cards: const [],
    createdAt: now,
    updatedAt: now,
  );
}

BingoProject _project({int cardCount = 6, List<PatternDefinition>? patterns}) {
  final now = DateTime(2026, 11, 8);
  return BingoProject(
    id: 'project-1',
    name: 'Test cards',
    rules: RuleSet.standard75(),
    patterns:
        patterns ??
        [
          PatternDefinition(
            id: 'top-row',
            name: 'Top row',
            cells: {
              CellPosition(0, 0),
              CellPosition(0, 1),
              CellPosition(0, 2),
              CellPosition(0, 3),
              CellPosition(0, 4),
            },
          ),
        ],
    theme: CardThemeConfig.comfort(),
    printLayout: const PrintLayoutConfig(),
    cardCount: cardCount,
    seed: 12345,
    cards: const [],
    createdAt: now,
    updatedAt: now,
  );
}

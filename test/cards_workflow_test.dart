import 'package:bingo_pro/app/app_theme.dart';
import 'package:bingo_pro/app/providers.dart';
import 'package:bingo_pro/domain/contracts.dart';
import 'package:bingo_pro/domain/coverage_card_generator.dart';
import 'package:bingo_pro/domain/models.dart';
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
}

Future<void> _pumpEditor(WidgetTester tester, BingoProject project) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectEditorProvider.overrideWith(() => _TestEditor(project)),
        projectRepositoryProvider.overrideWithValue(_MemoryRepository()),
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectEditorProvider.overrideWith(() => _TestEditor(project)),
        projectRepositoryProvider.overrideWithValue(
          repository ?? _MemoryRepository(),
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

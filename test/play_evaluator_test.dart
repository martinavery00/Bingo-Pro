import 'package:bingo_pro/domain/models.dart';
import 'package:bingo_pro/domain/play_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = PlayEvaluator();

  test('derives all one-away and completed patterns across cards', () {
    final rules = _rules();
    final cards = [_card('a', 1), _card('b', 2)];
    final pattern = PatternDefinition(
      id: 'top',
      name: 'Top row',
      cells: {
        const CellPosition(0, 0),
        const CellPosition(0, 1),
        const CellPosition(0, 2),
      },
    );

    final near = evaluator.evaluate(
      rules: rules,
      patterns: [pattern],
      cards: cards,
      calledNumbers: const [1, 11],
    );
    expect(near.oneAwayPatterns, hasLength(2));
    expect(
      near.oneAwayPatterns.map(
        (result) => result.missingNumbers.single.displayLabel,
      ),
      everyElement('C-21'),
    );

    final complete = evaluator.evaluate(
      rules: rules,
      patterns: [pattern],
      cards: cards,
      calledNumbers: const [1, 11, 21],
    );
    expect(complete.completedPatterns, hasLength(2));
    expect(complete.oneAwayPatterns, isEmpty);
  });

  test(
    'expands transforms and reevaluates deterministically after removal',
    () {
      final pattern = PatternDefinition(
        id: 'line',
        name: 'Line',
        cells: {
          const CellPosition(0, 0),
          const CellPosition(0, 1),
          const CellPosition(0, 2),
        },
        includeRotations: true,
      );
      final before = evaluator.evaluate(
        rules: _rules(),
        patterns: [pattern],
        cards: [_card('a', 1)],
        calledNumbers: const [1, 2, 3],
      );
      expect(before.completedPatterns, hasLength(1));

      final removed = evaluator.evaluate(
        rules: _rules(),
        patterns: [pattern],
        cards: [_card('a', 1)],
        calledNumbers: const [1, 2],
      );
      expect(removed.completedPatterns, isEmpty);
      expect(removed.oneAwayPatterns, hasLength(1));

      final repeated = evaluator.evaluate(
        rules: _rules(),
        patterns: [pattern],
        cards: [_card('a', 1)],
        calledNumbers: const [1, 2],
      );
      expect(
        repeated.oneAwayPatterns.single.identity,
        removed.oneAwayPatterns.single.identity,
      );
    },
  );

  test('excludes free cells and ignores a free-only pattern', () {
    final rules = _rules(free: {const CellPosition(1, 1)});
    final card = _card('a', 1, free: {const CellPosition(1, 1)});
    final middle = PatternDefinition(
      id: 'middle',
      name: 'Middle row',
      cells: {
        const CellPosition(1, 0),
        const CellPosition(1, 1),
        const CellPosition(1, 2),
      },
    );
    final freeOnly = PatternDefinition(
      id: 'free',
      name: 'Free only',
      cells: {const CellPosition(1, 1)},
    );

    final result = evaluator.evaluate(
      rules: rules,
      patterns: [middle, freeOnly],
      cards: [card],
      calledNumbers: const [2, 22],
    );
    expect(result.completedPatterns, hasLength(1));
    expect(result.completedPatterns.single.requiredCount, 2);
    expect(result.completedPatterns.single.patternId, 'middle');
  });

  test('source signature ignores regeneration locks', () {
    final now = DateTime(2026);
    BingoProject project(BingoCard card) => BingoProject(
      id: 'p',
      name: 'Project',
      rules: _rules(),
      patterns: const [],
      theme: CardThemeConfig.comfort(),
      printLayout: const PrintLayoutConfig(),
      cardCount: 1,
      seed: 1,
      cards: [card],
      createdAt: now,
      updatedAt: now,
    );
    final original = _card('a', 1);
    final locked = original.copyWith(
      isLocked: true,
      cells: [for (final cell in original.cells) cell.copyWith(isLocked: true)],
    );
    expect(
      playSourceSignature(project(original), 1),
      playSourceSignature(project(locked), 1),
    );
  });
}

RuleSet _rules({Set<CellPosition> free = const {}}) => RuleSet(
  name: 'Three',
  rows: 3,
  columns: 3,
  columnLabels: const ['A', 'B', 'C'],
  columnRanges: const [
    NumberRange(start: 1, end: 3),
    NumberRange(start: 11, end: 13),
    NumberRange(start: 21, end: 23),
  ],
  freeCells: free,
);

BingoCard _card(
  String id,
  int cardIndex, {
  Set<CellPosition> free = const {},
}) => BingoCard(
  id: id,
  setIndex: 1,
  cardIndex: cardIndex,
  cells: [
    for (var row = 0; row < 3; row++)
      for (var column = 0; column < 3; column++)
        CardCell(
          position: CellPosition(row, column),
          value: free.contains(CellPosition(row, column))
              ? null
              : column * 10 + row + 1,
          isFree: free.contains(CellPosition(row, column)),
        ),
  ],
);

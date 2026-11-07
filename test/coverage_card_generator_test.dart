import 'package:bingo_pro/domain/coverage_card_generator.dart';
import 'package:bingo_pro/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = RuleSet.standard75();
  final patterns = [
    PatternDefinition(
      id: 'row',
      name: 'Top row',
      cells: {
        for (var column = 0; column < 5; column++) CellPosition(0, column),
      },
      includeRotations: true,
      includeReflections: true,
    ),
  ];

  test('generates 18 valid, unique, balanced cards', () {
    final result = const CoverageCardGenerator(
      optimizationIterations: 300,
    ).generate(rules: rules, patterns: patterns, cardCount: 18, seed: 123456);
    expect(result.cards, hasLength(18));
    final signatures = <String>{};
    for (final card in result.cards) {
      expect(signatures.add(_signature(card)), isTrue);
      expect(card.cellAt(2, 2).isFree, isTrue);
      for (var column = 0; column < 5; column++) {
        final values = card.cells
            .where((cell) => cell.position.column == column && !cell.isFree)
            .map((cell) => cell.value!)
            .toList();
        expect(values.toSet(), hasLength(values.length));
        expect(
          values.every(
            (value) => rules.columnRanges[column].values.contains(value),
          ),
          isTrue,
        );
      }
    }
    for (var set = 1; set <= 3; set++) {
      final cards = result.cards.where((card) => card.setIndex == set);
      for (var column = 0; column < 5; column++) {
        final frequency = <int, int>{};
        for (final card in cards) {
          for (final cell in card.cells.where(
            (cell) => cell.position.column == column && !cell.isFree,
          )) {
            frequency[cell.value!] = (frequency[cell.value!] ?? 0) + 1;
          }
        }
        final allCounts = rules.columnRanges[column].values
            .map((value) => frequency[value] ?? 0)
            .toList();
        expect(
          allCounts.reduce((a, b) => a > b ? a : b) -
              allCounts.reduce((a, b) => a < b ? a : b),
          lessThanOrEqualTo(1),
        );
      }
    }
    expect(result.report.score, inInclusiveRange(0, 100));
  });

  test('same seed produces identical cards', () {
    const generator = CoverageCardGenerator(optimizationIterations: 100);
    final first = generator.generate(
      rules: rules,
      patterns: patterns,
      cardCount: 6,
      seed: 88,
    );
    final second = generator.generate(
      rules: rules,
      patterns: patterns,
      cardCount: 6,
      seed: 88,
    );
    expect(
      first.cards.map(_signature),
      orderedEquals(second.cards.map(_signature)),
    );
  });

  test('optimization does not reduce the coverage score', () {
    final baseline = const CoverageCardGenerator(optimizationIterations: 0)
        .generate(rules: rules, patterns: patterns, cardCount: 6, seed: 987);
    final optimized = const CoverageCardGenerator(optimizationIterations: 700)
        .generate(rules: rules, patterns: patterns, cardCount: 6, seed: 987);
    expect(optimized.report.score, greaterThanOrEqualTo(baseline.report.score));
  });

  test('supports custom grids across the complete 3 to 7 range', () {
    for (var size = 3; size <= 7; size++) {
      final customRules = RuleSet.custom(rows: size, columns: size);
      final customPattern = PatternDefinition(
        id: 'row-$size',
        name: 'Row',
        cells: {
          for (var column = 0; column < size; column++) CellPosition(0, column),
        },
      );
      final result = const CoverageCardGenerator(optimizationIterations: 20)
          .generate(
            rules: customRules,
            patterns: [customPattern],
            cardCount: 6,
            seed: size,
          );
      expect(result.cards, hasLength(6));
      expect(
        result.cards.every((card) => card.cells.length == size * size),
        isTrue,
      );
    }
  });

  test('locked cell survives regeneration', () {
    const generator = CoverageCardGenerator(optimizationIterations: 100);
    final first = generator.generate(
      rules: rules,
      patterns: patterns,
      cardCount: 6,
      seed: 10,
    );
    final card = first.cards.first;
    final target = card.cellAt(0, 0);
    final previous = [
      card.copyWith(
        cells: [
          for (final cell in card.cells)
            if (cell.position == target.position)
              cell.copyWith(isLocked: true)
            else
              cell,
        ],
      ),
      ...first.cards.skip(1),
    ];
    final second = generator.generate(
      rules: rules,
      patterns: patterns,
      cardCount: 6,
      seed: 11,
      previousCards: previous,
    );
    expect(second.cards.first.cellAt(0, 0).value, target.value);
    expect(second.cards.first.cellAt(0, 0).isLocked, isTrue);
  });

  test('default 18-card optimization meets the three-second target', () {
    final fullPatterns = <PatternDefinition>[
      for (var row = 0; row < 5; row++)
        PatternDefinition(
          id: 'r$row',
          name: 'Row',
          cells: {
            for (var column = 0; column < 5; column++)
              CellPosition(row, column),
          },
        ),
      for (var column = 0; column < 5; column++)
        PatternDefinition(
          id: 'c$column',
          name: 'Column',
          cells: {for (var row = 0; row < 5; row++) CellPosition(row, column)},
        ),
    ];
    final stopwatch = Stopwatch()..start();
    const CoverageCardGenerator().generate(
      rules: rules,
      patterns: fullPatterns,
      cardCount: 18,
      seed: 20261107,
    );
    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
  });
}

String _signature(BingoCard card) =>
    card.cells.map((cell) => cell.isFree ? 'F' : '${cell.value}').join(',');

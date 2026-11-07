import 'package:bingo_pro/domain/models.dart';
import 'package:bingo_pro/domain/pattern_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleSet', () {
    test('standard 75-ball rules are valid', () {
      final rules = RuleSet.standard75();
      expect(rules.validate(), isEmpty);
      expect(rules.freeCells, contains(const CellPosition(2, 2)));
      expect(
        rules.columnRanges.first.values,
        orderedEquals(List.generate(15, (i) => i + 1)),
      );
    });

    test('custom rules reject overlapping and undersized ranges', () {
      final rules = RuleSet.custom(rows: 5, columns: 3).copyWith(
        columnRanges: const [
          NumberRange(start: 1, end: 4),
          NumberRange(start: 4, end: 8),
          NumberRange(start: 9, end: 13),
        ],
      );
      expect(rules.validate(), contains(contains('at least 5')));
      expect(rules.validate(), contains(contains('must not overlap')));
    });
  });

  group('PatternService', () {
    test(
      'square masks expand into rotations and reflections without duplicates',
      () {
        final pattern = PatternDefinition(
          id: 'l',
          name: 'L',
          cells: {
            const CellPosition(0, 0),
            const CellPosition(1, 0),
            const CellPosition(1, 1),
          },
          includeRotations: true,
          includeReflections: true,
        );
        final variants = const PatternService().expand(
          pattern,
          RuleSet.custom(rows: 3, columns: 3),
        );
        expect(variants, hasLength(8));

        final detailed = const PatternService().expandVariants(
          pattern,
          RuleSet.custom(rows: 3, columns: 3),
        );
        expect(
          detailed.map((variant) => variant.transform),
          orderedEquals(PatternTransform.values),
        );
        expect(
          detailed[1].cells,
          containsAll(const [CellPosition(0, 2), CellPosition(0, 1)]),
        );
      },
    );

    test('rectangular masks only use the 180 degree rotation', () {
      final pattern = PatternDefinition(
        id: 'edge',
        name: 'Edge',
        cells: {const CellPosition(0, 0), const CellPosition(0, 1)},
        includeRotations: true,
      );
      final variants = const PatternService().expand(
        pattern,
        RuleSet.custom(rows: 3, columns: 5),
      );
      expect(variants, hasLength(2));
      expect(variants.last, contains(const CellPosition(2, 4)));
    });

    test('rectangular masks expose only dimension-preserving transforms', () {
      final pattern = PatternDefinition(
        id: 'corner',
        name: 'Corner',
        cells: {const CellPosition(0, 0), const CellPosition(0, 1)},
        includeRotations: true,
        includeReflections: true,
      );
      final variants = const PatternService().expandVariants(
        pattern,
        RuleSet.custom(rows: 3, columns: 5),
      );

      expect(
        variants.map((variant) => variant.transform),
        orderedEquals(const [
          PatternTransform.original,
          PatternTransform.rotate180,
          PatternTransform.mirror,
          PatternTransform.mirrorRotate180,
        ]),
      );
    });

    test('symmetric duplicates keep the first canonical transform label', () {
      final pattern = PatternDefinition(
        id: 'center',
        name: 'Center',
        cells: {const CellPosition(1, 1)},
        includeRotations: true,
        includeReflections: true,
      );
      final variants = const PatternService().expandVariants(
        pattern,
        RuleSet.custom(rows: 3, columns: 3),
      );

      expect(variants, hasLength(1));
      expect(variants.single.transform, PatternTransform.original);
    });
  });
}

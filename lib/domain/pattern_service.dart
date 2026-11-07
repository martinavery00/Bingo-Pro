import 'models.dart';

enum PatternTransform {
  original,
  rotate90,
  rotate180,
  rotate270,
  mirror,
  mirrorRotate90,
  mirrorRotate180,
  mirrorRotate270,
}

class PatternVariant {
  const PatternVariant({required this.transform, required this.cells});

  final PatternTransform transform;
  final Set<CellPosition> cells;
}

class PatternService {
  const PatternService();

  List<Set<CellPosition>> expand(PatternDefinition pattern, RuleSet rules) =>
      expandVariants(pattern, rules).map((variant) => variant.cells).toList();

  List<PatternVariant> expandVariants(
    PatternDefinition pattern,
    RuleSet rules,
  ) {
    final rotations = <PatternVariant>[
      PatternVariant(
        transform: PatternTransform.original,
        cells: pattern.cells,
      ),
    ];
    if (pattern.includeRotations) {
      if (rules.rows == rules.columns) {
        rotations.addAll([
          PatternVariant(
            transform: PatternTransform.rotate90,
            cells: _rotate90(pattern.cells, rules.rows),
          ),
          PatternVariant(
            transform: PatternTransform.rotate180,
            cells: _rotate180(pattern.cells, rules.rows, rules.columns),
          ),
          PatternVariant(
            transform: PatternTransform.rotate270,
            cells: _rotate270(pattern.cells, rules.rows),
          ),
        ]);
      } else {
        rotations.add(
          PatternVariant(
            transform: PatternTransform.rotate180,
            cells: _rotate180(pattern.cells, rules.rows, rules.columns),
          ),
        );
      }
    }

    final candidates = List<PatternVariant>.from(rotations);
    if (pattern.includeReflections) {
      for (final variant in rotations) {
        candidates.add(
          PatternVariant(
            transform: _mirroredTransform(variant.transform),
            cells: _reflect(variant.cells, rules.columns),
          ),
        );
      }
    }

    final unique = <String, PatternVariant>{};
    for (final variant in candidates) {
      final sorted = variant.cells.map((cell) => cell.key).toList()..sort();
      unique.putIfAbsent(sorted.join('|'), () => variant);
    }
    return unique.values.toList();
  }

  PatternTransform _mirroredTransform(PatternTransform transform) =>
      switch (transform) {
        PatternTransform.original => PatternTransform.mirror,
        PatternTransform.rotate90 => PatternTransform.mirrorRotate90,
        PatternTransform.rotate180 => PatternTransform.mirrorRotate180,
        PatternTransform.rotate270 => PatternTransform.mirrorRotate270,
        _ => throw ArgumentError.value(transform, 'transform'),
      };

  Set<CellPosition> _rotate90(Set<CellPosition> cells, int size) => cells
      .map((cell) => CellPosition(cell.column, size - 1 - cell.row))
      .toSet();

  Set<CellPosition> _rotate180(
    Set<CellPosition> cells,
    int rows,
    int columns,
  ) => cells
      .map(
        (cell) => CellPosition(rows - 1 - cell.row, columns - 1 - cell.column),
      )
      .toSet();

  Set<CellPosition> _rotate270(Set<CellPosition> cells, int size) => cells
      .map((cell) => CellPosition(size - 1 - cell.column, cell.row))
      .toSet();

  Set<CellPosition> _reflect(Set<CellPosition> cells, int columns) => cells
      .map((cell) => CellPosition(cell.row, columns - 1 - cell.column))
      .toSet();
}

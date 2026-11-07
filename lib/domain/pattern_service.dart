import 'models.dart';

class PatternService {
  const PatternService();

  List<Set<CellPosition>> expand(PatternDefinition pattern, RuleSet rules) {
    final variants = <Set<CellPosition>>[pattern.cells];
    if (pattern.includeRotations) {
      variants.add(_rotate180(pattern.cells, rules.rows, rules.columns));
      if (rules.rows == rules.columns) {
        variants
          ..add(_rotate90(pattern.cells, rules.rows))
          ..add(_rotate270(pattern.cells, rules.rows));
      }
    }
    if (pattern.includeReflections) {
      final current = List<Set<CellPosition>>.from(variants);
      variants.addAll(current.map((cells) => _reflect(cells, rules.columns)));
    }

    final unique = <String, Set<CellPosition>>{};
    for (final cells in variants) {
      final sorted = cells.map((cell) => cell.key).toList()..sort();
      unique[sorted.join('|')] = cells;
    }
    return unique.values.toList();
  }

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

import 'package:flutter/material.dart';

import '../../../domain/models.dart';

class BingoCardPreview extends StatelessWidget {
  const BingoCardPreview({
    required this.card,
    required this.rules,
    required this.theme,
    this.onCellTap,
    super.key,
  });

  final BingoCard card;
  final RuleSet rules;
  final CardThemeConfig theme;
  final ValueChanged<CellPosition>? onCellTap;

  @override
  Widget build(BuildContext context) {
    final grid = Color(theme.gridColor);
    return Container(
      decoration: BoxDecoration(
        color: Color(theme.backgroundColor),
        border: Border.all(color: grid, width: theme.outerLineWidth),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Color(theme.headerColor),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                for (final label in rules.columnLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Color(theme.headerTextColor),
                          fontFamily: theme.fontFamily,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var row = 0; row < rules.rows; row++)
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < rules.columns; column++)
                    Expanded(
                      child: _Cell(
                        cell: card.cellAt(row, column),
                        config: theme,
                        grid: grid,
                        onTap: onCellTap,
                      ),
                    ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card.displayId,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(card.id, style: const TextStyle(fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.config,
    required this.grid,
    this.onTap,
  });

  final CardCell cell;
  final CardThemeConfig config;
  final Color grid;
  final ValueChanged<CellPosition>? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null && !cell.isFree,
    label: cell.isFree
        ? 'Free cell'
        : '${cell.value}${cell.isLocked ? ', locked' : ', unlocked'}',
    child: InkWell(
      onTap: cell.isFree ? null : () => onTap?.call(cell.position),
      child: Container(
        decoration: BoxDecoration(
          color: cell.isFree ? Color(config.freeColor) : null,
          border: Border.all(color: grid, width: config.lineWidth),
        ),
        child: Stack(
          children: [
            Center(
              child: FittedBox(
                child: Text(
                  cell.isFree ? config.freeLabel : '${cell.value}',
                  style: TextStyle(
                    color: Color(config.textColor),
                    fontFamily: config.fontFamily,
                    fontWeight: cell.isFree ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (cell.isLocked)
              const Positioned(
                top: 2,
                right: 2,
                child: Icon(Icons.lock, size: 10),
              ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../../domain/models.dart';

class VirtualBingoCard extends StatelessWidget {
  const VirtualBingoCard({
    required this.card,
    required this.rules,
    this.onCellTap,
    super.key,
  });

  final BingoCard card;
  final RuleSet rules;
  final ValueChanged<CellPosition>? onCellTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '${card.displayId}, bingo card',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              ColoredBox(
                color: colors.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      for (final label in rules.columnLabels)
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: colors.onPrimaryContainer,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              for (var row = 0; row < rules.rows; row++)
                Expanded(
                  child: Row(
                    children: [
                      for (var column = 0; column < rules.columns; column++)
                        Expanded(
                          child: _VirtualCell(
                            cell: card.cellAt(row, column),
                            onTap: onCellTap,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VirtualCell extends StatelessWidget {
  const _VirtualCell({required this.cell, this.onTap});

  final CardCell cell;
  final ValueChanged<CellPosition>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final interactive = onTap != null && !cell.isFree;
    final label = cell.isFree ? 'Free cell' : '${cell.value}';
    return Semantics(
      button: interactive,
      label: cell.isFree
          ? label
          : '$label, ${cell.isLocked ? 'locked' : 'unlocked'}',
      child: Material(
        color: cell.isFree ? colors.tertiaryContainer : colors.surface,
        child: InkWell(
          onTap: interactive ? () => onTap!(cell.position) : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: FittedBox(
                      child: Text(
                        cell.isFree ? 'FREE' : '${cell.value}',
                        style: TextStyle(
                          color: cell.isFree
                              ? colors.onTertiaryContainer
                              : colors.onSurface,
                          fontSize: cell.isFree ? 17 : 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                if (cell.isLocked)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(Icons.lock, size: 12, color: colors.primary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'contracts.dart';
import 'models.dart';
import 'pattern_service.dart';

class CoverageCardGenerator implements CardGenerator {
  const CoverageCardGenerator({this.optimizationIterations = 1800});

  final int optimizationIterations;

  @override
  GenerationResult generate({
    required RuleSet rules,
    required List<PatternDefinition> patterns,
    required int cardCount,
    required int seed,
    List<BingoCard> previousCards = const [],
  }) {
    final errors = rules.validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.join(' '));
    if (cardCount < 1 || cardCount > 18) {
      throw ArgumentError.value(
        cardCount,
        'cardCount',
        'Must be between 1 and 18.',
      );
    }
    if (patterns.any((pattern) => pattern.cells.isEmpty)) {
      throw ArgumentError('Winning patterns cannot be empty.');
    }

    final random = Random(seed);
    final cards = <BingoCard>[];
    for (var offset = 0; offset < cardCount; offset += 6) {
      final groupSize = min(6, cardCount - offset);
      final previousGroup = previousCards
          .where((card) => card.setIndex == offset ~/ 6 + 1)
          .toList();
      cards.addAll(
        _buildGroup(
          rules: rules,
          patterns: patterns,
          count: groupSize,
          globalOffset: offset,
          seed: seed,
          random: random,
          previous: previousGroup,
        ),
      );
    }
    _ensureUnique(cards, rules, random);
    return GenerationResult(cards, _report(cards, rules, patterns));
  }

  List<BingoCard> _buildGroup({
    required RuleSet rules,
    required List<PatternDefinition> patterns,
    required int count,
    required int globalOffset,
    required int seed,
    required Random random,
    required List<BingoCard> previous,
  }) {
    final grids = <List<CardCell>>[];
    for (var cardIndex = 0; cardIndex < count; cardIndex++) {
      final old = cardIndex < previous.length ? previous[cardIndex] : null;
      grids.add([
        for (var row = 0; row < rules.rows; row++)
          for (var column = 0; column < rules.columns; column++)
            _startingCell(row, column, rules, old),
      ]);
    }

    for (var column = 0; column < rules.columns; column++) {
      final counts = <int, int>{
        for (final value in rules.columnRanges[column].values) value: 0,
      };
      final usedByCard = [for (var i = 0; i < count; i++) <int>{}];

      for (var cardIndex = 0; cardIndex < count; cardIndex++) {
        for (final cell in grids[cardIndex].where(
          (cell) => cell.position.column == column,
        )) {
          if (!cell.isFree && cell.isLocked && cell.value != null) {
            if (!counts.containsKey(cell.value)) {
              throw StateError(
                'Locked value ${cell.value} is outside its column range.',
              );
            }
            if (!usedByCard[cardIndex].add(cell.value!)) {
              throw StateError(
                'Locked values duplicate ${cell.value} on one card.',
              );
            }
            counts[cell.value!] = counts[cell.value!]! + 1;
          }
        }
      }

      for (var cardIndex = 0; cardIndex < count; cardIndex++) {
        for (
          var cellIndex = 0;
          cellIndex < grids[cardIndex].length;
          cellIndex++
        ) {
          final cell = grids[cardIndex][cellIndex];
          if (cell.position.column != column ||
              cell.isFree ||
              (cell.isLocked && cell.value != null)) {
            continue;
          }
          final available = counts.keys
              .where((value) => !usedByCard[cardIndex].contains(value))
              .toList();
          if (available.isEmpty) {
            throw StateError(
              'Locks leave no valid number for ${cell.position.key}.',
            );
          }
          final lowestCount = available
              .map((value) => counts[value]!)
              .reduce(min);
          final preferred =
              available.where((value) => counts[value] == lowestCount).toList()
                ..shuffle(random);
          final chosen = preferred.first;
          grids[cardIndex][cellIndex] = cell.copyWith(value: chosen);
          counts[chosen] = counts[chosen]! + 1;
          usedByCard[cardIndex].add(chosen);
        }
      }
    }

    var cards = [
      for (var cardIndex = 0; cardIndex < count; cardIndex++)
        BingoCard(
          id: previous.length > cardIndex && previous[cardIndex].isLocked
              ? previous[cardIndex].id
              : _shortId(seed, globalOffset + cardIndex),
          setIndex: globalOffset ~/ 6 + 1,
          cardIndex: cardIndex + 1,
          cells: grids[cardIndex],
          isLocked: previous.length > cardIndex && previous[cardIndex].isLocked,
        ),
    ];

    var currentCost = _cost(cards, rules, patterns);
    var bestCost = currentCost;
    var bestCards = List<BingoCard>.from(cards);
    for (
      var iteration = 0;
      iteration < optimizationIterations && cards.length > 1;
      iteration++
    ) {
      final firstIndex = random.nextInt(cards.length);
      var secondIndex = random.nextInt(cards.length - 1);
      if (secondIndex >= firstIndex) secondIndex++;
      final column = random.nextInt(rules.columns);
      final firstCandidates = cards[firstIndex].cells
          .where(
            (cell) =>
                cell.position.column == column &&
                !cell.isFree &&
                !cell.isLocked,
          )
          .toList();
      final secondCandidates = cards[secondIndex].cells
          .where(
            (cell) =>
                cell.position.column == column &&
                !cell.isFree &&
                !cell.isLocked,
          )
          .toList();
      if (firstCandidates.isEmpty || secondCandidates.isEmpty) continue;
      final firstCell = firstCandidates[random.nextInt(firstCandidates.length)];
      final secondCell =
          secondCandidates[random.nextInt(secondCandidates.length)];
      if (firstCell.value == secondCell.value ||
          _hasValue(
            cards[firstIndex],
            column,
            secondCell.value!,
            except: firstCell.position,
          ) ||
          _hasValue(
            cards[secondIndex],
            column,
            firstCell.value!,
            except: secondCell.position,
          )) {
        continue;
      }
      final candidate = List<BingoCard>.from(cards);
      candidate[firstIndex] = _replaceValue(
        cards[firstIndex],
        firstCell.position,
        secondCell.value!,
      );
      candidate[secondIndex] = _replaceValue(
        cards[secondIndex],
        secondCell.position,
        firstCell.value!,
      );
      final candidateCost = _cost(candidate, rules, patterns);
      if (candidateCost <= currentCost || random.nextDouble() < 0.002) {
        cards = candidate;
        currentCost = candidateCost;
        if (candidateCost < bestCost) {
          bestCost = candidateCost;
          bestCards = List<BingoCard>.from(candidate);
        }
      }
    }
    return bestCards;
  }

  CardCell _startingCell(
    int row,
    int column,
    RuleSet rules,
    BingoCard? previous,
  ) {
    final position = CellPosition(row, column);
    final isFree = rules.freeCells.contains(position);
    if (previous != null) {
      final old = previous.cellAt(row, column);
      if (previous.isLocked || old.isLocked) {
        return CardCell(
          position: position,
          value: isFree ? null : old.value,
          isFree: isFree,
          isLocked: true,
        );
      }
    }
    return CardCell(position: position, isFree: isFree);
  }

  bool _hasValue(
    BingoCard card,
    int column,
    int value, {
    required CellPosition except,
  }) => card.cells.any(
    (cell) =>
        cell.position.column == column &&
        cell.position != except &&
        cell.value == value,
  );

  BingoCard _replaceValue(BingoCard card, CellPosition position, int value) =>
      card.copyWith(
        cells: [
          for (final cell in card.cells)
            if (cell.position == position)
              cell.copyWith(value: value)
            else
              cell,
        ],
      );

  double _cost(
    List<BingoCard> cards,
    RuleSet rules,
    List<PatternDefinition> patterns,
  ) {
    if (cards.length < 2) return 0;
    var overlap = 0.0;
    var pairs = 0;
    for (var first = 0; first < cards.length; first++) {
      final firstValues = cards[first].cells
          .where((cell) => !cell.isFree)
          .map((cell) => cell.value)
          .toSet();
      for (var second = first + 1; second < cards.length; second++) {
        final secondValues = cards[second].cells
            .where((cell) => !cell.isFree)
            .map((cell) => cell.value)
            .toSet();
        overlap += firstValues.intersection(secondValues).length;
        pairs++;
      }
    }
    var patternPenalty = 0.0;
    final service = const PatternService();
    for (final pattern in patterns) {
      for (final variant in service.expand(pattern, rules)) {
        for (var first = 0; first < cards.length; first++) {
          final firstValues = _valuesForMask(cards[first], variant);
          for (var second = first + 1; second < cards.length; second++) {
            patternPenalty += firstValues
                .intersection(_valuesForMask(cards[second], variant))
                .length;
          }
        }
      }
    }
    return overlap / pairs + patternPenalty * 0.7;
  }

  Set<int> _valuesForMask(BingoCard card, Set<CellPosition> mask) => card.cells
      .where(
        (cell) =>
            mask.contains(cell.position) && !cell.isFree && cell.value != null,
      )
      .map((cell) => cell.value!)
      .toSet();

  void _ensureUnique(List<BingoCard> cards, RuleSet rules, Random random) {
    final signatures = <String>{};
    for (var index = 0; index < cards.length; index++) {
      var signature = _signature(cards[index]);
      if (signatures.add(signature)) continue;
      var repaired = false;
      for (var attempt = 0; attempt < 100 && !repaired; attempt++) {
        final column = random.nextInt(rules.columns);
        final candidates = cards[index].cells
            .where(
              (cell) =>
                  cell.position.column == column &&
                  !cell.isFree &&
                  !cell.isLocked,
            )
            .toList();
        if (candidates.length < 2) continue;
        final a = candidates[random.nextInt(candidates.length)];
        var b = candidates[random.nextInt(candidates.length - 1)];
        if (b.position == a.position) b = candidates.last;
        var changed = _replaceValue(cards[index], a.position, b.value!);
        changed = _replaceValue(changed, b.position, a.value!);
        final changedSignature = _signature(changed);
        if (!signatures.contains(changedSignature)) {
          cards[index] = changed;
          signature = changedSignature;
          repaired = true;
        }
      }
      if (!repaired) {
        throw StateError('Locked cards prevent creation of a unique batch.');
      }
      signatures.add(signature);
    }
  }

  String _signature(BingoCard card) =>
      card.cells.map((cell) => cell.isFree ? 'F' : '${cell.value}').join(',');

  OptimizationReport _report(
    List<BingoCard> cards,
    RuleSet rules,
    List<PatternDefinition> patterns,
  ) {
    final frequencies = <int, int>{};
    for (final card in cards) {
      for (final cell in card.cells.where(
        (cell) => !cell.isFree && cell.value != null,
      )) {
        frequencies[cell.value!] = (frequencies[cell.value!] ?? 0) + 1;
      }
    }
    var pairFraction = 0.0;
    var patternFraction = 0.0;
    var pairs = 0;
    var patternPairs = 0;
    final numberedCells = rules.rows * rules.columns - rules.freeCells.length;
    final service = const PatternService();
    for (var first = 0; first < cards.length; first++) {
      final a = cards[first].cells
          .where((cell) => !cell.isFree)
          .map((cell) => cell.value)
          .toSet();
      for (var second = first + 1; second < cards.length; second++) {
        final b = cards[second].cells
            .where((cell) => !cell.isFree)
            .map((cell) => cell.value)
            .toSet();
        pairFraction += a.intersection(b).length / numberedCells;
        pairs++;
        for (final pattern in patterns) {
          for (final variant in service.expand(pattern, rules)) {
            final pa = _valuesForMask(cards[first], variant);
            final pb = _valuesForMask(cards[second], variant);
            final union = pa.union(pb).length;
            if (union > 0) {
              patternFraction += pa.intersection(pb).length / union;
            }
            patternPairs++;
          }
        }
      }
    }
    final averagePair = pairs == 0 ? 0.0 : pairFraction / pairs;
    final averagePattern = patternPairs == 0
        ? 0.0
        : patternFraction / patternPairs;
    final score = (100 - averagePair * 65 - averagePattern * 35)
        .clamp(0, 100)
        .toDouble();
    return OptimizationReport(
      score: score,
      numberFrequencies: frequencies,
      pairwiseOverlap: averagePair,
      patternOverlap: averagePattern,
      warnings: const [
        'Coverage reduces correlation between your cards; it does not guarantee a win.',
      ],
    );
  }

  String _shortId(int seed, int index) => sha256
      .convert(utf8.encode('$seed:$index'))
      .toString()
      .substring(0, 6)
      .toUpperCase();
}

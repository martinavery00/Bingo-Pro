import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models.dart';
import 'pattern_service.dart';

class PlaySession {
  const PlaySession({
    required this.projectId,
    required this.setIndex,
    required this.sourceSignature,
    required this.calledNumbers,
    required this.startedAt,
    required this.updatedAt,
  });

  final String projectId;
  final int setIndex;
  final String sourceSignature;
  final List<int> calledNumbers;
  final DateTime startedAt;
  final DateTime updatedAt;

  PlaySession copyWith({List<int>? calledNumbers, DateTime? updatedAt}) =>
      PlaySession(
        projectId: projectId,
        setIndex: setIndex,
        sourceSignature: sourceSignature,
        calledNumbers: calledNumbers ?? this.calledNumbers,
        startedAt: startedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class MissingPlayNumber {
  const MissingPlayNumber({
    required this.position,
    required this.value,
    required this.columnLabel,
  });

  final CellPosition position;
  final int value;
  final String columnLabel;

  String get displayLabel => '$columnLabel-$value';
}

class PlayPatternResult {
  const PlayPatternResult({
    required this.cardId,
    required this.cardDisplayId,
    required this.patternId,
    required this.patternName,
    required this.transform,
    required this.requiredCount,
    required this.markedCount,
    required this.missingNumbers,
  });

  final String cardId;
  final String cardDisplayId;
  final String patternId;
  final String patternName;
  final PatternTransform transform;
  final int requiredCount;
  final int markedCount;
  final List<MissingPlayNumber> missingNumbers;

  bool get isComplete => missingNumbers.isEmpty;
  bool get isOneAway => missingNumbers.length == 1;

  String get variantLabel => switch (transform) {
    PatternTransform.original => patternName,
    PatternTransform.rotate90 => '$patternName · 90°',
    PatternTransform.rotate180 => '$patternName · 180°',
    PatternTransform.rotate270 => '$patternName · 270°',
    PatternTransform.mirror => '$patternName · mirrored',
    PatternTransform.mirrorRotate90 => '$patternName · mirrored 90°',
    PatternTransform.mirrorRotate180 => '$patternName · mirrored 180°',
    PatternTransform.mirrorRotate270 => '$patternName · mirrored 270°',
  };

  String get identity => '$cardId|$patternId|${transform.name}';
}

class PlayCardEvaluation {
  const PlayCardEvaluation({
    required this.cardId,
    required this.markedPositions,
    required this.oneAwayPatterns,
    required this.completedPatterns,
  });

  final String cardId;
  final Set<CellPosition> markedPositions;
  final List<PlayPatternResult> oneAwayPatterns;
  final List<PlayPatternResult> completedPatterns;
}

class PlayEvaluation {
  const PlayEvaluation({required this.cards});

  final List<PlayCardEvaluation> cards;

  List<PlayPatternResult> get oneAwayPatterns => [
    for (final card in cards) ...card.oneAwayPatterns,
  ];

  List<PlayPatternResult> get completedPatterns => [
    for (final card in cards) ...card.completedPatterns,
  ];

  PlayCardEvaluation forCard(String cardId) =>
      cards.firstWhere((card) => card.cardId == cardId);
}

class PlayEvaluator {
  const PlayEvaluator({this.patternService = const PatternService()});

  final PatternService patternService;

  PlayEvaluation evaluate({
    required RuleSet rules,
    required List<PatternDefinition> patterns,
    required List<BingoCard> cards,
    required Iterable<int> calledNumbers,
  }) {
    final called = calledNumbers.toSet();
    final evaluations = <PlayCardEvaluation>[];
    for (final card in cards) {
      final marked = {
        for (final cell in card.cells)
          if (!cell.isFree && cell.value != null && called.contains(cell.value))
            cell.position,
      };
      final oneAway = <PlayPatternResult>[];
      final completed = <PlayPatternResult>[];
      for (final pattern in patterns) {
        for (final variant in patternService.expandVariants(pattern, rules)) {
          final requiredCells = <CardCell>[];
          for (final position in variant.cells) {
            final matches = card.cells.where(
              (cell) => cell.position == position && !cell.isFree,
            );
            if (matches.isNotEmpty) requiredCells.add(matches.single);
          }
          // Free-only variants do not represent a playable win condition.
          if (requiredCells.isEmpty) continue;
          final missing = <MissingPlayNumber>[
            for (final cell in requiredCells)
              if (!called.contains(cell.value))
                MissingPlayNumber(
                  position: cell.position,
                  value: cell.value!,
                  columnLabel: rules.columnLabels[cell.position.column],
                ),
          ];
          final result = PlayPatternResult(
            cardId: card.id,
            cardDisplayId: card.displayId,
            patternId: pattern.id,
            patternName: pattern.name,
            transform: variant.transform,
            requiredCount: requiredCells.length,
            markedCount: requiredCells.length - missing.length,
            missingNumbers: missing,
          );
          if (result.isComplete) {
            completed.add(result);
          } else if (result.isOneAway) {
            oneAway.add(result);
          }
        }
      }
      evaluations.add(
        PlayCardEvaluation(
          cardId: card.id,
          markedPositions: marked,
          oneAwayPatterns: oneAway,
          completedPatterns: completed,
        ),
      );
    }
    return PlayEvaluation(cards: evaluations);
  }
}

String playSourceSignature(BingoProject project, int setIndex) {
  final cards =
      project.cards.where((card) => card.setIndex == setIndex).toList()
        ..sort((a, b) => a.cardIndex.compareTo(b.cardIndex));
  final payload = {
    'rules': project.rules.toJson(),
    'patterns': project.patterns.map((pattern) => pattern.toJson()).toList(),
    'cards': [
      for (final card in cards)
        {
          'id': card.id,
          'setIndex': card.setIndex,
          'cardIndex': card.cardIndex,
          'cells': [
            for (final cell in card.cells)
              {
                'position': cell.position.toJson(),
                'value': cell.value,
                'isFree': cell.isFree,
              },
          ],
        },
    ],
  };
  return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
}

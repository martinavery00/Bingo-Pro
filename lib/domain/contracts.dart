import 'dart:typed_data';

import 'models.dart';

abstract interface class ProjectRepository {
  Stream<List<BingoProject>> watchAll();
  Future<BingoProject?> find(String id);
  Future<void> save(BingoProject project);
  Future<void> delete(String id);
}

class GenerationResult {
  const GenerationResult(this.cards, this.report);

  final List<BingoCard> cards;
  final OptimizationReport report;
}

abstract interface class CardGenerator {
  GenerationResult generate({
    required RuleSet rules,
    required List<PatternDefinition> patterns,
    required int cardCount,
    required int seed,
    List<BingoCard> previousCards,
  });
}

abstract interface class PdfExporter {
  Future<Uint8List> build(BingoProject project);
  Future<Uint8List> buildCalibrationPage(PrintLayoutConfig layout);
}

import 'dart:typed_data';

import 'models.dart';
import 'play_session.dart';

abstract interface class ProjectRepository {
  Stream<List<BingoProject>> watchAll();
  Future<BingoProject?> find(String id);
  Future<void> save(BingoProject project);
  Future<void> delete(String id);
}

abstract interface class PlaySessionRepository {
  Stream<List<PlaySession>> watchForProject(String projectId);
  Future<PlaySession?> find(String projectId, int setIndex);
  Future<void> save(PlaySession session);
  Future<void> delete(String projectId, int setIndex);
  Future<void> deleteForProject(String projectId);
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

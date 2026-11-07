import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../data/drift_project_repository.dart';
import '../domain/contracts.dart';
import '../domain/coverage_card_generator.dart';
import '../domain/models.dart';
import '../printing/bingo_pdf_exporter.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => DriftProjectRepository(ref.watch(databaseProvider)),
);

final projectListProvider = StreamProvider<List<BingoProject>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);

final pdfExporterProvider = Provider<PdfExporter>(
  (_) => const BingoPdfExporter(),
);

final projectEditorProvider = NotifierProvider<ProjectEditor, BingoProject?>(
  ProjectEditor.new,
);

class ProjectEditor extends Notifier<BingoProject?> {
  @override
  BingoProject? build() => null;

  Future<void> create({String name = 'My bingo cards'}) async {
    final now = DateTime.now();
    final project = BingoProject(
      id: const Uuid().v4(),
      name: name,
      rules: RuleSet.standard75(),
      patterns: _straightLinePatterns(5, 5),
      theme: CardThemeConfig.comfort(),
      printLayout: const PrintLayoutConfig(),
      cardCount: 6,
      seed: Random.secure().nextInt(1 << 31),
      cards: const [],
      createdAt: now,
      updatedAt: now,
    );
    state = project;
    await _save();
  }

  void open(BingoProject project) => state = project;

  Future<void> rename(String name) =>
      _update(state!.copyWith(name: name.trim()));

  Future<void> setCardCount(int count) =>
      _update(state!.copyWith(cardCount: count, cards: const []));

  Future<void> setRules(RuleSet rules) {
    final project = state!;
    final dimensionsChanged =
        project.rules.rows != rules.rows ||
        project.rules.columns != rules.columns;
    return _update(
      project.copyWith(
        rules: rules,
        patterns: dimensionsChanged
            ? _straightLinePatterns(rules.rows, rules.columns)
            : project.patterns,
        cards: const [],
      ),
    );
  }

  Future<void> setPatterns(List<PatternDefinition> patterns) =>
      _update(state!.copyWith(patterns: patterns, cards: const []));

  Future<void> setTheme(CardThemeConfig theme) =>
      _update(state!.copyWith(theme: theme));

  Future<void> setPrintLayout(PrintLayoutConfig layout) =>
      _update(state!.copyWith(printLayout: layout));

  Future<void> generate({bool keepSeed = false}) async {
    final project = state!;
    final seed = keepSeed ? project.seed : Random.secure().nextInt(1 << 31);
    final payload = await compute(_generateCards, {
      'rules': project.rules.toJson(),
      'patterns': project.patterns.map((pattern) => pattern.toJson()).toList(),
      'cardCount': project.cardCount,
      'seed': seed,
      'cards': project.cards.map((card) => card.toJson()).toList(),
    });
    final cards = (payload['cards'] as List)
        .map((value) => BingoCard.fromJson(value as Map<String, dynamic>))
        .toList();
    final report = OptimizationReport.fromJson(
      payload['report'] as Map<String, dynamic>,
    );
    await _update(project.copyWith(seed: seed, cards: cards, report: report));
  }

  Future<void> toggleCardLock(int cardIndex) async {
    final project = state!;
    final cards = List<BingoCard>.from(project.cards);
    final card = cards[cardIndex];
    final locked = !card.isLocked;
    cards[cardIndex] = card.copyWith(
      isLocked: locked,
      cells: [for (final cell in card.cells) cell.copyWith(isLocked: locked)],
    );
    await _update(project.copyWith(cards: cards));
  }

  Future<void> toggleCellLock(int cardIndex, CellPosition position) async {
    final project = state!;
    final cards = List<BingoCard>.from(project.cards);
    final card = cards[cardIndex];
    cards[cardIndex] = card.copyWith(
      isLocked: false,
      cells: [
        for (final cell in card.cells)
          if (cell.position == position && !cell.isFree)
            cell.copyWith(isLocked: !cell.isLocked)
          else
            cell,
      ],
    );
    await _update(project.copyWith(cards: cards));
  }

  Future<void> replaceImported(BingoProject project) async {
    final now = DateTime.now();
    final copy = BingoProject(
      id: const Uuid().v4(),
      name: '${project.name} (imported)',
      rules: project.rules,
      patterns: project.patterns,
      theme: project.theme,
      printLayout: project.printLayout,
      cardCount: project.cardCount,
      seed: project.seed,
      cards: project.cards,
      report: project.report,
      createdAt: now,
      updatedAt: now,
    );
    state = copy;
    await _save();
  }

  Future<void> _update(BingoProject project) async {
    state = project.copyWith(updatedAt: DateTime.now());
    await _save();
  }

  Future<void> _save() async {
    if (state != null) await ref.read(projectRepositoryProvider).save(state!);
  }
}

Map<String, dynamic> _generateCards(Map<String, dynamic> input) {
  final rules = RuleSet.fromJson(input['rules'] as Map<String, dynamic>);
  final patterns = (input['patterns'] as List)
      .map((value) => PatternDefinition.fromJson(value as Map<String, dynamic>))
      .toList();
  final previous = (input['cards'] as List)
      .map((value) => BingoCard.fromJson(value as Map<String, dynamic>))
      .toList();
  final result = const CoverageCardGenerator().generate(
    rules: rules,
    patterns: patterns,
    cardCount: input['cardCount'] as int,
    seed: input['seed'] as int,
    previousCards: previous,
  );
  return {
    'cards': result.cards.map((card) => card.toJson()).toList(),
    'report': result.report.toJson(),
  };
}

List<PatternDefinition> _straightLinePatterns(int rows, int columns) {
  final patterns = <PatternDefinition>[];
  for (var row = 0; row < rows; row++) {
    patterns.add(
      PatternDefinition(
        id: 'row-$row',
        name: 'Row ${row + 1}',
        cells: {
          for (var column = 0; column < columns; column++)
            CellPosition(row, column),
        },
      ),
    );
  }
  for (var column = 0; column < columns; column++) {
    patterns.add(
      PatternDefinition(
        id: 'column-$column',
        name: 'Column ${column + 1}',
        cells: {for (var row = 0; row < rows; row++) CellPosition(row, column)},
      ),
    );
  }
  if (rows == columns) {
    patterns.addAll([
      PatternDefinition(
        id: 'diagonal-main',
        name: 'Main diagonal',
        cells: {for (var i = 0; i < rows; i++) CellPosition(i, i)},
      ),
      PatternDefinition(
        id: 'diagonal-reverse',
        name: 'Reverse diagonal',
        cells: {for (var i = 0; i < rows; i++) CellPosition(i, rows - 1 - i)},
      ),
    ]);
  }
  return patterns;
}

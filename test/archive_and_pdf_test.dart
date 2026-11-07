import 'dart:convert';

import 'package:bingo_pro/data/project_archive_service.dart';
import 'package:bingo_pro/domain/coverage_card_generator.dart';
import 'package:bingo_pro/domain/models.dart';
import 'package:bingo_pro/printing/bingo_pdf_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('project archive round trips and rejects tampering', () {
    final project = _project();
    const service = ProjectArchiveService();
    final archive = service.export(project);
    expect(service.import(archive).name, project.name);

    final decoded = jsonDecode(archive) as Map<String, dynamic>;
    (decoded['payload'] as Map<String, dynamic>)['name'] = 'Changed';
    expect(() => service.import(jsonEncode(decoded)), throwsFormatException);
  });

  test('PDF exporter produces a vector PDF and calibration page', () async {
    final project = _project();
    const exporter = BingoPdfExporter();
    final pdf = await exporter.build(project);
    final calibration = await exporter.buildCalibrationPage(
      project.printLayout,
    );
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
    expect(ascii.decode(calibration.take(4).toList()), '%PDF');
    expect(pdf.length, greaterThan(1000));
  });

  test('all bundled font choices embed successfully', () async {
    const exporter = BingoPdfExporter();
    for (final family in [
      'Atkinson Hyperlegible',
      'Noto Sans',
      'Roboto Slab',
    ]) {
      final project = _project();
      final pdf = await exporter.build(
        project.copyWith(theme: project.theme.copyWith(fontFamily: family)),
      );
      expect(pdf.length, greaterThan(1000), reason: family);
    }
  });
}

BingoProject _project() {
  final rules = RuleSet.standard75();
  final pattern = PatternDefinition(
    id: 'row',
    name: 'Row',
    cells: {for (var column = 0; column < 5; column++) CellPosition(0, column)},
  );
  final generated = const CoverageCardGenerator(optimizationIterations: 20)
      .generate(rules: rules, patterns: [pattern], cardCount: 6, seed: 5);
  final now = DateTime.utc(2026, 1, 1);
  return BingoProject(
    id: 'project',
    name: 'Test project',
    rules: rules,
    patterns: [pattern],
    theme: CardThemeConfig.comfort(),
    printLayout: const PrintLayoutConfig(),
    cardCount: 6,
    seed: 5,
    cards: generated.cards,
    report: generated.report,
    createdAt: now,
    updatedAt: now,
  );
}

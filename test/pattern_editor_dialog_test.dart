import 'package:bingo_pro/app/app_theme.dart';
import 'package:bingo_pro/domain/models.dart';
import 'package:bingo_pro/features/project/steps/patterns_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pattern preview updates as transforms are enabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openDialog(tester, RuleSet.custom(rows: 3, columns: 3));

    expect(find.text('Select cells to preview variants.'), findsOneWidget);
    for (final index in [0, 3, 4]) {
      final cell = find.byKey(ValueKey('pattern-cell-$index'));
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pump();
    }
    expect(find.text('Variants (1 unique variant)'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);

    final rotations = find.byKey(const ValueKey('include-rotations'));
    await tester.ensureVisible(rotations);
    await tester.tap(rotations);
    await tester.pump();
    expect(find.text('Variants (4 unique variants)'), findsOneWidget);
    expect(find.text('90°'), findsOneWidget);
    expect(find.text('180°'), findsOneWidget);

    final mirrors = find.byKey(const ValueKey('include-mirrors'));
    await tester.ensureVisible(mirrors);
    await tester.tap(mirrors);
    await tester.pump();
    expect(find.text('Variants (8 unique variants)'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('pattern-variants-list')),
      const Offset(-400, 0),
    );
    await tester.pump();
    expect(find.text('Mirror'), findsOneWidget);
    expect(find.text('Mirror + 90°'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('5 by 5 preview fits a phone-sized dialog', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openDialog(tester, RuleSet.custom(rows: 5, columns: 5));

    final cell = find.byKey(const ValueKey('pattern-cell-0'));
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    final rotations = find.byKey(const ValueKey('include-rotations'));
    await tester.ensureVisible(rotations);
    await tester.tap(rotations);
    await tester.pump();

    expect(find.text('Variants (4 unique variants)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rectangular preview stays dimension preserving', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openDialog(tester, RuleSet.custom(rows: 3, columns: 5));

    for (final index in [0, 1]) {
      final cell = find.byKey(ValueKey('pattern-cell-$index'));
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pump();
    }
    for (final key in ['include-rotations', 'include-mirrors']) {
      final toggle = find.byKey(ValueKey(key));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
    }

    expect(find.text('Variants (4 unique variants)'), findsOneWidget);
    expect(find.text('90°'), findsNothing);
    expect(find.text('270°'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openDialog(WidgetTester tester, RuleSet rules) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: BingoAppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PatternEditorDialog(rules: rules),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

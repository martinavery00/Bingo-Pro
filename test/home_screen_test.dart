import 'package:bingo_pro/app/app_theme.dart';
import 'package:bingo_pro/app/providers.dart';
import 'package:bingo_pro/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen presents the empty-state workflow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectListProvider.overrideWith((_) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: BingoAppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bingo Pro'), findsOneWidget);
    expect(find.text('Create your first card set'), findsOneWidget);
    expect(find.text('New project'), findsOneWidget);
  });
}

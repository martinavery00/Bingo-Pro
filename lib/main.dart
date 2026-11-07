import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_theme.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BingoProApp()));
}

class BingoProApp extends StatelessWidget {
  const BingoProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bingo Pro',
      debugShowCheckedModeBanner: false,
      theme: BingoAppTheme.light,
      home: const HomeScreen(),
    );
  }
}

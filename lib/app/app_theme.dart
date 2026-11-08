import 'package:flutter/material.dart';

@immutable
class BingoPlayColors extends ThemeExtension<BingoPlayColors> {
  const BingoPlayColors({
    required this.puroContainer,
    required this.onPuroContainer,
    required this.puroBorder,
  });

  static const golden = BingoPlayColors(
    puroContainer: Color(0xFFF4C95D),
    onPuroContainer: Color(0xFF332400),
    puroBorder: Color(0xFF9A6700),
  );

  final Color puroContainer;
  final Color onPuroContainer;
  final Color puroBorder;

  @override
  BingoPlayColors copyWith({
    Color? puroContainer,
    Color? onPuroContainer,
    Color? puroBorder,
  }) => BingoPlayColors(
    puroContainer: puroContainer ?? this.puroContainer,
    onPuroContainer: onPuroContainer ?? this.onPuroContainer,
    puroBorder: puroBorder ?? this.puroBorder,
  );

  @override
  BingoPlayColors lerp(BingoPlayColors? other, double t) {
    if (other == null) return this;
    return BingoPlayColors(
      puroContainer: Color.lerp(puroContainer, other.puroContainer, t)!,
      onPuroContainer: Color.lerp(onPuroContainer, other.onPuroContainer, t)!,
      puroBorder: Color.lerp(puroBorder, other.puroBorder, t)!,
    );
  }
}

class BingoAppTheme {
  static const canvas = Color(0xFFF4F1EA);
  static const charcoal = Color(0xFF1F2933);
  static const teal = Color(0xFF2F6F6D);
  static const paleTeal = Color(0xFFD9E7E5);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
      surface: canvas,
    ),
    extensions: const [BingoPlayColors.golden],
    scaffoldBackgroundColor: canvas,
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Color(0x1F52606D)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

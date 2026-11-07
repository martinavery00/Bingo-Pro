import 'dart:convert';

class CellPosition {
  const CellPosition(this.row, this.column);

  final int row;
  final int column;

  String get key => '$row:$column';

  Map<String, Object> toJson() => {'row': row, 'column': column};

  factory CellPosition.fromJson(Map<String, dynamic> json) =>
      CellPosition(json['row'] as int, json['column'] as int);

  @override
  bool operator ==(Object other) =>
      other is CellPosition && row == other.row && column == other.column;

  @override
  int get hashCode => Object.hash(row, column);
}

class NumberRange {
  const NumberRange({required this.start, required this.end});

  final int start;
  final int end;

  List<int> get values => [
    for (var value = start; value <= end; value++) value,
  ];

  Map<String, Object> toJson() => {'start': start, 'end': end};

  factory NumberRange.fromJson(Map<String, dynamic> json) =>
      NumberRange(start: json['start'] as int, end: json['end'] as int);
}

class RuleSet {
  const RuleSet({
    required this.name,
    required this.rows,
    required this.columns,
    required this.columnLabels,
    required this.columnRanges,
    required this.freeCells,
    this.isStandard75 = false,
  });

  final String name;
  final int rows;
  final int columns;
  final List<String> columnLabels;
  final List<NumberRange> columnRanges;
  final Set<CellPosition> freeCells;
  final bool isStandard75;

  factory RuleSet.standard75() => RuleSet(
    name: 'Standard 75-ball',
    rows: 5,
    columns: 5,
    columnLabels: ['B', 'I', 'N', 'G', 'O'],
    columnRanges: [
      NumberRange(start: 1, end: 15),
      NumberRange(start: 16, end: 30),
      NumberRange(start: 31, end: 45),
      NumberRange(start: 46, end: 60),
      NumberRange(start: 61, end: 75),
    ],
    freeCells: {const CellPosition(2, 2)},
    isStandard75: true,
  );

  factory RuleSet.custom({int rows = 5, int columns = 5}) {
    final rangeSize = rows * 3;
    return RuleSet(
      name: 'Custom rules',
      rows: rows,
      columns: columns,
      columnLabels: [
        for (var i = 0; i < columns; i++) String.fromCharCode(65 + i),
      ],
      columnRanges: [
        for (var i = 0; i < columns; i++)
          NumberRange(start: i * rangeSize + 1, end: (i + 1) * rangeSize),
      ],
      freeCells: const {},
    );
  }

  List<String> validate() {
    final errors = <String>[];
    if (rows < 3 || rows > 7 || columns < 3 || columns > 7) {
      errors.add('Grid dimensions must be between 3 and 7.');
    }
    if (columnLabels.length != columns || columnRanges.length != columns) {
      errors.add('Every column needs one label and one number range.');
      return errors;
    }
    final occupied = <int>{};
    for (var column = 0; column < columns; column++) {
      final range = columnRanges[column];
      final needed =
          rows - freeCells.where((cell) => cell.column == column).length;
      if (range.end < range.start || range.values.length < needed) {
        errors.add(
          'Column ${columnLabels[column]} needs at least $needed numbers.',
        );
      }
      for (final value in range.values) {
        if (!occupied.add(value)) {
          errors.add('Column number ranges must not overlap.');
          break;
        }
      }
    }
    if (freeCells.any(
      (cell) =>
          cell.row < 0 ||
          cell.row >= rows ||
          cell.column < 0 ||
          cell.column >= columns,
    )) {
      errors.add('A free cell is outside the grid.');
    }
    return errors.toSet().toList();
  }

  RuleSet copyWith({
    String? name,
    int? rows,
    int? columns,
    List<String>? columnLabels,
    List<NumberRange>? columnRanges,
    Set<CellPosition>? freeCells,
    bool? isStandard75,
  }) => RuleSet(
    name: name ?? this.name,
    rows: rows ?? this.rows,
    columns: columns ?? this.columns,
    columnLabels: columnLabels ?? this.columnLabels,
    columnRanges: columnRanges ?? this.columnRanges,
    freeCells: freeCells ?? this.freeCells,
    isStandard75: isStandard75 ?? this.isStandard75,
  );

  Map<String, Object> toJson() => {
    'name': name,
    'rows': rows,
    'columns': columns,
    'columnLabels': columnLabels,
    'columnRanges': columnRanges.map((range) => range.toJson()).toList(),
    'freeCells': freeCells.map((cell) => cell.toJson()).toList(),
    'isStandard75': isStandard75,
  };

  factory RuleSet.fromJson(Map<String, dynamic> json) => RuleSet(
    name: json['name'] as String,
    rows: json['rows'] as int,
    columns: json['columns'] as int,
    columnLabels: List<String>.from(json['columnLabels'] as List),
    columnRanges: (json['columnRanges'] as List)
        .map((value) => NumberRange.fromJson(value as Map<String, dynamic>))
        .toList(),
    freeCells: (json['freeCells'] as List)
        .map((value) => CellPosition.fromJson(value as Map<String, dynamic>))
        .toSet(),
    isStandard75: json['isStandard75'] as bool? ?? false,
  );
}

class PatternDefinition {
  const PatternDefinition({
    required this.id,
    required this.name,
    required this.cells,
    this.includeRotations = false,
    this.includeReflections = false,
  });

  final String id;
  final String name;
  final Set<CellPosition> cells;
  final bool includeRotations;
  final bool includeReflections;

  PatternDefinition copyWith({
    String? name,
    Set<CellPosition>? cells,
    bool? includeRotations,
    bool? includeReflections,
  }) => PatternDefinition(
    id: id,
    name: name ?? this.name,
    cells: cells ?? this.cells,
    includeRotations: includeRotations ?? this.includeRotations,
    includeReflections: includeReflections ?? this.includeReflections,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'cells': cells.map((cell) => cell.toJson()).toList(),
    'includeRotations': includeRotations,
    'includeReflections': includeReflections,
  };

  factory PatternDefinition.fromJson(Map<String, dynamic> json) =>
      PatternDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        cells: (json['cells'] as List)
            .map(
              (value) => CellPosition.fromJson(value as Map<String, dynamic>),
            )
            .toSet(),
        includeRotations: json['includeRotations'] as bool? ?? false,
        includeReflections: json['includeReflections'] as bool? ?? false,
      );
}

class CardCell {
  const CardCell({
    required this.position,
    this.value,
    this.isFree = false,
    this.isLocked = false,
  });

  final CellPosition position;
  final int? value;
  final bool isFree;
  final bool isLocked;

  CardCell copyWith({int? value, bool? isLocked}) => CardCell(
    position: position,
    value: value ?? this.value,
    isFree: isFree,
    isLocked: isLocked ?? this.isLocked,
  );

  Map<String, Object?> toJson() => {
    'position': position.toJson(),
    'value': value,
    'isFree': isFree,
    'isLocked': isLocked,
  };

  factory CardCell.fromJson(Map<String, dynamic> json) => CardCell(
    position: CellPosition.fromJson(json['position'] as Map<String, dynamic>),
    value: json['value'] as int?,
    isFree: json['isFree'] as bool? ?? false,
    isLocked: json['isLocked'] as bool? ?? false,
  );
}

class BingoCard {
  const BingoCard({
    required this.id,
    required this.setIndex,
    required this.cardIndex,
    required this.cells,
    this.isLocked = false,
  });

  final String id;
  final int setIndex;
  final int cardIndex;
  final List<CardCell> cells;
  final bool isLocked;

  String get displayId => 'S$setIndex-C$cardIndex';
  CardCell cellAt(int row, int column) =>
      cells.firstWhere((cell) => cell.position == CellPosition(row, column));

  BingoCard copyWith({List<CardCell>? cells, bool? isLocked}) => BingoCard(
    id: id,
    setIndex: setIndex,
    cardIndex: cardIndex,
    cells: cells ?? this.cells,
    isLocked: isLocked ?? this.isLocked,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'setIndex': setIndex,
    'cardIndex': cardIndex,
    'cells': cells.map((cell) => cell.toJson()).toList(),
    'isLocked': isLocked,
  };

  factory BingoCard.fromJson(Map<String, dynamic> json) => BingoCard(
    id: json['id'] as String,
    setIndex: json['setIndex'] as int,
    cardIndex: json['cardIndex'] as int,
    cells: (json['cells'] as List)
        .map((value) => CardCell.fromJson(value as Map<String, dynamic>))
        .toList(),
    isLocked: json['isLocked'] as bool? ?? false,
  );
}

class CardThemeConfig {
  const CardThemeConfig({
    required this.preset,
    required this.fontFamily,
    required this.fontSize,
    required this.lineWidth,
    required this.outerLineWidth,
    required this.backgroundColor,
    required this.textColor,
    required this.gridColor,
    required this.headerColor,
    required this.headerTextColor,
    required this.freeColor,
    required this.accentColor,
    this.freeLabel = 'FREE',
  });

  final String preset;
  final String fontFamily;
  final double fontSize;
  final double lineWidth;
  final double outerLineWidth;
  final int backgroundColor;
  final int textColor;
  final int gridColor;
  final int headerColor;
  final int headerTextColor;
  final int freeColor;
  final int accentColor;
  final String freeLabel;

  factory CardThemeConfig.comfort() => const CardThemeConfig(
    preset: 'Comfort',
    fontFamily: 'Atkinson Hyperlegible',
    fontSize: 14,
    lineWidth: 1,
    outerLineWidth: 1.5,
    backgroundColor: 0xFFFFFFFF,
    textColor: 0xFF1F2933,
    gridColor: 0xFF52606D,
    headerColor: 0xFFD9E7E5,
    headerTextColor: 0xFF163B3F,
    freeColor: 0xFFF2E8CF,
    accentColor: 0xFF2F6F6D,
  );

  CardThemeConfig copyWith({
    String? preset,
    String? fontFamily,
    double? fontSize,
    double? lineWidth,
    double? outerLineWidth,
    int? backgroundColor,
    int? textColor,
    int? gridColor,
    int? headerColor,
    int? headerTextColor,
    int? freeColor,
    int? accentColor,
    String? freeLabel,
  }) => CardThemeConfig(
    preset: preset ?? this.preset,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    lineWidth: lineWidth ?? this.lineWidth,
    outerLineWidth: outerLineWidth ?? this.outerLineWidth,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    textColor: textColor ?? this.textColor,
    gridColor: gridColor ?? this.gridColor,
    headerColor: headerColor ?? this.headerColor,
    headerTextColor: headerTextColor ?? this.headerTextColor,
    freeColor: freeColor ?? this.freeColor,
    accentColor: accentColor ?? this.accentColor,
    freeLabel: freeLabel ?? this.freeLabel,
  );

  Map<String, Object> toJson() => {
    'preset': preset,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'lineWidth': lineWidth,
    'outerLineWidth': outerLineWidth,
    'backgroundColor': backgroundColor,
    'textColor': textColor,
    'gridColor': gridColor,
    'headerColor': headerColor,
    'headerTextColor': headerTextColor,
    'freeColor': freeColor,
    'accentColor': accentColor,
    'freeLabel': freeLabel,
  };

  factory CardThemeConfig.fromJson(Map<String, dynamic> json) =>
      CardThemeConfig(
        preset: json['preset'] as String,
        fontFamily: json['fontFamily'] as String,
        fontSize: (json['fontSize'] as num).toDouble(),
        lineWidth: (json['lineWidth'] as num).toDouble(),
        outerLineWidth:
            (json['outerLineWidth'] as num?)?.toDouble() ??
            (json['lineWidth'] as num).toDouble() + 0.5,
        backgroundColor: json['backgroundColor'] as int,
        textColor: json['textColor'] as int,
        gridColor: json['gridColor'] as int,
        headerColor: json['headerColor'] as int,
        headerTextColor: json['headerTextColor'] as int,
        freeColor: json['freeColor'] as int,
        accentColor: json['accentColor'] as int,
        freeLabel: json['freeLabel'] as String? ?? 'FREE',
      );
}

class PrintLayoutConfig {
  const PrintLayoutConfig({
    this.paper = 'A4',
    this.orientation = 'portrait',
    this.unit = 'mm',
    this.exactSize = false,
    this.cardWidth = 93,
    this.cardHeight = 89.5,
    this.margin = 10,
    this.gutter = 4,
    this.columns = 2,
    this.rows = 3,
    this.cutMarks = true,
  });

  final String paper;
  final String orientation;
  final String unit;
  final bool exactSize;
  final double cardWidth;
  final double cardHeight;
  final double margin;
  final double gutter;
  final int columns;
  final int rows;
  final bool cutMarks;

  int get cardsPerPage => columns * rows;

  PrintLayoutConfig copyWith({
    String? paper,
    String? orientation,
    String? unit,
    bool? exactSize,
    double? cardWidth,
    double? cardHeight,
    double? margin,
    double? gutter,
    int? columns,
    int? rows,
    bool? cutMarks,
  }) => PrintLayoutConfig(
    paper: paper ?? this.paper,
    orientation: orientation ?? this.orientation,
    unit: unit ?? this.unit,
    exactSize: exactSize ?? this.exactSize,
    cardWidth: cardWidth ?? this.cardWidth,
    cardHeight: cardHeight ?? this.cardHeight,
    margin: margin ?? this.margin,
    gutter: gutter ?? this.gutter,
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
    cutMarks: cutMarks ?? this.cutMarks,
  );

  Map<String, Object> toJson() => {
    'paper': paper,
    'orientation': orientation,
    'unit': unit,
    'exactSize': exactSize,
    'cardWidth': cardWidth,
    'cardHeight': cardHeight,
    'margin': margin,
    'gutter': gutter,
    'columns': columns,
    'rows': rows,
    'cutMarks': cutMarks,
  };

  factory PrintLayoutConfig.fromJson(Map<String, dynamic> json) =>
      PrintLayoutConfig(
        paper: json['paper'] as String,
        orientation: json['orientation'] as String,
        unit: json['unit'] as String,
        exactSize: json['exactSize'] as bool,
        cardWidth: (json['cardWidth'] as num).toDouble(),
        cardHeight: (json['cardHeight'] as num).toDouble(),
        margin: (json['margin'] as num).toDouble(),
        gutter: (json['gutter'] as num).toDouble(),
        columns: json['columns'] as int,
        rows: json['rows'] as int,
        cutMarks: json['cutMarks'] as bool,
      );
}

class OptimizationReport {
  const OptimizationReport({
    required this.score,
    required this.numberFrequencies,
    required this.pairwiseOverlap,
    required this.patternOverlap,
    this.warnings = const [],
  });

  final double score;
  final Map<int, int> numberFrequencies;
  final double pairwiseOverlap;
  final double patternOverlap;
  final List<String> warnings;

  Map<String, Object> toJson() => {
    'score': score,
    'numberFrequencies': numberFrequencies.map(
      (key, value) => MapEntry('$key', value),
    ),
    'pairwiseOverlap': pairwiseOverlap,
    'patternOverlap': patternOverlap,
    'warnings': warnings,
  };

  factory OptimizationReport.fromJson(Map<String, dynamic> json) =>
      OptimizationReport(
        score: (json['score'] as num).toDouble(),
        numberFrequencies: (json['numberFrequencies'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(int.parse(key), value as int)),
        pairwiseOverlap: (json['pairwiseOverlap'] as num).toDouble(),
        patternOverlap: (json['patternOverlap'] as num).toDouble(),
        warnings: List<String>.from(json['warnings'] as List? ?? const []),
      );
}

class BingoProject {
  const BingoProject({
    required this.id,
    required this.name,
    required this.rules,
    required this.patterns,
    required this.theme,
    required this.printLayout,
    required this.cardCount,
    required this.seed,
    required this.cards,
    required this.createdAt,
    required this.updatedAt,
    this.report,
    this.schemaVersion = 1,
  });

  final String id;
  final String name;
  final int schemaVersion;
  final RuleSet rules;
  final List<PatternDefinition> patterns;
  final CardThemeConfig theme;
  final PrintLayoutConfig printLayout;
  final int cardCount;
  final int seed;
  final List<BingoCard> cards;
  final OptimizationReport? report;
  final DateTime createdAt;
  final DateTime updatedAt;

  BingoProject copyWith({
    String? name,
    RuleSet? rules,
    List<PatternDefinition>? patterns,
    CardThemeConfig? theme,
    PrintLayoutConfig? printLayout,
    int? cardCount,
    int? seed,
    List<BingoCard>? cards,
    OptimizationReport? report,
    DateTime? updatedAt,
  }) => BingoProject(
    id: id,
    name: name ?? this.name,
    schemaVersion: schemaVersion,
    rules: rules ?? this.rules,
    patterns: patterns ?? this.patterns,
    theme: theme ?? this.theme,
    printLayout: printLayout ?? this.printLayout,
    cardCount: cardCount ?? this.cardCount,
    seed: seed ?? this.seed,
    cards: cards ?? this.cards,
    report: report ?? this.report,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'schemaVersion': schemaVersion,
    'rules': rules.toJson(),
    'patterns': patterns.map((pattern) => pattern.toJson()).toList(),
    'theme': theme.toJson(),
    'printLayout': printLayout.toJson(),
    'cardCount': cardCount,
    'seed': seed,
    'cards': cards.map((card) => card.toJson()).toList(),
    'report': report?.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory BingoProject.fromJson(Map<String, dynamic> json) => BingoProject(
    id: json['id'] as String,
    name: json['name'] as String,
    schemaVersion: json['schemaVersion'] as int? ?? 1,
    rules: RuleSet.fromJson(json['rules'] as Map<String, dynamic>),
    patterns: (json['patterns'] as List)
        .map(
          (value) => PatternDefinition.fromJson(value as Map<String, dynamic>),
        )
        .toList(),
    theme: CardThemeConfig.fromJson(json['theme'] as Map<String, dynamic>),
    printLayout: PrintLayoutConfig.fromJson(
      json['printLayout'] as Map<String, dynamic>,
    ),
    cardCount: json['cardCount'] as int,
    seed: json['seed'] as int,
    cards: (json['cards'] as List)
        .map((value) => BingoCard.fromJson(value as Map<String, dynamic>))
        .toList(),
    report: json['report'] == null
        ? null
        : OptimizationReport.fromJson(json['report'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  factory BingoProject.decode(String value) =>
      BingoProject.fromJson(jsonDecode(value) as Map<String, dynamic>);
}

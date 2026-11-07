import 'dart:math';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/contracts.dart';
import '../domain/models.dart';

class BingoPdfExporter implements PdfExporter {
  const BingoPdfExporter();

  @override
  Future<Uint8List> build(BingoProject project) async {
    final regular = await _font(project.theme.fontFamily, bold: false);
    final bold = await _font(project.theme.fontFamily, bold: true);
    final document = pw.Document(
      title: project.name,
      author: 'Bingo Pro',
      creator: 'Bingo Pro',
    );
    final format = _pageFormat(project.printLayout);
    final layout = project.printLayout;
    final margin = _length(layout.margin, layout.unit);
    final gutter = _length(layout.gutter, layout.unit);
    final availableWidth = format.width - margin * 2;
    final availableHeight = format.height - margin * 2;
    final autoWidth =
        (availableWidth - gutter * (layout.columns - 1)) / layout.columns;
    final autoHeight =
        (availableHeight - gutter * (layout.rows - 1)) / layout.rows;
    final cardWidth = layout.exactSize
        ? _length(layout.cardWidth, layout.unit)
        : autoWidth;
    final cardHeight = layout.exactSize
        ? _length(layout.cardHeight, layout.unit)
        : autoHeight;
    if (cardWidth > availableWidth + 0.1 ||
        cardHeight > availableHeight + 0.1) {
      throw StateError('One card is larger than the printable page area.');
    }
    final pageColumns = layout.exactSize
        ? min(
            layout.columns,
            max(1, ((availableWidth + gutter) / (cardWidth + gutter)).floor()),
          )
        : layout.columns;
    final pageRows = layout.exactSize
        ? min(
            layout.rows,
            max(
              1,
              ((availableHeight + gutter) / (cardHeight + gutter)).floor(),
            ),
          )
        : layout.rows;
    final cardsPerPage = pageColumns * pageRows;

    for (var start = 0; start < project.cards.length; start += cardsPerPage) {
      final pageCards = project.cards.skip(start).take(cardsPerPage).toList();
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.all(margin),
          build: (_) => pw.Column(
            children: [
              for (var row = 0; row < pageRows; row++) ...[
                pw.Row(
                  children: [
                    for (var column = 0; column < pageColumns; column++) ...[
                      if (column > 0) pw.SizedBox(width: gutter),
                      if (row * pageColumns + column < pageCards.length)
                        _card(
                          pageCards[row * pageColumns + column],
                          project,
                          regular,
                          bold,
                          cardWidth,
                          cardHeight,
                          cutMarks: layout.cutMarks,
                        )
                      else
                        pw.SizedBox(width: cardWidth, height: cardHeight),
                    ],
                  ],
                ),
                if (row < pageRows - 1) pw.SizedBox(height: gutter),
              ],
            ],
          ),
        ),
      );
    }
    return document.save();
  }

  @override
  Future<Uint8List> buildCalibrationPage(PrintLayoutConfig layout) async {
    final document = pw.Document(title: 'Bingo Pro print calibration');
    final format = _pageFormat(layout);
    document.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('Print at 100% / Actual size'),
              pw.SizedBox(height: 20),
              pw.Container(
                width: 50 * PdfPageFormat.mm,
                height: 50 * PdfPageFormat.mm,
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Center(child: pw.Text('50 mm x 50 mm')),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Measure this square before printing your full card set.',
              ),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _card(
    BingoCard card,
    BingoProject project,
    pw.Font regular,
    pw.Font bold,
    double width,
    double height, {
    required bool cutMarks,
  }) {
    final theme = project.theme;
    final rules = project.rules;
    final borderColor = PdfColor.fromInt(theme.gridColor);
    final headerHeight = min(28.0, height * 0.13);
    final footerHeight = min(18.0, height * 0.08);
    final gridHeight = height - headerHeight - footerHeight;
    final content = pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(theme.backgroundColor),
        border: pw.Border.all(color: borderColor, width: theme.outerLineWidth),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            height: headerHeight,
            color: PdfColor.fromInt(theme.headerColor),
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Row(
              children: [
                for (final label in rules.columnLabels)
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Text(
                        label,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: min(
                            theme.fontSize + 2,
                            headerHeight * 0.62,
                          ),
                          color: PdfColor.fromInt(theme.headerTextColor),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(
            height: gridHeight,
            child: pw.Column(
              children: [
                for (var row = 0; row < rules.rows; row++)
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        for (var column = 0; column < rules.columns; column++)
                          pw.Expanded(
                            child: _cell(
                              card.cellAt(row, column),
                              theme,
                              regular,
                              bold,
                              borderColor,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          pw.Container(
            height: footerHeight,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  project.name,
                  style: pw.TextStyle(font: regular, fontSize: 6),
                ),
                pw.Text(
                  '${card.displayId} - ${card.id}',
                  style: pw.TextStyle(font: bold, fontSize: 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!cutMarks) {
      return content;
    }
    final mark = pw.BorderSide(color: borderColor, width: 0.5);
    return pw.Stack(
      children: [
        content,
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Container(
            width: 7,
            height: 7,
            decoration: pw.BoxDecoration(
              border: pw.Border(left: mark, top: mark),
            ),
          ),
        ),
        pw.Positioned(
          right: 0,
          top: 0,
          child: pw.Container(
            width: 7,
            height: 7,
            decoration: pw.BoxDecoration(
              border: pw.Border(right: mark, top: mark),
            ),
          ),
        ),
        pw.Positioned(
          left: 0,
          bottom: 0,
          child: pw.Container(
            width: 7,
            height: 7,
            decoration: pw.BoxDecoration(
              border: pw.Border(left: mark, bottom: mark),
            ),
          ),
        ),
        pw.Positioned(
          right: 0,
          bottom: 0,
          child: pw.Container(
            width: 7,
            height: 7,
            decoration: pw.BoxDecoration(
              border: pw.Border(right: mark, bottom: mark),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _cell(
    CardCell cell,
    CardThemeConfig theme,
    pw.Font regular,
    pw.Font bold,
    PdfColor borderColor,
  ) => pw.Container(
    decoration: pw.BoxDecoration(
      color: cell.isFree ? PdfColor.fromInt(theme.freeColor) : null,
      border: pw.Border.all(color: borderColor, width: theme.lineWidth),
    ),
    child: pw.Center(
      child: pw.Text(
        cell.isFree ? theme.freeLabel : '${cell.value}',
        style: pw.TextStyle(
          font: cell.isFree ? bold : regular,
          fontSize: cell.isFree ? max(7, theme.fontSize - 3) : theme.fontSize,
          color: PdfColor.fromInt(theme.textColor),
        ),
      ),
    ),
  );

  Future<pw.Font> _font(String family, {required bool bold}) async {
    final path = switch (family) {
      'Noto Sans' => 'assets/fonts/NotoSans.ttf',
      'Roboto Slab' => 'assets/fonts/RobotoSlab.ttf',
      _ =>
        bold
            ? 'assets/fonts/AtkinsonHyperlegible-Bold.ttf'
            : 'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    };
    final data = await rootBundle.load(path);
    return pw.Font.ttf(data);
  }

  PdfPageFormat _pageFormat(PrintLayoutConfig layout) {
    var format = layout.paper == 'Letter'
        ? PdfPageFormat.letter
        : PdfPageFormat.a4;
    if (layout.orientation == 'landscape') format = format.landscape;
    return format;
  }

  double _length(double value, String unit) =>
      value * (unit == 'in' ? PdfPageFormat.inch : PdfPageFormat.mm);
}

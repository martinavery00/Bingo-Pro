import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';

class PdfPreviewScreen extends ConsumerWidget {
  const PdfPreviewScreen({required this.project, super.key});

  final BingoProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exporter = ref.watch(pdfExporterProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print preview'),
        actions: [
          IconButton(
            tooltip: 'Print calibration page',
            icon: const Icon(Icons.square_foot),
            onPressed: () => Printing.layoutPdf(
              name: 'Bingo Pro calibration',
              onLayout: (_) =>
                  exporter.buildCalibrationPage(project.printLayout),
            ),
          ),
        ],
      ),
      body: PdfPreview(
        pdfFileName: '${project.name}.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        build: (_) => exporter.build(project),
      ),
    );
  }
}

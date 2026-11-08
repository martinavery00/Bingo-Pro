import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/project_archive_service.dart';
import 'steps/appearance_step.dart';
import 'steps/cards_step.dart';
import 'steps/patterns_step.dart';
import 'steps/rules_step.dart';

class ProjectEditorScreen extends ConsumerStatefulWidget {
  const ProjectEditorScreen({super.key});

  @override
  ConsumerState<ProjectEditorScreen> createState() =>
      _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends ConsumerState<ProjectEditorScreen> {
  var _index = 0;

  static const _labels = ['Rules', 'Patterns', 'Style', 'Cards'];
  static const _icons = [
    Icons.tune,
    Icons.auto_awesome_mosaic_outlined,
    Icons.palette_outlined,
    Icons.grid_view_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectEditorProvider);
    if (project == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = [
      const RulesStep(),
      const PatternsStep(),
      const AppearanceStep(),
      const CardsStep(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _rename(project.name),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(project.name, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined, size: 16),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export project',
            onPressed: _export,
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(index: _index, labels: _labels),
            Expanded(
              child: IndexedStack(index: _index, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
        ],
      ),
    );
  }

  Future<void> _rename(String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Project name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(projectEditorProvider.notifier).rename(name);
    }
  }

  Future<void> _export() async {
    try {
      final project = ref.read(projectEditorProvider)!;
      final text = const ProjectArchiveService().export(project);
      await FilePicker.platform.saveFile(
        dialogTitle: 'Export Bingo Pro project',
        fileName: '${_safeName(project.name)}.bingopro',
        type: FileType.custom,
        allowedExtensions: ['bingopro'],
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Project exported.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $error')));
      }
    }
  }

  String _safeName(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.index, required this.labels});

  final int index;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
    child: Row(
      children: [
        Text(
          'Step ${index + 1} of ${labels.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (index + 1) / labels.length,
              minHeight: 6,
            ),
          ),
        ),
      ],
    ),
  );
}

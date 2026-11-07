import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/project_archive_service.dart';
import '../../domain/models.dart';
import '../project/project_editor_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bingo Pro'),
            Text(
              'Print-ready cards, thoughtfully diversified',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Import project',
            onPressed: () => _import(context, ref),
            icon: const Icon(Icons.file_open_outlined),
          ),
        ],
      ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _EmptyState(
          icon: Icons.error_outline,
          title: 'Projects could not be loaded',
          message: '$error',
        ),
        data: (items) => items.isEmpty
            ? const _EmptyState(
                icon: Icons.grid_view_rounded,
                title: 'Create your first card set',
                message: 'Design up to 18 cards, grouped into optimized sets of six.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _ProjectTile(project: items[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await ref.read(projectEditorProvider.notifier).create();
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProjectEditorScreen()));
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bingopro', 'json'],
        withData: true,
      );
      if (result == null) {
        return;
      }
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw const FormatException('The selected file could not be read.');
      }
      final imported = const ProjectArchiveService().import(utf8.decode(bytes));
      await ref.read(projectEditorProvider.notifier).replaceImported(imported);
      if (!context.mounted) {
        return;
      }
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ProjectEditorScreen()));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $error')));
      }
    }
  }
}

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.project});

  final BingoProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        child: Text(
          '${project.cardCount}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        project.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${project.rules.name} · ${project.cards.isEmpty ? 'Not generated' : '${project.cards.length} cards'}\n'
        'Updated ${_relative(project.updatedAt)}',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'delete') {
            await ref.read(projectRepositoryProvider).delete(project.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () {
        ref.read(projectEditorProvider.notifier).open(project);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProjectEditorScreen()));
      },
    ),
  );

  static String _relative(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

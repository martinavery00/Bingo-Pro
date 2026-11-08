import 'package:drift/drift.dart';

import '../domain/contracts.dart';
import '../domain/models.dart';
import 'app_database.dart';

class DriftProjectRepository implements ProjectRepository {
  const DriftProjectRepository(this.database);

  final AppDatabase database;

  @override
  Stream<List<BingoProject>> watchAll() {
    final query = database.select(database.projects)
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().map(
      (rows) => rows.map((row) => BingoProject.decode(row.payload)).toList(),
    );
  }

  @override
  Future<BingoProject?> find(String id) async {
    final query = database.select(database.projects)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : BingoProject.decode(row.payload);
  }

  @override
  Future<void> save(BingoProject project) => database
      .into(database.projects)
      .insertOnConflictUpdate(
        ProjectsCompanion.insert(
          id: project.id,
          name: project.name,
          payload: project.encode(),
          updatedAt: project.updatedAt,
        ),
      );

  @override
  Future<void> delete(String id) async {
    await database.transaction(() async {
      await (database.delete(
        database.playSessions,
      )..where((row) => row.projectId.equals(id))).go();
      await (database.delete(
        database.projects,
      )..where((row) => row.id.equals(id))).go();
    });
  }
}

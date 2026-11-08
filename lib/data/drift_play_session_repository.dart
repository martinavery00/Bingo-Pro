import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/contracts.dart';
import '../domain/play_session.dart' as domain;
import 'app_database.dart';

class DriftPlaySessionRepository implements PlaySessionRepository {
  const DriftPlaySessionRepository(this.database);

  final AppDatabase database;

  @override
  Stream<List<domain.PlaySession>> watchForProject(String projectId) {
    final query = database.select(database.playSessions)
      ..where((row) => row.projectId.equals(projectId))
      ..orderBy([(row) => OrderingTerm.asc(row.setIndex)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<domain.PlaySession?> find(String projectId, int setIndex) async {
    final query = database.select(database.playSessions)
      ..where(
        (row) =>
            row.projectId.equals(projectId) & row.setIndex.equals(setIndex),
      );
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> save(domain.PlaySession session) => database
      .into(database.playSessions)
      .insertOnConflictUpdate(
        PlaySessionsCompanion.insert(
          projectId: session.projectId,
          setIndex: session.setIndex,
          sourceSignature: session.sourceSignature,
          calledNumbers: jsonEncode(session.calledNumbers),
          startedAt: session.startedAt,
          updatedAt: session.updatedAt,
        ),
      );

  @override
  Future<void> delete(String projectId, int setIndex) async {
    await (database.delete(database.playSessions)..where(
          (row) =>
              row.projectId.equals(projectId) & row.setIndex.equals(setIndex),
        ))
        .go();
  }

  @override
  Future<void> deleteForProject(String projectId) async {
    await (database.delete(
      database.playSessions,
    )..where((row) => row.projectId.equals(projectId))).go();
  }

  domain.PlaySession _fromRow(PlaySession row) => domain.PlaySession(
    projectId: row.projectId,
    setIndex: row.setIndex,
    sourceSignature: row.sourceSignature,
    calledNumbers: (jsonDecode(row.calledNumbers) as List)
        .map((value) => value as int)
        .toList(),
    startedAt: row.startedAt,
    updatedAt: row.updatedAt,
  );
}

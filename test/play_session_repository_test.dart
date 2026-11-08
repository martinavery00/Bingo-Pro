import 'package:bingo_pro/data/app_database.dart';
import 'package:bingo_pro/data/drift_play_session_repository.dart';
import 'package:bingo_pro/domain/play_session.dart' as domain;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftPlaySessionRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftPlaySessionRepository(database);
  });

  tearDown(() => database.close());

  test('round trips ordered calls and keeps sets independent', () async {
    final first = _session(setIndex: 1, calls: const [12, 4, 70]);
    final second = _session(setIndex: 2, calls: const [3]);
    await repository.save(first);
    await repository.save(second);

    expect(
      (await repository.find('project', 1))!.calledNumbers,
      orderedEquals([12, 4, 70]),
    );
    expect(await repository.watchForProject('project').first, hasLength(2));

    await repository.delete('project', 1);
    expect(await repository.find('project', 1), isNull);
    expect(await repository.find('project', 2), isNotNull);
  });

  test('deletes every session for a project', () async {
    await repository.save(_session(setIndex: 1, calls: const [1]));
    await repository.save(_session(setIndex: 2, calls: const [2]));
    await repository.deleteForProject('project');
    expect(await repository.watchForProject('project').first, isEmpty);
  });

  test('migrates a version 1 database by creating play sessions', () async {
    await database.close();
    database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE projects (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              payload TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    repository = DriftPlaySessionRepository(database);

    await repository.save(_session(setIndex: 1, calls: const [9]));
    expect((await repository.find('project', 1))!.calledNumbers, [9]);
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 2);
  });
}

domain.PlaySession _session({
  required int setIndex,
  required List<int> calls,
}) => domain.PlaySession(
  projectId: 'project',
  setIndex: setIndex,
  sourceSignature: 'signature-$setIndex',
  calledNumbers: calls,
  startedAt: DateTime(2026, 11, 8),
  updatedAt: DateTime(2026, 11, 8, 1),
);

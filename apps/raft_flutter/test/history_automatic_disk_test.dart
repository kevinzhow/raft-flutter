import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:sqlite3/sqlite3.dart';

import 'history_capacity_test.dart' as f;

String _dartExecutable() {
  // flutter_tester lives under cache/artifacts/engine/<host>. Use its SDK,
  // even when PATH deliberately contains no Dart or SQLite executables.
  final cache = File(Platform.resolvedExecutable).parent.parent.parent.parent;
  final executable = p.join(
    cache.path,
    'dart-sdk',
    'bin',
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
  if (!File(executable).existsSync()) {
    throw StateError('The test SDK has no Dart executable at $executable.');
  }
  return executable;
}

void main() {
  test('last release disk window and keep marker upgrade once without losing offline bodies', () async {
    // Initial: literal v2 disk schema and v1 window JSON used by the old release.
    // Event: the upgraded client opens and runs automatic maintenance.
    // Expected: all rows/draft survive; legacy keep becomes an automatic grace visit.
    final dir = await Directory.systemTemp.createTemp('raft-history-upgrade-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'workspace.sqlite'));
    final window = jsonEncode({
      'version': 1,
      'windowKind': 'tail',
      'authority': 'member',
      'parentChannelId': 'chat',
      'messages': f.rows('chat', 1, 50),
      'hasMore': false,
      'historyLimited': false,
    });
    final legacy = sqlite3.open(file.path);
    try {
      legacy.execute('''
PRAGMA user_version=2;
CREATE TABLE workspace_cache(origin TEXT NOT NULL,principal TEXT NOT NULL,server TEXT NOT NULL,kind TEXT NOT NULL,id TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(origin,principal,server,kind,id));
CREATE TABLE message_translations(origin TEXT NOT NULL,principal TEXT NOT NULL,server TEXT NOT NULL,message_id TEXT NOT NULL,channel_id TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(origin,principal,server,message_id));
''');
      for (final (kind, id, payload) in [
        ('window', 'chat', window),
        ('history-kept', 'chat', 'true'),
        (
          'draft',
          'draft-only',
          '{"text":"Unsent draft","channelId":"draft-only"}',
        ),
      ]) {
        legacy.execute('INSERT INTO workspace_cache VALUES(?,?,?,?,?,?)', [
          f.account.origin,
          'alice',
          'one',
          kind,
          id,
          payload,
        ]);
      }
    } finally {
      legacy.close();
    }
    var cache = DriftWorkspaceCache(
      NativeDatabase(file),
      historyBudget: 128 << 10,
      historyHardLimitEnabled: false,
      automaticHistoryMaintenance: false,
    );
    addTearDown(() => cache.close());
    await cache.messageHistory.migrateLegacy(f.scope('chat'), limit: 4);
    await cache.messageHistory.capacity.maintain(f.account);
    expect(
      (await cache.messageHistory.readPage(f.scope('chat'), limit: 100))?.rows,
      hasLength(50),
    );
    expect(
      await f.count(
        cache,
        "SELECT count(*) FROM workspace_cache WHERE kind='history-kept'",
      ),
      0,
    );
    final migrated = await cache.read(
      f.account.origin,
      'alice',
      'one',
      'history-visited',
      'chat',
    );
    expect(migrated, isA<int>());
    await cache.close();
    cache = DriftWorkspaceCache(
      NativeDatabase(file),
      historyBudget: 128 << 10,
      historyHardLimitEnabled: false,
      automaticHistoryMaintenance: false,
    );
    await cache.messageHistory.capacity.maintain(f.account);
    expect(
      await cache.read(
        f.account.origin,
        'alice',
        'one',
        'history-visited',
        'chat',
      ),
      migrated,
    );
    expect(
      (await cache.messageHistory.readPage(f.scope('chat'), limit: 100))?.rows,
      hasLength(50),
    );
    expect(
      (await cache.read(
        f.account.origin,
        'alice',
        'one',
        'draft',
        'draft-only',
      ))['text'],
      'Unsent draft',
    );
  });

  test('process killed in a WAL transaction reopens the last coherent committed body', () async {
    // Initial: a real file has one committed message body.
    // Event: another SQLite process changes its body inside a transaction, then is killed.
    // Expected: crash recovery exposes the complete old body; an authorized retry can commit the new one.
    final dir = await Directory.systemTemp.createTemp('raft-history-kill-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'workspace.sqlite'));
    var cache = DriftWorkspaceCache(
      NativeDatabase(file),
      automaticHistoryMaintenance: false,
    );
    addTearDown(() => cache.close());
    await f.store(cache, f.scope('chat'), [
      {'id': 'chat-1', 'channelId': 'chat', 'seq': '1', 'content': 'Committed'},
    ]);
    expect(
      (await cache.customSelect('PRAGMA journal_mode').getSingle())
          .read<String>('journal_mode'),
      'wal',
    );
    await cache.close();
    final dart = _dartExecutable();
    // Kernel-only compilation omits native assets. Build the supported SDK
    // bundle so the writer loads this project's SQLite, not a system fallback.
    // The SDK cleans its output directory; keep the live fixture outside it.
    final writer = p.join(dir.path, 'writer');
    final compiled = await Process.run(dart, [
      'build',
      'cli',
      '--target',
      p.join('test', 'support', 'history_wal_writer.dart'),
      '--output',
      writer,
    ]);
    expect(
      compiled.exitCode,
      0,
      reason: '${compiled.stdout}\n${compiled.stderr}',
    );
    final bundle = p.join(writer, 'bundle');
    final executable = p.join(
      bundle,
      'bin',
      Platform.isWindows ? 'history_wal_writer.exe' : 'history_wal_writer',
    );
    final diagnostics = sqlite3.openInMemory();
    late final List<String> options;
    try {
      options = [
        for (final row in diagnostics.select('PRAGMA compile_options'))
          row.values.single as String,
      ]..sort();
    } finally {
      diagnostics.close();
    }
    final fingerprint = jsonEncode({
      'sourceId': sqlite3.version.sourceId,
      'options': options,
    });
    final emptyPath = await Directory(p.join(dir.path, 'empty-path')).create();
    final arguments = [file.path, fingerprint];
    final environment = {'PATH': emptyPath.path};
    final libraries = Directory(p.join(bundle, 'lib'))
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) => p.basename(file.path).toLowerCase().contains('sqlite3'),
        )
        .toList();
    expect(libraries, hasLength(1));
    final library = libraries.single;
    final withheld = await library.rename(p.join(dir.path, 'withheld-sqlite'));
    try {
      // A passing system fallback must not hide a broken asset bundle on Mac.
      final missing = await Process.run(
        executable,
        arguments,
        environment: environment,
      );
      expect(missing.exitCode, isNot(0));
      expect(missing.stdout, isNot(contains('MUTATED')));
      expect('${missing.stderr}'.toLowerCase(), contains('sqlite'));
    } finally {
      await withheld.rename(library.path);
    }
    final child = await Process.start(
      executable,
      arguments,
      environment: environment,
    );
    final mutated = Completer<void>();
    final output = child.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((text) {
          if (text == 'MUTATED' && !mutated.isCompleted) mutated.complete();
        });
    final errors = child.stderr.transform(utf8.decoder).join();
    try {
      await Future.any([
        mutated.future,
        child.exitCode.then((code) async {
          throw StateError(
            'WAL writer exited before its signal ($code): ${await errors}',
          );
        }),
      ]).timeout(const Duration(seconds: 10));
      expect(child.kill(ProcessSignal.sigkill), isTrue);
      expect(await child.exitCode, isNot(0));
      expect(await errors, isEmpty);
    } finally {
      child.kill(ProcessSignal.sigkill);
      await child.exitCode;
      await output.cancel();
      await child.stdin.close();
    }
    cache = DriftWorkspaceCache(
      NativeDatabase(file),
      automaticHistoryMaintenance: false,
    );
    expect(
      ((await cache.messageHistory.readContext(
                f.scope('chat'),
                'chat-1',
                radius: 0,
              ))?['messages']
              as List?)
          ?.single['content'],
      'Committed',
    );
    await cache.messageHistory.acceptEvents(f.scope('chat'), [
      {
        'id': 'chat-1',
        'channelId': 'chat',
        'seq': '1',
        'content': 'Committed retry',
      },
    ]);
    expect(
      ((await cache.messageHistory.readContext(
                f.scope('chat'),
                'chat-1',
                radius: 0,
              ))?['messages']
              as List?)
          ?.single['content'],
      'Committed retry',
    );
  });

  for (final clock in [DateTime.utc(2000), DateTime.utc(2099)]) {
    test(
      'equal timestamps keep uint64 sequence ordering with device clock $clock',
      () async {
        // Initial: same server timestamp, sparse sequence values above JS safe integer.
        // Event: local clock is decades wrong and rows arrive in reverse order.
        // Expected: sequence order, never wall-clock order, controls history.
        final cache = DriftWorkspaceCache(
          NativeDatabase.memory(),
          historyClock: () => clock,
          automaticHistoryMaintenance: false,
        );
        addTearDown(cache.close);
        final values = [
          for (final seq in ['18446744073709551615', '9007199254740993'])
            {
              'id': seq,
              'channelId': 'chat',
              'seq': seq,
              'content': seq,
              'createdAt': '2026-10-15T00:00:00Z',
            },
        ];
        await f.store(cache, f.scope('chat'), values);
        expect(
          (await cache.messageHistory.readPage(f.scope('chat')))?.rows
              .map((r) => r['id']),
          values.reversed.map((r) => r['id']),
        );
      },
    );
  }
}

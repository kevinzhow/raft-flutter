import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_task_bucket.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  test('Source mounted channel task consumers share only the same in-flight authority read', () async {
    final (w, api) = await fixture('owner');
    addTearDown(w.dispose);
    final child =
        WorkspaceController(
            w.client,
            ownsClient: false,
            entityDirectory: w.entityDirectory,
          )
          ..server = w.server
          ..channels = w.channels
          ..channel = w.channel;
    addTearDown(child.dispose);
    final held = Completer<Map>();
    api.routes['GET /tasks/channel/c1'] = (_) => held.future;
    final first = readSourceTaskBucket(w, 'c1');
    final second = readSourceTaskBucket(child, 'c1');
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(api.calls.where((r) => r.path == '/tasks/channel/c1'), hasLength(1));
    held.complete({'tasks': []});
    expect(await first, {'tasks': []});
    expect(await second, {'tasks': []});
    // No accepted success cache: a later consumer makes a real current read.
    api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
    await readSourceTaskBucket(w, 'c1');
    expect(api.calls.where((r) => r.path == '/tasks/channel/c1'), hasLength(2));
  });
  test(
    'Source role/session/server keys cannot borrow a previous pending read',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      final held = Completer<Map>();
      api.routes['GET /tasks/channel/c1'] = (_) => held.future;
      final old = readSourceTaskBucket(w, 'c1');
      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      final role = readSourceTaskBucket(w, 'c1');
      expect(identical(old, role), isFalse);
      final oldOutcome = old.then<Object?>(
        (value) => value,
        onError: (Object e) => e,
      );
      final roleOutcome = role.then<Object?>(
        (value) => value,
        onError: (Object e) => e,
      );
      w.client.selectServer('s2');
      w.server = RaftRecord({'id': 's2', 'role': 'member'});
      final server = readSourceTaskBucket(w, 'c1');
      expect(identical(server, role), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        api.calls.where((r) => r.path == '/tasks/channel/c1'),
        hasLength(3),
      );
      held.complete({'tasks': []});
      expect(await oldOutcome, isA<RaftApiException>());
      expect(await roleOutcome, isA<RaftApiException>());
      expect(await server, {'tasks': []});
    },
  );
  test('Source channel authority changes separate pending reads; errors are not retained', () async {
    final (w, api) = await fixture('owner');
    addTearDown(w.dispose);
    final held = Completer<Map>();
    api.routes['GET /tasks/channel/c1'] = (_) => held.future;
    final joined = readSourceTaskBucket(w, 'c1');
    w.channel = RaftChannel({...w.channel!.json, 'joined': false});
    w.channels = [w.channel!];
    final left = readSourceTaskBucket(w, 'c1');
    expect(identical(joined, left), isFalse);
    held.complete({'tasks': []});
    await Future.wait([joined, left]);
    api.routes['GET /tasks/channel/c1'] = (_) =>
        throw StateError('held backend failure');
    await expectLater(readSourceTaskBucket(w, 'c1'), throwsA(anything));
    api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
    expect(await readSourceTaskBucket(w, 'c1'), {'tasks': []});
    expect(api.calls.where((r) => r.path == '/tasks/channel/c1'), hasLength(4));
  });
}

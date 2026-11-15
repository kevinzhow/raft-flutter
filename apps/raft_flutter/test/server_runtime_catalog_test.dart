// Web hooks/useServerRuntimeCatalog.ts + store/serverRuntimeCatalogCache.ts:
// one shared read per server, a minute of reuse, null on an error or an old
// server, a fresh start for the next account or workspace.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/server_runtime_catalog.dart';
import 'package:raft_flutter/features/server_runtime_catalog_reads.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  Object? answer = {
    'catalogVersion': 1,
    'runtimes': [
      {'id': 'antigravity', 'deprecated': false, 'experimental': false},
      {'id': 'qoder', 'deprecated': false, 'experimental': true},
    ],
  };
  Completer<dynamic>? pending;
  final reads = <String>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    if (pending case final held?) return held.future;
    final value = answer;
    if (value is Exception) throw value;
    return value;
  }
}

void main() {
  late _Client c;
  late _Workspace w;
  late ServerRuntimeCatalogReads reads;
  var clock = DateTime(2026, 11, 16, 12);
  setUp(() {
    c = _Client()..user = RaftRecord({'id': 'alice'});
    c.selectServer('s');
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
    clock = DateTime(2026, 11, 16, 12);
    reads = ServerRuntimeCatalogReads.of(w)..now = () => clock;
  });
  tearDown(() async {
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });

  test('concurrent readers share one request', () async {
    w.pending = Completer<dynamic>();
    final a = reads.read('s'), b = reads.read('s');
    expect(w.reads, ['/servers/s/runtimes']);
    w.pending!.complete(w.answer);
    final catalog = await a;
    expect(await b, same(catalog));
    expect(reads.settled('s'), same(catalog));
  });

  test('a settled answer is reused for a minute, then read again', () async {
    await reads.read('s');
    clock = clock.add(const Duration(seconds: 59));
    await reads.read('s');
    expect(w.reads, hasLength(1));
    clock = clock.add(const Duration(seconds: 2));
    expect(reads.settled('s'), isNull);
    await reads.read('s');
    expect(w.reads, hasLength(2));
  });

  test('an error or an answer without runtimes is null, and reused', () async {
    w.answer = Exception('boom');
    expect(await reads.read('s'), isNull);
    expect(await reads.read('s'), isNull);
    expect(w.reads, hasLength(1));
    clock = clock.add(const Duration(minutes: 2));
    w.answer = {'nothing': true};
    expect(await reads.read('s'), isNull);
    expect(w.reads, hasLength(2));
  });

  test('another workspace generation starts from no reads', () async {
    await reads.read('s');
    expect(reads.settled('s'), isNotNull);
    c.selectServer('other');
    expect(reads.settled('s'), isNull);
    await reads.read('s');
    expect(w.reads, hasLength(2));
  });

  test('deprecated is the server answer, else the bundled flag', () async {
    // Bundled: antigravity is deprecated; the server says it is not here.
    expect(isRuntimeDeprecatedOnServer('antigravity', null), isTrue);
    final catalog = await reads.read('s');
    expect(isRuntimeDeprecatedOnServer('antigravity', catalog), isFalse);
    // A runtime the catalog does not list falls back to the bundle.
    expect(isRuntimeDeprecatedOnServer('copilot', catalog), isTrue);
    expect(isRuntimeDeprecatedOnServer('claude', catalog), isFalse);
    expect(reads.deprecatedHere()('antigravity'), isFalse);
  });

  test('listeners hear when a read settles', () async {
    var heard = 0;
    reads.addListener(() => heard++);
    await reads.read('s');
    expect(heard, 1);
  });
}

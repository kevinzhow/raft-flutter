import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_grid_sessions.dart';
import 'package:raft_flutter/data/workspace_mode_store.dart';

import 'message_presentation_test.dart' show fixture, MessageAdapter;

class EventClient extends RaftClient {
  EventClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<void> dispose() async {
    await stream.close();
    await super.dispose();
  }
}

class Store implements SearchMemoryStorage {
  final values = <String, String>{};
  Completer<String?>? readGate;
  @override
  Future<String?> read(String key) async =>
      readGate == null ? values[key] : await readGate!.future;
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

Future<void> tick() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('DEV gates availability, not the personal default; exact1024; origin/user storage', () async {
    final (w, _) = await fixture('owner');
    final disk = Store();
    final mode = WorkspaceModeStore(w, storage: disk, dev: true);
    await tick();
    expect(mode.showCard, true);
    expect(mode.enabled, false);
    final captured = mode.authority;
    expect(mode.setEnabled(true, capturedAuthority: captured), true);
    await mode.writes;
    expect(mode.active(1023), false);
    expect(mode.active(1024), true);
    final oldKey = mode.preferenceKey!;
    expect(jsonDecode(disk.values[oldKey]!)['enabled'], true);
    w.client.user = RaftRecord({'id': 'different'});
    w.notifyListeners();
    expect(mode.enabled, false);
    expect(mode.hydrated, false);
    expect(mode.setEnabled(true, capturedAuthority: captured), false);
    await tick();
    expect(mode.preferenceKey, isNot(oldKey));
    expect(mode.enabled, false);
    mode.dispose();
    w.dispose();
  });

  test('release unknown stays disabled; old flag result cannot enable a different server', () async {
    final (w, a) = await fixture('owner');
    final gate = Completer<Object>();
    a.routes['POST /feature-flags/evaluate'] = (_) => gate.future;
    final mode = WorkspaceModeStore(w, storage: Store(), dev: false);
    await tick();
    expect(mode.showCard, false);
    w.server = RaftRecord({'id': 's2', 'role': 'owner'});
    w.client.selectServer('s2');
    a.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'chat_grid_layout_v0', 'enabled': false},
      ],
    };
    w.notifyListeners();
    await tick();
    gate.complete({
      'evaluations': [
        {'key': 'chat_grid_layout_v0', 'enabled': true},
      ],
    });
    await tick();
    expect(mode.available, false);
    expect(mode.active(1400), false);
    mode.dispose();
    w.dispose();
  });

  test(
    'late personal hydration never restores a departed account preference',
    () async {
      final (w, _) = await fixture('owner');
      final disk = Store()..readGate = Completer<String?>();
      final mode = WorkspaceModeStore(w, storage: disk, dev: true);
      w.client.user = null;
      w.notifyListeners();
      disk.readGate!.complete('{"enabled":true}');
      await tick();
      expect(mode.showCard, false);
      expect(mode.enabled, false);
      mode.dispose();
      w.dispose();
    },
  );

  test('borrowed controller releases subscription, never tears down owner client or recovers session', () async {
    final a = MessageAdapter();
    a.routes['POST /auth/login'] = (_) => {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    };
    final client = EventClient(a);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    final child = WorkspaceController(w.client, ownsClient: false);
    child.server = w.server;
    child.ledger.switchServer('s1');
    await expectLater(child.bootstrap(), throwsStateError);
    await expectLater(child.selectServer(w.server!), throwsStateError);
    client.stream.add(const RaftEvent('connected', {}));
    await tick();
    // Only the root may recover membership; child never selects/connects/resumes.
    expect(a.calls.where((o) => o.path == '/servers').length, 1);
    final generation = w.client.generation;
    var lateNotifications = 0;
    child.addListener(() => lateNotifications++);
    child.dispose();
    expect(w.client.user?.id, 'alice');
    expect(w.client.generation, generation);
    client.stream.add(
      RaftEvent('message:new', {'id': 'late', 'channelId': 'c1', 'seq': 2}),
    );
    await tick();
    expect(lateNotifications, 0);
    w.dispose();
  });

  test('grid children keep accepted windows independent; hidden read admission and foreground follow root', () async {
    final (w, a) = await fixture('owner');
    final c2 = RaftChannel({'id': 'c2', 'name': 'two', 'joined': true});
    w.channels.add(c2);
    for (final id in ['c1', 'c2']) {
      a.routes['GET /messages/channel/$id'] = (_) => {
        'messages': [
          {'id': 'm-$id', 'channelId': id, 'seq': 3, 'content': id},
        ],
        'hasMore': false,
      };
    }
    final sessions = WorkspaceGridSessions(w);
    final one = sessions.open('c1')!, two = sessions.open('c2')!;
    await tick();
    expect(one.messages.single.id, 'm-c1');
    expect(two.messages.single.id, 'm-c2');
    expect(w.channel?.id, 'c1');
    sessions.present({'c1'});
    expect(one.foreground, true);
    expect(two.foreground, false);
    one.setConversationPresentation(Object(), main: false, thread: true);
    one.visibleIds['c1'] = {'m-c1'};
    final before = a.calls.length;
    await two.markRead('c2');
    expect(a.calls.length, before);
    w.setForeground(false);
    expect(one.foreground, false);
    expect(two.foreground, false);
    w.setForeground(true);
    expect(one.foreground, true);
    await one.markRead('c1');
    // Parent resume must not grant reads to a still-folded retained main.
    expect(a.calls.length, before);
    sessions.dispose();
    expect(w.client.user?.id, 'alice');
    w.dispose();
  });

  test('same-scope drafts return to classic; revocation rejects pending windows and old drafts', () async {
    final (w, a) = await fixture('owner');
    w.drafts['c1'] = 'classic draft';
    final page = Completer<Object>();
    a.routes['GET /messages/channel/c1'] = (_) => page.future;
    final sessions = WorkspaceGridSessions(w);
    final child = sessions.open('c1')!;
    await tick();
    child.saveDraft('grid draft');
    sessions.transferDrafts('c1', child);
    expect(w.drafts['c1'], 'grid draft');
    child.saveDraft('private departed draft');
    var privateProjectionRetired = false;
    child.addListener(() {
      if (child.server == null &&
          child.channel == null &&
          child.drafts.isEmpty) {
        privateProjectionRetired = true;
      }
    });
    w.server = RaftRecord({'id': 's1', 'role': 'guest'});
    w.notifyListeners();
    expect(sessions.controllers, isEmpty);
    expect(privateProjectionRetired, true);
    page.complete({
      'messages': [
        {
          'id': 'private-late',
          'channelId': 'c1',
          'seq': 9,
          'content': 'private',
        },
      ],
      'hasMore': false,
    });
    await tick();
    expect(child.messages, isEmpty);
    expect(w.drafts['c1'], 'grid draft');
    expect(w.client.user?.id, 'alice');
    sessions.dispose();
    w.dispose();
  });
}

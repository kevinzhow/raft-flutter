import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/appearance_section.dart';
import 'package:raft_flutter/features/chat_agent_presentation.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';
import 'package:raft_flutter/features/live_agent_activity_bar.dart';

class _Storage implements SearchMemoryStorage {
  final values = <String, String>{};
  final pending = <String, Completer<String?>>{};
  @override
  Future<String?> read(String key) async => pending[key]?.future ?? values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  List<Map<String, dynamic>> agents = [
    {'id': 'a', 'name': 'Cindy', 'model': 'actual-model', 'runtime': 'codex'},
  ];
  Completer<dynamic>? pendingAgents;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path == '/agents' ? pendingAgents?.future ?? agents : [];
}

void main() {
  test('local choice beats profile seed; corrupt storage and native/web defaults are safe', () async {
    final storage = _Storage();
    final store = PersonalPresentationStore(storage: storage, desktop: true);
    await store.bind('https://fixture.invalid', 'u', profileFont: 'lg');
    expect(store.value.font, 'lg');
    expect(store.value.hideEmptySections, isTrue);
    final captured = store.key;
    store.update(captured, font: 'sm', liveActivity: false);
    await store.writes;
    final again = PersonalPresentationStore(storage: storage);
    await again.bind('https://fixture.invalid', 'u', profileFont: 'lg');
    expect(again.value.font, 'sm');
    expect(again.value.liveActivity, isFalse);
    await again.bind('https://other.invalid', 'u');
    expect(again.value.font, 'md');
    expect(again.value.hideEmptySections, isFalse);
    storage.values[again.key!] = '{corrupt';
    final corrupt = PersonalPresentationStore(storage: storage);
    await corrupt.bind('https://other.invalid', 'u');
    expect(corrupt.value.font, 'md');
    expect(jsonDecode(storage.values[captured!]!), isNot(contains('model')));
    store.dispose();
    again.dispose();
    corrupt.dispose();
  });
  test(
    'late reads cannot overwrite a chosen font or follow a different account',
    () async {
      final storage = _Storage();
      final active = PersonalPresentationStore(storage: storage);
      final key = active.scopeKey('https://fixture.invalid', 'old')!;
      storage.pending[key] = Completer<String?>();
      final pending = active.bind('https://fixture.invalid', 'old');
      active.update(key, font: 'lg');
      storage.pending[key]!.complete('{"font":"sm"}');
      await pending;
      expect(active.value.font, 'lg');
      final oldKey = active.key;
      await active.bind('https://fixture.invalid', 'next');
      expect(active.update(oldKey, font: 'sm', modelName: false), isFalse);
      expect(active.value.font, 'md');
      expect(active.value.modelName, isTrue);
      await active.writes;
      active.dispose();
    },
  );
  test('late old-account preferences cannot follow a principal change; late profile seed respects local choice', () async {
    final storage = _Storage();
    final store = PersonalPresentationStore(storage: storage);
    final oldKey = store.scopeKey('https://fixture.invalid', 'old')!;
    storage.pending[oldKey] = Completer<String?>();
    final oldRead = store.bind('https://fixture.invalid', 'old');
    await store.bind('https://fixture.invalid', 'next');
    storage.pending[oldKey]!.complete('{"font":"lg","modelName":false}');
    await oldRead;
    expect(store.value.font, 'md');
    expect(store.value.modelName, isTrue);
    await store.bind('https://fixture.invalid', 'next', profileFont: 'lg');
    expect(store.value.font, 'lg');
    store.update(store.key, font: 'sm');
    await store.bind('https://fixture.invalid', 'next', profileFont: 'lg');
    expect(store.value.font, 'sm');
    await store.writes;
    store.dispose();
  });
  test('real work signal lifecycle ignores absent/foreign agents, terminal clears and heartbeat does not manufacture work', () async {
    final client = RaftClient(
      origin: 'https://fixture.invalid',
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'u'});
    client.selectServer('s');
    final w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    final directory = MessageReferenceDirectory(w);
    await Future<void>.delayed(Duration.zero);
    var now = DateTime.utc(2026, 10, 8);
    final activity = ChatAgentPresentation(w, directory, clock: () => now);
    expect(activity.modelLabel('a'), 'actual-model');
    void signal(Map<String, dynamic> data) =>
        activity.event(RaftEvent('agent:activity', data));
    signal({'agentId': 'absent', 'activity': 'working'});
    expect(activity.latest, isNull);
    signal({'agentId': 'a', 'activity': 'working', 'serverId': 'other'});
    expect(activity.latest, isNull);
    signal({'agentId': 'a', 'activity': 'working', 'isHeartbeat': true});
    expect(activity.latest, isNull);
    signal({
      'agentId': 'a',
      'activity': 'working',
      'detail': 'Actual task',
      'serverSeq': '1',
    });
    expect(activity.latest!.text, 'Actual task');
    signal({'agentId': 'a', 'activity': 'thinking', 'serverSeq': '0'});
    expect(activity.latest!.text, 'Actual task');
    now = now.add(const Duration(seconds: 60));
    signal({
      'agentId': 'a',
      'activity': 'working',
      'detail': 'Still working',
      'isHeartbeat': true,
      'serverSeq': '2',
    });
    expect(activity.items.length, 1);
    now = now.add(const Duration(seconds: 91));
    activity.prune();
    expect(activity.latest, isNull);
    signal({'agentId': 'a', 'activity': 'thinking', 'serverSeq': '3'});
    expect(activity.latest!.text, 'Thinking…');
    signal({'agentId': 'a', 'activity': 'online', 'serverSeq': '4'});
    expect(activity.latest, isNull);
    signal({'agentId': 'a', 'activity': 'working', 'serverSeq': '5'});
    w.server = RaftRecord({'id': 's', 'role': 'guest'});
    w.notifyListeners();
    expect(activity.latest, isNull);
    expect(activity.modelLabel('a'), isNull);
    activity.dispose();
    directory.dispose();
    w.dispose();
    await client.dispose();
  });
  test('late permitted directory load cannot return metadata after authority changes', () async {
    final client = RaftClient(
      origin: 'https://fixture.invalid',
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'u'});
    client.selectServer('s');
    final w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..pendingAgents = Completer<dynamic>();
    final directory = MessageReferenceDirectory(w), old = w.pendingAgents!;
    w.server = RaftRecord({'id': 's', 'role': 'guest'});
    w.notifyListeners();
    old.complete([
      {'id': 'a', 'name': 'Private agent', 'model': 'private-model'},
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(directory.agents, isEmpty);
    expect(directory.references, isEmpty);
    directory.dispose();
    w.dispose();
    await client.dispose();
  });
  testWidgets('font and all three appearance controls mutate scoped state', (
    t,
  ) async {
    final store = PersonalPresentationStore(storage: _Storage());
    await store.bind('https://fixture.invalid', 'u');
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RaftAppearanceSection(
              appearance: const RaftAppearance(),
              onAppearance: (_) {},
              presentation: store,
            ),
          ),
        ),
      ),
    );
    await t.ensureVisible(find.text('Large'));
    await t.tap(find.text('Large'));
    await t.pumpAndSettle();
    expect(store.value.fontSize, 16);
    expect(
      t.widget<RaftMessageTile>(find.byType(RaftMessageTile)).bodyFontSize,
      16,
    );
    expect(
      t.widget<RaftMessageBody>(find.byType(RaftMessageBody)).fontSize,
      16,
    );
    for (final name in [
      'appearance-live-activity',
      'appearance-agent-model',
      'appearance-hide-empty',
    ]) {
      final finder = find.byKey(ValueKey(name));
      await t.ensureVisible(finder);
      await t.tap(finder);
      await t.pumpAndSettle();
    }
    expect(store.value.liveActivity, isFalse);
    expect(store.value.modelName, isFalse);
    expect(store.value.hideEmptySections, isTrue);
    final old = t
        .widget<RaftSwitch>(
          find.byKey(const ValueKey('appearance-agent-model')),
        )
        .onChanged!;
    await store.bind('https://fixture.invalid', 'next');
    old(false);
    expect(store.value.modelName, isTrue);
    await t.pumpWidget(const SizedBox());
    await store.writes;
    store.dispose();
  });
  testWidgets(
    'accepted real work bar hides on preference change and immediate authority revocation',
    (t) async {
      final client = RaftClient(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      )..user = RaftRecord({'id': 'u'});
      client.selectServer('s');
      final w = _Workspace(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      final directory = MessageReferenceDirectory(w);
      await t.pump();
      final activities = ChatAgentPresentation(w, directory);
      final store = PersonalPresentationStore(storage: _Storage());
      await store.bind(client.origin, 'u');
      activities.event(
        const RaftEvent('agent:activity', {
          'agentId': 'a',
          'activity': 'working',
          'detail': 'Public fixture work',
        }),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: NativeLiveAgentActivityBar(
              activities: activities,
              presentation: store,
              origin: client.origin,
            ),
          ),
        ),
      );
      expect(find.text('Public fixture work'), findsOneWidget);
      store.update(store.key, liveActivity: false);
      await t.pump();
      expect(find.text('Public fixture work'), findsNothing);
      store.update(store.key, liveActivity: true);
      await t.pump();
      expect(find.text('Public fixture work'), findsOneWidget);
      w.server = RaftRecord({'id': 's', 'role': 'guest'});
      w.notifyListeners();
      await t.pump();
      expect(find.text('Public fixture work'), findsNothing);
      await t.pumpWidget(const SizedBox());
      activities.dispose();
      directory.dispose();
      w.dispose();
      await client.dispose();
      await store.writes;
      store.dispose();
    },
  );
}

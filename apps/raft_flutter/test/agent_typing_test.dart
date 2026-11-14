import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/agent_typing_store.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart'
    show WorkspaceEntityKind;
import 'package:raft_flutter/features/agent_typing_line_host.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

/// Web v1.24 agent typing line (store/agentTypingStore.ts,
/// AgentTypingLine.tsx): `agent:typing` start/end per tool call, deadlines,
/// the agent's own message clearing it, reconnects, and the line above the
/// composer.
void main() {
  Map<String, dynamic> typing(
    String agent,
    String call, {
    String state = 'start',
    String channel = 'c1',
    String? parent,
    String server = 's1',
    int? expiresAt,
  }) => {
    'agentId': agent,
    'serverId': server,
    'channelId': channel,
    'parentMessageId': parent,
    'callId': call,
    'state': state,
    'expiresAt': expiresAt ?? 0,
  };

  group('store', () {
    late int now;
    late StreamController<RaftEvent> events;
    late AgentTypingStore store;
    var notified = 0;

    setUp(() {
      now = 1000000;
      notified = 0;
      events = StreamController<RaftEvent>.broadcast();
      store = AgentTypingStore(
        events: events.stream,
        serverId: () => 's1',
        now: () => now,
      );
      store.addListener(() => notified++);
    });
    tearDown(() {
      store.dispose();
      events.close();
    });

    void send(Map<String, dynamic> payload, [String name = 'agent:typing']) =>
        store.receive(RaftEvent(name, payload));

    test('calls line up in the order they started; refreshes keep place', () {
      send(typing('a1', 'x'));
      send(typing('a2', 'y'));
      send(typing('a1', 'x'));
      send(typing('a1', 'z'));
      expect(store.typingAgentIds('c1', null), ['a1', 'a2']);
      send(typing('a1', 'x', state: 'end'));
      expect(store.typingAgentIds('c1', null), ['a2', 'a1']);
      send(typing('a1', 'z', state: 'end'));
      send(typing('a2', 'y', state: 'end'));
      expect(store.typingAgentIds('c1', null), isEmpty);
    });

    test('threads and other servers are kept apart', () {
      send(typing('a1', 'x', parent: 'root'));
      send(typing('a2', 'y', server: 'other'));
      expect(store.typingAgentIds('c1', null), isEmpty);
      expect(store.typingAgentIds('c1', 'root'), ['a1']);
    });

    test('a deadline outside (0, TTL] falls back to the TTL', () {
      expect(localTypingDeadline(now + 5000, now), now + 5000);
      expect(localTypingDeadline(now - 5, now), now + 20000);
      expect(localTypingDeadline(now + 60000, now), now + 20000);
    });

    testWidgets('an unrefreshed start leaves at its deadline', (t) async {
      var clock = 1000000;
      final own = AgentTypingStore(
        events: const Stream.empty(),
        serverId: () => 's1',
        now: () => clock,
      );
      addTearDown(own.dispose);
      own.receive(
        RaftEvent('agent:typing', typing('a1', 'x', expiresAt: clock + 3000)),
      );
      expect(own.typingAgentIds('c1', null), ['a1']);
      clock += 3000;
      await t.pump(const Duration(milliseconds: 3100));
      expect(own.typingAgentIds('c1', null), isEmpty);
    });

    test('the agent\'s message clears it, and late starts of that call', () {
      send(typing('a1', 'x'));
      send({
        'senderType': 'agent',
        'senderId': 'a1',
        'channelId': 'c1',
      }, 'message:new');
      expect(store.typingAgentIds('c1', null), isEmpty);
      send(typing('a1', 'x'));
      expect(store.typingAgentIds('c1', null), isEmpty);
      send(typing('a1', 'next'));
      expect(store.typingAgentIds('c1', null), ['a1']);
    });

    test('a thread reply clears the thread line only', () {
      send(typing('a1', 'x', parent: 'root'));
      send(typing('a1', 'y'));
      send({
        'senderType': 'agent',
        'senderId': 'a1',
        'channelId': 'thread-c',
        'conversationContext': {
          'channelType': 'thread',
          'parentMessageId': 'root',
        },
      }, 'message:new');
      expect(store.typingAgentIds('c1', 'root'), isEmpty);
      expect(store.typingAgentIds('c1', null), ['a1']);
    });

    test('a reconnect starts over', () {
      send(typing('a1', 'x'));
      final before = notified;
      store.receive(const RaftEvent('connected', null));
      expect(store.typingAgentIds('c1', null), isEmpty);
      expect(notified, before + 1);
    });

    test('malformed frames are ignored', () {
      send({'agentId': 'a1', 'channelId': 'c1', 'callId': 'x'});
      send({...typing('a1', 'x'), 'state': 'paused'});
      expect(store.typingAgentIds('c1', null), isEmpty);
    });
  });

  testWidgets('sentences follow the Web wording', (t) async {
    late BuildContext context;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    String sentence(List<String> names) => agentTypingSentence(context, names);
    expect(sentence([]), '');
    expect(sentence(['Niko']), 'Niko is typing…');
    expect(sentence(['Niko', 'Kirby']), 'Niko and Kirby are typing…');
    expect(
      sentence(['Niko', 'Kirby', 'Tenny']),
      'Niko, Kirby and Tenny are typing…',
    );
    expect(
      sentence(['Niko', 'Kirby', 'Tenny', 'Rex', 'Ivy']),
      'Niko, Kirby and 3 other agents are typing…',
    );
    expect(sentence(['Niko', 'Kirby', 'Tenny']), isNot(contains('other')));
  });

  testWidgets('the line shows above the composer while an agent types', (
    t,
  ) async {
    final (w, transport) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      {
        'id': 'm1',
        'channelId': 'c1',
        'seq': 1,
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'createdAt': '2026-11-01T09:00:00Z',
        'content': 'Hello',
      },
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    transport.routes['GET /agents'] = (_) => [
      {'id': 'a1', 'name': 'niko', 'displayName': 'Niko', 'status': 'active'},
    ];
    transport.routes['GET /servers/s1/members'] = (_) => [];
    transport.routes['GET /tasks'] = (_) => [];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pumpAndSettle();
    expect(find.byType(RaftAgentTypingLine), findsOneWidget);
    expect(find.byKey(const Key('agent-typing-line')), findsNothing);

    final store = AgentTypingStore.of(w.client);
    store.receive(RaftEvent('agent:typing', typing('a1', 'x')));
    await t.pump();
    expect(find.text('Niko is typing…'), findsOneWidget);
    final line = t.getRect(find.byKey(const Key('agent-typing-line')));
    final composer = t.getRect(find.byType(RaftComposer));
    expect(line.bottom, lessThanOrEqualTo(composer.top + 0.5));
    expect(line.height, raftAgentTypingLineHeight);

    store.receive(
      RaftEvent('message:new', {
        'id': 'm2',
        'senderType': 'agent',
        'senderId': 'a1',
        'channelId': 'c1',
      }),
    );
    await t.pump();
    expect(find.byKey(const Key('agent-typing-line')), findsNothing);
  });

  testWidgets('in a channel the line says who works here, typing included', (
    t,
  ) async {
    final (w, transport) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    transport.routes['GET /agents'] = (_) => [
      {'id': 'a1', 'name': 'niko', 'displayName': 'Niko', 'status': 'active'},
    ];
    transport.routes['GET /servers/s1/members'] = (_) => [];
    await t.runAsync(
      () => w.services.entityDirectory.refresh(
        WorkspaceEntityKind.agents,
        force: true,
      ),
    );
    final store = AgentTypingStore.of(w.client);
    void listener() {}
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));
    const kirby = RaftWorkingAgent(
      id: 'a2',
      name: 'Kirby',
      text: 'Editing Flow.tsx',
      avatar: SizedBox(),
    );
    late BuildContext context;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    var state = agentTypingLineState(context, w, false, [kirby]);
    expect(state.sentence, '1 agent working here');
    expect(state.faces.map((a) => a.id), ['a2']);
    store.receive(RaftEvent('agent:typing', typing('a1', 'x')));
    state = agentTypingLineState(context, w, false, [kirby]);
    expect(state.faces.map((a) => a.id), ['a2', 'a1']);
    expect(state.sentence, 'Niko is typing… · 1 other working');
    expect(state.rows.last.text, 'Typing…');
    // Only the typers in a DM or a thread.
    state = agentTypingLineState(context, w, false, null);
    expect(state.inChannel, isFalse);
    expect(state.sentence, 'Niko is typing…');
    store.receive(RaftEvent('agent:typing', typing('a1', 'x', state: 'end')));
  });
}

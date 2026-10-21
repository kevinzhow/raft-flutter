import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

void _routes(MessageAdapter api) {
  api.routes['GET /channels/c1/members'] = (_) => {'humans': [], 'agents': []};
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {
    'collapseLongMessages': true,
  };
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  api.routes['GET /channels'] = (_) => [];
}

Future<void> _open(
  WidgetTester tester,
  WorkspaceController w,
  RaftChannel channel,
) async {
  w.channels = [channel];
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: ChannelSettings(controller: w, channel: channel, isPanel: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The settings actions are now lazily built. Visit the final region before
  // checking both the offered and forbidden permission cases.
  final scrollable = find
      .descendant(
        of: find.byType(ChannelSettings),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var i = 0; i < 4; i++) {
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
  }
}

Finder get _stopAgents => find.text('Stop Agents');

Iterable<RequestOptions> _sos(MessageAdapter api) =>
    api.calls.where((c) => c.path.endsWith('-all-agents'));

Future<void> _settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 40 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('member stops all agents, then resumes them with guidance', (
    tester,
  ) async {
    final (w, api) = (await tester.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    _routes(api);
    final stop = Completer<Object?>();
    api.routes['POST /channels/c1/stop-all-agents'] = (_) => stop.future;
    api.routes['POST /channels/c1/resume-all-agents'] = (_) => {'ok': true};
    await _open(
      tester,
      w,
      RaftChannel({'id': 'c1', 'name': 'release', 'joined': true}),
    );
    await tester.ensureVisible(_stopAgents);
    await tester.tap(_stopAgents);
    await tester.pumpAndSettle();
    expect(find.text('STOP ALL AGENTS'), findsOneWidget);
    expect(_sos(api), isEmpty, reason: 'opening the dialog sends nothing');
    await tester.tap(find.byKey(const ValueKey('sos-stop')));
    await _settle(tester, () => _sos(api).isNotEmpty);
    expect(find.text('Stopping…'), findsOneWidget);
    expect(_sos(api).single.method, 'POST');
    expect(_sos(api).single.path, '/channels/c1/stop-all-agents');
    stop.complete({'ok': true});
    await _settle(
      tester,
      () => find.text('AGENTS STOPPED').evaluate().isNotEmpty,
    );
    expect(find.text('AGENTS STOPPED'), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const ValueKey('sos-guidance')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'Stop touching the schema.');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sos-resume')));
    await _settle(
      tester,
      () => find.byKey(const ValueKey('channel-sos-dialog')).evaluate().isEmpty,
    );
    final resume = _sos(api).last;
    expect(resume.path, '/channels/c1/resume-all-agents');
    final prompt = (resume.data as Map)['prompt'] as String;
    expect(
      prompt,
      startsWith(
        '[SOS] The user has emergency-stopped all agents in #release because '
        "they were going off-track. Here is the user's correction and new "
        'guidance:\n\nStop touching the schema.\n\n',
      ),
    );
    expect(prompt, endsWith('before taking any action.'));
    expect(find.byKey(const ValueKey('channel-sos-dialog')), findsNothing);
    // The settings sheet stays open beneath, as in Web.
    expect(_stopAgents, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected stop stays on the confirmation with the error', (
    tester,
  ) async {
    final (w, api) = (await tester.runAsync(() => fixture('admin')))!;
    addTearDown(w.dispose);
    _routes(api);
    await _open(
      tester,
      w,
      RaftChannel({'id': 'c1', 'name': 'release', 'joined': true}),
    );
    await tester.ensureVisible(_stopAgents);
    await tester.tap(_stopAgents);
    await tester.pumpAndSettle();
    // No route: the adapter answers 404 `Unexpected endpoint`.
    await tester.tap(find.byKey(const ValueKey('sos-stop')));
    await _settle(
      tester,
      () => find.byKey(const ValueKey('sos-error')).evaluate().isNotEmpty,
    );
    expect(find.text('STOP ALL AGENTS'), findsOneWidget);
    expect(find.byKey(const ValueKey('sos-error')), findsOneWidget);
    expect(_sos(api).single.path, '/channels/c1/stop-all-agents');
    expect(
      tester
          .widget<RaftButton>(find.byKey(const ValueKey('sos-stop')))
          .onPressed,
      isNotNull,
    );
  });

  for (final (label, response) in <(String, Object?)>[
    (
      'partial',
      {
        'ok': false,
        'started': 1,
        'total': 3,
        'results': [
          {'agentId': 'a', 'ok': true},
          {'agentId': 'b', 'ok': false, 'reason': 'start_in_flight'},
          {'agentId': 'c', 'ok': false, 'error': 'Computer offline'},
        ],
      },
    ),
    ('legacy failure', {'ok': false}),
    ('missing response', null),
    (
      'incomplete results',
      {
        'ok': true,
        'started': 1,
        'total': 2,
        'results': [
          {'agentId': 'a', 'ok': true},
        ],
      },
    ),
  ]) {
    testWidgets('$label resume retains guidance until retry resolves it', (
      tester,
    ) async {
      final feedback = label == 'partial'
          ? 'sos-resume-shortfall'
          : 'sos-error';
      final (w, api) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      _routes(api);
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [
          {'id': 'b', 'name': 'Birch'},
          {'id': 'c', 'name': 'Cedar'},
        ],
      };
      api.routes['POST /channels/c1/stop-all-agents'] = (_) => {'ok': true};
      final resumeBodies = <Map>[];
      api.routes['POST /channels/c1/resume-all-agents'] = (request) {
        resumeBodies.add(Map.from(request.data as Map));
        return resumeBodies.length == 1
            ? response
            : {
                'ok': true,
                'started': 2,
                'total': 2,
                'results': [
                  {'agentId': 'b', 'ok': true},
                  {'agentId': 'c', 'ok': true},
                ],
              };
      };
      await _open(
        tester,
        w,
        RaftChannel({'id': 'c1', 'name': 'release', 'joined': true}),
      );
      await tester.tap(_stopAgents);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sos-stop')));
      await _settle(
        tester,
        () => find.text('AGENTS STOPPED').evaluate().isNotEmpty,
      );
      final field = find.descendant(
        of: find.byKey(const ValueKey('sos-guidance')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field, 'Keep the schema.');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sos-resume')));
      await _settle(
        tester,
        () =>
            resumeBodies.isNotEmpty &&
            find.byKey(Key(feedback)).evaluate().isNotEmpty,
      );
      expect(find.byKey(const ValueKey('channel-sos-dialog')), findsOneWidget);
      expect(
        tester.widget<EditableText>(field).controller.text,
        'Keep the schema.',
      );
      expect(find.byKey(Key(feedback)), findsOneWidget);
      expect(resumeBodies.single.containsKey('agentIds'), false);
      if (label == 'partial') {
        // Web counts: one agent still starting, one failed (no names).
        expect(
          find.text(
            '1 agent is still starting and did not get your guidance. Try again in a moment.',
          ),
          findsOneWidget,
        );
        expect(find.text('1 agent could not be resumed.'), findsOneWidget);
        expect(find.textContaining('Birch'), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('sos-resume')));
      await _settle(
        tester,
        () =>
            find.byKey(const ValueKey('channel-sos-dialog')).evaluate().isEmpty,
      );
      expect(resumeBodies, hasLength(2));
      if (label == 'partial') expect(resumeBodies.last['agentIds'], ['b', 'c']);
      expect(resumeBodies.last['prompt'], resumeBodies.first['prompt']);
      expect(find.byKey(const ValueKey('channel-sos-dialog')), findsNothing);
      expect(find.byKey(Key(feedback)), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, role, json) in [
    ('guest', 'guest', <String, dynamic>{'joined': true}),
    ('not joined', 'member', <String, dynamic>{'joined': false}),
    (
      'archived',
      'owner',
      <String, dynamic>{'joined': true, 'archivedAt': '2026-01-01T00:00:00Z'},
    ),
    (
      'direct message',
      'owner',
      <String, dynamic>{'joined': true, 'type': 'dm'},
    ),
    (
      '#all without channel management',
      'member',
      // GET /channels carries the viewer's per-channel capabilities: a
      // member has none in #all (addChannelMembers is false there), so the
      // drawer has neither a management nor a leave surface.
      <String, dynamic>{
        'joined': true,
        'name': 'all',
        'channelCapabilities': <String, dynamic>{},
      },
    ),
  ]) {
    testWidgets('$name does not offer Stop Agents', (tester) async {
      final (w, api) = (await tester.runAsync(() => fixture(role)))!;
      addTearDown(w.dispose);
      _routes(api);
      await _open(
        tester,
        w,
        RaftChannel({'id': 'c1', 'name': 'release', ...json}),
      );
      expect(_stopAgents, findsNothing);
    });
  }

  for (final role in ['owner', 'admin', 'member']) {
    testWidgets('$role in a joined channel is offered Stop Agents', (
      tester,
    ) async {
      final (w, api) = (await tester.runAsync(() => fixture(role)))!;
      addTearDown(w.dispose);
      _routes(api);
      await _open(
        tester,
        w,
        RaftChannel({'id': 'c1', 'name': 'release', 'joined': true}),
      );
      expect(_stopAgents, findsOneWidget);
    });
  }
}

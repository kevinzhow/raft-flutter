// WP-COMP1 R18 (Web v1.24 DeleteComputerDialog phases confirm -> others ->
// force, OthersAgentsOnComputerDialog, AgentOwnerNotifyActions): deleting
// one's own Computer while other people's agents are on it lists them with
// Notify owner to move it before Force unbind and delete.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_owner_notify.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mobile_computer_navigation_test.dart' show fixture;

String _in(Duration d) => DateTime.now().add(d).toUtc().toIso8601String();

class _Others {
  _Others({List<Map<String, dynamic>>? agents}) {
    listed = agents ?? [_agent('a1', 'Zed', owner: 'Bob')];
    f.overrides['GET /servers/a/machines'] = (_) => {
      'machines': [
        if (!deleted)
          {
            'id': 'computer-a',
            'name': 'Build Computer',
            'isComputer': true,
            'status': 'online',
            'computerVersion': '1.0.44',
            'hostname': 'fixture-host',
            'userId': 'alice',
            'runtimes': ['codex'],
          },
      ],
    };
    f.overrides['POST /servers/a/machines/computer-a/revoke-computer-key'] =
        (o) {
          final body = (o.data as Map?) ?? const {};
          revokes.add(Map<String, dynamic>.from(body));
          final force = (body['forceAgentIds'] as List?)?.cast<String>();
          final key = 'POST /servers/a/machines/computer-a/revoke-computer-key';
          var unresolved =
              force == null || !listed.every((a) => force.contains(a['id']));
          if (conflictList != null && force != null) {
            // More agents arrived since the list was read: nothing happens.
            listed = conflictList!;
            conflictList = null;
            unresolved = true;
          }
          if (unresolved) {
            f.adapter.statuses[key] = 409;
            return {
              'error': 'Other people’s agents are on this computer.',
              'code': 'others_agents_on_computer',
              'agents': listed,
            };
          }
          f.adapter.statuses.remove(key);
          return <String, dynamic>{};
        };
    f.overrides['DELETE /servers/a/machines/computer-a'] = (_) {
      deletes++;
      deleted = true;
      return <String, dynamic>{};
    };
    f.overrides['POST /servers/a/machines/computer-a/notify-agent-owners'] =
        (o) async {
          notifies.add(Map<String, dynamic>.from(o.data as Map));
          if (notifyFails) {
            f.adapter.statuses[_notifyKey] = 500;
            return {'error': 'nope'};
          }
          f.adapter.statuses.remove(_notifyKey);
          final ids = (o.data['agentIds'] as List).cast<String>();
          return notifyAnswer(ids);
        };
  }

  static const _notifyKey =
      'POST /servers/a/machines/computer-a/notify-agent-owners';

  static Map<String, dynamic> _agent(
    String id,
    String name, {
    String? owner,
    String? notifiedAt,
    String? nextAt,
    bool assistant = false,
  }) => {
    'id': id,
    'name': name,
    'owner': owner == null ? null : {'id': 'o-$id', 'name': owner},
    'ownerNotifiedAt': notifiedAt,
    'ownerNextNotifyAt': nextAt,
    'personalAssistant': assistant,
  };

  final f = fixture();
  late List<Map<String, dynamic>> listed;
  List<Map<String, dynamic>>? conflictList;
  bool deleted = false, notifyFails = false;
  int deletes = 0;
  final revokes = <Map<String, dynamic>>[];
  final notifies = <Map<String, dynamic>>[];
  Map<String, dynamic> Function(List<String> ids) notifyAnswer = (ids) => {
    'notified': [
      for (final id in ids) {'agentId': id, 'notifiedAt': _in(Duration.zero)},
    ],
    'skipped': <Object>[],
  };

  Finder get others => find.byKey(const ValueKey('computer-others-agents'));
  Finder get force => find.byKey(const ValueKey('force-unbind-dialog'));
  Finder get forceConfirm => find.byKey(const ValueKey('force-unbind-confirm'));
  Finder get forceFromList =>
      find.byKey(const ValueKey('computer-others-agents-force'));
  Finder notify(String id) => find.byKey(ValueKey('computer-notify-$id'));

  Future<void> open(WidgetTester t, {double width = 390}) async {
    await f.mount(
      t,
      'light',
      width,
      uri: Uri.parse('/s/alpha/computer/computer-a'),
    );
    addTearDown(() => f.close(t));
    await f.flush(t);
    await t.ensureVisible(find.byKey(const ValueKey('computer-delete')));
    await t.tap(find.byKey(const ValueKey('computer-delete')));
    await f.flush(t);
    await t.tap(
      find
          .descendant(
            of: find.byType(RaftConfirmDialog),
            matching: find.text('Delete computer'),
          )
          .last,
    );
    await f.flush(t);
  }

  Future<void> tapNotify(WidgetTester t, String id) async {
    await t.ensureVisible(notify(id));
    await t.tap(notify(id));
    await f.flush(t);
  }

  bool enabled(WidgetTester t, Finder button) =>
      t.widget<RaftButton>(button).onPressed != null;
}

void main() {
  for (final width in [390.0, 856.0]) {
    testWidgets('409 shows the others list, not the force confirm ($width)', (
      t,
    ) async {
      final h = _Others(
        agents: [
          _Others._agent('a1', 'Zed', owner: 'Bob'),
          _Others._agent('a2', 'Orphan'),
        ],
      );
      await h.open(t, width: width);
      expect(h.revokes, [<String, dynamic>{}]);
      expect(h.others, findsOneWidget);
      expect(h.force, findsNothing);
      expect(
        find.text("Other people's agents on this computer"),
        findsOneWidget,
      );
      expect(find.text('Zed'), findsOneWidget);
      expect(find.text('Owner: Bob'), findsOneWidget);
      expect(find.text('Orphan'), findsOneWidget);
      expect(find.text('No owner'), findsOneWidget);
      expect(h.deletes, 0);
    });
  }

  testWidgets('Notify owner posts the agent id, then Remind again', (t) async {
    final h = _Others();
    await h.open(t);
    expect(find.text('Notify owner to move it'), findsOneWidget);
    expect(find.textContaining('Notified'), findsNothing);
    await h.tapNotify(t, 'a1');
    expect(h.notifies, [
      {
        'agentIds': ['a1'],
      },
    ]);
    expect(find.textContaining('Notified ·'), findsOneWidget);
    expect(find.text('Remind again'), findsOneWidget);
    expect(find.text('Notify owner to move it'), findsNothing);
    expect(h.enabled(t, h.notify('a1')), isTrue);
  });

  testWidgets('rate_limited disables the button and says when', (t) async {
    final h = _Others();
    h.notifyAnswer = (ids) => {
      'notified': <Object>[],
      'skipped': [
        {
          'agentId': ids.single,
          'reason': 'rate_limited',
          'nextAllowedAt': _in(const Duration(hours: 3)),
        },
      ],
    };
    await h.open(t);
    await h.tapNotify(t, 'a1');
    expect(h.enabled(t, h.notify('a1')), isFalse);
    expect(find.text('You can remind again in 3 hours'), findsOneWidget);
  });

  testWidgets('rate_limited without a time says once every 24 hours', (t) async {
    final h = _Others();
    h.notifyAnswer = (ids) => {
      'notified': <Object>[],
      'skipped': [
        {'agentId': ids.single, 'reason': 'rate_limited'},
      ],
    };
    await h.open(t);
    await h.tapNotify(t, 'a1');
    expect(h.enabled(t, h.notify('a1')), isFalse);
    expect(find.text('You can remind once every 24 hours'), findsOneWidget);
  });

  testWidgets('a list that is already rate limited opens disabled', (t) async {
    final h = _Others(
      agents: [
        _Others._agent(
          'a1',
          'Zed',
          owner: 'Bob',
          notifiedAt: _in(const Duration(hours: -2)),
          nextAt: _in(const Duration(hours: 22)),
        ),
      ],
    );
    await h.open(t);
    expect(h.enabled(t, h.notify('a1')), isFalse);
    expect(find.text('Remind again'), findsOneWidget);
    expect(find.textContaining('Notified ·'), findsOneWidget);
    expect(find.text('You can remind again in 22 hours'), findsOneWidget);
  });

  testWidgets('no_owner turns the row into the contact-an-admin line', (t) async {
    final h = _Others();
    h.notifyAnswer = (ids) => {
      'notified': <Object>[],
      'skipped': [
        {'agentId': ids.single, 'reason': 'no_owner'},
      ],
    };
    await h.open(t);
    await h.tapNotify(t, 'a1');
    expect(h.enabled(t, h.notify('a1')), isFalse);
    expect(find.text('No owner'), findsOneWidget);
    expect(
      find.textContaining("There's no owner to notify."),
      findsOneWidget,
    );
  });

  testWidgets('not_delivered says so and can be tried again at once', (t) async {
    final h = _Others();
    h.notifyAnswer = (ids) => {
      'notified': <Object>[],
      'skipped': [
        {'agentId': ids.single, 'reason': 'not_delivered'},
      ],
    };
    await h.open(t);
    await h.tapNotify(t, 'a1');
    expect(find.text("The reminder wasn't sent. Try again."), findsOneWidget);
    expect(h.enabled(t, h.notify('a1')), isTrue);
    expect(find.textContaining('Notified ·'), findsNothing);
  });

  testWidgets('a failed call says it could not notify', (t) async {
    final h = _Others()..notifyFails = true;
    await h.open(t);
    await h.tapNotify(t, 'a1');
    expect(find.text("Couldn't notify the owner. Try again."), findsOneWidget);
    expect(h.enabled(t, h.notify('a1')), isTrue);
  });

  testWidgets('a personal assistant names who can move it', (t) async {
    final h = _Others(
      agents: [_Others._agent('a1', 'Helper', owner: 'Bob', assistant: true)],
    );
    await h.open(t);
    expect(
      find.text(
        "It's a personal assistant: only its owner can move it. A server admin can only stop it.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('Force unbind and delete opens the force confirm; Cancel goes back', (
    t,
  ) async {
    final h = _Others();
    await h.open(t);
    await h.tapNotify(t, 'a1');
    await t.tap(h.forceFromList);
    await h.f.flush(t);
    expect(h.force, findsOneWidget);
    expect(h.others, findsNothing);
    expect(find.text('Force unbind 1 agent?'), findsOneWidget);
    await t.tap(
      find.descendant(of: h.force, matching: find.text('Cancel')),
    );
    await h.f.flush(t);
    expect(h.force, findsNothing);
    expect(h.others, findsOneWidget);
    // What the list learned from its own calls is still there.
    expect(find.textContaining('Notified ·'), findsOneWidget);
    expect(h.deletes, 0);
    expect(h.revokes, hasLength(1));
  });

  testWidgets('confirming the force revokes with forceAgentIds, then deletes', (
    t,
  ) async {
    final h = _Others(
      agents: [
        _Others._agent('a1', 'Zed', owner: 'Bob'),
        _Others._agent('a2', 'Orphan'),
      ],
    );
    await h.open(t);
    await t.tap(h.forceFromList);
    await h.f.flush(t);
    await t.tap(h.forceConfirm);
    await h.f.flush(t);
    expect(h.revokes.last, {
      'forceAgentIds': ['a1', 'a2'],
    });
    expect(h.deletes, 1);
    expect(h.force, findsNothing);
    expect(h.others, findsNothing);
  });

  testWidgets('a force 409 shows the newer list and says nothing happened', (
    t,
  ) async {
    final h = _Others();
    h.conflictList = [
      _Others._agent('a1', 'Zed', owner: 'Bob'),
      _Others._agent('a3', 'Newcomer', owner: 'Cy'),
    ];
    await h.open(t);
    await t.tap(h.forceFromList);
    await h.f.flush(t);
    await t.tap(h.forceConfirm);
    await h.f.flush(t);
    expect(h.deletes, 0);
    expect(h.force, findsOneWidget);
    expect(find.text('Force unbind 2 agents?'), findsOneWidget);
    expect(find.text('Newcomer'), findsOneWidget);
    expect(
      find.text(
        'More agents were added to this computer, so nothing was unbound. Check the list and confirm again.',
      ),
      findsOneWidget,
    );
    // Confirming again names both and finishes.
    await t.tap(h.forceConfirm);
    await h.f.flush(t);
    expect(h.revokes.last, {
      'forceAgentIds': ['a1', 'a3'],
    });
    expect(h.deletes, 1);
  });

  testWidgets('closing the list ends the flow without deleting', (t) async {
    final h = _Others();
    await h.open(t);
    await t.tap(
      find.descendant(of: h.others, matching: find.text('Cancel')),
    );
    await h.f.flush(t);
    expect(h.others, findsNothing);
    expect(h.force, findsNothing);
    expect(h.deletes, 0);
  });

  group('postNotifyAgentOwners', () {
    test('sends nothing for no ids and batches at 200', () async {
      final calls = <List<String>>[];
      Future<dynamic> command(String m, String p, {dynamic data}) async {
        final ids = ((data as Map)['agentIds'] as List).cast<String>();
        calls.add(ids);
        return {
          'notified': [
            for (final id in ids) {'agentId': id, 'notifiedAt': _in(Duration.zero)},
          ],
          'skipped': <Object>[],
        };
      }

      expect(
        (await postNotifyAgentOwners(command, '/x', const [])).notified,
        isEmpty,
      );
      expect(calls, isEmpty);
      final ids = [for (var i = 0; i < 450; i++) 'a$i'];
      final result = await postNotifyAgentOwners(command, '/x', [...ids, 'a0']);
      expect(calls.map((c) => c.length), [200, 200, 50]);
      expect(result.notified, hasLength(450));
    });
  });
}

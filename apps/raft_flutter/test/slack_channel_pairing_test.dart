// Web ChannelSlackBridgeField: pairing a channel with a Slack channel from the
// channel's own settings and create form (RFC: Slack Bridge, channel scope).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/slack_channel_pairing.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture;

/// The bridge control plane as a small state machine over the pairs.
class Bridge {
  Bridge({this.stage = 'health', List<Map<String, dynamic>>? pairs})
    : pairs = pairs ?? [];
  String stage;
  final List<Map<String, dynamic>> pairs;
  bool preflightPasses = true;
  final calls = <String>[];

  Map<String, dynamic> snapshot({bool preflight = false}) => {
    'protocolVersion': 1,
    'oauthAuthority': null,
    'snapshot': {
      'stage': stage,
      'workspaceName': 'Fixture Slack',
      'raftChannels': [
        {'id': 'c1', 'name': 'work'},
        {'id': 'c2', 'name': 'other'},
        {'id': 'c3', 'name': 'third'},
      ],
      'slackChannels': [
        {
          'id': 's-pub',
          'name': 'launch',
          'isMember': true,
          'privacyClass': 'public',
        },
        {
          'id': 's-busy',
          'name': 'busy',
          'isMember': true,
          'privacyClass': 'public',
        },
        {
          'id': 's-app',
          'name': 'no-app',
          'isMember': false,
          'privacyClass': 'public',
        },
        {
          'id': 's-priv',
          'name': 'secret',
          'isMember': true,
          'privacyClass': 'private',
        },
        {'id': 's-any', 'name': 'plain', 'isMember': true},
      ],
      'channelPairs': [
        for (final p in pairs) {...p},
      ],
      'preflight': preflight
          ? {
              'state': preflightPasses ? 'passed' : 'failed',
              'checks': [
                for (final id in ['oauth', 'endpoint', 'scope', 'audience'])
                  {'id': id, 'state': preflightPasses ? 'passed' : 'failed'},
              ],
            }
          : null,
      'rawHealth': {
        'install': null,
        'credential': null,
        'bindings': <dynamic>[],
        'audiences': <dynamic>[],
        'lastVerifiedAt': null,
        'failingSurface': null,
      },
    },
  };
}

void main() {
  Future<(dynamic, dynamic, Bridge)> boot(
    WidgetTester? t, {
    bool flag = true,
    Bridge? bridge,
    Map<String, dynamic>? row,
  }) async {
    final b = bridge ?? Bridge();
    final (w, api) = (t == null
        ? await fixture('owner')
        : await t.runAsync(() => fixture('owner')))!;
    final channel = RaftChannel(
      row ??
          {
            'id': 'c1',
            'name': 'work',
            'type': 'channel',
            'joined': true,
            'channelCapabilities': {
              'editChannelMetadata': true,
              'archiveChannels': true,
              'deleteChannels': true,
              'addChannelMembers': true,
            },
          },
    );
    w.channels = [channel];
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': [],
      'agents': [],
    };
    api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
    api.routes['GET /channels/c1/message-display-settings'] = (_) => {
      'collapseLongMessages': true,
    };
    api.routes['GET /channels/c1/notification-settings'] = (_) => {
      'activityMuted': false,
    };
    api.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'slack_bridge_v0', 'enabled': flag},
      ],
    };
    api.routes['GET /slack-bridge/provisioning'] = (_) {
      b.calls.add('GET');
      return b.snapshot();
    };
    api.routes['PUT /slack-bridge/provisioning/channel-pairs'] = (o) {
      b.calls.add('PUT ${o.data}');
      b.pairs
        ..clear()
        ..addAll([
          for (final p in (o.data['pairs'] as List))
            {
              'raftChannelId': p['raftChannelId'],
              'slackChannelId': p['slackChannelId'],
              'bindingEpoch': 5,
            },
        ]);
      return b.snapshot();
    };
    api.routes['DELETE /slack-bridge/provisioning/channel-pairs'] = (o) {
      b.calls.add('DELETE ${o.data}');
      final gone = (o.data['pairs'] as List).first as Map;
      b.pairs.removeWhere(
        (p) =>
            p['raftChannelId'] == gone['raftChannelId'] &&
            p['slackChannelId'] == gone['slackChannelId'],
      );
      return b.snapshot();
    };
    api.routes['POST /slack-bridge/provisioning/preflight'] = (_) {
      b.calls.add('preflight');
      return b.snapshot(preflight: true);
    };
    api.routes['POST /slack-bridge/provisioning/enable'] = (_) {
      b.calls.add('enable');
      return b.snapshot(preflight: true);
    };
    return (w, api, b);
  }

  group('SlackChannelPairing', () {
    test(
      'available only with the flag on and a bridge in the health stage',
      () async {
        for (final (flag, stage, available) in [
          (true, 'health', true),
          (false, 'health', false),
          (true, 'channels', false),
          (true, 'connect', false),
        ]) {
          final (w, _, bridge) = await boot(
            null,
            flag: flag,
            bridge: Bridge(stage: stage),
          );
          final pairing = SlackChannelPairing(w, channelId: 'c1');
          await pairing.load(canManage: true);
          expect(pairing.available, available, reason: '$flag $stage');
          expect(
            bridge.calls,
            flag ? ['GET'] : isEmpty,
            reason: 'no provisioning read while the flag is off',
          );
          pairing.dispose();
          w.dispose();
        }
      },
    );

    test('someone who cannot manage the channel reads nothing', () async {
      final (w, api, bridge) = await boot(null);
      final pairing = SlackChannelPairing(w, channelId: 'c1');
      await pairing.load(canManage: false);
      expect(pairing.available, isFalse);
      expect(bridge.calls, isEmpty);
      expect(
        api.calls.where((c) => c.path == '/feature-flags/evaluate'),
        isEmpty,
      );
      pairing.dispose();
      w.dispose();
    });

    test('a failed read hides the field', () async {
      final (w, api, _) = await boot(null);
      api.routes['GET /slack-bridge/provisioning'] = (_) => throw DioException(
        requestOptions: RequestOptions(path: '/slack-bridge/provisioning'),
      );
      final pairing = SlackChannelPairing(w, channelId: 'c1');
      await pairing.load(canManage: true);
      expect(pairing.available, isFalse);
      pairing.dispose();
      w.dispose();
    });

    test(
      'the saved pairing is the starting pick; reset returns to it',
      () async {
        final (w, _, _) = await boot(
          null,
          bridge: Bridge(
            pairs: [
              {
                'raftChannelId': 'c1',
                'slackChannelId': 's-pub',
                'bindingEpoch': 3,
              },
            ],
          ),
        );
        final pairing = SlackChannelPairing(w, channelId: 'c1');
        await pairing.load(canManage: true);
        expect(pairing.selected, 's-pub');
        expect(pairing.dirty, isFalse);
        pairing.select('');
        expect(pairing.dirty, isTrue);
        pairing.reset();
        expect(pairing.selected, 's-pub');
        expect(pairing.dirty, isFalse);
        pairing.dispose();
        w.dispose();
      },
    );

    test(
      'apply: nothing to do when the pick equals the saved pairing',
      () async {
        final (w, _, bridge) = await boot(null);
        final pairing = SlackChannelPairing(w, channelId: 'c1');
        await pairing.load(canManage: true);
        bridge.calls.clear();
        await pairing.apply('c1');
        expect(bridge.calls, ['GET']);
        pairing.dispose();
        w.dispose();
      },
    );

    test(
      'apply: a new pairing saves every pair, verifies and enables',
      () async {
        final (w, _, bridge) = await boot(
          null,
          bridge: Bridge(
            pairs: [
              {
                'raftChannelId': 'c2',
                'slackChannelId': 's-busy',
                'bindingEpoch': 2,
              },
            ],
          ),
        );
        final pairing = SlackChannelPairing(w, channelId: 'c1');
        await pairing.load(canManage: true);
        pairing.select('s-pub');
        bridge.calls.clear();
        await pairing.apply('c1');
        expect(bridge.calls, [
          'GET',
          "PUT {pairs: [{raftChannelId: c2, slackChannelId: s-busy}, {raftChannelId: c1, slackChannelId: s-pub}]}",
          'preflight',
          'enable',
        ]);
        expect(pairing.current, 's-pub');
        pairing.dispose();
        w.dispose();
      },
    );

    test('apply: changing the pairing removes the old one by its binding epoch first', () async {
      final (w, _, bridge) = await boot(
        null,
        bridge: Bridge(
          pairs: [
            {
              'raftChannelId': 'c1',
              'slackChannelId': 's-pub',
              'bindingEpoch': 3,
            },
          ],
        ),
      );
      final pairing = SlackChannelPairing(w, channelId: 'c1');
      await pairing.load(canManage: true);
      pairing.select('s-any');
      bridge.calls.clear();
      await pairing.apply('c1');
      expect(bridge.calls, [
        'GET',
        'DELETE {pairs: [{raftChannelId: c1, slackChannelId: s-pub, expectedBindingEpoch: 3}]}',
        'PUT {pairs: [{raftChannelId: c1, slackChannelId: s-any}]}',
        'preflight',
        'enable',
      ]);
      pairing.dispose();
      w.dispose();
    });

    test('apply: "Do not connect" only removes the pairing', () async {
      final (w, _, bridge) = await boot(
        null,
        bridge: Bridge(
          pairs: [
            {
              'raftChannelId': 'c1',
              'slackChannelId': 's-pub',
              'bindingEpoch': 3,
            },
          ],
        ),
      );
      final pairing = SlackChannelPairing(w, channelId: 'c1');
      await pairing.load(canManage: true);
      pairing.select('');
      bridge.calls.clear();
      await pairing.apply('c1');
      expect(bridge.calls, [
        'GET',
        'DELETE {pairs: [{raftChannelId: c1, slackChannelId: s-pub, expectedBindingEpoch: 3}]}',
      ]);
      expect(pairing.current, '');
      pairing.dispose();
      w.dispose();
    });

    test('apply: a failed preflight throws and never enables', () async {
      final (w, _, bridge) = await boot(null);
      bridge.preflightPasses = false;
      final pairing = SlackChannelPairing(w, channelId: 'c1');
      await pairing.load(canManage: true);
      pairing.select('s-pub');
      bridge.calls.clear();
      await expectLater(pairing.apply('c1'), throwsA(isA<StateError>()));
      expect(bridge.calls.last, 'preflight');
      pairing.dispose();
      w.dispose();
    });

    testWidgets('options: privacy class, paired and app-missing channels', (
      t,
    ) async {
      final (w, _, _) = await boot(
        t,
        bridge: Bridge(
          pairs: [
            {
              'raftChannelId': 'c2',
              'slackChannelId': 's-busy',
              'bindingEpoch': 2,
            },
          ],
        ),
      );
      final pairing = SlackChannelPairing(w, channelId: 'c1');
      await t.runAsync(() => pairing.load(canManage: true));
      late List<RaftSlackChannelOption> options;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (context) {
              options = pairing.options(context, 'public');
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        [for (final o in options) (o.value, o.label, o.enabled)],
        [
          ('', 'Do not connect to Slack', true),
          ('s-pub', '#launch', true),
          ('s-busy', '#busy — already paired', false),
          ('s-app', '#no-app — invite the Raft app in Slack', false),
          ('s-any', '#plain', true),
        ],
      );
      pairing.dispose();
      w.dispose();
    });
  });

  group('channel settings', () {
    Future<(dynamic, dynamic, Bridge)> open(
      WidgetTester t, {
      bool flag = true,
      Bridge? bridge,
      Map<String, dynamic>? row,
    }) async {
      final made = await boot(t, flag: flag, bridge: bridge, row: row);
      final (w, api, b) = made;
      addTearDown(w.dispose);
      t.view.physicalSize = const Size(1280, 2600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final channel = (w.channels as List<RaftChannel>).first;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('host-open'),
                onPressed: () => ChannelSettings.show(
                  context,
                  controller: w,
                  channel: channel,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('host-open')));
      await t.pumpAndSettle();
      return (w, api, b);
    }

    Finder field() => find.byKey(const ValueKey('channel-slack-bridge-field'));

    testWidgets('the field appears only while the bridge is ready', (t) async {
      await open(t);
      expect(field(), findsOneWidget);
      expect(find.text('Connect to Slack'), findsOneWidget);
      expect(
        find.text(
          'Optionally pair this Raft channel with one available Slack channel.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('flag off, bridge not ready or no management right: no field', (
      t,
    ) async {
      await open(t, flag: false);
      expect(field(), findsNothing);
      await t.pumpWidget(const SizedBox());
      await open(t, bridge: Bridge(stage: 'oauth'));
      expect(field(), findsNothing);
      await t.pumpWidget(const SizedBox());
      await open(
        t,
        row: {
          'id': 'c1',
          'name': 'work',
          'type': 'channel',
          'joined': true,
          'channelCapabilities': {'addChannelMembers': true},
        },
      );
      expect(field(), findsNothing);
    });

    testWidgets('an archived channel never shows it', (t) async {
      await open(
        t,
        row: {
          'id': 'c1',
          'name': 'work',
          'type': 'channel',
          'joined': true,
          'archivedAt': '2026-10-01T00:00:00.000Z',
          'channelCapabilities': {
            'editChannelMetadata': true,
            'archiveChannels': true,
          },
        },
      );
      expect(field(), findsNothing);
    });

    testWidgets(
      'picking a Slack channel enables Save, which applies it after the channel',
      (t) async {
        final (_, api, bridge) = await open(t);
        expect(
          t
              .widget<RaftSettingsRecipeButton>(
                find.byKey(const ValueKey('channel-settings-save-inline')),
              )
              .onPressed,
          isNull,
        );
        await t.tap(find.byKey(const ValueKey('channel-slack-bridge-select')));
        await t.pumpAndSettle();
        await t.tap(find.text('#launch').last);
        await t.pumpAndSettle();
        final save = find.byKey(const ValueKey('channel-settings-save-inline'));
        expect(t.widget<RaftSettingsRecipeButton>(save).onPressed, isNotNull);
        bridge.calls.clear();
        await t.ensureVisible(save);
        await t.tap(save);
        await t.pumpAndSettle(const Duration(milliseconds: 100));
        expect(bridge.calls, [
          'GET',
          'PUT {pairs: [{raftChannelId: c1, slackChannelId: s-pub}]}',
          'preflight',
          'enable',
        ]);
        // Only the Slack pairing changed: the channel itself is not patched.
        expect(api.calls.where((c) => c.method == 'PATCH'), isEmpty);
        expect(bridge.pairs.single['slackChannelId'], 's-pub');
      },
    );

    testWidgets(
      'a failed bridge says the channel was saved and keeps the draft',
      (t) async {
        final (_, _, bridge) = await open(t);
        bridge.preflightPasses = false;
        await t.tap(find.byKey(const ValueKey('channel-slack-bridge-select')));
        await t.pumpAndSettle();
        await t.tap(find.text('#launch').last);
        await t.pumpAndSettle();
        final save = find.byKey(const ValueKey('channel-settings-save-inline'));
        await t.ensureVisible(save);
        await t.tap(save);
        await t.pumpAndSettle(const Duration(milliseconds: 100));
        expect(
          find.text(
            'The channel was saved, but its Slack bridge was not enabled. Retry to finish the bridge setup.',
          ),
          findsOneWidget,
        );
        expect(t.widget<RaftSettingsRecipeButton>(save).onPressed, isNotNull);
      },
    );

    testWidgets('an unsaved pairing guards closing the drawer', (t) async {
      await open(t);
      await t.tap(find.byKey(const ValueKey('channel-slack-bridge-select')));
      await t.pumpAndSettle();
      await t.tap(find.text('#launch').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('channel-overflow-scrim')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('channel-overflow-unsaved-prompt')),
        findsOneWidget,
      );
    });
  });

  group('create channel', () {
    testWidgets(
      'a created channel is paired once; a failed bridge retries without a second channel',
      (t) async {
        final (w, api, bridge) = await boot(t);
        addTearDown(w.dispose);
        var creates = 0;
        api.routes['POST /channels'] = (_) {
          creates++;
          return {
            'id': 'c1',
            'name': 'newroom',
            'type': 'channel',
            'joined': true,
          };
        };
        api.routes['GET /channels'] = (_) => [];
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        RaftChannel? created;
        t.view.physicalSize = const Size(900, 1800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: CreateChannelDialog(
                controller: w,
                onCreated: (c) async => created = c,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('channel-slack-bridge-field')),
          findsOneWidget,
        );
        await t.enterText(find.byType(TextField).first, 'newroom');
        await t.tap(find.byKey(const ValueKey('channel-slack-bridge-select')));
        await t.pumpAndSettle();
        await t.tap(find.text('#launch').last);
        await t.pumpAndSettle();
        bridge.preflightPasses = false;
        await t.tap(find.widgetWithText(RaftButton, 'Create Channel'));
        await t.pumpAndSettle(const Duration(milliseconds: 100));
        expect(creates, 1);
        expect(
          find.text(
            'The channel was saved, but its Slack bridge was not enabled. Retry to finish the bridge setup.',
          ),
          findsOneWidget,
        );
        expect(created, isNull, reason: 'the dialog stays open');
        bridge.preflightPasses = true;
        await t.tap(find.widgetWithText(RaftButton, 'Create Channel'));
        await t.pumpAndSettle(const Duration(milliseconds: 100));
        expect(creates, 1, reason: 'a retry never creates a second channel');
        expect(created?.id, 'c1');
        expect(bridge.pairs.single['slackChannelId'], 's-pub');
      },
    );

    testWidgets('without the bridge the dialog is unchanged', (t) async {
      final (w, api, bridge) = await boot(t, flag: false);
      addTearDown(w.dispose);
      api.routes['GET /agents'] = (_) => [];
      api.routes['GET /servers/s1/members'] = (_) => [];
      t.view.physicalSize = const Size(900, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(body: CreateChannelDialog(controller: w)),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('channel-slack-bridge-field')),
        findsNothing,
      );
      expect(bridge.calls, isEmpty);
    });
  });
}

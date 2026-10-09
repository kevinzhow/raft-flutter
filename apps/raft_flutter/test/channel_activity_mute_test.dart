import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'joint_channel_views_test.dart' show fixture;

RaftChannel _channel({
  String type = 'channel',
  bool joined = true,
  bool supported = true,
}) => RaftChannel({
  'id': 'c1',
  'name': 'work',
  'type': type,
  'joined': joined,
  'activityMuteSupported': supported,
});

Finder _mute() => find.byWidgetPredicate(
  (widget) => widget is RaftSwitch && widget.semanticLabel == 'Mute activity',
);

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark mute round trip waits for API confirmation', (
      tester,
    ) async {
      final (w, api) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      final channel = _channel();
      w.channels = [channel];
      var muted = false;
      final pending = Completer<void>();
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
      api.routes['GET /channels/c1/message-display-settings'] = (_) => {
        'collapseLongMessages': true,
      };
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.routes['GET /channels/c1/notification-settings'] = (_) => {
        'activityMuted': muted,
      };
      api.routes['PATCH /channels/c1/notification-settings'] = (request) async {
        if (request.data['activityMuted'] == true) await pending.future;
        muted = request.data['activityMuted'] as bool;
        return {'activityMuted': muted};
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: ChannelSettings(
              controller: w,
              channel: channel,
              isPanel: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<RaftSwitch>(_mute()).value, false);
      final oldToggle = tester.widget<RaftSwitch>(_mute()).onChanged!;
      await tester.ensureVisible(_mute());
      await tester.tap(_mute());
      await tester.pump();
      expect(tester.widget<RaftSwitch>(_mute()).onChanged, isNull);
      expect(tester.widget<RaftSwitch>(_mute()).value, false);
      // An activation queued before the busy rebuild must not write twice.
      oldToggle(true);
      for (
        var i = 0;
        i < 8 && api.calls.where((call) => call.method == 'PATCH').isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(api.calls.where((call) => call.method == 'PATCH').length, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<RaftSwitch>(_mute()).value, true);
      await tester.tap(_mute());
      await tester.pumpAndSettle();
      expect(muted, false);
      expect(tester.widget<RaftSwitch>(_mute()).value, false);
      expect(
        api.calls
            .where((call) => call.method == 'PATCH')
            .map((call) => call.data),
        [
          {'activityMuted': true},
          {'activityMuted': false},
        ],
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in [
    'standalone',
    'dm',
    'not-joined',
    'unsupported',
    'missing-preference',
  ]) {
    testWidgets('$mode does not expose an activity mute action', (
      tester,
    ) async {
      final (w, api) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      final channel = _channel(
        type: mode == 'dm' ? 'dm' : 'channel',
        joined: mode != 'not-joined',
        supported: mode != 'unsupported',
      );
      w.channels = [channel];
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
      api.routes['GET /channels/c1/message-display-settings'] = (_) => {};
      api.routes['GET /channels/c1/notification-settings'] = (_) =>
          mode == 'missing-preference' ? {} : {'activityMuted': false};
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: ChannelSettings(
              controller: w,
              channel: channel,
              isPanel: mode != 'standalone',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_mute(), findsNothing);
      expect(api.calls.where((call) => call.method == 'PATCH'), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final revocation in ['membership', 'workspace', 'generation']) {
    testWidgets('$revocation change rejects a previously mounted mute action', (
      tester,
    ) async {
      final (w, api) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      final channel = _channel();
      w.channels = [channel];
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
      api.routes['GET /channels/c1/message-display-settings'] = (_) => {};
      api.routes['GET /channels/c1/notification-settings'] = (_) => {
        'activityMuted': false,
      };
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: ChannelSettings(
              controller: w,
              channel: channel,
              isPanel: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final staleToggle = tester.widget<RaftSwitch>(_mute()).onChanged!;
      switch (revocation) {
        case 'membership':
          w.channels = [_channel(joined: false)];
        case 'workspace':
          w.server = RaftRecord({'id': 's2', 'role': 'member'});
        case 'generation':
          w.client.selectServer('s2');
      }
      staleToggle(true);
      await tester.pumpAndSettle();
      expect(api.calls.where((call) => call.method == 'PATCH'), isEmpty);
      expect(
        find.textContaining(
          'Channel activity preference is no longer available.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'failed API write leaves the preference unchanged and retry works',
    (tester) async {
      final (w, api) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      final channel = _channel();
      w.channels = [channel];
      var muted = false;
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
      api.routes['GET /channels/c1/message-display-settings'] = (_) => {};
      api.routes['GET /channels/c1/notification-settings'] = (_) => {
        'activityMuted': muted,
      };
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.statuses['PATCH /channels/c1/notification-settings'] = 503;
      api.routes['PATCH /channels/c1/notification-settings'] = (_) => {
        'message': 'Preference update unavailable',
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: ChannelSettings(
              controller: w,
              channel: channel,
              isPanel: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_mute());
      await tester.pumpAndSettle();
      expect(tester.widget<RaftSwitch>(_mute()).value, false);
      expect(tester.widget<RaftSwitch>(_mute()).onChanged, isNotNull);
      api.statuses['PATCH /channels/c1/notification-settings'] = 200;
      api.routes['PATCH /channels/c1/notification-settings'] = (request) {
        muted = request.data['activityMuted'] as bool;
        return {'activityMuted': muted};
      };
      await tester.tap(_mute());
      await tester.pumpAndSettle();
      expect(muted, true);
      expect(tester.widget<RaftSwitch>(_mute()).value, true);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/notification_level_menu.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'support/joint_channel_fixture.dart' show fixture;

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

// Web v1.24 ChannelPreferencesSection: the Activity mute is the
// Notifications level select's third choice ("Mute").
Finder _mute() =>
    find.byKey(const ValueKey('channel-settings-notification-level-select'));

RaftSettingsSelect<NotificationLevelChoice> _select(WidgetTester t) =>
    t.widget<RaftSettingsSelect<NotificationLevelChoice>>(_mute());

bool _muted(WidgetTester t) => _select(t).value == NotificationLevelChoice.mute;

/// The select's write as the old switch's (on = Mute, off = back to a level).
ValueChanged<bool>? _toggle(WidgetTester t) {
  final changed = _select(t).onChanged;
  return changed == null
      ? null
      : (on) => changed(
          on ? NotificationLevelChoice.mute : NotificationLevelChoice.all,
        );
}

bool _offersMute(WidgetTester t) =>
    _mute().evaluate().isNotEmpty &&
    _select(t).items.any((i) => i.value == NotificationLevelChoice.mute);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} mute round trip waits for API confirmation',
      (tester) async {
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
        api.routes['PATCH /channels/c1/notification-settings'] =
            (request) async {
              if (request.data['activityMuted'] == true) await pending.future;
              muted = request.data['activityMuted'] as bool;
              return {'activityMuted': muted};
            };
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
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
        expect(_muted(tester), false);
        final oldToggle = _toggle(tester)!;
        _toggle(tester)!(true);
        await tester.pump();
        expect(_toggle(tester), isNull);
        expect(_muted(tester), false);
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
        expect(_muted(tester), true);
        _toggle(tester)!(false);
        await tester.pumpAndSettle();
        expect(muted, false);
        expect(_muted(tester), false);
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
      },
    );
  }

  for (final mode in [
    'standalone',
    'dm',
    'not-joined',
    // The wire `activityMuteSupported` flag does not gate the control: Web
    // `canToggleActivityMute` is type in {channel, private, joint} && joined
    // (see field_parity_channels_test.dart).
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
          theme: raftTheme(),
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
      expect(_offersMute(tester), isFalse);
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
          theme: raftTheme(),
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
      final staleToggle = _toggle(tester)!;
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
          theme: raftTheme(),
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
      _toggle(tester)!(true);
      await tester.pumpAndSettle();
      expect(_muted(tester), false);
      expect(_toggle(tester), isNotNull);
      api.statuses['PATCH /channels/c1/notification-settings'] = 200;
      api.routes['PATCH /channels/c1/notification-settings'] = (request) {
        muted = request.data['activityMuted'] as bool;
        return {'activityMuted': muted};
      };
      _toggle(tester)!(true);
      await tester.pumpAndSettle();
      expect(muted, true);
      expect(_muted(tester), true);
      expect(tester.takeException(), isNull);
    },
  );
}

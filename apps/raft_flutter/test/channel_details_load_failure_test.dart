// A failed preference read on channel Details names what failed and offers a
// retry for that read; a read Web does not report stays silent.
//
// Kevin, 2026-11-26 (task #377, screenshot k12748): Details showed only
// "未能完成，请重试。" (raftGenericErrorText) with no retry, and the
// "折叠长消息" row rendered with no switch.
//
// channel_settings.dart load() fans four reads out in parallel and collapsed
// ANY failure into that one sentence. The generic text is only ever reached
// when the error carries no Raft JSON `error` body (user_error.dart:74-90),
// so it told the user nothing and offered no way back. The same failed part
// also skips `known.add(part)`, which leaves its row `pending`: the switch's
// space is reserved and nothing is shown there. The missing toggle and the
// banner were one failed `display` read.
//
// Web names the two preference reads and stays silent on the other two:
//   ChatPanel.tsx:505-514  message.chatPanel.loadMessageDisplayPrefsError
//                          "Failed to load message display settings."
//   ChatPanel.tsx:468-476  message.chatPanel.loadActivityMuteError
//   hooks/useChannelMembers.ts:187-190  logs, empty roster, no banner
//   store/serverStore.ts:826-835        silent default order

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/private_route_guard.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_channel_settings_identity_test.dart'
    show settingsFixture, mountSettingsWorkspace;

const _generic = 'Could not complete that. Try again.';
const _displayFailed = 'Failed to load message display settings.';

void main() {
  testWidgets('a failed display read names itself and retries just that read', (
    t,
  ) async {
    final (w, api) = await settingsFixture(t);
    api.routes['GET /channels/c1/notification-settings'] = (_) => {};
    var fail = true;
    var reads = 0;
    api.routes['GET /channels/c1/message-display-settings'] = (_) {
      reads++;
      if (fail) throw RaftApiException('Boom', status: null);
      return {'collapseLongMessages': true};
    };
    await mountSettingsWorkspace(t, w, false, PrivateRouteGuard());

    expect(find.text(_generic), findsNothing, reason: 'says nothing useful');
    expect(find.text(_displayFailed), findsOneWidget);

    // The row is there but its switch is inert while the value is unknown:
    // `pending` hides it and nulls onChanged (channel_overflow_sheet.dart:903).
    final toggle = find.byKey(
      const ValueKey('channel-settings-collapse-switch'),
    );
    expect(toggle, findsOneWidget);
    expect(
      t.widget<RaftSwitch>(toggle).onChanged,
      isNull,
      reason: 'a failed read leaves the toggle pending and inoperable',
    );

    final before = reads;
    fail = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();

    expect(reads, before + 1, reason: 'the retry re-reads that preference');
    expect(find.text(_displayFailed), findsNothing);
    expect(find.text(_generic), findsNothing);
    // Once it loads, the toggle works and shows the value the server sent.
    expect(t.widget<RaftSwitch>(toggle).onChanged, isNotNull);
    expect(t.widget<RaftSwitch>(toggle).value, isTrue);

    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });

  testWidgets('a failed roster read shows no banner, as Web does', (t) async {
    final (w, api) = await settingsFixture(t);
    api.routes['GET /channels/c1/notification-settings'] = (_) => {};
    api.routes['GET /channels/c1/members'] = (_) =>
        throw RaftApiException('Boom', status: null);
    await mountSettingsWorkspace(t, w, false, PrivateRouteGuard());

    expect(find.text(_generic), findsNothing);
    expect(find.text(_displayFailed), findsNothing);

    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });

  // Found by an adversary review of this change. Web names the read itself
  // whatever the request returned (ChatPanel.tsx:505-514), and renders the
  // two notices independently, both at once (:1919-1946).
  testWidgets('a structured server error still names the read', (t) async {
    final (w, api) = await settingsFixture(t);
    api.routes['GET /channels/c1/notification-settings'] = (_) => {};
    api.routes['GET /channels/c1/message-display-settings'] = (_) =>
        throw RaftApiException.response(
          'Channel preference store unavailable',
          status: 500,
          body: const {'error': 'Channel preference store unavailable'},
        );
    await mountSettingsWorkspace(t, w, false, PrivateRouteGuard());
    expect(find.text(_displayFailed), findsOneWidget);
    expect(find.text('Channel preference store unavailable'), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });

  testWidgets('both failed preference reads are named', (t) async {
    final (w, api) = await settingsFixture(t);
    api.routes['GET /channels/c1/message-display-settings'] = (_) =>
        throw RaftApiException('Boom', status: null);
    api.routes['GET /channels/c1/notification-settings'] = (_) =>
        throw RaftApiException('Boom', status: null);
    await mountSettingsWorkspace(t, w, false, PrivateRouteGuard());
    final banner = find.textContaining(_displayFailed);
    expect(banner, findsOneWidget);
    expect(
      t.widget<Text>(banner).data,
      contains('Failed to load Activity mute setting.'),
      reason: 'the mute read failed and would otherwise be silent',
    );
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
}

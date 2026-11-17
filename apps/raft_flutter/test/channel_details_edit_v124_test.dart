import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;
import 'support/joint_channel_fixture.dart' as joint;

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  Finder key(String value) => find.byKey(ValueKey(value));
  Future<MessageAdapter> open(
    WidgetTester t, {
    String type = 'channel',
    List<Map<String, dynamic>> humans = const [],
  }) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    t.view.physicalSize = const Size(900, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final row = {
      'id': 'c1',
      'name': 'work',
      'description': 'Original description',
      'joined': true,
      'type': type,
      'channelCapabilities': {'editChannelMetadata': true},
    };
    final channel = RaftChannel(row);
    w.channel = channel;
    w.channels = [channel];
    api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': humans,
      'agents': [],
      'externalMembers': [],
    };
    api.routes['GET /servers/s1/sidebar-order'] = (_) => <String, dynamic>{};
    api.routes['GET /channels/c1/notification-settings'] = (_) => {
      'activityMuted': false,
    };
    api.routes['GET /channels/c1/message-display-settings'] = (_) => {
      'collapseLongMessages': true,
    };
    api.routes['PATCH /channels/c1'] = (o) => {...row, ...(o.data as Map)};

    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ChannelSettings(
            controller: w,
            channel: channel,
            isPanel: true,
            details: true,
            onClose: () => throw TestFailure('Details closed unexpectedly'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return api;
  }

  testWidgets('Details places the visibility badge beside the channel name', (
    t,
  ) async {
    await open(t);
    final title = key('channel-overflow-title-text');
    final badge = key('channel-overflow-visibility-badge');
    expect(t.widget<Text>(title).data, 'work');
    expect(t.getTopLeft(badge).dx - t.getTopRight(title).dx, 12);
    expect(t.getCenter(badge).dy, t.getCenter(title).dy);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('inline edit cancels with Escape and saves exactly one field', (
    t,
  ) async {
    final api = await open(t);
    final edit = key('channel-details-edit');
    final name = key('channel-settings-name');
    expect(name, findsNothing);
    await t.tap(edit);
    await t.pumpAndSettle();
    expect(name, findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(name, findsNothing);
    final button = t.widget<RaftButton>(edit);
    expect(button.focusNode?.hasFocus, isTrue);
    await t.tap(edit);
    await t.pumpAndSettle();
    await t.enterText(name, 'renamed');
    await t.pump();
    final from = api.calls.length;
    await t.tap(key('channel-settings-save-inline'));
    await t.pumpAndSettle();
    expect(name, findsNothing);
    expect(find.text('renamed'), findsOneWidget);
    expect(
      api.calls
          .skip(from)
          .map((request) => [request.method, request.path, request.data]),
      [
        [
          'PATCH',
          '/channels/c1',
          {'name': 'renamed'},
        ],
      ],
    );
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'archived rename conflict keeps the draft and names the channel',
    (t) async {
      final (w, api) = (await t.runAsync(joint.fixture))!;
      addTearDown(w.dispose);
      addTearDown(w.client.dispose);
      final channel = RaftChannel({
        'id': 'c1',
        'name': 'work',
        'joined': true,
        'type': 'channel',
        'channelCapabilities': {'editChannelMetadata': true},
      });
      w.channel = channel;
      w.channels = [channel];
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.routes['GET /servers/s1/sidebar-order'] = (_) => <String, dynamic>{};
      api.routes['GET /channels/c1/message-display-settings'] = (_) =>
          <String, dynamic>{};
      api.statuses['PATCH /channels/c1'] = 409;
      api.routes['PATCH /channels/c1'] = (_) => {
        'error': 'Name held',
        'code': 'archived_name_collision',
        'archivedChannelId': 'archived-c1',
        'archivedChannelName': 'held',
        'archivedChannelType': 'channel',
        'canUnarchiveArchivedChannel': false,
      };
      await t.pumpWidget(
        joint.host(
          ChannelSettings(
            controller: w,
            channel: channel,
            isPanel: true,
            details: true,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(key('channel-details-edit'));
      await t.pumpAndSettle();
      final name = key('channel-settings-name');
      await t.enterText(name, 'held');
      await t.pump();
      await t.tap(key('channel-settings-save-inline'));
      await t.pumpAndSettle();
      expect(find.text('held'), findsWidgets);
      expect(key('channel-settings-rename-collision'), findsOneWidget);
      expect(find.text('Open channel'), findsOneWidget);
      expect(find.text('Unarchive'), findsNothing);
      await t.enterText(name, 'other');
      await t.pumpAndSettle();
      expect(key('channel-settings-rename-collision'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final (type, humans, title, message) in [
    (
      'private',
      [
        {'id': 'u1', 'name': 'Ana'},
      ],
      'Leave and delete channel?',
      'You are the last member of this private channel.',
    ),
    (
      'private',
      [
        {'id': 'u1', 'name': 'Ana'},
        {'id': 'u2', 'name': 'Bo'},
      ],
      'Leave channel',
      "a member has to invite you again",
    ),
    (
      'joint',
      <Map<String, dynamic>>[],
      'Leave channel',
      "an admin has to invite you again",
    ),
  ]) {
    testWidgets(
      '$type leave explains what happens with ${humans.length} members',
      (t) async {
        final api = await open(t, type: type, humans: humans);
        final leave = key('channel-overflow-leave');
        expect(t.widget<RaftListRow>(leave).tone, RaftListRowTone.warning);
        await t.ensureVisible(leave);
        await t.pumpAndSettle();
        await t.tap(leave);
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('channel-settings-confirm-dialog')),
          findsOneWidget,
        );
        expect(find.text(title), findsWidgets);
        expect(find.textContaining(message), findsOneWidget);
        expect(
          api.calls.where(
            (request) =>
                request.method == 'POST' && request.path.endsWith('/leave'),
          ),
          isEmpty,
        );
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/channel_roster_invalidations.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture, host;

void main() {
  test(
    'member candidates hide assistants and agents excluded from member lists',
    () {
      final candidates = channelMemberCandidatesFrom(
        [
          {'id': 'visible', 'name': 'Visible'},
          {
            'id': 'assistant',
            'name': 'Assistant',
            'assistantOwnerUserId': 'alice',
          },
          {'id': 'hidden', 'name': 'Hidden', 'inMemberLists': false},
          {'id': 'deleted', 'name': 'Deleted', 'deletedAt': '2026'},
        ],
        const [],
        'alice',
      );
      expect(candidates.map((c) => c.id), ['visible']);
    },
  );

  testWidgets(
    'create picker finds descriptions and ranks exact handles first',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture()))!;
      addTearDown(w.dispose);
      addTearDown(w.client.dispose);
      api.routes['GET /agents'] = (_) => [
        {'id': 'a1', 'name': 'support', 'description': 'Release helper'},
        {'id': 'a2', 'name': 'release'},
      ];
      t.view.physicalSize = const Size(1280, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(CreateChannelDialog(controller: w)));
      await t.pumpAndSettle();
      final picker = find.byType(RaftMemberPickerContent);
      final input = find.descendant(
        of: picker,
        matching: find.byType(TextField),
      );
      await t.enterText(input, '@release');
      await t.pumpAndSettle();
      expect(find.text('release'), findsOneWidget);
      expect(find.text('support'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('release')).dy,
        lessThan(t.getTopLeft(find.text('support')).dy),
      );
      expect(find.text('No matches'), findsNothing);
    },
  );

  testWidgets(
    'managed app agents retain their App label in the member choices',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture()))!;
      addTearDown(w.dispose);
      addTearDown(w.client.dispose);
      api.routes['GET /agents'] = (_) => [
        {
          'id': 'a-app',
          'name': 'helper',
          'displayName': 'Release helper',
          'managedByAppInstallId': 'install-1',
          'managedByApp': {'name': 'Deploy'},
        },
      ];
      t.view.physicalSize = const Size(1280, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(CreateChannelDialog(controller: w)));
      await t.pumpAndSettle();
      expect(find.text('App · Deploy'), findsOneWidget);
      expect(find.text('Release helper'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'sync membership invalidations refresh an open roster only for its channel',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture()))!;
      addTearDown(w.dispose);
      addTearDown(w.client.dispose);
      final channel = RaftChannel({
        'id': 'c1',
        'name': 'work',
        'type': 'channel',
      });
      w.channels = [channel];
      var joined = false;
      var reads = 0;
      api.routes['GET /channels/c1/members'] = (_) {
        reads++;
        return {
          'humans': <dynamic>[],
          'agents': [
            if (joined) {'id': 'a-new', 'name': 'New arrival'},
          ],
        };
      };
      await t.pumpWidget(host(ChannelMembers(controller: w, channel: channel)));
      await t.pumpAndSettle();
      final before = reads;
      ChannelRosterInvalidations.of(w.client).invalidate('other');
      await t.pumpAndSettle();
      expect(reads, before);
      joined = true;
      ChannelRosterInvalidations.of(w.client).invalidate('c1');
      await t.pumpAndSettle();
      expect(find.text('New arrival'), findsOneWidget);
      expect(reads, before + 1);
      joined = false;
      ChannelRosterInvalidations.of(w.client).invalidate('c1');
      await t.pumpAndSettle();
      expect(find.text('New arrival'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  for (final mayRemove in [false, true]) {
    testWidgets('roster removal follows the server row decision $mayRemove', (
      t,
    ) async {
      final (w, api) = (await t.runAsync(() => fixture()))!;
      addTearDown(w.dispose);
      addTearDown(w.client.dispose);
      final channel = RaftChannel({
        'id': 'c1',
        'name': 'work',
        'type': 'channel',
        'serverId': 's1',
        'channelCapabilities': {'removeChannelMembers': true},
      });
      w.channels = [channel];
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [
          {
            'id': 'bob',
            'name': 'Bob',
            'serverId': mayRemove ? 'remote' : 's1',
            'canRemoveFromChannel': mayRemove,
          },
        ],
        'agents': <dynamic>[],
      };
      t.view.physicalSize = const Size(1280, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(ChannelMembers(controller: w, channel: channel)));
      await t.pumpAndSettle();
      final view = t.widget<RaftChannelMembersModal>(
        find.byType(RaftChannelMembersModal),
      );
      expect(view.humans.single.onRemove, mayRemove ? isNotNull : isNull);
    });
  }

  for (final (size, platform) in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('member page searches handles at $size on $platform', (
      t,
    ) async {
      final (w, api) = (await t.runAsync(() => fixture()))!;
      addTearDown(w.dispose);
      addTearDown(w.client.dispose);
      final channel = RaftChannel({
        'id': 'c1',
        'name': 'work',
        'type': 'channel',
      });
      w.channels = [channel];
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [
          {'id': 'bob', 'name': 'robert', 'displayName': 'Bob'},
        ],
        'agents': <dynamic>[],
      };
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(
            body: ChannelMembers(controller: w, channel: channel, page: true),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('member-page-search')),
          matching: find.byType(TextField),
        ),
        'robert',
      );
      await t.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}

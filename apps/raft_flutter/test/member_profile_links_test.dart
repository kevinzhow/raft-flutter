// Web HumanDetailPanel: anybody's uploaded picture opens large, and a created
// agent opens its profile.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, this.profile);
  final Map<String, dynamic> profile;
  final opened = <(RaftProfileKind, String)>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/profile') ? profile : [];
  @override
  void openProfile(
    RaftProfileKind kind,
    String id, {
    String? agentTab,
    String? channelId,
    Map<String, dynamic>? externalAuthor,
  }) => opened.add((kind, id));
}

// A 1x1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xFF,
  0xFF,
  0x3F,
  0x00,
  0x05,
  0xFE,
  0x02,
  0xFE,
  0xA7,
  0x35,
  0x81,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Map<String, dynamic> profile({String? avatarUrl, List<Map>? agents}) => {
  'userId': 'u2',
  'name': 'pat',
  'displayName': 'Pat',
  'role': 'member',
  'membershipStatus': 'active',
  'description': 'About Pat',
  'gravatarHash': '',
  'avatarUrl': ?avatarUrl,
  'createdAgents': agents ?? <Map>[],
};

void main() {
  final fetched = <String>[];
  setUp(() {
    fetched.clear();
    RaftImageBytes.instance = RaftImageBytes(
      fetcher: (url) async {
        fetched.add(url);
        return RaftFetchedImage(_png);
      },
    );
  });
  tearDown(() => RaftImageBytes.instance = RaftImageBytes());

  Future<_Workspace> open(
    WidgetTester t,
    Map<String, dynamic> p, {
    void Function(String)? onOpenAgent,
  }) async {
    t.view.physicalSize = const Size(900, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final client = _Client()..user = RaftRecord({'id': 'me'});
    client.selectServer('s1');
    final w = _Workspace(client, p)
      ..server = RaftRecord({'id': 's1', 'role': 'member'});
    addTearDown(w.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: MemberProfileView(
            controller: w,
            userId: 'u2',
            onClose: () {},
            onOpenAgent: onOpenAgent,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return w;
  }

  Finder trigger() =>
      find.byKey(const ValueKey('agent-profile-avatar-trigger'));

  testWidgets("someone else's uploaded picture opens large", (t) async {
    await open(t, profile(avatarUrl: '/api/avatars/users/abc123.webp'));
    expect(trigger(), findsOneWidget);
    expect(find.bySemanticsLabel('View avatar'), findsWidgets);
    await t.tap(trigger());
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
    expect(fetched, ['https://fixture.test/api/avatars/users/abc123.webp']);
    expect(find.byType(RaftAttachmentLightbox), findsOneWidget);
    expect(find.text('Pat'), findsWidgets);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(RaftAttachmentLightbox), findsNothing);
  });

  testWidgets('no uploaded picture: nothing to enlarge', (t) async {
    await open(t, profile());
    expect(trigger(), findsNothing);
    await open(t, profile(avatarUrl: 'https://www.gravatar.com/avatar/x'));
    expect(trigger(), findsNothing);
  });

  testWidgets('a created agent opens its profile through the host', (t) async {
    final opened = <String>[];
    await open(
      t,
      profile(
        agents: [
          {
            'id': 'a1',
            'name': 'helper',
            'displayName': 'Helper',
            'runtime': 'codex',
          },
          {
            'id': 'a2',
            'name': 'scout',
            'displayName': 'Scout',
            'runtime': 'codex',
          },
        ],
      ),
      onOpenAgent: opened.add,
    );
    await t.tap(find.byKey(const ValueKey('created-agent-a2')));
    await t.pump();
    expect(opened, ['a2']);
  });

  testWidgets('without a host the workspace opens the agent profile', (
    t,
  ) async {
    final w = await open(
      t,
      profile(
        agents: [
          {
            'id': 'a1',
            'name': 'helper',
            'displayName': 'Helper',
            'runtime': 'codex',
          },
        ],
      ),
    );
    await t.tap(find.byKey(const ValueKey('created-agent-a1')));
    await t.pump();
    expect(w.opened, [(RaftProfileKind.agent, 'a1')]);
  });
}

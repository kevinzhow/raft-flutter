// Web HumanDetailPanel: in your own member profile the picture uploads from
// the avatar and the description edits in place; nobody else's profile does.

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_ui/raft_ui.dart';

const _server = 'server-1';

class _Picker extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile.fromData(
    Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]),
    name: 'me.png',
    path: 'me.png',
    mimeType: 'image/png',
  );
}

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final patches = <(String, Object?)>[];
  final posts = <String>[];
  Object? avatarFailure;
  int reloads = 0;

  @override
  Future<dynamic> patch(String path, {dynamic data}) async {
    patches.add((path, data));
    return {};
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    posts.add(path);
    if (avatarFailure != null) throw avatarFailure!;
    return {};
  }

  @override
  Future<void> reloadUser() async => reloads++;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, this.profile);
  final Map<String, dynamic> profile;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/profile') ? profile : [];
}

Map<String, dynamic> _profile(String id, {String status = 'active'}) => {
  'userId': id,
  'name': '${id}_handle',
  'displayName': 'Person $id',
  'role': 'member',
  'membershipStatus': status,
  'description': 'About $id',
  'gravatarHash': '',
};

Future<_Client> _open(WidgetTester t, Map<String, dynamic> profile) async {
  FileSelectorPlatform.instance = _Picker();
  t.view
    ..physicalSize = const Size(900, 1400)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = _Client()..user = RaftRecord({'id': 'me'});
  client.selectServer(_server);
  final w = _Workspace(client, profile)
    ..server = RaftRecord({'id': _server, 'role': 'member'});
  addTearDown(w.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: MemberProfileView(
          controller: w,
          userId: profile['userId'] as String,
          onClose: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return client;
}

/// The desktop file picker, not the phone's photo picker.
void testDesktop(String name, Future<void> Function(WidgetTester t) body) =>
    testWidgets(name, (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body(t);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

void main() {
  testDesktop('your own profile offers the picture and the description', (
    t,
  ) async {
    await _open(t, _profile('me'));
    expect(find.byTooltip('Upload image'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('member-edit-description')),
      findsOneWidget,
    );
  });

  testDesktop('somebody else\'s, or a departed membership, offers neither', (
    t,
  ) async {
    await _open(t, _profile('other'));
    expect(find.byTooltip('Upload image'), findsNothing);
    expect(find.byKey(const ValueKey('member-edit-description')), findsNothing);
  });

  testDesktop('you after leaving the server cannot edit either', (t) async {
    await _open(t, _profile('me', status: 'left'));
    expect(find.byTooltip('Upload image'), findsNothing);
    expect(find.byKey(const ValueKey('member-edit-description')), findsNothing);
  });

  testDesktop('saving the description patches the account and clears blanks', (
    t,
  ) async {
    final client = await _open(t, _profile('me'));
    await t.tap(find.byKey(const ValueKey('member-edit-description')));
    await t.pumpAndSettle();
    expect(find.text('Edit description'), findsWidgets);
    await t.enterText(find.byType(EditableText).last, '  New words  ');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(client.patches.map((p) => p.$1), ['/auth/me']);
    expect((client.patches.single.$2 as Map)['description'], 'New words');
    expect(client.reloads, 1);

    await t.tap(find.byKey(const ValueKey('member-edit-description')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(EditableText).last, '   ');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(client.patches, hasLength(2));
    expect((client.patches.last.$2 as Map).containsKey('description'), true);
    expect((client.patches.last.$2 as Map)['description'], isNull);
  });

  testDesktop('a description over 3000 characters is refused before sending', (
    t,
  ) async {
    final client = await _open(t, _profile('me'));
    await t.tap(find.byKey(const ValueKey('member-edit-description')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(EditableText).last, 'x' * 3001);
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(
      find.text('Description must be 3000 characters or fewer.'),
      findsOneWidget,
    );
    expect(client.patches, isEmpty);
  });

  testDesktop('tapping the picture uploads the chosen image', (t) async {
    final client = await _open(t, _profile('me'));
    await t.tap(find.byTooltip('Upload image'));
    await t.pumpAndSettle();
    expect(client.posts, ['/auth/me/avatar']);
    expect(client.reloads, 1, reason: 'the account is re-read');
    expect(find.byKey(const ValueKey('member-avatar-error')), findsNothing);
  });

  testDesktop('a failed upload says so under the identity', (t) async {
    final client = await _open(t, _profile('me'));
    client.avatarFailure = const RaftApiException('nope');
    await t.tap(find.byTooltip('Upload image'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<RaftCssText>(
            find.byKey(const ValueKey('member-avatar-error')),
          )
          .data,
      'Failed to upload avatar',
    );
  });
}

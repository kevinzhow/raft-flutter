// Web HumanDetailPanel: in your own member profile the picture uploads from
// the avatar and the description edits in place; nobody else's profile does.

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show anyX;
import 'support/close_support.dart';
import 'support/close_surface.dart';

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
  void Function(String path, Object? data)? onPatch;
  Object? avatarFailure;
  int reloads = 0;

  @override
  Future<dynamic> patch(String path, {dynamic data}) async {
    patches.add((path, data));
    onPatch?.call(path, data);
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
  _Workspace(super.client, this.profile, this.computers);
  final Map<String, dynamic> profile;
  final int computers;
  @override
  Future<dynamic> command(String method, String path, {dynamic data}) {
    if (method == 'PATCH') return client.patch(path, data: data);
    return super.command(method, path, data: data);
  }

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/profile')) return profile;
    if (path.endsWith('/removal-impact')) {
      return {
        'computers': computers,
        'computerNames': [if (computers > 0) 'Dev box'],
      };
    }
    if (path.endsWith('/members')) return [profile, _anotherOwner];
    return [];
  }
}

const _anotherOwner = {
  'id': 'another-owner',
  'userId': 'another-owner',
  'name': 'Another Owner',
  'role': 'owner',
};

Map<String, dynamic> _profile(String id, {String status = 'active'}) => {
  'userId': id,
  'name': '${id}_handle',
  'displayName': 'Person $id',
  'role': 'member',
  'membershipStatus': status,
  'description': 'About $id',
  'gravatarHash': '',
};

Future<_Client> _open(
  WidgetTester t,
  Map<String, dynamic> profile, {
  String role = 'member',
  int computers = 0,
  bool seedOwners = false,
  Size size = const Size(900, 1400),
  TargetPlatform? platform,
}) async {
  FileSelectorPlatform.instance = _Picker();
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = _Client()
    ..user = RaftRecord({'id': 'me'})
    ..onPatch = (path, data) {
      if (path == '/servers/$_server/members/${profile['userId']}') {
        profile['role'] = (data as Map)['role'];
      }
    };
  client.selectServer(_server);
  final w = _Workspace(client, profile, computers)
    ..server = RaftRecord({'id': _server, 'role': role});
  addTearDown(w.dispose);
  if (seedOwners) {
    await w.entityDirectory.refresh(WorkspaceEntityKind.members);
  }
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: RaftToastHost(
        child: Scaffold(
          body: MemberProfileView(
            controller: w,
            userId: profile['userId'] as String,
            onClose: () {},
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return client;
}

Future<void> _selectRole(WidgetTester t, String label) async {
  await t.tap(find.byKey(const ValueKey('member-edit-role')));
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

Future<SurfaceProbe> openRoleConfirmation(
  WidgetTester tester,
  Size size, {
  required bool self,
}) async {
  final profile = _profile(self ? 'me' : 'other');
  if (self) profile['role'] = 'owner';
  await _open(
    tester,
    profile,
    role: 'owner',
    computers: 1,
    seedOwners: self,
    size: size,
    platform: closePlatform(size),
  );
  await _selectRole(tester, self ? 'Admin' : 'Owner');
  final key = self ? 'human-self-demote-dialog' : 'human-owner-grant-dialog';
  final dialog = find.byKey(ValueKey(key));
  return SurfaceProbe(
    isOpen: () => dialog.evaluate().isNotEmpty,
    x: find.descendant(of: dialog, matching: anyX),
    scrim: const Offset(6, 6),
  );
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
    expect(
      find.byKey(const ValueKey('human-detail-avatar-edit')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('member-edit-description')),
      findsOneWidget,
    );
  });

  testDesktop('somebody else\'s, or a departed membership, offers neither', (
    t,
  ) async {
    await _open(t, _profile('other'));
    expect(
      find.byKey(const ValueKey('human-detail-avatar-edit')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('member-edit-description')), findsNothing);
  });

  testDesktop('you after leaving the server cannot edit either', (t) async {
    await _open(t, _profile('me', status: 'left'));
    expect(
      find.byKey(const ValueKey('human-detail-avatar-edit')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('member-edit-description')), findsNothing);
  });

  testDesktop('saving the description patches the account and clears blanks', (
    t,
  ) async {
    final client = await _open(t, _profile('me'));
    await t.tap(find.byKey(const ValueKey('member-edit-description')));
    await t.pumpAndSettle();
    expect(find.text('Edit Description'), findsWidgets);
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

  testDesktop('the description draft uses the current account profile', (
    t,
  ) async {
    final profile = _profile('me');
    await _open(t, profile);
    profile['description'] = 'Changed elsewhere';
    await t.tap(find.byKey(const ValueKey('member-edit-description')));
    await t.pumpAndSettle();
    expect(
      t.widget<EditableText>(find.byType(EditableText).last).controller.text,
      'Changed elsewhere',
    );
  });

  testDesktop('the role editor selects the current server role', (t) async {
    final profile = _profile('other');
    await _open(t, profile, role: 'owner');
    profile['role'] = 'admin';
    await t.tap(find.byKey(const ValueKey('member-edit-role')));
    await t.pumpAndSettle();
    expect(
      t
          .widget<RaftInlineBadgeEditor>(find.byType(RaftInlineBadgeEditor))
          .selectedId,
      'admin',
    );
  });

  testDesktop('role undo restores the prior role and consumes the action', (
    t,
  ) async {
    final profile = _profile('other');
    final client = await _open(t, profile, role: 'owner');
    expect(find.text('Undo'), findsNothing);
    await _selectRole(t, 'Admin');
    expect(client.patches.single.$2, {'role': 'admin'});
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(client.patches.last.$2, {'role': 'member'});
    expect(find.text('Undo'), findsNothing);
    expect(profile['role'], 'member');
  });

  testDesktop('role undo leaves a subsequent role change in place', (t) async {
    final profile = _profile('other');
    final client = await _open(t, profile, role: 'owner');
    await _selectRole(t, 'Admin');
    expect(client.patches.single.$2, {'role': 'admin'});
    profile['role'] = 'owner';
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(client.patches, hasLength(1));
    expect(
      find.text(
        "Person other's role has changed since, so it wasn't changed back",
      ),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsNothing);
  });

  testDesktop('owner grant confirms when your computers are attached', (
    t,
  ) async {
    final client = await _open(
      t,
      _profile('other'),
      role: 'owner',
      computers: 1,
    );
    await _selectRole(t, 'Owner');
    final confirm = find.byKey(const ValueKey('human-owner-grant-confirm'));
    expect(confirm, findsOneWidget);
    expect(find.textContaining('Dev box'), findsOneWidget);
    expect(client.patches, isEmpty);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(client.patches, isEmpty);
    await _selectRole(t, 'Owner');
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(client.patches.single.$2, {'role': 'owner'});
    expect(find.text('Undo'), findsOneWidget);
  });

  testDesktop('stepping down asks first and offers no undo', (t) async {
    final profile = _profile('me')..['role'] = 'owner';
    final client = await _open(
      t,
      profile,
      role: 'owner',
      computers: 1,
      seedOwners: true,
    );
    await _selectRole(t, 'Admin');
    final confirm = find.byKey(const ValueKey('human-self-demote-confirm'));
    expect(confirm, findsOneWidget);
    expect(find.textContaining('Dev box'), findsOneWidget);
    expect(client.patches, isEmpty);
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(client.patches.single.$2, {'role': 'admin'});
    expect(find.text('Undo'), findsNothing);
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

  testDesktop('Upload a photo from the avatar menu uploads the chosen image', (
    t,
  ) async {
    final client = await _open(t, _profile('me'));
    await t.tap(find.byKey(const ValueKey('human-detail-avatar-edit')));
    await t.pumpAndSettle();
    await t.tap(find.text('Upload a photo'));
    await t.pumpAndSettle();
    expect(client.posts, ['/auth/me/avatar']);
    expect(client.reloads, 1, reason: 'the account is re-read');
    expect(find.byKey(const ValueKey('member-avatar-error')), findsNothing);
  });

  testDesktop('a failed upload says so under the identity', (t) async {
    final client = await _open(t, _profile('me'));
    client.avatarFailure = const RaftApiException('nope');
    await t.tap(find.byKey(const ValueKey('human-detail-avatar-edit')));
    await t.pumpAndSettle();
    await t.tap(find.text('Upload a photo'));
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

import 'dart:async';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_settings.dart';
import 'package:raft_flutter/features/human_avatar_builder_dialog.dart';
import 'package:raft_flutter/features/human_avatar_edit_menu.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart' show loadParityFonts;

/// Web `HumanAvatarEditMenu` in Settings > Account (C17, C19): the avatar is
/// the menu trigger (pencil veil, "Change avatar" / "Uploading avatar"), the
/// menu offers "Upload a photo" and, with `human_avatar_builder_v0` on,
/// "Build an avatar"; there is no Remove Profile Image.
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
  _Client({String? avatar})
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({
      'id': 'me',
      'name': 'ada',
      'displayName': 'Ada',
      'email': 'ada@example.invalid',
      'emailVerified': true,
      'avatarUrl': ?avatar,
    });
  }
  final calls = <String>[];
  bool builderFlag = false;
  Completer<void>? uploadGate;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    calls.add('$method $path');
    if (path == '/feature-flags/evaluate') {
      return {
        'evaluations': [
          {'key': 'human_avatar_builder_v0', 'enabled': builderFlag},
        ],
      };
    }
    if (path == '/auth/me/avatar') {
      await uploadGate?.future;
      return {};
    }
    if (path == '/auth/identities') {
      return {'identities': [], 'passwordConfigured': true};
    }
    return method == 'GET' ? <String, dynamic>{} : {};
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) =>
      request('POST', path, data: data);

  @override
  Future<void> reloadUser() async => calls.add('reloadUser');
}

/// The desktop file picker, not the phone's photo picker.
void testDesktop(String name, Future<void> Function(WidgetTester t) body) =>
    testWidgets(name, (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final semantics = t.ensureSemantics();
      try {
        await body(t);
      } finally {
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });

void main() {
  setUpAll(loadParityFonts);
  Future<(_Client, WorkspaceController)> open(
    WidgetTester t, {
    String? avatar,
    bool flag = false,
    Size size = const Size(1000, 1800),
  }) async {
    FileSelectorPlatform.instance = _Picker();
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final client = _Client(avatar: avatar)..builderFlag = flag;
    client.selectServer('s1');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'name': 'Team', 'role': 'owner'});
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: AccountSettings(controller: w)),
        ),
      ),
    );
    await t.pumpAndSettle();
    return (client, w);
  }

  final trigger = find.byKey(const Key('account-profile-image'));
  SemanticsNode button(WidgetTester t) => t.getSemantics(
    find.descendant(of: trigger, matching: find.byType(RaftInteractive)).first,
  );

  testDesktop(
    'the avatar is a menu: Upload a photo only while the flag is off',
    (t) async {
      final (client, _) = await open(t, avatar: '/api/avatars/users/a1.webp');
      expect(button(t).label, 'Change avatar');
      expect(button(t).flagsCollection.isButton, isTrue);
      await t.tap(trigger);
      await t.pumpAndSettle();
      expect(find.text('Upload a photo'), findsOneWidget);
      expect(find.text('Build an avatar'), findsNothing);
      expect(client.calls, isNot(contains('POST /auth/me/avatar')));
    },
  );

  testDesktop('with the flag on the menu also offers Build an avatar', (
    t,
  ) async {
    final (client, _) = await open(t, flag: true);
    expect(
      client.calls.where((c) => c == 'POST /feature-flags/evaluate'),
      hasLength(1),
    );
    await t.tap(trigger);
    await t.pumpAndSettle();
    expect(find.text('Upload a photo'), findsOneWidget);
    expect(find.text('Build an avatar'), findsOneWidget);
    await t.tap(find.text('Build an avatar'));
    await t.pumpAndSettle();
    expect(find.byType(HumanAvatarBuilderDialog), findsOneWidget);
  });

  testDesktop('Upload a photo runs the picker and the upload', (t) async {
    final (client, _) = await open(t);
    await t.tap(trigger);
    await t.pumpAndSettle();
    await t.tap(find.text('Upload a photo'));
    await t.pumpAndSettle();
    expect(client.calls.where((c) => c.contains('/auth/me/avatar')), [
      'POST /auth/me/avatar',
    ]);
  });

  testDesktop(
    'while a photo uploads the avatar says Uploading avatar and the menu is off',
    (t) async {
      final (client, _) = await open(t);
      client.uploadGate = Completer<void>();
      await t.tap(trigger);
      await t.pumpAndSettle();
      await t.tap(find.text('Upload a photo'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(button(t).label, 'Uploading avatar');
      await t.tap(trigger, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.text('Upload a photo'), findsNothing);
      client.uploadGate!.complete();
      await t.pumpAndSettle();
      expect(button(t).label, 'Change avatar');
    },
  );

  testDesktop('there is no Remove Profile Image, even with a stored avatar', (
    t,
  ) async {
    await open(t, avatar: '/api/avatars/users/a1.webp');
    expect(find.text('Remove Profile Image'), findsNothing);
    expect(find.text('Keep Image'), findsNothing);
    await open(t, avatar: 'pixel-human:v1:sky.3.curly.brown.grin.cap.none');
    expect(find.text('Remove Profile Image'), findsNothing);
  });

  testDesktop('a built avatar is drawn in the account card', (t) async {
    await open(t, avatar: 'pixel-human:v1:sky.3.curly.brown.grin.cap.none');
    expect(find.byType(RaftHumanPixelAvatar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('account-profile-avatar')),
        matching: find.byType(RaftHumanPixelAvatar),
      ),
      findsOneWidget,
    );
  });

  testDesktop('without a current server the menu has no Build an avatar', (
    t,
  ) async {
    final client = _Client()..builderFlag = true;
    addTearDown(client.dispose);
    t.view
      ..physicalSize = const Size(600, 400)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Center(
            child: HumanAvatarEditMenu(
              key: const Key('menu'),
              client: client,
              avatarUrl: null,
              avatar: const SizedBox.square(dimension: 56),
              onUpload: () {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(client.calls, isNot(contains('POST /feature-flags/evaluate')));
    await t.tap(find.byKey(const Key('menu')));
    await t.pumpAndSettle();
    expect(find.text('Upload a photo'), findsOneWidget);
    expect(find.text('Build an avatar'), findsNothing);
  });
}

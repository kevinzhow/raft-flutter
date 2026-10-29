import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_onboarding.dart'
    show PickedAvatar;
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_shell_contract_test.dart' show retire;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;
import 'support/app_services_fixture.dart';

/// Web server avatar: `POST /servers/:id/avatar` (multipart `avatar`), then the
/// response's `avatarUrl` is upserted into the server rows.
class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final writes = <(String, String, dynamic)>[];
  Iterable<(String, String, dynamic)> get avatar =>
      writes.where((w) => w.$2.endsWith('/avatar'));
  Object? Function(String method, String path)? answer;
  @override
  void connect() {}
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
    writes.add((method, path, data));
    final result = answer?.call(method, path);
    if (result is Future) return await result;
    return result;
  }
}

const _avatar = '/api/avatars/server-s/0123abcd.webp';

PickedAvatar _png() => PickedAvatar(
  'logo.png',
  Uint8List.fromList(const [137, 80, 78, 71]),
  'image/png',
);

void main() {
  late _Client client;
  late WorkspaceController w;
  Future<PickedAvatar?> Function(RaftClient)? pick;

  setUp(() {
    client = _Client()..user = RaftRecord({'id': 'owner'});
    client.selectServer('s');
    final row = RaftRecord({
      'id': 's',
      'name': 'Moon',
      'slug': 'moon',
      'role': 'owner',
    });
    w = WorkspaceController(client)
      ..servers = [row]
      ..server = row;
    pick = (_) async => _png();
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<void> mount(
    WidgetTester t, {
    Locale locale = const Locale('en'),
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1000, 900);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: w,
            builder: (_, _) =>
                ServerSettingsView(controller: w, pickAvatar: (c) => pick!(c)),
          ),
        ),
      ),
    );
    await t.pump();
  }

  RaftServerProfileTile tile(WidgetTester t) => t.widget<RaftServerProfileTile>(
    find.byKey(const Key('server-profile-avatar')),
  );
  final error = find.byKey(const Key('server-profile-avatar-error'));
  Future<void> tapAvatar(WidgetTester t) async {
    await t.tap(find.byKey(const Key('server-profile-avatar')));
    await t.pump();
  }

  testWidgets('an owner sees the upload control, a member does not', (t) async {
    final semantics = t.ensureSemantics();
    await mount(t);
    expect(tile(t).onUpload, isNotNull);
    expect(tile(t).imageUrl, isNull);
    expect(find.bySemanticsLabel('Upload image'), findsOneWidget);
    w.server = RaftRecord({...w.server!.json, 'role': 'member'});
    w.notifyListeners();
    await t.pump();
    expect(tile(t).onUpload, isNull);
    expect(find.bySemanticsLabel('Upload image'), findsNothing);
    await tapAvatar(t);
    expect(client.avatar, isEmpty);
    w.server = RaftRecord({...w.server!.json, 'role': 'admin'});
    w.notifyListeners();
    await t.pump();
    expect(tile(t).onUpload, isNotNull);
    semantics.dispose();
  });

  testWidgets('pick uploads multipart to the server and updates the rows', (
    t,
  ) async {
    client.answer = (_, _) => {'id': 's', 'name': 'Moon', 'avatarUrl': _avatar};
    await mount(t);
    await tapAvatar(t);
    await t.pump();
    expect(client.avatar, hasLength(1));
    final (method, path, data) = client.avatar.single;
    expect((method, path), ('POST', '/servers/s/avatar'));
    final form = data as FormData;
    expect(form.files.single.key, 'avatar');
    expect(form.files.single.value.filename, 'logo.png');
    expect(form.files.single.value.contentType?.mimeType, 'image/png');
    expect(w.server!.json['avatarUrl'], _avatar);
    expect(w.servers.single.json['avatarUrl'], _avatar);
    expect(tile(t).imageUrl, 'https://fixture.test$_avatar');
    expect(tile(t).busy, false);
    expect(error, findsNothing);
  });

  testWidgets('cancelling the picker uploads nothing', (t) async {
    pick = (_) async => null;
    await mount(t);
    await tapAvatar(t);
    await t.pump();
    expect(client.avatar, isEmpty);
    expect(tile(t).busy, false);
    expect(error, findsNothing);
  });

  testWidgets('the tile is busy while uploading and ignores a second tap', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    final hold = Completer<Object?>();
    client.answer = (_, _) => hold.future;
    await mount(t);
    await tapAvatar(t);
    await t.pump();
    expect(tile(t).busy, true);
    expect(find.bySemanticsLabel('Uploading avatar'), findsOneWidget);
    await tapAvatar(t);
    expect(client.avatar, hasLength(1));
    hold.complete({'avatarUrl': _avatar});
    await t.pump();
    await t.pump();
    expect(tile(t).busy, false);
    expect(tile(t).imageUrl, 'https://fixture.test$_avatar');
    semantics.dispose();
  });

  testWidgets('a too-large file shows the size error and never uploads', (
    t,
  ) async {
    pick = (_) async =>
        throw const RaftUserError('Avatar image must be 5 MB or smaller');
    await mount(t);
    await tapAvatar(t);
    await t.pump();
    expect(find.text('Avatar image must be 5 MB or smaller'), findsOneWidget);
    expect(client.avatar, isEmpty);
    expect(tile(t).busy, false);
  });

  testWidgets('the too-large error is localized for zh users', (t) async {
    pick = (_) async =>
        throw const RaftUserError('Avatar image must be 5 MB or smaller');
    await mount(t, locale: const Locale('zh', 'CN'));
    await tapAvatar(t);
    await t.pump();
    expect(find.text('头像图片不能超过 5 MB'), findsOneWidget);
  });

  testWidgets('a failed upload shows the server error and clears on retry', (
    t,
  ) async {
    var fail = true;
    client.answer = (_, _) {
      if (fail) {
        throw RaftApiException.response(
          'Only server owners and admins can edit the server profile',
          status: 403,
          body: {
            'error':
                'Only server owners and admins can edit the server profile',
          },
        );
      }
      return {'avatarUrl': _avatar};
    };
    await mount(t);
    await tapAvatar(t);
    await t.pump();
    expect(
      find.text('Only server owners and admins can edit the server profile'),
      findsOneWidget,
    );
    expect(w.server!.json['avatarUrl'], isNull);
    fail = false;
    await tapAvatar(t);
    // The retry clears the notice as soon as it starts.
    expect(error, findsNothing);
    await t.pump();
    expect(error, findsNothing);
    expect(w.server!.json['avatarUrl'], _avatar);
  });

  testWidgets('a generic failure falls back to the Web upload copy', (t) async {
    client.answer = (_, _) => throw StateError('boom');
    await mount(t);
    await tapAvatar(t);
    await t.pump();
    expect(find.text('Failed to upload server avatar'), findsOneWidget);
  });

  testWidgets('the notice goes away when the permission is lost', (t) async {
    pick = (_) async =>
        throw const RaftUserError('Avatar image must be 5 MB or smaller');
    await mount(t);
    await tapAvatar(t);
    await t.pump();
    expect(error, findsOneWidget);
    w.server = RaftRecord({...w.server!.json, 'role': 'member'});
    w.notifyListeners();
    await t.pump();
    expect(error, findsNothing);
  });

  testWidgets('the rail and the switcher show the new avatar without refresh', (
    t,
  ) async {
    final (wf, api) = await pageFixture(t, section: 'chat');
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /servers/unread-summary'] = (_) => [];
    wf.servers = [wf.server!];
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: withAppServices(
          WorkspaceView(
            controller: wf,
            appearance: RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
            onChooseServer: () {},
          ),
        ),
      ),
    );
    await frames(t, () {});
    await t.pumpAndSettle();
    RaftServerSwitcher switcher() =>
        t.widget<RaftServerSwitcher>(find.byType(RaftServerSwitcher));
    expect(switcher().workspaceAvatarUrl, isNull);
    wf.applyServerAvatar('s1', '/api/avatars/server-s1/abc.webp');
    await frames(t, () {});
    const url = 'https://example.invalid/api/avatars/server-s1/abc.webp';
    expect(switcher().workspaceAvatarUrl, url);
    expect(switcher().rows.single.avatarUrl, url);
    await retire(t);
  });
}

// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the
// account-level announcement modal. Ids
// `components.announcements.<platform>.<kind>.<theme>`, dispatched on
// props.ann like tool/parity-ext/host/AnnouncementCases.tsx.
//
// Mounts the real [AnnouncementHost] over a white page: the fixture client
// answers `GET /announcements/active` with the case's announcement
// (fixtures/announcements.json) and the server setup projection with
// `phase: null`, so the host presents it exactly as on workspace entry.
// Element cases crop `capture.androidKey` (the card); overlay cases capture
// the viewport. A picture is served from tool/parity-ext/fixtures through
// `HttpOverrides`.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/announcement_host.dart';

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

const _pictureFile = '../../tool/parity-ext/fixtures/announcement-picture.png';

/// Every HTTP client answers picture requests with the fixture PNG (the React
/// side serves the same file on `GET /api/announcements/images/:id`).
class _PictureOverrides extends HttpOverrides {
  _PictureOverrides(this.bytes);
  final Uint8List bytes;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _PictureClient(bytes);
}

class _PictureClient implements HttpClient {
  _PictureClient(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PictureRequest(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PictureRequest implements HttpClientRequest {
  _PictureRequest(this.bytes);
  final Uint8List bytes;
  @override
  HttpHeaders get headers => _NoHeaders();
  @override
  Future<HttpClientResponse> close() async => _PictureResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PictureResponse extends Stream<List<int>> implements HttpClientResponse {
  _PictureResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

WorkspaceController _workspace(ParityContext ctx) {
  final fx = ctx.fixtures['ext:announcements'] as Map<String, dynamic>;
  final announcement =
      (fx['announcements'] as Map)[ctx.props['ann']] as Map<String, dynamic>;
  final sidebar = ctx.props['sidebar'] == '1';
  final wire = ScreenWire(ctx.fixtureData);
  final serverId = wire.server()['id'] as String;
  final client = ScreenFixtureClient(
    (method, path, query) => switch ((method, path)) {
      ('GET', '/announcements/active') => {
        'announcements': [
          if (sidebar) ...[
            {...announcement, 'displayMode': 'sidebar'},
            {...announcement, 'id': 'next', 'displayMode': 'sidebar'},
          ] else
            announcement,
        ],
      },
      ('GET', _) when path == '/servers/$serverId/setup-projection' => {
        'phase': null,
      },
      _ => wire.common(method, path, query),
    },
    user: wire.me(),
    server: serverId,
  );
  final w = WorkspaceController(client);
  addTearDown(w.dispose);
  final server = RaftRecord(wire.server());
  w
    ..servers = [server]
    ..server = server;
  return w;
}

ParityCase _case() => ParityCase(
  widgets: const [
    'raft_ui:RaftAnnouncementModal',
    'raft_ui:RaftAnnouncementCard',
    'raft_ui:RaftAnnouncementMarkdown',
  ],
  notes: 'Extension suite (not official).',
  settle: const Duration(milliseconds: 300),
  // The announcement is read, the dialog route pushed and faded in (150 ms)
  // over several frames; a picture decodes off the test clock.
  interact: (WidgetTester t, ParityContext ctx) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pump(const Duration(milliseconds: 50));
    if ((ctx.props['extCase'] as String).endsWith('.expanded')) {
      await t.tap(find.byKey(const Key('announcement-picture-zoom')));
      for (var frame = 0; frame < 6; frame++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }
    final image = find.descendant(
      of: find.byKey(const Key('announcement-picture')),
      matching: find.byType(Image),
    );
    if (image.evaluate().isNotEmpty) {
      final element = t.element(image);
      await t.runAsync(() async {
        await precacheImage(
          (element.widget as Image).image,
          element,
          onError: (error, stack) =>
              Error.throwWithStackTrace(error, stack ?? StackTrace.current),
        ).timeout(const Duration(seconds: 5));
      });
      await t.pump();
    }
  },
  build: (ctx) {
    final picture = File(_pictureFile).readAsBytesSync();
    final previous = HttpOverrides.current;
    HttpOverrides.global = _PictureOverrides(picture);
    addTearDown(() => HttpOverrides.global = previous);
    return AnnouncementHost(
      controller: _workspace(ctx),
      deployment: 'production',
      preferSidebar: ctx.props['sidebar'] == '1',
      child: const SizedBox.expand(
        child: ColoredBox(
          color: Colors.white,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 268, child: AnnouncementSidebarSlot()),
          ),
        ),
      ),
    );
  },
);

const _kinds = {
  'desktop': [
    'single',
    'cta',
    'cta-long',
    'image',
    'image-only',
    'multi',
    'rich',
    'long',
    'long-title',
    'overlay',
    'sidebar',
    'expanded',
  ],
  'mobile': ['single', 'cta', 'cta-long', 'image', 'rich', 'long', 'overlay'],
};

/// Every extension announcement case, keyed by id (3 themes each).
final Map<String, ParityCase> extAnnouncementCases = {
  for (final MapEntry(key: platform, value: kinds) in _kinds.entries)
    for (final kind in kinds)
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.announcements.$platform.$kind.$theme': _case(),
};

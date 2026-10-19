import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/app_root_router.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'message_context_transition_test.dart' show row;
import 'task_surface_test.dart' show flush;
import 'support/app_services_fixture.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/enabled')) return {'enabled': true};
    if (path.endsWith('/preview')) {
      return {
        'status': 'ok',
        'data': {'kind': 'text', 'text': 'Fixture document'},
      };
    }
    return {'url': 'https://example.invalid/public-fixture'};
  }
}

class _Files extends AttachmentFiles {
  @override
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int, int)? onProgress,
  }) async => throw StateError('Fixture image unavailable');
}

class _Routes extends NavigatorObserver {
  Route<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      latest = route;
}

void main() {
  _narrowDesktopTests();
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    for (final dm in [false, true]) {
      testWidgets(
        'Attachment predictive back preserves message history $family/$dark DM=$dm',
        (t) async {
          t.view.physicalSize = const Size(390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await pageFixture(t, section: 'chat');
          if (dm) {
            w.channel = RaftChannel({
              ...w.channel!.json,
              'type': 'dm',
              'peerName': 'bob',
              'peerDisplayName': 'Bob',
            });
            w.channels = [];
            w.dms = [w.channel!];
          }
          w.navigation.navigate(
            RaftLocation.at(serverSlug: 'demo', route: RaftRoute.home),
          );
          w.navigation.navigate(
            RaftLocation.at(
              serverSlug: 'demo',
              route: dm ? RaftRoute.dm : RaftRoute.channel,
              entityId: 'c1',
            ),
          );
          w.messageDomain.ledger.ingest([
            {
              ...row('attachment-message', 'c1', 1),
              'attachments': [
                {
                  'id': 'preview-attachment',
                  'filename': 'research.md',
                  'mimeType': 'text/markdown',
                },
              ],
            },
          ], expectedGeneration: w.messageDomain.ledger.generation);
          w.messageDomain.visibleIds['c1'] = {'attachment-message'};
          api.routes['GET /messages/attachment-preview/enabled'] = (_) => {
            'enabled': true,
          };
          api.routes['GET /attachments/preview-attachment/preview'] = (_) => {
            'status': 'ok',
            'data': {'kind': 'text', 'text': 'Fixture document'},
          };
          final router = RaftAppRouter(
            home: (_) => withAppServices(
              WorkspaceView(
                controller: w,
                appearance: RaftAppearance(light: family),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
            onLocation: (_) async {},
            onRootBack: () async => false,
            observers: [],
          );
          addTearDown(router.dispose);
          await t.pumpWidget(
            MaterialApp.router(
              theme: raftTheme(family, dark: dark),
              routerDelegate: router,
              routeInformationParser: const RaftAppRouteParser(),
            ),
          );
          await flush(t);
          await t.pumpAndSettle();
          final base = w.location;
          final index = w.navigation.index;
          for (final back in ['toolbar', 'system', 'predictive']) {
            await t.tap(find.text('research.md'));
            await flush(t);
            await t.pumpAndSettle();
            expect(previewSurface, findsOneWidget);
            if (back == 'predictive') {
              // Cancellation must leave both the preview and history intact.
              await startPredictiveBack(t);
              expect(
                t
                    .stateList<NavigatorState>(
                      find.byType(Navigator, skipOffstage: false),
                    )
                    .where((n) => n.userGestureInProgress),
                hasLength(1),
              );
              await backEvent(t, const MethodCall('cancelBackGesture'));
              await t.pumpAndSettle();
              expect(previewSurface, findsOneWidget);
              expect(w.location, base);
              expect(w.navigation.index, index);
              await startPredictiveBack(t);
              await backEvent(t, const MethodCall('commitBackGesture'));
            } else if (back == 'system') {
              await t.binding.handlePopRoute();
            } else {
              await t.tap(find.byTooltip('Close preview'));
            }
            await t.pumpAndSettle();
            expect(previewSurface, findsNothing);
            expect(w.location, base);
            expect(w.navigation.index, index);
            expect(find.text('research.md'), findsOneWidget);
            expect(t.takeException(), isNull);
          }
          // After the preview closes, a separate gesture returns from chat.
          await startPredictiveBack(t);
          expect(
            t
                .stateList<NavigatorState>(
                  find.byType(Navigator, skipOffstage: false),
                )
                .where((n) => n.userGestureInProgress),
            hasLength(1),
          );
          await backEvent(t, const MethodCall('commitBackGesture'));
          await t.pumpAndSettle();
          expect(w.location.route, RaftRoute.home);
          expect(w.navigation.index, index - 1);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  for (final width in [390.0, 1280.0]) {
    for (final (name, mime) in [
      ('photo.png', 'image/png'),
      ('research.md', 'text/markdown'),
      ('page.html', 'text/html'),
    ]) {
      testWidgets(
        'Actual attachment $name uses platform page on phone $width',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final client = _Client()..user = RaftRecord({'id': 'preview-owner'});
          client.selectServer('preview-server');
          final w = WorkspaceController(client)
            ..server = RaftRecord({'id': 'preview-server', 'role': 'owner'})
            ..channel = RaftChannel({'id': 'preview-channel', 'joined': true});
          w.channels = [w.channel!];
          final routes = _Routes();
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(RaftFamily.elegant),
              navigatorObservers: [routes],
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: AttachmentView(
                    controller: w,
                    files: _Files(),
                    metadata: {
                      'id': 'preview-attachment',
                      'filename': name,
                      'mimeType': mime,
                    },
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          for (var cycle = 0; cycle < 2; cycle++) {
            await t.tap(
              mime.startsWith('image/')
                  ? find.byType(RaftAttachmentCard)
                  : find.text(name),
            );
            await t.pumpAndSettle();
            expect(previewSurface, findsOneWidget);
            final image = mime.startsWith('image/');
            final phone = width < RaftAdaptiveWorkspace.desktopMinWidth;
            if (image) {
              // Images open in the media browser: a fading route (the card's
              // picture flies in), immersive and black on a phone.
              expect(routes.latest, isA<RaftMediaBrowserRoute<void>>());
              expect(routes.latest?.settings.name, '/attachment-preview');
              expect(
                find.byType(RaftMediaImmersiveShell).evaluate().isNotEmpty,
                phone,
              );
            } else if (phone) {
              expect(routes.latest, isA<MaterialPageRoute<void>>());
              expect(routes.latest?.settings.name, '/attachment-preview');
              expect(find.byType(Dialog), findsNothing);
              // Native-only page: Web's phone PanelHeader (62 brutal / 56
              // elegant, px-5, boxed 26x28 / 32x32 Back).
              expect(find.byType(RaftMobilePageHeader), findsNothing);
              final brutal = RaftTokens.of(t.element(previewSurface)).brutal;
              expect(
                t.getSize(find.byType(RaftPanelHeaderBar)).height,
                brutal ? 62 : 56,
              );
              expect(t.getTopLeft(find.byType(RaftPanelAction)).dx, 20);
            } else {
              expect(routes.latest, isA<DialogRoute<void>>());
              expect(find.byType(RaftMobilePageHeader), findsNothing);
            }
            await t.tap(
              image && phone
                  ? find.bySemanticsLabel('Back')
                  : find.byTooltip('Close preview'),
            );
            await t.pumpAndSettle();
            expect(previewSurface, findsNothing);
            expect(find.byType(RaftAttachmentCard), findsOneWidget);
            expect(t.takeException(), isNull);
          }
          await t.tap(
            mime.startsWith('image/')
                ? find.byType(RaftAttachmentCard)
                : find.text(name),
          );
          await t.pumpAndSettle();
          w.channel = RaftChannel({...w.channel!.json, 'joined': false});
          w.notifyListeners();
          await t.pumpAndSettle();
          expect(previewSurface, findsNothing);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          w.dispose();
        },
      );
    }
  }
}

Future<(WorkspaceController, RaftAppRouter)> _desktopChat(
  WidgetTester t,
  TargetPlatform platform,
  Size size, {
  String filename = 'research.md',
  String mime = 'text/markdown',
}) async {
  debugDefaultTargetPlatformOverride = platform;
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final (w, api) = await pageFixture(t, section: 'chat');
  w.navigation.navigate(
    RaftLocation.at(serverSlug: 'demo', route: RaftRoute.home),
  );
  w.navigation.navigate(
    RaftLocation.at(
      serverSlug: 'demo',
      route: RaftRoute.channel,
      entityId: 'c1',
    ),
  );
  w.messageDomain.ledger.ingest([
    {
      ...row('attachment-message', 'c1', 1),
      'attachments': [
        {'id': 'preview-attachment', 'filename': filename, 'mimeType': mime},
      ],
    },
  ], expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['c1'] = {'attachment-message'};
  api.routes['GET /messages/attachment-preview/enabled'] = (_) => {
    'enabled': true,
  };
  api.routes['GET /attachments/preview-attachment/preview'] = (_) => {
    'status': 'ok',
    'data': {'kind': 'text', 'text': 'Fixture document'},
  };
  final router = RaftAppRouter(
    home: (_) => withAppServices(
      WorkspaceView(
        controller: w,
        appearance: RaftAppearance(light: RaftFamily.elegant),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
    onLocation: (_) async {},
    onRootBack: () async => false,
    observers: [],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MaterialApp.router(
      theme: raftTheme(RaftFamily.elegant),
      routerDelegate: router,
      routeInformationParser: const RaftAppRouteParser(),
    ),
  );
  await flush(t);
  await t.pumpAndSettle();
  return (w, router);
}

/// The preview must survive the whole transition, not only its first frames:
/// the covered page used to remount at the end of the push on desktop input.
Future<void> _expectPreviewStays(WidgetTester t) async {
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 50));
    expect(previewSurface, findsOneWidget, reason: 'frame $i');
  }
  await t.pumpAndSettle();
  expect(previewSurface, findsOneWidget);
}

/// The platform override must be cleared before the framework's invariant
/// check, which runs ahead of `addTearDown` callbacks.
void _desktopTest(String name, Future<void> Function(WidgetTester t) body) =>
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    });

void _narrowDesktopTests() {
  for (final platform in [TargetPlatform.linux, TargetPlatform.macOS]) {
    _desktopTest('Narrow $platform keeps the preview page open until Back', (
      t,
    ) async {
      final (w, _) = await _desktopChat(t, platform, const Size(390, 844));
      final base = w.location;
      final index = w.navigation.index;
      for (final back in ['system', 'toolbar']) {
        await t.tap(find.text('research.md'));
        await flush(t);
        await _expectPreviewStays(t);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(RaftPanelHeaderBar), findsOneWidget);
        expect(w.location, base);
        expect(w.navigation.index, index);
        if (back == 'system') {
          await t.binding.handlePopRoute();
        } else {
          await t.tap(find.byTooltip('Close preview'));
        }
        await t.pumpAndSettle();
        expect(previewSurface, findsNothing);
        expect(find.text('research.md'), findsOneWidget);
        expect(w.location, base);
        expect(w.navigation.index, index);
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox.shrink());
    });

    _desktopTest('Narrow $platform keeps the image lightbox page open', (
      t,
    ) async {
      final (w, _) = await _desktopChat(
        t,
        platform,
        const Size(390, 844),
        filename: 'photo.png',
        mime: 'image/png',
      );
      final base = w.location;
      await t.tap(find.byType(RaftAttachmentCard));
      await flush(t);
      await _expectPreviewStays(t);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(previewSurface, findsNothing);
      expect(w.location, base);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });

    _desktopTest('$platform resize keeps an open preview', (t) async {
      final (w, _) = await _desktopChat(t, platform, const Size(1280, 844));
      final base = w.location;
      // Wide: desktop dialog; shrinking must not dismiss it.
      await t.tap(find.text('research.md'));
      await flush(t);
      await t.pumpAndSettle();
      expect(previewSurface, findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      t.view.physicalSize = const Size(390, 844);
      await t.pumpAndSettle();
      expect(previewSurface, findsOneWidget);
      expect(w.location, base);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(previewSurface, findsNothing);
      expect(find.text('research.md'), findsOneWidget);
      expect(w.location, base);
      // Narrow: page; widening must not dismiss it either.
      await t.tap(find.text('research.md'));
      await flush(t);
      await _expectPreviewStays(t);
      t.view.physicalSize = const Size(1280, 844);
      await t.pumpAndSettle();
      expect(previewSurface, findsOneWidget);
      expect(w.location, base);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(previewSurface, findsNothing);
      expect(w.location, base);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}

/// Images open in the lightbox; documents and HTML in the preview shell.
final previewSurface = find.byWidgetPredicate(
  (w) =>
      w is RaftAttachmentLightbox ||
      w is RaftMediaImmersiveShell ||
      w is RaftAttachmentPreviewShell,
);

Future<void> backEvent(WidgetTester t, MethodCall call) async {
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(call),
    (_) {},
  );
  await t.pump();
}

Future<void> startPredictiveBack(WidgetTester t) async {
  await backEvent(
    t,
    const MethodCall('startBackGesture', {
      'touchOffset': [5.0, 300.0],
      'progress': 0.0,
      'swipeEdge': 0,
    }),
  );
  await backEvent(
    t,
    const MethodCall('updateBackGestureProgress', {
      'touchOffset': [100.0, 300.0],
      'progress': 0.35,
      'swipeEdge': 0,
    }),
  );
}

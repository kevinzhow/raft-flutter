import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/media_failure.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

/// A player whose source fails the way a backend reports it: playback with the
/// error flag and the class, or an exception from `open`.
class _FailingPlayer implements AttachmentPlayer {
  _FailingPlayer(this.failure, {this.throwOnOpen = false});
  final MediaFailure failure;
  final bool throwOnOpen;
  final events = StreamController<AttachmentPlayback>.broadcast();
  bool disposed = false;
  AttachmentPlayback last = const AttachmentPlayback();
  @override
  Stream<AttachmentPlayback> get changes => events.stream;
  @override
  AttachmentPlayback get playback => last;
  @override
  bool get usesPlatformView => false;
  @override
  Widget video() => const ColoredBox(color: Colors.black);
  @override
  Future<void> open(AttachmentSource source) async {
    last = AttachmentPlayback(error: true, failure: failure);
    if (throwOnOpen) throw MediaPlaybackException(failure);
    // Like libmpv: the open call returns, the failure is reported after it.
    unawaited(Future(() => events.isClosed ? null : events.add(last)));
  }

  @override
  Future<void> toggle() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    unawaited(events.close());
  }
}

/// Opens fine; used for the second attempt of a Retry.
class _OkPlayer extends _FailingPlayer {
  _OkPlayer() : super(const MediaFailure(MediaFailureKind.unknown));
  @override
  Future<void> open(AttachmentSource source) async {
    last = const AttachmentPlayback(duration: Duration(seconds: 5));
    events.add(last);
  }
}

const _proxy = '192.168.5.7:6152';

const _byKind = <MediaFailureKind, MediaFailure>{
  MediaFailureKind.proxyUnreachable: MediaFailure(
    MediaFailureKind.proxyUnreachable,
    proxy: _proxy,
  ),
  MediaFailureKind.proxyAuth: MediaFailure(
    MediaFailureKind.proxyAuth,
    proxy: _proxy,
  ),
  MediaFailureKind.network: MediaFailure(MediaFailureKind.network),
  MediaFailureKind.expired: MediaFailure(MediaFailureKind.expired),
  MediaFailureKind.notFound: MediaFailure(MediaFailureKind.notFound),
  MediaFailureKind.unsupported: MediaFailure(MediaFailureKind.unsupported),
  MediaFailureKind.unknown: MediaFailure(MediaFailureKind.unknown),
};

const _videoText = <MediaFailureKind, String>{
  MediaFailureKind.proxyUnreachable:
      'Cannot reach the proxy $_proxy. Check Network settings, then try again.',
  MediaFailureKind.proxyAuth:
      'The proxy $_proxy needs a username and password. Check Network settings.',
  MediaFailureKind.network:
      'Cannot reach the server. Check your connection and try again.',
  MediaFailureKind.expired:
      'This link has expired or access was denied. Try again.',
  MediaFailureKind.notFound: 'This file is no longer available.',
  MediaFailureKind.unsupported:
      'This video may use a codec this browser cannot preview.',
  MediaFailureKind.unknown: 'The media could not be played.',
};

/// Which actions each class offers: (Retry, Network settings).
const _actions = <MediaFailureKind, (bool, bool)>{
  MediaFailureKind.proxyUnreachable: (true, true),
  MediaFailureKind.proxyAuth: (true, true),
  MediaFailureKind.network: (true, true),
  MediaFailureKind.expired: (true, false),
  MediaFailureKind.notFound: (false, false),
  MediaFailureKind.unsupported: (false, false),
  MediaFailureKind.unknown: (true, false),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  dynamic mounted;
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    mounted?.attachmentMedia.playerSessions.clear();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> mount(
    WidgetTester tester,
    Widget Function(dynamic w) build, {
    Size size = const Size(600, 500),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    mounted = w;
    api.routes['GET /attachments/a1/url'] = (_) => {
      'url': 'https://media.invalid/a1',
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: build(w)),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('audio card', () {
    for (final kind in MediaFailureKind.values) {
      testWidgets('${kind.name}: message and actions', (tester) async {
        var downloads = 0, network = 0;
        await mount(
          tester,
          (w) => InlineAudioAttachment(
            controller: w,
            metadata: const {'id': 'a1', 'filename': 'standup.mp3'},
            authorized: () => true,
            pending: false,
            onDownload: () => downloads++,
            onNetworkSettings: () => network++,
            playerFactory: () => _FailingPlayer(_byKind[kind]!),
          ),
        );
        final expected = kind == MediaFailureKind.unsupported
            ? 'This audio may use a codec this app cannot play.'
            : _videoText[kind]!;
        expect(find.text(expected), findsOneWidget);
        final (retry, settings) = _actions[kind]!;
        expect(
          find.byKey(const Key('audio-retry')),
          retry ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const Key('audio-network-settings')),
          settings ? findsOneWidget : findsNothing,
        );
        if (settings) {
          await tester.tap(find.byKey(const Key('audio-network-settings')));
          expect(network, 1);
        }
        await tester.tap(find.byKey(const Key('audio-placeholder')));
        expect(downloads, 1);
        await unmount(tester);
      });
    }
  });

  group('viewer', () {
    Future<void> openViewer(
      WidgetTester tester,
      MediaFailure failure, {
      required void Function() onNetwork,
      required void Function() onDownload,
      List<AttachmentPlayer>? made,
      String file = 'clip.mp4',
      bool throwOnOpen = false,
    }) async {
      final client = _ViewerClient();
      final w = WorkspaceController(client);
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: AttachmentPreviewDialog(
            controller: w,
            metadata: {'id': 'v1', 'filename': file},
            authorized: () => true,
            onClose: () {},
            onDownload: () async => onDownload(),
            onNetworkSettings: onNetwork,
            playerFactory: () {
              final next = (made?.isEmpty ?? true)
                  ? _FailingPlayer(failure, throwOnOpen: throwOnOpen)
                  : _OkPlayer();
              made?.add(next);
              return next;
            },
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    for (final kind in MediaFailureKind.values) {
      testWidgets('${kind.name}: message, Retry, Network settings, Download', (
        tester,
      ) async {
        var network = 0, downloads = 0;
        await openViewer(
          tester,
          _byKind[kind]!,
          onNetwork: () => network++,
          onDownload: () => downloads++,
        );
        expect(find.text(_videoText[kind]!), findsOneWidget);
        final (retry, settings) = _actions[kind]!;
        expect(find.text('Retry'), retry ? findsOneWidget : findsNothing);
        expect(
          find.byKey(const Key('viewer-network-settings')),
          settings ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byKey(const Key('viewer-download')));
        expect(downloads, 1);
        if (settings) {
          await tester.tap(find.byKey(const Key('viewer-network-settings')));
          expect(network, 1);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }

    testWidgets('a thrown open failure keeps its cause and retry actions', (
      tester,
    ) async {
      await openViewer(
        tester,
        _byKind[MediaFailureKind.proxyAuth]!,
        onNetwork: () {},
        onDownload: () {},
        throwOnOpen: true,
      );
      expect(
        find.text(_videoText[MediaFailureKind.proxyAuth]!),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const Key('viewer-network-settings')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Retry opens a fresh player', (tester) async {
      final made = <AttachmentPlayer>[];
      await openViewer(
        tester,
        _byKind[MediaFailureKind.network]!,
        onNetwork: () {},
        onDownload: () {},
        made: made,
      );
      await tester.tap(find.text('Retry'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(made, hasLength(2));
      expect(find.text(_videoText[MediaFailureKind.network]!), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}

/// Answers the signed-URL request of the viewer.
class _ViewerClient extends RaftClient {
  _ViewerClient()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'url': 'https://media.invalid/signed',
  };
}

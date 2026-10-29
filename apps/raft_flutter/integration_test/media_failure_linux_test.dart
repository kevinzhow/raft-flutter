// Real libmpv, real sockets: drives the app's NativeAttachmentPlayer against a
// local server (and local proxies) and checks that every kind of failure lands
// in the class the UI keys its message and actions on.
//
//   xvfb-run -a tool/flutter test integration_test/media_failure_linux_test.dart \
//     -d linux --dart-define=MEDIA_FAILURE_HOST=<non-loopback LAN address>
//
// The server binds a LAN address, not loopback: no_proxy often lists 127.0.0.1,
// which would hide the proxy cases.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_flutter/features/media_failure_text.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/media_failure.dart';
import 'package:raft_ui/raft_ui.dart';

import '../test/fixtures/preview_samples.dart';

/// When set, the failed card for the proxy case is drawn and saved here.
const _shots = String.fromEnvironment('MEDIA_FAILURE_SHOTS');

const _host = String.fromEnvironment(
  'MEDIA_FAILURE_HOST',
  defaultValue: '192.168.0.19',
);

Future<HttpServer> _media() async {
  final server = await HttpServer.bind(_host, 0);
  server.listen((req) async {
    final r = req.response;
    Future<void> bytes(Uint8List b, ContentType type) async {
      r.headers.contentType = type;
      r.headers.set('accept-ranges', 'bytes');
      r.contentLength = b.length;
      r.add(b);
    }

    switch (req.uri.path) {
      case '/ok.webm':
        await bytes(previewVideo(), ContentType('video', 'webm'));
      case '/ok.wav':
        await bytes(previewWav(), ContentType('audio', 'wav'));
      case '/403':
        r.statusCode = 403;
      case '/401':
        r.statusCode = 401;
      case '/410':
        r.statusCode = 410;
      case '/404':
        r.statusCode = 404;
      case '/500':
        r.statusCode = 500;
      case '/corrupt.mp4':
        await bytes(
          Uint8List.fromList(
            List.generate(4096, (i) => (i * 7919 + 13) % 251),
          ),
          ContentType('video', 'mp4'),
        );
      case '/corrupt.wav':
        await bytes(
          Uint8List.fromList(
            List.generate(4096, (i) => (i * 104729 + 7) % 241),
          ),
          ContentType('audio', 'wav'),
        );
      default:
        r.statusCode = 404;
    }
    await r.close();
  });
  return server;
}

/// A proxy that refuses every request with 407.
Future<HttpServer> _proxy407() async {
  final server = await HttpServer.bind(_host, 0);
  server.listen((req) async {
    req.response
      ..statusCode = 407
      ..headers.set('proxy-authenticate', 'Basic realm="raft-test"');
    await req.response.close();
  });
  return server;
}

Future<int> _closedPort() async {
  final s = await ServerSocket.bind(_host, 0);
  final port = s.port;
  await s.close();
  return port;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every failure of the bundled libmpv lands in its class', (
    tester,
  ) async {
    final media = await _media();
    final proxy407 = await _proxy407();
    final closed = await _closedPort();
    final base = 'http://$_host:${media.port}';
    final saved = SystemProxy.instance.settings;
    addTearDown(() async {
      SystemProxy.instance.configure(saved);
      await media.close(force: true);
      await proxy407.close(force: true);
    });

    /// Opens [url] and returns the final playback (error or first duration).
    Future<(AttachmentPlayback, int)> run(
      String url, {
      ProxySettings proxy = const ProxySettings(mode: ProxyMode.direct),
      bool video = true,
      bool withRefresh = false,
    }) async {
      SystemProxy.instance.configure(proxy);
      final player = NativeAttachmentPlayer(video: video);
      var refreshes = 0;
      final done = Completer<AttachmentPlayback>();
      final sub = player.changes.listen((p) {
        if (p.error && !done.isCompleted) done.complete(p);
        if (p.duration > Duration.zero && !done.isCompleted) done.complete(p);
      });
      if (video) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(width: 320, height: 180, child: player.video()),
            ),
          ),
        );
      }
      try {
        await player.open(
          AttachmentSource.network(
            Uri.parse(url),
            refresh: withRefresh
                ? () async {
                    refreshes++;
                    return Uri.parse(url);
                  }
                : null,
          ),
        );
        for (var i = 0; i < 300 && !done.isCompleted; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final result = done.isCompleted
            ? await done.future
            : player.playback;
        return (result, refreshes);
      } finally {
        await sub.cancel();
        await player.dispose();
        if (video) await tester.pumpWidget(const SizedBox());
      }
    }

    void expectKind(
      (AttachmentPlayback, int) result,
      MediaFailureKind kind, {
      String? proxy,
      int refreshes = 0,
    }) {
      final playback = result.$1;
      expect(playback.error, isTrue, reason: 'expected a failure');
      expect(playback.failure?.kind, kind, reason: '${playback.failure}');
      expect(playback.failure?.proxy, proxy);
      expect(result.$2, refreshes, reason: 'URL re-signs');
    }

    // A valid file plays.
    final ok = await run('$base/ok.webm');
    expect(ok.$1.error, isFalse);
    expect(ok.$1.duration, greaterThan(Duration.zero));
    final okAudio = await run('$base/ok.wav', video: false);
    expect(okAudio.$1.error, isFalse);

    // The host answers an error: the link is signed again once, then the
    // class shows.
    expectKind(
      await run('$base/403', withRefresh: true),
      MediaFailureKind.expired,
      refreshes: 1,
    );
    expectKind(await run('$base/401'), MediaFailureKind.expired);
    expectKind(await run('$base/410'), MediaFailureKind.expired);
    expectKind(await run('$base/404'), MediaFailureKind.notFound);
    expectKind(await run('$base/500'), MediaFailureKind.network);

    // The bytes arrive but are not a media file.
    expectKind(await run('$base/corrupt.mp4'), MediaFailureKind.unsupported);
    expectKind(
      await run('$base/corrupt.wav', video: false),
      MediaFailureKind.unsupported,
    );

    // No proxy: a closed port and a name that does not resolve.
    expectKind(
      await run('http://$_host:$closed/x.mp4', withRefresh: true),
      MediaFailureKind.network,
    );
    expectKind(
      await run('http://nonexistent.invalid/x.mp4'),
      MediaFailureKind.network,
    );

    // Manual proxy that refuses the connection, one that wants credentials,
    // and Kevin's: an address nothing answers on ("No route to host").
    expectKind(
      await run(
        '$base/ok.webm',
        proxy: ProxySettings(mode: ProxyMode.manual, host: _host, port: closed),
        withRefresh: true,
      ),
      MediaFailureKind.proxyUnreachable,
      proxy: '$_host:$closed',
    );
    expectKind(
      await run(
        '$base/ok.webm',
        proxy: ProxySettings(
          mode: ProxyMode.manual,
          host: _host,
          port: proxy407.port,
        ),
      ),
      MediaFailureKind.proxyAuth,
      proxy: '$_host:${proxy407.port}',
    );
    final kevin = await run(
      '$base/ok.webm',
      proxy: const ProxySettings(
        mode: ProxyMode.manual,
        host: '192.168.5.7',
        port: 6152,
      ),
    );
    expectKind(
      kevin,
      MediaFailureKind.proxyUnreachable,
      proxy: '192.168.5.7:6152',
    );

    // The card the user sees for that failure.
    if (_shots.isNotEmpty) {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 448,
                  child: Builder(
                    builder: (context) => RaftInlineVideo(
                      state: RaftInlineMediaState.failed,
                      filename: 'clip.mp4',
                      failureMessage: mediaFailureMessage(
                        context,
                        kevin.$1.failure,
                        video: true,
                      ),
                      onRetry: () {},
                      onNetworkSettings: () {},
                      onDownload: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(() => render.toImage(pixelRatio: 2));
      final png = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      await Directory(_shots).create(recursive: true);
      await File('$_shots/proxy-unreachable-card.png')
          .writeAsBytes(png!.buffer.asUint8List());
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

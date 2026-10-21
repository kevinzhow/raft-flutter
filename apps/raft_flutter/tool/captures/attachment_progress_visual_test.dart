// Renders the attachment loading states of Option A from the REAL widgets
// (AttachmentView, the lightbox, the file preview dialog) in three themes at
// 390x844, for visual comparison with the approved mockup.
//
//   ATTACH_PROGRESS_OUT=/tmp/attach-progress-A/frames \
//     tool/flutter test apps/raft_flutter/tool/captures/attachment_progress_visual_test.dart
//
// Skipped unless ATTACH_PROGRESS_OUT is set (it writes PNG files).
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/attachment_preview_files.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_bars.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../test/parity/parity_harness.dart' show loadParityFonts;

const _themes = [
  ('brutal-light', RaftFamily.brutal, false),
  ('elegant-light', RaftFamily.elegant, false),
  ('elegant-dark', RaftFamily.elegant, true),
];
const mb = 1024 * 1024;
final _outDir = Platform.environment['ATTACH_PROGRESS_OUT'];

void _paintScene(Canvas c, Size s) {
  final w = s.width, h = s.height;
  c.drawRect(
    Offset.zero & s,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * .62), const [
        Color(0xFF4A8FE0),
        Color(0xFFF6C58B),
      ]),
  );
  c.drawCircle(
    Offset(w * .72, h * .34),
    h * .09,
    Paint()..color = const Color(0xFFFFF3C4),
  );
  Path ridge(double base, double amp, double phase, double freq) {
    final p = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w; x += w / 40) {
      final y =
          h * base -
          amp * h * (.5 + .5 * math.sin(x / w * freq * math.pi + phase)) -
          amp * h * .35 * math.sin(x / w * freq * 2.7 * math.pi + phase * 2);
      p.lineTo(x, y);
    }
    return p
      ..lineTo(w, h)
      ..close();
  }

  c.drawPath(ridge(.62, .22, 1.0, 3), Paint()..color = const Color(0xFF6C7FA6));
  c.drawPath(ridge(.70, .16, 2.4, 4), Paint()..color = const Color(0xFF3D5A80));
  c.drawPath(ridge(.78, .10, .3, 5), Paint()..color = const Color(0xFF22384F));
}

Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  _paintScene(Canvas(rec), Size(w.toDouble(), h.toDouble()));
  final image = await rec.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/enabled')) return {'enabled': true};
    final id = RegExp(r'/attachments/([^/]+)/url').firstMatch(path)?.group(1);
    return {'url': 'https://storage.example.invalid/${id ?? 'x'}'};
  }
}

class _Route {
  _Route({this.length, this.immediate, this.fail = false});
  final int? length;
  final Uint8List? immediate;
  final bool fail;
  StreamController<Uint8List>? stream;
}

class _Server implements HttpClientAdapter {
  final routes = <String, _Route>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final route = routes[options.uri.path]!;
    if (route.fail) return ResponseBody.fromString('nope', 500);
    if (route.immediate != null) {
      return ResponseBody.fromBytes(route.immediate!, 200);
    }
    final stream = route.stream = StreamController<Uint8List>();
    cancelFuture?.then((_) {
      if (!stream.isClosed) stream.close();
    });
    return ResponseBody(
      stream.stream,
      200,
      headers: {
        if (route.length != null) 'content-length': ['${route.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _PdfFiles extends AttachmentPreviewFiles {
  void Function(int, int)? progress;
  final hold = Completer<void>();
  @override
  Future<SharedFileLease?> load(
    String url,
    String filename, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int, int)? onProgress,
  }) async {
    progress = onProgress;
    await hold.future;
    return null;
  }
}

Widget _statusBar(RaftTokens t, {bool onBlack = false}) => Positioned(
  left: 0,
  right: 0,
  top: 0,
  height: 40,
  child: IgnorePointer(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          for (final text in ['9:41', '5G  100%']) ...[
            Text(
              text,
              style: RaftTypography.body(
                t,
                size: text == '9:41' ? 13 : 11,
                line: 16,
                weight: FontWeight.w700,
                color: onBlack ? Colors.white : t.ink,
              ).copyWith(decoration: TextDecoration.none),
            ),
            if (text == '9:41') const Spacer(),
          ],
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'render attachment progress frames from the real widgets',
    (tester) async {
      Directory(_outDir!).createSync(recursive: true);
      late Uint8List thumb;
      await tester.runAsync(() async {
        await loadParityFonts();
        thumb = await _png(320, 213);
      });
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 34 * 3);
      tester.view.viewPadding = const FakeViewPadding(
        top: 44 * 3,
        bottom: 34 * 3,
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });
      final boundary = GlobalKey();

      Future<void> hop([int n = 8]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      Future<void> shoot(String theme, String state) async {
        await tester.pump(const Duration(milliseconds: 120));
        final ro = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundary),
        );
        await tester.runAsync(() async {
          final image = await ro.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$_outDir/$theme$state.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      for (final (theme, family, dark) in _themes) {
        Future<(WorkspaceController, _Server, _Client)> mount(
          Widget Function(BuildContext, WorkspaceController, AttachmentFiles)
          body, {
          bool onBlack = false,
          _Server? server,
        }) async {
          final client = _Client()..user = RaftRecord({'id': 'alice'});
          client.selectServer('server');
          final w = WorkspaceController(client)
            ..server = RaftRecord({'id': 'server', 'role': 'owner'})
            ..channel = RaftChannel({'id': 'channel', 'joined': true});
          w.channels = [w.channel!];
          final srv = server ?? _Server();
          final files = AttachmentFiles(dio: Dio()..httpClientAdapter = srv);
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: raftTheme(family, dark: dark),
                builder: (context, child) => Stack(
                  children: [
                    Positioned.fill(
                      child: Localizations.override(
                        context: context,
                        locale: const Locale('zh'),
                        child: child,
                      ),
                    ),
                    _statusBar(RaftTokens.of(context), onBlack: onBlack),
                  ],
                ),
                home: Builder(builder: (c) => body(c, w, files)),
              ),
            ),
          );
          return (w, srv, client);
        }

        Widget timelinePage(BuildContext c, List<Widget> rows) {
          final t = RaftTokens.of(c);
          return Material(
            color: t.canvas,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  RaftPanelHeaderBar(title: '# design', onBack: () {}),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 8),
                      physics: const NeverScrollableScrollPhysics(),
                      children: rows,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget message(
          BuildContext c,
          String time,
          String text,
          Widget attachment,
        ) {
          final t = RaftTokens.of(c);
          return RaftMessageRow(
            author: 'Cindy',
            timestamp: time,
            avatar: const RaftAvatar(name: 'Cindy'),
            content: Text(
              text,
              style: RaftTypography.body(t, size: 15, line: 20, color: t.ink),
            ),
            attachments: Align(
              alignment: Alignment.centerLeft,
              child: attachment,
            ),
          );
        }

        Map<String, dynamic> image(
          String id, {
          bool thumbnail = false,
          int size = 3565158,
        }) => {
          'id': id,
          'filename': 'IMG_4821.jpg',
          'mimeType': 'image/jpeg',
          'sizeBytes': size,
          'width': 1200,
          'height': 800,
          if (thumbnail) 'thumbnailUrl': 'https://cdn.example.invalid/$id.webp',
        };

        // 1. timeline: 35% and still connecting.
        {
          final server = _Server()
            ..routes['/a'] = _Route(length: 3565158)
            ..routes['/b'] = _Route(length: 3565158);
          final (w, _, client) = await mount(
            (c, w, files) => timelinePage(c, [
              message(
                c,
                '10:42',
                '拍了几张，先发你看看',
                AttachmentView(
                  controller: w,
                  files: files,
                  metadata: image('a'),
                  imageExtent: const Size(300, 200),
                ),
              ),
              message(
                c,
                '10:43',
                '还有这张（网络不太稳）',
                AttachmentView(
                  controller: w,
                  files: files,
                  metadata: image('b'),
                  imageExtent: const Size(300, 200),
                ),
              ),
            ]),
            server: server,
          );
          await hop();
          server.routes['/a']!.stream!.add(Uint8List((1.2 * mb).round()));
          await hop();
          await tester.pump(const Duration(milliseconds: 150));
          await shoot(theme, '__timeline');
          await tester.pumpWidget(const SizedBox());
          server.routes['/a']!.stream!.close();
          server.routes['/b']!.stream!.close();
          w.dispose();
          await client.dispose();
        }

        // 2./3. viewer with and without a thumbnail.
        for (final withThumb in [true, false]) {
          final server = _Server()
            ..routes['/a'] = _Route(length: 3565158)
            ..routes['/a.webp'] = _Route(immediate: thumb);
          final (w, _, client) = await mount(
            (c, w, files) => Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: AttachmentView(
                  controller: w,
                  files: files,
                  metadata: image('a', thumbnail: withThumb),
                  imageExtent: const Size(300, 200),
                ),
              ),
            ),
            onBlack: true,
            server: server,
          );
          await hop();
          if (withThumb) {
            final dynamic state = tester.state(find.byType(AttachmentView));
            for (var i = 0; i < 100 && state.imageProvider == null; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 10)),
              );
            }
            await tester.pump();
          }
          await tester.tap(find.byType(RaftAttachmentCard));
          await hop();
          await tester.pump(const Duration(milliseconds: 400));
          server.routes['/a']!.stream!.add(
            Uint8List(((withThumb ? 2.1 : 1.2) * mb).round()),
          );
          await hop();
          await tester.pump(const Duration(milliseconds: 150));
          await shoot(theme, withThumb ? '__viewer-thumb' : '__viewer-nothumb');
          await tester.pumpWidget(const SizedBox());
          server.routes['/a']!.stream!.close();
          w.dispose();
          await client.dispose();
        }

        // 4. a PDF preview downloading.
        {
          final files = _PdfFiles();
          final client = _Client()..user = RaftRecord({'id': 'alice'});
          final w = WorkspaceController(client);
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: raftTheme(family, dark: dark),
                builder: (context, child) => Stack(
                  children: [
                    Positioned.fill(
                      child: Localizations.override(
                        context: context,
                        locale: const Locale('zh'),
                        child: child,
                      ),
                    ),
                    _statusBar(RaftTokens.of(context), onBlack: true),
                  ],
                ),
                home: Builder(
                  builder: (c) {
                    final t = RaftTokens.of(c);
                    return Scaffold(
                      backgroundColor: t.panel,
                      body: RaftSystemBarSurface(
                        statusBarFallback: t.panel,
                        child: AttachmentPreviewDialog(
                          controller: w,
                          metadata: const {
                            'id': 'doc',
                            'filename': '2026Q3-report.pdf',
                            'mimeType': 'application/pdf',
                            'sizeBytes': 2936012,
                          },
                          authorized: () => true,
                          onClose: () {},
                          onDownload: () async {},
                          files: files,
                          page: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          await hop();
          files.progress!((1.7 * mb).round(), 2936012);
          await hop();
          await tester.pump(const Duration(milliseconds: 150));
          await shoot(theme, '__pdf');
          await tester.pumpWidget(const SizedBox());
          files.hold.complete();
          w.dispose();
          await client.dispose();
        }

        // 5. failed: image tile (real fetch failure) and a failed file card.
        {
          final server = _Server()
            ..routes['/a'] = _Route(fail: true)
            ..routes['/b'] = _Route(fail: true);
          final (w, _, client) = await mount(
            (c, w, files) => timelinePage(c, [
              message(
                c,
                '10:42',
                '拍了几张，先发你看看',
                AttachmentView(
                  controller: w,
                  files: files,
                  metadata: image('a'),
                  imageExtent: const Size(300, 200),
                ),
              ),
              message(
                c,
                '10:44',
                '季度报告在这里',
                RaftAttachmentCard(
                  filename: '2026Q3-report.pdf',
                  mimeType: 'application/pdf',
                  sizeBytes: 2936012,
                  metaLabel: 'application/pdf',
                  downloadFailed: true,
                  onOpen: () {},
                ),
              ),
            ]),
            server: server,
          );
          await hop(12);
          await tester.pump(const Duration(milliseconds: 150));
          await shoot(theme, '__failed');
          await tester.pumpWidget(const SizedBox());
          w.dispose();
          await client.dispose();
        }
      }
    },
    skip: _outDir == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

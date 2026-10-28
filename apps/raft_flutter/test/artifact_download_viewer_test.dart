import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifact_viewer.dart';
import 'package:raft_flutter/platform/artifact_download_bridge.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_webview.dart';

Future<void> _wait(
  WidgetTester t,
  bool Function() ready, {
  String? reason,
}) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!ready() && DateTime.now().isBefore(end)) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUp(() {
    WebViewPlatform.instance = FakeWebView();
    FakeWebView.reset();
  });

  for (final (size, platform, input) in [
    (const Size(390, 844), TargetPlatform.linux, PointerDeviceKind.mouse),
    (const Size(856, 944), TargetPlatform.android, PointerDeviceKind.touch),
    (const Size(944, 856), TargetPlatform.android, PointerDeviceKind.touch),
  ]) {
    testWidgets(
      'Artifact save retries, returns to report and cancels on close at $size using $input',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final root = (await t.runAsync(
          () => Directory.systemTemp.createTemp('raft-artifact-viewer-'),
        ))!;
        final staging = await t.runAsync(
          () => Directory('${root.path}/staging').create(),
        );
        final server = (await t.runAsync(
          () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        ))!;
        final report = Uri.parse('http://127.0.0.1:${server.port}/report');
        final bytes = utf8.encode('Report,bytes\n日本語,42\n');
        var requests = 0, picks = 0, discarded = 0;
        var fail = true;
        server.listen((r) async {
          requests++;
          if (fail) {
            r.response.statusCode = 503;
          } else {
            r.response.add(bytes);
          }
          await r.response.close();
        });
        final saved = File('${root.path}/selected.csv');
        final lastPicked = Completer<String?>();
        Map<dynamic, dynamic>? binding;
        final messenger = t.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(ArtifactDownloadBridge.channel, (
          call,
        ) async {
          if (call.method == 'attach') {
            binding = Map<dynamic, dynamic>.from(call.arguments as Map);
          }
          return null;
        });
        addTearDown(() async {
          messenger.setMockMethodCallHandler(
            ArtifactDownloadBridge.channel,
            null,
          );
          if (!lastPicked.isCompleted) lastPicked.complete(null);
          await server.close(force: true);
          await root.delete(recursive: true);
        });
        Future<void> event() async {
          final done = Completer<void>();
          messenger.handlePlatformMessage(
            ArtifactDownloadBridge.channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('download', {
                ...binding!,
                'url': report.resolve('/file').toString(),
                'filename': 'report.csv',
                'mimeType': 'text/csv',
                'cookie': 'fixture_artifact=only-this-origin',
              }),
            ),
            (_) => done.complete(),
          );
          await done.future;
        }

        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            home: Builder(
              builder: (context) => Column(
                children: [
                  const Text('Conversation'),
                  RaftButton(
                    label: 'Open report',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (inner) => ArtifactViewer(
                            uri: report,
                            api: null,
                            page: true,
                            onClose: () => Navigator.of(inner).pop(),
                            webViewBuilder: (_, _) =>
                                const Center(child: Text('Loaded report')),
                            bindDownloads: (_, origin, onDownload) =>
                                ArtifactDownloadBridge.attach(
                                  webViewId: 42,
                                  origin: origin,
                                  onDownload: onDownload,
                                ),
                            downloadFiles: (dio) => AttachmentFiles(
                              dio: dio,
                              pickDestination: (_, _) async {
                                picks++;
                                if (picks == 3) return lastPicked.future;
                                await saved.create();
                                return saved.path;
                              },
                              stagingDirectory: () async => staging!,
                              discardIncompleteDestination: true,
                              discardDestination: (path) async {
                                discarded++;
                                final file = File(path);
                                if (await file.exists()) await file.delete();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.pump();
        });
        await t.tap(find.text('Open report'), kind: input);
        await t.pumpAndSettle();
        for (var frame = 0; frame < 8 && binding == null; frame++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump();
        }
        expect(
          binding,
          isNotNull,
          reason: 'the native listener is attached before a download response',
        );
        FakeWebView.finish(report.toString());
        await t.pump();
        expect(find.text('Loaded report'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('artifact-download-status')),
          findsNothing,
        );
        await t.runAsync(event);
        await _wait(
          t,
          () => requests == 1 && discarded == 1,
          reason: 'failed response must clean its selected document',
        );
        await t.pump();
        expect(find.text('Download failed. Try again.'), findsOneWidget);
        fail = false;
        await t.tap(find.text('Retry'), kind: input);
        await _wait(
          t,
          () =>
              requests == 2 &&
              saved.existsSync() &&
              saved.readAsBytesSync().length == bytes.length &&
              find.text('Saved.').evaluate().isNotEmpty,
          reason: 'Retry must finish writing the actual selected file',
        );
        await t.pump();
        expect(find.text('Saved.'), findsOneWidget);
        expect(find.text('Download failed. Try again.'), findsNothing);
        expect(await t.runAsync(saved.readAsBytes), bytes);
        await t.tap(
          find.descendant(
            of: find.byKey(const ValueKey('artifact-download-status')),
            matching: find.text('Close'),
          ),
          kind: input,
        );
        await t.pump();
        expect(
          find.byKey(const ValueKey('artifact-download-status')),
          findsNothing,
        );
        expect(find.text('Loaded report'), findsOneWidget);
        expect(FakeWebView.loads, [report.toString()]);
        await t.runAsync(event);
        await t.pump();
        expect(picks, 3);
        await t.tap(
          find.byKey(const ValueKey('artifact-viewer-close')),
          kind: input,
        );
        await t.pumpAndSettle();
        await t.runAsync(() async {
          final abandoned = File('${root.path}/abandoned.csv');
          await abandoned.create();
          lastPicked.complete(abandoned.path);
        });
        await _wait(t, () => discarded == 2);
        expect(File('${root.path}/abandoned.csv').existsSync(), isFalse);
        await t.runAsync(event);
        expect(requests, 2);
        expect(picks, 3);
        expect(find.text('Conversation'), findsOneWidget);
        await t.tap(find.text('Open report'), kind: input);
        await t.pumpAndSettle();
        FakeWebView.finish(report.toString());
        await t.pump();
        expect(
          find.byKey(const ValueKey('artifact-download-status')),
          findsNothing,
        );
        await t.tap(
          find.byKey(const ValueKey('artifact-viewer-close')),
          kind: input,
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump();
      },
    );
  }
}

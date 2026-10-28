import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifact_download_controller.dart';
import 'package:raft_flutter/platform/artifact_download_bridge.dart';
import 'package:raft_flutter/platform/attachment_files.dart';

const _cookie = 'fixture_artifact=memory-only';
final _bytes = utf8.encode('column,value\n中文,42\n');

Future<void> _until(
  bool Function() condition, {
  String Function()? diagnostic,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(
    condition(),
    isTrue,
    reason: diagnostic?.call() ?? 'the bounded download must finish',
  );
}

class _Download {
  _Download(this.root, this.server);
  final Directory root;
  final HttpServer server;
  late ArtifactDownloadController controller;
  late ArtifactDownloadBridge bridge;
  late Map<dynamic, dynamic> binding;
  var picks = 0, requests = 0, discarded = 0;
  final headers = <HttpHeaders>[];
  final errors = <String>[];
  Future<String?> Function(String, String)? picker;
  final destinations = <File>[];
  Uri get origin => Uri.parse('http://127.0.0.1:${server.port}');
  Directory get staging => Directory('${root.path}/staging');

  static Future<_Download> create() async {
    final root = await Directory.systemTemp.createTemp(
      'raft-artifact-download-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _Download(root, server);
    await fixture.staging.create();
    fixture.controller = ArtifactDownloadController(
      origin: fixture.origin,
      files: (dio) => AttachmentFiles(
        dio: dio,
        pickDestination: (name, mime) async {
          fixture.picks++;
          if (fixture.picker != null) return fixture.picker!(name, mime);
          final file = File('${root.path}/selected-${fixture.picks}.csv');
          await file.create(); // ACTION_CREATE_DOCUMENT creates the target.
          fixture.destinations.add(file);
          return file.path;
        },
        stagingDirectory: () async => fixture.staging,
        discardIncompleteDestination: true,
        discardDestination: (destination) async {
          fixture.discarded++;
          final file = File(destination);
          if (await file.exists()) await file.delete();
        },
      ),
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ArtifactDownloadBridge.channel, (
      call,
    ) async {
      if (call.method == 'attach') {
        fixture.binding = Map<dynamic, dynamic>.from(call.arguments as Map);
      }
      return null;
    });
    fixture.bridge = await ArtifactDownloadBridge.attach(
      webViewId: 42,
      origin: fixture.origin,
      onDownload: fixture.controller.receive,
    );
    addTearDown(() async {
      await fixture.bridge.dispose();
      fixture.controller.dispose();
      await _until(() => !fixture.controller.busy);
      await server.close(force: true);
      await root.delete(recursive: true);
      messenger.setMockMethodCallHandler(ArtifactDownloadBridge.channel, null);
    });
    return fixture;
  }

  void serve(Future<void> Function(HttpRequest) response) {
    server.listen((request) async {
      requests++;
      headers.add(request.headers);
      try {
        await response(request);
      } catch (error) {
        // A cancelled transfer closes its socket before the held response.
        errors.add(error.toString());
      }
    });
  }

  Future<void> event({
    String path = '/file',
    Map<String, Object?> extra = const {},
  }) async {
    final reply = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          ArtifactDownloadBridge.channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('download', {
              ...binding,
              'url': origin.resolve(path).toString(),
              'filename': '../../private\\report.csv',
              'mimeType': 'text/csv',
              'cookie': _cookie,
              'userAgent': 'Artifact download fixture',
              ...extra,
            }),
          ),
          (_) => reply.complete(),
        );
    await reply.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Real loopback responses and real temporary file readback, no HTTP mock.
  HttpOverrides.global = null;

  test('native callback selects before fetching and saves complete private same-origin bytes', () async {
    final f = await _Download.create();
    f.picker = (name, mime) async {
      expect(name, 'report.csv');
      expect(mime, 'text/csv');
      expect(f.requests, 0);
      final destination = File('${f.root.path}/saved.csv');
      await destination.create();
      f.destinations.add(destination);
      return destination.path;
    };
    f.serve((request) async {
      expect(request.headers.value(HttpHeaders.cookieHeader), _cookie);
      expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
      expect(request.headers.value('X-Server-Id'), isNull);
      if (request.uri.path == '/begin') {
        request.response
          ..statusCode = 302
          ..headers.set(HttpHeaders.locationHeader, '/file');
      } else {
        request.response
          ..headers.contentType = ContentType('text', 'csv')
          ..contentLength = _bytes.length
          ..add(_bytes);
      }
      await request.response.close();
    });
    await f.event(extra: {'bindingId': 'retired-binding'});
    await f.event(extra: {'webViewId': 99});
    expect(f.picks, 0);
    await f.event(path: '/begin');
    await _until(() => !f.controller.busy);
    expect(f.controller.status, ArtifactDownloadStatus.saved);
    expect(await f.destinations.single.readAsBytes(), _bytes);
    expect(f.requests, 2);
    expect(f.discarded, 0);
    expect(await f.staging.list().toList(), isEmpty);
    f.controller.dismiss();
    expect(f.controller.status, ArtifactDownloadStatus.idle);
  });

  test('cancelled picker and duplicate callbacks fetch nothing; a later retry saves', () async {
    final f = await _Download.create();
    final picked = Completer<String?>();
    f.picker = (_, _) => picked.future;
    f.serve((request) async {
      request.response.add(_bytes);
      await request.response.close();
    });
    await f.event();
    await f.event();
    expect(f.picks, 1);
    expect(f.requests, 0);
    picked.complete(null);
    await _until(() => !f.controller.busy);
    expect(f.controller.status, ArtifactDownloadStatus.cancelled);
    expect(f.requests, 0);
    f.picker = null;
    await f.controller.retry();
    expect(f.picks, 2);
    expect(f.requests, 1);
    expect(f.controller.status, ArtifactDownloadStatus.saved);
    expect(await f.destinations.single.readAsBytes(), _bytes);
    expect(await f.staging.list().toList(), isEmpty);
  });

  test('foreign download and cross-origin redirect get no cookie or request; failure can retry', () async {
    final f = await _Download.create();
    final foreign = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => foreign.close(force: true));
    var foreignRequests = 0, redirect = true;
    foreign.listen((r) async {
      foreignRequests++;
      await r.response.close();
    });
    f.serve((request) async {
      if (redirect) {
        request.response
          ..statusCode = 302
          ..headers.set(
            HttpHeaders.locationHeader,
            'http://127.0.0.1:${foreign.port}/file',
          );
      } else {
        request.response.add(_bytes);
      }
      await request.response.close();
    });
    await f.event(extra: {'url': 'http://127.0.0.1:${foreign.port}/file'});
    expect(f.picks, 0);
    expect(foreignRequests, 0);
    await f.event();
    await _until(() => !f.controller.busy);
    expect(f.controller.status, ArtifactDownloadStatus.failed);
    expect(f.controller.unsupportedOrigin, isTrue);
    expect(f.headers.single.value(HttpHeaders.cookieHeader), _cookie);
    expect(foreignRequests, 0);
    expect(await f.destinations.single.exists(), isFalse);
    expect(f.discarded, 1);
    expect(await f.staging.list().toList(), isEmpty);
    redirect = false;
    await f.controller.retry();
    expect(f.controller.status, ArtifactDownloadStatus.saved);
    expect(await f.destinations.last.readAsBytes(), _bytes);
  });

  test('closing during a response cancels bytes and removes the newly selected document', () async {
    final f = await _Download.create();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    f.serve((request) async {
      request.response
        ..bufferOutput = false
        ..headers.contentType = ContentType.binary
        ..add(List.filled(1024, 7));
      await request.response.flush();
      await release.future;
      request.response.add(List.filled(64512, 9));
      await request.response.close();
    });
    await f.event();
    await _until(
      () => f.controller.progress.received > 0,
      diagnostic: () =>
          'before close: requests=${f.requests}, picks=${f.picks}, status=${f.controller.status}, busy=${f.controller.busy}, received=${f.controller.progress.received}, serverErrors=${f.errors}',
    );
    await f.bridge.dispose();
    f.controller.retire();
    release.complete();
    await _until(() => !f.controller.busy);
    await f.event(); // A queued callback from the now-detached view is inert.
    expect(f.picks, 1);
    expect(f.requests, 1);
    expect(await f.destinations.single.exists(), isFalse);
    expect(f.discarded, 1);
    expect(await f.staging.list().toList(), isEmpty);
  });
}

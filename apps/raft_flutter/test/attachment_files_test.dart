import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/platform/attachment_files.dart';

import 'support/mock_attachment_writer.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(mockAttachmentWriter);
  // These cases talk to a real loopback server; undo the test binding's mock client.
  HttpOverrides.global = null;
  test('cancelled save picker fetches nothing and revoked scope never creates a temp file', () async {
    final base = await Directory.systemTemp.createTemp('raft-download-test-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) {
      requests++;
      request.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}/fixture';
    final cancelled = AttachmentFiles(
      pickDestination: (_, _) async => null,
      stagingDirectory: () async => base,
    );
    expect(
      await cancelled.save(
        url: url,
        filename: 'report.txt',
        mimeType: 'text/plain',
        cancel: CancelToken(),
        authorized: () => true,
        onProgress: (_, _) {},
      ),
      isNull,
    );
    final revoked = AttachmentFiles(
      pickDestination: (_, _) async => p.join(base.path, 'report.txt'),
      stagingDirectory: () async => base,
    );
    expect(
      await revoked.save(
        url: url,
        filename: 'report.txt',
        mimeType: 'text/plain',
        cancel: CancelToken(),
        authorized: () => false,
        onProgress: (_, _) {},
      ),
      isNull,
    );
    expect(requests, 0);
    expect(await base.list().toList(), isEmpty);
    await server.close(force: true);
    await base.delete(recursive: true);
  });
  test('failed transfer preserves existing selected file and removes private partial bytes', () async {
    final base = await Directory.systemTemp.createTemp('raft-download-test-');
    final existing = File(p.join(base.path, 'original.txt'));
    await existing.writeAsString('must survive');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = 503;
      request.response.write('unavailable');
      await request.response.close();
    });
    final files = AttachmentFiles(
      pickDestination: (_, _) async => existing.path,
      stagingDirectory: () async => base,
    );
    await expectLater(
      files.save(
        url: 'http://127.0.0.1:${server.port}/fixture',
        filename: '../../original.txt',
        mimeType: 'text/plain',
        cancel: CancelToken(),
        authorized: () => true,
        onProgress: (_, _) {},
      ),
      throwsA(isA<DioException>()),
    );
    expect(await existing.readAsString(), 'must survive');
    expect(await base.list().toList(), hasLength(1));
    await server.close(force: true);
    await base.delete(recursive: true);
  });
  test('successful file save writes complete bytes and does not retain transfer files', () async {
    final base = await Directory.systemTemp.createTemp('raft-download-test-');
    final saved = File(p.join(base.path, '日本語.txt'));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.write('中文 日本語');
      await request.response.close();
    });
    final files = AttachmentFiles(
      pickDestination: (_, _) async => saved.path,
      stagingDirectory: () async => base,
    );
    expect(
      await files.save(
        url: 'http://127.0.0.1:${server.port}/fixture',
        filename: '日本語.txt',
        mimeType: 'text/plain',
        cancel: CancelToken(),
        authorized: () => true,
        onProgress: (_, _) {},
      ),
      saved.path,
    );
    expect(await saved.readAsString(), '中文 日本語');
    expect(await base.list().toList(), hasLength(1));
    await server.close(force: true);
    await base.delete(recursive: true);
  });
  test('macOS cached files and byte exports publish through the native writer only while authorized', () async {
    final base = await Directory.systemTemp.createTemp(
      'raft-native-save-test-',
    );
    addTearDown(() => base.delete(recursive: true));
    final source = File(p.join(base.path, 'cache.zip'));
    await source.writeAsString('cached attachment');
    final destination = File(p.join(base.path, 'selected.zip'));
    var calls = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AttachmentFiles.channel,
      (call) async {
        expect(call.method, 'writeSaved');
        final args = Map<String, Object?>.from(call.arguments as Map);
        expect(args['uri'], destination.path);
        final staged = File(args['path']! as String);
        expect(await staged.exists(), isTrue);
        await destination.writeAsBytes(await staged.readAsBytes());
        calls++;
        return null;
      },
    );
    final files = AttachmentFiles(
      pickDestination: (_, _) async => destination.path,
      stagingDirectory: () async => base,
    );
    await files.saveFile(
      source: source,
      filename: 'cache.zip',
      mimeType: 'application/zip',
      authorized: () => true,
    );
    expect(await destination.readAsString(), 'cached attachment');
    expect(await source.readAsString(), 'cached attachment');
    await files.saveBytes(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'export.zip',
      mimeType: 'application/zip',
      authorized: () => true,
    );
    expect(await destination.readAsBytes(), [1, 2, 3]);
    expect(
      await files.saveFile(
        source: source,
        filename: 'cache.zip',
        mimeType: 'application/zip',
        authorized: () => false,
      ),
      isNull,
    );
    expect(
      await files.saveBytes(
        bytes: Uint8List(0),
        filename: 'export.zip',
        mimeType: 'application/zip',
        authorized: () => false,
      ),
      isNull,
    );
    expect(calls, 2);
    expect(await base.list().toList(), hasLength(2));
  }, skip: !Platform.isMacOS);

  test('native publication failure preserves the destination and cleans staged bytes', () async {
    final base = await Directory.systemTemp.createTemp(
      'raft-native-save-test-',
    );
    addTearDown(() => base.delete(recursive: true));
    final destination = File(p.join(base.path, 'selected.txt'));
    await destination.writeAsString('keep this');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write('complete new attachment');
      await request.response.close();
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AttachmentFiles.channel,
      (call) async => throw PlatformException(code: 'save_failed'),
    );
    final files = AttachmentFiles(
      pickDestination: (_, _) async => destination.path,
      stagingDirectory: () async => base,
    );
    await expectLater(
      files.save(
        url: 'http://127.0.0.1:${server.port}/fixture',
        filename: 'new.txt',
        mimeType: 'text/plain',
        cancel: CancelToken(),
        authorized: () => true,
        onProgress: (_, _) {},
      ),
      throwsA(isA<PlatformException>()),
    );
    expect(await destination.readAsString(), 'keep this');
    expect(await base.list().toList(), hasLength(1));
  }, skip: !Platform.isMacOS);
}

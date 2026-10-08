import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/platform/attachment_files.dart';

void main() {
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
      temporaryDirectory: () async => base,
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
      temporaryDirectory: () async => base,
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
      temporaryDirectory: () async => base,
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
      temporaryDirectory: () async => base,
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
}

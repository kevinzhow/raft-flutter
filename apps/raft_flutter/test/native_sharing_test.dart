import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/content_links.dart';
import 'package:raft_flutter/features/incoming_share_review.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'incoming content grants are bounded and filenames cannot escape staging',
    () {
      expect(
        IncomingShare.parse({
          'files': [
            {'uri': 'file:///private', 'filename': 'x'},
          ],
        }),
        isNull,
      );
      expect(IncomingShare.parse({'text': 'x' * 65537}), isNull);
      expect(
        IncomingShare.parse({
          'files': List.generate(
            11,
            (_) => {'uri': 'content://proof/item', 'filename': 'x'},
          ),
        }),
        isNull,
      );
      final share = IncomingShare.parse({
        'text': 'review me',
        'files': [
          {'uri': 'content://proof/item', 'filename': '../../report.txt'},
        ],
      })!;
      expect(share.files.single.filename, 'report.txt');
      expect(
        unsafeSharedText('https://example.test/file?X-Amz-Signature=secret'),
        true,
      );
      expect(unsafeSharedText('https://user:password@example.test/a'), true);
      expect(unsafeSharedText('raft://oauth/callback?code=secret'), true);
      expect(
        unsafeSharedText('https://example.test/voucher?code=ordinary'),
        false,
      );
    },
  );
  test(
    'receiver replacement owns unsubscribe and never persists incoming content',
    () async {
      final sharing = NativeSharing(supported: false);
      final received = <String?>[];
      sharing.receive(const IncomingShare(text: 'queued'));
      final unsubscribe = sharing.registerReceiver(
        (s) => received.add('old:${s.text}'),
      );
      sharing.registerReceiver((s) => received.add(s.text));
      unsubscribe();
      sharing.receive(const IncomingShare(text: 'new'));
      expect(received, ['old:queued', 'new']);
      await sharing.dispose();
      sharing.receive(const IncomingShare(text: 'closed'));
      expect(received.length, 2);
    },
  );
  test('platform byte read drops late bytes after account changes', () async {
    const channel = MethodChannel('test.raft.share');
    final pending = Completer<Uint8List>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) => pending.future);
    final sharing = NativeSharing(channel: channel, supported: true);
    var authorized = true;
    final read = sharing.readIncoming(
      const IncomingSharedFile('content://proof/item', 'item', 'text/plain', 1),
      authorized: () => authorized,
    );
    authorized = false;
    pending.complete(Uint8List.fromList([1]));
    await expectLater(read, throwsA(isA<PlatformException>()));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('real download exports bytes only; leases and stale transfers delete private artifacts', () async {
    final folder = await Directory.systemTemp.createTemp('raft-share-test');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.write('private proof bytes');
      await request.response.close();
    });
    final dio = Dio()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttp()),
      );
    final sharing = NativeSharing(
      dio: dio,
      supported: true,
      temporaryDirectory: () async => folder,
    );
    final lease = await sharing.prepareAttachment(
      url: 'http://127.0.0.1:${server.port}/file?signature=private',
      filename: '../../proof.txt',
      cancel: CancelToken(),
      authorized: () => true,
      onProgress: (_, _) {},
    );
    expect(await lease!.file.readAsString(), 'private proof bytes');
    expect(lease.file.path, endsWith('/proof.txt'));
    expect(
      await folder.list(recursive: true).where((e) => e is File).length,
      1,
    );
    await Future.wait([lease.dispose(), lease.dispose()]);
    var valid = true;
    final stale = await sharing.prepareAttachment(
      url: 'http://127.0.0.1:${server.port}/file',
      filename: 'stale.txt',
      cancel: CancelToken(),
      authorized: () => valid,
      onProgress: (_, _) => valid = false,
    );
    expect(stale, isNull);
    expect(
      await folder.list(recursive: true).where((e) => e is File).length,
      0,
    );
    await server.close(force: true);
    await folder.delete(recursive: true);
  });
  test(
    'PNG export byte leases are scoped; cancelled save writes nothing',
    () async {
      final folder = await Directory.systemTemp.createTemp('raft-png-export');
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final sharing = NativeSharing(
        supported: true,
        temporaryDirectory: () async => folder,
      );
      final lease = await sharing.prepareBytes(
        bytes,
        filename: '../export.png',
        authorized: () => true,
      );
      expect(await lease!.file.readAsBytes(), bytes);
      await lease.dispose();
      final files = AttachmentFiles(
        pickDestination: (_, _) async => null,
        temporaryDirectory: () async => folder,
      );
      expect(
        await files.saveBytes(
          bytes: bytes,
          filename: 'export.png',
          mimeType: 'image/png',
          authorized: () => true,
        ),
        isNull,
      );
      final output = File('${folder.path}/chosen.png');
      final accepted = AttachmentFiles(
        pickDestination: (_, _) async => output.path,
        temporaryDirectory: () async => folder,
      );
      expect(
        await accepted.saveBytes(
          bytes: bytes,
          filename: '../export.png',
          mimeType: 'image/png',
          authorized: () => true,
        ),
        output.path,
      );
      expect(await output.readAsBytes(), bytes);
      expect(
        await folder.list(recursive: true).where((e) => e is File).length,
        1,
      );
      await folder.delete(recursive: true);
    },
  );
  test('frontend aliases bind to exact API and source DM/thread links remain canonical', () {
    final alias = ContentLinks.originFor(
      'http://localhost:13041',
      api: 'http://localhost:13041',
      frontend: 'http://localhost:15213',
    );
    expect(alias.origin, 'http://localhost:15213');
    expect(
      ContentLinks.originFor(
        'https://other.test',
        api: 'http://localhost:13041',
        frontend: 'http://localhost:15213',
      ).origin,
      'https://other.test',
    );
    for (final bad in [
      'https://user:secret@example.test',
      'http://untrusted.test',
      'https://example.test/a',
      'https://example.test?token=private',
    ]) {
      expect(
        ContentLinks.originFor(
          'https://api.test',
          api: 'https://api.test',
          frontend: bad,
        ).origin,
        'https://api.test',
      );
    }
    final url = ContentLinks.messageUrl(
      origin: alias,
      slug: 'my-server',
      kind: 'dm',
      channelId: 'channel-id',
      messageId: 'reply-id',
      parentMessageId: 'parent-id',
    );
    expect(url.path, '/s/my-server/dm/channel-id');
    expect(url.queryParameters, {
      'msg': 'reply-id',
      'thread': 'channel-id:parent-id',
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receive_intent/receive_intent.dart' as intents;
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/content_links.dart';
import 'package:raft_flutter/features/incoming_share_review.dart';

import 'support/mock_attachment_writer.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final slowRecovery in [true, false]) {
    test(
      slowRecovery
          ? 'Android launch receives while old inbox recovery remains pending'
          : 'Android launch precedes old shares even when recovery finishes first',
      () async {
        final root = await Directory.systemTemp.createTemp('raft-cold-share-');
        final old = await Directory('${root.path}/${'a' * 32}').create();
        await File('${old.path}/envelope.json').writeAsString(
          jsonEncode({
            'token': 'a' * 32,
            'created': DateTime.now().millisecondsSinceEpoch,
            'pending': true,
            'text': 'old saved share',
            'files': [],
          }),
        );
        const plugin = MethodChannel('receive_intent');
        const bridge = MethodChannel('test.raft.cold-share');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final launch = Completer<Map<String, dynamic>>();
        final directory = Completer<Directory>();
        final recovering = Completer<void>();
        final receivedLaunch = Completer<void>();
        final launchIntent = {
          'action': 'android.intent.action.SEND',
          'extra': jsonEncode({
            'android.intent.extra.TEXT': 'new launch share',
          }),
        };
        final calls = <String>[];
        messenger.setMockMethodCallHandler(plugin, (_) => launch.future);
        messenger.setMockMethodCallHandler(bridge, (call) async {
          calls.add(call.method);
          return null;
        });
        final original = intents.ReceiveIntent.receivedIntentStream;
        intents.ReceiveIntent.receivedIntentStream = const Stream.empty();
        final service = NativeSharing(
          channel: bridge,
          supported: true,
          ios: false,
          incomingDirectory: () {
            if (!recovering.isCompleted) recovering.complete();
            return directory.future;
          },
        );
        final received = <IncomingShare>[];
        service.registerReceiver((share) {
          received.add(share);
          if (share.text == 'new launch share') receivedLaunch.complete();
        });
        if (!slowRecovery) directory.complete(root);
        final initialization = service.init();
        addTearDown(() async {
          if (!launch.isCompleted) launch.complete(launchIntent);
          if (!directory.isCompleted) directory.complete(root);
          await initialization;
          await service.dispose();
          intents.ReceiveIntent.receivedIntentStream = original;
          messenger.setMockMethodCallHandler(plugin, null);
          messenger.setMockMethodCallHandler(bridge, null);
          await root.delete(recursive: true);
        });
        await recovering.future.timeout(const Duration(seconds: 2));
        if (slowRecovery) {
          launch.complete(launchIntent);
          await receivedLaunch.future.timeout(const Duration(seconds: 2));
          expect(directory.isCompleted, isFalse);
          expect(received.map((s) => s.text), ['new launch share']);
          expect(calls, isNot(contains('sharingReady')));
          directory.complete(root);
        } else {
          // This read is queued after recovery's scan, so its completion proves
          // the old envelope is already available while the initial intent waits.
          expect(
            (await service.inbox.pending()).single.text,
            'old saved share',
          );
          expect(received, isEmpty);
          launch.complete(launchIntent);
        }
        await initialization;
        expect(received.map((s) => s.text), [
          'new launch share',
          'old saved share',
        ]);
        expect(received.last.token, 'a' * 32);
        expect(calls, ['sharingReady']);
        await service.init();
        expect(received.length, 2, reason: 'initialization stays idempotent');
      },
    );
  }

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
      sharing.receive(const IncomingShare(text: 'also queued'));
      final unsubscribe = sharing.registerReceiver(
        (s) => received.add('old:${s.text}'),
      );
      sharing.registerReceiver((s) => received.add(s.text));
      unsubscribe();
      sharing.receive(const IncomingShare(text: 'new'));
      expect(received, ['old:queued', 'old:also queued', 'new']);
      await sharing.dispose();
      sharing.receive(const IncomingShare(text: 'closed'));
      expect(received.length, 3);
    },
  );
  test('plugin byte stream drops late bytes after account changes', () async {
    final stream = StreamController<Uint8List>();
    var cancelled = false;
    stream.onCancel = () => cancelled = true;
    final sharing = NativeSharing(
      supported: true,
      readContent: (_) => stream.stream,
    );
    var authorized = true;
    final read = sharing.readIncoming(
      const IncomingSharedFile('content://proof/item', 'item', 'text/plain', 1),
      authorized: () => authorized,
    );
    final checked = expectLater(read, throwsA(isA<PlatformException>()));
    stream.add(Uint8List.fromList([1]));
    await Future<void>.delayed(Duration.zero);
    authorized = false;
    stream.add(Uint8List.fromList([2]));
    await checked;
    expect(cancelled, isTrue);
    await stream.close();
    await sharing.dispose();
  });

  test('file size is bounded before and during plugin streaming', () async {
    var reads = 0, cancelled = false;
    final stream = StreamController<Uint8List>();
    stream.onCancel = () => cancelled = true;
    final sharing = NativeSharing(
      supported: true,
      readContent: (_) {
        reads++;
        return stream.stream;
      },
    );
    await expectLater(
      sharing.readIncoming(
        const IncomingSharedFile(
          'content://proof/item',
          'item',
          'text/plain',
          NativeSharing.maxIncomingBytes + 1,
        ),
        authorized: () => true,
      ),
      throwsA(isA<PlatformException>()),
    );
    expect(reads, 0);
    final read = sharing.readIncoming(
      const IncomingSharedFile(
        'content://proof/item',
        'item',
        'text/plain',
        null,
      ),
      authorized: () => true,
    );
    final checked = expectLater(read, throwsA(isA<PlatformException>()));
    final chunk = Uint8List(1024 * 1024);
    for (var i = 0; i < 51; i++) {
      stream.add(chunk);
    }
    await checked;
    expect(cancelled, isTrue);
    await stream.close();
    await sharing.dispose();
  });

  test(
    'cold and warm plugin intents are queued in order until a receiver exists',
    () async {
      const plugin = MethodChannel('receive_intent');
      const bridge = MethodChannel('test.raft.share');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Map<String, dynamic> intent(String text) => {
        'action': 'android.intent.action.SEND',
        'extra': '{"android.intent.extra.TEXT":"$text"}',
      };
      messenger.setMockMethodCallHandler(plugin, (_) async => intent('cold'));
      messenger.setMockMethodCallHandler(bridge, (_) async => null);
      final events = StreamController<intents.Intent?>();
      final original = intents.ReceiveIntent.receivedIntentStream;
      intents.ReceiveIntent.receivedIntentStream = events.stream;
      addTearDown(() {
        intents.ReceiveIntent.receivedIntentStream = original;
        messenger.setMockMethodCallHandler(plugin, null);
        messenger.setMockMethodCallHandler(bridge, null);
      });
      final sharing = NativeSharing(channel: bridge, supported: true);
      await sharing.init();
      events.add(intents.Intent.fromMap(intent('warm-1')));
      events.add(intents.Intent.fromMap(intent('warm-2')));
      await Future<void>.delayed(Duration.zero);
      final received = <String?>[];
      sharing.registerReceiver((s) => received.add(s.text));
      expect(received, ['cold', 'warm-1', 'warm-2']);
      await sharing.dispose();
      await events.close();
    },
  );

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
      stagingDirectory: () async => folder,
    );
    final lease = await sharing.prepareAttachment(
      url: 'http://127.0.0.1:${server.port}/file?signature=private',
      filename: '../../proof.txt',
      cancel: CancelToken(),
      authorized: () => true,
      onProgress: (_, _) {},
    );
    expect(await lease!.file.readAsString(), 'private proof bytes');
    // The traversal is stripped: the file is proof.txt inside the staging
    // folder (path checks that work with either separator).
    expect(p.basename(lease.file.path), 'proof.txt');
    expect(p.isWithin(folder.path, lease.file.path), isTrue);
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
      mockAttachmentWriter();
      final folder = await Directory.systemTemp.createTemp('raft-png-export');
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final sharing = NativeSharing(
        supported: true,
        stagingDirectory: () async => folder,
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
        stagingDirectory: () async => folder,
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
        stagingDirectory: () async => folder,
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

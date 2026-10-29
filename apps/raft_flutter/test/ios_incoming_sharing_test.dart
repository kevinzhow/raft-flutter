import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/native_sharing.dart';

void main() {
  late Directory root;
  const channel = MethodChannel('test/ios-incoming-sharing');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-ios-sharing-test-');
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  Future<void> envelope(String token, String text) async {
    final folder = await Directory('${root.path}/$token').create();
    await File('${folder.path}/envelope.json').writeAsString(
      jsonEncode({
        'token': token,
        'created': DateTime.now().millisecondsSinceEpoch,
        'pending': true,
        'text': text,
        'files': [],
      }),
    );
  }

  NativeSharing sharing({Future<Directory> Function()? directory}) =>
      NativeSharing(
        channel: channel,
        supported: true,
        ios: true,
        incomingDirectory: directory ?? () async => root,
      );

  test('share wake links accept only an opaque inbox token', () {
    expect(
      NativeSharing.isIncomingShareLink(Uri.parse('raft://share/${'a' * 32}')),
      isTrue,
    );
    for (final location in [
      'raft://share/not-a-token',
      'raft://share/${'a' * 32}/item-0',
      'raft://share/${'a' * 32}?path=/tmp/private',
      'raft://share/${'a' * 32}#fragment',
      'raft://user@share/${'a' * 32}',
      'raft://share:80/${'a' * 32}',
      'https://share/${'a' * 32}',
      'raft://oauth/callback',
    ]) {
      expect(
        NativeSharing.isIncomingShareLink(Uri.parse(location)),
        isFalse,
        reason: location,
      );
    }
  });

  test(
    'iOS cold recovery, repeated resume and later shares preserve identity',
    () async {
      await envelope('a' * 32, 'first');
      final service = sharing();
      final received = <IncomingShare>[];
      service.registerReceiver(received.add);
      await service.init();
      await Future.wait([service.resume(), service.resume()]);
      expect(received.map((s) => s.text), ['first']);
      await envelope('b' * 32, 'second');
      await service.resume();
      expect(received.map((s) => s.text), ['first', 'second']);
      await service.dispose();
      await envelope('c' * 32, 'closed');
      await service.resume();
      expect(received.length, 2);
    },
  );

  test(
    'extension shares queued before receiver attachment survive recovery',
    () async {
      await envelope('d' * 32, 'waiting for login');
      final service = sharing();
      await service.init();
      await service.resume();
      final received = <String?>[];
      service.registerReceiver((s) => received.add(s.text));
      expect(received, ['waiting for login']);
      await service.dispose();
    },
  );

  test('a directory failure can recover on the next iOS resume', () async {
    var available = false;
    await envelope('e' * 32, 'recover');
    final service = sharing(
      directory: () async {
        if (!available) throw const FileSystemException('unavailable');
        return root;
      },
    );
    final received = <String?>[];
    service.registerReceiver((s) => received.add(s.text));
    await service.init();
    expect(received, isEmpty);
    available = true;
    await service.resume();
    expect(received, ['recover']);
    await service.dispose();
  });

  test(
    'dispose prevents late directory recovery from delivering a share',
    () async {
      await envelope('f' * 32, 'late');
      final directory = Completer<Directory>();
      final service = sharing(directory: () => directory.future);
      final received = <IncomingShare>[];
      service.registerReceiver(received.add);
      final initialization = service.init();
      await service.dispose();
      directory.complete(root);
      await initialization;
      expect(received, isEmpty);
    },
  );

  test(
    'iOS uses the native shared container and never Android intents',
    () async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'incomingDirectory') return root.path;
            throw MissingPluginException();
          });
      await envelope('1' * 32, 'shared container');
      final service = NativeSharing(
        channel: channel,
        supported: true,
        ios: true,
      );
      final received = <String?>[];
      service.registerReceiver((s) => received.add(s.text));
      await service.init();
      expect(received, ['shared container']);
      expect(methods, isNotEmpty);
      expect(methods, everyElement('incomingDirectory'));
      await service.dispose();
    },
  );

  test(
    'native Swift producer hands exact file bytes to the ordinary draft inbox',
    () async {
      final binary = '${root.path}/producer';
      final compile = await Process.run('xcrun', [
        'swiftc',
        'ios/Shared/ShareInboxWriter.swift',
        'ios/ShareInboxTests/main.swift',
        '-o',
        binary,
      ]);
      expect(
        compile.exitCode,
        0,
        reason: '${compile.stdout}\n${compile.stderr}',
      );
      final nativeRoot = Directory('${root.path}/native-inbox');
      final run = await Process.run(binary, [nativeRoot.path]);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
      expect(run.stdout, contains('native inbox checks passed'));
      final service = sharing(directory: () async => nativeRoot);
      final pending = await service.inbox.pending();
      expect(pending.length, 1);
      final share = pending.single;
      expect(share.text, 'https://example.test/page');
      expect(share.files.single.filename, 'photo.png');
      expect(
        await service.inbox.claim(share.token!, 'https://example.test', 'user'),
        isTrue,
      );
      final file = await service.inbox.restore(
        {'token': share.token, 'file': 'item-0'},
        'https://example.test',
        'user',
      );
      expect(file, isNotNull);
      expect(await file!.openRead().expand((chunk) => chunk).toList(), [
        1,
        2,
        3,
        4,
      ]);
      await service.inbox.complete(share.token!);
      expect(await service.inbox.pending(), isEmpty);
      await service.dispose();
    },
    skip: !Platform.isMacOS,
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/attachment_preview_files.dart';
import 'package:raft_flutter/platform/cache_hygiene.dart';
import 'package:raft_flutter/platform/cache_staging.dart';
import 'package:raft_flutter/platform/video_cache.dart';
import 'package:raft_flutter/platform/native_sharing.dart';

import 'support/mock_attachment_writer.dart';

const _origin = 'https://x.invalid';

AttachmentImageStoreKey key(
  String id, {
  String account = 'alice',
  String kind = 'file',
}) => AttachmentImageStoreKey(
  identity: AttachmentImageKey.identityOf(_origin, account, 's1'),
  channelId: 'c1',
  entry: jsonEncode([id, 'rev', kind]),
);

Uint8List bytes(int length) => Uint8List.fromList(List.filled(length, 7));

Session session(String? userId) => Session(
  accessToken: 'a',
  refreshToken: 'r',
  cachedUser: userId == null ? null : {'id': userId},
);

/// Marks [path] as last changed [age] ago (portable `touch -t`).
Future<void> age(String path, Duration age) async {
  final t = DateTime.now().subtract(age);
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}'
      '${two(t.minute)}.${two(t.second)}';
  final result = await Process.run('touch', ['-t', stamp, path]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

void main() {
  late Directory root;
  late DateTime now;
  AttachmentDiskCache open({
    int previewVersion = attachmentPreviewFormatVersion,
  }) => AttachmentDiskCache(
    () async => root,
    clock: () => now,
    previewFormatVersion: previewVersion,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-hygiene');
    now = DateTime.now();
  });
  tearDown(() => root.delete(recursive: true));

  group('idle expiry', () {
    test('an entry unopened for 30 days is a miss and is deleted', () async {
      final cache = open();
      await cache.write(key('a'), bytes(10));
      await cache.write(key('b'), bytes(20));
      expect(await cache.sizeBytes(), 30);

      now = now.add(const Duration(days: 29));
      expect(await cache.contains(key('a')), isTrue);
      expect(await cache.read(key('a')), bytes(10)); // restarts a's clock

      now = now.add(const Duration(days: 2)); // b idle 31 days, a 2 days
      expect(await cache.contains(key('b')), isFalse);
      expect(await cache.read(key('b')), isNull);
      expect(await cache.read(key('a')), bytes(10));
      expect(await cache.sizeBytes(), 10);
      expect(await cache.entryCount(), 1);
    });

    test('file entries expire too, unless a preview holds them', () async {
      final cache = open();
      Future<void> download(File f, cancel, progress) =>
          f.writeAsBytes(bytes(5));
      final held = await cache.fetchFile(
        key('pdf'),
        filename: 'a.pdf',
        download: download,
      );
      final loose = await cache.fetchFile(
        key('pdf2'),
        filename: 'b.pdf',
        download: download,
      );
      loose!.release();
      now = now.add(const Duration(days: 31));
      expect(await cache.containsFile(key('pdf2'), filename: 'b.pdf'), isFalse);
      expect(await cache.openFile(key('pdf2'), filename: 'b.pdf'), isNull);
      // Still pinned: in use is not idle.
      expect(await cache.containsFile(key('pdf'), filename: 'a.pdf'), isTrue);
      held!.release();
      expect(await cache.sizeBytes(), 5);
    });

    test('the start-up scan deletes expired private entries only', () async {
      final first = open();
      await first.write(key('old'), bytes(10));
      await first.write(key('older', account: 'bob'), bytes(10));
      await first.writePublic('avatar', bytes(4));
      now = now.add(const Duration(days: 31));
      final second = open();
      await second.warm();
      expect(await second.entryCount(), 1);
      expect(await second.sizeBytes(), 4);
      expect(await second.readPublic('avatar'), bytes(4));
      final left = [
        await for (final e in root.list(recursive: true))
          if (e is File) e,
      ];
      expect(left, hasLength(1));
      // The emptied account folders are gone too.
      final accounts = Directory(
        p.join(root.path, 'raft-attachments', 'v2'),
      ).listSync();
      expect(accounts, isEmpty);
    });

    test('the scan keeps what was opened within 30 days', () async {
      final first = open();
      await first.write(key('a'), bytes(10));
      now = now.add(const Duration(days: 29));
      final second = open();
      await second.warm();
      expect(await second.entryCount(), 1);
    });
  });

  group('preview entries', () {
    test('a different preview format version is a miss', () async {
      await open().writePreview(key('d', kind: 'preview'), bytes(8));
      final next = open(previewVersion: attachmentPreviewFormatVersion + 1);
      expect(await next.readPreview(key('d', kind: 'preview')), isNull);
      expect(await next.entryCount(), 0);
    });

    test('same version round-trips the payload', () async {
      final cache = open();
      final payload = Uint8List.fromList(utf8.encode('{"data":1}\n'));
      await cache.writePreview(key('d', kind: 'preview'), payload);
      expect(await cache.readPreview(key('d', kind: 'preview')), payload);
    });

    test(
      '14 days after it was stored it is refetched, opened or not',
      () async {
        final cache = open();
        final k = key('d', kind: 'html');
        await cache.writePreview(k, bytes(8));
        now = now.add(const Duration(days: 10));
        expect(await cache.readPreview(k), bytes(8)); // opening is not storing
        now = now.add(const Duration(days: 5)); // 15 days since stored
        expect(await cache.readPreview(k), isNull);
        expect(await cache.contains(k), isFalse);
      },
    );

    test('an entry without the header is a miss', () async {
      final cache = open();
      final k = key('d', kind: 'preview');
      await cache.write(k, bytes(8));
      expect(await cache.readPreview(k), isNull);
      expect(await cache.contains(k), isFalse);
    });
  });

  group('orphan accounts', () {
    test('only accounts without a saved session are removed', () async {
      final cache = open();
      await cache.write(key('a'), bytes(10));
      await cache.write(key('b', account: 'bob'), bytes(20));
      await cache.write(key('c', account: 'carol'), bytes(30));
      await cache.writePublic('avatar', bytes(4));

      final removed = await removeOrphanAttachmentAccounts(
        cache,
        () async => {_origin: session('alice')},
      );
      expect(removed, 2);
      expect(await cache.read(key('a')), bytes(10));
      expect(await cache.read(key('b', account: 'bob')), isNull);
      expect(await cache.read(key('c', account: 'carol')), isNull);
      expect(await cache.sizeBytes(), 14);
      expect(
        await cache.sizeBytes(namespace: AttachmentCacheNamespace.public),
        4,
      );
      expect(await cache.readPublic('avatar'), bytes(4));
      final folders = Directory(
        p.join(root.path, 'raft-attachments', 'v2'),
      ).listSync();
      expect(folders, hasLength(1));
    });

    test(
      'several saved accounts all stay; a trailing slash is the same origin',
      () async {
        final cache = open();
        await cache.write(key('a'), bytes(10));
        await cache.write(key('b', account: 'bob'), bytes(20));
        final removed = await removeOrphanAttachmentAccounts(
          cache,
          () async => {'$_origin/': session('alice'), _origin: session('bob')},
        );
        expect(removed, 0);
        expect(await cache.entryCount(), 2);
      },
    );

    test('an unreadable or incomplete session list deletes nothing', () async {
      final cache = open();
      await cache.write(key('a'), bytes(10));
      expect(
        await removeOrphanAttachmentAccounts(
          cache,
          () async => throw StateError('keychain locked'),
        ),
        0,
      );
      expect(
        await removeOrphanAttachmentAccounts(
          cache,
          () async => {_origin: session(null)},
        ),
        0,
      );
      expect(await cache.entryCount(), 1);
    });

    test('without any saved session every account folder goes', () async {
      final cache = open();
      await cache.write(key('a'), bytes(10));
      expect(await removeOrphanAttachmentAccounts(cache, () async => {}), 1);
      expect(await cache.entryCount(), 0);
      expect(await cache.sizeBytes(), 0);
    });
  });

  group('orphan video accounts', () {
    Directory folderOf(String origin, String user) =>
        Directory(p.join(root.path, VideoCacheAccount.segmentOf(origin, user)))
          ..createSync(recursive: true);

    setUp(() => VideoCache.debugRoot = root);
    tearDown(() => VideoCache.debugRoot = null);

    test('only accounts without a saved session lose their videos', () async {
      final alice = folderOf(_origin, 'alice');
      final bob = folderOf(_origin, 'bob');
      final removed = await removeOrphanVideoAccounts(
        () async => {'$_origin/': session('alice')},
      );
      expect(removed, 1);
      expect(alice.existsSync(), isTrue);
      expect(bob.existsSync(), isFalse);
    });

    test('an unreadable or incomplete session list deletes nothing', () async {
      final bob = folderOf(_origin, 'bob');
      expect(
        await removeOrphanVideoAccounts(() async => throw StateError('keychain')),
        0,
      );
      expect(
        await removeOrphanVideoAccounts(() async => {_origin: session(null)}),
        0,
      );
      expect(bob.existsSync(), isTrue);
    });

    test('the start-up pass covers videos too, and starts no proxy', () async {
      final bob = folderOf(_origin, 'bob');
      final cache = open();
      await runStartupCacheHygiene(
        cache: cache,
        savedSessions: () async => {_origin: session('alice')},
      );
      expect(bob.existsSync(), isFalse);
      expect(VideoCache.debugStarted, 0);
    });
  });

  group('files removed underneath', () {
    test('the totals are corrected on the next touch', () async {
      final cache = open();
      await cache.write(key('a'), bytes(10));
      await cache.write(key('b'), bytes(20));
      Future<File> fileOf(int size) async =>
          (await root
                  .list(recursive: true)
                  .where((e) => e is File)
                  .cast<File>()
                  .toList())
              .firstWhere((f) => f.lengthSync() == size);
      await (await fileOf(10)).delete();
      expect(await cache.sizeBytes(), 30); // not noticed yet
      expect(await cache.contains(key('a')), isFalse); // noticed on touch
      expect(await cache.sizeBytes(), 20);
      await (await fileOf(20)).delete();
      expect(await cache.read(key('b')), isNull);
      expect(await cache.sizeBytes(), 0);
      expect(await cache.entryCount(), 0);
    });

    test('a whole account folder removed underneath', () async {
      final cache = open();
      await cache.write(key('a'), bytes(10));
      await Directory(
        p.join(root.path, 'raft-attachments'),
      ).delete(recursive: true);
      expect(await cache.read(key('a')), isNull);
      expect(await cache.sizeBytes(), 0);
      await cache.write(key('a'), bytes(10)); // and it can be written again
      expect(await cache.read(key('a')), bytes(10));
    });
  });

  group('staging sweep', () {
    late Directory staging, temp;
    setUp(() async {
      staging = await Directory(
        p.join(root.path, 'cache', 'staging'),
      ).create(recursive: true);
      temp = await Directory(p.join(root.path, 'tmp')).create();
    });

    Future<Directory> folder(
      Directory parent,
      String name, {
      Duration old = Duration.zero,
    }) async {
      final dir = await Directory(
        p.join(parent.path, name),
      ).create(recursive: true);
      final file = await File(p.join(dir.path, 'f.bin')).writeAsBytes([1]);
      if (old > Duration.zero) {
        await age(file.path, old);
        await age(dir.path, old);
      }
      return dir;
    }

    test('removes staging older than an hour, keeps fresh staging', () async {
      const stale = Duration(hours: 3);
      final oldPreview = await folder(
        staging,
        'raft-previews/preview-a',
        old: stale,
      );
      final freshPreview = await folder(staging, 'raft-previews/preview-b');
      final oldShare = await folder(staging, 'raft-share/share-1', old: stale);
      final freshShare = await folder(staging, 'raft-share/share-2');
      final oldAttachment = await folder(
        staging,
        'raft-attachment-1',
        old: stale,
      );
      final freshAttachment = await folder(staging, 'raft-attachment-2');
      final oldExport = await folder(staging, 'raft-export-1', old: stale);
      final oldGallery = await folder(staging, 'raft-gallery-1', old: stale);
      final unrelated = await folder(staging, 'something-else', old: stale);

      final removed = await sweepStaging(staging: staging);
      expect(removed, 5);
      for (final gone in [
        oldPreview,
        oldShare,
        oldAttachment,
        oldExport,
        oldGallery,
      ]) {
        expect(gone.existsSync(), isFalse, reason: gone.path);
      }
      for (final kept in [
        freshPreview,
        freshShare,
        freshAttachment,
        unrelated,
      ]) {
        expect(kept.existsSync(), isTrue, reason: kept.path);
      }
    });

    test('a folder with a recently written file is still in use', () async {
      final dir = await folder(
        staging,
        'raft-attachment-9',
        old: const Duration(hours: 3),
      );
      await File(p.join(dir.path, 'f.bin')).writeAsBytes([1, 2]); // now
      await age(dir.path, const Duration(hours: 3));
      expect(await sweepStaging(staging: staging), 0);
      expect(dir.existsSync(), isTrue);
    });

    test('never touches raft-incoming, however old', () async {
      const stale = Duration(days: 30);
      final incoming = await folder(temp, 'raft-incoming/share-x', old: stale);
      final incomingInStaging = await folder(
        staging,
        'raft-incoming/share-y',
        old: stale,
      );
      await age(p.dirname(incoming.path), stale);
      await sweepStaging(staging: staging, legacyTemporary: temp);
      expect(incoming.existsSync(), isTrue);
      expect(incomingInStaging.existsSync(), isTrue);
    });

    test(
      'also clears what earlier versions left in the system temp dir',
      () async {
        const stale = Duration(hours: 2);
        final oldPreview = await folder(
          temp,
          'raft-previews/preview-z',
          old: stale,
        );
        final oldExport = await folder(temp, 'raft-export-5', old: stale);
        final other = await folder(temp, 'not-ours', old: stale);
        final removed = await sweepStaging(
          staging: staging,
          legacyTemporary: temp,
        );
        expect(removed, 2);
        expect(oldPreview.existsSync(), isFalse);
        expect(oldExport.existsSync(), isFalse);
        expect(other.existsSync(), isTrue);
      },
    );

    test('a missing directory is not an error', () async {
      expect(
        await sweepStaging(
          staging: Directory(p.join(root.path, 'nope')),
          legacyTemporary: Directory(p.join(root.path, 'nope2')),
        ),
        0,
      );
    });
  });

  group('staging location', () {
    late Directory appCache, systemTemp;
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      appCache = await Directory(p.join(root.path, 'app-cache')).create();
      systemTemp = await Directory(p.join(root.path, 'sys-tmp')).create();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => switch (call.method) {
              'getApplicationCacheDirectory' => appCache.path,
              'getTemporaryDirectory' => systemTemp.path,
              _ => null,
            },
          );
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );

    test('lives in <app cache>/staging', () async {
      expect(
        (await cacheStagingDirectory()).path,
        p.join(appCache.path, 'staging'),
      );
    });

    test('share-sheet copies are staged there, not in the temp dir', () async {
      final sharing = NativeSharing(supported: true);
      final lease = await sharing.prepareBytes(
        bytes(3),
        filename: 'x.png',
        authorized: () => true,
      );
      addTearDown(() async => lease?.dispose());
      expect(
        p.isWithin(
          p.join(appCache.path, 'staging', 'raft-share'),
          lease!.file.path,
        ),
        isTrue,
      );
      expect(systemTemp.listSync(), isEmpty);
    });

    test('preview inputs and save copies are staged there too', () async {
      mockAttachmentWriter();
      final files = AttachmentFiles(
        pickDestination: (_, _) async => p.join(root.path, 'saved.bin'),
        dio: Dio()..httpClientAdapter = _Bytes([1, 2, 3]),
      );
      await files.saveBytes(
        bytes: bytes(3),
        filename: 'x.bin',
        mimeType: 'application/octet-stream',
        authorized: () => true,
      );
      // The export folder is removed after the save; the staging root, not
      // the system temp dir, is where it was created.
      expect(Directory(p.join(appCache.path, 'staging')).existsSync(), isTrue);
      expect(systemTemp.listSync(), isEmpty);
      final previews = AttachmentPreviewFiles(
        dio: Dio()..httpClientAdapter = _Bytes([1, 2, 3]),
      );
      final lease = await previews.load(
        'https://x.invalid/a.pdf',
        'a.pdf',
        cancel: CancelToken(),
        authorized: () => true,
      );
      addTearDown(() async => lease?.dispose());
      expect(
        p.isWithin(
          p.join(appCache.path, 'staging', 'raft-previews'),
          lease!.file.path,
        ),
        isTrue,
      );
      expect(systemTemp.listSync(), isEmpty);
    });

    test('received shares stay in the temp dir fallback', () async {
      final sharing = NativeSharing(supported: false);
      final incoming = await sharing.inbox.directory();
      expect(incoming.path, p.join(systemTemp.path, 'raft-incoming'));
    });
  });
}

class _Bytes implements HttpClientAdapter {
  _Bytes(this.data);
  final List<int> data;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(data, 200);
}

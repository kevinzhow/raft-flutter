import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';

/// Sign-out removes the account's cached image bytes on every server it
/// used; other accounts' entries stay.
void main() {
  test('purgeAccount deletes one account on every server it used, others stay', () async {
    final directory = await Directory.systemTemp.createTemp('raft-images');
    addTearDown(() => directory.delete(recursive: true));
    final disk = AttachmentDiskCache(() async => directory);
    final previous = AttachmentDiskCache.installed;
    AttachmentDiskCache.installed = disk;
    addTearDown(() => AttachmentDiskCache.installed = previous);
    AttachmentImageStoreKey key(String principal, String server) =>
        AttachmentImageStoreKey(
          identity: AttachmentImageKey.identityOf(
            'https://example.invalid',
            principal,
            server,
          ),
          channelId: 'c1',
          entry: jsonEncode(['a1', 1, 'thumb']),
        );
    final bytes = Uint8List.fromList([1, 2, 3]);
    await disk.write(key('alice', 's1'), bytes);
    await disk.write(key('alice', 's2'), bytes);
    await disk.write(key('bob', 's1'), bytes);

    await AttachmentDiskCache.purgeInstalledAccount(
      'https://example.invalid',
      'alice',
    );

    expect(await disk.read(key('alice', 's1')), isNull);
    expect(await disk.read(key('alice', 's2')), isNull);
    expect(await disk.read(key('bob', 's1')), bytes);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/attachment_retention_index.dart';

const _metadata = <String, dynamic>{
  'id': 'image',
  'mimeType': 'image/png',
  'width': 16,
  'height': 16,
};

class _Fixture {
  _Fixture() {
    owner = AttachmentRetentionIndex(
      ledgerRevision: () => revision,
      stateStamp: () => stamp,
      scope: () => scope,
      channels: () => channels,
      dms: () => dms,
      revokedChannels: () => revoked,
      canView: (row) {
        checks.add(row.id);
        return !denied.contains(row.id);
      },
      messages: (id) {
        reads.add(id);
        return rows[id] ?? [];
      },
    );
  }
  late final AttachmentRetentionIndex owner;
  int revision = 0, stamp = 0;
  AttachmentImageScope scope = const AttachmentImageScope(
    origin: 'https://example.invalid',
    principal: 'alice',
    server: 'server',
    generation: 1,
    role: 'owner',
  );
  List<RaftChannel> channels = [
        RaftChannel({'id': 'channel'}),
      ],
      dms = [];
  final revoked = <String>{}, denied = <String>{};
  final reads = <String>[], checks = <String>[];
  final rows = <String, List<Map<String, dynamic>>>{
    'channel': [
      {
        'id': 'host',
        'attachments': [_metadata],
      },
    ],
  };
  AttachmentImageKey key({
    String channel = 'channel',
    Map<String, dynamic> metadata = _metadata,
    String rendition = 'original',
  }) => AttachmentImageKey.fromMetadata(
    scope: scope,
    channelId: channel,
    metadata: metadata,
    rendition: rendition,
  );
}

void main() {
  test('admission-only invalidation does not read the history port again', () {
    final f = _Fixture();
    expect(f.owner.retains(f.key()), isTrue);
    expect(f.reads, ['channel', 'channel']);
    f.checks.clear();
    f.reads.clear();
    f.stamp++;
    expect(f.owner.retains(f.key()), isTrue);
    expect(f.checks, ['channel']);
    expect(f.reads, isEmpty);
    expect(f.owner.debugBuilds, 1);
    f.channels = [
      RaftChannel({'id': 'channel', 'name': 'renamed'}),
    ];
    expect(f.owner.retains(f.key()), isTrue);
    expect(f.reads, isEmpty);
    expect(f.owner.debugBuilds, 1);
  });

  test(
    'two parent references read a shared thread only once per index build',
    () {
      final f = _Fixture();
      f.rows['channel'] = [
        {'id': 'host', 'threadId': 'thread'},
        {'id': 'second', 'threadId': 'thread'},
      ];
      f.rows['thread'] = [
        {
          'id': 'reply',
          'attachments': [_metadata],
        },
      ];
      expect(f.owner.retains(f.key(channel: 'thread')), isTrue);
      expect(f.reads, ['channel', 'channel', 'thread']);
      expect(f.owner.debugBuilds, 1);
      f.revision++;
      expect(f.owner.retains(f.key(channel: 'thread')), isTrue);
      expect(f.reads.where((id) => id == 'thread'), hasLength(2));
    },
  );

  test(
    'revoked and denied ids are excluded while non-string file ids are ignored',
    () {
      final f = _Fixture();
      f.channels.addAll([
        RaftChannel({'id': 'revoked'}),
        RaftChannel({'id': 'denied'}),
      ]);
      f.revoked.add('revoked');
      f.denied.add('denied');
      f.rows['channel']!.add({
        'id': 'invalid',
        'attachments': [
          {'id': 7},
        ],
      });
      expect(f.owner.retains(f.key()), isTrue);
      expect(f.owner.retains(f.key(channel: 'revoked')), isFalse);
      expect(f.owner.retains(f.key(channel: 'denied')), isFalse);
      expect(f.reads, ['channel', 'channel']);
      expect(f.checks, ['channel', 'denied']);
    },
  );

  test('scope changes rebuild and current rendition participates in canonical matching', () {
    final f = _Fixture();
    expect(f.owner.retains(f.key(rendition: 'thumbnail')), isTrue);
    expect(
      f.owner.retains(f.key(metadata: {..._metadata, 'contentVersion': 'new'})),
      isFalse,
    );
    f.scope = const AttachmentImageScope(
      origin: 'https://example.invalid',
      principal: 'bob',
      server: 'server',
      generation: 2,
      role: 'owner',
    );
    expect(f.owner.retains(f.key()), isTrue);
    expect(f.owner.debugBuilds, 2);
    // Media performs scope authorization before calling this metadata index.
    expect(f.reads, ['channel', 'channel', 'channel', 'channel']);
  });
}

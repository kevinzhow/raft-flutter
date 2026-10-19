import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/shared_draft_attachment.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

import 'app_global_server_selector_test.dart' show RootCache;

class _Transfer {
  _Transfer(this.channel, this.cancellation, this.progress);
  final String channel;
  final UploadCancellation cancellation;
  final void Function(int, int)? progress;
  final response = Completer<List<Map<String, dynamic>>>();
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://upload-lifetime.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }

  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final transfers = <_Transfer>[];
  final uploadedMimeTypes = <String?>[];
  bool autoComplete = false;
  Future<void>? closing;

  static final channelRows = [
    for (final id in ['c1', 'c2'])
      RaftChannel({'id': id, 'name': id, 'joined': true, 'type': 'channel'}),
  ];

  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels') return channelRows.map((c) => c.json).toList();
    if (path == '/channels/unread') return {'channels': <String, int>{}};
    if (path == '/attachments/upload-capabilities') return {'maxBytes': 1024};
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path.startsWith('/messages/channel/')) {
      final channel = path.split('/').last;
      return {
        'messages': [
          {
            'id': 'message-$channel',
            'channelId': channel,
            'seq': '1',
            'senderId': 'alice',
            'senderName': 'Alice',
            'content': 'Message body $channel',
            'createdAt': '2026-10-01T00:00:00Z',
          },
        ],
        'hasMore': false,
        'hasNewer': false,
      };
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '1', 'readStateVersion': 1};
    }
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> upload(
    String channelId,
    Uint8List bytes,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) {
    final transfer = _Transfer(channelId, cancellation!, onProgress);
    transfers.add(transfer);
    uploadedMimeTypes.add(mimeType);
    if (autoComplete) {
      transfer.response.complete([
        {'id': 'file-${transfers.length}'},
      ]);
    }
    return transfer.response.future;
  }

  @override
  Future<void> dispose() => closing ??= close();

  Future<void> close() async {
    await stream.close();
    await super.dispose();
  }
}

class _HeldDraftCache extends RootCache {
  final entered = Completer<void>();
  final result = Completer<void>();

  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (kind == 'draft' && !entered.isCompleted) {
      entered.complete();
      await result.future;
    }
    await super.write(origin, principal, server, kind, id, value);
  }
}

WorkspaceController _workspace(_Client client, {RootCache? cache}) {
  final w = WorkspaceController(client, cache: cache)
    ..server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': 'lab'})
    ..channels = [..._Client.channelRows]
    ..channel = _Client.channelRows.first
    ..loading = false
    ..messageDomain.state.channelLoading = false;
  w.messageDomain.ledger.switchServer('s1');
  return w;
}

void main() {
  test(
    'settled upload progress cannot overwrite its retry operation',
    () async {
      final client = _Client();
      final w = _workspace(client);
      final pending = <Future<void>>[];
      try {
        pending.add(w.attachUpload('retry.txt', Uint8List.fromList([1])));
        final draft = w.uploads().single;
        client.transfers.first.response.completeError(
          const RaftApiException('Synthetic upload failure'),
        );
        await pending.first;
        pending.add(w.retryUpload(draft));
        client.transfers.last.progress!(25, 100);
        client.transfers.first.progress!(99, 100);
        expect(
          draft.progress,
          .25,
          reason: 'a settled operation no longer owns the draft',
        );
        client.transfers.last.response.complete([
          {'id': 'retried-file'},
        ]);
        await pending.last;
        expect(draft.id, 'retried-file');
      } finally {
        for (final transfer in client.transfers) {
          if (!transfer.response.isCompleted) {
            transfer.response.complete([
              {'id': 'cleanup-file'},
            ]);
          }
        }
        await Future.wait(pending);
        w.dispose();
        await client.dispose();
      }
    },
  );

  for (final revokeChannel in [false, true]) {
    for (final outcome in ['success', 'failure', 'cancel']) {
      test(
        'late $outcome from retired ${revokeChannel ? 'channel' : 'server'} cannot settle or notify the new upload',
        () async {
          final client = _Client();
          final w = _workspace(client);
          final pending = <Future<void>>[];
          try {
            pending.add(w.attachUpload('same.txt', Uint8List.fromList([1])));
            final old = client.transfers.single;
            if (revokeChannel) {
              client.stream.add(
                const RaftEvent('channel:removed', {'channelId': 'c1'}),
              );
              await w.selectChannel(_Client.channelRows.last);
            } else {
              await w.selectServer(
                RaftRecord({'id': 's2', 'slug': 'second', 'role': 'owner'}),
              );
            }
            pending.add(w.attachUpload('same.txt', Uint8List.fromList([2])));
            final next = w.uploads().single;
            var scopeNotifications = 0, workspaceNotifications = 0;
            final signal = w.draftChanges();
            void scopeChanged() => scopeNotifications++;
            void workspaceChanged() => workspaceNotifications++;
            signal.addListener(scopeChanged);
            w.addListener(workspaceChanged);
            try {
              expect(old.cancellation.cancelled, true);
              old.progress!(99, 100);
              if (outcome == 'failure') {
                old.response.completeError(
                  const RaftApiException('Old operation failed'),
                );
              } else {
                if (outcome == 'cancel') old.cancellation.cancel();
                old.response.complete([
                  {'id': 'old-file-must-not-win'},
                ]);
              }
              await pending.first;
              expect(w.uploads().single, same(next));
              expect(next.id, isNull);
              expect(next.error, isNull);
              expect(next.progress, 0);
              expect(scopeNotifications, 0);
              expect(workspaceNotifications, 0);
              client.transfers.last.progress!(50, 100);
              expect(next.progress, .5);
              expect(scopeNotifications, 1);
              expect(workspaceNotifications, 0);
              client.transfers.last.response.complete([
                {'id': 'new-file'},
              ]);
              await pending.last;
              expect(w.uploads().single.id, 'new-file');
            } finally {
              signal.removeListener(scopeChanged);
              w.removeListener(workspaceChanged);
            }
          } finally {
            for (final transfer in client.transfers) {
              if (!transfer.response.isCompleted) {
                transfer.response.complete([
                  {'id': 'cleanup-file'},
                ]);
              }
            }
            await Future.wait(pending);
            w.dispose();
            await client.dispose();
          }
        },
      );
    }
  }

  test('retired selection completion cannot notify a reused scope', () async {
    final client = _Client();
    final w = _workspace(client);
    final pending = <Future<void>>[];
    try {
      pending.add(
        w.attachSelection([
          (name: 'old-first.txt', bytes: Uint8List.fromList([1])),
          (name: 'old-second.txt', bytes: Uint8List.fromList([2])),
        ], text: (key, args) => key),
      );
      for (var i = 0; i < 20 && client.transfers.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(client.transfers, hasLength(1));
      final old = client.transfers.single;
      await w.selectServer(
        RaftRecord({'id': 's2', 'slug': 'second', 'role': 'owner'}),
      );
      pending.add(w.attachUpload('new.txt', Uint8List.fromList([3])));
      final next = w.uploads().single;
      var notifications = 0;
      final signal = w.draftChanges();
      void changed() => notifications++;
      signal.addListener(changed);
      try {
        old.response.complete([
          {'id': 'old-file'},
        ]);
        await pending.first;
        expect(w.uploads(), [same(next)]);
        expect(notifications, 0);
        expect(client.transfers, hasLength(2));
      } finally {
        signal.removeListener(changed);
      }
    } finally {
      for (final transfer in client.transfers) {
        if (!transfer.response.isCompleted) {
          transfer.response.complete([
            {'id': 'cleanup-file'},
          ]);
        }
      }
      await Future.wait(pending);
      w.dispose();
      await client.dispose();
    }
  });

  for (final channel in [false, true]) {
    for (final fail in [false, true]) {
      test(
        'retired shared staging ${fail ? 'failure' : 'success'} cannot change the new ${channel ? 'channel' : 'server'} draft',
        () async {
          final client = _Client(), cache = _HeldDraftCache();
          final w = _workspace(client, cache: cache);
          Future<Object?>? staging;
          try {
            w.drafts['c1'] = 'Original authored text';
            staging = w
                .stageSharedDraft(
                  'Incoming caption',
                  [],
                  sourceToken: 'old-share',
                )
                .then<Object?>((_) => null, onError: (Object e) => e);
            await cache.entered.future;
            if (channel) {
              client.stream.add(
                const RaftEvent('channel:removed', {'channelId': 'c1'}),
              );
            } else {
              w.revokeServer('s1');
            }
            w.drafts['c1'] = 'New authored text';
            var notifications = 0;
            final signal = w.composer.changes('c1');
            void changed() => notifications++;
            signal.addListener(changed);
            try {
              if (fail) {
                cache.result.completeError(
                  StateError('Synthetic disk failure'),
                );
              } else {
                cache.result.complete();
              }
              final error = await staging;
              expect(error, fail ? isStateError : isNull);
              expect(w.drafts['c1'], 'New authored text');
              expect(notifications, 0);
            } finally {
              signal.removeListener(changed);
            }
          } finally {
            if (!cache.result.isCompleted) cache.result.complete();
            await staging;
            await w.flushCache();
            w.dispose();
            await client.dispose();
          }
        },
      );
    }
  }

  test(
    'failed shared staging keeps text edited while disk write was pending',
    () async {
      final client = _Client(), cache = _HeldDraftCache();
      final w = _workspace(client, cache: cache);
      final signal = w.draftChanges();
      var observedFiles = <String>[];
      void observeFiles() {
        observedFiles = w.uploads().map((file) => file.filename).toList();
      }

      signal.addListener(observeFiles);
      Future<Object?>? staging;
      try {
        w.drafts['c1'] = 'Original';
        staging = w
            .stageSharedDraft('Incoming caption', [
              SharedDraftAttachment(
                reference: const {'token': 'share', 'file': 'incoming.txt'},
                filename: 'incoming.txt',
                mimeType: 'text/plain',
                sizeBytes: 1,
                openRead: () => Stream.value([1]),
                release: () async {},
              ),
            ], sourceToken: 'share')
            .then<Object?>((_) => null, onError: (Object e) => e);
        await cache.entered.future;
        w.saveDraft('User edited the text while saving');
        expect(observedFiles, ['incoming.txt']);
        cache.result.completeError(StateError('Synthetic disk failure'));
        expect(await staging, isStateError);
        expect(w.drafts['c1'], 'User edited the text while saving');
        expect(w.uploads(), isEmpty);
        expect(observedFiles, isEmpty);
        await w.flushCache();
        expect(
          (await cache.read(
            client.origin,
            'alice',
            's1',
            'draft',
            'c1',
          ))['text'],
          w.drafts['c1'],
        );
      } finally {
        signal.removeListener(observeFiles);
        if (!cache.result.isCompleted) cache.result.complete();
        await staging;
        await w.flushCache();
        w.dispose();
        await client.dispose();
      }
    },
  );

  for (final revokeChannel in [false, true]) {
    test(
      'invalidating ${revokeChannel ? 'channel' : 'server'} disposes its draft signal',
      () async {
        final client = _Client();
        final w = _workspace(client);
        try {
          final previous = w.draftChanges();
          if (revokeChannel) {
            client.stream.add(
              const RaftEvent('channel:removed', {'channelId': 'c1'}),
            );
          } else {
            w.revokeServer('s1');
          }
          await Future<void>.delayed(Duration.zero);
          expect(
            () => previous.addListener(() {}),
            throwsFlutterError,
            reason: 'an invalid scope must not retain its notification object',
          );
        } finally {
          w.dispose();
          await client.dispose();
        }
      },
    );
  }
}

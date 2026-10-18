import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/shared_draft_attachment.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://composer-contract.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'fixture-user'});
    selectServer('fixture-server');
  }

  final enteredSend = Completer<void>();
  final receipt =
      Completer<({RaftMessage message, Map<String, dynamic> receipt})>();

  @override
  void connect() {}

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      path == '/attachments/upload-capabilities' ? {'maxBytes': 1024} : [];

  @override
  Future<List<Map<String, dynamic>>> uploadStream(
    String channelId,
    Stream<List<int>> Function() openRead,
    int length,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) async => [
    {
      'id': 'fixture-attachment',
      'filename': filename,
      'mimeType': mimeType,
      'sizeBytes': length,
      'downloadUrl': 'https://signed.invalid/not-for-cache',
    },
  ];

  @override
  Future<({RaftMessage message, Map<String, dynamic> receipt})> sendWithReceipt(
    String channelId,
    String content, {
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
    String? timezone,
  }) {
    enteredSend.complete();
    return receipt.future;
  }
}

Future<List<Map<String, dynamic>>> _records(DriftWorkspaceCache cache) async =>
    [
      for (final row in await cache.customSelect('''
    SELECT origin, principal, server, kind, id, payload,
      CAST(payload AS BLOB) AS payload_bytes
    FROM workspace_cache WHERE kind IN ('draft', 'attempt')
    ORDER BY origin, principal, server, kind, id
  ''').get())
        {
          for (final name in ['origin', 'principal', 'server', 'kind', 'id'])
            name: row.read<String>(name),
          'payload': row.read<String>('payload'),
          'payloadBytes': row.read<Uint8List>('payload_bytes').toList(),
        },
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('draft and in-flight attempt SQL payloads match the pre-M3 bytes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'raft-composer-contract-',
    );
    final cache = DriftWorkspaceCache(
      NativeDatabase(File('${directory.path}/cache.sqlite')),
    );
    final client = _Client();
    final w = WorkspaceController(client, cache: cache)
      ..server = RaftRecord({'id': 'fixture-server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'fixture-channel', 'joined': true});
    w.ledger.switchServer('fixture-server');
    final file = SharedDraftAttachment(
      reference: const {'token': 'fixture-share-reference', 'file': 'item-0'},
      filename: '照片-あ.png',
      mimeType: 'image/png',
      sizeBytes: 3,
      openRead: () => Stream.value([1, 2, 3]),
      release: () async {},
    );
    Future<bool>? sending;
    addTearDown(() async {
      if (!client.receipt.isCompleted && client.enteredSend.isCompleted) {
        client.receipt.completeError(
          const RaftApiException('Fixture send failure'),
        );
      }
      await sending;
      await w.flushCache();
      w.dispose();
      await client.dispose();
      await cache.close();
      await directory.delete(recursive: true);
    });

    final actual = <String, List<Map<String, dynamic>>>{};
    Future<void> capture(String name) async {
      await w.flushCache();
      actual[name] = await _records(cache);
    }

    w.saveDraft('');
    await capture('empty');
    w.saveDraft('原来的草稿\nDraft "one"');
    await w.stageSharedDraft('共有メモ', [file], sourceToken: 'fixture-share');
    await capture('queuedSharedFile');

    w.saveDraft('');
    sending = w.send('送信する本文', randomId: 'fixture-random-id');
    await client.enteredSend.future.timeout(const Duration(seconds: 5));
    w.saveDraft('后面新输入的文字\n\nSecond paragraph');
    await capture('inFlightWithNewText');

    client.receipt.completeError(
      const RaftApiException('Fixture send failure'),
    );
    expect(await sending, isFalse);
    await capture('failedWithNewText');
    w.saveDraft('');
    w.removeUpload(w.uploads().single);
    await capture('clearedDraftKeepsRetry');

    final fixture = File('test/fixtures/composer/pre_m3_sql_payloads.json');
    // Captured from the unchanged pre-M3 controller at the source revision
    // recorded in this fixture. Payload text and SQLite BLOB bytes are compared
    // as stored; decoding/re-encoding the payload would weaken this contract.
    final expected = jsonDecode(fixture.readAsStringSync()) as Map;
    for (final entry in actual.entries) {
      final rows = expected['scenarios'][entry.key] as List;
      expect(entry.value, hasLength(rows.length), reason: entry.key);
      for (var i = 0; i < rows.length; i++) {
        final wanted = Map<String, dynamic>.from(rows[i] as Map);
        wanted['payloadBytes'] = utf8.encode(wanted['payload'] as String);
        expect(entry.value[i], wanted, reason: '${entry.key} row $i');
      }
    }
  });
}

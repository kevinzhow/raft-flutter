import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_composer.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _PendingClient extends RaftClient {
  _PendingClient()
    : super(
        origin: 'https://composer.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'fixture-user'});
    selectServer('fixture-server');
  }
  final ids = <String>[];
  final entered = Completer<void>();
  final receipts =
      <Completer<({RaftMessage message, Map<String, dynamic> receipt})>>[];

  @override
  void connect() {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => [];

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
    ids.add(randomId!);
    final receipt =
        Completer<({RaftMessage message, Map<String, dynamic> receipt})>();
    receipts.add(receipt);
    if (!entered.isCompleted) entered.complete();
    return receipt.future;
  }
}

void main() {
  test(
    'two editors never share an in-flight send id for identical text',
    () async {
      final client = _PendingClient();
      final root = WorkspaceController(client);
      final borrowed = WorkspaceController(
        client,
        composer: root.composer,
        ownsClient: false,
      );
      for (final editor in [root, borrowed]) {
        editor.server = RaftRecord({'id': 'fixture-server', 'role': 'owner'});
        editor.channel = RaftChannel({'id': 'a', 'joined': true});
        editor.messageDomain.ledger.switchServer('fixture-server');
      }
      final pending = <Future<bool>>[];
      try {
        pending.add(root.send('same text', randomId: 'fixture-one'));
        await client.entered.future;
        pending.add(borrowed.send('same text', randomId: 'fixture-two'));
        for (var i = 0; i < 10 && client.ids.length < 2; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(client.ids, ['fixture-one', 'fixture-two']);
        for (final receipt in client.receipts) {
          receipt.completeError(const RaftApiException('Fixture send failure'));
        }
        await Future.wait(pending);
        pending.add(root.send('same text', randomId: 'fixture-three'));
        for (var i = 0; i < 10 && client.ids.length < 3; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(client.ids, ['fixture-one', 'fixture-two', 'fixture-two']);
      } finally {
        for (final receipt in client.receipts) {
          if (!receipt.isCompleted) {
            receipt.completeError(
              const RaftApiException('Fixture send failure'),
            );
          }
        }
        await Future.wait(pending);
        borrowed.dispose();
        root.dispose();
        await client.dispose();
      }
    },
  );

  test('draft signals stay within one channel or thread', () {
    final owner = Object();
    final composer = WorkspaceComposer(
      owner: owner,
      read: (_, _) async => null,
      write: (_, _, _, {required requiredSuccess}) async {},
    );
    addTearDown(() => composer.disposeOwnedBy(owner));
    var channelA = 0, channelB = 0, threadA = 0;
    composer.changes('a').addListener(() => channelA++);
    composer.changes('b').addListener(() => channelB++);
    composer.changes('thread:a').addListener(() => threadA++);
    composer.drafts['a'] = '输入🧭';
    composer.drafts['a'] = '输入🧭';
    expect((channelA, channelB, threadA), (1, 0, 0));
    composer.drafts['thread:a'] = 'reply';
    expect((channelA, channelB, threadA), (1, 0, 1));
    composer.drafts.remove('a');
    expect((channelA, channelB, threadA), (2, 0, 1));
  });

  test('borrower retirement keeps drafts and queued root writes', () async {
    final owner = Object(), borrower = Object();
    final writing = Completer<void>();
    final composer = WorkspaceComposer(
      owner: owner,
      read: (_, _) async => null,
      write: (_, _, _, {required requiredSuccess}) => writing.future,
    );
    addTearDown(() => composer.disposeOwnedBy(owner));
    composer.drafts['a'] = 'keep';
    final saved = composer.saveDraft(
      'a',
      pendingText: [],
      queuedText: '',
      files: [],
    );
    var flushed = false;
    final draining = composer.flushed.then((_) => flushed = true);
    composer.clearOwnedBy(borrower);
    composer.disposeOwnedBy(borrower);
    expect(composer.drafts['a'], 'keep');
    await Future<void>.delayed(Duration.zero);
    expect(flushed, false);
    writing.complete();
    await saved;
    await draining;
    expect(flushed, true);
  });

  test('owner reset rejects a late restore from the previous scope', () async {
    final owner = Object();
    final reading = Completer<dynamic>();
    final reads = <String>[];
    final composer = WorkspaceComposer(
      owner: owner,
      read: (kind, scope) {
        reads.add('$kind/$scope');
        return reading.future;
      },
      write: (_, _, _, {required requiredSuccess}) async {},
    );
    addTearDown(() => composer.disposeOwnedBy(owner));
    var restored = false;
    final restoring = composer.restore(
      'a',
      current: () => true,
      restoreFiles: (_) async => fail('stale files must not be admitted'),
      restored: () => restored = true,
    );
    composer.clearOwnedBy(owner);
    reading.complete({'text': 'private old draft', 'files': []});
    await restoring;
    expect(composer.drafts, isEmpty);
    expect(composer.attempts, isEmpty);
    expect(restored, false);
    expect(reads, ['draft/a']);
  });

  test(
    'required disk failure reaches caller and cannot poison flush',
    () async {
      final owner = Object();
      final composer = WorkspaceComposer(
        owner: owner,
        read: (_, _) async => null,
        write: (_, _, _, {required requiredSuccess}) async {
          throw StateError('fixture disk full');
        },
      );
      addTearDown(() => composer.disposeOwnedBy(owner));
      composer.drafts['a'] = 'keep after failure';
      await expectLater(
        composer.saveDraft(
          'a',
          pendingText: [],
          queuedText: '',
          files: [],
          requiredSuccess: true,
        ),
        throwsStateError,
      );
      await composer.flushed;
      expect(composer.drafts['a'], 'keep after failure');
    },
  );
}

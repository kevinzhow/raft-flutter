import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/history_read_policy.dart';
import 'package:raft_flutter/data/message_history_verification.dart';

import 'support/history_range_case.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundaries = [
    for (final n in [201, 151, 101, 51]) BigInt.from(n),
  ];

  for (final first in ['gap', 'verification']) {
    test(
      '$first accepts first and both automatic consumers fetch each range once',
      () async {
        // Initial: islands 1–100 and 201–250. Event: reconnect with two consumers
        // deliberately ordered. Expected: complete projections, four wire pages.
        final c = HistoryRangeCase();
        addTearDown(c.close);
        await c.open();
        final gate = Completer<void>(), arrived = Completer<void>();
        final blocked = first == 'gap' ? null : BigInt.from(201);
        c.client.gates[blocked] = gate;
        c.client.requested = (before) {
          if (before == blocked && !arrived.isCompleted) arrived.complete();
        };
        c.reconnect();
        await arrived.future;
        c.attach();
        if (first == 'gap') await c.windowContains(101);
        gate.complete();
        await c.settle();
        expect(c.client.beforeReads, boundaries);
        expect(await c.db.messageHistory.gaps.readSaved(c.scope), isEmpty);
        expect(c.w.messageDomain.ledger.message('chat', 'chat-151'), isNotNull);
        expect(c.w.error, isNull);
      },
    );
  }

  test(
    'a new reconnect rereads accepted ranges and sees missed old edits',
    () async {
      // Initial: accepted coverage from a complete reconnect. Event: another
      // device edits old rows with no new sequence. Expected: new wire proof.
      final c = HistoryRangeCase();
      addTearDown(c.close);
      await c.open();
      c.attach();
      c.reconnect();
      await c.settle();
      c.client.beforeReads.clear();
      c.client.edits.addAll({
        25: 'Second connection',
        151: 'Changed in old gap',
      });
      c.reconnect();
      await c.settle();
      expect(c.client.beforeReads, boundaries);
      expect(
        c.w.messageDomain.ledger.message('chat', 'chat-25')?['content'],
        'Second connection',
      );
      expect(
        c.w.messageDomain.ledger.message('chat', 'chat-151')?['content'],
        'Changed in old gap',
      );
      final saved = await c.db.messageHistory.readContext(
        c.scope,
        'chat-25',
        radius: 0,
      );
      expect(
        (saved?['messages'] as List).single['content'],
        'Second connection',
      );
    },
  );

  test('an old in-flight response cannot prove or repaint the next reconnect', () async {
    // Initial: an old reconnect is blocked on before=201. Event: a second
    // reconnect and server edit. Expected: fresh request, old response retired.
    final c = HistoryRangeCase();
    addTearDown(c.close);
    await c.open();
    final shown = <String>[];
    void observe() {
      final content = c.w.messageDomain.ledger.message(
        'chat',
        'chat-151',
      )?['content'];
      if (content != null) shown.add(content as String);
    }

    c.w.addListener(observe);
    addTearDown(() => c.w.removeListener(observe));
    final gate = Completer<void>(), arrived = Completer<void>();
    c.client.gates[BigInt.from(201)] = gate;
    c.client.requested = (before) {
      if (before == BigInt.from(201) && !arrived.isCompleted) {
        arrived.complete();
      }
    };
    c.reconnect();
    await arrived.future;
    c.client.edits[151] = 'New connection wins';
    c.reconnect();
    gate.complete();
    await c.settle();
    expect(c.client.beforeReads, [BigInt.from(201), ...boundaries]);
    expect(shown, isNotEmpty);
    expect(shown.every((content) => content == 'New connection wins'), isTrue);
    expect(
      c.w.messageDomain.ledger.message('chat', 'chat-151')?['content'],
      'New connection wins',
    );
    final saved = await c.db.messageHistory.readContext(
      c.scope,
      'chat-151',
      radius: 0,
    );
    expect(
      (saved?['messages'] as List).single['content'],
      'New connection wins',
    );
  });

  test('explicit gap reads still recheck the wire after automatic acceptance', () async {
    // Initial: automatic coverage exists. Event: two explicit gap commands.
    // Expected: each explicit read remains a fresh user-requested verification.
    final c = HistoryRangeCase();
    addTearDown(c.close);
    await c.open();
    c.reconnect();
    await c.settle();
    c.client.beforeReads.clear();
    c.client.edits[151] = 'Explicit verification';
    await c.w.messageDomain.loadHistoryGap(BigInt.from(201));
    await c.w.messageDomain.loadHistoryGap(BigInt.from(201));
    expect(c.client.beforeReads, [BigInt.from(201), BigInt.from(201)]);
    expect(
      c.w.messageDomain.ledger.message('chat', 'chat-151')?['content'],
      'Explicit verification',
    );
  });

  test(
    'a failed page can retry without refetching successful pages in the pass',
    () async {
      // Initial: before=201 was accepted; the next page fails. Event: retry on
      // the same connection. Expected: the failed page retries, accepted one joins.
      final c = HistoryRangeCase();
      addTearDown(c.close);
      await c.open();
      final request = c.w.messageWindows.request(
        allowed: () => c.w.deviceStore.writable,
      );
      Future<Object?> read(int before) => MessageHistoryVerification.readRange(
        c.w,
        request,
        c.scope,
        before: BigInt.from(before),
        reason: HistoryReadReason.reconnect,
      );
      expect(await read(201), isNotNull);
      c.client.failures.add(BigInt.from(151));
      expect(await read(151), isNull);
      expect(await read(201), isNotNull);
      expect(await read(151), isNotNull);
      expect(c.client.beforeReads, [
        for (final n in [201, 151, 151]) BigInt.from(n),
      ]);
      expect(c.w.messageDomain.ledger.message('chat', 'chat-101'), isNotNull);
    },
  );

  test('hard-capacity proof repairs only this online window and is not durable', () async {
    // Initial: gap repair can no longer admit bodies. Event: reconnect then
    // close/reopen the presented window offline. Expected: no fake disk proof.
    final c = HistoryRangeCase();
    addTearDown(c.close);
    await c.open();
    c.free = 512 << 20;
    c.attach();
    c.reconnect();
    await c.settle();
    expect(c.client.beforeReads, boundaries);
    expect(c.w.messageDomain.ledger.message('chat', 'chat-151'), isNotNull);
    expect(
      await c.db.messageHistory.readContext(c.scope, 'chat-151', radius: 0),
      isNull,
    );
    expect(await c.db.messageHistory.gaps.readSaved(c.scope), isNotEmpty);
    c.detach();
    for (var n = 101; n <= 200; n++) {
      c.w.messageDomain.ledger.remove('chat', 'chat-$n');
      c.w.messageDomain.visibleIds['chat']?.remove('chat-$n');
    }
    c.client.beforeReads.clear();
    c.client.disconnected = true;
    c.attach();
    await c.settle();
    expect(c.client.beforeReads, [BigInt.from(201)]);
    expect(c.recovery!.contains('chat-201'), isTrue);
    expect(
      c.recovery!.failed('chat-201'),
      isFalse,
      reason:
          'One failed attempt stays quiet while automatic recovery can retry.',
    );
    expect(c.w.messageDomain.ledger.message('chat', 'chat-151'), isNull);
  });

  test('revoking permission while a shared page is pending retires its proof', () async {
    // Initial: a shared read is held at the server. Event: channel is revoked.
    // Expected: no new projection or stored gap coverage is admitted.
    final c = HistoryRangeCase();
    addTearDown(c.close);
    await c.open();
    final gate = Completer<void>(), arrived = Completer<void>();
    c.client.gates[BigInt.from(201)] = gate;
    c.client.requested = (before) {
      if (before == BigInt.from(201) && !arrived.isCompleted) {
        arrived.complete();
      }
    };
    c.reconnect();
    await arrived.future;
    c.client.arrivals.add(
      const RaftEvent('channel:removed', {'channelId': 'chat'}),
    );
    gate.complete();
    await c.settle();
    expect(c.w.messageDomain.messages, isEmpty);
    expect(
      await c.db.messageHistory.readContext(c.scope, 'chat-151', radius: 0),
      isNull,
    );
    expect(c.client.beforeReads, [BigInt.from(201)]);
  });

  test(
    'automatic backoff retries the failed page within the same generation',
    () async {
      // Initial: one accepted page followed by a temporary error. Event: the
      // automatic timer retries. Expected: successful pages keep their proof.
      final c = HistoryRangeCase();
      addTearDown(c.close);
      await c.open();
      c.w.connected = true;
      c.client.failures.add(BigInt.from(151));
      final retried = Completer<void>();
      c.client.requested = (before) {
        if (before == BigInt.from(151) &&
            c.client.beforeReads.where((n) => n == before).length == 2) {
          retried.complete();
        }
      };
      c.reconnect();
      await c.settle();
      expect(c.client.beforeReads, [BigInt.from(201), BigInt.from(151)]);
      await retried.future.timeout(const Duration(seconds: 10));
      await c.settle();
      expect(c.client.beforeReads, [
        for (final n in [201, 151, 151, 101, 51]) BigInt.from(n),
      ]);
      expect(c.w.messageDomain.ledger.message('chat', 'chat-101'), isNotNull);
    },
  );

  test('hard-capacity transient proof expires on the next reconnect', () async {
    // Initial: repaired rows are online-only. Event: reconnect after an old
    // server edit. Expected: new verification updates RAM without claiming disk.
    final c = HistoryRangeCase();
    addTearDown(c.close);
    await c.open();
    c.free = 512 << 20;
    c.attach();
    c.reconnect();
    await c.settle();
    c.client.beforeReads.clear();
    c.client.edits[151] = 'Fresh online body';
    c.reconnect();
    await c.settle();
    expect(c.client.beforeReads, boundaries);
    expect(
      c.w.messageDomain.ledger.message('chat', 'chat-151')?['content'],
      'Fresh online body',
    );
    expect(
      await c.db.messageHistory.readContext(c.scope, 'chat-151', radius: 0),
      isNull,
    );
  });

  test('account storage cleanup retires completed coverage without navigation', () async {
    // Initial: an automatic page is already accepted. Event: account history
    // is cleared under the same window. Expected: a new read, not an old proof.
    final c = HistoryRangeCase();
    addTearDown(c.close);
    await c.open();
    final request = c.w.messageWindows.request(
      allowed: () => c.w.deviceStore.writable,
    );
    Future<Object?> read() => MessageHistoryVerification.readRange(
      c.w,
      request,
      c.scope,
      before: BigInt.from(201),
      reason: HistoryReadReason.reconnect,
    );
    expect(await read(), isNotNull);
    await c.db.clearAccount(c.client.origin, c.client.user!.id);
    c.client.edits[151] = 'After cleanup';
    expect(await read(), isNotNull);
    expect(c.client.beforeReads, [BigInt.from(201), BigInt.from(201)]);
    expect(
      c.w.messageDomain.ledger.message('chat', 'chat-151')?['content'],
      'After cleanup',
    );
  });

  test('a live edit wins over a late online-only page and later proof reuse', () async {
    // Initial: the current window holds an online-only row. Event: a live edit
    // arrives while its old HTTP body is held. Expected: no body replay.
    final c = HistoryRangeCase();
    addTearDown(c.close);
    await c.open();
    c.free = 512 << 20;
    c.attach();
    c.reconnect();
    await c.settle();
    final gate = Completer<void>(), arrived = Completer<void>();
    c.client.gates[BigInt.from(201)] = gate;
    c.client.requested = (before) {
      if (before == BigInt.from(201) && !arrived.isCompleted) {
        arrived.complete();
      }
    };
    c.reconnect();
    await arrived.future;
    c.client.arrivals.add(
      const RaftEvent('message:updated', {
        'id': 'chat-151',
        'channelId': 'chat',
        'content': 'Live edit wins',
      }),
    );
    await c.db.messageHistory.receiver.settled;
    gate.complete();
    await c.settle();
    expect(
      c.w.messageDomain.ledger.message('chat', 'chat-151')?['content'],
      'Live edit wins',
    );
    final count = c.client.beforeReads.length;
    final request = c.w.messageWindows.request(
      allowed: () => c.w.deviceStore.writable,
    );
    await MessageHistoryVerification.readRange(
      c.w,
      request,
      c.scope,
      before: BigInt.from(201),
      reason: HistoryReadReason.reconnect,
    );
    expect(c.client.beforeReads.length, count);
    expect(
      c.w.messageDomain.ledger.message('chat', 'chat-151')?['content'],
      'Live edit wins',
    );
  });
}

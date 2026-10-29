import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';

const _scope = AttachmentImageScope(
  origin: 'https://parity.invalid',
  principal: 'phase-owner',
  server: 'phase-server',
  generation: 1,
  role: 'owner',
);
AttachmentImageKey _key({
  AttachmentDecodeTarget? target,
  String revision = 'A',
}) => AttachmentImageKey(
  scope: _scope,
  channelId: 'phase-channel',
  attachmentId: 'phase-image',
  revision: revision,
  target: target,
);

class _Fetch {
  final address = Completer<void>();
  final bytes = Completer<Uint8List>();
  AttachmentFetchToken? token;
  int calls = 0;
  Future<Uint8List> load(CancelToken raw) async {
    calls++;
    token = raw as AttachmentFetchToken;
    raw.reportAttachmentPhase(AttachmentFetchPhase.waitingForAddress);
    await address.future;
    if (raw.isCancelled) throw const StaleAttachmentImage();
    raw.reportAttachmentPhase(AttachmentFetchPhase.transfer);
    return bytes.future;
  }

  void close() {
    if (!address.isCompleted) address.complete();
    if (!bytes.isCompleted) bytes.complete(Uint8List(4));
  }
}

AttachmentImageRepository _repo() => AttachmentImageRepository(
  scope: _scope,
  retainedAuthority: (_) => true,
  decoder: (bytes, _) async => DecodedAttachmentImage(
    provider: MemoryImage(bytes),
    encodedBytes: bytes.length,
    decodedBytes: 4,
    release: () async {},
  ),
);
Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'shared source leases receive phase changes without changing byte values',
    () async {
      final repo = _repo(), fetch = _Fetch();
      addTearDown(() {
        repo.dispose();
        fetch.close();
      });
      final a = repo.acquire(
        _key(target: AttachmentDecodeTarget.box(64, 64, devicePixelRatio: 1)),
        load: fetch.load,
        authorized: () => true,
      );
      final b = repo.acquire(
        _key(target: AttachmentDecodeTarget.box(128, 128, devicePixelRatio: 1)),
        load: fetch.load,
        authorized: () => true,
      );
      final seenA = <bool>[], seenB = <bool>[];
      a.progress.addListener(() => seenA.add(a.waitingForAddress));
      b.progress.addListener(() => seenB.add(b.waitingForAddress));
      await _tick();
      expect(fetch.calls, 1);
      expect(a.waitingForAddress, isTrue);
      expect(b.waitingForAddress, isTrue);
      final bytesA = a.progress.value, bytesB = b.progress.value;
      fetch.address.complete();
      await _tick();
      expect(a.waitingForAddress, isFalse);
      expect(b.waitingForAddress, isFalse);
      expect(a.progress.value, same(bytesA));
      expect(b.progress.value, same(bytesB));
      expect(seenA, contains(false));
      expect(seenB, contains(false));
      a.release();
      await _tick();
      expect(fetch.token!.isCancelled, isFalse);
      final retiredNotifications = seenA.length;
      fetch.token!.reportAttachmentPhase(
        AttachmentFetchPhase.waitingForAddress,
      );
      expect(b.waitingForAddress, isTrue);
      expect(seenA.length, retiredNotifications);
      b.release();
      await _tick();
      expect(fetch.token!.isCancelled, isTrue);
      expect(repo.entryCount, 0);
      fetch.close();
      await _tick();
    },
  );

  test(
    'replacement owns its phase while the retired fetch completes late',
    () async {
      final repo = _repo(), oldFetch = _Fetch(), newFetch = _Fetch();
      addTearDown(() {
        repo.dispose();
        oldFetch.close();
        newFetch.close();
      });
      final old = repo.acquire(
        _key(),
        load: oldFetch.load,
        authorized: () => true,
      );
      await _tick();
      final current = repo.acquire(
        _key(revision: 'B'),
        load: newFetch.load,
        authorized: () => true,
      );
      await _tick();
      expect(old.active, isFalse);
      expect(oldFetch.token!.isCancelled, isTrue);
      expect(current.waitingForAddress, isTrue);
      oldFetch.close();
      await _tick();
      expect(current.active, isTrue);
      expect(current.waitingForAddress, isTrue);
      newFetch.address.complete();
      await _tick();
      expect(current.waitingForAddress, isFalse);
      current.release();
      await _tick();
      expect(newFetch.token!.isCancelled, isTrue);
      expect(repo.entryCount, 0);
    },
  );

  test(
    'revocation and disposal end phases and ignore late callbacks',
    () async {
      final repo = _repo(), fetch = _Fetch();
      addTearDown(fetch.close);
      final lease = repo.acquire(
        _key(),
        load: fetch.load,
        authorized: () => true,
      );
      await _tick();
      expect(lease.waitingForAddress, isTrue);
      const next = AttachmentImageScope(
        origin: 'https://parity.invalid',
        principal: 'phase-other',
        server: 'phase-server',
        generation: 2,
        role: 'owner',
      );
      repo.synchronize(next);
      expect(lease.active, isFalse);
      expect(lease.waitingForAddress, isFalse);
      expect(fetch.token!.isCancelled, isTrue);
      repo.dispose();
      fetch.token!.reportAttachmentPhase(AttachmentFetchPhase.transfer);
      fetch.close();
      await _tick();
      expect(repo.entryCount, 0);
    },
  );
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/platform/desktop_cache_scope.dart';
import 'package:raft_flutter/platform/desktop_windows.dart';

import 'app_global_server_selector_test.dart' show RootCache;
import 'desktop_window_broker_test.dart' show owner, Peer, beta;

String? executableOnPath(String name) {
  for (final directory in (Platform.environment['PATH'] ?? '').split(
    Platform.isWindows ? ';' : ':',
  )) {
    if (directory.isEmpty) continue;
    final executable = File(p.join(directory, name));
    if (executable.existsSync() && (executable.statSync().mode & 0x49) != 0) {
      return executable.path;
    }
  }
  return null;
}

final statExecutable = executableOnPath('stat');
final chmodExecutable = executableOnPath('chmod');
final idExecutable = executableOnPath('id');

Future<String?> identity(String path) async {
  final result = await Process.run(statExecutable!, [
    if (Platform.isMacOS) '-f' else '-Lc',
    '%d:%i',
    path,
  ]);
  return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
}

Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> cleaned(DesktopSessionBroker broker, String id) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (broker.cleanupOutcomes[id] != 'removed' &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(broker.cleanupOutcomes[id], 'removed');
}

void main() {
  if ((!Platform.isLinux && !Platform.isMacOS) || statExecutable == null) {
    test(
      'physical cache identity requires a POSIX stat executable',
      () {},
      skip: 'A physical directory identity oracle is unavailable on this host.',
    );
    return;
  }
  final uid = Platform.isLinux && idExecutable != null
      ? Process.runSync(idExecutable!, ['-u'])
      : null;
  final uidValue = int.tryParse('${uid?.stdout}'.trim());
  final canDenyDeletion =
      chmodExecutable != null &&
      uid?.exitCode == 0 &&
      uidValue != null &&
      uidValue > 0;
  late Directory parent;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp(
      'raft-cache-lifecycle-test-',
    );
  });
  tearDown(() async {
    if (await parent.exists()) await parent.delete(recursive: true);
  });

  test('normal native window removal reclaims exactly the primary-owned child root, never a live peer or shared data', () async {
    final (client, _) = await owner();
    late Peer peer;
    final broker = DesktopSessionBroker(
      createWindow: (id, s, b) async => peer = Peer(b, id),
      focusPrimary: () async {},
      createCache: () =>
          DesktopOwnedCache.create(parent: parent, identify: identity),
    );
    broker.bind(client, null, cache: RootCache());
    await broker.openServer(beta);
    final lease = await broker.cacheLease(peer.id),
        root = Directory(lease['root']!);
    await File(p.join(root.path, 'attachment-cache')).writeAsString('owned');
    final other = await parent.createTemp('other-window-');
    await File(p.join(other.path, 'keep')).writeAsString('shared');
    broker.removeClosed({peer.id});
    await settle();
    expect(await root.exists(), isTrue);
    broker.removeClosed({});
    await cleaned(broker, peer.id);
    expect(await root.exists(), isFalse);
    expect(await File(p.join(other.path, 'keep')).readAsString(), 'shared');
    expect(broker.cleanupOutcomes[peer.id], 'removed');
    await broker.dispose();
    await client.dispose();
    await peer.stream.close();
  });

  test('revocation retains an active native engine and removes its lease only after confirmed removal', () async {
    final (client, _) = await owner();
    late Peer peer;
    final broker = DesktopSessionBroker(
      createWindow: (id, s, b) async => peer = Peer(b, id),
      focusPrimary: () async {},
      createCache: () =>
          DesktopOwnedCache.create(parent: parent, identify: identity),
    );
    broker.bind(client, null, cache: RootCache());
    await broker.openServer(beta);
    final lease = await broker.cacheLease(peer.id);
    final root = Directory(lease['root']!);
    broker.bind(null, null);
    await settle();
    expect(await root.exists(), isTrue);
    broker.removeClosed({peer.id});
    await settle();
    expect(await root.exists(), isTrue);
    broker.removeClosed({});
    await cleaned(broker, peer.id);
    expect(await root.exists(), isFalse);
    await broker.dispose();
    await client.dispose();
    await peer.stream.close();
  });

  test('a pending create revoked before attachment is cleaned after its returned native window is gone', () async {
    final (client, _) = await owner();
    final entered = Completer<String>(), created = Completer<Peer>();
    late DesktopSessionBroker broker;
    broker = DesktopSessionBroker(
      createWindow: (id, s, b) {
        entered.complete(id);
        return created.future;
      },
      focusPrimary: () async {},
      createCache: () =>
          DesktopOwnedCache.create(parent: parent, identify: identity),
    );
    broker.bind(client, null, cache: RootCache());
    final opening = broker.openServer(beta);
    final rejected = expectLater(opening, throwsA(anything));
    final binding = await entered.future;
    final lease = await broker.cacheLease(binding);
    final root = Directory(lease['root']!);
    broker.bind(null, null);
    final peer = Peer(broker, binding);
    created.complete(peer);
    await rejected;
    expect(await root.exists(), isTrue);
    broker.removeClosed({});
    await cleaned(broker, peer.id);
    expect(await root.exists(), isFalse);
    await broker.dispose();
    await client.dispose();
    await peer.stream.close();
  });

  test('symlink and same-marker directory replacement are retained with outcomes; external files survive', () async {
    final lease = await DesktopOwnedCache.create(
      parent: parent,
      identify: identity,
    );
    final moved = await lease.root.rename('${lease.root.path}-saved');
    final replacement = await Directory(lease.root.path).create();
    await File(p.join(replacement.path, '.raft-owner'))
        .writeAsString(lease.marker);
    await File(p.join(replacement.path, 'keep')).writeAsString('replacement');
    expect(await lease.remove(), isFalse);
    expect(lease.outcome, 'identity_changed');
    await replacement.delete(recursive: true);
    await Link(lease.root.path).create(moved.path);
    expect(await lease.remove(), isFalse);
    expect(
      await File(p.join(moved.path, '.raft-owner')).readAsString(),
      lease.marker,
    );
  });

  test('owned descendants symlink is unlinked without touching its target and changed ownership marker is preserved', () async {
    final lease = await DesktopOwnedCache.create(
      parent: parent,
      identify: identity,
    );
    final other = await parent.createTemp('other-');
    await File(p.join(other.path, 'keep')).writeAsString('outside');
    await Link(p.join(lease.root.path, 'link')).create(other.path);
    expect(await lease.remove(), isTrue);
    expect(await File(p.join(other.path, 'keep')).readAsString(), 'outside');
    final changed = await DesktopOwnedCache.create(
      parent: parent,
      identify: identity,
    );
    await File(p.join(changed.root.path, '.raft-owner'))
        .writeAsString('changed');
    expect(await changed.remove(), isFalse);
    expect(changed.outcome, 'marker_changed');
  });

  test('identity creation failure preserves uncertainty and retired child paths never fall back to primary caches', () async {
    await expectLater(
      DesktopOwnedCache.create(parent: parent, identify: (_) async => null),
      throwsStateError,
    );
    expect(await parent.list().length, 1);
    final lease = await DesktopOwnedCache.create(
      parent: parent,
      identify: identity,
    );
    final child = DesktopChildCache(lease.root);
    await child.directory('media');
    child.retire();
    expect(() => child.directory('staging'), throwsStateError);
    child.resume();
    await child.directory('staging');
    expect(await lease.remove(), isTrue);
  });
  test('normal application quit waits for native child removal and reclaims its cache before approving exit', () async {
    final (client, _) = await owner();
    late Peer peer;
    final observed = Completer<Set<String>>();
    final broker = DesktopSessionBroker(
      createWindow: (id, s, b) async => peer = Peer(b, id),
      focusPrimary: () async {},
      createCache: () =>
          DesktopOwnedCache.create(parent: parent, identify: identity),
      observeWindows: () => observed.future,
    );
    broker.bind(
      client,
      null,
      cache: RootCache(),
      prepareClose: () async => true,
    );
    await broker.openServer(beta);
    final lease = await broker.cacheLease(peer.id);
    final root = Directory(lease['root']!);
    var approved = false;
    final closing = broker.prepareExit().then((v) => approved = v);
    await settle();
    expect(approved, isFalse);
    expect(await root.exists(), isTrue);
    observed.complete({});
    expect(await closing, isTrue);
    expect(await root.exists(), isFalse);
    expect(client.signedIn, isTrue);
    await broker.dispose();
    await client.dispose();
    await peer.stream.close();
  });

  test(
    'an actual deletion failure retains the owned root and a failure outcome',
    () async {
      final lease = await DesktopOwnedCache.create(
        parent: parent,
        identify: identity,
      );
      final locked = await Directory(p.join(lease.root.path, 'locked'))
          .create();
      await File(p.join(locked.path, 'keep')).writeAsString('retained');
      await Process.run(chmodExecutable!, ['000', locked.path]);
      try {
        expect(await lease.remove(), isFalse);
        expect(lease.outcome, 'cleanup_failed');
        expect(await Directory(lease.retainedPath).exists(), isTrue);
      } finally {
        await Process.run(chmodExecutable!, [
          '700',
          p.join(lease.retainedPath, 'locked'),
        ]);
      }
    },
    skip: !canDenyDeletion,
  );
  test('creation failure never becomes an unhandled cleanup future or deletion grant', () async {
    final (client, _) = await owner();
    late Peer peer;
    final broker = DesktopSessionBroker(
      createWindow: (id, s, b) async => peer = Peer(b, id),
      focusPrimary: () async {},
      createCache: () => Future.error(StateError('identity unavailable')),
    );
    broker.bind(client, null, cache: RootCache());
    await broker.openServer(beta);
    await expectLater(broker.cacheLease(peer.id), throwsStateError);
    broker.bind(null, null);
    broker.removeClosed({});
    await settle();
    expect(broker.cleanupOutcomes[peer.id], 'creation_failed_retained');
    await broker.dispose();
    await client.dispose();
    await peer.stream.close();
  });
  test('a replacement raced after the first identity check is restored intact, never recursively deleted', () async {
    Directory? original;
    var checks = 0;
    late DesktopOwnedCache lease;
    Future<String?> racingIdentity(String path) async {
      final current = await identity(path);
      checks++;
      if (checks == 2) {
        original = await Directory(path).rename('$path-original');
        await Directory(path).create();
        await File(p.join(path, '.raft-owner')).writeAsString(lease.marker);
        await File(p.join(path, 'replacement')).writeAsString('keep');
      }
      return current;
    }

    lease = await DesktopOwnedCache.create(
      parent: parent,
      identify: racingIdentity,
    );
    expect(await lease.remove(), isFalse);
    expect(lease.outcome, 'identity_changed');
    expect(
      await File(p.join(lease.root.path, 'replacement')).readAsString(),
      'keep',
    );
    expect(await original!.exists(), isTrue);
  });
}

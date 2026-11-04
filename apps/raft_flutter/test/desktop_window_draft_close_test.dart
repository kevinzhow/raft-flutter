import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_composer.dart';
import 'package:raft_flutter/data/workspace_uploads.dart';
import 'package:raft_flutter/platform/desktop_windows.dart';
import 'package:raft_flutter/platform/desktop_window_exit.dart';

import 'app_global_server_selector_test.dart' show RootCache, RootFixture;
import 'desktop_server_windows_test.dart' show WindowsFixture;
import 'desktop_window_broker_test.dart' show owner, Peer, alpha, beta;

class ClosingPeer extends Peer {
  ClosingPeer(super.broker, super.id);
  bool sealed = false, accepts = true;
  @override
  Future<bool> prepareClose() async {
    sealed = true;
    return accepts;
  }

  @override
  Future<void> cancelClose() async {
    sealed = false;
  }
}

class CloseWindow extends WindowsFixture {
  Future<bool> Function()? prepare;
  void Function()? cancel;
  @override
  bool get isChild => true;
  @override
  void bind(
    RaftClient? client,
    String? serverId, {
    Future<void> Function()? onLogout,
    WorkspaceCache? cache,
    Future<bool> Function()? prepareClose,
    void Function()? cancelClose,
  }) {
    prepare = prepareClose;
    cancel = cancelClose;
  }
}

class HoldDraftCache extends RootCache {
  Completer<void>? hold;
  final entered = Completer<void>();
  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (kind == 'draft' && hold != null) {
      if (!entered.isCompleted) entered.complete();
      await hold!.future;
    }
    await super.write(origin, principal, server, kind, id, value);
  }
}

void main() {
  testWidgets(
    'actual Root closes behind an editor shield, cancels cleanly, and displays the attachment veto using its real Navigator',
    (t) async {
      final cache = HoldDraftCache(), window = CloseWindow();
      final f = RootFixture(cache: cache);
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri(path: '/s/beta'),
        desktopWindows: window,
      );
      final w = f.workspace(t), scope = f.workspace(t).channel!.id;
      w.composer.drafts[scope] = 'still here';
      cache.hold = Completer<void>();
      late Future<bool> preparing;
      bool? outcome;
      await t.runAsync(() async {
        preparing = window.prepare!();
        preparing.then((v) => outcome = v);
      });
      await f.flush(t);
      expect(cache.entered.isCompleted, isTrue);
      bool shielded() => t
          .widgetList<IgnorePointer>(
            find.ancestor(
              of: find.byType(WorkspaceView),
              matching: find.byType(IgnorePointer),
            ),
          )
          .any((w) => w.ignoring);
      expect(shielded(), isTrue);
      cache.hold!.complete();
      await f.flush(t);
      expect(outcome, isTrue);
      window.cancel!();
      outcome = null;
      await t.pump();
      expect(shielded(), isFalse);
      w.composer.uploads.byScope[scope] = [
        UploadDraft('unsent.txt', Uint8List.fromList([1]), key: 1),
      ];
      await t.runAsync(() async {
        preparing = window.prepare!();
        preparing.then((v) => outcome = v);
      });
      await f.flush(t);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('This window still has unsaved drafts'), findsOneWidget);
      await t.tap(find.text('OK'));
      await f.flush(t);
      expect(outcome, isFalse);
      expect(shielded(), isFalse);
      w.composer.uploads.byScope.remove(scope);
      await f.close(t);
    },
  );

  test('typing during a held close write is saved again before close is acknowledged', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final rows = <Map>[];
    final composer = WorkspaceComposer(
      owner: Object(),
      read: (k, id) async => null,
      write: (kind, id, value, {required bool requiredSuccess}) async {
        if (kind != 'draft') return;
        rows.add(Map.from(value));
        if (!entered.isCompleted) {
          entered.complete();
          await release.future;
        }
      },
    );
    composer.drafts['c'] = 'before';
    var closed = false;
    final closing = prepareDesktopComposerClose(composer)
        .then((_) => closed = true);
    await entered.future;
    composer.drafts['c'] = 'typed while saving';
    expect(closed, isFalse);
    release.complete();
    await closing;
    expect(rows.last['text'], 'typed while saving');
  });

  test(
    'unretained byte attachments also keep a child window open until removed',
    () async {
      final composer = WorkspaceComposer(
        owner: Object(),
        read: (k, id) async => null,
        write: (k, id, v, {required bool requiredSuccess}) async {},
      );
      composer.uploads.byScope['c'] = [
        UploadDraft('unsent.txt', Uint8List.fromList([1]), key: 1),
      ];
      await expectLater(
        prepareDesktopComposerClose(composer),
        throwsStateError,
      );
      composer.uploads.byScope.remove('c');
      await prepareDesktopComposerClose(composer);
    },
  );

  test(
    'a child veto or missing engine releases already prepared sibling editors',
    () async {
      final (client, _) = await owner();
      final peers = <ClosingPeer>[];
      final broker = DesktopSessionBroker(
        createWindow: (id, s, b) async {
          final peer = ClosingPeer(b, id);
          peers.add(peer);
          return peer;
        },
        focusPrimary: () async {},
      );
      broker.bind(
        client,
        null,
        cache: RootCache(),
        prepareClose: () async => true,
      );
      await broker.openServer(alpha);
      await broker.openServer(beta);
      peers.last.accepts = false;
      expect(await broker.prepareExit(), isFalse);
      expect(peers.every((p) => !p.sealed), isTrue);
      peers.last.accepts = true;
      expect(await broker.prepareExit(), isTrue);
      expect(peers.every((p) => p.sealed), isTrue);
      await broker.dispose();
      await client.dispose();
      for (final peer in peers) {
        await peer.stream.close();
      }
    },
  );

  test(
    'a live server draft slot is unique when two children switch servers',
    () async {
      final (client, _) = await owner();
      final peers = <Peer>[];
      final broker = DesktopSessionBroker(
        createWindow: (id, s, b) async {
          final peer = Peer(b, id);
          peers.add(peer);
          return peer;
        },
        focusPrimary: () async {},
      );
      broker.bind(client, null, cache: RootCache());
      await broker.openServer(alpha);
      await broker.openServer(beta);
      await expectLater(
        broker.bindServer(peers.first.id, 'b'),
        throwsA(isA<DesktopWindowAlreadyOpen>()),
      );
      expect(peers.last.focuses, 2);
      await broker.openServer(alpha);
      expect(peers.first.focuses, 2);
      await broker.dispose();
      await client.dispose();
      for (final peer in peers) {
        await peer.stream.close();
      }
    },
  );
}

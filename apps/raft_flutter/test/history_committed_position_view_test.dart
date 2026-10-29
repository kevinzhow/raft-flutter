import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart'
    show QueryExecutor, QueryInterceptor, ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_window_snapshot.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_memory_test.dart' show HistoryClient, receiver, row;
import 'history_memory_viewport_test.dart' show drainIo;

class _Gate extends QueryInterceptor {
  final reached = Completer<void>(), release = Completer<void>();
  bool hold = false;

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    if (hold &&
        sql.startsWith('DELETE FROM workspace_cache') &&
        args.contains('blocking')) {
      hold = false;
      reached.complete();
      await release.future;
    }
    await super.runCustom(executor, sql, args);
  }
}

class _RealCache extends DriftWorkspaceCache {
  _RealCache(File file, _Gate gate)
    : super(
        NativeDatabase.createInBackground(
          file,
          readPool: 1,
        ).interceptWith(gate),
        automaticHistoryMaintenance: false,
      );
  Future<void> Function()? beforeWindow;
  final windowReturned = Completer<dynamic>();

  @override
  Future<dynamic> readCommittedWindow(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) async {
    final action = beforeWindow;
    beforeWindow = null;
    if (action != null) await action();
    final saved = await super.readCommittedWindow(
      origin,
      principal,
      server,
      kind,
      id,
    );
    if (!windowReturned.isCompleted) windowReturned.complete(saved);
    return saved;
  }
}

void main() {
  testWidgets(
    'real file tail paints before an unrelated writer allows position lookup',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final directory = Directory.systemTemp.createTempSync(
        'raft-committed-tail-view-',
      );
      final (gate, client, cache, w) = (await t.runAsync(() async {
        final gate = _Gate(), client = HistoryClient()..offline = true;
        final cache = _RealCache(
          File('${directory.path}/history.sqlite'),
          gate,
        );
        final w = receiver(client, cache);
        w.channel = w.channels.single;
        await cache.write(
          client.origin,
          client.user!.id,
          client.serverId!,
          'window',
          'chat',
          {
            'version': 1,
            'windowKind': 'tail',
            'parentChannelId': 'chat',
            'authority': messageWindowAuthority('owner', w.channel!.json),
            'messages': [row('chat', 42)],
            'hasMore': false,
            'hasNewer': false,
          },
        );
        return (gate, client, cache, w);
      }))!;
      Future<void>? opening, writing;
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        cache.beforeWindow = () async {
          gate.hold = true;
          writing = cache.write(
            client.origin,
            client.user!.id,
            client.serverId!,
            'draft',
            'blocking',
            {'text': 'pending'},
          );
          await gate.reached.future;
        };
        await t.runAsync(() async {
          opening = w.selectChannel(w.channels.single, autoRead: false);
        });
        await drainIo(t, gate.reached.future);
        final saved = await drainIo(t, cache.windowReturned.future);
        expect(saved, isA<Map>());
        expect((saved as Map)['messages'], hasLength(1));
        final watch = Stopwatch()..start();
        while (find.text('Saved message 42 中文').evaluate().isEmpty &&
            watch.elapsed < const Duration(seconds: 2)) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await t.pump(const Duration(milliseconds: 5));
        }
        await t.pump();
        expect(gate.release.isCompleted, isFalse);
        expect(w.messageDomain.messages.map((m) => m.id), contains('chat-42'));
        expect(w.messageDomain.state.channelLoading, isFalse);
        expect(find.text('Saved message 42 中文'), findsOneWidget);
      } finally {
        if (!gate.release.isCompleted) gate.release.complete();
        await drainIo(
          t,
          Future.wait([
            if (writing != null) writing!,
            if (opening != null) opening!,
          ]),
        );
        await drainIo(t, w.flushCache());
        await t.pumpWidget(const SizedBox());
        w.dispose();
        await client.arrivals.close();
        await t.runAsync(cache.close);
        directory.deleteSync(recursive: true);
        await t.pump(const Duration(seconds: 1));
      }
    },
  );
}

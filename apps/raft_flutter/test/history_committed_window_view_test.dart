import 'dart:async';

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

class _Cache extends DriftWorkspaceCache {
  _Cache() : super(NativeDatabase.memory(), messageHistoryEnabled: false);
  final writing = Completer<void>(), release = Completer<void>();
  final captured = Completer<void>(), releaseRead = Completer<void>();
  late Map<String, dynamic> window;
  void Function()? onDraft;
  bool holdRead = false;
  bool holdDraft = true;

  @override
  Future<dynamic> read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) async {
    if (kind == 'draft') onDraft?.call();
    return kind == 'window' ? window : null;
  }

  @override
  Future<dynamic> readCommittedWindow(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) async {
    final saved = window;
    if (!captured.isCompleted) captured.complete();
    if (holdRead) await releaseRead.future;
    return saved;
  }

  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (kind == 'draft' && holdDraft) {
      if (!writing.isCompleted) writing.complete();
      await release.future;
    }
  }
}

void main() {
  testWidgets(
    'a committed disk window paints while an unrelated draft write is held',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final cache = _Cache(), client = HistoryClient()..offline = true;
      final w = receiver(client, cache);
      w.channel = w.channels.single;
      cache.window = {
        'version': 1,
        'windowKind': 'tail',
        'parentChannelId': 'chat',
        'channelId': 'chat',
        'authority': messageWindowAuthority('owner', w.channel!.json),
        'messages': [row('chat', 42)],
        'hasMore': false,
      };
      // A user edit arrives after the draft read started, before window restore.
      cache.onDraft = () {
        cache.onDraft = null;
        w.saveDraft('Still typing');
      };
      Future<void>? opening;
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await t.runAsync(() async {
          opening = w.selectChannel(w.channels.single, autoRead: false);
          await cache.writing.future;
          for (var n = 0; n < 100 && w.messageDomain.messages.isEmpty; n++) {
            await Future<void>.delayed(const Duration(milliseconds: 2));
          }
        });
        await t.pump();
        expect(cache.release.isCompleted, isFalse);
        expect(find.text('Saved message 42 中文'), findsOneWidget);
        expect(w.drafts['chat'], 'Still typing');
      } finally {
        cache.release.complete();
        cache.releaseRead.complete();
        await t.runAsync(() async {
          await opening;
          await w.flushCache();
        });
        await t.pumpWidget(const SizedBox());
        w.dispose();
        await client.arrivals.close();
        await cache.close();
        await t.pump(const Duration(seconds: 1));
      }
    },
  );

  testWidgets(
    'retiring the account drops a window captured by the old workspace',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final cache = _Cache()
        ..holdRead = true
        ..holdDraft = false;
      final client = HistoryClient()..offline = true;
      final w = receiver(client, cache);
      w.channel = w.channels.single;
      cache.window = {
        'version': 1,
        'windowKind': 'tail',
        'parentChannelId': 'chat',
        'channelId': 'chat',
        'authority': messageWindowAuthority('owner', w.channel!.json),
        'messages': [row('chat', 42)],
        'hasMore': false,
      };
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        late Future<void> opening;
        await t.runAsync(() async {
          opening = w.selectChannel(w.channels.single, autoRead: false);
        });
        await drainIo(t, cache.captured.future);
        final retiring = w.retireCache();
        await t.runAsync(() async {
          cache.releaseRead.complete();
        });
        await drainIo(t, Future.wait([opening, retiring]));
        await t.pump();
        expect(w.messageDomain.messages, isEmpty);
        expect(find.text('Saved message 42 中文'), findsNothing);
      } finally {
        cache.release.complete();
        if (!cache.releaseRead.isCompleted) cache.releaseRead.complete();
        await drainIo(t, w.flushCache());
        await t.pumpWidget(const SizedBox());
        w.dispose();
        await client.arrivals.close();
        await cache.close();
        await t.pump(const Duration(seconds: 1));
      }
    },
  );
}

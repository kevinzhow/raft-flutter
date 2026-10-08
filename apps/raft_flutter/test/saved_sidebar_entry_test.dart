import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/saved_sidebar_entry.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    serverId = 's';
  }
  int total = 105;
  bool fail = false;
  Completer<dynamic>? pending;
  final reads = <Map<String, dynamic>?>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/saved') {
      reads.add(query);
      if (pending != null) return pending!.future;
      if (fail) throw const RaftApiException('Unavailable');
      return {
        'globalTotal': total,
        'total': total,
        'saved': [
          {'content': 'Do not cache private body'},
        ],
      };
    }
    return {'channels': {}};
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async => {'ok': true};
}

void main() {
  Future<void> host(WidgetTester t, WorkspaceController w) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: SavedSidebarEntry(
            controller: w,
            onTap: () => w.setSection('saved'),
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets(
    'Saved uses true globalTotal and accepted save receipts, never loaded-page length',
    (t) async {
      final client = _Client();
      final controller = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      await host(t, controller);
      expect(t.widget<RaftNavItem>(find.byType(RaftNavItem)).count, 105);
      expect(client.reads.single, {'limit': 1, 'offset': 0, 'sort': 'desc'});
      client.total = 106;
      await controller.command(
        'POST',
        '/channels/saved',
        data: {'messageId': 'owned'},
      );
      await t.pump();
      expect(controller.savedRevision, 1);
      expect(t.widget<RaftNavItem>(find.byType(RaftNavItem)).count, 106);
      client.fail = true;
      controller.savedRevision++;
      controller.notifyListeners();
      await t.pump();
      expect(t.widget<RaftNavItem>(find.byType(RaftNavItem)).count, 106);
      expect(find.text('Do not cache private body'), findsNothing);
      await t.tap(find.text('Saved'));
      expect(controller.section, 'saved');
      await t.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await client.dispose();
    },
  );
  testWidgets(
    'same-generation role reset clears total and rejects pending earlier authority',
    (t) async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      await host(t, w);
      expect(t.widget<RaftNavItem>(find.byType(RaftNavItem)).count, 105);
      final old = Completer<dynamic>();
      client.pending = old;
      w.savedRevision++;
      w.notifyListeners();
      await t.pump();
      client.pending = null;
      client.total = 2;
      w.server = RaftRecord({'id': 's', 'role': 'member'});
      w.notifyListeners();
      await t.pump();
      expect(t.widget<RaftNavItem>(find.byType(RaftNavItem)).count, 2);
      old.complete({'globalTotal': 999});
      await t.pump();
      expect(t.widget<RaftNavItem>(find.byType(RaftNavItem)).count, 2);
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.dispose();
    },
  );
}

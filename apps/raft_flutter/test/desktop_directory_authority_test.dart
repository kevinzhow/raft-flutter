import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_ui/raft_ui.dart';

class _DirectoryClient extends RaftClient {
  _DirectoryClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  Completer<dynamic>? pending;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (pending != null) return pending!.future;
    if (path == '/agents') {
      return [
        {'id': 'agent', 'name': 'Current agent'},
      ];
    }
    if (path.endsWith('/members')) {
      return [
        {'userId': 'human', 'name': 'Private human'},
      ];
    }
    if (path.endsWith('/machines')) {
      return [
        {'id': 'machine', 'name': 'Current computer'},
      ];
    }
    return [];
  }
}

void main() {
  testWidgets(
    'directory selection is controlled and revoked payload is removed immediately',
    (t) async {
      final client = _DirectoryClient();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      DesktopContentTarget? selected;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: DesktopDirectoryView(
                controller: w,
                onSelected: (value) => selected = value,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Current agent'), findsOneWidget);
      expect(find.text('Private human'), findsOneWidget);
      await t.tap(find.text('Private human'));
      expect(selected!.id, 'human');
      expect(selected!.kind, DesktopContentKind.human);
      // Pending replacement must not keep an accepted owner payload visible.
      client.pending = Completer<dynamic>();
      w.server = RaftRecord({
        'id': 's',
        'role': 'member',
        'hideHumansFromMembers': true,
      });
      w.notifyListeners();
      await t.pump();
      expect(find.text('Private human'), findsNothing);
      expect(find.text('Current agent'), findsNothing);
      client.pending!.complete([
        {'id': 'agent', 'name': 'Permitted agent'},
      ]);
      await t.pumpAndSettle();
      expect(find.text('Private human'), findsNothing);
      expect(find.text('Permitted agent'), findsOneWidget);
    },
  );

  testWidgets(
    'late prior-workspace directory cannot populate the next workspace',
    (t) async {
      final client = _DirectoryClient()..pending = Completer<dynamic>();
      final old = client.pending!;
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: DesktopDirectoryView(controller: w, onSelected: (_) {}),
          ),
        ),
      );
      await t.pump();
      client.pending = null;
      client.selectServer('next');
      w.server = RaftRecord({'id': 'next', 'role': 'owner'});
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(find.text('Private human'), findsOneWidget);
      old.complete([
        {'id': 'old', 'userId': 'old', 'name': 'Old private result'},
      ]);
      await t.pumpAndSettle();
      expect(find.text('Old private result'), findsNothing);
      expect(find.text('Private human'), findsOneWidget);
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final reads = <Completer<dynamic>>[];
  Completer<dynamic>? pendingCommand;
  int commands = 0;
  bool queueReads = false, missing = false;
  static const computer = {
    'id': 'machine',
    'name': 'Private computer',
    'userId': 'alice',
    'isComputer': true,
    'status': 'online',
  };
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (queueReads) {
      final pending = Completer<dynamic>();
      reads.add(pending);
      return pending.future;
    }
    if (path.endsWith('/machines')) {
      return {
        'machines': missing ? [] : [computer],
      };
    }
    return [];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands++;
    return pendingCommand?.future ?? {'apiKey': 'TEST_ONLY_NOT_A_CREDENTIAL'};
  }
}

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() {
    c = _Client()..user = RaftRecord({'id': 'alice'});
    c.selectServer('s');
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
  });
  tearDown(() async {
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });
  Future<void> detail(WidgetTester t, {Widget? child}) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const Text('Preserved workspace'),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          child ??
                          FleetDetail(
                            controller: w,
                            computers: true,
                            initial: _Workspace.computer,
                          ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump();
  }

  testWidgets(
    'directory clears same-generation account rows and rejects late old HTTP',
    (t) async {
      w.queueReads = true;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(body: FleetView(controller: w, computers: false)),
        ),
      );
      await t.pump();
      expect(w.reads.length, 1);
      final generation = c.generation;
      c.user = RaftRecord({'id': 'bob'});
      w.notifyListeners();
      await t.pump();
      expect(c.generation, generation);
      expect(w.reads.length, 2);
      w.reads.first.complete([
        {'id': 'old', 'name': 'Alice private row'},
      ]);
      await t.pump();
      expect(find.text('Alice private row'), findsNothing);
      w.reads.last.complete([
        {'id': 'new', 'name': 'Bob authorized row'},
      ]);
      await t.pumpAndSettle();
      expect(find.text('Bob authorized row'), findsOneWidget);
    },
  );
  testWidgets(
    'same-generation authority loss closes credential and blocks retained copy/submit',
    (t) async {
      final clipboard = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard.add('${call.arguments}');
            }
            return null;
          });
      await detail(t);
      await t.ensureVisible(find.text('Rotate computer key'));
      await t.tap(find.text('Rotate computer key'));
      await t.pumpAndSettle();
      final form = t.widget<RaftFormDialog>(find.byType(RaftFormDialog));
      await t.tap(find.text('Continue'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump();
      expect(find.text('Save this credential'), findsOneWidget);
      final copy = t.widget<RaftSecretView>(find.byType(RaftSecretView)).onCopy;
      final generation = c.generation;
      w.server = RaftRecord({'id': 's', 'role': 'member'});
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(c.generation, generation);
      expect(find.text('Save this credential'), findsNothing);
      expect(find.text('Preserved workspace'), findsOneWidget);
      await copy('TEST_ONLY_NOT_A_CREDENTIAL');
      expect(clipboard, isEmpty);
      await expectLater(form.onSubmit({}), throwsA(isA<RaftApiException>()));
      expect(w.commands, 1);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    },
  );
  testWidgets(
    'same-role account adoption drops a delayed private credential reply',
    (t) async {
      w.pendingCommand = Completer<dynamic>();
      await detail(t);
      await t.ensureVisible(find.text('Rotate computer key'));
      await t.tap(find.text('Rotate computer key'));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pump();
      final generation = c.generation;
      c.user = RaftRecord({'id': 'bob'});
      w.notifyListeners();
      await t.pumpAndSettle();
      w.pendingCommand!.complete({'apiKey': 'TEST_ONLY_NOT_A_CREDENTIAL'});
      await t.pumpAndSettle();
      expect(c.generation, generation);
      expect(find.text('Save this credential'), findsNothing);
      expect(find.byType(RaftSecretView), findsNothing);
      expect(find.text('Preserved workspace'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'socket deletion before DELETE reply closes owned routes once and preserves workspace',
    (t) async {
      w.pendingCommand = Completer<dynamic>();
      await detail(t);
      await t.ensureVisible(find.text('Delete computer'));
      await t.tap(find.text('Delete computer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pump();
      expect(w.commands, 1);
      w.missing = true;
      c.stream.add(RaftEvent('machine:deleted', {'id': 'machine'}));
      await t.pump(const Duration(milliseconds: 200));
      await t.pumpAndSettle();
      expect(find.text('Preserved workspace'), findsOneWidget);
      expect(find.byType(FleetDetail), findsNothing);
      w.pendingCommand!.complete({});
      await t.pumpAndSettle();
      expect(find.text('Preserved workspace'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'inspection rejects stale rows and late file bytes after account change',
    (t) async {
      w.queueReads = true;
      await detail(
        t,
        child: FleetInspection(
          controller: w,
          base: '/agents/a',
          kind: 'workspace-files',
          computers: false,
        ),
      );
      w.reads.single.complete({
        'files': [
          {'name': 'private.txt', 'path': 'private.txt'},
        ],
      });
      await t.pumpAndSettle();
      await t.tap(find.text('private.txt'));
      await t.pump();
      expect(w.reads.length, 2);
      c.user = RaftRecord({'id': 'bob'});
      w.notifyListeners();
      await t.pumpAndSettle();
      w.reads.last.complete({'content': 'Alice private file bytes'});
      await t.pumpAndSettle();
      expect(find.text('Alice private file bytes'), findsNothing);
      expect(find.text('Preserved workspace'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}

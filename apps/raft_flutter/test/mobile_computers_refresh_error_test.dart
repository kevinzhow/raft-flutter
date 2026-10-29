import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

/// MobileComputersPanel states: the first read loads the list, later reads can
/// be made to fail.
class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  bool failMachines = false;
  int machineReads = 0;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/machines') {
      machineReads++;
      if (failMachines) throw const RaftApiException('down', status: 500);
      return {
        'machines': [
          {
            'id': 'c',
            'name': 'Studio Test Rig',
            'status': 'online',
            'statusVersion': 1,
          },
        ],
      };
    }
    return <dynamic>[];
  }
}

void main() {
  late _Client client;
  late _Workspace w;
  setUp(() async {
    client = _Client();
    w = _Workspace(client)..server = RaftRecord({'id': 's', 'role': 'owner'});
    await w.entityDirectory.preload();
  });
  tearDown(() async {
    w.dispose();
    await client.stream.close();
    await client.dispose();
  });

  Future<void> mount(WidgetTester t) => t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Scaffold(
          body: FleetView(controller: w, computers: true, onOpenDetail: (_) {}),
        ),
      ),
    ),
  );

  testWidgets('a failed refresh keeps the saved list under a Retry banner', (
    t,
  ) async {
    await mount(t);
    await t.pumpAndSettle();
    expect(find.text('Studio Test Rig'), findsOneWidget);
    expect(find.byKey(const ValueKey('computers-refresh-error')), findsNothing);

    w.failMachines = true;
    final reads = w.machineReads;
    unawaited(
      w.entityDirectory.refresh(WorkspaceEntityKind.computers, force: true),
    );
    await t.pumpAndSettle();
    expect(w.machineReads, greaterThan(reads));
    expect(
      find.byKey(const ValueKey('computers-refresh-error')),
      findsOneWidget,
    );
    expect(
      find.text("Couldn't refresh computers. Showing saved results."),
      findsOneWidget,
    );
    // The accepted row stays; the load-error state is not shown.
    expect(find.text('Studio Test Rig'), findsOneWidget);
    expect(find.text('Directory could not be loaded.'), findsNothing);

    // Retry re-reads and a good answer removes the banner.
    w.failMachines = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('computers-refresh-error')), findsNothing);
    expect(find.text('Studio Test Rig'), findsOneWidget);
  });
}

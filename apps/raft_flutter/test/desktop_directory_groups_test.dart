import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _GroupingClient extends RaftClient {
  _GroupingClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'self'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final requests = <String>[];
  var deniedMachines = false;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    requests.add(path);
    if (path == '/agents') {
      return [
        {
          'id': 'a',
          'name': 'First agent',
          'machineId': 'second',
          'avatarUrl': 'pixel:bot-1',
        },
        {'id': 'b', 'name': 'Second agent', 'machineId': 'first'},
        {'id': 'c', 'name': 'Third agent', 'machineId': 'second'},
        {'id': 'd', 'name': 'Unassigned agent'},
      ];
    }
    if (path.endsWith('/members')) {
      return [
        {
          'userId': 'self',
          'name': 'Kevin',
          'displayName': '',
          'description': 'Product builder',
        },
      ];
    }
    if (path.endsWith('/machines')) {
      if (deniedMachines) throw StateError('auxiliary directory unavailable');
      return [
        {'id': 'first', 'name': 'First computer'},
        {'id': 'second', 'name': 'Second computer'},
      ];
    }
    return [];
  }
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'authorized grouped directory $family/$dark preserves order and collapse',
      (t) async {
        final client = _GroupingClient();
        final w = WorkspaceController(client)
          ..server = RaftRecord({'id': 's', 'role': 'owner'});
        addTearDown(() async {
          w.dispose();
          await client.stream.close();
          await client.dispose();
        });
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 240,
                child: DesktopDirectoryView(controller: w, onSelected: (_) {}),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final groups = t
            .widgetList<RaftSidebarMachineGroup>(
              find.byType(RaftSidebarMachineGroup),
            )
            .toList();
        expect(groups.map((g) => g.name), [
          'Second computer',
          'First computer',
          'No computer',
        ]);
        expect(groups.map((g) => g.count), [2, 1, 1]);
        final row = find.byKey(const ValueKey('desktop-directory-agent-a'));
        final avatar = t.widget<RaftAvatarContent>(
          find.descendant(of: row, matching: find.byType(RaftAvatarContent)),
        );
        expect(avatar.pixelKey, 'bot-1');
        expect(find.text('Kevin (you)', findRichText: true), findsOneWidget);
        expect(find.text('Product builder'), findsOneWidget);
        expect(find.byTooltip('Refresh'), findsNothing);
        await t.tap(
          find.byKey(const ValueKey('directory-machine-disclosure-second')),
        );
        await t.pumpAndSettle();
        expect(find.text('First agent'), findsNothing);
        expect(find.text('Third agent'), findsNothing);
        expect(find.text('Second agent'), findsOneWidget);
        client.stream.add(RaftEvent('agent:updated', {'id': 'b'}));
        await t.pumpAndSettle();
        expect(find.text('First agent'), findsNothing);
        // Revocation retires names, private projections and remembered folds.
        w.server = RaftRecord({'id': 's', 'role': 'guest'});
        w.notifyListeners();
        await t.pumpAndSettle();
        expect(find.byType(RaftSidebarMachineGroup), findsNothing);
        expect(find.text('Kevin (you)', findRichText: true), findsNothing);
        final requestCount = client.requests.length;
        await t.pump(const Duration(seconds: 1));
        expect(client.requests.length, requestCount);
        w.server = RaftRecord({'id': 's', 'role': 'owner'});
        w.notifyListeners();
        await t.pumpAndSettle();
        expect(find.text('First agent'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('auxiliary machine failure keeps permitted member rows', (
    t,
  ) async {
    final client = _GroupingClient()..deniedMachines = true;
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'member'});
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
      await client.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: DesktopDirectoryView(controller: w, onSelected: (_) {}),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('First agent'), findsOneWidget);
    expect(find.text('Kevin (you)', findRichText: true), findsOneWidget);
    expect(find.text('Directory could not be loaded.'), findsNothing);
    expect(t.takeException(), isNull);
  });
}

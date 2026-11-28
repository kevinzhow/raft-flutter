import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

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
        {
          'id': 'agent',
          'name': 'Current agent',
          'description': 'Shared Source row',
        },
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
  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        'touch directory ${dark ? 'dark' : 'light'}/$width retains Source avatar, row and selection',
        (t) async {
          final compact = width < 768;
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final client = _DirectoryClient();
          final w = WorkspaceController(client)
            ..server = RaftRecord({'id': 's', 'role': 'owner'});
          addTearDown(() async {
            w.dispose();
            await client.stream.close();
            await client.dispose();
          });
          DesktopContentTarget? selected;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark)
                  .copyWith(platform: TargetPlatform.android),
              home: Scaffold(
                body: DesktopDirectoryView(
                  controller: w,
                  mobileRoot: compact,
                  onSelected: (value) => selected = value,
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final row = find.byKey(
            const ValueKey('desktop-directory-agent-agent'),
          );
          final avatar = find.descendant(
            of: row,
            matching: find.byType(RaftAvatar),
          );
          expect(t.getSize(avatar), Size.square(compact ? 19 : 35));
          expect(
            find.descendant(of: row, matching: find.text('Shared Source row')),
            findsOneWidget,
          );
          if (compact) {
            final control = find.descendant(
              of: row,
              matching: find.byType(RaftControl),
            );
            expect(t.getSize(control).height, 60);
            expect(t.getSize(row).height - t.getSize(control).height, 2);
          } else {
            final card = find.descendant(
              of: row,
              matching: find.byType(RaftCard),
            );
            expect(t.getSize(card).height, greaterThanOrEqualTo(56));
          }
          expect(row.hitTestable(), findsOneWidget);
          await t.tap(row);
          expect(selected!.kind, DesktopContentKind.agent);
          expect(selected!.id, 'agent');
          expect(t.takeException(), isNull);
        },
      );
    }
  }
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
          theme: raftTheme(),
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
          theme: raftTheme(),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final commands = <(String, String, dynamic)>[];
  Completer<dynamic>? pending;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/machines') ? {'machines': <dynamic>[]} : <dynamic>[];
  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add((method, path, data));
    return pending?.future ??
        {
          'id': 'created',
          'machine': {'id': 'created'},
          'apiKey': 'TEST_ONLY_NOT_A_CREDENTIAL',
        };
  }
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [390.0, 1280.0]) {
      for (final computer in [false, true]) {
        testWidgets(
          '[K12a] $family/$dark/$width real ${computer ? 'computer' : 'agent'} Add control opens and submits',
          (t) async {
            t.view.physicalSize = Size(width, 844);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            final c = _Client();
            final w = _Workspace(c)
              ..server = RaftRecord({'id': 's', 'role': 'owner'});
            addTearDown(() async {
              w.dispose();
              await c.stream.close();
              await c.dispose();
            });
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(family, dark: dark),
                home: Scaffold(
                  body: DesktopDirectoryView(
                    controller: w,
                    computers: computer,
                    mobileRoot: width < 768,
                    onSelected: (_) {},
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            await t.tap(
              find.byKey(
                ValueKey(
                  'desktop-directory-add-${computer ? 'computer' : 'agent'}',
                ),
              ),
            );
            await t.pumpAndSettle();
            if (!computer) {
              final managed = find.widgetWithText(RaftMenuItem, 'Create agent');
              expect(managed, findsOneWidget);
              await t.tap(managed);
              await t.pumpAndSettle();
              expect(find.text('Connect a computer first'), findsOneWidget);
              await t.tap(find.byTooltip('Close'));
              await t.pumpAndSettle();
              await t.tap(
                find.byKey(const ValueKey('desktop-directory-add-agent')),
              );
              await t.pumpAndSettle();
              await t.tap(
                find.widgetWithText(RaftMenuItem, 'Create external agent'),
              );
              await t.pumpAndSettle();
            }
            if (computer) {
              // Web AddMachineDialog: choose Your Computer, then Next
              // registers a placeholder row and shows the connect commands;
              // the one-time key is never displayed.
              expect(find.byType(RaftAddComputerDialog), findsOneWidget);
              await t.tap(find.byKey(const ValueKey('add-computer-next')));
              await t.pumpAndSettle();
              expect(w.commands, hasLength(1));
              expect(w.commands.single.$1, 'POST');
              expect(w.commands.single.$2, '/servers/s/machines');
              expect((w.commands.single.$3 as Map)['name'], 'my-computer');
              expect(
                find.byKey(const ValueKey('add-computer-waiting')),
                findsOneWidget,
              );
              expect(
                find.text('Waiting for computer to connect...'),
                findsOneWidget,
              );
              expect(find.text('TEST_ONLY_NOT_A_CREDENTIAL'), findsNothing);
              expect(t.takeException(), isNull);
              return;
            }
            expect(find.byType(RaftFormDialog), findsOneWidget);
            await t.enterText(find.byType(TextField).first, 'Own resource');
            await t.tap(
              find.widgetWithText(RaftButton, computer ? 'Register' : 'Create'),
            );
            await t.pumpAndSettle();
            expect(w.commands, hasLength(1));
            expect(w.commands.single.$1, 'POST');
            expect(
              w.commands.single.$2,
              computer ? '/servers/s/machines' : '/agents',
            );
            expect((w.commands.single.$3 as Map)['name'], 'Own resource');
            if (computer) {
              expect(find.text('Credential hidden'), findsOneWidget);
              expect(find.text('TEST_ONLY_NOT_A_CREDENTIAL'), findsNothing);
            } else {
              expect((w.commands.single.$3 as Map)['external'], true);
            }
            expect(t.takeException(), isNull);
          },
        );
      }
    }
    testWidgets(
      '[K12b] $family/$dark revoke closes actual menu and drops late creation',
      (t) async {
        final c = _Client();
        final w = _Workspace(c)
          ..server = RaftRecord({'id': 's', 'role': 'owner'});
        addTearDown(() async {
          w.dispose();
          await c.stream.close();
          await c.dispose();
        });
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: DesktopDirectoryView(controller: w, onSelected: (_) {}),
            ),
          ),
        );
        await t.pumpAndSettle();
        final add = find.byKey(const ValueKey('desktop-directory-add-agent'));
        await t.tap(add);
        await t.pumpAndSettle();
        expect(
          find.widgetWithText(RaftMenuItem, 'Create external agent'),
          findsOneWidget,
        );
        w.server = RaftRecord({'id': 's', 'role': 'viewer'});
        w.notifyListeners();
        await t.pumpAndSettle();
        expect(find.byType(RaftMenuItem), findsNothing);
        expect(add, findsNothing);
        w.server = RaftRecord({'id': 's', 'role': 'owner'});
        w.notifyListeners();
        await t.pumpAndSettle();
        await t.tap(add);
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(RaftMenuItem, 'Create external agent'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField).first, 'Old account resource');
        w.pending = Completer<dynamic>();
        await t.tap(find.widgetWithText(RaftButton, 'Create'));
        await t.pump();
        c.user = RaftRecord({'id': 'bob'});
        w.notifyListeners();
        await t.pumpAndSettle();
        expect(find.byType(RaftFormDialog), findsNothing);
        w.pending!.complete({'id': 'old-private-row'});
        await t.pumpAndSettle();
        expect(find.text('Old account resource'), findsNothing);
        expect(find.text('Save this credential'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
}

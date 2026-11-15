import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

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
  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [390.0, 1280.0]) {
      for (final computer in [false, true]) {
        testWidgets(
          '[K12a] ${dark ? 'dark' : 'light'}/$width real ${computer ? 'computer' : 'agent'} Add control opens and submits',
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
                theme: raftTheme(dark: dark),
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
            // The Add Computer dialog's waiting spinner never settles.
            if (computer) {
              await t.pump();
              await t.pump(const Duration(milliseconds: 400));
            } else {
              await t.pumpAndSettle();
            }
            if (!computer) {
              final managed = find.widgetWithText(RaftMenuItem, 'Create Agent');
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
              // Web v1.24 AddMachineDialog opens on the connect commands and
              // registers nothing; the one-time key is never displayed.
              expect(find.byType(RaftAddComputerDialog), findsOneWidget);
              await t.pump(const Duration(milliseconds: 400));
              expect(w.commands, isEmpty);
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
            // Web v1.24 CreateExternalAgentDialog: step 1, then Next.
            expect(
              find.byKey(const ValueKey('create-external-agent-dialog')),
              findsOneWidget,
            );
            await t.enterText(
              find.byKey(const ValueKey('create-external-agent-name')),
              'Own resource',
            );
            await t.pump();
            await t.tap(
              find.byKey(const ValueKey('create-external-agent-next')),
            );
            await t.pumpAndSettle();
            final first = w.commands.first;
            expect(first.$1, 'POST');
            expect(first.$2, '/agents');
            expect((first.$3 as Map)['name'], 'Own resource');
            expect((first.$3 as Map)['external'], true);
            expect(t.takeException(), isNull);
          },
        );
      }
    }
    testWidgets(
      '[K12b] ${dark ? 'dark' : 'light'} revoke closes actual menu and drops late creation',
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
            theme: raftTheme(dark: dark),
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
        await t.enterText(
          find.byKey(const ValueKey('create-external-agent-name')),
          'Old account resource',
        );
        await t.pump();
        w.pending = Completer<dynamic>();
        await t.tap(find.byKey(const ValueKey('create-external-agent-next')));
        await t.pump();
        c.user = RaftRecord({'id': 'bob'});
        w.notifyListeners();
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('create-external-agent-dialog')),
          findsNothing,
        );
        w.pending!.complete({'id': 'old-private-row'});
        await t.pumpAndSettle();
        expect(find.text('Old account resource'), findsNothing);
        expect(find.text('Save this credential'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
}

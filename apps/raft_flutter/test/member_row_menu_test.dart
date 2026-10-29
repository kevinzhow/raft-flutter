import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'self'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final commands = <String>[];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/agents') {
      return [
        {
          'id': 'on',
          'name': 'Online agent',
          'machineId': 'm',
          'status': 'active',
        },
        {'id': 'off', 'name': 'Offline agent', 'machineId': 'm'},
        {
          'id': 'ext',
          'name': 'External agent',
          'runtime': 'external',
          'external': true,
        },
      ];
    }
    if (path.endsWith('/members')) {
      return [
        {'userId': 'self', 'name': 'Kevin'},
        {'userId': 'u2', 'name': 'Alice'},
      ];
    }
    if (path.endsWith('/machines')) {
      return [
        {'id': 'm', 'name': 'Machine'},
      ];
    }
    return [];
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
  }) async {
    if (method == 'GET') return get(path, query: query);
    commands.add('$method $path ${data ?? ''}'.trim());
    return {};
  }
}

/// Web Sidebar `member-human` / `member-agent` context menu: Message for
/// everyone, Start / Stop and Restart / Reset for a managed agent the viewer
/// may control.
void main() {
  for (final (family, dark) in raftThemeMatrix([
    (raftThemePackId, false),
    (raftThemePackId, true),
    (brutalThemePackId, false),
    (elegantThemePackId, false),
    (elegantThemePackId, true),
  ], look: (v) => raftLookOf(v.$1))) {
    Future<(WorkspaceController, _Client, List<DesktopContentTarget>)> mount(
      WidgetTester t, {
      String role = 'owner',
      bool longPress = false,
    }) async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'role': role});
      final opened = <DesktopContentTarget>[];
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
        await client.dispose();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(family), dark: dark),
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: DesktopDirectoryView(
                controller: w,
                onSelected: (_) {},
                onOpenDm: (target) async => opened.add(target),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      return (w, client, opened);
    }

    Future<void> rightClick(WidgetTester t, String key) async {
      await t.tapAt(
        t.getCenter(find.byKey(ValueKey(key))),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await t.pumpAndSettle();
    }

    testWidgets('$family/$dark a person row offers Message only', (t) async {
      final (_, client, opened) = await mount(t);
      await rightClick(t, 'desktop-directory-human-u2');
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Restart / Reset'), findsNothing);
      await t.tap(find.text('Message'));
      await t.pumpAndSettle();
      expect(opened.single.kind, DesktopContentKind.human);
      expect(opened.single.id, 'u2');
      expect(client.commands, isEmpty);
      expect(find.text('Message'), findsNothing, reason: 'the menu closed');
    });

    testWidgets('$family/$dark an online managed agent: Stop asks first, then '
        'posts /stop', (t) async {
      final (_, client, _) = await mount(t);
      await rightClick(t, 'desktop-directory-agent-on');
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Restart / Reset'), findsOneWidget);
      await t.tap(find.text('Stop'));
      await t.pumpAndSettle();
      // Web: a "Stop Agent" confirmation, no request yet.
      expect(find.text('Stop Agent'), findsWidgets);
      expect(client.commands, isEmpty);
      await t.tap(find.text('Stop Agent').last);
      await t.pumpAndSettle();
      expect(client.commands, ['POST /agents/on/stop {}']);
    });

    testWidgets('$family/$dark an offline agent: Start posts at once, no '
        'confirmation', (t) async {
      final (_, client, _) = await mount(t);
      await rightClick(t, 'desktop-directory-agent-off');
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
      await t.tap(find.text('Start'));
      await t.pumpAndSettle();
      expect(client.commands, ['POST /agents/off/start {}']);
    });

    testWidgets('$family/$dark Restart / Reset opens the reset dialog and '
        'posts the chosen mode', (t) async {
      final (_, client, _) = await mount(t);
      await rightClick(t, 'desktop-directory-agent-off');
      await t.tap(find.text('Restart / Reset'));
      await t.pumpAndSettle();
      expect(find.byType(RaftResetAgentDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-reset-option-restart')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('agent-reset-option-session')));
      await t.pump();
      // The confirm button now carries the chosen mode.
      await t.tap(find.textContaining('Reset Session & Restart').last);
      await t.pumpAndSettle();
      expect(client.commands, ['POST /agents/off/reset {mode: session}']);
    });

    testWidgets('$family/$dark an external agent gets no runtime entries', (
      t,
    ) async {
      await mount(t);
      await rightClick(t, 'desktop-directory-agent-ext');
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Restart / Reset'), findsNothing);
    });

    testWidgets('$family/$dark a long press opens the same menu', (t) async {
      await mount(t);
      await t.longPress(
        find.byKey(const ValueKey('desktop-directory-agent-on')),
      );
      await t.pumpAndSettle();
      expect(find.text('Restart / Reset'), findsOneWidget);
    });
  }
}

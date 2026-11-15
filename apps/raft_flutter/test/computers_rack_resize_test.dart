// The side panel beside the rack is drag-resizable (Web ColumnResizeHandle
// column="detail": the profile panel's 300 to 600, kept on the device).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_preferences.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_page.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_flutter/features/panel_width_store.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<Map<String, dynamic>> machines = [];
  List<Map<String, dynamic>> agents = [];
  final commands = <(String, String, dynamic)>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/machines')) {
      return {'machines': machines.map(Map<String, dynamic>.from).toList()};
    }
    if (path == '/agents') {
      return agents.map(Map<String, dynamic>.from).toList();
    }
    return <dynamic>[];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add((method, path, data));
    return <String, dynamic>{};
  }
}

Map<String, dynamic> computer(
  String id, [
  Map<String, dynamic> extra = const {},
]) => {
  'id': id,
  'name': id,
  'status': 'online',
  'isComputer': true,
  'computerVersion': '1.0.60',
  'os': 'linux',
  'osRelease': 'Ubuntu 26.04',
  'hostname': '$id.host',
  'runtimes': ['claude'],
  'userId': 'bob',
  ...extra,
};

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
    ComputersRackPreferences.instance.resetForTests();
    c = _Client();
    w = _Workspace(c)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});
  });
  tearDown(() async {
    ComputersRackPreferences.instance.resetForTests();
    DevicePreferences.reset();
  });

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await c.stream.close();
      await c.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ComputersRackDesktopPage(
            controller: w,
            target: const DesktopContentTarget(
              DesktopContentKind.computer,
              'alpha',
            ),
            onSelected: (_) {},
            detail: const SizedBox.expand(key: ValueKey('detail-body')),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  double panelWidth(WidgetTester t) =>
      t.getSize(find.byKey(const ValueKey('computers-rack-side-panel'))).width;

  Future<void> dragHandle(WidgetTester t, double dx) async {
    final handle = find.byKey(const ValueKey('rack-side-panel-resize-handle'));
    final g = await t.startGesture(t.getCenter(handle));
    await g.moveBy(Offset(dx, 0));
    await t.pump();
    await g.up();
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('dragging the panel edge resizes it inside 300 to 600', (
    t,
  ) async {
    w.machines = [computer('alpha')];
    await open(t);
    expect(panelWidth(t), 380);
    await dragHandle(t, -100);
    expect(panelWidth(t), 480);
    await dragHandle(t, -400);
    expect(panelWidth(t), 600, reason: 'the widest the panel can be');
    await dragHandle(t, 700);
    expect(panelWidth(t), 300, reason: 'the narrowest');
  });

  testWidgets('the width a drag ended on is the next open\'s width', (t) async {
    w.machines = [computer('alpha')];
    await open(t);
    await dragHandle(t, -60);
    expect(profilePanelWidth.value, 440);
  });

  testWidgets('keys and double click work as Web ColumnResizeHandle', (
    t,
  ) async {
    w.machines = [computer('alpha')];
    await open(t);
    final handle = find.byKey(const ValueKey('rack-side-panel-resize-handle'));
    // Focus the handle (a tap on it does not move it).
    final focusNode = Focus.of(
      t.element(find.descendant(of: handle, matching: find.byType(SizedBox)).first),
    );
    focusNode.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pump();
    expect(
      panelWidth(t),
      396,
      reason: 'the panel is on the right: left grows it by 16',
    );
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(panelWidth(t), 364);
    await t.sendKeyEvent(LogicalKeyboardKey.home);
    await t.pump();
    expect(panelWidth(t), 300);
    await t.sendKeyEvent(LogicalKeyboardKey.end);
    await t.pump();
    expect(panelWidth(t), 600);
    // A double click restores the default width.
    await t.tap(handle);
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(handle);
    await t.pump(const Duration(milliseconds: 400));
    expect(panelWidth(t), 380);
  });
}

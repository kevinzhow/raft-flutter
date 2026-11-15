import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/runtime_auth_fixture.dart';

/// Web MachineRuntimeChips: on the Computer page every detected runtime with
/// usage or a sign-in from here opens its card (not only usage runtimes);
/// one with neither stays a plain chip.
class _Workspace extends FixtureWorkspace {
  _Workspace(super.client);
  Map<String, dynamic> view = authView();

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/runtime-auth') ? view : super.query(path, query: query);
}

Map<String, dynamic> machine({bool attached = true}) => {
  'id': 'c',
  'name': 'build-box',
  'isComputer': true,
  'status': 'online',
  'computerVersion': '1.4.0',
  'runtimes': ['pi', 'cursor', 'claude'],
  'computerAttachedByCurrentUser': attached,
};

void main() {
  late _Workspace w;
  Finder chip(String id) => find.byKey(ValueKey('runtime-usage-c-$id'));

  Future<void> mount(
    WidgetTester t, {
    bool attached = true,
    bool canAct = true,
  }) async {
    final client = FixtureClient();
    w = _Workspace(client)
      ..view = authView(
        canAct: canAct,
        supported: ['claude', 'codex', 'pi'],
        runtimes: {
          'pi': {'kind': 'logged_out'},
          'claude': {'kind': 'logged_in'},
        },
      );
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
      await client.dispose();
    });
    await w.entityDirectory.preload();
    t.view.physicalSize = const Size(900, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: ComputerDetailPanel(
            controller: w,
            machine: machine(attached: attached),
          ),
        ),
      ),
    );
    await settle(t, 8);
  }

  Future<void> hover(WidgetTester t, Finder at) async {
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(t.getCenter(at));
    await t.pump(const Duration(milliseconds: 210));
    await settle(t);
  }

  testWidgets('a detected Pi opens the sign-in card for a person who may '
      'act, with its action', (t) async {
    await mount(t);
    expect(chip('pi'), findsOneWidget);
    await hover(t, chip('pi'));
    expect(find.byKey(const ValueKey('runtime-usage-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('runtime-auth-add-provider')),
      findsOneWidget,
    );
  });

  testWidgets('a detected runtime with neither usage nor a sign-in stays a '
      'plain chip', (t) async {
    await mount(t);
    expect(find.text('Cursor CLI'), findsOneWidget);
    expect(chip('cursor'), findsNothing);
    await hover(t, find.text('Cursor CLI'));
    expect(find.byKey(const ValueKey('runtime-usage-card')), findsNothing);
  });

  testWidgets('a person who may not see the Computer\'s runtimes gets plain '
      'chips', (t) async {
    await mount(t, attached: false);
    expect(chip('pi'), findsNothing);
    expect(find.text('Pi'), findsOneWidget);
  });

  testWidgets('usage runtimes still open theirs', (t) async {
    await mount(t);
    expect(chip('claude'), findsOneWidget);
  });
}

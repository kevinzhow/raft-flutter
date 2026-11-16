import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_flutter/features/computer_runtime_chip_groups.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/runtime_auth_fixture.dart';

/// Web v1.24 MachineRuntimeChips: the detected runtimes (Qoder and Qwen
/// included) open their cards, an in-process runtime the Computer predates is
/// an "(update required)" warning chip, and the not-installed ones stay behind
/// "Show all supported".
class _Workspace extends FixtureWorkspace {
  _Workspace(super.client);
  Map<String, dynamic> view = authView();

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/runtime-auth') ? view : super.query(path, query: query);
}

Map<String, dynamic> machine() => {
  'id': 'c',
  'name': 'build-box',
  'isComputer': true,
  'status': 'online',
  'computerVersion': '1.4.0',
  'runtimes': ['claude', 'qoder', 'qwen', 'pi'],
  'computerAttachedByCurrentUser': true,
};

void main() {
  test(
    'the display list follows Web v1.24 and sorts a Computer\'s runtimes',
    () {
      expect(computerRuntimeOptions.map((r) => r.id), [
        'claude',
        'codex',
        'grok',
        'builtin',
        'kimi-sdk',
        'cursor',
        'opencode',
        'pi',
        'qwen',
        'qoder',
        'codebuddy',
      ]);
      final g = computerRuntimeChipGroups(['claude', 'qoder', 'pi']);
      expect(g.detected.map((r) => r.id), ['claude', 'pi', 'qoder']);
      // Only the in-process runtimes the Computer does not report.
      expect(g.updateComputer.map((r) => r.id), ['builtin', 'kimi-sdk']);
      expect(g.notInstalled.map((r) => r.id), [
        'codex',
        'grok',
        'cursor',
        'opencode',
        'qwen',
        'codebuddy',
      ]);
    },
  );

  late _Workspace w;

  Future<void> mount(WidgetTester t) async {
    final client = FixtureClient();
    w = _Workspace(client)
      ..view = authView(
        supported: ['claude', 'pi', 'qoder', 'qwen'],
        runtimes: {
          'qoder': {'kind': 'logged_out'},
          'qwen': {'kind': 'not_configured'},
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
          body: ComputerDetailPanel(controller: w, machine: machine()),
        ),
      ),
    );
    await settle(t, 8);
  }

  testWidgets('Qoder and Qwen are detected chips that open their cards', (
    t,
  ) async {
    await mount(t);
    expect(find.byKey(const ValueKey('runtime-usage-c-qoder')), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-usage-c-qwen')), findsOneWidget);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      t.getCenter(find.byKey(const ValueKey('runtime-usage-c-qoder'))),
    );
    await t.pump(const Duration(milliseconds: 210));
    await settle(t);
    expect(find.byKey(const ValueKey('runtime-usage-card')), findsOneWidget);
  });

  testWidgets('an in-process runtime the Computer predates is an update '
      'required warning chip; the rest waits behind Show all supported', (
    t,
  ) async {
    await mount(t);
    expect(find.text('Built-in Pi (update required)'), findsOneWidget);
    expect(find.text('Kimi Code (update required)'), findsOneWidget);
    expect(find.textContaining('update computer'), findsNothing);
    expect(find.text('Grok Build (not installed)'), findsNothing);
    final toggle = find.byKey(const ValueKey('machine-runtime-show-all'));
    expect(find.text('Show all supported'), findsOneWidget);
    await t.ensureVisible(toggle);
    await t.tap(toggle);
    await t.pump();
    expect(find.text('Grok Build (not installed)'), findsOneWidget);
    expect(
      find.text('CodeBuddy Code (experimental) (not installed)'),
      findsOneWidget,
    );
    expect(find.text('Show installed only'), findsOneWidget);
    await t.tap(toggle);
    await t.pump();
    expect(find.text('Grok Build (not installed)'), findsNothing);
  });

  testWidgets('the update chip says what to do', (t) async {
    await mount(t);
    final chip = find.byKey(const ValueKey('machine-runtime-chip-builtin'));
    await t.ensureVisible(chip);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(t.getCenter(chip));
    await t.pump(const Duration(milliseconds: 210));
    await settle(t);
    expect(
      find.text('Update Raft Computer to use Built-in Pi.'),
      findsOneWidget,
    );
  });
}

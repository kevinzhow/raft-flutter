import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/task_view_mode_preference.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;
import 'task_claim_flow_test.dart' show TaskPageWorkspace, row;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefs([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final loaded = await SharedPreferences.getInstance();
    DevicePreferences.adopt(loaded);
    return loaded;
  }

  tearDown(DevicePreferences.reset);

  test('only board and list are remembered modes', () async {
    final p = await prefs();
    expect(TaskViewModePreference.read(), isNull);
    TaskViewModePreference.write('sideways');
    expect(p.getString(TaskViewModePreference.preferenceKey), isNull);
    TaskViewModePreference.write('list');
    expect(TaskViewModePreference.read(), 'list');
    await p.setString(TaskViewModePreference.preferenceKey, 'garbage');
    expect(TaskViewModePreference.read(), isNull);
  });

  group('Tasks page', () {
    late ActivityClient client;
    late TaskPageWorkspace w;
    setUp(() {
      client = ActivityClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s1');
      w = TaskPageWorkspace(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channels = [
          RaftChannel({'id': 'c1', 'name': 'General', 'joined': true}),
        ]
        ..tasks = [row('a', 'todo')];
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Widget page() => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: ResourceView(
          controller: w,
          section: 'tasks',
          onMessage: (_, _) async {},
        ),
      ),
    );

    Future<String> mountedLayout(
      WidgetTester tester,
      Size size, {
      Map<String, Object> stored = const {},
    }) async {
      await prefs(stored);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(ResourceView));
      return state.taskLayout as String;
    }

    const desktop = Size(1400, 900), phone = Size(390, 844);

    testWidgets('without a choice the viewport decides', (tester) async {
      expect(await mountedLayout(tester, desktop), 'board');
      await tester.pumpWidget(const SizedBox.shrink());
      w.resourceSnapshots.clear();
      expect(await mountedLayout(tester, phone), 'list');
    });

    testWidgets('a remembered List beats the desktop default', (tester) async {
      expect(
        await mountedLayout(
          tester,
          desktop,
          stored: {TaskViewModePreference.preferenceKey: 'list'},
        ),
        'list',
      );
    });

    testWidgets('a remembered Board beats the phone default', (tester) async {
      expect(
        await mountedLayout(
          tester,
          phone,
          stored: {TaskViewModePreference.preferenceKey: 'board'},
        ),
        'board',
      );
    });

    testWidgets('picking a view stores it for the next start', (tester) async {
      expect(await mountedLayout(tester, desktop), 'board');
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      final p = DevicePreferences.current!;
      expect(p.getString(TaskViewModePreference.preferenceKey), 'list');
      // A new app start: no session snapshot, the same device preference.
      await tester.pumpWidget(const SizedBox.shrink());
      w.resourceSnapshots.clear();
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(ResourceView));
      expect(state.taskLayout, 'list');
    });
  });
}

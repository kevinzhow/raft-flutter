import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_master_detail.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  test('classic route rail mode does not follow retained conversation', () {
    expect(DesktopNavigationPolicy.forSection('saved').railMode, 'chat');
    for (final section in ['chat', 'saved', 'home']) {
      expect(
        DesktopNavigationPolicy.forSection(section).usesConversationSidebar,
        true,
      );
    }
    for (final section in [
      'tasks',
      'search',
      'activity',
      'settings',
      'members',
      'computers',
      'agents',
    ]) {
      expect(
        DesktopNavigationPolicy.forSection(section).usesConversationSidebar,
        false,
      );
    }
    expect(DesktopNavigationPolicy.forSection('agents').railMode, 'members');
    expect(
      DesktopNavigationPolicy.forSection('search').sidebarKind,
      DesktopSidebarKind.searchMaster,
    );
    expect(
      DesktopNavigationPolicy.forSection('activity').sidebarKind,
      DesktopSidebarKind.activityMaster,
    );
  });
  test(
    'content selection and late completions cannot cross authority or route',
    () {
      final navigation = DesktopNavigationState()
        ..bind('principalA/serverA/owner');
      navigation.selectRoute('search');
      final ticket = navigation.selectTarget(
        const DesktopContentTarget(
          DesktopContentKind.channel,
          'private',
          channelId: 'private',
        ),
      );
      expect(navigation.visibleRoute('chat'), 'search');
      expect(navigation.accepts('principalA/serverA/owner', ticket), true);
      navigation.bind('principalA/serverA/member');
      expect(navigation.target, isNull);
      expect(navigation.masterRoute, isNull);
      expect(navigation.accepts('principalA/serverA/owner', ticket), false);
      navigation.selectRoute('activity');
      final newer = navigation.selectTarget(
        const DesktopContentTarget(DesktopContentKind.thread, 'thread'),
      );
      navigation.closeTarget();
      expect(navigation.visibleRoute('activity'), 'activity');
      expect(navigation.accepts('principalA/serverA/member', newer), false);
      navigation.selectRoute('tasks');
      expect(navigation.masterRoute, isNull);
    },
  );
  testWidgets('absent conversation sidebar is not mounted or resized', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final section in ['chat', 'tasks', 'search', 'activity', 'settings']) {
      final visible = DesktopNavigationPolicy.forSection(section)
          .usesConversationSidebar;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftAdaptiveWorkspace(
              sidebarVisible: visible,
              sidebar: const Text('Conversation directory'),
              rail: const Text('Rail'),
              content: Text('Current $section'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Current $section'), findsOneWidget);
      expect(
        find.text('Conversation directory'),
        visible ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('sidebar-resize-handle')),
        visible ? findsOneWidget : findsNothing,
      );
    }
  });
  testWidgets('picked detail preserves real master state across open/close', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var detail = false;
    late StateSetter update;
    final text = TextEditingController();
    addTearDown(text.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return DesktopMasterDetail(
                master: ListView(
                  children: [
                    TextField(controller: text),
                    TextButton(
                      onPressed: () => setState(() => detail = true),
                      child: const Text('Open picked result'),
                    ),
                  ],
                ),
                detail: detail ? const Text('Selected entity') : null,
              );
            },
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'retained query');
    final state = t.state(find.byType(Scrollable).first);
    await t.tap(find.text('Open picked result'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('desktop-content-detail')), findsOneWidget);
    expect(t.getSize(find.byKey(const Key('desktop-master-panel'))).width, 560);
    expect(t.state(find.byType(Scrollable).first), same(state));
    update(() => detail = false);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('desktop-content-detail')), findsNothing);
    expect(text.text, 'retained query');
    expect(t.state(find.byType(Scrollable).first), same(state));
  });
}

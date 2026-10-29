import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/mobile_resource_direct.dart';
import 'package:raft_flutter/features/resource_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('the open tasks page reads the workspace on the first entry', (
    t,
  ) async {
    final f = RootFixture();
    await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/tasks'));
    await settle(t);
    expect(find.byType(MobileResourceDirectPage), findsOneWidget);
    await f.close(t);
  });

  for (final route in ['tasks', 'saved']) {
    testWidgets('direct $route ignores messages and presence', (t) async {
      final f = RootFixture();
      await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/$route'));
      await settle(t);
      expect(find.byType(MobileResourceDirectPage), findsOneWidget);
      final list = t.widget<ResourceView>(find.byType(ResourceView));
      for (var i = 0; i < 3; i++) {
        f.client.event('message:new', {
          'id': 'resource-quiet-$route-$i',
          'channelId': 'ca',
          'serverId': 'a',
          'seq': '${i + 2}',
          'content': 'Quiet $i',
          'senderId': 'bob',
          'senderType': 'user',
          'createdAt': '2026-10-15T05:30:00Z',
        });
        f.client.event('agent:activity', {
          'agentId': 'bob',
          'activity': 'typing',
        });
        await f.flush(t);
      }
      expect(t.widget<ResourceView>(find.byType(ResourceView)), same(list));
      f.workspace(t).applyMembershipRole({
        'userId': 'alice',
        'serverId': 'a',
        'role': 'member',
      });
      await f.flush(t);
      expect(
        t.widget<ResourceView>(find.byType(ResourceView)),
        isNot(same(list)),
      );
      await f.close(t);
    });
  }

  testWidgets('a direct list rebuilds only when its inputs change', (t) async {
    var wide = false;
    var builds = 0;
    late void Function(void Function()) set;
    await t.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setter) {
            set = setter;
            return MobileResourceDirectPage(
              inputs: wide,
              active: () => true,
              buildList: () {
                builds++;
                return Text(wide ? 'board' : 'list');
              },
            );
          },
        ),
      ),
    );
    expect(find.text('list'), findsOneWidget);
    final before = builds;
    set(() {});
    await t.pump();
    expect(builds, before);
    set(() => wide = true);
    await t.pump();
    expect(find.text('board'), findsOneWidget);
    expect(builds, before + 1);
  });

  testWidgets('direct tasks layout follows the window width', (t) async {
    final f = RootFixture();
    await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/tasks'));
    await settle(t);
    expect(find.byType(MobileResourceDirectPage), findsOneWidget);
    expect(find.byKey(const ValueKey('task-drop-todo')), findsNothing);
    t.view.physicalSize = const Size(1280, 900);
    await t.pump();
    await settle(t);
    expect(find.byKey(const ValueKey('task-drop-todo')), findsOneWidget);
    await f.close(t);
  });

  testWidgets('a covered tasks list is not mounted', (t) async {
    final f = RootFixture();
    await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/tasks'));
    await settle(t);
    expect(find.byType(ResourceView), findsOneWidget);
    await t.tap(find.byKey(const Key('mobile-tab-settings')));
    await f.flush(t);
    await settle(t);
    expect(
      find.descendant(
        of: find.byType(MobileResourceDirectPage),
        matching: find.byType(ResourceView),
      ),
      findsNothing,
    );
    await f.close(t);
  });

  testWidgets('a wide window keeps the tasks page on its own controller', (
    t,
  ) async {
    final f = RootFixture();
    await f.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha/tasks'));
    await settle(t);
    expect(find.byType(MobileResourceDirectPage), findsNothing);
    expect(find.byType(ResourceView), findsOneWidget);
    await f.close(t);
  });
}

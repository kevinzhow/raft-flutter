import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/page_layout.dart';

import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';

void main() {
  RaftLocation location(
    RaftRoute route, {
    String? id,
    List<String> settings = const [],
    Map<String, String> query = const {},
  }) => RaftLocation.at(
    serverSlug: 'mobile-navigation-test',
    route: route,
    entityId: id,
    settingsPath: settings,
    query: query,
  );

  test('Tab roots reset the visual stack; focus edits retain and tasks create pages', () {
    final navigation = WorkspaceNavigation();
    navigation.bind('isolated', location(RaftRoute.home));
    navigation.navigate(location(RaftRoute.channel, id: 'one'));
    expect(mobilePageEntries(navigation), hasLength(2));
    navigation.navigate(navigation.location.withQuery({'msg': 'focus'}));
    expect(mobilePageEntries(navigation), hasLength(2));
    navigation.navigate(navigation.location.withQuery({'task': 'one:task'}));
    expect(mobilePageEntries(navigation), hasLength(3));
    navigation.navigate(location(RaftRoute.settings));
    expect(mobilePageEntries(navigation), hasLength(1));
    navigation.navigate(location(RaftRoute.settings, settings: ['account']));
    expect(mobilePageEntries(navigation), hasLength(2));
    navigation.back();
    expect(mobilePageEntries(navigation), hasLength(1));
  });

  testWidgets(
    'Platform routes own separate live states and retain the root on Back',
    (tester) async {
      final navigation = WorkspaceNavigation();
      navigation.bind('isolated', location(RaftRoute.home));
      late StateSetter rebuild;
      var backCount = 0;
      var mountCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MobileWorkspacePages(
                navigation: navigation,
                onBack: () {
                  backCount++;
                  rebuild(() => backMobilePage(navigation));
                },
                pageBuilder: (_, location) => _LivePage(
                  onMount: () => mountCount++,
                  label: mobilePageIdentity(location),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      rebuild(
        () => navigation.navigate(location(RaftRoute.channel, id: 'one')),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      rebuild(
        () => navigation.navigate(
          navigation.location.withQuery({'msg': 'focus'}),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(mountCount, 2);
      expect(
        find.text(mobilePageIdentity(navigation.location)),
        findsOneWidget,
      );
      final context = tester.element(find.byType(_LivePage));
      await Navigator.of(context).maybePop();
      await tester.pumpAndSettle();
      expect(backCount, 1);
      expect(navigation.location.route, RaftRoute.home);
      expect(mountCount, 2);
      expect(tester.takeException(), isNull);
      rebuild(() => navigation.navigate(location(RaftRoute.settings)));
      await tester.pump();
      final tabContext = tester.element(find.byType(_LivePage));
      expect(ModalRoute.of(tabContext)?.animation?.value, 1);
      await tester.pumpAndSettle();
      expect(mountCount, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Scroll storage survives page, tab and layout changes but retires with authority',
    (tester) async {
      final navigation = WorkspaceNavigation();
      navigation.bind('scroll-fixture', location(RaftRoute.home));
      late StateSetter rebuild;
      var authority = 'alice/server-one/owner';
      var mobile = true;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MobileWorkspacePages(
                key: ValueKey(authority),
                enabled: mobile,
                navigation: navigation,
                onBack: () => rebuild(() => backMobilePage(navigation)),
                pageBuilder: (_, location) => ListView.builder(
                  key: PageStorageKey(location.route.name),
                  primary: false,
                  itemExtent: 60,
                  itemCount: 80,
                  itemBuilder: (_, i) => Text('Row $i'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      ScrollPosition scroll() =>
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      for (final (i, route) in [
        RaftRoute.home,
        RaftRoute.members,
        RaftRoute.settings,
      ].indexed) {
        rebuild(() => navigation.navigate(location(route)));
        await tester.pumpAndSettle();
        expect(scroll().pixels, 0);
        final offset = 300.0 + i * 200;
        scroll().jumpTo(offset);
        await tester.pump();
        rebuild(
          () => navigation.navigate(
            location(RaftRoute.channel, id: 'channel-$i'),
          ),
        );
        await tester.pumpAndSettle();
        scroll().jumpTo(120);
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(scroll().pixels, offset);
      }
      rebuild(() => navigation.navigate(location(RaftRoute.home)));
      await tester.pumpAndSettle();
      expect(scroll().pixels, 300);
      rebuild(() => mobile = false);
      await tester.pumpAndSettle();
      expect(scroll().pixels, 300);
      rebuild(() => mobile = true);
      await tester.pumpAndSettle();
      expect(scroll().pixels, 300);
      rebuild(() => authority = 'alice/server-two/member');
      await tester.pumpAndSettle();
      expect(scroll().pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Task pages preserve their underlying destination including cold links',
    () {
      for (final route in [
        RaftRoute.home,
        RaftRoute.tasks,
        RaftRoute.members,
        RaftRoute.settings,
      ]) {
        for (final slot in ['task', 'legacyTask']) {
          final navigation = WorkspaceNavigation();
          final base = location(route);
          navigation.bind('isolated', base);
          final root = mobilePageEntries(navigation);
          for (var i = 0; i < 3; i++) {
            navigation.navigateTask(base.withQuery({slot: 'c:t$i'}));
            expect(mobilePageEntries(navigation), hasLength(root.length + 1));
            navigation.back();
            expect(mobilePageEntries(navigation), root);
          }
          navigation.bind('cold', base.withQuery({slot: 'c:t'}));
          expect(mobilePageEntries(navigation), hasLength(root.length + 1));
          expect(mobilePageEntries(navigation).first, root.first);
        }
      }
    },
  );

  testWidgets('Cold detail system pop paints its semantic root', (
    tester,
  ) async {
    final navigation = WorkspaceNavigation();
    navigation.bind('isolated', location(RaftRoute.channel, id: 'one'));
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return MobileWorkspacePages(
              navigation: navigation,
              onBack: () => rebuild(() => backMobilePage(navigation)),
              pageBuilder: (_, location) => _LivePage(
                onMount: () {},
                label: mobilePageIdentity(location),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(navigation.location.route, RaftRoute.home);
    expect(find.text(mobilePageIdentity(navigation.location)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Cold channel management pages and task alias retain distinct back destinations', () {
    for (final page in ['settings', 'members']) {
      final base = location(RaftRoute.channel, id: 'one');
      final navigation = WorkspaceNavigation();
      navigation.bind(
        'cold-$page',
        base.withQuery({'channelPage': '$page:one'}),
      );
      expect(mobilePageEntries(navigation), hasLength(3));
      expect(backMobilePage(navigation), base);
      expect(mobilePageEntries(navigation), hasLength(2));
      expect(backMobilePage(navigation).route, RaftRoute.home);
    }
    final thread = location(
      RaftRoute.channel,
      id: 'one',
      query: {'thread': 'one:message'},
    );
    final navigation = WorkspaceNavigation();
    navigation.bind('cold-task-alias', thread.withQuery({'task': '1'}));
    // Home -> conversation -> thread -> task: a cold thread still has its
    // conversation page under it.
    expect(mobilePageEntries(navigation), hasLength(4));
    expect(backMobilePage(navigation), thread);
    expect(navigation.location.task, isNull);
    expect(navigation.location.thread?.itemId, 'message');
    expect(mobilePageEntries(navigation), hasLength(3));
  });

  testWidgets(
    'Reentering a page during its exit animation owns a new route frame',
    (tester) async {
      final navigation = WorkspaceNavigation();
      navigation.bind('isolated', location(RaftRoute.home));
      late StateSetter rebuild;
      var mountCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MobileWorkspacePages(
                navigation: navigation,
                onBack: () => rebuild(() => backMobilePage(navigation)),
                pageBuilder: (_, location) => _LivePage(
                  onMount: () => mountCount++,
                  label: mobilePageIdentity(location),
                ),
              );
            },
          ),
        ),
      );
      for (var cycle = 0; cycle < 4; cycle++) {
        rebuild(
          () => navigation.navigate(location(RaftRoute.channel, id: 'one')),
        );
        await tester.pumpAndSettle();
        rebuild(() => backMobilePage(navigation));
        await tester.pump();
        rebuild(
          () => navigation.navigate(location(RaftRoute.channel, id: 'one')),
        );
        for (var frame = 0; frame < 24; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            find.text(mobilePageIdentity(navigation.location)),
            findsWidgets,
          );
          expect(mountCount, 1 + (cycle + 1) * 2);
          expect(tester.takeException(), isNull);
        }
        rebuild(() => backMobilePage(navigation));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('Standalone mobile routes share header and safe-area geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: raftPageAppBar(context, title: 'Detail'),
                    body: const SizedBox.expand(),
                  ),
                ),
              ),
              child: const Text('Open detail'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    // Web v1.21.23 Raft: pl-4 minus the 13px leading overhang,
    // then the 44px ghost action's center.
    expect(find.byType(RaftMobilePageHeader), findsNothing);
    expect(tester.getSize(find.byType(RaftPanelHeaderBar)).height, 56);
    expect(tester.getSize(find.byType(RaftPanelAction)), const Size(44, 44));
    expect(tester.getCenter(find.byType(RaftPanelAction)).dx, 3 + 22);
    await tester.tap(find.byType(RaftPanelAction));
    await tester.pumpAndSettle();
    expect(find.text('Open detail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LivePage extends StatefulWidget {
  const _LivePage({required this.onMount, required this.label});
  final VoidCallback onMount;
  final String label;
  @override
  State<_LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<_LivePage> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(widget.label));
}

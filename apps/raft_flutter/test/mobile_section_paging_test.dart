import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/features/agent_activity_pane.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show activityFixture;
import 'message_presentation_test.dart' show fixture;
import 'panel_revisit_cache_test.dart' show settle;
import 'source_feedback_store_test.dart' as feedback;

void main() {
  Future<void> mount(
    WidgetTester t,
    Widget child, {
    Size size = const Size(390, 844),
    TargetPlatform? platform,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(body: child),
      ),
    );
    await settle(t);
    await t.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester t, {bool back = false}) async {
    await t.drag(find.byType(PageView).first, Offset(back ? 310 : -310, 0));
    await settle(t);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Activity filter choices share owner; revisits retain offset and show cached window before network',
    (t) async {
      final (client, w) = activityFixture();
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      await mount(
        t,
        ResourceView(
          controller: w,
          section: 'activity',
          onMessage: (_, _) async {},
        ),
      );
      final dynamic owner = t.state(find.byType(ResourceView));
      final originalOwner = owner;
      expect(w.savedQueries, isEmpty);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await t.pumpAndSettle();
      final double offset = owner.listScroll.offset;
      expect(offset, greaterThan(100));
      // Web: the Filter menu picks the view (no horizontal paging).
      for (final view in [ActivityFilterChoice.unread, ActivityFilterChoice.mentions]) {
        owner.chooseActivityFilter(view);
        await settle(t);
        await t.pumpAndSettle();
        expect(owner.filter, view.name);
        expect(t.state(find.byType(ResourceView)), same(originalOwner));
      }
      expect(w.savedQueries, isEmpty);
      w.hold = Completer<void>();
      owner.chooseActivityFilter(ActivityFilterChoice.all);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(owner.filter, 'all');
      expect(owner.rows, isNotEmpty);
      expect(owner.listScroll.offset, closeTo(offset, 1));
      expect(find.byType(RaftActivityLoadingList), findsNothing);
      w.hold!.complete();
      w.hold = null;
      await t.pumpAndSettle();
      w.channels = [];
      w.server = RaftRecord({'id': 's2', 'role': 'guest'});
      client.selectServer('s2');
      w.notifyListeners();
      await t.pump();
      expect(owner.viewWindows, isEmpty);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Agent swipe mounts visited sections; hidden Activity defers refresh and permission loss removes tabs',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /agents/a1/activity-log'] = (_) => [];
      api.routes['GET /agents/a1/channels'] = (_) => {'channels': []};
      api.routes['GET /agents/a1/agent-dms'] = (_) => {'dms': []};
      final agent = {
        'id': 'a1',
        'name': 'bot',
        'status': 'active',
        'runtime': 'claude',
        'model': 'sonnet',
      };
      Widget panel(bool private) => AgentDetailPanel(
        key: const Key('agent'),
        controller: w,
        agent: agent,
        machines: const [],
        actions: const AgentDetailActions(),
        canViewPrivate: private,
      );
      await mount(t, panel(true));
      // The profile's embedded Skills section (Web AgentSkills) and Recent
      // activity card (Web AgentRecentActivity) load eagerly; no other tab
      // fetches before it is visited.
      expect(
        api.calls.where(
          (r) =>
              r.path.startsWith('/agents/a1/') &&
              r.path != '/agents/a1/skills' &&
              r.path != '/agents/a1/activity-summaries',
        ),
        isEmpty,
      );
      await swipe(t);
      expect(
        t
            .widget<RaftSectionPager<AgentDetailTab>>(
              find.byType(RaftSectionPager<AgentDetailTab>),
            )
            .value,
        AgentDetailTab.activity,
      );
      // The Activity tab opens on the Overview (Web 1.24, the
      // `activity_overview_web_v0` gate is retired); its raw log is one toggle
      // away and is the part that refreshes on its own.
      await t.tap(find.byKey(const ValueKey('activity-view-raw')));
      await settle(t);
      final reads = api.calls
          .where((r) => r.path == '/agents/a1/activity-log')
          .length;
      expect(reads, greaterThanOrEqualTo(1));
      await swipe(t);
      expect(
        t
            .widget<RaftSectionPager<AgentDetailTab>>(
              find.byType(RaftSectionPager<AgentDetailTab>),
            )
            .value,
        AgentDetailTab.chat,
      );
      final dynamic activity = t.state(
        find.byType(AgentActivityPane, skipOffstage: false),
      );
      // The pane's activity window defers its refresh while hidden.
      unawaited(activity.source.reload() as Future<void>);
      await t.pump(const Duration(milliseconds: 600));
      await settle(t);
      expect(
        api.calls.where((r) => r.path == '/agents/a1/activity-log'),
        hasLength(reads),
      );
      await swipe(t, back: true);
      expect(
        api.calls.where((r) => r.path == '/agents/a1/activity-log'),
        hasLength(reads + 1),
      );
      await mount(t, panel(false));
      expect(find.byType(AgentActivityPane), findsNothing);
      expect(
        t
            .widget<RaftSectionPager<AgentDetailTab>>(
              find.byType(RaftSectionPager<AgentDetailTab>),
            )
            .sections,
        [AgentDetailTab.profile],
      );
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Connected Apps swipes three locally projected sections without extra requests',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /integrations/clients'] = (_) => [
        {'id': 'app1', 'name': 'Registered App'},
      ];
      api.routes['GET /integrations/marketplace'] = (_) => [];
      api.routes['GET /integrations/overview'] = (_) => [];
      await mount(t, IntegrationsView(controller: w));
      final before = api.calls.length;
      await swipe(t);
      expect(
        t
            .widget<RaftSectionPager<RaftConnectedAppsTab>>(
              find.byType(RaftSectionPager<RaftConnectedAppsTab>),
            )
            .value,
        RaftConnectedAppsTab.installed,
      );
      await swipe(t);
      expect(
        t
            .widget<RaftSectionPager<RaftConnectedAppsTab>>(
              find.byType(RaftSectionPager<RaftConnectedAppsTab>),
            )
            .value,
        RaftConnectedAppsTab.myApps,
      );
      expect(find.text('Registered App'), findsOneWidget);
      expect(api.calls.length, before);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Feedback swipes locally filtered status sections without extra requests',
    (t) async {
      var reads = 0;
      final store = SourceFeedbackStore(
        authority: () => 'mobile-sections',
        get: (path, {query}) async {
          reads++;
          return feedback.page([
            feedback.ticket(feedback.first),
            feedback.ticket(feedback.second, status: 'closed'),
          ]);
        },
      );
      addTearDown(store.dispose);
      await store.loadList();
      await mount(t, SourceFeedbackProjectionView(store: store));
      await swipe(t);
      expect(store.filter, SourceFeedbackFilter.open);
      expect(
        find.byKey(const ValueKey('feedback-ticket-${feedback.second}')),
        findsNothing,
      );
      await swipe(t);
      expect(store.filter, SourceFeedbackFilter.resolved);
      expect(
        find.byKey(const ValueKey('feedback-ticket-${feedback.second}')),
        findsOneWidget,
      );
      expect(reads, 1);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );

  // Swiping between sections is a finger gesture: it follows the input, not
  // the width. An unfolded foldable is wide and touched; a narrow desktop
  // window is narrow and driven by a mouse.
  for (final (label, size, platform, swipes) in [
    (
      'foldable 856x944, touch',
      const Size(856, 944),
      TargetPlatform.android,
      true,
    ),
    (
      'landscape 944x856, touch',
      const Size(944, 856),
      TargetPlatform.android,
      true,
    ),
    (
      'phone 390x844, touch',
      const Size(390, 844),
      TargetPlatform.android,
      true,
    ),
    (
      'narrow 390x844, desktop',
      const Size(390, 844),
      TargetPlatform.linux,
      false,
    ),
    (
      'wide 1280x800, desktop',
      const Size(1280, 800),
      TargetPlatform.linux,
      false,
    ),
  ]) {
    testWidgets('Connected Apps sections swipe on $label: $swipes', (t) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /integrations/clients'] = (_) => [];
      api.routes['GET /integrations/marketplace'] = (_) => [];
      api.routes['GET /integrations/overview'] = (_) => [];
      await mount(
        t,
        IntegrationsView(controller: w),
        size: size,
        platform: platform,
      );
      RaftConnectedAppsTab tab() => t
          .widget<RaftSectionPager<RaftConnectedAppsTab>>(
            find.byType(RaftSectionPager<RaftConnectedAppsTab>),
          )
          .value;
      final first = tab();
      await t.drag(
        find.byType(PageView).first,
        Offset(-size.shortestSide * .8, 0),
      );
      await settle(t);
      await t.pumpAndSettle();
      expect(tab() != first, swipes);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    });
  }
}

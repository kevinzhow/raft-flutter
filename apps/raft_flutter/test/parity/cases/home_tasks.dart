// Official cases owned by this group (default selection):
//   components.auth.register.inputs
//   components.navigation.tabbar.states
//   components.home.titlebar.states
//   components.home.notification-center.states
//   components.home.search.results
//   components.home.search.channel-dropdown
//   components.home.saved.results
//   components.home.activity.results
//   components.tasks.panel.states
//   components.tasks.status-menu
//   components.home.create-channel.dialog
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [homeTaskUncovered] with an honest reason.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/mobile_workspace_navigation.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'home_tasks/fixture_workspace.dart';

final Map<String, ParityCase> homeTaskCases = {
  'components.auth.register.inputs': _register,
  'components.navigation.tabbar.states': _tabbar,
  'components.home.titlebar.states': _titlebar,
  'components.home.notification-center.states': _notificationCenter,
  'components.home.search.results': _searchResults,
  'components.home.search.channel-dropdown': _searchChannelDropdown,
  'components.home.saved.results': _saved,
  'components.home.activity.results': _activity,
  'components.tasks.panel.states': _tasksPanel,
  'components.tasks.status-menu': _statusMenu,
  'components.home.create-channel.dialog': _createChannel,
};

final Map<String, ParityUncovered> homeTaskUncovered = {};

// Owner-authorized repair of the empty reference fixture. Both hosts use the
// same explicit warning/info entries. The actual raft_ui button is tapped to
// open the actual center; this tests presentation, not authenticated delivery
// or SystemNotificationBell's store/permission/lifecycle adapter.
final ParityCase _notificationCenter = ParityCase(
  widgets: const [
    'raft_ui:RaftMobileNotificationButton',
    'raft_ui:RaftNotificationAttention',
    'raft_ui:RaftNotificationCenter',
  ],
  notes:
      'Repaired public component fixture: original 390x844 frame, '
      'production raft_ui controls, shared notification-center.json entries. '
      'Popup placement follows mobile trigger end/bottom plus 8px. '
      'Not a SystemNotificationBell authorization/API/delivery test.',
  build: (ctx) => _NotificationReferenceCase(ctx),
  interact: (t, ctx) async {
    expect(find.byType(RaftNotificationCenter), findsNothing);
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump();
    expect(find.byType(RaftNotificationCenter), findsOneWidget);
    final fixture = ctx.fixtures['notificationCenterFixture'] as Map;
    for (final entry in fixture['entries'] as List) {
      expect(find.text(entry['title'] as String), findsOneWidget);
      expect(find.text(entry['body'] as String), findsOneWidget);
    }
    expect(find.text('2 items'), findsOneWidget);
  },
);

class _NotificationReferenceCase extends StatefulWidget {
  const _NotificationReferenceCase(this.ctx);
  final ParityContext ctx;
  @override
  State<_NotificationReferenceCase> createState() =>
      _NotificationReferenceState();
}

class _NotificationReferenceState extends State<_NotificationReferenceCase> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final fixture = widget.ctx.fixtures['notificationCenterFixture'] as Map;
    final frame = fixture['frame'] as Map, trigger = fixture['trigger'] as Map;
    final entries = [
      for (final row in fixture['entries'] as List)
        RaftNotificationEntry(
          id: row['id'] as String,
          kind: RaftNotificationKind.values.byName(row['kind'] as String),
          title: row['title'] as String,
          body: row['body'] as String,
        ),
    ];
    return Scaffold(
      body: widget.ctx.target(
        SizedBox(
          width: (frame['width'] as num).toDouble(),
          height: (frame['height'] as num).toDouble(),
          child: ColoredBox(
            color: Colors.white,
            child: Stack(
              children: [
                Positioned(
                  top: (frame['topInset'] as num).toDouble(),
                  right: (frame['sideInset'] as num).toDouble(),
                  child: Stack(
                    children: [
                      RaftMobileNotificationButton(
                        open: open,
                        semanticLabel: 'Notification center, 2 notifications',
                        onPressed: () => setState(() => open = !open),
                      ),
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: IgnorePointer(
                          child: RaftNotificationAttention(count: 2),
                        ),
                      ),
                    ],
                  ),
                ),
                if (open)
                  Positioned(
                    right: (frame['sideInset'] as num).toDouble(),
                    top:
                        ((frame['topInset'] as num) +
                                (trigger['size'] as num) +
                                (trigger['popupGap'] as num))
                            .toDouble(),
                    child: RaftNotificationCenter(entries: entries),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth register — React's AuthVisualCaseView mounts RegisterPage in a plain
// block 390x844 `overflow: hidden` box (not a flex column), so AuthBrandShell
// gets an auto height and its content is top-aligned. Flutter's signed-out
// surface is AuthView (main.dart sessionHome) in register mode, reached by the
// "Create one" link; it is mounted with unbounded height inside the clipped
// 390x844 box to reproduce that host context.

final ParityCase _register = ParityCase(
  widgets: const [
    'raft_flutter:AuthView',
    'raft_ui:RaftAuthPage',
    'raft_ui:RaftBrandMark',
    'raft_ui:RaftButton',
    'raft_ui:RaftFieldSurface',
  ],
  notes:
      'AuthView mounted like main.dart (default origin http://localhost:13041, '
      'onOAuth set); /auth/providers answered with Google+GitHub like the React '
      'stub. Register mode reached through "No account? Create one", then the '
      'case props are typed into the email/password fields. Mounted with '
      'unbounded height in the clipped 390x844 box like the React block host.',
  build: (ctx) => SizedBox(
    width: 390,
    height: 844,
    child: ctx.target(
      ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: AuthView(
            origin: 'http://localhost:13041',
            onLogin: (_, _, _) async {},
            onRegister: (_, _, _, _) async {},
            onOAuth: (_, _, _, _) async {},
            anonymousClientFactory: ParityAuthClient.new,
          ),
        ),
      ),
    ),
  ),
  interact: (t, ctx) async {
    await t.pump(const Duration(milliseconds: 50));
    await t.tapOnText(find.textRange.ofSubstring('Create one'));
    await t.pump(const Duration(milliseconds: 100));
    await t.enterText(
      find.byKey(const Key('login-email')),
      ctx.props['registerEmail'] as String,
    );
    await t.enterText(
      find.byKey(const Key('login-password')),
      ctx.props['registerPassword'] as String,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump(const Duration(milliseconds: 100));
  },
);

// ---------------------------------------------------------------------------
// Bottom tab bar — React: <MobileTabBar/> in a 390px-wide box at its natural
// height. Flutter: RaftMobileNav with the items WorkspaceView.mobileNavigation
// builds for an owner (Home/Tasks/Members/Settings), Home selected.

final ParityCase _tabbar = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceMobileTabBar',
    'raft_ui:RaftMobileNav',
    'raft_ui:RaftMobileNavItem',
  ],
  notes:
      'WorkspaceMobileTabBar (the bar WorkspaceView.mobileNavigation mounts) '
      'for the fixture owner, so Members is present; Home selected, '
      'bottomInset 0 as the app passes.',
  build: (ctx) {
    final w = parityWorkspace(ctx);
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 390,
        child: ctx.target(
          WorkspaceMobileTabBar(
            controller: w,
            selectedId: 'chat',
            onSelected: (_) {},
          ),
        ),
      ),
    );
  },
);

// ---------------------------------------------------------------------------
final ParityCase _titlebar = ParityCase(
  widgets: const [
    'raft_ui:RaftServerSwitcher',
    'raft_ui:RaftMobileRootHeader',
    'raft_ui:RaftMobileServerSelector',
    'raft_ui:RaftMobileNotificationButton',
  ],
  notes:
      'Each manifest variant mounts the production phone switcher in its '
      'own clipped viewport, matching the React board. The last trigger opens '
      'the real popup.',
  build: (ctx) {
    final previous = RaftImageBytes.instance;
    RaftImageBytes.instance = RaftImageBytes(
      fetcher: (_) async => RaftFetchedImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAANUlEQVR4nGMUERRkwAaYGBgYhLfeF956H8KHs5mwKmdgYGDEZxRWwAKhXr97BxcSFRIiyw4ARRYKTkWPDY0AAAAASUVORK5CYII=',
        ),
      ),
    );
    ctx.onDispose(() => RaftImageBytes.instance = previous);
    return Builder(
      builder: (context) {
        final tokens = RaftTokens.of(context);
        return Material(
          color: tokens.canvas,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 342,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 6,
                  children: [
                    for (final variant in ctx.caseJson['variants'] as List)
                      _titlebarFrame(ctx, tokens, variant as Map),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  },
  interact: (tester, _) async {
    Future<void> decodeAvatars() async {
      final images = find.descendant(
        of: find.byType(RaftSizedImage),
        matching: find.byType(Image),
      );
      await tester.runAsync(() async {
        for (final element in images.evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pump();
    }

    await decodeAvatars();
    final frame = find.byKey(const ValueKey('titlebar-switcher-open'));
    final focusStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = focusStrategy);
    final switcher = find.descendant(
      of: frame,
      matching: find.byType(RaftServerSwitcher),
    );
    tester.widget<RaftServerSwitcher>(switcher).controller.open();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await decodeAvatars();
    expect(find.text('Raft Community'), findsOneWidget);
  },
);

Widget _titlebarFrame(ParityContext ctx, RaftTokens tokens, Map variant) {
  final props = variant['props'] as Map;
  final name = props['serverName'] as String;
  final other = props['otherServerName'] as String?;
  final open = props['switcherOpen'] == true;
  final avatar = props['serverAvatar'] == 'image'
      ? 'https://parity-fixture.invalid/home-titlebar-avatar.png'
      : null;
  final controller = RaftMenuController();
  ctx.onDispose(controller.dispose);
  return Column(
    key: ValueKey('titlebar-${variant['id']}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          (variant['name'] as String).toUpperCase(),
          style: RaftTypography.heading(
            tokens,
            size: 12,
            line: 16,
            weight: FontWeight.w500,
            color: tokens.muted,
          ),
        ),
      ),
      SizedBox(
        height: open ? 340 : 62,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minHeight: 844,
            maxHeight: 844,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(342, 844)),
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Material(
                    color: tokens.canvas,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: RaftServerSwitcher(
                        mobile: true,
                        controller: controller,
                        workspaceName: name,
                        workspaceAvatarUrl: avatar,
                        label: 'Switch Server',
                        attention: props['otherServerUnread'] == true,
                        headerActions: [
                          RaftMobileNotificationButton(
                            mobileHeader: true,
                            semanticLabel: 'Notification center',
                            onPressed: () {},
                          ),
                        ],
                        rows: [
                          RaftServerMenuRow(
                            id: 'visual-server',
                            name: name,
                            slug: 'visual',
                            current: true,
                            avatarUrl: avatar,
                            onSelected: () {},
                          ),
                          if (other != null)
                            RaftServerMenuRow(
                              id: 'visual-community',
                              name: other,
                              slug: 'raft-community',
                              onSelected: () {},
                            ),
                        ],
                        actions: [
                          RaftMenuEntry(
                            label: 'Join community',
                            glyph: RaftGlyph.plus,
                            onPressed: () {},
                          ),
                          RaftMenuEntry(
                            label: 'Switch or create server',
                            glyph: RaftGlyph.plus,
                            onPressed: () {},
                          ),
                          RaftServerMenuAction(
                            label: 'Invite human',
                            glyph: RaftGlyph.userPlus,
                            onPressed: () {},
                          ),
                        ],
                        onReorder: (_, _) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Resource pages (search/saved/activity/tasks) — React mounts the page
// components against stubbed /api routes; Flutter mounts ResourceView (the
// route WorkspaceView shows for those sections on mobile) against a
// controller answering the same routes from the shared fixture JSON.

Widget _resource(
  ParityContext ctx,
  String section, {
  double? width,
  double? height,
}) {
  final w = parityWorkspace(ctx, section: section);
  final now = parityNow(ctx);
  final view = Scaffold(
    body: ResourceView(
      controller: w,
      section: section,
      clock: () => now,
      onBack: () {},
      searchMemory: SearchMemoryStore(
        storage: ParityMemorySearchStorage(),
        clock: () => now,
      ),
      restoreSearchState: false,
      onMessage: (_, _) async {},
    ),
  );
  if (width == null || height == null) return view;
  return ctx.frame(
    width: width,
    height: height,
    padding: EdgeInsets.zero,
    child: view,
  );
}

Future<void> _typeSearch(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.enterText(find.byType(TextField).first, 'android');
  // React waits 850ms after the fill; ResourceView debounces 200ms.
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 550));
}

final ParityCase _searchResults = ParityCase(
  widgets: const [
    'raft_flutter:ResourceView(search)',
    'raft_flutter:ResourceSearchResults',
    'raft_flutter:TaskSelectionFilter',
    'raft_ui:RaftDropdownMenu',
  ],
  notes:
      'Query "android" typed like the React fill. React applies range=7d and '
      'sort=recent from the case URL params; Flutter has no URL state, so the '
      'same values are chosen through the date-range and sort dropdowns. The '
      'React sender/channel props match no React id and stay unselected, so '
      'they are not applied here either. Input focus is restored after choosing '
      'the filters: React seeds them via URL and then fills the focused input. '
      'Relative times use the fixture clock.',
  build: (ctx) => _resource(ctx, 'search'),
  interact: (t, ctx) async {
    await _typeSearch(t);
    await t.tap(find.text('Any time').last);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Last 7 days').last);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Relevant').last);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Recent').last);
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byType(TextField).first);
    await t.pump();
  },
);

final ParityCase _searchChannelDropdown = ParityCase(
  widgets: const [
    'raft_flutter:ResourceView(search)',
    'raft_flutter:TaskSelectionFilter',
    'raft_flutter:ResourceSearchResults',
  ],
  notes:
      'Query "android" typed, then the Channel filter (TaskSelectionFilter) '
      'opened, mirroring the React click on "Open channel filter".',
  build: (ctx) => _resource(ctx, 'search'),
  interact: (t, ctx) async {
    await _typeSearch(t);
    await t.tap(find.text('Channel').first);
    await t.pump(const Duration(milliseconds: 250));
  },
);

final ParityCase _saved = ParityCase(
  widgets: const [
    'raft_flutter:ResourceView(saved)',
    'raft_ui:RaftPageHeader',
    'raft_ui:RaftConversationCardRecipe',
  ],
  notes:
      'ResourceView(section saved) in the React 342x620 box; /channels/saved '
      'answers savedMessagesFixture.json. Relative times use the fixture clock.',
  build: (ctx) => _resource(ctx, 'saved', width: 342, height: 620),
  settle: const Duration(milliseconds: 850),
);

final ParityCase _activity = ParityCase(
  widgets: const [
    'raft_flutter:ResourceView(activity)',
    'raft_ui:RaftPageHeader',
    'raft_ui:RaftSegmentedControl',
  ],
  notes:
      'ResourceView(section activity) in the React 342x620 box; /channels/inbox '
      'answers activityResultsFixture.json. Relative times use the fixture clock. '
      'Desktop pointer density matches the real Chromium host (hover:none is '
      'false); the Android provider names the Widget capture, not a device.',
  build: (ctx) => RaftDensityScope(
    density: RaftDensity.desktop,
    child: _resource(ctx, 'activity', width: 342, height: 620),
  ),
  settle: const Duration(milliseconds: 850),
);

final ParityCase _tasksPanel = ParityCase(
  widgets: const [
    'raft_flutter:ResourceView(tasks)',
    'raft_ui:RaftPageHeader',
    'raft_ui:RaftTaskStatus',
    'raft_ui:RaftTaskCard',
  ],
  notes:
      'ResourceView(section tasks, list layout at 390px) with /tasks/server '
      'answering tasksFixture.json. The React "Show Done" click maps to the '
      'Done group disclosure (task-group-done).',
  build: (ctx) => _resource(ctx, 'tasks'),
  interact: (t, ctx) async {
    await t.pump(const Duration(milliseconds: 100));
    final done = find.byKey(const ValueKey('task-group-done'));
    final list = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await t.scrollUntilVisible(done, 200, scrollable: list);
    await t.tap(done);
    await t.pump(const Duration(milliseconds: 160));
    // Scrolling to the toggle moved the list; React captures from the top.
    t.state<ScrollableState>(list).position.jumpTo(0);
    await t.pump(const Duration(milliseconds: 50));
  },
);

// ---------------------------------------------------------------------------
// Task status menu — React renders InlineBadgeEditor (the status chip menu
// TaskCard opens) with `open`, status in_progress, all five status options and
// dropdownAlign="left", in a 342x260 box with 16px padding. Flutter mounts the
// same product control, RaftTaskStatusEditor (RaftInlineBadgeEditor), open.

final ParityCase _statusMenu = ParityCase(
  widgets: const [
    'raft_ui:RaftTaskStatusEditor',
    'raft_ui:RaftInlineBadgeEditor',
  ],
  notes:
      'RaftTaskStatusEditor for in_progress with raftTaskStatuses, opened via '
      'its controlled `open` like the React host; menu aligned left.',
  build: (ctx) => ctx.frame(
    width: 342,
    height: 260,
    // The host div is a block box under `<main class="font-display">`, so the
    // badge sits in a line box of the heading font at 16px / 1.5.
    child: Builder(
      builder: (context) => Align(
        alignment: Alignment.topLeft,
        child: RaftInlineLineBox(
          style: RaftTypography.heading(
            RaftTokens.of(context),
            weight: FontWeight.w400,
          ),
          child: RaftTaskStatusEditor(
            status: 'in_progress',
            options: raftTaskStatuses,
            onSelect: (_) {},
            open: true,
            alignRight: false,
          ),
        ),
      ),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Create channel — React (VisualTestingCases.tsx CreateChannelVisualCaseView):
// CreateChannelDialog over the 390x844 viewport, prefilled name/description/
// public + agent-cindy and visual-human-designer selected, stores primed by
// primeCreateChannelStores (agents Cindy + Visual QA; members owner +
// designer). Flutter mounts the product CreateChannelDialog with the same
// props over a workspace answering /agents and /servers/:id/members with that
// roster.

class _CreateChannelWorkspace extends ParityFixtureWorkspace {
  _CreateChannelWorkspace(super.client, super.ctx);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    final fx = ctx.fixtureData;
    if (path == '/agents') {
      final cindy = Map<String, dynamic>.from(fx['agents']['cindy'] as Map);
      return [
        {
          'id': cindy['id'],
          'name': cindy['name'],
          'displayName': cindy['displayName'],
          'avatarUrl': cindy['avatar'],
          'description': cindy['description'],
          'deletedAt': null,
        },
        // primeCreateChannelStores' inline second agent.
        {
          'id': 'agent-qa',
          'name': 'Visual-QA',
          'displayName': 'Visual QA',
          'avatarUrl': 'pixel:eye',
          'description': 'Checks screenshots before release.',
          'deletedAt': null,
        },
      ];
    }
    return super.query(path, query: query);
  }
}

final ParityCase _createChannel = ParityCase(
  widgets: const ['raft_flutter:CreateChannelDialog', 'raft_ui:RaftDialogCard'],
  notes:
      'Product CreateChannelDialog opened through the adaptive form route with the React prefill props '
      '(name, description, public, agent-cindy + visual-human-designer).',
  build: (_) => const Scaffold(
    key: ValueKey('create-channel-case-host'),
    backgroundColor: Colors.white,
  ),
  interact: (tester, ctx) async {
    final base = parityWorkspace(ctx);
    final w = _CreateChannelWorkspace(base.client, ctx)
      ..server = base.server
      ..channels = base.channels
      ..section = base.section;
    ctx.onDispose(w.dispose);
    unawaited(
      showRaftForm<void>(
        tester.element(find.byKey(const ValueKey('create-channel-case-host'))),
        builder: (_) => CreateChannelDialog(
          controller: w,
          prefilledName: ctx.props['name'] as String,
          prefilledDescription: ctx.props['description'] as String,
          prefilledVisibility: 'public',
          prefilledAgentIds: const ['agent-cindy'],
          prefilledHumanIds: const ['visual-human-designer'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CreateChannelDialog), findsOneWidget);
  },
);

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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'home_tasks/fixture_workspace.dart';

final Map<String, ParityCase> homeTaskCases = {
  'components.auth.register.inputs': _register,
  'components.navigation.tabbar.states': _tabbar,
  'components.home.titlebar.states': _titlebar,
  'components.home.search.results': _searchResults,
  'components.home.search.channel-dropdown': _searchChannelDropdown,
  'components.home.saved.results': _saved,
  'components.home.activity.results': _activity,
  'components.tasks.panel.states': _tasksPanel,
  'components.tasks.status-menu': _statusMenu,
  'components.home.create-channel.dialog': _createChannel,
};

final Map<String, ParityUncovered> homeTaskUncovered = {
  'components.home.notification-center.states': ParityUncovered(
    ParityGap.invalidBaseline,
    'The React render host branch (VisualTestingCases.tsx kind '
    '"notification-center") mounts no component: the baseline is an empty '
    '390x844 white box. An empty-vs-empty match would be a hollow 100%, so it '
    'is not counted. Flutter has SystemNotificationBell/RaftNotificationCenter '
    'ready to map once the React fixture renders something.',
  ),
};

// ---------------------------------------------------------------------------
// Auth register — React mounts RegisterPage in a 390x844 box and fills the
// email/password inputs. Flutter's signed-out surface is AuthView (main.dart
// sessionHome); register is its 'register' mode, reached by the
// "Create account" switch.

final ParityCase _register = ParityCase(
  widgets: const [
    'raft_flutter:AuthView',
    'raft_ui:RaftPanel',
    'raft_ui:RaftButton',
  ],
  notes:
      'AuthView mounted like main.dart (default origin http://localhost:13041, '
      'onOAuth set); /auth/providers answered with Google+GitHub like the React '
      'stub. Register mode reached by tapping "Create account", then the case '
      'props are typed into the email/password fields.',
  build: (ctx) => AuthView(
    origin: 'http://localhost:13041',
    onLogin: (_, _, _) async {},
    onRegister: (_, _, _, _) async {},
    onOAuth: (_, _, _, _) async {},
    anonymousClientFactory: ParityAuthClient.new,
  ),
  interact: (t, ctx) async {
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Create account').last);
    await t.pump(const Duration(milliseconds: 100));
    await t.enterText(
      find.byKey(const Key('login-email')),
      ctx.props['registerEmail'] as String,
    );
    await t.enterText(
      find.byKey(const Key('login-password')),
      ctx.props['registerPassword'] as String,
    );
    await t.pump(const Duration(milliseconds: 100));
  },
);

// ---------------------------------------------------------------------------
// Bottom tab bar — React: <MobileTabBar/> in a 390px-wide box at its natural
// height. Flutter: RaftMobileNav with the items WorkspaceView.mobileNavigation
// builds for an owner (Home/Tasks/Members/Settings), Home selected.

final ParityCase _tabbar = ParityCase(
  widgets: const ['raft_ui:RaftMobileNav', 'raft_ui:RaftMobileNavItem'],
  notes:
      'Items/ids/glyphs copied from WorkspaceView.mobileNavigation (owner role, '
      'so Members is present); bottomInset 0 as the app passes.',
  build: (ctx) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 390,
      child: ctx.target(
        Builder(
          builder: (context) => RaftMobileNav(
            selectedId: 'chat',
            bottomInset: 0,
            onSelected: (_) {},
            items: [
              RaftMobileNavItem(
                id: 'chat',
                label: raftText(context, 'Home'),
                glyph: RaftGlyph.home,
              ),
              RaftMobileNavItem(
                id: 'tasks',
                label: raftText(context, 'Tasks'),
                glyph: RaftGlyph.checkSquare,
              ),
              RaftMobileNavItem(
                id: 'members',
                label: raftText(context, 'Members'),
                glyph: RaftGlyph.users,
              ),
              RaftMobileNavItem(
                id: 'settings',
                label: raftText(context, 'Settings'),
                glyph: RaftGlyph.settings,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Home titlebar — React: 390x844 white case box; inside, a 342x110 box with
// paddingTop 48 holding a 342x62 overflow-hidden slot with <Sidebar
// mobileInline/> (server "Raft Design"). Flutter: the mobile-home header of
// WorkspaceView.sidebar(mobileHome: true): RaftMobileRootHeader with
// RaftMobileServerSelector + SystemNotificationBell over the sidebar body.

final ParityCase _titlebar = ParityCase(
  widgets: const [
    'raft_ui:RaftMobileRootHeader',
    'raft_ui:RaftMobileServerSelector',
    'raft_flutter:SystemNotificationBell',
    'raft_ui:RaftMobileNotificationButton',
  ],
  notes:
      'Composition copied from WorkspaceView.sidebar(mobileHome: true) (private '
      'method); server name "Raft Design" as primeNavigationVisualStores seeds. '
      'The app passes no server-unread attention to the selector, so none is shown.',
  build: (ctx) {
    final w = parityWorkspace(ctx, serverName: 'Raft Design');
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: 390,
        height: 844,
        color: Colors.white,
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.only(top: 48),
        child: SizedBox(
          width: 342,
          height: 62,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Builder(
                builder: (context) {
                  final recipe = RaftSidebarRecipe(
                    RaftTokens.of(context),
                    viewportWidth: MediaQuery.sizeOf(context).width,
                    viewportHeight: MediaQuery.sizeOf(context).height,
                    variant: RaftSidebarVariant.mountedProduct,
                  );
                  return ColoredBox(
                    color: recipe.bodyBackground,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RaftMobileRootHeader(
                          leading: RaftMobileServerSelector(
                            label: w.server?.name ?? 'Workspace',
                            onPressed: () {},
                          ),
                          actions: [
                            SystemNotificationBell(
                              controller: w,
                              onBilling: () {},
                            ),
                          ],
                        ),
                        // Sidebar body below the header (clipped by the
                        // React 62px slot, as in the fixture).
                        const SizedBox(height: 120),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  },
);

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
      'they are not applied here either. Relative times use the fixture clock.',
  build: (ctx) => _resource(ctx, 'search'),
  interact: (t, ctx) async {
    await _typeSearch(t);
    await t.tap(find.text('Any Time').last);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Last 7 Days').last);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Relevant').last);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Recent').last);
    await t.pump(const Duration(milliseconds: 600));
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
      'answers activityResultsFixture.json. Relative times use the fixture clock.',
  build: (ctx) => _resource(ctx, 'activity', width: 342, height: 620),
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
          of: find.byType(ListView),
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
// Create channel — React: CreateChannelDialog over the 390x844 viewport,
// prefilled name/description/public + one agent and one human selected.
// Flutter: WorkspaceView.createChannel's RaftFormDialog (name, description,
// visibility); the values are typed into its fields.

final ParityCase _createChannel = ParityCase(
  widgets: const ['raft_ui:RaftFormDialog', 'raft_ui:RaftFormField'],
  notes:
      'Fields copied from WorkspaceView.createChannel (private method). The '
      'Flutter create-channel dialog has no members picker, so the React '
      'prefilled agent/human selection has no Flutter counterpart.',
  build: (ctx) => const Scaffold(body: _CreateChannelLauncher()),
  interact: (t, ctx) async {
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(
      find.byKey(const ValueKey('field-name')),
      ctx.props['name'] as String,
    );
    await t.enterText(
      find.byKey(const ValueKey('field-description')),
      ctx.props['description'] as String,
    );
    await t.pump(const Duration(milliseconds: 100));
  },
);

class _CreateChannelLauncher extends StatefulWidget {
  const _CreateChannelLauncher();
  @override
  State<_CreateChannelLauncher> createState() => _CreateChannelLauncherState();
}

class _CreateChannelLauncherState extends State<_CreateChannelLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      String tr(String s) => raftText(context, s);
      showDialog<bool>(
        context: context,
        builder: (_) => RaftFormDialog(
          title: tr('Create channel'),
          submitLabel: tr('Create'),
          fields: [
            RaftFormField('name', 'Channel name', required: true),
            RaftFormField('description', 'Description', multiline: true),
            RaftFormField(
              'visibility',
              'Visibility',
              initial: 'public',
              choices: {
                'public': 'Public channel',
                'private': 'Private channel',
              },
            ),
          ],
          onSubmit: (_) async {},
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

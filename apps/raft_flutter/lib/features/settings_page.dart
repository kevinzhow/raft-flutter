import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/navigation_registry.dart';
import 'pushed_server_page.dart';
import 'settings_anchor.dart';
import 'settings_search.dart';
import 'settings_search_match.dart';
import 'settings_sub_pages.dart';

/// SettingsPanel / Sidebar(mobileInline) SettingsSidebarList composition.
/// Account transport and platform notification ownership are supplied by the
/// caller, never by this UI shell.
class RaftSettingsDestination {
  const RaftSettingsDestination(
    this.id,
    this.label,
    this.glyph,
    this.builder, {
    this.group = 'Personal',
    this.scroll = true,
    this.title,
    this.onOpen,
    this.mobileOnly = false,
    this.attention = false,
    this.attentionDanger = false,
    this.attached = true,
    this.ownHeader = false,
    this.contentColor,
    this.headerIcon = false,
    this.semanticLabel,
    this.trailingText,
    this.external = false,
  }) : assert(builder != null || onOpen != null);

  /// A row that leaves the Settings page (external link or another route),
  /// like the Sidebar.tsx Documentation / Computers / Release Notes rows.
  const RaftSettingsDestination.action(
    this.id,
    this.label,
    this.glyph, {
    required VoidCallback this.onOpen,
    this.group = 'Personal',
    this.mobileOnly = false,
    this.attention = false,
    this.external = false,
  }) : builder = null,
       semanticLabel = null,
       trailingText = null,
       attentionDanger = false,
       scroll = false,
       title = null,
       attached = true,
       ownHeader = false,
       headerIcon = false,
       contentColor = null;
  final String id, label, group;

  /// The row's accessible name when the label alone repeats another row's.
  final String? semanticLabel;

  /// Hint text before the row's end ("Muted").
  final String? trailingText;

  /// The row leaves Raft: it ends in the ArrowUpRight mark.
  final bool external;

  /// Listed only in the mobile Settings root (Sidebar.tsx adds Computers to
  /// the Settings sub-nav on mobile only; desktop has its own rail mode).
  final bool mobileOnly;

  /// Trailing attention dot (Feedback's unread replies).
  final bool attention;

  /// Paint [attention] in the `--danger` red ("update available").
  final bool attentionDanger;

  /// Rendered inside SettingsPanel's `Panel edge="attached"` (false for the
  /// /release-notes route, which is a plain column).
  final bool attached;

  /// The panel header sits inside the content surface (AboutFeedbackPanel).
  final bool ownHeader;

  /// The page passes an `icon` to its PanelHeader (RaftBench); Settings tabs
  /// do not, so their head carries no tile in the Raft look.
  final bool headerIcon;

  /// Content surface override (RaftSettingsPanelFrame.contentColor).
  final Color Function(RaftTokens)? contentColor;

  /// Panel title (SETTINGS_TAB_TITLE_ID) when it differs from the nav label.
  final String? title;
  final RaftGlyph glyph;
  final WidgetBuilder? builder;
  final VoidCallback? onOpen;
  final bool scroll;
}

class RaftSettingsPage extends StatefulWidget {
  const RaftSettingsPage({
    super.key,
    required this.destinations,
    this.initialTab = 'account',
    this.onBack,
    this.mobileRoot = false,
    this.mobileResetRevision = 0,
    this.onMobileDetailChanged,
    this.onMobileLocationChanged,
    this.subPage,
    this.subPageBody,
    this.subPageQuery = const {},
    this.onSubPageOpen,
    this.onSubPageBack,
    this.search,
    this.anchor,
    this.anchorRevision = 0,
    this.anchorFromKeyboard = false,
  }) : assert(subPage == null || subPageBody != null);
  final List<RaftSettingsDestination> destinations;
  final String initialTab;

  /// The level-2 page open over [initialTab] (`/settings/account/delete`):
  /// its title, a desktop breadcrumb back to the tab, and Back to the tab on
  /// a phone.
  final SettingsSubPage? subPage;

  /// The body of [subPage].
  final WidgetBuilder? subPageBody;
  final Map<String, String> subPageQuery;

  /// Opens a sub-page from a row inside a tab ([openSettingsSubPage]).
  final void Function(String id, Map<String, String> query)? onSubPageOpen;

  /// A phone's Back out of the sub-page, to its parent tab (the host owns the
  /// location); without it the page falls back to the list.
  final VoidCallback? onSubPageBack;

  /// Settings search; null leaves the list without a field.
  final SettingsSearchHost? search;

  /// `/settings/<tab>#<anchor>`: the section the tab opens scrolled to
  /// (useScrollToSettingsSection). [anchorRevision] makes opening the same
  /// anchor again a new jump; [anchorFromKeyboard] moves focus to it.
  final String? anchor;
  final int anchorRevision;
  final bool anchorFromKeyboard;
  final VoidCallback? onBack;
  final bool mobileRoot;
  final int mobileResetRevision;
  final ValueChanged<bool>? onMobileDetailChanged;
  final ValueChanged<String?>? onMobileLocationChanged;
  @override
  State<RaftSettingsPage> createState() => _RaftSettingsPageState();
}

class _RaftSettingsPageState extends State<RaftSettingsPage> {
  late String selected = widget.initialTab;
  late bool mobileNavigation = widget.mobileRoot;

  /// Search settings' query lives as long as this surface does: it is kept
  /// while the person stays in Settings of one server (a phone's Back returns
  /// to the results) and goes with the surface on leaving it or switching
  /// server (settingsSearchStore.ts). Not in the URL.
  final searchController = TextEditingController();
  final searchFocus = FocusNode(debugLabel: 'settings-search');
  final resultsKey = GlobalKey<SettingsSearchResultsState>();
  final anchors = SettingsAnchorRegistry();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_findShortcut);
    if (widget.anchor != null) {
      anchors.jump(widget.anchor!, fromKeyboard: widget.anchorFromKeyboard);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_findShortcut);
    searchController.dispose();
    searchFocus.dispose();
    anchors.dispose();
    super.dispose();
  }

  /// Cmd/Ctrl+F anywhere in Settings focuses and selects Search settings
  /// (registry `search-settings`); pressed in the field it is left to the
  /// platform, and a field that can't take focus (the phone's page showing a
  /// tab) leaves the key alone.
  bool _findShortcut(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyF ||
        widget.search == null ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        !primaryShortcutModifierDown(keyboard)) {
      return false;
    }
    if (searchFocus.hasFocus ||
        searchFocus.context == null ||
        !searchFocus.canRequestFocus) {
      return false;
    }
    searchFocus.requestFocus();
    // The field restores its caret as it takes focus; select once it has.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !searchFocus.hasFocus) return;
      searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: searchController.text.length,
      );
    });
    return true;
  }

  @override
  void didUpdateWidget(covariant RaftSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A link to a section (or the same one again, a new revision) is a new
    // jump; the tab it opens is already selected below.
    if (widget.anchor != null &&
        (widget.anchor != oldWidget.anchor ||
            widget.anchorRevision != oldWidget.anchorRevision ||
            widget.initialTab != oldWidget.initialTab)) {
      anchors.jump(widget.anchor!, fromKeyboard: widget.anchorFromKeyboard);
    }
    if (oldWidget.initialTab != widget.initialTab) selected = widget.initialTab;
    if (widget.onMobileLocationChanged != null ||
        oldWidget.mobileRoot != widget.mobileRoot) {
      mobileNavigation = widget.mobileRoot;
    }
    if (oldWidget.mobileResetRevision != widget.mobileResetRevision &&
        widget.mobileRoot) {
      mobileNavigation = true;
    }
  }

  void showNavigation() {
    if (!mounted) return;
    if (widget.onMobileLocationChanged == null) {
      setState(() => mobileNavigation = true);
    }
    widget.onMobileDetailChanged?.call(false);
    widget.onMobileLocationChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final mobile =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    // Phone-only rows configure or stand in for the bottom bar; the left rail
    // (like the desktop layout) has neither, so they are hidden with it.
    final bottomBar = mobile && !RaftAdaptiveWorkspace.phoneRailOf(context);
    final available = [
      for (final d in widget.destinations)
        if (bottomBar || !d.mobileOnly) d,
    ];
    final pages = available.where((d) => d.builder != null).toList();
    if (pages.isEmpty) return const SizedBox.shrink();
    final subPage = widget.subPage;
    final tabId = subPage?.parentTab ?? selected;
    final shown = pages.where((d) => d.id == tabId).firstOrNull;
    // A tab the registry knows but this role, flag or layout hides resolves
    // to the first page like Web's denied tab (SettingsPanel). A tab nobody
    // registered is a broken link: loud in debug, the same fallback in release.
    if (shown == null && !NavigationRegistry.knowsSettingsTab(tabId)) {
      NavigationRegistry.reportFallback('settings tab', tabId);
    }
    final active = shown ?? pages.first;
    void open(RaftSettingsDestination destination) {
      if (destination.onOpen != null) {
        destination.onOpen!();
        return;
      }
      if (!mounted) return;
      if (!mobile || widget.onMobileLocationChanged == null) {
        setState(() {
          selected = destination.id;
          mobileNavigation = false;
        });
      }
      if (mobile) widget.onMobileDetailChanged?.call(true);
      widget.onMobileLocationChanged?.call(destination.id);
    }

    final groups = [
      for (final group in available.map((d) => d.group).toSet())
        RaftSettingsNavGroup(group, [
          for (final d in available.where((d) => d.group == group))
            RaftSettingsNavEntry(
              id: d.id,
              label: d.label,
              glyph: d.glyph,
              onTap: () => open(d),
              attention: d.attention,
              attentionDanger: d.attentionDanger,
              semanticLabel: d.semanticLabel,
              trailingText: d.trailingText,
              external: d.external,
            ),
        ]),
    ];
    // Sidebar.tsx mobile root highlights nothing until a sub-page is open.
    // Web SettingsSearch lists the pages the list shows this person, in its
    // order, under the title each page's header carries.
    final searchPages = [
      for (final d in available)
        if (d.builder != null)
          SettingsSearchPage(
            d.id,
            d.title ?? (d.label == 'Providers' ? 'AI Providers' : d.label),
          ),
    ];
    void openResult(SearchableSetting setting, {required bool fromKeyboard}) {
      final host = widget.search;
      if (host == null || !mounted) return;
      // Without a location the page owns its tab and runs the jump itself;
      // hosted, the location carries both and the new props start the jump.
      if (widget.onMobileLocationChanged == null) {
        setState(() {
          selected = setting.page;
          mobileNavigation = false;
        });
        anchors.jump(setting.id, fromKeyboard: fromKeyboard);
      }
      if (mobile) widget.onMobileDetailChanged?.call(true);
      host.open(setting.page, setting.id, fromKeyboard: fromKeyboard);
    }

    Widget list(String? activeId) => _SettingsNavigationList(
      storageKey: mobile ? 'settings-mobile-list' : 'settings-sidebar',
      padding: raftScrollPadding(context, RaftSettingsSidebarList.inset(t)),
      groups: groups,
      activeId: activeId,
      search: widget.search,
      pages: searchPages,
      controller: searchController,
      focusNode: searchFocus,
      resultsKey: resultsKey,
      isOpen: (setting) =>
          activeId != null &&
          activeId == setting.page &&
          widget.anchor == setting.id,
      onOpen: openResult,
    );
    Widget navigation() => mobile
        ? ColoredBox(
            // Sidebar mobileInline: `theme-brutal:bg-white`.
            color: RaftSettingsText(t).panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RaftMobileRootHeader(
                  title: 'Settings',
                  onBack: widget.onBack,
                  backKey: pushedServerPageBackKey,
                ),
                Expanded(child: list(null)),
              ],
            ),
          )
        : RaftMountedSidebarFrame(
            trailingEdge: true,
            header: RaftChatSidebarHeading(
              label: raftText(context, 'Settings'),
            ),
            body: list(active.id),
          );
    // Account > Delete account: the tab name leads back on a desktop width;
    // a phone shows the plain title and its Back returns to the tab.
    Widget header() => RaftSettingsPanelHeader(
      title: subPage?.title ?? active.title ?? active.label,
      glyph: active.glyph,
      iconTile: active.headerIcon,
      mobile: mobile,
      backKey: const Key('mobile-settings-back'),
      backTooltip: 'Back',
      onMobileBack: subPage == null
          ? showNavigation
          : widget.onSubPageBack ?? showNavigation,
      titleSlot: subPage == null
          ? null
          : RaftSettingsBreadcrumb(
              key: const Key('settings-breadcrumb'),
              tabKey: const Key('settings-breadcrumb-tab'),
              tabLabel: active.title ?? active.label,
              title: subPage.title,
              onTab: () => open(active),
            ),
    );
    // A sub-page is its own page under the tab: its own body, scroll position
    // and key, the tab's row staying selected in the list.
    final pageId = subPage?.id ?? active.id;
    final pageBuilder = subPage == null ? active.builder! : widget.subPageBody!;
    Widget page() => subPage != null || active.scroll
        ? ListView(
            key: PageStorageKey('settings-page-$pageId'),
            primary: false,
            padding: raftScrollPadding(
              context,
              RaftSettingsPanelFrame.contentInset,
            ),
            children: [
              KeyedSubtree(key: ValueKey(pageId), child: pageBuilder(context)),
            ],
          )
        : KeyedSubtree(key: ValueKey(pageId), child: pageBuilder(context));
    // ownHeader: the header sits inside the content surface, outside the
    // Panel's header slot (AboutFeedbackPanel), so no frame divider.
    Widget content() => RaftSettingsPanelFrame(
      attached: active.attached,
      contentColor: active.contentColor?.call(t),
      header: active.ownHeader ? null : header(),
      child: active.ownHeader
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header(),
                Expanded(child: page()),
              ],
            )
          : page(),
    );
    Widget surface() {
      if (mobile) return mobileNavigation ? navigation() : content();
      return Row(
        children: [
          SizedBox(
            key: const ValueKey('settings-navigation'),
            width: RaftSettingsLayoutRecipe.navigationWidth,
            child: navigation(),
          ),
          Expanded(
            child: KeyedSubtree(
              key: const ValueKey('settings-panel'),
              child: content(),
            ),
          ),
        ],
      );
    }

    final open0 = widget.onSubPageOpen;
    return SettingsAnchorScope(
      registry: anchors,
      child: open0 == null
          ? surface()
          : SettingsSubPageScope(
              open: open0,
              query: widget.subPageQuery,
              child: surface(),
            ),
    );
  }
}

/// The list of pages with Search settings pinned above it. While the query has
/// words the results take the list's place, in the same scroll view; only this
/// part listens to the query, so typing never rebuilds the open tab.
class _SettingsNavigationList extends StatelessWidget {
  const _SettingsNavigationList({
    required this.storageKey,
    required this.padding,
    required this.groups,
    required this.activeId,
    required this.search,
    required this.pages,
    required this.controller,
    required this.focusNode,
    required this.resultsKey,
    required this.isOpen,
    required this.onOpen,
  });
  final String storageKey;
  final EdgeInsets padding;
  final List<RaftSettingsNavGroup> groups;
  final String? activeId;
  final SettingsSearchHost? search;
  final List<SettingsSearchPage> pages;
  final TextEditingController controller;
  final FocusNode focusNode;
  final GlobalKey<SettingsSearchResultsState> resultsKey;
  final bool Function(SearchableSetting setting) isOpen;
  final void Function(SearchableSetting setting, {required bool fromKeyboard})
  onOpen;

  @override
  Widget build(BuildContext context) {
    final host = search;
    // The pages' own list; the field and results are Settings search's.
    Widget scroll(Widget child) => ListView(
      key: PageStorageKey(storageKey),
      primary: false,
      padding: padding,
      children: [child],
    );
    final pageList = RaftSettingsSidebarList(
      groups: groups,
      activeId: activeId,
    );
    if (host == null) return scroll(pageList);
    List<SettingsSearchResult> found() => searchSettings(
      searchableSettings(context, host, pages),
      controller.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSearchField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (_) {},
          onEnter: () {
            final first = found().firstOrNull;
            if (first != null) onOpen(first.setting, fromKeyboard: true);
          },
          onDown: () => resultsKey.currentState?.focusFirst() ?? false,
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => scroll(
              !settingsSearching(controller.text)
                  ? pageList
                  : SettingsSearchResults(
                      key: resultsKey,
                      results: found(),
                      query: controller.text,
                      field: focusNode,
                      isOpen: isOpen,
                      onOpen: onOpen,
                      onSearchEverywhere: () =>
                          host.searchEverywhere(controller.text.trim()),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/navigation_registry.dart';

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
  }) : builder = null,
       attentionDanger = false,
       scroll = false,
       title = null,
       attached = true,
       ownHeader = false,
       headerIcon = false,
       contentColor = null;
  final String id, label, group;

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
  });
  final List<RaftSettingsDestination> destinations;
  final String initialTab;
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
  @override
  void didUpdateWidget(covariant RaftSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final shown = pages.where((d) => d.id == selected).firstOrNull;
    // A tab the registry knows but this role, flag or layout hides resolves
    // to the first page like Web's denied tab (SettingsPanel). A tab nobody
    // registered is a broken link: loud in debug, the same fallback in release.
    if (shown == null && !NavigationRegistry.knowsSettingsTab(selected)) {
      NavigationRegistry.reportFallback('settings tab', selected);
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
            ),
        ]),
    ];
    // Sidebar.tsx mobile root highlights nothing until a sub-page is open.
    Widget list(String? activeId) => ListView(
      key: PageStorageKey(mobile ? 'settings-mobile-list' : 'settings-sidebar'),
      primary: false,
      padding: raftScrollPadding(context, RaftSettingsSidebarList.inset(t)),
      children: [RaftSettingsSidebarList(groups: groups, activeId: activeId)],
    );
    Widget navigation() => mobile
        ? ColoredBox(
            // Sidebar mobileInline: `theme-brutal:bg-white`.
            color: RaftSettingsText(t).panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RaftMobileRootHeader(title: 'Settings'),
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
    Widget header() => RaftSettingsPanelHeader(
      title: active.title ?? active.label,
      glyph: active.glyph,
      iconTile: active.headerIcon,
      mobile: mobile,
      backKey: const Key('mobile-settings-back'),
      backTooltip: 'Back',
      onMobileBack: showNavigation,
    );
    Widget page() => active.scroll
        ? ListView(
            key: PageStorageKey('settings-page-${active.id}'),
            primary: false,
            padding: raftScrollPadding(
              context,
              RaftSettingsPanelFrame.contentInset,
            ),
            children: [
              KeyedSubtree(
                key: ValueKey(active.id),
                child: active.builder!(context),
              ),
            ],
          )
        : KeyedSubtree(
            key: ValueKey(active.id),
            child: active.builder!(context),
          );
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
}

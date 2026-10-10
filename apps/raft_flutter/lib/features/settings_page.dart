import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

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
  }) : assert(builder != null || onOpen != null);

  /// A row that leaves the Settings page (external link or another route),
  /// like the Sidebar.tsx Documentation / Computers / Release Notes rows.
  const RaftSettingsDestination.action(
    this.id,
    this.label,
    this.glyph, {
    required VoidCallback this.onOpen,
    this.group = 'Personal',
  }) : builder = null,
       scroll = false,
       title = null;
  final String id, label, group;

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
    setState(() => mobileNavigation = true);
    widget.onMobileDetailChanged?.call(false);
    widget.onMobileLocationChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final available = widget.destinations;
    final pages = available.where((d) => d.builder != null).toList();
    if (pages.isEmpty) return const SizedBox.shrink();
    final active =
        pages.where((d) => d.id == selected).firstOrNull ?? pages.first;
    final mobile =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    void open(RaftSettingsDestination destination) {
      if (destination.onOpen != null) {
        destination.onOpen!();
        return;
      }
      if (!mounted) return;
      setState(() {
        selected = destination.id;
        mobileNavigation = false;
      });
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
            ),
        ]),
    ];
    // Sidebar.tsx mobile root highlights nothing until a sub-page is open.
    Widget list(String? activeId) => ListView(
      primary: false,
      padding: RaftSettingsLayoutRecipe.navigationInset,
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
            header: RaftChatSidebarHeading(
              label: raftText(context, 'Settings'),
            ),
            body: list(active.id),
          );
    Widget content() => RaftSettingsPanelFrame(
      header: RaftSettingsPanelHeader(
        title: active.title ?? active.label,
        glyph: active.glyph,
        mobile: mobile,
        backKey: const Key('mobile-settings-back'),
        backTooltip: 'Back',
        onMobileBack: showNavigation,
      ),
      child: active.scroll
          ? ListView(
              key: ValueKey('settings-page-${active.id}'),
              primary: false,
              padding: RaftSettingsPanelFrame.contentInset,
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
            ),
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

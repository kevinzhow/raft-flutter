import 'dart:async';

import 'package:flutter/material.dart';

import '../data/phone_stack.dart';
import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_navigation.dart';
import 'route_transition_gate.dart';

/// Focus/search edits stay on a page; task and channel-management identities
/// own platform pages while retaining the workspace's existing data owners.
String mobilePageIdentity(RaftLocation location) {
  return [
    location.uri.path,
    location.query('open') ?? '',
    location.query('thread') ?? '',
    location.query('profile') ?? '',
    location.query('task') ?? '',
    location.query('legacyTask') ?? '',
    location.query('channelPage') ?? '',
  ].join('|');
}

/// The pages a phone shows for the accepted location. Derived from the
/// location (root tab -> list -> conversation -> thread -> profile / task /
/// channel page), never from raw history: wide panel open/close and sidebar
/// switches leave history entries that are not phone pages.
List<RaftLocation> mobilePageStack(WorkspaceNavigation navigation) {
  final tabs = navigation.mobileTabs;
  final location = navigation.location;
  return phoneStackFor(
    location,
    tabs,
    source: phoneReturnSource(
      navigation.entries,
      navigation.index,
      location,
      tabs,
      floor: navigation.phoneFloor,
    ),
    sibling: channelPageSibling(navigation.entries, navigation.index, location),
    direct: openedDirectly(navigation.entries, navigation.index, location),
  );
}

/// Back pops one level of [mobilePageStack]. History only locates the entry to
/// return to (so Forward and revisions stay coherent); a level that history
/// never saw (cold link, translated layout) is reached by replacing.
RaftLocation backMobilePage(WorkspaceNavigation navigation) {
  final stack = mobilePageStack(navigation);
  if (stack.length < 2) return _backThroughHistory(navigation);
  final target = stack[stack.length - 2];
  final identity = mobilePageIdentity(target);
  for (var at = navigation.index - 1; at >= 0; at--) {
    final entry = navigation.entries[at];
    if (mobilePageIdentity(entry) != identity) continue;
    while (navigation.index > at) {
      final before = navigation.index;
      navigation.back();
      if (navigation.index == before) break;
    }
    return navigation.location;
  }
  if (target.task != null ||
      target.legacyTask != null ||
      navigation.location.task != null ||
      navigation.location.legacyTask != null) {
    navigation.navigateTask(target, kind: RaftNavigationKind.replace);
  } else {
    navigation.navigate(target, kind: RaftNavigationKind.replace);
  }
  return navigation.location;
}

/// Root pages have no phone parent: keep stepping the observed history until
/// the visual page changes, then fall back to the semantic tab root.
RaftLocation _backThroughHistory(WorkspaceNavigation navigation) {
  final identity = mobilePageIdentity(navigation.location);
  final limit = navigation.entries.length + 1;
  for (var step = 0; step < limit; step++) {
    final before = navigation.location.uri;
    final index = navigation.index;
    final next = navigation.back();
    if (mobilePageIdentity(next) != identity ||
        next.uri == before && navigation.index == index) {
      return next;
    }
  }
  return navigation.location;
}

/// Project the location into a single-column stack of page identities.
List<String> mobilePageEntries(WorkspaceNavigation navigation) => [
  for (final location in mobilePageStack(navigation))
    '${navigation.mobileRootTabOf(location) != null ? 'root' : 'page'}::'
        '${mobilePageIdentity(location)}',
];

/// Each platform route owns its live page widgets. History stores locations,
/// never rasterized frames; the workspace remains the data/navigation owner.
class MobileWorkspacePages extends StatefulWidget {
  const MobileWorkspacePages({
    super.key,
    required this.navigation,
    required this.onBack,
    required this.pageBuilder,
    this.storageBucket,
    this.enabled = true,
  });
  final WorkspaceNavigation navigation;
  final VoidCallback onBack;
  final Widget Function(BuildContext context, RaftLocation location)
  pageBuilder;
  final PageStorageBucket? storageBucket;
  final bool enabled;

  @override
  State<MobileWorkspacePages> createState() => _MobileWorkspacePagesState();
}

class _MobileWorkspacePagesState extends State<MobileWorkspacePages> {
  final navigator = GlobalKey<NavigatorState>();
  final transitions = RouteTransitionGate();
  late final transitionObserver = RouteTransitionObserver(transitions);
  final pageStorage = PageStorageBucket();
  int nextInstance = 0;
  late List<_MobilePageEntry> entries = reconcile(const []);
  bool rootChanged = false;

  /// Set while the first frames of a workspace that mounted behind another
  /// route settle (the window was narrowed behind the expanded composer
  /// editor). A Navigator takes the focus when it mounts; excluding its
  /// subtree makes that a no-op so the route in front keeps its focus, and
  /// the exclusion lifts once the mount-time requests are over.
  bool mountedCovered = false, mountChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mountChecked) return;
    mountChecked = true;
    if (!(ModalRoute.isCurrentOf(context) ?? true)) {
      mountedCovered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: raft_lints/avoid_unreviewed_idle_work -- Runs once per mount, only when the workspace mounted behind another route; it lifts the exclusion and schedules nothing else.
        scheduleMicrotask(() {
          if (mounted) setState(() => mountedCovered = false);
        });
      });
    }
  }

  List<_MobilePageEntry> reconcile(List<_MobilePageEntry> previous) {
    final stack = mobilePageStack(widget.navigation);
    final root = widget.navigation.mobileRootTabOf(stack.first) != null;
    return [
      for (final (index, page) in stack.indexed)
        () {
          final identity =
              '${index == 0 && root ? 'root' : 'page'}::'
              '${mobilePageIdentity(page)}';
          return _MobilePageEntry(
            identity,
            previous
                    .where((entry) => entry.identity == identity)
                    .firstOrNull
                    ?.id ??
                '${nextInstance++}::$identity',
            index == stack.length - 1 &&
                    mobilePageIdentity(widget.navigation.location) ==
                        mobilePageIdentity(page)
                ? widget.navigation.location
                : page,
          );
        }(),
    ];
  }

  @override
  void didUpdateWidget(MobileWorkspacePages oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = reconcile(entries);
    rootChanged =
        entries.first.identity != next.first.identity &&
        !entries.any(
          (entry) => next.any((item) => item.identity == entry.identity),
        );
    entries = next;
  }

  Widget page(BuildContext context, RaftLocation location) => PageStorage(
    bucket: widget.storageBucket ?? pageStorage,
    child: widget.pageBuilder(context, location),
  );

  @override
  void dispose() {
    transitions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return page(context, widget.navigation.location);
    final parentCurrent = ModalRoute.isCurrentOf(context) ?? true;
    return NavigatorPopHandler<void>(
      onPopWithResult: (_) => navigator.currentState?.maybePop(),
      child: ExcludeFocus(
        excluding: mountedCovered,
        child: Navigator(
          key: navigator,
          observers: [transitionObserver],
          // Pages pushed while a route covers the whole workspace must not take
          // the focus from that route.
          requestFocus: parentCurrent,
          transitionDelegate: _MobileTransitionDelegate(
            skip: rootChanged || MediaQuery.disableAnimationsOf(context),
          ),
          pages: [
            for (final entry in entries)
              MaterialPage<void>(
                key: ValueKey(entry.id),
                canPop: parentCurrent,
                allowSnapshotting: false,
                child: Builder(
                  builder: (context) => page(context, entry.location),
                ),
              ),
          ],
          onDidRemovePage: (page) {
            if (page.key == ValueKey(entries.last.id)) widget.onBack();
          },
        ),
      ),
    );
  }
}

class _MobilePageEntry {
  const _MobilePageEntry(this.identity, this.id, this.location);
  final String identity, id;
  final RaftLocation location;
}

/// Tab roots and reduced-motion navigation switch immediately. Hierarchical
/// pushes/pops use Flutter's default platform transition delegate.
class _MobileTransitionDelegate extends DefaultTransitionDelegate<void> {
  const _MobileTransitionDelegate({required this.skip});
  final bool skip;
  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord>
    locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>>
    pageRouteToPagelessRoutes,
  }) {
    if (!skip) {
      return super.resolve(
        newPageRouteHistory: newPageRouteHistory,
        locationToExitingPageRoute: locationToExitingPageRoute,
        pageRouteToPagelessRoutes: pageRouteToPagelessRoutes,
      );
    }
    for (final entry in newPageRouteHistory) {
      if (entry.isWaitingForEnteringDecision) {
        entry.markForAdd();
      }
    }
    for (final entry in locationToExitingPageRoute.values) {
      if (entry.isWaitingForExitingDecision) entry.markForComplete();
      for (final pageless
          in pageRouteToPagelessRoutes[entry] ?? <RouteTransitionRecord>[]) {
        if (pageless.isWaitingForExitingDecision) pageless.markForComplete();
      }
    }
    return [...newPageRouteHistory, ...locationToExitingPageRoute.values];
  }
}

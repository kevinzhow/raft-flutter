import 'raft_location.dart';
import 'workspace_navigation.dart';

/// Layout adapters for the one canonical [RaftLocation]. Wide (columns) and
/// phone (a page stack) are two projections of the same location; crossing the
/// 768dp breakpoint translates the few identities that only mean something in
/// one of them. Mirrors Web MainLayout, which re-derives the layout from the
/// pathname + matchMedia(768) instead of keeping a second navigation state.
const phonePageLimit = 8;

/// Activity / Search keep a list in the master column and the picked
/// conversation in `open=`. A phone has no master/detail: the picked
/// conversation is a page above the list.
bool hasContentSlot(RaftLocation location) =>
    {RaftRoute.search, RaftRoute.activity}.contains(location.route) &&
    location.content != null;

/// The list page under a master/detail content slot (the Back destination).
/// Closing a task shown in a list's detail slot closes the slot with it.
Map<String, String?> taskSlotRemoval(RaftLocation location) => {
  if (location.query('taskMsg') != null) 'taskMsg': null,
  if (location.query('taskConversation') != null) 'taskConversation': null,
  if (location.content?.kind == RaftContentKind.task) ...{
    'open': null,
    'msg': null,
  },
};

RaftLocation contentList(RaftLocation location) => _tidy(
  location.withQuery({
    'open': null,
    'msg': null,
    'thread': null,
    if (location.content?.kind == RaftContentKind.task) ...{
      'task': null,
      'taskMsg': null,
      'taskConversation': null,
    },
  }),
);

/// `withQuery` leaves a bare `?` once the last parameter is gone.
RaftLocation _tidy(RaftLocation location) =>
    location.uri.hasQuery && location.uri.query.isEmpty
    ? RaftLocation.parse(location.toString().replaceFirst('?', ''))
    : location;

/// The phone page for a master/detail content slot; any other location is
/// returned unchanged. A slot that cannot be resolved falls back to the list.
RaftLocation locationForPhone(RaftLocation location) {
  final content = location.content;
  if (!hasContentSlot(location) || content == null) return location;
  final keep = {
    for (final key in const [
      'profile',
      'agentTab',
      'task',
      'taskMsg',
      'taskConversation',
      'legacyTask',
      'channelPageAdd',
    ])
      if (location.query(key) != null) key: location.query(key)!,
  };
  RaftLocation at(RaftRoute route, String id, [Map<String, String>? extra]) =>
      RaftLocation.at(
        serverSlug: location.serverSlug,
        route: route,
        entityId: id,
        query: {...keep, ...?extra},
      );
  final msg = location.messageId;
  switch (content.kind) {
    case RaftContentKind.channel:
      return at(RaftRoute.channel, content.id, {'msg': ?msg});
    case RaftContentKind.dm:
      return at(RaftRoute.dm, content.id, {'msg': ?msg});
    case RaftContentKind.thread:
      final thread = location.thread;
      if (thread == null) return contentList(location);
      return at(RaftRoute.channel, thread.channelId, {
        'thread': thread.toString(),
        'msg': ?msg,
      });
    case RaftContentKind.agent:
      return at(RaftRoute.agent, content.id);
    case RaftContentKind.human:
      return at(RaftRoute.human, content.id);
    case RaftContentKind.machine:
      return at(RaftRoute.computer, content.id);
    case RaftContentKind.task:
      // Web TaskContentSlot on a phone: the task's page over the list.
      return _tidy(location.withQuery({'open': null, 'msg': null}));
  }
}

/// `channelPage=` is a phone-only page identity; wide opens the same
/// management surface as a dialog and keeps no such URL state.
bool hasPhoneOnlyIdentity(RaftLocation location) =>
    location.channelPage != null;

RaftLocation locationForWide(RaftLocation location) =>
    hasPhoneOnlyIdentity(location)
    ? _tidy(location.withQuery({'channelPage': null, 'channelPageAdd': null}))
    : location;

/// One overlay level removed, topmost first: channel page, task, legacy task,
/// profile, thread. Each slot owns its own query keys.
RaftLocation? _withoutTopOverlay(RaftLocation location) {
  Map<String, String?>? removal;
  if (location.channelPage != null) {
    removal = {'channelPage': null, 'channelPageAdd': null};
  } else if (location.task != null) {
    removal = {'task': null, ...taskSlotRemoval(location)};
  } else if (location.legacyTask != null) {
    removal = {'legacyTask': null};
  } else if (location.profile != null) {
    removal = {
      'profile': null,
      if (location.route != RaftRoute.agent) 'agentTab': null,
    };
  } else if (location.thread != null && !hasContentSlot(location)) {
    removal = {
      'thread': null,
      if (location.threadFocusedMessageId != null) 'msg': null,
    };
  }
  return removal == null ? null : _tidy(location.withQuery(removal));
}

/// The phone page stack of [location] (a content slot opened on the phone,
/// e.g. a Search thread hit, is its own page above its list): root tab, then the list the user came
/// from ([source], the only history-derived page), the conversation / detail,
/// its thread and finally profile / task / channel page. Pure: it never reads
/// history, so wide panel open/close can not leak into it. Back pops exactly
/// one level of this chain.
List<RaftLocation> phoneStackFor(
  RaftLocation location,
  Set<String> tabs, {
  RaftLocation? source,
  RaftLocation? sibling,
  bool direct = false,
}) {
  final list = hasContentSlot(location) ? contentList(location) : null;
  final levels = <RaftLocation>[location];
  for (var up = _withoutTopOverlay(location); up != null;) {
    levels.add(up);
    up = _withoutTopOverlay(up);
  }
  final base = levels.last;
  final stack = <RaftLocation>[];
  final isRoot = WorkspaceNavigation.rootTabOf(base, tabs) != null;
  final candidate = isRoot || (list ?? source)?.uri == base.uri
      ? null
      : list ?? source;
  // A page the reader came back from (a Settings page above the Settings
  // list, an agent above Members) is not under the one now shown.
  final from = candidate != null && _standsOn(candidate, base)
      ? null
      : candidate;
  if (isRoot) {
    stack.add(base);
  } else if (from != null) {
    // A root the reader came from is the only page under; any other page
    // brings the pages it stands on.
    if (WorkspaceNavigation.rootTabOf(from, tabs) == null) {
      stack.addAll(_pagesUnder(from, tabs));
    }
    stack.add(from);
  } else {
    stack.addAll(_pagesUnder(base, tabs));
  }
  // A thread opened straight from a list (Activity thread row) has no
  // conversation page under it: Back returns to the list.
  final skipBase = direct && from != null && !isRoot && levels.length > 1;
  stack.addAll(levels.reversed.skip(isRoot || skipBase ? 1 : 0));
  // Channel settings -> members are two pages of the same slot: the one the
  // reader came through stays under it.
  if (sibling != null &&
      stack.length >= 2 &&
      sibling.channelPage != null &&
      location.channelPage != null &&
      sibling.uri != location.uri &&
      _withoutTopOverlay(sibling)?.uri == _withoutTopOverlay(location)?.uri) {
    stack.insert(stack.length - 1, sibling);
  }
  return stack.length > phonePageLimit
      ? stack.sublist(stack.length - phonePageLimit)
      : stack;
}

/// Whether [page] is [base] or one of the pages above it.
bool _standsOn(RaftLocation page, RaftLocation base) {
  for (
    RaftLocation? up = page;
    up != null;
    up = WorkspaceNavigation.parentPageOf(up)
  ) {
    if (up.uri == base.uri) return true;
  }
  return false;
}

/// The pages a non-root [page] stands on, root first: its parent pages (agent
/// -> Members, settings page -> Settings), then the root tab. A pushed page
/// (Members, Computers, Settings) and any other page with no parent stand on
/// Home.
List<RaftLocation> _pagesUnder(RaftLocation page, Set<String> tabs) {
  final parent = WorkspaceNavigation.parentPageOf(page);
  if (parent != null) {
    return [
      if (WorkspaceNavigation.rootTabOf(parent, tabs) == null)
        ..._pagesUnder(parent, tabs),
      parent,
    ];
  }
  return [WorkspaceNavigation.tabHomeOf(page, tabs)];
}

/// The non-hierarchical Back destination: the page observed immediately before
/// the current one (Activity -> channel, Search -> result, channel -> channel
/// from a link). Only entries made while the phone layout was live count
/// (index >= [floor]): the columns' history (sidebar switches, panel
/// open/close) is not a phone journey. Lists and tab roots stay eligible from
/// any age, as they are the pages a wide master/detail slot was opened from.
RaftLocation? phoneReturnSource(
  List<RaftLocation> entries,
  int index,
  RaftLocation current,
  Set<String> tabs, {
  int floor = 0,
}) {
  String pageOf(RaftLocation value) {
    final page = _baseOf(locationForPhone(value));
    return page.uri.replace(query: '', fragment: '').toString();
  }

  final here = pageOf(current);
  for (var at = index - 1; at >= 0 && at < entries.length; at--) {
    final entry = entries[at];
    if (entry.serverSlug != current.serverSlug) return null;
    final list = hasContentSlot(entry) ? contentList(entry) : entry;
    if (pageOf(list) == here) continue;
    final base = _baseOf(locationForPhone(list));
    if (at >= floor ||
        WorkspaceNavigation.rootTabOf(base, tabs) != null ||
        const {
          RaftRoute.search,
          RaftRoute.activity,
          RaftRoute.saved,
          RaftRoute.drafts,
          RaftRoute.computers,
        }.contains(base.route)) {
      return base;
    }
    return null;
  }
  return null;
}

RaftLocation _baseOf(RaftLocation location) {
  var base = location;
  for (var up = _withoutTopOverlay(base); up != null;) {
    base = up;
    up = _withoutTopOverlay(up);
  }
  return base;
}

/// The channel page the reader opened the current one from (settings ->
/// members), the previous history entry when it differs only in that slot.
RaftLocation? channelPageSibling(
  List<RaftLocation> entries,
  int index,
  RaftLocation current,
) {
  if (current.channelPage == null || index < 1 || index > entries.length) {
    return null;
  }
  final previous = entries[index - 1];
  return previous.channelPage != null &&
          previous.channelPage!.kind != current.channelPage!.kind &&
          _withoutTopOverlay(previous)?.uri == _withoutTopOverlay(current)?.uri
      ? previous
      : null;
}

/// True when the overlay page on [current] (thread, profile, ...) was opened
/// together with its conversation from another page, without the bare
/// conversation ever being shown in between.
bool openedDirectly(
  List<RaftLocation> entries,
  int index,
  RaftLocation current,
) {
  if (!current.hasOverlay || index < 1 || index > entries.length) return false;
  final here = _pageKey(current);
  for (var at = index - 1; at >= 0; at--) {
    final entry = entries[at];
    if (_pageKey(entry) != here) return true;
    if (!entry.hasOverlay && !hasContentSlot(entry)) return false;
  }
  return false;
}

String _pageKey(RaftLocation value) {
  final page = _baseOf(locationForPhone(value));
  return page.uri.replace(query: '', fragment: '').toString();
}

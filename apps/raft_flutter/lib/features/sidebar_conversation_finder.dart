import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import 'conversation_finder_model.dart';
import 'quick_switcher_host.dart';
import 'search_ranking.dart';
import 'sender_avatar_projection.dart';

/// Web SidebarConversationFinder: the "Find a conversation…" jump box pinned
/// above the chat sidebar's list. A name-based fuzzy jump over channels, DMs,
/// agents and people the workspace already holds; no message-content search
/// and no keyboard shortcut by design. Arrow keys move, Enter opens, Escape
/// closes; the field stays focused while the result list is up.
///
/// Web shows it in the Electron desktop shell only (the browser withdrew it,
/// 2026-09-11), so it shows on the desktop platforms (pointer input) and
/// nowhere else. [SidebarFinderLayer] wraps the sidebar and provides the
/// result list over it; [SidebarConversationFinderBox] is the field, placed
/// where the sidebar's scroll surface begins. Without the layer (or on touch)
/// the box takes no room.
class SidebarFinderLayer extends StatefulWidget {
  const SidebarFinderLayer({
    super.key,
    required this.host,
    required this.child,
  });
  final QuickSwitcherHost host;
  final Widget child;

  /// Visual-parity captures compare with the browser, which has no box.
  @visibleForTesting
  static bool hiddenForParity = false;

  @override
  State<SidebarFinderLayer> createState() => _SidebarFinderLayerState();
}

class _SidebarFinderLayerState extends State<SidebarFinderLayer> {
  final controller = TextEditingController();
  final focus = FocusNode();
  final link = LayerLink();
  final model = _FinderState();
  bool opened = false;
  int active = 0;
  bool authorsRequested = false;

  // Ranking is rebuilt when its inputs change, not on every notification.
  Object? _channels, _dms, _agents, _members;
  String? _agentTag, _user;
  List<SearchRankEntry<ConversationMatch>> _entries = const [];
  String _rankedQuery = '';
  List<ConversationMatch> _ranked = const [];

  @override
  void initState() {
    super.initState();
    controller.addListener(queryChanged);
    focus.addListener(focusChanged);
  }

  @override
  void dispose() {
    controller.removeListener(queryChanged);
    focus.removeListener(focusChanged);
    controller.dispose();
    focus.dispose();
    model.dispose();
    super.dispose();
  }

  String get query => controller.text.trim();

  void queryChanged() {
    // The highlight returns to the first row whenever the query changes.
    if (_rankedQuery != query) active = 0;
    model.changed();
  }

  void focusChanged() {
    if (focus.hasFocus && !opened) {
      opened = true;
      if (!authorsRequested) {
        authorsRequested = true;
        widget.host.w.services.entityDirectory.ensureAuthors();
      }
      model.changed();
    }
  }

  void close() {
    opened = false;
    active = 0;
    controller.clear();
    focus.unfocus();
    model.changed();
  }

  List<ConversationMatch> results(String agentTag) {
    final w = widget.host.w;
    final directory = w.services.entityDirectory;
    final agents = directory.authorAgents, members = directory.authorMembers;
    final user = w.client.user?.id;
    if (!identical(_channels, w.channels) ||
        !identical(_dms, w.dms) ||
        !identical(_agents, agents) ||
        !identical(_members, members) ||
        _agentTag != agentTag ||
        _user != user) {
      _channels = w.channels;
      _dms = w.dms;
      _agents = agents;
      _members = members;
      _agentTag = agentTag;
      _user = user;
      _entries = finderSearchEntries(
        buildFinderResults(
          channels: w.channels,
          dms: w.dms,
          agents: agents,
          members: members,
          currentUserId: user,
          agentTag: agentTag,
        ),
      );
      _rankedQuery = '\u0000';
    }
    if (_rankedQuery != query) {
      _rankedQuery = query;
      _ranked = rankFinderResults(query, _entries);
    }
    return _ranked;
  }

  void select(ConversationMatch? result) {
    if (result == null) return;
    close();
    widget.host.openFinderResult(result);
  }

  KeyEventResult key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // A composing IME owns the arrows, Enter and Escape of its candidate list.
    if (controller.value.composing.isValid &&
        !controller.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      close();
      return KeyEventResult.handled;
    }
    final shown = opened && query.isNotEmpty;
    final count = _ranked.length;
    if (!shown || count == 0) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      active = (active + 1) % count;
      model.changed();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      active = (active - 1 + count) % count;
      model.changed();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      select(_ranked[math.min(active, count - 1)]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        !SidebarFinderLayer.hiddenForParity &&
        !kIsWeb &&
        !RaftInteraction.of(context).touch;
    if (!enabled) return widget.child;
    return _FinderScope(
      layer: this,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          // The sidebar keeps the constraints it always had.
          fit: StackFit.passthrough,
          children: [
            widget.child,
            ListenableBuilder(
              listenable: model,
              builder: (context, _) {
                if (!opened || query.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  left: 0,
                  top: 0,
                  child: CompositedTransformFollower(
                    link: link,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.bottomLeft,
                    followerAnchor: Alignment.topLeft,
                    offset: RaftConversationFinderMetrics.panelOffset,
                    child: SizedBox(
                      width: constraints.constrainWidth(
                        constraints.maxWidth -
                            RaftConversationFinderMetrics.panelInset,
                      ),
                      child: TextFieldTapRegion(
                        child: _FinderResults(layer: this),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FinderState extends ChangeNotifier {
  void changed() => notifyListeners();
}

class _FinderScope extends InheritedWidget {
  const _FinderScope({required this.layer, required super.child});
  final _SidebarFinderLayerState layer;
  @override
  bool updateShouldNotify(_FinderScope old) => !identical(layer, old.layer);
}

/// The field. Placed in the sidebar column above the scroll surface.
class SidebarConversationFinderBox extends StatelessWidget {
  const SidebarConversationFinderBox({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FinderScope>();
    if (scope == null) return const SizedBox.shrink();
    final layer = scope.layer;
    return CompositedTransformTarget(
      link: layer.link,
      child: RaftConversationFinderField(
        key: const Key('sidebar-conversation-finder'),
        inputKey: const Key('sidebar-conversation-finder-input'),
        controller: layer.controller,
        focusNode: layer.focus,
        hint: raftText(context, 'Find a conversation…'),
        onKeyEvent: layer.key,
        // Pointer presses outside the field and its result list close the
        // list, like Web's document pointerdown.
        onTapOutside: () {
          if (layer.opened) layer.close();
        },
      ),
    );
  }
}

class _FinderResults extends StatelessWidget {
  const _FinderResults({required this.layer});
  final _SidebarFinderLayerState layer;

  @override
  Widget build(BuildContext context) {
    final tag = raftText(context, 'Agent');
    return ListenableBuilder(
      listenable: layer.widget.host.w,
      builder: (context, _) {
        final ranked = layer.results(tag);
        final active = ranked.isEmpty
            ? 0
            : math.min(layer.active, ranked.length - 1);
        return KeyedSubtree(
          key: const Key('sidebar-conversation-finder-results'),
          child: RaftConversationFinderPanel(
            emptyLabel: ranked.isEmpty ? raftText(context, 'No matches') : null,
            children: [
              for (final (i, result) in ranked.indexed)
                RaftConversationFinderRow(
                  key: ValueKey('sidebar-conversation-finder-${result.key}'),
                  leading: _leading(context, result),
                  label: result.label,
                  sublabel: result.sublabel,
                  active: i == active,
                  onPressed: () => layer.select(result),
                  onHover: () {
                    if (layer.active != i) {
                      layer.active = i;
                      layer.model.changed();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _leading(BuildContext context, ConversationMatch result) {
    if (result.kind == 'channel') {
      // A channel is a place, not a "who": a bare # (private: a lock).
      return RaftIcon(
        result.private ? RaftGlyph.lock : RaftGlyph.hash,
        size: RaftConversationFinderMetrics.glyphSize,
        color: RaftTokens.of(context).colors['foreground-hint'],
      );
    }
    final w = layer.widget.host.w;
    final directory = w.services.entityDirectory;
    final agent = result.isAgent;
    final peer = result.kind == 'dm'
        ? w.dms.where((c) => c.id == result.id).firstOrNull?.string('peerId') ??
              ''
        : result.id;
    final projection = projectSenderAvatar(
      origin: w.client.origin,
      senderId: peer,
      senderType: agent ? 'agent' : 'user',
      agents: directory.authorAgents,
      members: directory.authorMembers,
      currentUser: w.client.user?.json,
      carriedAvatarUrl: result.avatar['avatarUrl'] is String
          ? result.avatar['avatarUrl'] as String
          : null,
      requestSize: 32,
    );
    return RaftAvatar(
      name: result.label,
      kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
      mountedContext: RaftMountedAvatarContext.sidebarList,
      content: RaftAvatarContent(
        name: result.label,
        kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
        uploadedUrl: projection.uploadedUrl,
        gravatarUrl: projection.gravatarUrl,
        pixelKey: agent ? projection.pixelKey ?? 'robot' : null,
        fallback: RaftMountedAvatarFallback(
          avatarContext: RaftMountedAvatarContext.sidebarList,
          identity: agent
              ? RaftMountedAvatarIdentity.agent
              : RaftMountedAvatarIdentity.human,
          gravatar: projection.gravatarUrl != null,
          initials: result.label,
        ),
      ),
    );
  }
}

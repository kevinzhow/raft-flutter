import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_grid_sessions.dart';
import 'conversation_panel.dart';
import 'chat_view.dart';
import 'server_setup_gate.dart';
import 'thread_actions.dart';

/// First actual editor-group consumer: channels/DMs each have an independent
/// accepted window and draft, with selected/retained tabs and draggable splits.
/// Non-conversation routes retain the existing admitted root page in a tab.
class WorkspaceGridView extends StatefulWidget {
  const WorkspaceGridView({
    super.key,
    required this.controller,
    required this.route,
    required this.routeBody,
    required this.active,
    this.onDraftsChanged,
    this.onRouteSelected,
  });
  final WorkspaceController controller;
  final String route;
  final Widget routeBody;
  final bool active;
  final VoidCallback? onDraftsChanged;
  final ValueChanged<String>? onRouteSelected;
  @override
  State<WorkspaceGridView> createState() => WorkspaceGridViewState();
}

class WorkspaceGridViewState extends State<WorkspaceGridView> {
  late WorkspaceGridSessions sessions;
  List<List<String>> groups = [[]];
  final selected = <String, String>{};
  List<double> weights = [1];
  int nextGroup = 1;
  List<String> groupIds = ['workspace-primary'];
  String? route;
  String? panelScope;
  String activeGroup = 'workspace-primary';
  final routeBodies = <String, Widget>{};
  String? get activeChannelId {
    final id = selected[activeGroup];
    return id == null || id.startsWith('route:') ? null : id;
  }

  @override
  void initState() {
    super.initState();
    sessions = WorkspaceGridSessions(widget.controller)..addListener(changed);
    panelScope = sessions.scope;
    final id = widget.controller.channel?.id;
    if (id != null) openChannel(id);
    followRoute();
  }

  void changed() {
    if (!mounted) return;
    setState(() {
      if (panelScope != sessions.scope) {
        panelScope = sessions.scope;
        groups = [[]];
        groupIds = ['workspace-primary'];
        weights = [1];
        selected.clear();
        routeBodies.clear();
        route = null;
        activeGroup = groupIds.first;
      }
      for (final group in groups) {
        group.removeWhere(
          (id) =>
              !id.startsWith('route:') && !sessions.controllers.containsKey(id),
        );
      }
      for (var i = 0; i < groups.length; i++) {
        if (!groups[i].contains(selected[groupIds[i]])) {
          selected[groupIds[i]] = groups[i].firstOrNull ?? '';
        }
      }
    });
  }

  @override
  void didUpdateWidget(WorkspaceGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      sessions.removeListener(changed);
      sessions.dispose();
      sessions = WorkspaceGridSessions(widget.controller)..addListener(changed);
      groups = [[]];
      groupIds = ['workspace-primary'];
      weights = [1];
      selected.clear();
      route = null;
      routeBodies.clear();
      panelScope = sessions.scope;
      activeGroup = groupIds.first;
    }
    followRoute();
    if (oldWidget.active && !widget.active) flushDrafts();
    if (!oldWidget.active && widget.active) sessions.restoreParentDrafts();
  }

  void followRoute() {
    if (route == widget.route && !['chat', 'home'].contains(widget.route)) {
      routeBodies['route:${widget.route}'] = widget.routeBody;
      return;
    }
    if (['chat', 'home'].contains(widget.route)) {
      return;
    }
    route = widget.route;
    final id = 'route:${widget.route}';
    routeBodies[id] = widget.routeBody;

    if (!groups.any((g) => g.contains(id))) groups.first.add(id);
    activeGroup = groupIds[groups.indexWhere((g) => g.contains(id))];
    selected[activeGroup] = id;
  }

  bool openChannel(String id) {
    if (sessions.open(id) == null) return false;
    var index = groups.indexWhere((g) => g.contains(id));
    if (index < 0) {
      index = 0;
      groups.first.add(id);
    }
    selected[groupIds[index]] = id;
    activeGroup = groupIds[index];
    if (mounted) setState(() {});
    return true;
  }

  bool flushDrafts() {
    for (final entry in sessions.controllers.entries) {
      sessions.transferDrafts(entry.key, entry.value);
    }
    if (sessions.draftsChanged) {
      sessions.draftsChanged = false;
      widget.onDraftsChanged?.call();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    // Transfer while the same scope is still current, before releasing children.
    // The root host decides whether a retained classic editor needs hydration.
    for (final entry in sessions.controllers.entries) {
      sessions.transferDrafts(entry.key, entry.value);
    }
    sessions.removeListener(changed);
    sessions.dispose();
    super.dispose();
  }

  void close(String id) => setState(() {
    sessions.close(id);
    routeBodies.remove(id);
    for (var i = groups.length - 1; i >= 0; i--) {
      groups[i].remove(id);
      if (groups[i].isEmpty && groups.length > 1) {
        selected.remove(groupIds.removeAt(i));
        groups.removeAt(i);
        weights.removeAt(i);
      } else if (selected[groupIds[i]] == id) {
        selected[groupIds[i]] = groups[i].firstOrNull ?? '';
      }
    }
    if (!groupIds.contains(activeGroup)) activeGroup = groupIds.first;
  });
  void move(String id, String group) => setState(() {
    final index = groupIds.indexOf(group);
    if (index < 0) return;
    for (final list in groups) {
      list.remove(id);
    }
    groups[index].add(id);
    selected[group] = id;
    activeGroup = group;
    for (var i = groups.length - 1; i >= 0; i--) {
      if (groups[i].isEmpty && groups.length > 1) {
        selected.remove(groupIds.removeAt(i));
        groups.removeAt(i);
        weights.removeAt(i);
      } else if (!groups[i].contains(selected[groupIds[i]])) {
        selected[groupIds[i]] = groups[i].firstOrNull ?? '';
      }
    }
  });
  void split(String id) => setState(() {
    // First consumer supports two real independently resizable groups. More
    // than two and vertical/maximize/rail relocation remain explicit gaps.
    if (groups.length >= 2 || groups.fold<int>(0, (n, g) => n + g.length) < 2) {
      return;
    }
    for (var i = 0; i < groups.length; i++) {
      groups[i].remove(id);
      if (selected[groupIds[i]] == id) {
        selected[groupIds[i]] = groups[i].firstOrNull ?? '';
      }
    }
    final group = 'workspace-group-${nextGroup++}';
    groupIds.add(group);
    groups.add([id]);
    selected[group] = id;
    activeGroup = group;
    weights = [1, 1];
  });

  @override
  Widget build(BuildContext context) {
    sessions.present(
      widget.active
          ? selected.values.where((id) => !id.startsWith('route:')).toSet()
          : {},
    );
    return RaftEditorGroups(
      groups: [
        for (var i = 0; i < groups.length; i++)
          RaftEditorGroup(
            id: groupIds[i],
            selected: selected[groupIds[i]] ?? '',
            tabs: [
              for (final id in groups[i])
                RaftEditorTab(
                  id: id,
                  label: id.startsWith('route:')
                      ? raftText(
                          context,
                          id.substring(6, 7).toUpperCase() + id.substring(7),
                        )
                      : sessions.controllers[id]?.channel?.name ??
                            sessions.channel(id)?.name ??
                            '',
                  child: id.startsWith('route:')
                      ? routeBodies[id] ?? const SizedBox.shrink()
                      : sessions.controllers[id] == null
                      ? const SizedBox.shrink()
                      : _Conversation(
                          key: ValueKey(
                            'grid-conversation-$id-${sessions.draftRevisions[id] ?? 0}',
                          ),
                          controller: sessions.controllers[id]!,
                        ),
                ),
            ],
          ),
      ],
      onSelect: (g, t) {
        setState(() {
          activeGroup = g;
          selected[g] = t;
        });
        // Root page props and selected rail must refresh on a user tab change.
        // Initialization/layout updates never emit a navigation callback.
        widget.onRouteSelected?.call(
          t.startsWith('route:') ? t.substring(6) : 'chat',
        );
      },
      onClose: close,
      onMove: move,
      onSplit:
          MediaQuery.sizeOf(context).width - 240 >=
              2 * RaftEditorGroupMetrics.minimumWidth
          ? split
          : null,
      weights: weights,
      onWeightsChanged: (next) => setState(() => weights = next),
    );
  }
}

class _Conversation extends StatefulWidget {
  const _Conversation({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  final mainSlot = GlobalKey();
  final threadViewport = ChatViewportHandle();
  WorkspaceController get w => widget.controller;
  @override
  void dispose() {
    w.releaseConversationPresentation(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: w,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final thread = w.threadParent != null;
        final split = thread && bounds.maxWidth >= 680;
        w.setConversationPresentation(
          this,
          main: w.foreground && (!thread || split),
          thread: w.foreground && thread,
        );
        final main = Column(
          children: [
            // Source WorkspaceGridRealPanel.ChannelPanel mounts ChatPanel
            // with hideHeader; the editor group's tab already names the channel.
            Expanded(
              child: ServerSetupGate(
                controller: w,
                child: ConversationPanel(controller: w, hideHeader: true),
              ),
            ),
          ],
        );
        final threadBody = !thread
            ? null
            : RaftConversationSurface(
                role: RaftConversationSurfaceRole.threadTimeline,
                child: Column(
                  children: [
                    RaftThreadHeader(
                      presentation: RaftThreadPresentation.side,
                      backLabel: raftText(context, 'Close thread'),
                      closeLabel: raftText(context, 'Close thread'),
                      jumpLabel: raftText(context, 'Jump to beginning'),
                      threadLabel: raftText(context, 'Thread'),
                      onClose: w.closeThread,
                      onBack: w.closeThread,
                      onJumpToStart: threadViewport.jumpToBeginning,
                      actions: [
                        ThreadActions(
                          controller: w,
                          parent: w.threadParent!,
                          menuMode: true,
                        ),
                      ],
                    ),
                    Expanded(
                      child: ServerSetupGate(
                        controller: w,
                        child: RaftChatView(
                          controller: w,
                          thread: true,
                          viewportHandle: threadViewport,
                        ),
                      ),
                    ),
                  ],
                ),
              );
        // Grid panels own no nested application rail. Folded replies retain their
        // main editor, while invisible focus, ticker and read admission stop.
        return Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                Expanded(
                  child: Visibility(
                    visible: !thread || split,
                    maintainState: true,
                    child: ExcludeFocus(
                      excluding: thread && !split,
                      child: KeyedSubtree(key: mainSlot, child: main),
                    ),
                  ),
                ),
                if (split) ConstrainedBox(
                  constraints: const BoxConstraints.tightFor(width: RaftEditorGroupMetrics.threadPaneWidth),
                  child: threadBody,
                ),
              ],
            ),
            if (thread && !split) Positioned.fill(child: threadBody!),
          ],
        );
      },
    ),
  );
}

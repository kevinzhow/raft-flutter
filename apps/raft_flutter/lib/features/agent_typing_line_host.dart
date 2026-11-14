import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_typing_store.dart';
import '../data/personal_presentation.dart';
import '../data/workspace_controller.dart';
import 'sender_avatar_projection.dart';

/// Web `formatAgentTypingSentence` (`typing`): "Niko is typing…", "Niko and
/// Kirby are typing…", "Niko, Kirby and Tenny are typing…", "Niko, Kirby and 3
/// other agents are typing…". Empty for nobody.
String agentTypingSentence(BuildContext context, List<String> names) {
  final others = names.length - 2;
  final (key, values) = switch (names) {
    [] => ('', const <String, Object>{}),
    [final first] => ('{first} is typing…', {'first': first}),
    [final first, final second] => (
      '{first} and {second} are typing…',
      {'first': first, 'second': second},
    ),
    [final first, final second, final third] => (
      '{first}, {second} and {third} are typing…',
      {'first': first, 'second': second, 'third': third},
    ),
    [final first, final second, ...] => (
      others == 1
          ? '{first}, {second} and {others} other agent are typing…'
          : '{first}, {second} and {others} other agents are typing…',
      {
        'first': first,
        'second': second,
        // Web zh-cn counts every agent ("等 5 个 Agent"), en the others.
        'others': Localizations.localeOf(context).languageCode == 'zh'
            ? names.length
            : others,
      },
    ),
  };
  return key.isEmpty ? '' : raftFormat(context, key, values);
}

/// The typing agents of one conversation as the line draws them: named and
/// drawn from the server's agent directory, in the order they started. Empty
/// while the personal "Live agent activity" setting is off.
List<RaftWorkingAgent> typingAgents(
  BuildContext context,
  WorkspaceController w,
  String? channelId,
  String? parentMessageId,
) {
  final presentation = PersonalPresentationScope.maybeOf(context);
  if (presentation != null && !presentation.value.liveActivity) {
    return const [];
  }
  final ids = AgentTypingStore.of(w.client)
      .typingAgentIds(channelId, parentMessageId);
  if (ids.isEmpty) return const [];
  final directory = w.services.entityDirectory.authorAgents;
  final fallback = raftText(context, 'Agent');
  return [
    for (final id in ids)
      () {
        final agent = directory.firstWhere(
          (a) => a['id'] == id,
          orElse: () => const <String, dynamic>{},
        );
        final shown = '${agent['displayName'] ?? ''}';
        final name = shown.isNotEmpty ? shown : '${agent['name'] ?? ''}';
        final avatar = projectSenderAvatar(
          origin: w.client.origin,
          senderId: id,
          senderType: 'agent',
          agents: agent.isEmpty ? const [] : [agent],
          members: const [],
        );
        return RaftWorkingAgent(
          id: id,
          name: name.isEmpty ? fallback : name,
          text: '',
          avatar: RaftAvatarContent(
            name: name.isEmpty ? fallback : name,
            kind: RaftAvatarContentKind.agent,
            uploadedUrl: avatar.uploadedUrl,
            pixelKey: avatar.pixelKey,
          ),
        );
      }(),
  ];
}

/// Rebuilds [builder] when who types into [scope] changes (or, while someone
/// does, the agent directory). Listening is what keeps the store reading the
/// events; rows whose conversation nobody types into never rebuild.
class AgentTypingListener extends StatefulWidget {
  const AgentTypingListener({
    super.key,
    required this.controller,
    required this.scope,
    required this.builder,
  });
  final WorkspaceController controller;

  /// The conversation: its channel id and thread root (null: the channel).
  final (String?, String?) Function() scope;
  final WidgetBuilder builder;

  @override
  State<AgentTypingListener> createState() => _AgentTypingListenerState();
}

class _AgentTypingListenerState extends State<AgentTypingListener> {
  late Listenable listened = _listenable();
  late Object shown = _shown();

  Listenable _listenable() => Listenable.merge([
    AgentTypingStore.of(widget.controller.client),
    widget.controller.services.entityDirectory,
  ]);

  Object _shown() {
    final (channelId, parentId) = widget.scope();
    final ids = AgentTypingStore.of(widget.controller.client)
        .typingAgentIds(channelId, parentId);
    return ids.isEmpty
        ? const <Object>[]
        : [...ids, widget.controller.services.entityDirectory.authorRevision];
  }

  void changed() {
    final next = _shown();
    if (!mounted || listEquals(next as List, shown as List)) return;
    setState(() => shown = next);
  }

  @override
  void initState() {
    super.initState();
    listened.addListener(changed);
  }

  @override
  void didUpdateWidget(covariant AgentTypingListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    shown = _shown();
    if (oldWidget.controller == widget.controller) return;
    listened.removeListener(changed);
    listened = _listenable()..addListener(changed);
  }

  @override
  void dispose() {
    listened.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The typing line of the conversation this chat view shows: the channel or
/// DM itself, or the open thread (its parent's channel and root message). It
/// floats over the bottom of the list, above the composer; nothing while
/// nobody types.
class AgentTypingLineHost extends StatelessWidget {
  const AgentTypingLineHost({
    super.key,
    required this.controller,
    required this.thread,
  });
  final WorkspaceController controller;
  final bool thread;

  @override
  Widget build(BuildContext context) => AgentTypingListener(
    controller: controller,
    scope: () => _scopeOf(controller, thread),
    builder: (context) {
      final w = controller;
      final parent = thread ? w.presentedThreadParent : null;
      if (thread && parent == null) return const SizedBox.shrink();
      final agents = typingAgents(
        context,
        w,
        parent?.channelId ?? w.channel?.id,
        parent?.id,
      );
      return Align(
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(
          child: RaftAgentTypingLine(
            agents: agents,
            sentence: agentTypingSentence(context, [
              for (final agent in agents) agent.name,
            ]),
          ),
        ),
      );
    },
  );
}

(String?, String?) _scopeOf(WorkspaceController w, bool thread) {
  final parent = thread ? w.presentedThreadParent : null;
  if (thread && parent == null) return (null, null);
  return (parent?.channelId ?? w.channel?.id, parent?.id);
}

bool _shown(BuildContext context, WorkspaceController w, bool thread) {
  final (channelId, parentId) = _scopeOf(w, thread);
  return typingAgents(context, w, channelId, parentId).isNotEmpty;
}

/// The list's extra end while the typing line shows (Web
/// AgentTypingListEnd): the last message stays whole above the line. A reader
/// who follows the bottom stays pinned to it when it appears.
class AgentTypingListEnd extends StatefulWidget {
  const AgentTypingListEnd({
    super.key,
    required this.controller,
    required this.thread,
  });
  final WorkspaceController controller;
  final bool thread;

  @override
  State<AgentTypingListEnd> createState() => _AgentTypingListEndState();
}

class _AgentTypingListEndState extends State<AgentTypingListEnd> {
  bool was = false;

  @override
  Widget build(BuildContext context) => AgentTypingListener(
    controller: widget.controller,
    scope: () => _scopeOf(widget.controller, widget.thread),
    builder: (context) {
      final shown = _shown(context, widget.controller, widget.thread);
      if (shown && !was) {
        final position = Scrollable.maybeOf(context)?.position;
        final atEnd =
            position != null &&
            position.hasContentDimensions &&
            position.pixels >= position.maxScrollExtent - 1;
        if (atEnd) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && position.hasContentDimensions) {
              position.jumpTo(position.maxScrollExtent);
            }
          });
        }
      }
      was = shown;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RaftTimelineFooter(),
          if (shown) const SizedBox(height: raftAgentTypingListEnd),
        ],
      );
    },
  );
}

/// The inner stack of [AgentTypingInset]: the timeline's own stack is the
/// next one up.
const agentTypingInsetKey = ValueKey('agent-typing-inset');

/// Lifts the list's bottom controls (Back to bottom, the unread-thread pill)
/// above the typing line while it shows, so the two never overlap.
class AgentTypingInset extends StatelessWidget {
  const AgentTypingInset({
    super.key,
    required this.controller,
    required this.thread,
    required this.child,
  });
  final WorkspaceController controller;
  final bool thread;

  /// Children positioned in a [Stack].
  final Widget child;

  @override
  Widget build(BuildContext context) => AgentTypingListener(
    controller: controller,
    scope: () => _scopeOf(controller, thread),
    builder: (context) => Positioned.fill(
      bottom: _shown(context, controller, thread)
          ? raftAgentTypingLineHeight
          : 0,
      child: Stack(
        key: agentTypingInsetKey,
        fit: StackFit.expand,
        children: [child],
      ),
    ),
  );
}

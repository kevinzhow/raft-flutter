import 'package:flutter/widgets.dart';

import '../data/workspace_controller.dart';
import 'notification_activation_banner.dart';

/// Keeps a conversation's composer alive when the window crosses the phone /
/// desktop breakpoint.
///
/// Below the breakpoint the chat is a page of the phone navigator; above it
/// the same chat sits in the desktop workspace. They are different widget
/// trees, so the chat view (and the composer inside it) is rebuilt from
/// nothing. A composer with its expanded editor open would lose its
/// controller, caret, focus and route.
///
/// This wrapper gives the composer a [GlobalKey] shared by every chat view of
/// the same conversation, so the framework moves the composer's element (and
/// State) into the new tree in the same frame. A GlobalKey must be unique, and
/// a conversation can be built twice at once (the phone keeps the channel
/// page alive under its thread page), so only one wrapper holds the key at a
/// time; the others build their composer plain. A wrapper lets go of the key
/// when it is deactivated, which happens before the replacement tree is built.
class ComposerSlot extends StatefulWidget {
  const ComposerSlot({
    super.key,
    required this.controller,
    required this.thread,
    required this.builder,
  });
  final WorkspaceController controller;
  final bool thread;

  /// Builds the composer. It runs again when the conversation's draft changes
  /// (the composer follows drafts that arrive from elsewhere).
  final WidgetBuilder builder;

  @override
  State<ComposerSlot> createState() => _ComposerSlotState();
}

class _SlotRegistry {
  final keys = <String, GlobalKey>{};
  final holders = <String, State>{};
}

final _registries = Expando<_SlotRegistry>('composer slots');

class _ComposerSlotState extends State<ComposerSlot> {
  late final _SlotRegistry registry = _registries[widget.controller] ??=
      _SlotRegistry();
  String? slot;

  @override
  void initState() {
    super.initState();
    // The channel (or thread channel) the composer writes to. The key is chosen
    // when the slot mounts and does not follow a later channel change.
    final id = widget.thread
        ? widget.controller.threadChannelId
        : widget.controller.channel?.id;
    if (id == null) return;
    final name = '${widget.thread ? 'thread' : 'main'}:$id';
    if (registry.holders.containsKey(name)) return;
    registry.holders[name] = this;
    slot = name;
  }

  void _release() {
    final name = slot;
    if (name != null && identical(registry.holders[name], this)) {
      registry.holders.remove(name);
    }
  }

  @override
  void deactivate() {
    _release();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    final name = slot;
    if (name == null) return;
    // Someone else took the key while this subtree was out of the tree: build
    // plain rather than share a GlobalKey.
    if (registry.holders.containsKey(name)) {
      slot = null;
    } else {
      registry.holders[name] = this;
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.controller.draftChanges(thread: widget.thread),
      builder: (context, _, _) {
        final composer = NotificationActivationComposer(
          controller: widget.controller,
          thread: widget.thread,
          child: widget.builder(context),
        );
        final name = slot;
        if (name == null) return composer;
        return KeyedSubtree(
          key: registry.keys[name] ??= GlobalKey(debugLabel: 'composer:$name'),
          child: composer,
        );
      },
    );
  }
}

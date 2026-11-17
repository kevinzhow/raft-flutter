// The composers that offer As task, by channel (Web
// features/composer/composerTaskMode.ts): the Tasks card's "+ New task"
// turns As task on in the channel's composer when one is mounted.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show RaftComposer;

/// Web `composerTaskMode.ts`: a composer that offers "As task" for a channel
/// says so here; "+" on the Tasks card then writes the task in that channel's
/// own composer instead of opening a dialog. A request reaches the composer
/// that registered last.
abstract final class ComposerTaskModeTargets {
  static final _targets = <String, List<VoidCallback>>{};

  /// Registers [turnOn] (As task on, composer focused) for [channelId];
  /// returns the call that withdraws it (the composer is gone).
  static VoidCallback register(String channelId, VoidCallback turnOn) {
    (_targets[channelId] ??= []).add(turnOn);
    return () {
      final list = _targets[channelId];
      if (list == null) return;
      list.remove(turnOn);
      if (list.isEmpty) _targets.remove(channelId);
    };
  }

  /// Turns As task on in [channelId]'s composer. False when none of that
  /// channel is mounted (the caller falls back to the New task dialog).
  static bool request(String channelId) {
    final list = _targets[channelId];
    if (list == null || list.isEmpty) return false;
    list.last();
    return true;
  }
}

/// A composer that offers As task for [channelId] (Web
/// `useComposerTaskModeTarget` in MessageInput): while mounted, the Tasks
/// card's "+" turns As task on through [onTurnOn] and moves the caret to the
/// end of the composer's text. Wraps the composer's As task toggle.
class ComposerTaskModeTarget extends StatefulWidget {
  const ComposerTaskModeTarget({
    super.key,
    required this.channelId,
    required this.onTurnOn,
    required this.child,
  });
  final String? channelId;
  final VoidCallback onTurnOn;
  final Widget child;

  @override
  State<ComposerTaskModeTarget> createState() => _ComposerTaskModeTargetState();
}

class _ComposerTaskModeTargetState extends State<ComposerTaskModeTarget> {
  VoidCallback? withdraw;

  void bind() {
    withdraw?.call();
    final id = widget.channelId;
    withdraw = id == null ? null : ComposerTaskModeTargets.register(id, turnOn);
  }

  void turnOn() {
    widget.onTurnOn();
    // The composer's text field: the nearest RaftComposer above the toggle,
    // then its EditableText.
    Element? composer;
    context.visitAncestorElements((e) {
      if (e.widget is! RaftComposer) return true;
      composer = e;
      return false;
    });
    EditableTextState? field;
    void visit(Element e) {
      if (field != null) return;
      if (e is StatefulElement && e.state is EditableTextState) {
        field = e.state as EditableTextState;
        return;
      }
      e.visitChildren(visit);
    }

    composer?.visitChildren(visit);
    final editable = field;
    if (editable == null) return;
    editable.requestKeyboard();
    final text = editable.textEditingValue.text;
    editable.userUpdateTextEditingValue(
      editable.textEditingValue.copyWith(
        selection: TextSelection.collapsed(offset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
  }

  @override
  void initState() {
    super.initState();
    bind();
  }

  @override
  void didUpdateWidget(ComposerTaskModeTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) bind();
  }

  @override
  void dispose() {
    withdraw?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Task v2 steps that ask a reason before they write (Web v1.24
// TaskBacklogReasonPopover and TaskHandoffReasonPanel). Backlog is a popover
// anchored to the task's status chip; a hand-off is the step after choosing
// someone in the assignee picker, shown inside the picker. The app owns the
// request: [RaftTaskReasonPanel] collects the optional reason and runs
// `onSubmit`, which resolves false when the write failed (the panel stays
// with the failure under the field).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'anchored_popup.dart';
import 'dismiss_scope.dart';
import 'form_controls.dart' show RaftTextInput, RaftTextarea;
import 'localization.dart';
import 'popover_surface.dart';
import 'raft/button.dart';
import 'space.dart';
import 'task_surface.dart' show taskAssigneeSurface;
import 'theme.dart';

/// Which reason a [RaftTaskReasonPanel] asks for.
enum RaftTaskReasonKind {
  /// Moving a task into Backlog: what would bring it back.
  backlog,

  /// Handing a task to someone else: what it waits on them for.
  handoff,
}

/// The reason form: a field, the failure under it, Cancel and the confirm.
/// Enter confirms (the hand-off field is one line high-wise two rows but
/// Enter still hands over); Escape or Cancel go back without writing.
class RaftTaskReasonPanel extends StatefulWidget {
  const RaftTaskReasonPanel({
    super.key,
    required this.kind,
    required this.onSubmit,
    required this.onCancel,
    this.name,
  });
  final RaftTaskReasonKind kind;

  /// Runs the write with the trimmed reason (blank is no reason).
  final Future<bool> Function(String reason) onSubmit;
  final VoidCallback onCancel;

  /// Hand-off: the chosen assignee as the list names them.
  final String? name;

  @override
  State<RaftTaskReasonPanel> createState() => RaftTaskReasonPanelState();
}

class RaftTaskReasonPanelState extends State<RaftTaskReasonPanel> {
  final reason = TextEditingController();
  bool busy = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next submit starts; the state is dropped when the panel closes.
  bool failed = false;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  bool get backlog => widget.kind == RaftTaskReasonKind.backlog;

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    final ok = await widget.onSubmit(reason.text.trim());
    if (!mounted) return;
    setState(() {
      busy = false;
      failed = !ok;
    });
  }

  /// The write is on its way: going back now would say nothing changed.
  void cancel() {
    if (!busy) widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name ?? '';
    final label = backlog
        ? raftText(context, 'Reason (optional)')
        : raftFormat(
            context,
            'What are you waiting on {name} for? (optional)',
            {'name': name},
          );
    final failure = raftText(
      context,
      backlog
          ? "Couldn't move the task. Try again."
          : "Couldn't assign the task. Try again.",
    );
    final confirm = backlog
        ? raftText(context, 'Move to Backlog')
        : raftFormat(context, 'Hand to {name}', {'name': name});
    final field = backlog
        ? RaftTextInput(
            controller: reason,
            fieldKey: const ValueKey('task-backlog-reason-input'),
            hintText: raftText(context, 'What would bring it back?'),
            semanticLabel: label,
            autofocus: true,
            invalid: failed,
            maxLength: 500,
            onSubmitted: (_) => submit(),
          )
        : CallbackShortcuts(
            // Enter hands it over.
            bindings: {const SingleActivator(LogicalKeyboardKey.enter): submit},
            child: RaftTextarea(
              controller: reason,
              fieldKey: const ValueKey('task-handoff-reason-input'),
              semanticLabel: label,
              rows: 2,
              autofocus: true,
              invalid: failed,
              maxLength: 500,
            ),
          );
    final id = backlog ? 'task-backlog-reason' : 'task-handoff-reason';
    final textStyle = DefaultTextStyle.of(context).style;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): cancel},
      child: Padding(
        key: ValueKey(backlog ? id : '$id-panel'),
        padding: const EdgeInsets.all(RaftSpace.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x3,
          children: [
            if (!backlog) Text(label, style: textStyle),
            field,
            if (failed)
              Text(
                failure,
                key: ValueKey('$id-error'),
                style: textStyle.copyWith(
                  color: RaftTokens.of(context).colors['warning-strong'],
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: RaftSpace.x2,
              runSpacing: RaftSpace.x2,
              children: [
                RaftButton(
                  key: ValueKey('$id-cancel'),
                  label: 'Cancel',
                  uiVariant: RaftButtonVariant.ghost,
                  uiSize: RaftButtonSize.md,
                  onPressed: cancel,
                ),
                RaftButton(
                  key: ValueKey('$id-confirm'),
                  label: confirm,
                  uiVariant: RaftButtonVariant.outline,
                  uiSize: RaftButtonSize.md,
                  busy: busy,
                  onPressed: submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The popover shell of a hand-off reason inside the assignee picker (the
/// picker's own surface and width).
class RaftTaskReasonSurface extends StatelessWidget {
  const RaftTaskReasonSurface({
    super.key,
    required this.child,
    this.width = 240,
  });
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: RaftPopoverSurface(
      surfaceStyle: taskAssigneeSurface(RaftTokens.of(context)),
      child: child,
    ),
  );
}

/// Web `TaskBacklogReasonPopover`: the Backlog reason as a popover under the
/// status chip ([anchorKey], 8px below, 300 wide). A press outside, Escape and
/// Android Back go back without writing ([onDismiss]); [panelKey] lets that
/// wait while a write is on its way.
class RaftTaskReasonPopover extends StatefulWidget {
  const RaftTaskReasonPopover({
    super.key,
    required this.open,
    required this.anchorKey,
    required this.panelKey,
    required this.onSubmit,
    required this.onDismiss,
    required this.child,
  });
  final bool open;
  final GlobalKey anchorKey;
  final GlobalKey<RaftTaskReasonPanelState> panelKey;
  final Future<bool> Function(String reason) onSubmit;
  final VoidCallback onDismiss;

  /// The status chip the popover hangs from.
  final Widget child;

  @override
  State<RaftTaskReasonPopover> createState() => _RaftTaskReasonPopoverState();
}

class _RaftTaskReasonPopoverState extends State<RaftTaskReasonPopover> {
  final portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => sync());
  }

  @override
  void didUpdateWidget(RaftTaskReasonPopover old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => sync());
  }

  void sync() {
    if (!mounted) return;
    if (widget.open && !portal.isShowing) portal.show();
    if (!widget.open && portal.isShowing) portal.hide();
  }

  void dismiss() {
    final panel = widget.panelKey.currentState;
    if (panel != null) {
      panel.cancel();
    } else {
      widget.onDismiss();
    }
  }

  @override
  // ds-allow: the anchored popover host, same OverlayPortal + RaftAnchoredPopup shape as RaftInlineBadgeEditor.
  Widget build(BuildContext context) => OverlayPortal(
    controller: portal,
    overlayChildBuilder: (context) => !widget.open
        ? const SizedBox.shrink()
        : RaftBackDismiss(
            onDismiss: dismiss,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('task-reason-scrim'),
                    behavior: HitTestBehavior.opaque,
                    onTap: dismiss,
                  ),
                ),
                Positioned.fill(
                  child: RaftAnchoredPopup(
                    anchorKey: widget.anchorKey,
                    gap: RaftSpace.x2,
                    collisionPadding: RaftSpace.x2,
                    child: RaftTaskReasonSurface(
                      width: 300,
                      child: RaftTaskReasonPanel(
                        key: widget.panelKey,
                        kind: RaftTaskReasonKind.backlog,
                        onSubmit: widget.onSubmit,
                        onCancel: widget.onDismiss,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    child: widget.child,
  );
}

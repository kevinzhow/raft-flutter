import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;

import 'agent_avatar_picker.dart' show RaftAvatarDiscardConfirmation;
import 'overlays/dialog.dart' show showRaftDialog;

import 'design_primitives.dart';
import 'icons.dart';
import 'dialog_card.dart'
    show RaftCloseButton, RaftTextSteps, raftCssTextStyle, showRaftModal;
import 'presentation.dart';
import 'settings_layout.dart' show RaftSpace;
import 'sheet.dart';
import 'theme.dart';

// A form is a window with inputs and a submit button (create a channel, edit a
// profile, rename). It is shown with `RaftPresentationPolicy.form`: a bottom
// sheet below 768 and a centered dialog from 768. One route carries both, so
// the window keeps its text, focus and caret when it crosses the breakpoint.
//
// The route knows the form; the form's scaffold (a dialog card, a form dialog)
// has to draw it. [RaftFormFrame] tells the scaffold which form it is in:
// outside any frame (a preview, a test that opens a plain dialog) a scaffold
// draws its dialog card as it always did.

/// Which form the window around this scaffold currently has.
class RaftFormFrame extends InheritedWidget {
  const RaftFormFrame({super.key, required this.form, required super.child});
  final RaftSurfaceForm form;

  /// The form of the enclosing presented window, or null when the scaffold is
  /// not in one.
  static RaftSurfaceForm? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftFormFrame>()?.form;

  /// Whether the scaffold is drawn as a bottom sheet.
  static bool sheetOf(BuildContext context) =>
      maybeOf(context) == RaftSurfaceForm.sheet;

  /// Whether the scaffold sits in a presented window (sheet or dialog) that
  /// already draws the scrim and centers its content.
  static bool framedOf(BuildContext context) => maybeOf(context) != null;

  @override
  bool updateShouldNotify(RaftFormFrame oldWidget) => form != oldWidget.form;
}

Widget _formContent(
  WidgetBuilder builder,
  RaftSurfaceForm form,
  bool guardUnsaved,
) {
  final content = RaftFormFrame(
    form: form,
    child: Builder(builder: builder),
  );
  return Material(
    type: MaterialType.transparency,
    // The guard keeps one state across the sheet / dialog switch (the same
    // slot in the tree), and with it the text it saw when the form opened.
    child: guardUnsaved ? RaftUnsavedGuard(child: content) : content,
  );
}

/// The route [showRaftForm] pushes, for hosts that keep it (to close it when
/// their authority changes).
RaftPresentedRoute<T> raftFormRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  RaftPresentationPolicy policy = RaftPresentationPolicy.form,
  RouteSettings? routeSettings,
  bool dismissible = true,
  bool guardUnsaved = true,
  String? label,
  double dialogMaxWidth = 560,
  double sheetInitialSize = RaftSheetMetrics.largeDetent,
}) => raftPresentedRoute<T>(
  context,
  policy: policy,
  content: (_, form) => _formContent(builder, form, guardUnsaved),
  routeSettings: routeSettings,
  dismissible: dismissible,
  label: label,
  dialogMaxWidth: dialogMaxWidth,
  sheetInitialSize: sheetInitialSize,
);

/// Opens a form. The sheet opens at the large detent: a form with inputs gets
/// the keyboard at once, and the sheet is then only as tall as the window
/// above it. [builder] builds the form's scaffold once; the scaffold draws
/// itself as a sheet or a dialog from [RaftFormFrame]. Esc, Back, a scrim press,
/// a drag down and the close button all ask the route to close, and with
/// [guardUnsaved] (the default) a form whose fields changed since it opened
/// asks "Discard your changes?" first; Cancel and Submit in the footer pop
/// directly and never ask. [policy] is [RaftPresentationPolicy.confirm] for a form without inputs
/// (a question with two buttons), which stays a dialog on every width.
Future<T?> showRaftForm<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  RaftPresentationPolicy policy = RaftPresentationPolicy.form,
  RouteSettings? routeSettings,
  bool dismissible = true,
  bool guardUnsaved = true,
  String? label,
  double dialogMaxWidth = 560,
  double sheetInitialSize = RaftSheetMetrics.largeDetent,
}) => Navigator.of(context, rootNavigator: true).push(
  raftFormRoute<T>(
    context,
    builder: builder,
    policy: policy,
    routeSettings: routeSettings,
    dismissible: dismissible,
    guardUnsaved: guardUnsaved,
    label: label,
    dialogMaxWidth: dialogMaxWidth,
    sheetInitialSize: sheetInitialSize,
  ),
);

/// Keeps unsaved input from being lost to a stray close.
///
/// It watches every editable text field in the form (the text each had when it
/// first appeared against the text now) plus any [watch]ed checks, and answers
/// a close request - Back, Esc, a scrim press, a drag down and, through
/// [raftGuardedClose], the close button - with the existing "Unsaved changes /
/// Discard your changes?" confirmation while something differs. A form that
/// has not changed closes at once. The route's own Cancel and Submit pop
/// directly and are not asked.
class RaftUnsavedGuard extends StatefulWidget {
  const RaftUnsavedGuard({super.key, required this.child});
  final Widget child;

  /// The guard of the enclosing form, or null outside one.
  static RaftUnsavedGuardState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_GuardScope>()?.state;

  @override
  State<RaftUnsavedGuard> createState() => RaftUnsavedGuardState();
}

/// Excludes the text inputs below it from the enclosing [RaftUnsavedGuard]: a
/// search box or a picker whose text only mirrors a choice, where Web asks
/// nothing when the form is closed.
class RaftUnsavedGuardIgnore extends StatelessWidget {
  const RaftUnsavedGuardIgnore({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

class _GuardScope extends InheritedWidget {
  const _GuardScope({required this.state, required super.child});
  final RaftUnsavedGuardState state;
  @override
  bool updateShouldNotify(_GuardScope old) => false;
}

class RaftUnsavedGuardState extends State<RaftUnsavedGuard> {
  /// The text each field had when the guard first saw it.
  final _initial = <TextEditingController, String>{};
  final _checks = <bool Function()>{};
  bool _dirty = false, _asking = false, _bypass = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_scan);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scan);
    // A disposed controller still accepts removeListener.
    for (final controller in _initial.keys) {
      controller.removeListener(_refresh);
    }
    super.dispose();
  }

  /// Adds a check for state that is not text (a choice, a toggle). Call
  /// [recheck] when it changes.
  void watch(bool Function() dirty) => _checks.add(dirty);
  void unwatch(bool Function() dirty) => _checks.remove(dirty);
  void recheck() => _refresh();

  /// Takes in the fields that appeared since the last look (a new row) and
  /// forgets the ones that went away.
  void _scan() {
    if (!mounted) return;
    final seen = <TextEditingController>{};
    void visit(Element element) {
      final widget = element.widget;
      if (widget is RaftUnsavedGuardIgnore) return;
      if (widget is EditableText && !widget.readOnly) {
        seen.add(widget.controller);
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    for (final gone in _initial.keys.where((c) => !seen.contains(c)).toList()) {
      gone.removeListener(_refresh);
      _initial.remove(gone);
    }
    for (final controller in seen) {
      if (_initial.containsKey(controller)) continue;
      _initial[controller] = controller.text;
      controller.addListener(_refresh);
    }
    _refresh();
  }

  bool get _changed =>
      _initial.entries.any((e) => e.key.text != e.value) ||
      _checks.any((check) => check());

  /// A field whose text the app rewrote itself (a combobox showing the chosen
  /// name once the list has loaded), not the member: the new text is its
  /// baseline.
  void rebase(TextEditingController controller) {
    if (_initial.containsKey(controller))
      _initial[controller] = controller.text;
  }

  void _refresh() {
    if (!mounted) return;
    // A controller written while the tree builds must not rebuild the guard
    // in the same frame.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
      return;
    }
    final dirty = _changed;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  /// Runs [close] now, or after the member confirmed discarding the changes.
  void requestClose(VoidCallback close) {
    if (!_changed) return close();
    unawaited(
      _confirm().then((discard) => discard ? closeWithoutAsking(close) : null),
    );
  }

  /// Runs [close] (a Cancel button, a confirmed discard) without asking, even
  /// when it closes through [Navigator.maybePop]. The route asks the pop
  /// scopes a moment later, so the exemption lasts until the next frame.
  void closeWithoutAsking(VoidCallback close) {
    _bypass = true;
    close();
    // The pop (or the route's refusal) rebuilds the page, so a frame follows.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bypass = false);
  }

  Future<bool> _confirm() async {
    if (_asking) return false;
    _asking = true;
    final discard = await showRaftDialog<bool>(
      context: context,
      builder: (dialog) => RaftAvatarDiscardConfirmation(
        onKeep: () => Navigator.pop(dialog, false),
        onDiscard: () => Navigator.pop(dialog, true),
      ),
    );
    _asking = false;
    return discard == true && mounted;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (_bypass) {
        Navigator.of(context).pop();
      } else if (_changed) {
        // Another PopScope's veto (a submit in flight) is not ours to
        // override: only ask when this form has unsaved input.
        requestClose(() => Navigator.of(context).pop());
      }
    },
    child: _GuardScope(state: this, child: widget.child),
  );
}

/// [close] for an explicit Cancel in the form's footer: never asks.
VoidCallback? raftExplicitClose(BuildContext context, VoidCallback? close) {
  if (close == null) return null;
  final guard = RaftUnsavedGuard.maybeOf(context);
  return guard == null ? close : () => guard.closeWithoutAsking(close);
}

/// [close] for a close button: it asks first when the form has unsaved input.
/// Null stays null (a disabled button).
VoidCallback? raftGuardedClose(BuildContext context, VoidCallback? close) {
  if (close == null) return null;
  final guard = RaftUnsavedGuard.maybeOf(context);
  return guard == null ? close : () => guard.requestClose(close);
}

/// Opens [builder] in a window: a form
/// with inputs ([form]: a bottom sheet below 768, a dialog from 768), a Web
/// `Modal` ([modal]) or a dialog. For a host that decides at run time which of
/// the three a page needs.
Future<V?> showRaftWindow<V>(
  BuildContext context,
  WidgetBuilder builder, {
  bool modal = false,
  bool form = false,
}) => form
    ? showRaftForm<V>(context, builder: builder)
    : modal
    ? showRaftModal<V>(context, builder: builder)
    : showDialog<V>(
        context: context,
        // Web `DialogCard` / `ConfirmDialog`: no scrim close.
        barrierDismissible: false,
        builder: builder,
      );

/// A form drawn as a bottom sheet: the handle and a pinned title row with the
/// close button, the fields scrolling in between and the actions pinned at
/// the bottom (above the keyboard).
class RaftFormSheet extends StatelessWidget {
  const RaftFormSheet({
    super.key,
    required this.title,
    required this.onClose,
    required this.body,
    this.footer,
    this.uppercase = true,
    this.titleGlyph,
    this.closeButton,
  });

  /// The title as it is shown (already localized).
  final String title;
  final VoidCallback? onClose;
  final Widget body;

  /// The action row; stays in view while [body] scrolls.
  final Widget? footer;
  final bool uppercase;

  /// A leading icon in the title row.
  final RaftGlyph? titleGlyph;

  /// The scaffold's own close button; defaults to [RaftCloseButton].
  final Widget? closeButton;

  static const _closeFace = RaftMetrics.buttonSm;
  static const _titleLines = 2, _glyph = 18.0;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = raftCssTextStyle(
      family: t.headingFont,
      step: RaftTextSteps.lg,
      weight: FontWeight.w700,
      color: t.ink,
    );
    final text = uppercase ? title.toUpperCase() : title;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        // The pinned header has one fixed height: as tall as the title needs,
        // up to two lines.
        final painter =
            TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: Directionality.of(context),
              textScaler: scaler,
              maxLines: _titleLines,
            )..layout(
              maxWidth:
                  box.maxWidth -
                  RaftSpace.x4 * 3 -
                  _closeFace -
                  (titleGlyph == null ? 0 : _glyph + RaftSpace.x4),
            );
        final textHeight = painter.height;
        painter.dispose();
        final extent =
            (textHeight > _closeFace ? textHeight : _closeFace) +
            RaftSpace.x2 * 2;
        return RaftSheet(
          header: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RaftSpace.x4,
              vertical: RaftSpace.x2,
            ),
            child: Row(
              spacing: RaftSpace.x4,
              children: [
                if (titleGlyph != null)
                  RaftIcon(titleGlyph!, size: _glyph, color: t.ink),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      text,
                      maxLines: _titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ),
                closeButton ??
                    RaftCloseButton(
                      onPressed: raftGuardedClose(context, onClose),
                    ),
              ],
            ),
          ),
          headerExtent: extent,
          padding: const EdgeInsets.fromLTRB(
            RaftSpace.x4,
            0,
            RaftSpace.x4,
            RaftSpace.x4,
          ),
          body: body,
          footer: footer == null
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RaftSpace.x4,
                    RaftSpace.x2,
                    RaftSpace.x4,
                    RaftSpace.x2,
                  ),
                  child: footer,
                ),
        );
      },
    );
  }
}

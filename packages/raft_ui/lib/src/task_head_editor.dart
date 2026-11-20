// Editing a task's title and description in its head (Web v1.24
// TaskHeadEditor.tsx, #wg-task-v2:#22). The app owns the write (PATCH
// /tasks/:id) and is the authority on who may edit; this owns the draft.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'banner.dart';
import 'form_controls.dart' show RaftTextInput, RaftTextarea;
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'icons.dart';
import 'localization.dart';
import 'raft/button.dart';
import 'tooltip.dart' show RaftTooltip;

/// Which field of the task head is edited.
enum RaftTaskHeadField { title, description }

/// What a save came to.
sealed class RaftTaskAmendOutcome {
  const RaftTaskAmendOutcome();
}

/// Written.
class RaftTaskAmendSaved extends RaftTaskAmendOutcome {
  const RaftTaskAmendSaved();
}

/// Someone else got there first (a 409 carrying `currentRevision`).
class RaftTaskAmendStale extends RaftTaskAmendOutcome {
  const RaftTaskAmendStale();
}

/// Refused or lost; [message] is the server's word, if any.
class RaftTaskAmendFailed extends RaftTaskAmendOutcome {
  const RaftTaskAmendFailed([this.message]);
  final String? message;
}

/// The pencil beside the title or the description: an icon button named by
/// its tooltip (Web TaskHeadEditButton).
class RaftTaskHeadEditButton extends StatelessWidget {
  const RaftTaskHeadEditButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => RaftTooltip(
    message: raftText(context, label),
    excludeFromSemantics: true,
    child: RaftButton(
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.iconMd,
      glyph: RaftGlyph.pencil,
      glyphSize: 16,
      semanticLabel: label,
      onPressed: onPressed,
    ),
  );
}

/// The title (one line) or the description (a text area) being edited, in
/// place. Enter saves either; in the description Shift+Enter is a new line.
/// Leaving the field saves too; Esc cancels, putting the text back. There
/// are no Save / Cancel buttons: refusals and the stale warning show under
/// the field, which stays in edit mode with the draft, so nothing typed is
/// lost to a race or a dropped connection.
///
/// Someone else's edit is caught by the field itself: the field's text when
/// editing opened is the base, and a save finding [value] no longer the base
/// says so and sends nothing. Saving again after that replaces their text.
class RaftTaskHeadFieldEditor extends StatefulWidget {
  const RaftTaskHeadFieldEditor({
    super.key,
    required this.field,
    required this.value,
    required this.onSave,
    required this.onClose,
  });
  final RaftTaskHeadField field;

  /// The field's text as the task has it now.
  final String value;

  /// Writes [text] (blank description: remove it).
  final Future<RaftTaskAmendOutcome> Function(String text) onSave;
  final VoidCallback onClose;

  @override
  State<RaftTaskHeadFieldEditor> createState() =>
      _RaftTaskHeadFieldEditorState();
}

enum _Problem { titleRequired, stale, failed }

class _RaftTaskHeadFieldEditorState extends State<RaftTaskHeadFieldEditor> {
  late final draft = TextEditingController(text: widget.value);
  final focus = FocusNode();

  /// The text this edit started from. Null after a lost race: the next save
  /// takes whatever the task has then as the base.
  String? base;
  bool busy = false, closed = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next save starts, the text changes or the editor closes; the state is dropped with the field.
  _Problem? problem;
  // ignore: raft_lints/avoid_imperative_notice_state -- The server's sentence for the failed save; read only while problem is failed and replaced by the next one.
  String? failure;

  bool get title => widget.field == RaftTaskHeadField.title;

  @override
  void initState() {
    super.initState();
    base = widget.value.trim();
    focus.addListener(() {
      // Leaving the field saves. Enter on the one-line title also gives up
      // focus before it submits; that save keeps the field focused, so the
      // blur's save waits a frame and stands down.
      if (focus.hasFocus) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !focus.hasFocus && !closed && !busy) save();
      });
    });
    draft.addListener(() {
      if (problem == _Problem.titleRequired) {
        setState(() => problem = null);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focus.requestFocus();
      draft.selection = TextSelection.collapsed(offset: draft.text.length);
    });
  }

  @override
  void dispose() {
    draft.dispose();
    focus.dispose();
    super.dispose();
  }

  void close() {
    closed = true;
    widget.onClose();
  }

  Future<void> save() async {
    if (busy || closed) return;
    final value = draft.text.trim(), current = widget.value.trim();
    if (title && value.isEmpty) {
      setState(() => problem = _Problem.titleRequired);
      focus.requestFocus();
      return;
    }
    final from = base ?? current;
    // Nothing of ours to write: unchanged, or already what the task says.
    if (value == from || value == current) {
      close();
      return;
    }
    if (current != from) {
      // Someone else changed this field since the edit opened: say so and let
      // the person decide. The next save is against their text.
      setState(() {
        base = current;
        problem = _Problem.stale;
      });
      focus.requestFocus();
      return;
    }
    base = current;
    setState(() {
      busy = true;
      problem = null;
    });
    final outcome = await widget.onSave(value);
    if (!mounted) return;
    // Enter on a one-line field gives up focus; a refused save keeps editing.
    if (outcome is! RaftTaskAmendSaved) focus.requestFocus();
    switch (outcome) {
      case RaftTaskAmendSaved():
        busy = false;
        close();
      case RaftTaskAmendStale():
        setState(() {
          busy = false;
          base = null;
          problem = _Problem.stale;
        });
      case RaftTaskAmendFailed(:final message):
        setState(() {
          busy = false;
          problem = _Problem.failed;
          failure = message;
        });
    }
  }

  void cancel() {
    // The write is on its way: closing now would say nothing changed.
    if (!busy) close();
  }

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, title ? 'Task title' : 'Task description');
    final notice = switch (problem) {
      _Problem.stale => raftText(
        context,
        'Someone else changed this while you were editing. Keep editing, or save again to replace their version with yours.',
      ),
      _Problem.failed =>
        failure ?? raftText(context, "Couldn't save your edit. Try again."),
      _ => null,
    };
    final control = title
        ? RaftTextInput(
            controller: draft,
            focusNode: focus,
            fieldKey: const ValueKey('task-head-title-input'),
            semanticLabel: label,
            invalid: problem == _Problem.titleRequired,
            maxLength: 200,
            onSubmitted: (_) => save(),
          )
        : RaftTextarea(
            controller: draft,
            focusNode: focus,
            fieldKey: const ValueKey('task-head-description-input'),
            semanticLabel: label,
            rows: 5,
            maxLength: 10000,
          );
    return CallbackShortcuts(
      bindings: {
        // Esc cancels the edit and stops there: the dialog stays open.
        const SingleActivator(LogicalKeyboardKey.escape): cancel,
        if (!title) const SingleActivator(LogicalKeyboardKey.enter): save,
      },
      child: Column(
        key: ValueKey(
          title ? 'task-head-editor-title' : 'task-head-editor-description',
        ),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          control,
          if (problem == _Problem.titleRequired)
            Text(
              raftText(context, 'A task needs a title.'),
              key: const ValueKey('task-head-title-required'),
              style: RaftTokens.of(context).scale(
                RaftTypeScale.footnote,
                color: RaftTokens.of(context).ui.danger,
              ),
            ),
          if (notice != null)
            RaftBanner(
              key: const ValueKey('task-head-edit-notice'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.triangleAlert,
              description: notice,
            ),
        ],
      ),
    );
  }
}
